# -*- coding: utf-8 -*-
"""srovnani_1x_2x.py - srovnavaci list 1x vs 2x (ZADANI-25 §9 odst. 3).

  python tools/artgen/srovnani_1x_2x.py
      -> tools/artgen/_srovnani-1x-2x.png

ODPOVIDA NA JEDNU OTazku: "ma smysl prejit na 2x geometrii?" - a odpovida
obrazkem, ne dojmem. Tri sloupce ve stejnem poradi ve vsech sekcich:

    puvodni UO  |  nas 1x  |  nas 2x (slunce + AO + kontaktni stin)

Dve rady pro kazdou sekci:
  * "STEJNE MERITKO" - 2x sprite se PRED kreslenim zmensi presne na polovinu
    (`postprocess.zmensi`, tedy RGB a alfa ZVLAST - `PIL.Image.resize` na RGBA
    rozsype barvu tam, kde je alfa ~0), takze vsechny tri sloupce maji stejnou
    velikost pixelu. Odpovida: "vypada to lip, kdyz je to stejne velke?"
  * "VYREZ 1:1" - kazdy sloupec v NATIVNICH pixelech (2x se nezmensuje).
    Odpovida: "co to vyssi rozliseni vubec prinasi?"

Zarovnava se STRED DLAZDICE, ne stred boxu: `to_screen` vraci horni vrchol
diamantu dlazdice (`render/chunk_renderer.gd:451-457`) a sprite se kresli na
`to_screen - (ox,oy)`, takze stred dlazdice je v sprite na `(w//2, h-GROUND_PX)`
- u UO, u 1x i u 2x (stejny vzorec, jen 22 -> 44 px). Kdyby se boxy centrovally,
rozdilna vyska boxu by posunula obrazek a "sedi to?" by se z listu nedalo poznat.

POZOR: tenhle list je NA POHLED, ne brana (stejne jako `contact_sheet.py`).
Cisla (kotvy, masky, pomer 2x/1x, existence stinu) hlida
`pack_atlas_2x.py --check`.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import artgen_common as ac1
import artgen_common_2x as ac2
import postprocess as pp
import uo_ref

HERE = Path(__file__).resolve().parent
OWN1X = Path("assets/own")
OWN2X = Path("assets/own2x")
UO = Path("assets/uo")

# ⚠ PODKLAD JE SVETLY, a je to MERENE ROZHODNUTI: UO telo 400 je SEDE
# (prumer obsahu (115,115,114) - je to "naha" vrstva, ktera se v UO barvi hue).
# Na sedem podkladu (150,150,150) splynulo a v listu vypadalo jako duch;
# na svetlem (198,200,205) je videt a zaroven je na nem videt polopruhledny
# kontaktni stin (cerny s alfou do 118/255).
POZADI = (198, 200, 205, 255)
RAM = (24, 26, 32, 255)
TITULEK = (255, 214, 120, 255)
POPIS = (236, 238, 244, 255)
POPIS2 = (186, 192, 204, 255)
POPIS_TMAVY = (40, 44, 52, 255)
OBRYS_DLAZDICE = (40, 44, 52, 150)
KRIZ = (220, 30, 30, 190)


def font(size: int, tlusty: bool = False):
    for p in ((r"C:\Windows\Fonts\arialbd.ttf" if tlusty else r"C:\Windows\Fonts\arial.ttf"),
              r"C:\Windows\Fonts\arial.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


F_H1 = font(28, True)
F_H2 = font(19, True)
F = font(15)
F_M = font(13)
F_S = font(12)


# ---------------------------------------------------------------------------
# zdroje
# ---------------------------------------------------------------------------
class Zdroj:
    """Sprite + kde je v nem STRED DLAZDICE (v pixelech spritu)."""

    def __init__(self, img: Image.Image, ax: float, ay: float):
        self.img = img
        self.ax = ax
        self.ay = ay

    def zmenseny(self, r: float) -> "Zdroj":
        """Zmenseni na `r` - pres `postprocess.zmensi` (RGB a alfa ZVLAST)."""
        if r == 1.0:
            return self
        nova = pp.zmensi(self.img, (max(1, round(self.img.width * r)),
                                    max(1, round(self.img.height * r))))
        return Zdroj(nova, self.ax * r, self.ay * r)


def _stranky(zaklad: Path, manifest: dict) -> dict:
    return {p["file"]: Image.open(zaklad / p["file"]).convert("RGBA")
            for p in manifest["pages"]}


def _vyrezej(manifest, stranky, kind, ident):
    for s in manifest["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return stranky[s["page"]].crop(tuple(s["rect"]))
    return None


class Sada:
    """Tri zdroje tehoz spritu: UO, 1x, 2x - s pozici stredu dlazdice."""

    def __init__(self) -> None:
        self.m1 = json.loads((OWN1X / "manifest.json").read_text(encoding="utf-8"))
        self.m2 = json.loads((OWN2X / "manifest.json").read_text(encoding="utf-8"))
        self.p1 = _stranky(OWN1X, self.m1)
        self.p2 = _stranky(OWN2X, self.m2)

    def item(self, uo_id: int) -> dict:
        out = {}
        m_uo = uo_ref.nacti_manifest(UO / "manifest.json")
        z = uo_ref.zaznam(m_uo, "item", uo_id)
        if z is not None:
            img = uo_ref.Stranky(UO).sprite(z)
            out["uo"] = Zdroj(img, img.width // 2, img.height - ac1.GROUND_PX)
        img = _vyrezej(self.m1, self.p1, "item", uo_id)
        if img is not None:
            out["1x"] = Zdroj(img, img.width // 2, img.height - ac1.GROUND_PX)
        img = _vyrezej(self.m2, self.p2, "item", uo_id)
        if img is not None:
            out["2x"] = Zdroj(img, img.width // 2, img.height - ac2.GROUND_PX)
        return out

    def anim(self, frame: int, smer: int = 0) -> dict:
        out = {}
        d = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
        v = d["sprites"].get(f"{ac1.CHAR['body']}/{ac1.CHAR['action_walk']}/{smer}")
        if v and frame < len(v["frames"]):
            fr = v["frames"][frame]
            img = Image.open(UO / "anim" / v["file"]).convert("RGBA").crop(tuple(fr["rect"]))
            out["uo"] = Zdroj(img, fr["cx"], fr["cy"] + fr["h"])
        img = _vyrezej(self.m1, self.p1, "anim", ac1.anim_id(smer, frame))
        if img is not None:
            out["1x"] = Zdroj(img, img.width // 2, img.height - ac1.GROUND_PX)
        img = _vyrezej(self.m2, self.p2, "anim", ac2.anim_id(smer, frame))
        if img is not None:
            out["2x"] = Zdroj(img, img.width // 2, img.height - ac2.GROUND_PX)
        return out


# ---------------------------------------------------------------------------
# kresleni
# ---------------------------------------------------------------------------
VZDUCH_VRCH = 26          # px nad spritem v bunce (na popisek)


def bunka(z: Zdroj, sirka: int, vyska: int, zoom: int, dilace: int,
          kotva: tuple[int, int], popisek: str) -> Image.Image:
    """Bunka: sprite zarovnany STREDEM DLAZDICE (v `kotva`) + obrys dlazdice.

    ⚠ Kotva se NEPOCITA jako "vyska - 34": NAMERENO 2026-10-10, ze u spritu,
    jehoz kontakt je blizko SPODKU boxu (2x dyka: 25 px nad spodkem z 69), se
    sprite orezal o spodni hranu bunky. Kotva se proto predava ZMERENA
    (`rada_skupin` ji pocita z `ax`/`ay` vsech framu skupiny).
    """
    b = Image.new("RGBA", (sirka, vyska), POZADI)
    d = ImageDraw.Draw(b)
    if z is not None:
        velky = z.img.resize((z.img.width * zoom, z.img.height * zoom), Image.NEAREST)
        b.alpha_composite(velky, (int(round(kotva[0] - z.ax * zoom)),
                                  int(round(kotva[1] - z.ay * zoom))))
    if dilace:
        r = dilace * zoom / 2.0
        d.polygon([(kotva[0], kotva[1] - r), (kotva[0] + r, kotva[1]),
                   (kotva[0], kotva[1] + r), (kotva[0] - r, kotva[1])],
                  outline=OBRYS_DLAZDICE)
    d.line([(kotva[0] - 8, kotva[1]), (kotva[0] + 8, kotva[1])], fill=KRIZ)
    d.line([(kotva[0], kotva[1] - 8), (kotva[0], kotva[1] + 8)], fill=KRIZ)
    d.text((5, 4), popisek, font=F_S, fill=POPIS_TMAVY)
    if z is not None:
        d.text((5, 18), f"{z.img.width}x{z.img.height}", font=F_S, fill=POPIS_TMAVY)
    return b


def _miry(skupina: list[Zdroj], zoom: int, dilace: int) -> dict:
    """Zmeri skupinu: kolik px je POTREBA vlevo/vpravo/nad/pod kotvou."""
    z = [x for x in skupina if x is not None]
    vlevo = max((x.ax * zoom for x in z), default=20)
    vpravo = max(((x.img.width - x.ax) * zoom for x in z), default=20)
    nad = max((x.ay * zoom for x in z), default=20)
    pod = max(((x.img.height - x.ay) * zoom for x in z), default=20)
    r = dilace * zoom / 2.0 if dilace else 0.0
    return {"vlevo": vlevo, "vpravo": vpravo, "nad": nad, "pod": pod, "r": r,
            "sirka": int(max(vlevo + vpravo + 16, 2 * r + 16)),
            "kotva_x": int(max(vlevo, r) + 8),
            "vyska": int(VZDUCH_VRCH + max(nad, r) + max(pod, r) + 34),
            "kotva_y": int(VZDUCH_VRCH + max(nad, r))}


def rada_skupin(skupiny: list[list[Zdroj]], zoom: int, popisky_skupin: list[str],
                popisky_bunek: list[list[str]], dilace: list[int]) -> Image.Image:
    """Rada skupin: kazda skupina = jeden zdroj (UO/1x/2x), vnitr = framy."""
    miry = [_miry(s, zoom, dilace[j]) for j, s in enumerate(skupiny)]
    vyska = max(m["vyska"] for m in miry)
    sirka = 132 + sum(m["sirka"] * len(skupiny[j]) for j, m in enumerate(miry))
    p = Image.new("RGBA", (sirka, vyska + 30), RAM)
    d = ImageDraw.Draw(p)
    x = 132
    for j, popisek in enumerate(popisky_skupin):
        d.text((x + 6, 8), popisek, font=F_M,
               fill=(150, 190, 255, 255) if j == 2 else POPIS)
        x += miry[j]["sirka"] * len(skupiny[j])
    x = 132
    for j, skupina in enumerate(skupiny):
        m = miry[j]
        for i, z in enumerate(skupina):
            pop = popisky_bunek[j][i] if popisky_bunek else ""
            p.alpha_composite(bunka(z, m["sirka"], vyska, zoom, dilace[j],
                                    (m["kotva_x"], m["kotva_y"]), pop), (x, 30))
            x += m["sirka"]
    return p


def nadpis(text: str, sirka: int, f=None, barva=TITULEK) -> Image.Image:
    f = f or F_H2
    p = Image.new("RGBA", (sirka, f.size + 14), RAM)
    ImageDraw.Draw(p).text((8, 5), text, font=f, fill=barva)
    return p


def hlavicka(sirka: int) -> Image.Image:
    radky = [
        ("SROVNANI 1x vs 2x - vlastni art (ZADANI-25 §9)", F_H1, TITULEK),
        ("Sloupce: puvodni UO sprite | nas 1x | nas 2x (jedno smerove slunce + "
         "jemný ambient occlusion + kontaktni stin pod objektem).", F, POPIS),
        ("Rada A = STEJNE MERITKO: 2x je pred kreslenim zmenseno presne na polovinu "
         "(postprocess.zmensi - RGB a alfa zvlast, jinak vzniknou cerne linky).",
         F, POPIS2),
        ("Rada B = VYREZ 1:1: kazdy sloupec v NATIVNICH pixelech, 2x se nezmensuje "
         "-> je videt, co vyssi rozliseni prinasi.", F, POPIS2),
        ("Cerveny krizek = STRED DLAZDICE (tam sedi kontakt); obrys = dlazdice 44 px "
         "(UO, 1x) / 88 px (2x). Podklad je svetly schvalne - UO telo 400 je sede "
         "(115,115,114).", F_M, POPIS2),
    ]
    vyska = sum(f.size + 10 for _t, f, _b in radky) + 14
    p = Image.new("RGBA", (sirka, vyska), RAM)
    d = ImageDraw.Draw(p)
    y = 7
    for t, f, b in radky:
        d.text((10, y), t, font=f, fill=b)
        y += f.size + 10
    return p


def ostrost(img: Image.Image):
    """Prumer |Laplace| ALFY na hranici obsahu (vyssí = ostřejsi hrana).

    Je to jediné číslo, které na listu vysvětluje, proč 2×/2 vypadá měkčeji:
    zmenšení na polovinu vezme víc ostrosti, než kolik jí 2× přinese.
    """
    import numpy as np
    a = np.asarray(img.split()[3], dtype=np.float32) / 255.0
    if a.max() <= 0:
        return None
    lap = np.abs(4 * a[1:-1, 1:-1] - a[:-2, 1:-1] - a[2:, 1:-1]
                 - a[1:-1, :-2] - a[1:-1, 2:])
    hrana = lap > 1e-6
    return round(float(lap[hrana].mean()), 3) if hrana.any() else 0.0


def stin_px(img: Image.Image) -> int:
    """Viditelné polopruhledné pixely spritu = kontaktni stin."""
    import numpy as np
    a = np.asarray(img)[:, :, 3]
    return int(((a > 0) & (a < 200)).sum())


def mereni_text(dodatky: list[str] = None) -> list[str]:
    """Namereny text k listu - cisla z manifestu (ne od oka)."""
    out = []
    m1 = json.loads((OWN1X / "manifest.json").read_text(encoding="utf-8"))
    m2 = json.loads((OWN2X / "manifest.json").read_text(encoding="utf-8"))
    r1, r2 = m1["report"], m2["report"]
    s1 = next(s for s in m1["sprites"] if s["kind"] == "item")
    s2 = next(s for s in m2["sprites"] if s["kind"] == "item")
    o1 = r1["item_obsah_proti_UO"]["dagger"]
    out.append(f"dyka: UO obsah {o1['uo'][0]}x{o1['uo'][1]} px v boxu 22x26  |  "
               f"1x obsah {o1['nase'][0]}x{o1['nase'][1]} px v boxu {s1['w']}x{s1['h']}  |  "
               f"2x obsah {r2['item_obsah_sirka_px'][str(s2['id'])]}x"
               f"{r2['item_obsah_vyska_px'][str(s2['id'])]} px v boxu {s2['w']}x{s2['h']}")
    a1 = next(s for s in m1["sprites"] if s["kind"] == "anim")
    a2 = next(s for s in m2["sprites"] if s["kind"] == "anim")
    key2 = str(a2["id"])
    out.append(f"postava: 1x box {a1['w']}x{a1['h']} (obsah 60 px vysoký)  |  "
               f"2x box {a2['w']}x{a2['h']} (obsah {r2['anim_obsah_vyska_px'][key2]} px)  "
               f"-> pomer obsahu {r2['anim_obsah_vyska_px'][key2] / 60.0:.2f}x")
    out.append(f"2x kontaktni stin: dyka {r2['item_stin_px_min']} px, postava "
               f"{r2['anim_stin_px_min']} px (max krytí "
               f"{max(r2['item_stin_max_alfa'], r2['anim_stin_max_alfa'])}/255); "
               f"1 jednotka = {r2['item_px_na_jednotku'][0]} px (dyka) / "
               f"{r2['anim_px_na_jednotku'][0]} px (postava) - sprite se normalizuje "
               f"na obsah UO, ne na pevne meritko")
    out.append(f"2x kotva: ox=(w>>1)-44, oy=h-88 (overeno u {len(m2['sprites'])}/"
               f"{len(m2['sprites'])} spritu); 1x kotva ox=(w>>1)-22, oy=h-44")
    out.extend(dodatky or [])
    return out


# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description="srovnavaci list 1x vs 2x")
    ap.add_argument("--out", default="tools/artgen/_srovnani-1x-2x.png")
    ap.add_argument("--zoom-item", type=int, default=5)
    ap.add_argument("--zoom-char", type=int, default=3)
    a = ap.parse_args()

    sada = Sada()
    klic = ("uo", "1x", "2x")
    jmena = ("puvodni UO", "nas 1x", "nas 2x (slunce + AO + stin)")

    def tri(fn, popis: str) -> list[Zdroj]:
        z = fn()
        chybi = [k for k in klic if k not in z]
        if chybi:
            raise SystemExit(f"{popis}: chybi zdroj {chybi} (je {sorted(z)})")
        return [z[k] for k in klic]

    def skupiny(indexy, fn, popis: str, zmensit_2x: bool) -> list[list[Zdroj]]:
        """Vrati [UO framy, 1x framy, 2x framy]; u `zmensit_2x` je 2x na polovine."""
        zdroje = [tri(lambda i=i: fn(i), f"{popis} {i}") for i in indexy]
        po_slozkach = [list(g) for g in zip(*zdroje)]
        if zmensit_2x:
            # Zmensuje se CELA treti skupina (2x), ne "vsechno od tretiho prvku":
            # `po_slozkach` je po ZDROJICH (UO | 1x | 2x), kazda skupina ma vsechny
            # framy. Prvni verze psala `g[:2] + [g[2].zmenseny(0.5)]`, coz
            # (a) u 8 framu skupinu TISE ZKRATILO na 3 a (b) u 2x skupiny
            # zmensilo jen treti frame - na liste pak byly f0 a f1 dvakrat tak
            # velke nez f2..f7. Obe vady byly videt jen POHLEDEM na list.
            po_slozkach = [po_slozkach[0], po_slozkach[1],
                           [x.zmenseny(0.5) for x in po_slozkach[2]]]
        return po_slozkach

    tabulky: list[Image.Image] = []
    # --- sekce A: dyka ------------------------------------------------------
    dyka = sada.item(ac2.ITEMS[0]["uo_id"])
    A1 = [[dyka["uo"]], [dyka["1x"]], [dyka["2x"].zmenseny(0.5)]]
    A2 = [[dyka["uo"]], [dyka["1x"]], [dyka["2x"]]]
    tabulky.append(nadpis("SEKCE A - DYKA (item 3921, lezi na zemi)",
                          max(700, 132 + 3 * 8 * 70)))
    tabulky.append(nadpis("A1) STEJNE MERITKO - 2x zmenseno na polovinu, "
                          "vsechny tri sloupce maji stejnou velikost pixelu",
                          1200, F_M))
    tabulky.append(rada_skupin(A1, a.zoom_item, list(jmena),
                               [["UO"], ["1x"], ["2x/2"]], [44, 44, 44]))
    tabulky.append(nadpis("A2) VYREZ 1:1 - NATIVNI pixely: 2x sloupec je proto 2x "
                          "vetsi (tak vypada dlazdice 88 px proti 44 px)",
                          1200, F_M))
    tabulky.append(rada_skupin(A2, a.zoom_item, list(jmena),
                               [["UO 1:1"], ["1x 1:1"], ["2x 1:1"]], [44, 44, 88]))

    # --- sekce B: postava ---------------------------------------------------
    framy = list(range(ac2.CHAR["frames"]))
    B1 = skupiny(framy, sada.anim, "anim", zmensit_2x=True)
    tabulky.append(nadpis("SEKCE B - POSTAVA (telo 400, akce walk, smer 0, 8 framu)",
                          1200))
    tabulky.append(nadpis("B1) STEJNE MERITKO - 2x zmenseno na polovinu", 1200, F_M))
    tabulky.append(rada_skupin(
        B1, a.zoom_char, [f"{j} - framy 0..7" for j in jmena],
        [[f"f{i}" for i in framy] for _ in klic], [0, 0, 0]))
    vyber = (0, 2, 4)
    B2 = skupiny(vyber, sada.anim, "anim", zmensit_2x=False)
    tabulky.append(nadpis("B2) VYREZ 1:1 - framy 0, 2, 4 v NATIVNICH pixelech",
                          1200, F_M))
    tabulky.append(rada_skupin(
        B2, a.zoom_char, [f"{j} - framy {list(vyber)}" for j in jmena],
        [[f"f{i} 1:1" for i in vyber] for _ in klic], [44, 44, 88]))

    # --- slozit -------------------------------------------------------------
    sirka = max(t.width for t in tabulky) + 20
    hlav = hlavicka(sirka)
    dodatky = []
    for jmeno, trojice in (("dyka", [dyka["uo"], dyka["1x"], dyka["2x"].zmenseny(0.5),
                                     dyka["2x"]]),
                           ("postava f0", [B1[0][0], B1[1][0], B1[2][0],
                                           sada.anim(0)["2x"]])):
        ost = [ostrost(z.img) for z in trojice]
        dodatky.append(
            f"{jmeno}: ostrost hrany (prumer |Laplace| alfy, vyssi = ostřejsi): "
            f"UO {ost[0]} | 1x {ost[1]} | 2x zmensene na 1x {ost[2]} | 2x natívne {ost[3]}"
            f"  -> 2x ve stejnem meritku je MEKCÍ, ne ostřejsi")
    dodatky.append(f"2x kontaktni stin VIDITELNY ve sprite: dyka {stin_px(dyka['2x'].img)} px, "
                   f"postava {stin_px(sada.anim(0)['2x'].img)} px (polopruhledne pixely; "
                   f"zvysok vrstvy stinu je pod objektem)")
    popisky = mereni_text(dodatky)
    vyska = hlav.height + sum(t.height + 8 for t in tabulky) + 26 * len(popisky) + 60
    out = Image.new("RGBA", (sirka, vyska), (16, 17, 21, 255))
    y = 0
    out.alpha_composite(hlav, (10, y))
    y += hlav.height
    for t in tabulky:
        out.alpha_composite(t, (10, y))
        y += t.height + 8
    d = ImageDraw.Draw(out)
    y += 8
    d.text((12, y), "NAMERENO (z manifestu, ne od oka):", font=F_H2, fill=TITULEK)
    y += 26
    for radek in popisky:
        d.text((12, y), radek, font=F_S, fill=POPIS2)
        y += 20
    out.convert("RGB").save(a.out)
    print(f"[srovnani] {a.out} ({out.width}x{out.height})")
    for radek in popisky:
        print(f"[srovnani] {radek}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
