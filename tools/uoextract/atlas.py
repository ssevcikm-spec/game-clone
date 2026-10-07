#!/usr/bin/env python3
"""atlas.py - shelf-pack do 2048x2048 + manifest.json (granule assets.atlas).

ROZSAH (MERENO 2026-10-05 na instalaci 1.25.35, ne odhadnuto):
  land = LAND TILE ID z mapy (0..16383), NE pole `texture` z tiledata.
         ⚠ OPRAVA 2026-10-07 (12. session): do 11. session tu stalo, ze land art
         je indexovany polem `texture` ("TexID") - a bylo to VYVRACENO merenim:
           * `render.chunk` kresli land s `art_id = land tile id` (ClassicUO
             `LandView.cs:96` `Arts.GetLand(Graphic)`, kde `Graphic` je id z mapy),
           * art[0] je grafika s textem "UNUSED", kdezto `texture[168] = 0` -
             kdyby platil TexID, kreslila by se voda (id 168) jako "UNUSED",
           * prumerna barva art[id] sedi na texmap[texture] u 76 druhů dlaždic,
             art[texture] jen u 2 (váženo počtem dlaždic 934 504 : 738),
           * v atlase stavěném podle TexID CHYBĚLO 512 land artů, které v archivu
             jsou - a to práve ty, které mapa používá (např. 77..100: písek, hlína
             a svahové dlaždice u pobřeží; uživatel to viděl jako "kde je svah,
             tam není tile").
         Mereni: `_analyza/vlna1-land-index.py` (+ montáž `vlna1-land-montaz.png`).
         Land ID s payloadem je 4 244 z 16 384; zbytek se do manifestu nedostane
         a je to v `report` (ne v tichu).
  item = staticky art z archivu: bere se CELY rozsah 0..65535 (art ID =
         tiledata id + 0x4000). ⚠ OPRAVA 2026-10-07 (12. session): do 11. session
         se vynechavaly arty s PRAZDNYM JMENEM v tiledata (36 222 z 65 536) -
         ale mapa je pouziva a klient je kresli (jmeno kresleni nepotrebuje).
         NamEReno (`_analyza/vlna6-statiky-bez-jmena.py`): 232 druhu statiku
         (14 199 zaznamu) ma art v archivu a prazdne jmeno; statiku, ktere by art
         v archivu nemely, je 0. Co v archivu opravdu neni, se pocita do `report`.
  gump = vsechny gumpy v gumpartLegacyMUL.uop.
  texmap = textury TERENU pro SVAHY (`texmaps.mul`, `tools/uoextract/texmaps.py`).
         UO kresli rovnou plochu land ARTEM a svah TEXMAPEM natazenym pres
         ctyrrohy dlazdice (ClassicUO `LandView.cs:58-96`, `Land.cs:96-161`) -
         bez toho zustava v miste prechodu vysky SEDA DIRA (vada uzivatele
         2026-10-07: "kde je svah, tam neni tile"). Klicem je `TexID` z tiledata
         (land pole `texture`); VODA (`TexID == 0 && Wet`) se kresli artem
         (ClassicUO `Land.cs:48`) a proto texmap 0 nema.
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
  python tools/uoextract/atlas.py --out assets/uo [--only land,item,gump,texmap]
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
from texmaps import MAX_TEXMAP, TexmapArchive  # noqa: E402

PAGE = 2048
PAD = 1                      # 1 px pruhledneho okraje: filtr v GPU by nasal souseda
# docs/03 §3.5.3 bod 1: 6 znamych art ID, ktera se maji poznat pohledem
KNOWN = ((3921, "item"), (3936, "item"), (5118, "item"),
         (7609, "item"), (2482, "item"), (3, "land"), (3, "texmap"))


def rozmiar(kind: str, payload: bytes | None) -> tuple[int, int] | None:
    """(sirka, vyska) z hlavicky payloadu - bez dekodovani pixelu (dvoupruchod).

    TVARY HLAVICE (kazdy format jinak - a tady se to uz jednou spletlo):
      item: [u32 flags][i16 width][i16 height]  -> "<Ihh" od offsetu 0
            (docs/03 §3.3.4; cte to stejne `art.py:176` pri dekodovani)
      gump: [u32 width][u32 height]             -> "<II" od offsetu 0
            (`gump.py:111`)
      land: vzdy LAND_SIZE x LAND_SIZE, hlavicka zadna (`art.py:162`)
    Namerено 2026-10-06: se SPRAVNYM offsetem se hlavicka == dekodovane
    rozmery u 39 516 z 39 516 item spritu, takze je pro sazeni verohodna.
    Pred opravou se u itemu cetlo "<Hxxh" (tedy `flags` jako sirka): 11 681
    z 11 685 spritu melo jinou sirku, nez se pak ulozilo -> prekryvy v atlase.

    Rozmery vetsi nez stranka se odmita: `rozloz` by je musel umistit mimo
    stranku a sprite by vysel z obrazku.
    """
    if payload is None or len(payload) < 8:
        return None
    if kind == "land":
        return (LAND_SIZE, LAND_SIZE) if len(payload) >= LAND_BYTES else None
    if kind == "texmap":
        # Delka rozhoduje o rozmeru: 0x2000 = 64x64, 0x8000 = 128x128
        # (`texmaps.py`, portovane z ClassicUO TexmapsLoader.cs:79).
        return (64, 64) if len(payload) == 0x2000 else (
            (128, 128) if len(payload) == 0x8000 else None)
    if kind == "item":
        _flags, w, h = struct.unpack_from("<Ihh", payload, 0)   # [u32][i16][i16]
    else:
        w, h = struct.unpack_from("<II", payload, 0)            # [u32][u32]
    return (w, h) if 0 < w <= PAGE and 0 < h <= PAGE else None


def ofsahy(kind: str, w: int, h: int) -> tuple[int, int]:
    """(ox, oy) = posun, ktery se odecte od baseX/baseY dlazdice (ChunkMesh.cs)."""
    if kind in ("land", "texmap"):
        return (0, 0)
    return ((w >> 1) - 22, h - 44)


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


def rozsah(tiles: dict) -> tuple[set, set, set]:
    """(land art id, item art id, texmap id) - vsechny prostore se berou CELE,
    rozhoduje archiv.

    LAND: art ID je LAND TILE ID z mapy (ne `texture` z tiledata) - viz hlavicka
    a `_analyza/vlna1-land-index.py`.
    ITEM: art ID je `tiledata id + 0x4000` (docs/03 §3.5.4) a bere se CELY
    rozsah 0..65535. Do 12. session se vynechavaly arty s PRAZDNYM JMENEM
    v tiledata (36 222 z 65 536) - jenze mapa je pouziva: namEReno
    (`_analyza/vlna6-statiky-bez-jmena.py`) 232 druhu statiku / 14 199 zaznamu
    ma art v archivu, ale prazdne jmeno - a klient kresli art podle ID, jmeno
    k tomu nepotrebuje. Statiku BEZ artu v archivu je 0, takze po teto oprave
    nema byt v mape zadna dira.
    TEXMAP: textura terenu pro SVAHY (`texmaps.py`); klic je `TexID` z tiledata
    (land pole `texture`), ktery kresleni bere z `world.tiledata.texture()`.
    Co v archivu NENI (payload chybi), preskoci `rozmiar()` a je to v `report`.
    """
    return (set(range(MAX_LAND)), set(range(0x10000)), set(range(MAX_TEXMAP)))


def sha256(cesta: Path) -> str:
    h = hashlib.sha256()
    with open(cesta, "rb") as f:
        for blok in iter(lambda: f.read(1 << 20), b""):
            h.update(blok)
    return h.hexdigest()


def rozbal(archiv, kind: str, ident: int):
    """Dekodovany sprite (w, h, pixely) nebo None."""
    if kind == "land":
        return archiv.land_art(ident)
    if kind == "texmap":
        return archiv.texmap(ident)
    return archiv.art(ident) if kind == "item" else archiv.gump(ident)


def sestav(install: str, out: Path, tiles_path: Path, only: set[str]) -> dict:
    """Zaradi vsechny pozadovane sprity do stranek a napise manifest.json."""
    from PIL import Image

    tiles = json.loads(tiles_path.read_text(encoding="utf-8"))
    land_ids, item_ids, texmap_ids = rozsah(tiles)
    art, gumpy = ArtArchive(install), GumpArchive(install)
    texmapy = TexmapArchive(install)
    report: dict[str, int] = {}
    sprites: list[dict] = []
    stranky: list[str] = []

    for kind in ("land", "item", "gump", "texmap"):
        if kind not in only:
            continue
        archiv = {"gump": gumpy, "texmap": texmapy}.get(kind, art)
        ids = (sorted(land_ids) if kind == "land" else sorted(item_ids) if kind == "item"
               else sorted(texmap_ids) if kind == "texmap"
               else [i for i in range(len(gumpy.entries) + 2048) if gumpy.payload(i) is not None])
        rady, chybi = [], 0
        for ident in ids:
            if kind == "land" and not 0 <= ident < MAX_LAND:
                chybi += 1                 # obrana: rozsah land je dany (viz `rozsah`)
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
    zdroje = [Path(install) / "artLegacyMUL.uop", Path(install) / "gumpartLegacyMUL.uop",
              Path(install) / "texmaps.mul", Path(install) / "texidx.mul", tiles_path]
    manifest = {
        "version": 1,
        "generator": "tools/uoextract/atlas.py",
        "page_size": PAGE,
        "pad": PAD,
        "source": {
            "install": str(install),
            "client_version": tiles.get("source", {}).get("install_version"),
            "sha256": {p.name: sha256(p) for p in zdroje if p.exists()},
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
    # UKLID OSIRELYCH STRANEK: novy beh muze potrebovat min stran nez predchozi
    # a stare PNG by v `atlas/` zustaly. Namerено 2026-10-06: po oprave
    # rozlozeni zustalo v adresari 198 souboru, ale manifest znal jen 67 -
    # 131 osirelych stranek (10,1 MB). Uklidi se jen to, co NENI v manifestu
    # a lezi v `atlas/`; nic jineho se nedotyka.
    # POZOR: u castecneho behu (`--only item`) by uklid smazal stranky ostatnich
    # druhu, ktere tento manifest nezna - proto se uklizi jen pri plnem behu.
    if set(only) >= {"land", "item", "gump", "texmap"}:
        platne = {Path(p["file"]).name for p in manifest["pages"]}
        uklizeno = 0
        for stara in (out / "atlas").glob("*.png"):
            if stara.name not in platne:
                stara.unlink()
                uklizeno += 1
        if uklizeno:
            print(f"[atlas] uklizeno osirelych stranek: {uklizeno}")
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


def _prekryvy(umisteni: list[tuple], rozmery: dict) -> list[tuple]:
    """Kontrola SAZENI v meritku: vraci seznam dvojic, ktere se prekryvaji.

    Prochazi stranky a police, ne vsechny dvojice - aby sla pouzit i na
    tisicich spritu (dvoupruchodova kontrola O(n^2) je na tom slepa, protoze
    se neda spustit).
    """
    from collections import defaultdict

    police: dict = defaultdict(list)
    for kind, ident, cislo, x, y in umisteni:
        police[(cislo, y)].append((x, kind, ident))
    kolize = []
    for klic, v in police.items():
        v.sort()
        for (x1, k1, i1), (x2, k2, i2) in zip(v, v[1:]):
            w1 = rozmery[(k1, i1)][0]
            if x1 + w1 > x2:
                kolize.append(((k1, i1), (k2, i2)))
    return kolize


def _mezery(umisteni: list[tuple], rozmery: dict) -> list[tuple]:
    """Mezery mezi sousedy na policce - kazda ma byt presne PAD.

    Proč zvlast: bez teto kontroly prosly mutace "konec police bez padu"
    a "konec stranky bez padu" (namerено 2026-10-06). Self-test tehdy overoval
    jen to, ze se sprity NEprekryvaji - ale ne to, ze maji mezi sebou
    predepsanou mezeru, ktera brani filtraci souseda v GPU.
    """
    from collections import defaultdict

    police: dict = defaultdict(list)
    for kind, ident, cislo, x, y in umisteni:
        police[(cislo, y)].append((x, kind, ident))
    spatne = []
    for klic, v in police.items():
        v.sort()
        for (x1, k1, i1), (x2, k2, i2) in zip(v, v[1:]):
            mezera = x2 - (x1 + rozmery[(k1, i1)][0])
            if mezera != PAD:
                spatne.append(((k1, i1), (k2, i2), mezera))
    return spatne


def _sada_v_meritku(nic: int = 0) -> list[tuple]:
    """Synteticka sada v meritku REALNEHO behu: 40 000 spritu, stranka 2048.

    Proč: puvodni self-test poustel kontrolu prekryvu na 6 spritech na strance
    256 px. Police se v takovem vstupu nikdy nezaplni a stranka se ani jednou
    neprekroci, takze kontrola nemela jak selhat - a 117 prekryvu proslo.
    Namerено 2026-10-06: 6 000 spritu da jen 19 stranek (algoritmus je efektivni),
    proto je vstup vetsi, aby test skutecne prosel prechodem na dalsi stranku.
    """
    import random

    rng = random.Random(20261006)
    vysky = [24, 44, 46, 60, 80, 108, 130, 177, 204, 256]
    sada = []
    for i in range(40000):
        kind = ("item", "gump", "land")[i % 3]
        h = rng.choice(vysky)
        w = rng.randint(10, 200)
        sada.append((kind, i, w, h))
    sada.append(("land", 99999, LAND_SIZE, LAND_SIZE))
    return sada


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
    kontrola(rozmiar("item", struct.pack("<Ihh", 0, 5000, 10).ljust(8, b"\x00")) is None and
             rozmiar("item", struct.pack("<Ihh", 0, 44, 44).ljust(8, b"\x00")) == (44, 44),
             "sprite vetsi nez stranka se odmita, bežny projde")
    kontrola(ofsahy("land", 44, 44) == (0, 0), "land ma ox = oy = 0")
    kontrola(ofsahy("item", 45, 114) == (0, 70), "item ox = (w>>1)-22, oy = h-44")
    # TEXMAP: o rozmeru rozhoduje DELKA zaznamu (64x64 = 0x2000, 128x128 = 0x8000)
    kontrola(rozmiar("texmap", b"\x00" * 0x2000) == (64, 64),
             "texmap: delka 0x2000 = 64x64")
    kontrola(rozmiar("texmap", b"\x00" * 0x8000) == (128, 128),
             "texmap: delka 0x8000 = 128x128")
    kontrola(rozmiar("texmap", b"\x00" * 0x1000) is None,
             "texmap: jina delka nez 0x2000/0x8000 se odmita")
    kontrola(ofsahy("texmap", 64, 64) == (0, 0), "texmap ma ox = oy = 0")

    # --- TVAR HLAVICE: presne offsety poli (tady byla vada, ktera udelala 117 prekryvu) ---
    # item: [u32 flags][i16 width][i16 height]. Kdo cte "<Hxxh", precte `flags`
    # jako sirku - a sazi podle jineho rozmeru, nez pak dekoduje.
    item_hlavicka = struct.pack("<Ihh", 0x00002000, 87, 62)
    kontrola(rozmiar("item", item_hlavicka) == (87, 62),
             "item: rozmiar neprecetl [u32 flags][i16 w][i16 h] (cte se spatnym offsetem?)")
    kontrola(rozmiar("item", struct.pack("<Ihh", 1464, 44, 44)) == (44, 44),
             "item: hodnota z pole flags se dostala do sirky (offsety hlavicky nesedi)")
    gump_hlavicka = struct.pack("<II", 640, 480)
    kontrola(rozmiar("gump", gump_hlavicka) == (640, 480),
             "gump: rozmiar neprecetl [u32 w][u32 h]")

    # --- SAZENI V MERITKU REALNEHO BEHU (6 000 spritu, stranka 2048) ---
    sada = _sada_v_meritku()
    rozmery_s = {(k, i): (w, h) for k, i, w, h in sada}
    velke = rozloz(sada)
    zpet = rozloz(list(reversed(sada)))
    kontrola(velke == zpet, "v meritku: rozloz zavisi na poradi vstupu")
    kolize = _prekryvy(velke, rozmery_s)
    kontrola(not kolize,
             f"v meritku: sprity se prekryvaji ({len(kolize)} kolizi, prvni {kolize[:3]})")
    mimo = [r for r in velke
            if r[3] + rozmery_s[r[:2]][0] > PAGE or r[4] + rozmery_s[r[:2]][1] > PAGE]
    kontrola(not mimo, f"v meritku: {len(mimo)} spritu lezi za hranici stranky")
    # mezera mezi sousedy MUSI byt PAD - bez teto kontroly prosly mutace,
    # ktere pad na konci police/stranky vynechaly (namerено 2026-10-06)
    mezery = _mezery(velke, rozmery_s)
    kontrola(not mezery,
             f"v meritku: {len(mezery)} sousedu nema mezeru {PAD} px (prvni {mezery[:3]})")
    # Mezera musi byt dodrzena i VE SMERU DOLU: sprite + PAD se jeste musi vejit
    # na stranku. Bez tohoto je pad jen na konci police, ne na konci stranky.
    za_okraj = [r for r in velke
                if r[3] + rozmery_s[r[:2]][0] + PAD > PAGE
                or r[4] + rozmery_s[r[:2]][1] + PAD > PAGE]
    kontrola(not za_okraj,
             f"v meritku: {len(za_okraj)} spritu nema za sebou PAD "
             "(lepi se na okraj stranky - filtr v GPU by nasal souseda)")
    kontrola(len(velke) == len(sada), "v meritku: ne vsechny sprity se umistily")
    policek = len({(r[2], r[4]) for r in velke})
    stran = len({r[2] for r in velke})
    # Kriterium ma byt o TOM, co test prokazuje: ze se opravdu prosel
    # prechodem na dalsi stranku (jinak by test obstal i s jednou strankou
    # a o chovani na hranici by netvrdil nic).
    kontrola(stran >= 20, f"v meritku: stran jen {stran} - test neprosel prechodem stranky")
    kontrola(policek >= 200, f"v meritku: policek jen {policek} - vstup nema meritko realneho behu")
    # Vsechny stranky krome POSLEDNI (ta muze byt castecna) musi byt zaplnene
    # do vetsiny vysky - jinak by na nich prekryvy nemely kde vzniknout.
    # Pozor na past: kdyz se "posledni" urci z dat, mutace, ktera prida dalsi
    # stranku, si ji sama oznaci za posledni a kontrole unikne.
    podle_stran = {}
    for kind, ident, cislo, x, y in velke:
        w, h = rozmery_s[(kind, ident)]
        podle_stran[cislo] = max(podle_stran.get(cislo, 0), y + h)
    nejvyssi = max(podle_stran)
    plne = [c for c, dno in podle_stran.items() if c != nejvyssi and dno < PAGE * 0.8]
    kontrola(not plne,
             f"v meritku: {len(plne)} stranek je zaplneno pod 80 % vysky "
             f"(nejnizsi dno {min((podle_stran[c] for c in plne), default=0)} px)")

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
    ap.add_argument("--only", default="land,item,gump,texmap")
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