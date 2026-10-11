# -*- coding: utf-8 -*-
"""srovnani_sady.py - srovnavaci list UO | nas stary | nas novy (a mereni).

  python tools/artgen/srovnani_sady.py

  -> tools/artgen/_srovnani-v3.png        (list na POHLED)
  -> tools/artgen/_srovnani-v3.json       (cisla, ze kterych se rozhoduje)

SLOUPCE (a proc prave tyhle):
  1. **UO** - vzor POCTEM, ne telesne (`docs/01` §1.2.1). Nekopirujeme ho; je to
     referencia pro "jak vypada pixel art, ktery nekdo kreslil rukou".
  2. **nas 1x bez svetla** (`assets/own/`) - stary stav PRED svetlem.
  3. **nas lit** (`assets/own-lit/`) - predchozi sada se svetlem; v ni jsou dve
     ZMERENE vady, ktere tenhle krok opravuje (`ZADANI-25` §11): placate
     predmety maji stin jako 1px lem a kontrast klesl.
  4. **nas v3** (`assets/own-v3/`) - opravena sada.

RADY: kazdy prvek je 2x - JEDNOU na trave a JEDNOU na ceste (aby se nevybirala
jedna dlazdice) - a navic radek "VYREZ 1 : 1" (ctyrikrat zvetseny stred), kde je
videt stin a obrys.

CISLA (`_srovnani-v3.json`), vsechno z PIXELU:
  * `stin_viditelne_px`, `stin_max_alfa` - kolik stinu je VIDET a jak je silny,
  * `telo_sd` (smerodatna odchylka jasu jadra) - KONTRAST, tedy to, co v MERENI.md
    §9.3 spadlo (dyka 25,7 -> 15,2),
  * `telo_jas` - prumerny jas (sada byla tmavsi o 8-13 %),
  * `telo_barvy` - kolik barev zustalo po palete (pixel-art kontrola).

⚠ Definice "jadra" je popsana u `jadro_mask` a je pro VSECHNY sady STEJNA - bez
toho by se merily ruzne veci (a "kontrast stoupl" by mohlo znamenat jen to, ze
se do masky dostalo vic pozadi).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

import artgen_common as ac1
import artgen_common_lit as acl
import artgen_common_v3 as acv

HERE = Path(__file__).resolve().parent
SADY = [("UO", Path("assets/uo")),
        ("nas 1x bez svetla", Path("assets/own")),
        ("nas lit (stary)", acl.SADA),
        ("nas v3 (novy)", acv.SADA)]
# Co se srovnava: dyka, krumpac, ruda, ingot, 3 framy chuze.
PRVKY = [("item", 3921), ("item", 3717), ("item", 6583), ("item", 7151),
         ("anim", 400000), ("anim", 400004), ("anim", 400007)]
KOLIK = 5                      # zvetseni bunky


def _man(sada: Path) -> dict | None:
    cesta = sada / "manifest.json"
    if not cesta.exists():
        return None
    return json.loads(cesta.read_text(encoding="utf-8"))


def sprite(sada: Path, man: dict, kind: str, ident: int):
    for s in man["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def jadro_mask(img: Image.Image, kind: str) -> np.ndarray:
    """Jadro tela pro mereni kontrastu - STEJNA definice pro vsechny sady.

    Je to `alfa == 255` ERODOVANA o 1 px: tim se z mereni vyhodi antialias
    hrany (u UO je to 1px lem, u naseho 0/255 silueta) a zustane VNITREK tvaru.
    Bez eroze by se u UO meril i svetly lem a kontrast by vysel jinak nez
    u naseho artu - a to by bylo mereni hrany, ne tela.
    """
    from scipy import ndimage
    a = np.asarray(img)[:, :, 3]
    plna = a >= 250
    if not plna.any():
        return plna
    return ndimage.binary_erosion(plna, iterations=1)


def zmer(img: Image.Image, kind: str) -> dict:
    a = np.asarray(img)
    alfa = a[:, :, 3]
    jadro = jadro_mask(img, kind)
    jas = a[:, :, :3].mean(axis=2)[jadro] if jadro.any() else np.array([0.0])
    # stin: polopruhledne pixely (u vsech sad stejna definice)
    stin = (alfa > 0) & (alfa < 200)
    sa = alfa[stin]
    # barvy v tele (jen plne pixely - u UO i nase)
    plne = alfa >= 250
    barvy = (int(len(np.unique(a[:, :, :3][plne].reshape(-1, 3), axis=0)))
             if plne.any() else 0)
    return {"box": list(img.size),
            "telo_px": int(plne.sum()),
            "telo_jadro_px": int(jadro.sum()),
            "telo_jas": round(float(jas.mean()), 2),
            "telo_sd": round(float(jas.std()), 2),
            "telo_rozptyl_q05_q95": round(
                float(np.quantile(jas, 0.95) - np.quantile(jas, 0.05)), 2),
            "telo_barvy": barvy,
            "polopruhle_px": int(stin.sum()),
            "stin_max_alfa": int(sa.max()) if sa.size else 0,
            "stin_prumer_alfa": round(float(sa.mean()), 1) if sa.size else 0.0}


def dlazdice(sada: Path, man: dict, ident: int = 3) -> Image.Image | None:
    """Dlazdice (44x44) z DANE sady; UO se bere z `assets/uo`, nase z nasi sady.

    ⚠ NESMI SE BRAT VZDY Z UO: dlazdice UO sady ma v sobe popisky ("UNUSED",
    "UN!!"), ktere se v nasi sade nevyskytuji - prvni verze listu je kvuli tomu
    ukazovala nasi travu s cizimi napisy (namEReno POHLEDEM).
    """
    for s in man["sprites"]:
        if s["kind"] == "land" and s["id"] == ident:
            return Image.open(sada / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
    return None


def na_dlazdici(spr: Image.Image, pozadi: Image.Image) -> Image.Image:
    out = pozadi.copy()
    kx = spr.width // 2
    ky = spr.height - ac1.GROUND_PX
    out.alpha_composite(spr, (out.width // 2 - kx, out.height // 2 - ky))
    return out


def list_sheet(bunky: dict, cesta: Path) -> None:
    """List "rada = sada, sloupec = prvek" z uz polozenych sprite.

    ⚠ KLIC BUNKY JE (jmeno sady, popisek prvku) - a popisek je ZAROVEN to, co se
    pise do hlavicky. Kdyz se hledalo `(jmeno, k)` pro `k` = cely klic, hledalo
    se neco, co v `bunky` neni: list se ulozil PRAZDNY a nikdo si toho nevsiml
    (namEReno - prazdny list vypada jako "hotovo").
    """
    popisky = list(dict.fromkeys(k[1] for k in bunky))
    kolik = KOLIK
    sirka = max(v.width for v in bunky.values()) * kolik + 8
    vyska = max(v.height for v in bunky.values()) * kolik + 20
    p = Image.new("RGB", (sirka * len(popisky) + 10, vyska * len(SADY) + 24),
                  (22, 24, 28))
    d = ImageDraw.Draw(p)
    vlozeno = 0
    for r, (jmeno, _s) in enumerate(SADY):
        y = 20 + vyska * r
        d.text((8, y + 4), jmeno, fill=(235, 235, 235))
        for c, popisek in enumerate(popisky):
            img = bunky.get((jmeno, popisek))
            if img is None:
                continue
            x = 10 + sirka * c
            p.paste(img.resize((img.width * kolik, img.height * kolik),
                               Image.NEAREST), (x + 4, y + 2))
            vlozeno += 1
    for c, popisek in enumerate(popisky):
        d.text((14 + sirka * c, 4), popisek, fill=(235, 235, 235))
    p.save(cesta)
    print(f"LIST {cesta} ({p.width}x{p.height}) bunka {sirka}x{vyska}, "
          f"vlozeno {vlozeno}/{len(popisky) * len(SADY)} bunek")
    if vlozeno == 0:
        raise SystemExit("list je PRAZDNY - klice bunek nesedi s hlavickou")


def main() -> int:
    ap = argparse.ArgumentParser(description="srovnani sad UO | stary | novy")
    ap.add_argument("--list", default="tools/artgen/_srovnani-v3.png")
    ap.add_argument("--json", default="tools/artgen/_srovnani-v3.json")
    ap.add_argument("--jen-trava", action="store_true",
                    help="bez druheho listu na ceste")
    a = ap.parse_args()

    many = {j: _man(s) for j, s in SADY}
    chybejici = [j for j, m in many.items() if m is None]
    if chybejici:
        print(f"CHYBI sada: {chybejici} - neni co srovnavat")
        return 1
    # dlazdice pro polstovani: bere se z KAZDE sady zvlast (kdyz nema land,
    # pouzije se UO - jinak by se dala nase trava vedle UO postavy)
    dlazdice_sady = {}
    for jmeno, sada in SADY:
        t = dlazdice(sada, many[jmeno])
        if t is None:
            t = dlazdice(SADY[0][1], many["UO"])
        if t is None:
            raise SystemExit(f"{jmeno}: neni land 3 ani v sade, ani v UO - "
                             "neni na co sprity polozit")
        w = 44 + 2 * 22
        poz = Image.new("RGBA", (w, w), (0, 0, 0, 255))
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                poz.alpha_composite(t, (22 + 22 * dx, 22 + 22 * dy))
        dlazdice_sady[jmeno] = poz

    cisla: dict[str, dict] = {}
    bunky = {}
    for jmeno, sada in SADY:
        man = many[jmeno]
        cisla[jmeno] = {}
        for kind, ident in PRVKY:
            spr = sprite(sada, man, kind, ident)
            if spr is None:
                cisla[jmeno][f"{kind} {ident}"] = {"chybi": True}
                continue
            cisla[jmeno][f"{kind} {ident}"] = zmer(spr, kind)
            bunky[(jmeno, f"{kind} {ident}")] = na_dlazdici(
                spr, dlazdice_sady[jmeno])
    print("[srovnani] bunky:", len(bunky), "velikosti:",
          {k: v.size for k, v in list(bunky.items())[:4]})
    list_sheet(bunky, Path(a.list))

    # --- souhrn po sadach (co je videt na prvni pohled v cislech) -----------
    souhrn = {}
    for jmeno in many:
        it = [v for k, v in cisla[jmeno].items() if k.startswith("item") and "chybi" not in v]
        an = [v for k, v in cisla[jmeno].items() if k.startswith("anim") and "chybi" not in v]
        souhrn[jmeno] = {
            "item_stin_px": {k: v["polopruhle_px"] for k, v in cisla[jmeno].items()
                             if k.startswith("item") and "chybi" not in v},
            "item_stin_max_alfa": {k: v["stin_max_alfa"] for k, v in cisla[jmeno].items()
                                   if k.startswith("item") and "chybi" not in v},
            "item_sd_prumer": round(float(np.mean([v["telo_sd"] for v in it])), 2) if it else None,
            "anim_sd_prumer": round(float(np.mean([v["telo_sd"] for v in an])), 2) if an else None,
            "item_jas_prumer": round(float(np.mean([v["telo_jas"] for v in it])), 2) if it else None,
            "anim_jas_prumer": round(float(np.mean([v["telo_jas"] for v in an])), 2) if an else None,
        }
    for jmeno in many:
        s = souhrn[jmeno]
        print(f"{jmeno:20s} stin item px {s['item_stin_px']}")
        print(f"{'':20s} max krytí    {s['item_stin_max_alfa']}")
        print(f"{'':20s} sd item {s['item_sd_prumer']} anim {s['anim_sd_prumer']} | "
              f"jas item {s['item_jas_prumer']} anim {s['anim_jas_prumer']}")
    Path(a.json).write_text(json.dumps(
        {"co_to_je": "srovnani sad UO | nas 1x bez svetla | nas lit | nas v3",
         "definice_jadra": "alfa == 255 erodovana o 1 px (stejne pro vsechny sady)",
         "prvky": [f"{k} {i}" for k, i in PRVKY],
         "cisla": cisla, "souhrn": souhrn},
        ensure_ascii=False, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"ZAPIS {a.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
