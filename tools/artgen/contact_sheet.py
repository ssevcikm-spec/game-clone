# -*- coding: utf-8 -*-
"""contact_sheet.py - kontaktni list: VLASTNI art VEDLE PUVODNIHO (ZADANI-25 §3.4).

  python tools/artgen/contact_sheet.py                    # z hotovych manifestu
  python tools/artgen/contact_sheet.py --z-raw            # z renderu (pred zabalenim)
  python tools/artgen/contact_sheet.py --jen dagger       # jen jeden predmet

Sekce listu (kazda odpovida na jinou otazku - "je to ono?" se neda zmerit):
  1. PREDMETY  - vlastni vs UO ve STEJNEM meritku (x8) + vyznacena linka
                 kontaktu a stred dlazdice. Odpovida: sedi velikost a kotva?
  2. TEREN     - kosoctvercove dlazdice 3x3 vedle sebe (vlastni vs UO).
                 Odpovida: sedi tvar, smer svetla a sedi na sebe?
  3. POSTAVA   - 5 smeru x 8 framu vedle UO (stejne smery jako UO).
                 Odpovida: sedi orientace smeru a vyska postavy?
  4. SCENA     - vlastni art posazeny do hry vzorcem `core/iso.gd`
                 (`screen = ((x-y)*22, (x+y)*22) - offset`) na vlastni dlazdice.
                 Odpovida: sedi to dohromady?

POZOR: tenhle list je NA POHLED, ne brana. Co je na nem videt, se pise do
`MERENI.md` slovem - a cisla (velikosti, kotvy) hlida `pack_atlas.py --check`.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import artgen_common as ac
import uo_ref

HERE = Path(__file__).resolve().parent
OWN = Path("assets/own")
UO = Path("assets/uo")
POZADI = (30, 32, 38, 255)


def font(size: int):
    for p in (r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\arialbd.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


F = font(15)
F_M = font(13)


def popis(d: ImageDraw.ImageDraw, xy, text: str, f=None, barva=(225, 228, 235, 255)):
    d.text(xy, text, font=f or F, fill=barva)


# ---------------------------------------------------------------------------
# zdroje spritu
# ---------------------------------------------------------------------------
class Zdroj:
    """Prirezany sprite + jeho zaznam (jednotne pro UO i vlastni art)."""

    def __init__(self, obrazek: Image.Image, zaznam: dict):
        self.img = obrazek
        self.z = zaznam


def nacti_uo(kind: str, ident: int) -> Zdroj | None:
    m = uo_ref.nacti_manifest(UO / "manifest.json")
    z = uo_ref.zaznam(m, kind, ident)
    if z is None:
        return None
    return Zdroj(uo_ref.Stranky(UO).sprite(z), z)


def nacti_own(kind: str, ident: int) -> Zdroj | None:
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            img = Image.open(OWN / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
            return Zdroj(img, s)
    return None


def priprav_own_z_rawu() -> dict:
    """Vlastni sprity z renderu (bez manifestu) - pro ladeni pred zabalenim.

    Chybejici davka (napr. jeste nevyrenderovana postava) se preskoci a rekne se
    to: sekce, ktera nema z ceho, se vynecha - nikdy se nedoplni prazdnem.
    """
    import pack_atlas as pa
    out = {}
    for jmeno, fn, klic in (("teren", pa.davka_land, None), ("predmety", pa.davka_item, None),
                            ("postava", pa.davka_anim, None)):
        try:
            klice, sprity, _meta = fn()
        except SystemExit as e:
            print(f"[contact_sheet] {jmeno}: {e} - sekce se vynecha")
            continue
        for (k, ident), img in zip(klice, sprity):
            out[(k, ident)] = img
    return out


# ---------------------------------------------------------------------------
# sekce
# ---------------------------------------------------------------------------
def sekce_predmety(vyber: list[dict], zdroje: dict) -> Image.Image:
    """Vlastni vs UO ve STEJNEM meritku, zarovnane KOTVOU.

    Zarovnava se podle kotvy (`w//2`, `h-22`), ne podle stredu boxu - prave
    kotva rozhoduje, kam se sprite v hre sadi. Kdyby se boxy centrovally,
    rozdilna vyska boxu (UO nema pod obsahem zadnou rezervu) by posunula
    obrazek a "sedi to?" by se z listu nedalo poznat.
    """
    bunka_w, bunka_h = 170, 230
    kolik = 8
    w = bunka_w * 2 * len(vyber) + 20
    h = 44 + bunka_h
    p = Image.new("RGBA", (w, h), POZADI)
    d = ImageDraw.Draw(p)
    popis(d, (10, 8), "1) PREDMETY: puvodni UO (vlevo) vs VLASTNI (vpravo), x8; "
                      "cerveny krizek = kotva (w//2, h-22) = stred dlazdice")
    for i, spec in enumerate(vyber):
        for j, (jmeno, zdroj) in enumerate((("UO", zdroje["uo"].get(spec["name"])),
                                            ("vlastni", zdroje["own"].get(spec["name"])))):
            x0 = 10 + (i * 2 + j) * bunka_w
            popis(d, (x0 + 4, 30), f"{spec['name']} {jmeno}", F_M,
                  (180, 200, 255, 255) if j else (200, 200, 200, 255))
            if zdroj is None:
                popis(d, (x0 + 4, 60), "CHYBI", F_M, (255, 120, 120, 255))
                continue
            img = zdroj.img
            bb = img.split()[3].getbbox() or (0, 0, img.width, img.height)
            velky = img.resize((img.width * kolik, img.height * kolik), Image.NEAREST)
            # kotva spritu -> pevny bod v bunce (126 px od spodu, 85 px od leveho okraje)
            kx, ky = img.width // 2, img.height - ac.GROUND_PX
            px = x0 + 85 - kx * kolik
            py = 44 + bunka_h - 60 - (velky.height - ky * kolik)
            p.alpha_composite(velky, (px, py))
            cx, cy = px + kx * kolik, py + ky * kolik
            d.line([(px, cy), (px + velky.width, cy)], fill=(255, 80, 80, 200))
            d.line([(cx, py), (cx, py + velky.height)], fill=(255, 80, 80, 200))
            popis(d, (x0 + 4, 44 + bunka_h - 42),
                  f"box {img.width}x{img.height}  obsah {bb[2]-bb[0]}x{bb[3]-bb[1]}", F_M)
            popis(d, (x0 + 4, 44 + bunka_h - 26),
                  f"ox={zdroj.z['ox']} oy={zdroj.z['oy']}  (UO vzorec)", F_M,
                  (160, 170, 180, 255))
    return p


def iso_patch(zdroj, dlazdice: int = 3, kolik: int = 3, popisek: str = "") -> Image.Image:
    """Dlazdice posazene presne vzorcem hry (`core/iso.gd`)."""
    krok = ac.TILE // 2
    w = (dlazdice + 1) * ac.TILE
    h = (dlazdice + 1) * ac.TILE + ac.TILE
    p = Image.new("RGBA", (w, h), POZADI)
    for y in range(dlazdice):
        for x in range(dlazdice):
            sx = (x - y) * krok + dlazdice * krok
            sy = (x + y) * krok + ac.TILE
            if zdroj is not None:
                p.alpha_composite(zdroj.img, (sx - zdroj.z["ox"], sy - zdroj.z["oy"]))
    return p.resize((w * kolik, h * kolik), Image.NEAREST)


def sekce_teren(zdroje: dict, kolik: int = 3) -> Image.Image:
    radky = []
    for spec in ac.LAND:
        uo, own = zdroje["uo"].get(spec["name"]), zdroje["own"].get(spec["name"])
        radky.append((spec["name"], uo, own))
    bunka = iso_patch(None, 3, kolik)
    p = Image.new("RGBA", (bunka.width * 2 + 30, bunka.height * len(radky) + 150), POZADI)
    d = ImageDraw.Draw(p)
    popis(d, (10, 8), "2) TEREN: kosoctvercove dlazdice 3x3 (vlevo UO, vpravo vlastni)")
    y = 36
    for jmeno, uo, own in radky:
        for i, (kdo, zdroj) in enumerate((("UO", uo), ("vlastni", own))):
            if zdroj is None:
                continue
            patch = iso_patch(zdroj, 3, kolik)
            p.alpha_composite(patch, (10 + i * (bunka.width + 10), y))
            popis(d, (10 + i * (bunka.width + 10) + 4, y + 2), f"{jmeno} {kdo}", F_M,
                  (180, 200, 255, 255) if i else (200, 200, 200, 255))
        y += bunka.height + 8
    return p


def sekce_postava(zdroje: dict, kolik: int = 2) -> Image.Image:
    """5 smeru x 8 framu vlastni vs UO (stejne indexy smeru)."""
    uo_sheets = {}
    am = UO / "anim" / "anim-sheets.json"
    if am.exists():
        data = json.loads(am.read_text(encoding="utf-8"))
        for k, v in data["sprites"].items():
            telo, akce, smer = (int(x) for x in k.split("/"))
            if telo == ac.CHAR["body"] and akce == ac.CHAR["action_walk"]:
                uo_sheets[smer] = (UO / "anim" / v["file"], v)
    radky = []
    for d in range(ac.CHAR["dirs"]):
        framy = [zdroje["own"].get((d, f)) for f in range(ac.CHAR["frames"])]
        if any(f is None for f in framy):
            continue                              # nekompletni sada se nevykresluje
        radky.append(("vlastni", d, framy))
        if d in uo_sheets:
            cesta, v = uo_sheets[d]
            img = Image.open(cesta).convert("RGBA")
            f2 = [img.crop(tuple(f["rect"])) for f in v["frames"][:ac.CHAR["frames"]]]
            radky.append(("UO", d, [Zdroj(i, {"ox": 0, "oy": 0}) for i in f2]))
    if not radky:
        return None
    vyska = sum(max(f.img.height for f in framy if f) * kolik + 24 for _k, _d, framy in radky)
    sirka = max(sum(f.img.width * kolik + 2 for f in framy if f) + 90 for _k, _d, framy in radky)
    p = Image.new("RGBA", (sirka + 20, vyska + 50), POZADI)
    d = ImageDraw.Draw(p)
    popis(d, (10, 8), "3) POSTAVA: 5 smeru x 8 framu (UO ma 10 framu, bere se 8) - "
                      "vlastni vs UO pro stejny index smeru")
    y = 40
    zaklad = None
    for kdo, smer, framy in radky:
        vyska_r = max(f.img.height for f in framy if f) * kolik
        zaklad = y + vyska_r
        x = 80
        for f in framy:
            if f is None:
                continue
            velky = f.img.resize((f.img.width * kolik, f.img.height * kolik), Image.NEAREST)
            p.alpha_composite(velky, (x, zaklad - velky.height))
            x += velky.width + 2
        popis(d, (8, zaklad - 12), f"{kdo} smer {smer}", F_M,
              (180, 200, 255, 255) if kdo == "vlastni" else (200, 200, 200, 255))
        # linka zeme (kontakt) - u vlastniho artu je 22 px nad spodni hranou
        if kdo == "vlastni" and framy and framy[0] is not None:
            d.line([(80, zaklad - ac.GROUND_PX * kolik), (x, zaklad - ac.GROUND_PX * kolik)],
                   fill=(255, 80, 80, 160))
        y += vyska_r + 24
    return p


def sekce_scena(zdroje: dict, kolik: int = 3) -> Image.Image:
    """Vlastni art ve hre: dlazdice + predmety + postava, vzorcem `core/iso.gd`.

    Klicovani: dlazdice a predmety jsou ve `zdroje` pod JMENEM (grass, dagger, ...),
    postava pod (smer, frame) - stejne v obou režimech (manifest i --z-raw).
    """
    krok = ac.TILE // 2
    nx, ny = 4, 4
    w = (nx + ny) * krok
    h = (nx + ny) * krok + ac.TILE * 2
    p = Image.new("RGBA", (w, h), (18, 20, 24, 255))
    trava = zdroje["own"].get(ac.LAND[0]["name"])
    cesta = zdroje["own"].get(ac.LAND[1]["name"])

    def pozice(x, y):
        return ((x - y) * krok + ny * krok, (x + y) * krok + ac.TILE)

    for y in range(ny):
        for x in range(nx):
            zdroj = cesta if (y == 1 and x >= 1) else trava
            if zdroj is None:
                continue
            sx, sy = pozice(x, y)
            p.alpha_composite(zdroj.img, (sx - zdroj.z["ox"], sy - zdroj.z["oy"]))
    # predmety na dlazdice (kotva se odcita jako ve hre)
    poloha = [(1, 2, "dagger"), (3, 1, "pickaxe"), (2, 2, "ore"), (3, 2, "ingot")]
    for x, y, jmeno in poloha:
        zdroj = zdroje["own"].get(jmeno)
        if zdroj is None:
            continue
        sx, sy = pozice(x, y)
        p.alpha_composite(zdroj.img, (sx - zdroj.z["ox"], sy - zdroj.z["oy"]))
    # postava (smer 0 = celni) stoji na dlazdici (2, 3)
    # ⚠ POZOR: postava je ve `zdroje` klicovana (smer, frame), NE ("anim", id) -
    # kdyz se klic splete, sekce se VYTVORI BEZ POSTAVY a nic nehlasí (presne to
    # se stalo 2026-10-10 a prislo se na to jen pohledem na scenu).
    postava = zdroje["own"].get((0, 0))
    if postava is None:
        raise SystemExit("contact_sheet: v sekci SCENA chybi postava (klic (0,0)) - "
                         "scena bez postavy nema co overovat")
    if postava is not None:
        sx, sy = pozice(2, 3)
        p.alpha_composite(postava.img, (sx - postava.z["ox"], sy - postava.z["oy"]))
    d = ImageDraw.Draw(p)
    popis(d, (6, 6), "4) SCENA: vlastni art vzorcem hry (screen=(x-y,y+x)*22 - offset)",
          F_M, (225, 228, 235, 255))
    return p.resize((p.width * kolik, p.height * kolik), Image.NEAREST)


# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="kontaktni list vlastniho artu")
    ap.add_argument("--out", default="tools/artgen/_kontaktni-list.png")
    ap.add_argument("--z-raw", action="store_true", help="brat sprity z renderu (bez manifestu)")
    ap.add_argument("--jen", default="", help="jen jeden predmet (dagger/pickaxe/ore/ingot)")
    ap.add_argument("--zoom", type=int, default=8)
    a = ap.parse_args()

    if a.z_raw:
        raw = priprav_own_z_rawu()
        own = {(k, i): Zdroj(img, {"ox": ac.ofsahy(k, img.width, img.height)[0],
                                   "oy": ac.ofsahy(k, img.width, img.height)[1]})
               for (k, i), img in raw.items()}
        # preindexuj na jmena jako u manifestu (land/item) a (dir, frame) u postavy
        prejmenovane = {}
        for spec in ac.LAND:
            if ("land", spec["uo_id"]) in own:
                prejmenovane[spec["name"]] = own[("land", spec["uo_id"])]
        for spec in ac.ITEMS:
            if ("item", spec["uo_id"]) in own:
                prejmenovane[spec["name"]] = own[("item", spec["uo_id"])]
        for (k, i), z in own.items():
            if k == "anim":
                _b, _a, d, f = ac.anim_parts(i)
                prejmenovane[(d, f)] = z
        own = prejmenovane
    else:
        def nacti(kind, ident):
            return nacti_own(kind, ident)

        own = {}
        for spec in ac.LAND:
            own[spec["name"]] = nacti("land", spec["uo_id"])
        for spec in ac.ITEMS:
            own[spec["name"]] = nacti("item", spec["uo_id"])
        for d in range(ac.CHAR["dirs"]):
            for f in range(ac.CHAR["frames"]):
                own[(d, f)] = nacti("anim", ac.anim_id(d, f))

    uo = {}
    for spec in ac.LAND:
        uo[spec["name"]] = nacti_uo("land", spec["uo_id"])
    for spec in ac.ITEMS:
        uo[spec["name"]] = nacti_uo("item", spec["uo_id"])
    zdroje = {"uo": uo, "own": own}

    vyber = [s for s in ac.ITEMS if not a.jen or s["name"] == a.jen]
    if a.jen == "scena":
        # jen scenu a vetsi - na kontrolu usazeni predmetu na dlazdice
        out = sekce_scena(zdroje, kolik=5)
        out.convert("RGB").save(a.out)
        print(f"[contact_sheet] {a.out} ({out.width}x{out.height}), sekce: scena")
        return 0
    if not vyber:
        raise SystemExit(f"predmet {a.jen} neni v artgen_common.ITEMS")
    sekce = [sekce_predmety(vyber, zdroje), sekce_teren(zdroje)]
    postava = sekce_postava(zdroje)
    if postava is not None:
        sekce.append(postava)
    if all(zdroje["own"].get(t["name"]) for t in ac.LAND):
        sekce.append(sekce_scena(zdroje))

    sirka = max(s.width for s in sekce) + 20
    vyska = sum(s.height for s in sekce) + 12 * (len(sekce) + 1)
    out = Image.new("RGBA", (sirka, vyska), (16, 17, 20, 255))
    y = 12
    for s in sekce:
        out.alpha_composite(s, (10, y))
        y += s.height + 12
    out.convert("RGB").save(a.out)
    print(f"[contact_sheet] {a.out} ({out.width}x{out.height}), sekci {len(sekce)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
