# -*- coding: utf-8 -*-
"""srovnani_svetlo.py - srovnavaci list "1x bez svetla vs 1x se svetlem".

  python tools/artgen/srovnani_svetlo.py
      -> tools/artgen/_srovnani-svetlo.png

ODPOVIDA NA JEDNU OTazku (ZADANI-25 §10): "ma smysl vzit z 2x svetlo?" - a
odpovida obrazkem, ne dojmem. Tri sloupce ve stejnem poradi ve vsech sekcich:

    puvodni UO  |  nas 1x BEZ svetla (`assets/own/`)  |  nas 1x SE svetlem
                                                       (`assets/own-lit/`)

Radky pro kazdou sekci:
  * "STEJNE MERITKO" - vsechny tri sloupce ve stejnem zvetseni. Odpovida:
    "vypada to lip, kdyz je to stejne velke?"
  * "VYREZ 1 : 1" - NATIVNI pixely (zoom 1), tak to vypada ve hre.

DVĚ VADY PREDCHOZIHO LISTU, KTERE JSOU TADY OPRAVENE (ZADANI-25 §10):
  (a) KRESLI SE NAMERENY OBSAH, NE BOX. Kazdy sprite se pred kreslenim oreze na
      svuj namereny obsah (alfa > 0) a teprve pak se sadi kotvou - takze UO dyka
      (obsah 11x11 v boxu 22x26) je na listu STEJNE VELKA jako nase (11x12),
      zatimco driv se vedle sebe tiskly rozmery BOXu (22x26 vs 14x28) a UO
      "vypadala vetsi". Cisla v popiscich jsou namerena z pixelu.
  (b) CERVENY KRIZEK SE NEKRESLI PRES ART. Kresli se POD sprite (a jen tam, kde
      sprite nema obsah), takze se v postave neobjevuji cervene pixely. Kdyz
      kotva lezi pod obsahem (u postavy na chodidlech), je to v popisku RECENO,
      ne nakresleno.

Zarovnava se STRED DLAZDICE: sprite se kresli na `to_screen - (ox,oy)`, takze
kontaktni bod je v sprite na `(w//2, h-22)` - u UO, u 1x i u lit (stejny
vzorec, kotva je kontrakt). Kdyby se boxy centrovally, rozdilna vyska boxu by
posunula obrazek a "sedi to na dlazdici?" by z listu neznamerilo.

POZOR: tenhle list je NA POHLED, ne brana. Cisla (kotvy, masky, stin, obsah)
hlida `pack_atlas_lit.py --check`.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import artgen_common as ac1
import artgen_common_lit as acl
import postprocess as pp
import uo_ref

HERE = Path(__file__).resolve().parent
OWN1X = Path("assets/own")
OWNLIT = acl.SADA
UO = Path("assets/uo")

PODKLAD = (198, 200, 205, 255)          # svetly podklad: UO telo 400 je sede (115,115,114)
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


F_H1 = font(26, True)
F_H2 = font(17, True)
F = font(14)
F_M = font(13)
F_S = font(11)


# ---------------------------------------------------------------------------
# zdroje
# ---------------------------------------------------------------------------
class Zdroj:
    """Sprite + kde je v nem STRED DLAZDICE + co je v nem NAMERENY obsah."""

    def __init__(self, img: Image.Image, ax: float, ay: float, jmeno: str = ""):
        self.img = img
        self.ax, self.ay = ax, ay          # stred dlazdice (kontakt) ve spritu
        self.jmeno = jmeno
        a = np.asarray(img)[:, :, 3]
        self.viditelny = self._bbox(a > 0)                       # vcetne stinu
        self.objekt = self._bbox(a >= 200) or self.viditelny     # bez stinu (plna alfa)
        self.box = (img.width, img.height)
        self.kotva_pod_obsahem = bool(a[int(round(ay)), int(round(ax))] > 0) \
            if 0 <= int(round(ay)) < img.height and 0 <= int(round(ax)) < img.width else False
        cerno = (np.asarray(img)[:, :, :3] ==
                 np.array(acl.STIN_BARVA, dtype=np.uint8)).all(axis=2)
        stin = (a > 0) & (a < 200) & cerno
        self.stin_px = int(stin.sum())
        self.stin_max_alfa = int(a[stin].max()) if stin.any() else 0

    @staticmethod
    def _bbox(m: np.ndarray):
        if not m.any():
            return None
        ys, xs = np.nonzero(m)
        return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)

    def rozmer_obsahu(self) -> tuple[int, int]:
        b = self.objekt
        return (b[2] - b[0], b[3] - b[1])

    def prumer_rgb(self):
        a = np.asarray(self.img)
        m = a[:, :, 3] >= 200
        if not m.any():
            return None
        return tuple(int(round(v)) for v in a[:, :, :3][m].mean(axis=0))

    def kontrast(self):
        """Smerodatna odchylka jasu jadra - kolik je v spritu SVETELNEHO rozptylu.

        Slouzi k tomu, aby tvrzeni "AO pridal hloubku" melo cislo: kdyby se
        rozptyl nezvedl, je to jen ztmaveni, ne modelace.
        """
        a = np.asarray(self.img)[:, :, :3].astype(np.float64)
        m = np.asarray(self.img)[:, :, 3] >= 200
        if not m.any():
            return None
        jas = 0.2126 * a[:, :, 0] + 0.7152 * a[:, :, 1] + 0.0722 * a[:, :, 2]
        return round(float(jas[m].std()), 1)

    def zmenseny(self, r: float) -> "Zdroj":
        if r == 1.0:
            return self
        nova = pp.zmensi(self.img, (max(1, round(self.img.width * r)),
                                    max(1, round(self.img.height * r))))
        return Zdroj(nova, self.ax * r, self.ay * r, self.jmeno)


def _stranky(zaklad: Path, manifest: dict) -> dict:
    return {p["file"]: Image.open(zaklad / p["file"]).convert("RGBA")
            for p in manifest["pages"]}


def _vyrezej(manifest, stranky, kind, ident):
    for s in manifest["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return stranky[s["page"]].crop(tuple(s["rect"]))
    return None


class Sada:
    """Tri zdroje tehoz spritu: UO, 1x bez svetla, 1x se svetlem."""

    def __init__(self) -> None:
        self.m1 = json.loads((OWN1X / "manifest.json").read_text(encoding="utf-8"))
        self.ml = json.loads((OWNLIT / "manifest.json").read_text(encoding="utf-8"))
        self.p1 = _stranky(OWN1X, self.m1)
        self.pl = _stranky(OWNLIT, self.ml)
        self.uo_m = uo_ref.nacti_manifest(UO / "manifest.json")
        self.uo_p = uo_ref.Stranky(UO)

    def _uo_item(self, uo_id: int):
        z = uo_ref.zaznam(self.uo_m, "item", uo_id)
        if z is None:
            return None
        img = self.uo_p.sprite(z)
        return Zdroj(img, img.width // 2, img.height - ac1.GROUND_PX, f"UO {uo_id}")

    def _uo_land(self, uo_id: int):
        z = uo_ref.zaznam(self.uo_m, "land", uo_id)
        if z is None:
            return None
        img = self.uo_p.sprite(z)
        # ⚠ U dlazdice je kotva `ox=oy=0` (levy horni roh boxu = HORNI VRCHOL
        # kosoctverce). List ale zarovnava STRED DLAZDICE (tam sedi kontakt
        # predmetu), a ten je ve sprite na (22, 22) - proto se u dlazdice
        # nepredava (0,0), ale stred. Jinak by dlazdice v bunce utekla o pul
        # kosoctverce a "sedi to na sobe?" by se z listu nedalo precist.
        return Zdroj(img, img.width / 2.0, img.height / 2.0, f"UO {uo_id}")

    def predmet(self, uo_id: int) -> dict:
        out = {}
        z = self._uo_item(uo_id)
        if z is not None:
            out["uo"] = z
        img = _vyrezej(self.m1, self.p1, "item", uo_id)
        if img is not None:
            out["1x"] = Zdroj(img, img.width // 2, img.height - ac1.GROUND_PX, "1x")
        img = _vyrezej(self.ml, self.pl, "item", uo_id)
        if img is not None:
            out["lit"] = Zdroj(img, img.width // 2, img.height - acl.GROUND_PX, "1x+svetlo")
        return out

    def dlazdice(self, uo_id: int, jmeno: str) -> dict:
        out = {}
        z = self._uo_land(uo_id)
        if z is not None:
            out["uo"] = z
        img = _vyrezej(self.m1, self.p1, "land", uo_id)
        if img is not None:
            out["1x"] = Zdroj(img, img.width / 2.0, img.height / 2.0, jmeno)
        img = _vyrezej(self.ml, self.pl, "land", uo_id)
        if img is not None:
            out["lit"] = Zdroj(img, img.width / 2.0, img.height / 2.0, jmeno)
        return out

    def anim(self, frame: int, smer: int = 0) -> dict:
        out = {}
        d = json.loads((UO / "anim" / "anim-sheets.json").read_text(encoding="utf-8"))
        v = d["sprites"].get(f"{ac1.CHAR['body']}/{ac1.CHAR['action_walk']}/{smer}")
        if v and frame < len(v["frames"]):
            fr = v["frames"][frame]
            img = Image.open(UO / "anim" / v["file"]).convert("RGBA").crop(tuple(fr["rect"]))
            out["uo"] = Zdroj(img, fr["cx"], fr["cy"] + fr["h"], f"UO f{frame}")
        img = _vyrezej(self.m1, self.p1, "anim", ac1.anim_id(smer, frame))
        if img is not None:
            out["1x"] = Zdroj(img, img.width // 2, img.height - ac1.GROUND_PX, "1x")
        img = _vyrezej(self.ml, self.pl, "anim", acl.anim_id(smer, frame))
        if img is not None:
            out["lit"] = Zdroj(img, img.width // 2, img.height - acl.GROUND_PX, "1x+svetlo")
        return out


# ---------------------------------------------------------------------------
# kresleni
# ---------------------------------------------------------------------------
VZDUCH_VRCH = 30          # px nad spritem v bunce (na popisek)


def bunka(z: Zdroj, sirka: int, vyska: int, zoom: int, dilace: int,
          kotva: tuple[int, int], popisek: str, popisek2: str = "") -> Image.Image:
    """Bunka: NAMERENY OBSAH spritu zarovnany stredem dlazdice (v `kotva`).

    Kresli se ORÍZNUTY sprite (na namereny obsah), ne cely box - viz (a) v
    docstringu modulu. Krizek se kresli PRVNI, takze ho sprite prekryje a nikdy
    neleze pres art - viz (b).
    """
    b = Image.new("RGBA", (sirka, vyska), PODKLAD)
    d = ImageDraw.Draw(b)
    # krizek = stred dlazdice; kresli se POD sprite
    d.line([(kotva[0] - 8, kotva[1]), (kotva[0] + 8, kotva[1])], fill=KRIZ)
    d.line([(kotva[0], kotva[1] - 8), (kotva[0], kotva[1] + 8)], fill=KRIZ)
    if z is not None:
        bb = z.viditelny
        oriznuty = z.img.crop(bb)
        velky = oriznuty.resize((oriznuty.width * zoom, oriznuty.height * zoom),
                                Image.NEAREST)
        # kde je v oriznute casti kotva: (ax - bb[0], ay - bb[1])
        b.alpha_composite(velky, (int(round(kotva[0] - (z.ax - bb[0]) * zoom)),
                                  int(round(kotva[1] - (z.ay - bb[1]) * zoom))))
    if dilace:
        r = dilace * zoom / 2.0
        d.polygon([(kotva[0], kotva[1] - r), (kotva[0] + r, kotva[1]),
                   (kotva[0], kotva[1] + r), (kotva[0] - r, kotva[1])],
                  outline=OBRYS_DLAZDICE)
    d.text((5, 4), popisek, font=F_S, fill=POPIS_TMAVY)
    if popisek2:
        d.text((5, 17), popisek2, font=F_S, fill=POPIS_TMAVY)
    return b


def _miry(skupina: list[Zdroj], zoom: int, dilace: int,
          texty: list[str] = None) -> dict:
    """Zmeri skupinu: kolik px je potreba vlevo/vpravo/nad/pod kotvou.

    Pocita se z NAMERENEHO OBSAHU (ne z boxu) - jinak by UO sprite s prazdnymi
    okraji delal zbytecne siroke bunky. Sirka bunky se navic roztahne tak, aby
    se do ni Vesel POPISEK: pri zoomu 1 (vyrez 1:1) je obsah 44 px, ale popisek
    ma ~100 px - prvni verze listu ho nechala pretect do sousedni bunky a texty
    se prekryvaly (vada nalezena POHLEDEM na list, ne strojem).
    """
    z = [x for x in skupina if x is not None]
    if not z:
        return {"sirka": 60, "kotva_x": 30, "vyska": VZDUCH_VRCH + 40,
                "kotva_y": VZDUCH_VRCH}
    vlevo = max(((x.ax - x.viditelny[0]) * zoom for x in z), default=20)
    vpravo = max(((x.viditelny[2] - x.ax) * zoom for x in z), default=20)
    nad = max(((x.ay - x.viditelny[1]) * zoom for x in z), default=20)
    pod = max(((x.viditelny[3] - x.ay) * zoom for x in z), default=20)
    r = dilace * zoom / 2.0 if dilace else 0.0
    text = 0
    for t in (texty or []):
        if t:
            text = max(text, _sirka_textu(t, F_S))
    sirka = int(max(vlevo + vpravo + 8, 2 * r + 8, text + 12, 44))
    return {"vlevo": vlevo, "vpravo": vpravo, "nad": nad, "pod": pod,
            "sirka": sirka,
            # obsah se v sirsi bunce vycentruje (jinak by u popisku utekl vlevo)
            "kotva_x": int((sirka - (vlevo + vpravo)) / 2.0 + vlevo),
            "vyska": int(VZDUCH_VRCH + max(nad, r) + max(pod, r) + 14),
            "kotva_y": int(VZDUCH_VRCH + max(nad, r))}


def _sirka_textu(text: str, f) -> int:
    """Sirka textu v px (bez kresleni) - aby bunka popisek neuřízla."""
    try:
        return int(f.getlength(text))
    except AttributeError:                      # starsi Pillow
        return int(f.getsize(text)[0])


def rada(skupiny: list[list[Zdroj]], zoom: int, popisky: list[str],
         dilace: list[int], popisky_bunek: list[list[str]] = None,
         popisky2: list[list[str]] = None) -> Image.Image:
    miry = [_miry(s, zoom, dilace[j],
                  [t for t in ((popisky_bunek[j] if popisky_bunek else []) +
                               (popisky2[j] if popisky2 else []))])
            for j, s in enumerate(skupiny)]
    vyska = max(m["vyska"] for m in miry) + 22
    sirka = 150 + sum(m["sirka"] * len(skupiny[j]) for j, m in enumerate(miry))
    p = Image.new("RGBA", (sirka, vyska), RAM)
    d = ImageDraw.Draw(p)
    x = 150
    for j, popisek in enumerate(popisky):
        d.text((x + 6, 4), popisek, font=F_M,
               fill=(150, 190, 255, 255) if j == 2 else POPIS)
        x += miry[j]["sirka"] * len(skupiny[j])
    x = 150
    for j, skupina in enumerate(skupiny):
        m = miry[j]
        for i, z in enumerate(skupina):
            pop = popisky_bunek[j][i] if popisky_bunek else ""
            pop2 = popisky2[j][i] if popisky2 else ""
            p.alpha_composite(bunka(z, m["sirka"], vyska - 22, zoom, dilace[j],
                                    (m["kotva_x"], m["kotva_y"]), pop, pop2), (x, 22))
            x += m["sirka"]
    return p


def nadpis(text: str, sirka: int, f=None, barva=TITULEK) -> Image.Image:
    f = f or F_H2
    p = Image.new("RGBA", (sirka, f.size + 12), RAM)
    ImageDraw.Draw(p).text((8, 4), text, font=f, fill=barva)
    return p


def hlavicka(sirka: int) -> Image.Image:
    radky = [
        ("SROVNANI: 1x BEZ SVETLA vs 1x SE SVETLEM (ZADANI-25 §10)", F_H1, TITULEK),
        ("Sloupce: puvodni UO sprite | nas 1x bez svetla (3 slunce, 512 px) | "
         "nas 1x se svetlem (1 smerove slunce + Fast-GI AO + kontaktni stin).",
         F, POPIS),
        ("ROZLISENI JE STEJNE ve vsech trech sloupcich (dlazdice 44 px, krok 22, "
         "kotva ox=(w>>1)-22, oy=h-44) - meni se JEN svetlo.", F, POPIS),
        ("Rada A = STEJNE MERITKO (vsechny sloupce stejne zvetsene). "
         "Rada B = VYREZ 1:1 (nativni pixely - tak to vypada ve hre).", F, POPIS2),
        ("Kresli se NAMERENY OBSAH spritu (ne box): sprite je oriznuty na svuj "
         "obsah a teprve pak usazen kotvou, takze UO dyka (obsah 11x11 v boxu "
         "22x26) je vedle nasi STEJNE velka. Popisky jsou namerene z pixelu.",
         F_M, POPIS2),
        ("Cerveny krizek = STRED DLAZDICE (tam sedi kontakt). Kresli se POD "
         "sprite, takze NIKDY neleze pres art - u postavy je v popisku receno, "
         "ze kotva lezi pod obsahem. Obrys = dlazdice 44 px.", F_M, POPIS2),
    ]
    vyska = sum(f.size + 9 for _t, f, _b in radky) + 12
    p = Image.new("RGBA", (sirka, vyska), RAM)
    d = ImageDraw.Draw(p)
    y = 6
    for t, f, b in radky:
        d.text((10, y), t, font=f, fill=b)
        y += f.size + 9
    return p


# ---------------------------------------------------------------------------
def merene_radky(sada: Sada) -> list[str]:
    """Namereny text k listu - cisla z PIXELU obou sad (a z manifestu lit sady).

    ⚠ JAK SE MERI VELIKOST (a je to receno i na listu): "obsah" = jadro spritu
    (`alfa >= 200`). U UO je to totéž co `alfa > 0`, protoze UO art je kresleny
    bez antialiasu (alfa je 0 nebo 255); nase sprity maji mekky lem, takze
    `alfa > 0` je o 1-2 px vetsi. Kdyby se UO merilo pres `alfa > 0` a nase pres
    `alfa >= 200`, vyslo by, ze "UO je vetsi" - a to je presne vada (a), ktera se
    tady opravuje.
    """
    out = []
    rl = sada.ml["report"]
    dyka = sada.predmet(3921)
    d_uo, d_1x, d_lit = dyka["uo"], dyka["1x"], dyka["lit"]
    out.append(
        f"dyka: obsah (jadro alfa>=200) UO {d_uo.rozmer_obsahu()[0]}x{d_uo.rozmer_obsahu()[1]} "
        f"| 1x {d_1x.rozmer_obsahu()[0]}x{d_1x.rozmer_obsahu()[1]} "
        f"| 1x+svetlo {d_lit.rozmer_obsahu()[0]}x{d_lit.rozmer_obsahu()[1]} px  ·  "
        f"videt (alfa>0): UO {d_uo.viditelny[2]-d_uo.viditelny[0]}x"
        f"{d_uo.viditelny[3]-d_uo.viditelny[1]} | 1x {d_1x.viditelny[2]-d_1x.viditelny[0]}x"
        f"{d_1x.viditelny[3]-d_1x.viditelny[1]} | 1x+svetlo "
        f"{d_lit.viditelny[2]-d_lit.viditelny[0]}x{d_lit.viditelny[3]-d_lit.viditelny[1]} "
        f"(vetsi jen o stin)  ·  box: UO {d_uo.box[0]}x{d_uo.box[1]} | 1x {d_1x.box[0]}x"
        f"{d_1x.box[1]} | 1x+svetlo {d_lit.box[0]}x{d_lit.box[1]} (roste o misto na stin)")
    a_uo, a_1x, a_lit = sada.anim(0)["uo"], sada.anim(0)["1x"], sada.anim(0)["lit"]
    out.append(f"postava f0: obsah UO {a_uo.rozmer_obsahu()[0]}x{a_uo.rozmer_obsahu()[1]} | "
               f"1x {a_1x.rozmer_obsahu()[0]}x{a_1x.rozmer_obsahu()[1]} | 1x+svetlo "
               f"{a_lit.rozmer_obsahu()[0]}x{a_lit.rozmer_obsahu()[1]} px  ·  box: 1x "
               f"{a_1x.box[0]}x{a_1x.box[1]} -> 1x+svetlo {a_lit.box[0]}x{a_lit.box[1]}")
    out.append(
        f"viditelny kontaktni stin (pixely barvy stinu v hotovem spritu, mereno z pixelu): "
        f"dyka {d_lit.stin_px} px (krytí do {d_lit.stin_max_alfa}/255), krumpac "
        f"{sada.predmet(3717)['lit'].stin_px}, ruda {sada.predmet(6583)['lit'].stin_px}, "
        f"ingot {sada.predmet(7151)['lit'].stin_px}, postava f0 {a_lit.stin_px} px "
        f"(krytí do {a_lit.stin_max_alfa}/255)")
    out.append(f"dlazdice stin NEMA - {rl['land_stin_duvod']}; AO na dlazdici zustava "
               "(hloubka travnich trsu a kament)")
    out.append(f"barvy obsahu (prumer jadra, sRGB): trava UO {sada.dlazdice(3, 'grass')['uo'].prumer_rgb()} "
               f"| 1x {sada.dlazdice(3, 'grass')['1x'].prumer_rgb()} "
               f"| 1x+svetlo {sada.dlazdice(3, 'grass')['lit'].prumer_rgb()}   ·   "
               f"cesta UO {sada.dlazdice(1001, 'road')['uo'].prumer_rgb()} "
               f"| 1x {sada.dlazdice(1001, 'road')['1x'].prumer_rgb()} "
               f"| 1x+svetlo {sada.dlazdice(1001, 'road')['lit'].prumer_rgb()}")
    out.append(f"barvy obsahu: dyka UO {d_uo.prumer_rgb()} | 1x {d_1x.prumer_rgb()} | "
               f"1x+svetlo {d_lit.prumer_rgb()}   ·   postava f0 UO {a_uo.prumer_rgb()} | "
               f"1x {a_1x.prumer_rgb()} | 1x+svetlo {a_lit.prumer_rgb()}")
    g1, gl = sada.dlazdice(3, "grass"), sada.dlazdice(3, "grass")
    c1, cl = sada.dlazdice(1001, "road"), sada.dlazdice(1001, "road")
    k_t1, k_tl = g1["1x"].kontrast(), g1["lit"].kontrast()
    k_d1, k_dl = d_1x.kontrast(), d_lit.kontrast()
    k_a1, k_al = a_1x.kontrast(), a_lit.kontrast()
    out.append(
        "CO SE TIM ZMENILO (mereno, ne od oka): rozptyl jasu se u vsech vzorku SNIZIL "
        f"(trava {k_t1} -> {k_tl}, cesta {c1['1x'].kontrast()} -> {c1['lit'].kontrast()}, "
        f"dyka {k_d1} -> {k_dl}, postava {k_a1} -> {k_al}). Jedno slunce misto trojice "
        "(klic+vypln+obrys) bere odlesky a obrysovy svetly lem, ktere driv drzely "
        "kontrast - u kovovych predmetu je to videt nejvic. Co svetlo PRIDALO, je "
        "kontaktni stin (objekt stoji NA dlazdici) a barvy bliz UO; co UBALO, je "
        "vysekove svetlo a modelace objemu.")
    out.append("recept svetla je prevzaty z 2x vetve 1:1 (1 slunce energie 4,0, uhel 12 st., "
               "Fast-GI AO dosah 0,20 jednotky, stin R0 0,14 / R1 0,34 jednotky, sila 0,55); "
               "`pack_atlas_lit.py --check` na tom ma branu - kdyby se rozešel, spadne")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="srovnavaci list 1x bez svetla vs se svetlem")
    ap.add_argument("--out", default="tools/artgen/_srovnani-svetlo.png")
    ap.add_argument("--zoom-item", type=int, default=6)
    ap.add_argument("--zoom-tile", type=int, default=3)
    ap.add_argument("--zoom-char", type=int, default=3)
    a = ap.parse_args()

    sada = Sada()
    klic = ("uo", "1x", "lit")
    jmena = ("puvodni UO", "nas 1x BEZ svetla", "nas 1x SE svetlem")

    def trojice(z: dict, popis: str) -> list[Zdroj]:
        chybi = [k for k in klic if k not in z]
        if chybi:
            raise SystemExit(f"{popis}: chybi zdroj {chybi} (je {sorted(z)})")
        return [z[k] for k in klic]

    def popisky_bunek(zdroje: list[Zdroj]) -> tuple[list[list[str]], list[list[str]]]:
        p1, p2 = [], []
        for z in zdroje:
            b = []
            b2 = []
            for x in z:
                w, h = x.rozmer_obsahu()
                b.append(f"{x.jmeno}: {w}x{h}")
                b2.append("kotva pod obsahem" if x.kotva_pod_obsahem else
                          f"box {x.box[0]}x{x.box[1]}")
            p1.append(b)
            p2.append(b2)
        return p1, p2

    tabulky: list[Image.Image] = []

    # --- sekce A: dyka ------------------------------------------------------
    tabulky.append(nadpis("SEKCE A - DYKA (item 3921, lezi na zemi)", 1400))
    dyka = trojice(sada.predmet(3921), "dyka")
    for popis, zoom, dil in (("A1) STEJNE MERITKO (vsechny sloupce x%d)" % a.zoom_item,
                              a.zoom_item, 44),
                             ("A2) VYREZ 1 : 1 - nativni pixely", 1, 44)):
        tabulky.append(nadpis(popis, 1400, F_M))
        p1, p2 = popisky_bunek([[dyka[0]], [dyka[1]], [dyka[2]]])
        tabulky.append(rada([[dyka[0]], [dyka[1]], [dyka[2]]], zoom, list(jmena),
                            [dil, dil, dil], p1, p2))

    # --- sekce B: teren -----------------------------------------------------
    tabulky.append(nadpis("SEKCE B - TEREN (land 3 trava, land 1001 cesta)", 1400))
    for jmeno, uo_id in (("trava (land 3)", 3), ("cesta (land 1001)", 1001)):
        d = trojice(sada.dlazdice(uo_id, jmeno), jmeno)
        for popis, zoom in ((f"B) {jmeno} - STEJNE MERITKO (x{a.zoom_tile})", a.zoom_tile),
                            (f"B) {jmeno} - VYREZ 1 : 1", 1)):
            tabulky.append(nadpis(popis, 1400, F_M))
            p1, p2 = popisky_bunek([[d[0]], [d[1]], [d[2]]])
            tabulky.append(rada([[d[0]], [d[1]], [d[2]]], zoom, list(jmena),
                                [44, 44, 44], p1, p2))

    # --- sekce C: postava ---------------------------------------------------
    framy = list(range(ac1.CHAR["frames"]))
    tabulky.append(nadpis("SEKCE C - POSTAVA (telo 400, akce walk, smer 0, 8 framu)", 1400))
    for popis, zoom in ((f"C1) STEJNE MERITKO (x{a.zoom_char})", a.zoom_char),
                        ("C2) VYREZ 1 : 1 - nativni pixely", 1)):
        tabulky.append(nadpis(popis, 1400, F_M))
        zdroje = [trojice(sada.anim(f), f"anim f{f}") for f in framy]
        po_slozkach = [list(g) for g in zip(*zdroje)]
        p1, p2 = popisky_bunek(po_slozkach)
        # u postavy se obrys dlazdice nekresli (pres chodidla by to byl sum) a
        # popisky jsou jen velikosti - bunek je 24, dlouhy text by list rozhodil
        p2 = [["" for _ in p2[j]] for j in range(len(p2))]
        tabulky.append(rada(po_slozkach, zoom, list(jmena), [0, 0, 0], p1, p2))

    # --- slozit -------------------------------------------------------------
    sirka = max(t.width for t in tabulky) + 20
    hlav = hlavicka(sirka)
    popisky = merene_radky(sada)
    vyska = hlav.height + sum(t.height + 6 for t in tabulky) + 24 * len(popisky) + 70
    out = Image.new("RGBA", (sirka, vyska), (16, 17, 21, 255))
    y = 0
    out.alpha_composite(hlav, (10, y))
    y += hlav.height
    for t in tabulky:
        out.alpha_composite(t, (10, y))
        y += t.height + 6
    d = ImageDraw.Draw(out)
    y += 10
    d.text((12, y), "NAMERENO (z pixelu obou sad a z manifestu lit sady, ne od oka):",
           font=F_H2, fill=TITULEK)
    y += 24
    for radek in popisky:
        d.text((12, y), radek, font=F_S, fill=POPIS2)
        y += 19
    out.convert("RGB").save(a.out)
    print(f"[srovnani-svetlo] {a.out} ({out.width}x{out.height})")
    for radek in popisky:
        print(f"[srovnani-svetlo] {radek}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
