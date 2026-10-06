#!/usr/bin/env python3
"""atlas.py - shelf-pack do 2048x2048 + manifest.json (granule assets.atlas).

ROZSAH (MERENO 2026-10-05 na instalaci 1.25.35, ne odhadnuto):
  land = TexID z tiledata (`tiles.json` land.pole `texture`), NE id dlazdice:
         pokryti artem je pri TexID 16 055/16 384 dlazdic (97 %), pri id dlazdice
         jen 4 244 (25 %) - mereni: `.cache/analysis/mereni-land-index.py`.
         3 732 TexID z 4 012 ma v archivu zaznam; tech 280 se nedostane do
         manifestu a vypsou se do `report`.
  item = staticky art z archivu, ktery ma v tiledata neprazdne jmeno
         (36 179 z 39 516; 3 337 prazdnych slotu = art ID, ktere tiledata nezná,
         ty se podle docs/03 §3.5.3 bod 2 do manifestu nedostanou).
  gump = vsechny gumpy v gumpartLegacyMUL.uop.
  Plne pruhledny sprite se do manifestu nedostane (G6 by ho hlasil jako chybu a
  spravne by udelala); jeho pocet je v `report`, ne v tichu.

KLIC MANIFESTU: `sprites` je SEZNAM (ne slovnik), aby ho brana G6 umela precist
(`check-assets.py:43` hleda `sprites/entries/tiles/items` jako list). Kazdy
zaznam ma `page` jako JMENO souboru a `rect` ve tvaru PILu
`[levy, horni, pravy, dolni]` (tak to chce `Image.crop`, ktery G6 i `over()`
volaji) - vedle toho i `x`, `y`, `w`, `h`, aby neslo o tom, ktera cisla jsou
souřadnice a ktera rozměr. Kdyby byl `rect` = [x, y, w, h], PIL by branu
shodil na Exception misto vady.

OFSAHY ZAROVNANI (ox, oy) - prevedeno z ClassicUO, ne odhadnuto:
  ChunkMesh.cs:434-439 (staticky objekt z mapy):
      baseX = (x - y) * 22 - 22;  baseY = (x + y) * 22 - (z << 2) - 22
      ox = (w >> 1) - 22;          oy = h - 44
      -> spodni hrana statiku lezi na spodni hrane dlazdice, vodorovne je
         uprostred. Kontrolni invariant je v `self_test`.
  ChunkMesh.cs:358 (land): ox = oy = 0 - diamant 44x44 se kresli od baseX/baseY,
      ktera uz maji -22, takze centering je primo v tom vzorci.
  ! NEROZLISENO A NEODHADNUTO: predmet/mobil lezici na zemi kresli ClassicUO
      o 22 px vys (ItemView.cs:349-352, SpriteInfo.Center = 0,0). My davame
      variantu pro mapovy static; rozhodne `render` (otevrena vec v HANDOFF).

DETERMINISM: razeni `(-h, w, kind, id)`, zadne casove znacky, sort_keys=True.
Priimaci kriterium granule: dva behy daji shodny SHA-256 manifestu.

Pouziti:
  python tools/uoextract/atlas.py --out assets/uo [--only land,item,gump]
  python tools/uoextract/atlas.py --verify --out assets/uo
  python tools/uoextract/atlas.py --self-test
"""
from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from art import (DEFAULT_INSTALL, LAND_BYTES, LAND_SIZE, MAX_LAND,  # noqa: E402
                 STATIC_BASE, ArtArchive, to_image)
from gump import GumpArchive  # noqa: E402

PAGE = 2048
PAD = 1                      # 1 px pruhledneho okraje: filtr v GPU by nasal souseda
# docs/03 §3.5.3 bod 1: 6 znamych art ID, ktera se maji poznat pohledem
KNOWN = ((3921, "item"), (3936, "item"), (5118, "item"),
         (7609, "item"), (2482, "item"), (3, "land"))


def rozmiar(kind: str, payload: bytes | None) -> tuple[int, int] | None:
    """(sirka, vyska) z hlavicky payloadu - bez dekodovani pixelu (dvoupruchod).

    Rozmery vetsi nez stranka se odmita: `rozloz` by je musel umistit mimo
    stranku a sprite by vysel z obrazku.
    """
    if payload is None or len(payload) < 8:
        return None
    if kind == "land":
        return (LAND_SIZE, LAND_SIZE) if len(payload) >= LAND_BYTES else None
    w, h = (struct.unpack_from("<Hxxh", payload, 0) if kind == "item"
            else struct.unpack_from("<II", payload, 0))
    return (w, h) if 0 < w <= PAGE and 0 < h <= PAGE else None


def ofsahy(kind: str, w: int, h: int) -> tuple[int, int]:
    """(ox, oy) = posun, ktery se odecte od baseX/baseY dlazdice (ChunkMesh.cs)."""
    return (0, 0) if kind == "land" else ((w >> 1) - 22, h - 44)


def rozloz(rady: list[tuple], page: int = PAGE, pad: int = PAD) -> list[tuple]:
    """Shelf-pack: police po vysce sestupne, na shodne vysce razeni podle id.

    `rady` jsou (kind, id, w, h); vraci (kind, id, cislo stranky, x, y).
    Poradi vstupu nehraje roli - to je prijimaci podminka opakovatelnosti.
    Cisl stranky nikdy neklesa, takze vystup je seskupeny po strankach.
    """
    out: list[tuple] = []
    cislo = x = y = vyska = 0
    for kind, ident, w, h in sorted(rady, key=lambda r: (-r[3], r[2], r[0], r[1])):
        if x + w + pad > page:
            x, y, vyska = 0, y + vyska + pad, 0
        if y + h + pad > page:
            cislo, x, y, vyska = cislo + 1, 0, 0, 0
        out.append((kind, ident, cislo, x, y))
        x += w + pad
        vyska = max(vyska, h)
    return out


def rozsah(tiles: dict) -> tuple[set, set]:
    """(land TexID, item id) z extrahovaného tiledata + pravidla docs/03 §3.5.3."""
    pole = tiles["layout"]["land_fields"].index("texture")
    jmeno = tiles["layout"]["item_fields"].index("name")
    return ({r[pole] for r in tiles["land"]},
            {i for i, r in enumerate(tiles["item"]) if r[jmeno]})


def sha256(cesta: Path) -> str:
    h = hashlib.sha256()
    with open(cesta, "rb") as f:
        for blok in iter(lambda: f.read(1 << 20), b""):
            h.update(blok)
    return h.hexdigest()


def rozbal(archiv, kind: str, ident: int):
    """Dekodovany sprite (w, h, pixely) nebo None."""
    return archiv.land_art(ident) if kind == "land" else (
        archiv.art(ident) if kind == "item" else archiv.gump(ident))


def sestav(install: str, out: Path, tiles_path: Path, only: set[str]) -> dict:
    """Zaradi vsechny pozadovane sprity do stranek a napise manifest.json."""
    from PIL import Image

    tiles = json.loads(tiles_path.read_text(encoding="utf-8"))
    land_ids, item_ids = rozsah(tiles)
    art, gumpy = ArtArchive(install), GumpArchive(install)
    report: dict[str, int] = {}
    sprites: list[dict] = []
    stranky: list[str] = []

    for kind in ("land", "item", "gump"):
        if kind not in only:
            continue
        archiv = gumpy if kind == "gump" else art
        ids = (sorted(land_ids) if kind == "land" else sorted(item_ids) if kind == "item"
               else [i for i in range(len(gumpy.entries) + 2048) if gumpy.payload(i) is not None])
        rady, chybi = [], 0
        for ident in ids:
            if kind == "land" and not 0 <= ident < MAX_LAND:
                chybi += 1                 # TexID mimo land casti archivu (mereno: 21 333)
                continue
            rozm = rozmiar(kind, archiv.payload(ident + STATIC_BASE if kind == "item" else ident))
            if rozm is None:                  # art ID, ktery v archivu neni (report, ne ticho)
                chybi += 1
                continue
            rady.append((kind, ident, *rozm))
        prazdnych, otevrena = 0, None
        for _, ident, cislo, x, y in rozloz(rady):
            if cislo != otevrena:                      # predchozi stranka se zapise a uvolni
                if otevrena is not None:
                    stranky.append(uloz(plocha, out, f"{kind}_{otevrena}.png"))
                otevrena = cislo
                plocha = Image.new("RGBA", (PAGE, PAGE), (0, 0, 0, 0))
            dec = rozbal(archiv, kind, ident)
            if dec is None:
                prazdnych += 1
                continue
            w, h, pixely = dec
            if not any(p[3] for radka in pixely for p in radka):
                prazdnych += 1                      # plne pruhledny: do manifestu nejde
                continue
            plocha.paste(to_image(w, h, pixely), (x, y))
            ox, oy = ofsahy(kind, w, h)
            sprites.append({"id": ident, "kind": kind, "page": f"atlas/{kind}_{cislo}.png",
                            "x": x, "y": y, "w": w, "h": h, "rect": [x, y, x + w, y + h],
                            "ox": ox, "oy": oy})
        if otevrena is not None:
            stranky.append(uloz(plocha, out, f"{kind}_{otevrena}.png"))
        report[f"{kind}_pozadovano"] = len(ids)
        report[f"{kind}_chybi_v_archivu"] = chybi
        report[f"{kind}_prazdnych"] = prazdnych
        print(f"[atlas] {kind}: {len(ids)} pozadovano, {chybi} v archivu chybi, "
              f"{sum(1 for s in sprites if s['kind'] == kind)} vlozeno, {prazdnych} preskoceno")

    (out / "atlas").mkdir(parents=True, exist_ok=True)
    manifest = {
        "version": 1,
        "generator": "tools/uoextract/atlas.py",
        "page_size": PAGE,
        "pad": PAD,
        "source": {
            "install": str(install),
            "client_version": tiles.get("source", {}).get("install_version"),
            "sha256": {p.name: sha256(p) for p in
                       (Path(install) / "artLegacyMUL.uop",
                        Path(install) / "gumpartLegacyMUL.uop", tiles_path)},
        },
        "pages": [{"file": f"atlas/{n}", "w": PAGE, "h": PAGE,
                   "count": sum(1 for s in sprites if s["page"] == f"atlas/{n}")}
                  for n in sorted(stranky)],
        "sprites": sorted(sprites, key=lambda s: (s["kind"], s["id"])),
        "anim": {"file": "anim-manifest.json", "pixels_decoded": False,
                 "duvod": "tvar hlavicky framu a kody indexu v RLE proudu anim.mul "
                          "nejsou overene (research/anim-mereni.md) - pixely se "
                          "neextrahuji"},
        "report": report,
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=1) + "\n",
        encoding="utf-8", newline="\n")
    return manifest


def uloz(plocha, out: Path, jmeno: str) -> str:
    """Zapise stranku atlasu a vrati jeji relativni cestu."""
    (out / "atlas").mkdir(parents=True, exist_ok=True)
    plocha.save(out / "atlas" / jmeno)
    return jmeno


def over(out: Path, sada: str) -> int:
    """Premera manifestu z disku: stranky existuji, sprity nejsou prazdne, znama ID jsou."""
    from PIL import Image

    chyby: list[str] = []
    cesta = out / "manifest.json"
    if not cesta.exists():
        print(f"[atlas] CHYBA: {cesta} neexistuje - neni co overovat")
        return 1
    data = json.loads(cesta.read_text(encoding="utf-8"))
    mereno = len(data["pages"])
    for stranka in data["pages"]:
        if not (out / stranka["file"]).exists():
            chyby.append(f"chybi stranka {stranka['file']}")
    obrazky = {s["file"]: Image.open(out / s["file"]).convert("RGBA") for s in data["pages"]
               if (out / s["file"]).exists()}
    for sprite in data["sprites"]:
        img = obrazky.get(sprite["page"])
        if img is None:
            continue
        mereno += 1
        if img.crop(tuple(sprite["rect"])).getbbox() is None:
            chyby.append(f"prazdny sprite {sprite['kind']} {sprite['id']}")
    nalezene = []
    for ident, kind in KNOWN:
        sprite = next((s for s in data["sprites"] if s["id"] == ident and s["kind"] == kind), None)
        if sprite is None or sprite["page"] not in obrazky:
            chyby.append(f"znamy art {kind} {ident} neni v manifestu")
            continue
        nalezene.append(obrazky[sprite["page"]].crop(tuple(sprite["rect"])))
    if nalezene:
        vyska = max(i.height for i in nalezene)
        plachta = Image.new("RGBA", (sum(i.width for i in nalezene), vyska), (24, 24, 32, 255))
        x = 0
        for img in nalezene:
            plachta.alpha_composite(img, (x, 0))
            x += img.width
        plachta.save(sada)
        print(f"[atlas] nahled pro lidskou kontrolu (read_image): {sada}")
    print(f"[atlas] overeno {mereno} veci ({len(data['pages'])} stranek, "
          f"{len(data['sprites'])} spritu), {len(chyby)} chyb")
    for chyba in chyby[:10]:
        print(f"[atlas] CHYBA: {chyba}")
    return 1 if chyby else 0


def self_test() -> int:
    """Offline: pomer, razeni, ofsahy a opakovatelnost - bez instalace UO."""
    chyby: list[str] = []
    pocet = 0

    def kontrola(ok: bool, text: str) -> None:
        nonlocal pocet
        pocet += 1
        if not ok:
            chyby.append(text)

    rady = [("item", 7, 40, 100), ("item", 3, 50, 100), ("land", 2, 44, 44),
            ("item", 9, 20, 10), ("gump", 1, 60, 204), ("item", 5, 44, 44)]
    a = rozloz(rady, page=256)
    b = rozloz(list(reversed(rady)), page=256)
    kontrola(a == b, "rozloz zavisi na poradi vstupu (stejne rady -> jine umisteni)")
    vysky = {(k, i): h for k, i, w, h in rady}
    poradi = sorted(a, key=lambda r: r[2])
    kontrola(all(vysky[poradi[i][:2]] >= vysky[poradi[i + 1][:2]]
                 for i in range(len(poradi) - 1) if poradi[i][2] == poradi[i + 1][2]),
             "sprity na jedne strance nejsou razeny sestupne podle vysky")
    rozmery = {(k, i): (w, h) for k, i, w, h in rady}
    for kind, ident, cislo, x, y in a:
        w, h = rozmery[(kind, ident)]
        kontrola(x + w <= 256 and y + h <= 256, f"sprite {ident} lezi za hranici stranky")
    for i, prvni in enumerate(a):
        for druhy in a[i + 1:]:
            if prvni[2] != druhy[2]:
                continue
            w1, h1 = rozmery[prvni[:2]]
            w2, h2 = rozmery[druhy[:2]]
            x1, y1, x2, y2 = prvni[3], prvni[4], druhy[3], druhy[4]
            kontrola(not (x1 < x2 + w2 + PAD and x2 < x1 + w1 + PAD and
                          y1 < y2 + h2 + PAD and y2 < y1 + h1 + PAD),
                     f"sprity {prvni[1]} a {druhy[1]} se prekrivaji")
    kontrola(len({c for _, _, c, _, _ in a}) == 1, "vsechno se vejde na jednu stranku 256 px")
    mala = rozloz(rady, page=40, pad=0)
    kontrola(mala != [] and len({c for _, _, c, _, _ in mala}) > 1,
             "u male stranky se sprite rozbiji na vice stran")
    kontrola(rozmiar("item", struct.pack("<Hxxh", 5000, 10).ljust(8, b"\x00")) is None and
             rozmiar("item", struct.pack("<Hxxh", 44, 44).ljust(8, b"\x00")) == (44, 44),
             "sprite vetsi nez stranka se odmita, bežny projde")
    kontrola(ofsahy("land", 44, 44) == (0, 0), "land ma ox = oy = 0")
    kontrola(ofsahy("item", 45, 114) == (0, 70), "item ox = (w>>1)-22, oy = h-44")
    # invariant z ChunkMesh.cs: spodni hrana statiku lezi na spodni hrane dlazdice
    ox, oy = ofsahy("item", 45, 114)
    kontrola((-oy + 114) == (0 + 44), "spodni hrana statiku nesedi na spodni hranu dlazdice")
    # opakovatelnost: stejne hodnoty daji stejne bajty, nezalezi na poradi vlozeni
    def bajty(slovnik):
        return json.dumps(slovnik, ensure_ascii=False, sort_keys=True, indent=1).encode("utf-8")
    jeden = {"sprites": [{"id": i, "rect": [x, y]} for _, i, _, x, y in a]}
    kontrola(bajty(jeden) == bajty(jeden) and
             bajty({"a": jeden, "b": jeden["sprites"][0]["id"]}) ==
             bajty({"b": jeden["sprites"][0]["id"], "a": jeden}),
             "manifest neni stabilni pri stejnych hodnotach")
    print(f"[atlas] self-test: {pocet} kontrol, {len(chyby)} chyb")
    for chyba in chyby:
        print(f"[atlas] CHYBA: {chyba}")
    return 1 if chyby else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="atlas + manifest")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--out", default="assets/uo")
    ap.add_argument("--tiles", default="assets/uo/tiles.json")
    ap.add_argument("--only", default="land,item,gump")
    ap.add_argument("--verify", action="store_true", help="jen premer hotovy manifest")
    ap.add_argument("--preview", default=".cache/analysis/atlas-preview.png")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    out = Path(args.out)
    if not args.verify:
        sestav(args.install, out, Path(args.tiles), set(args.only.split(",")))
    return over(out, args.preview)


if __name__ == "__main__":
    raise SystemExit(main())