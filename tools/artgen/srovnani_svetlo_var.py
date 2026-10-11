# -*- coding: utf-8 -*-
"""srovnani_svetlo_var.py - ZMERI varianty svetla z `_rawvar/` (nic nezapisuje).

  python tools/artgen/srovnani_svetlo_var.py
  python tools/artgen/srovnani_svetlo_var.py --json tools/artgen/_svetlo-var.json

PROC: `MERENI.md` §9 zmerilo, ze jedna sada se svetlem ma NIZSI kontrast a
placate predmety schovavaji stin. Nez se pregeneruje cela sada, je potreba
zmerit, KTERY parametr svetla to dela - a to na techtez modelech, se stejnou
kamerou a stejnou kontaktni rovinou (`probe_svetlo_var.py`).

Meri se z PIXELU (nic se nedopocitava z nastaveni svetel):

  1. KONTRAST SPRITU (jen BEAUTY bez stinu): smerodatna odchylka jasu pres
     pixely, kde je objekt (alfa >= 128), a rozptyl (max-min kvantil 5-95 %).
     To je cislo, ktere v MERENI.md §9.3 spadlo (dyka 25,7 -> 15,2).
  2. PRUMERNY JAS objektu (sada je tmavsi o 8-13 %).
  3. STIN: z pomeru `stin/ref` se meri
       * `dosah_vpred_px` = jak daleko od OBJEKTU je hustota > 0,15 ve smeru
         od stredu roviny (tedy ven, ne pod predmet),
       * `hustota_u_obrysu` = max hustota v prvnich 2 px mimo objekt,
       * `stin_px_mimo` = pocet pixelu roviny mimo objekt s hustotou > 0,15.

⚠ Kde je predmet se urcuje z BEAUTY renderu: `objekt = dilate(alfa>=128, 4)`.
Dilatace 4 px schvalne - chci merit stin MIMO predmet vcetne par pixelu, ktere
antialias a perspektiva "podhodi" (viz MERENI.md: stin placateho predmetu je
1px lem tesne u obrysu). Kdyby maska byla tesna, merilo by se jen to, co je
schovane. Sloupec `pod_obryzem` proto hlasi, kolik pixelu stinu padlo DO masky.

⚠ Kdyz vstup chybi, sonda to REKNE a skonci nenulove - chybejici mereni se
nesmi tvarit jako namerena nula.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
RAWVAR = HERE / "_rawvar"
RAW = HERE / "_rawlit"
PRAH_STINU = 0.15


def _img(p: Path) -> np.ndarray:
    if not p.exists():
        raise SystemExit(f"CHYBI vstup: {p} (spust probe_svetlo_var.py)")
    return np.asarray(Image.open(p).convert("RGBA"), dtype=np.float32)


def zmer(davka: str, beauty: Path, ref: Path, stin: Path, dil: int = 4) -> dict:
    b, r, s = _img(beauty), _img(ref), _img(stin)
    objekt = b[:, :, 3] >= 128
    if not objekt.any():
        raise SystemExit(f"{beauty}: v beauty renderu neni zadny objekt")
    rovina = r[:, :, 3] > 127
    jas_r = r[:, :, :3].mean(axis=2)
    jas_s = s[:, :, :3].mean(axis=2)
    f = np.clip(jas_s / np.maximum(jas_r, 1e-3), 0.0, 1.0)
    hustota = np.where(rovina, 1.0 - f, 0.0)

    # --- kontrast samotneho objektu (bez stinu) -----------------------------
    jas_obj = b[:, :, :3].mean(axis=2)[objekt]
    q05, q95 = np.quantile(jas_obj, 0.05), np.quantile(jas_obj, 0.95)

    # --- stin: profil pres vzdalenost od objektu ----------------------------
    maska = ndimage.binary_dilation(objekt, iterations=dil)
    mimo = rovina & ~maska & (hustota > PRAH_STINU)
    dal = ndimage.distance_transform_edt(~objekt)
    uvnitr_masky = rovina & maska & (hustota > PRAH_STINU)
    # prvni 2 px mimo objekt (i kdyz padnou do masky)
    blizko = rovina & (dal > 0.0) & (dal <= 2.0 + dil)
    hs = hustota[blizko]
    # SMER, KTERYM SLUNCE ODHAZUJE STIN: teziste stinu vuci tezisti objektu
    # (merene, ne z rotace svetla - rotace se do pixelu prevadi kamerou)
    smer = None
    if mimo.any():
        oy, ox = ndimage.center_of_mass(objekt)
        sy, sx = ndimage.center_of_mass(mimo)
        smer = [round(float(sx - ox), 1), round(float(sy - oy), 1)]
    return {
        "davka": davka,
        "objekt_px": int(objekt.sum()),
        "jas_objektu": round(float(jas_obj.mean()), 2),
        "jas_sd": round(float(jas_obj.std()), 2),
        "jas_rozptyl_q05_q95": round(float(q95 - q05), 2),
        "stin_px_mimo": int(mimo.sum()),
        "stin_pod_obryzem_px": int(uvnitr_masky.sum()),
        "stin_max_vzdalenost_px": round(float(dal[mimo].max()), 1) if mimo.any() else 0.0,
        "stin_smer_px": smer,
        "hustota_u_obrysu_max": round(float(hs.max()), 3) if hs.size else 0.0,
        "hustota_u_obrysu_stred": round(float(np.median(hs)), 3) if hs.size else 0.0,
        "hustota_max": round(float(hustota.max()), 3),
    }


def dvojice(slozka: Path, plan: str):
    """Vstup varianty: `_rawvar/<varianta>/<plan>/` (a zpetne i `_rawvar/<varianta>/`)."""
    for zaklad in (slozka / plan, slozka):
        b = zaklad / f"item_{plan}.png"
        r = zaklad / f"_ref_item_{plan}.png"
        s = zaklad / f"_stin_item_{plan}.png"
        if b.exists() and r.exists() and s.exists():
            return b, r, s
    return None


def _radek(v: dict, jmeno: str = None) -> None:
    smer = v.get("stin_smer_px")
    smer_txt = f"{smer[0]:+.0f},{smer[1]:+.0f}" if smer else "-"
    print(f"{(jmeno or v['davka']):12s} {v['objekt_px']:>7d} {v['jas_objektu']:>7.2f} "
          f"{v['jas_sd']:>6.2f} {v['jas_rozptyl_q05_q95']:>8.2f} "
          f"{v['stin_px_mimo']:>9d} {v['stin_pod_obryzem_px']:>8d} "
          f"{v['stin_max_vzdalenost_px']:>6.1f} {smer_txt:>10s} "
          f"{v['hustota_u_obrysu_max']:>7.3f} {v['hustota_max']:>6.3f}")


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser(description="mereni variant svetla")
    ap.add_argument("--plan", default="dagger")
    ap.add_argument("--json", default="")
    a = ap.parse_args()
    if not RAWVAR.exists():
        print(f"CHYBI {RAWVAR} - neni co merit (spust probe_svetlo_var.py)")
        return 1
    varianty = sorted(d for d in RAWVAR.iterdir() if d.is_dir())
    if not varianty:
        print(f"v {RAWVAR} nejsou zadne varianty")
        return 1
    vse = {}
    print(f"{'varianta':12s} {'obj_px':>7s} {'jas':>7s} {'sd':>6s} {'rozptyl':>8s} "
          f"{'stin_mimo':>9s} {'pod_obr':>8s} {'dosah':>6s} {'smer':>10s} "
          f"{'h_obrys':>7s} {'h_max':>6s}")
    for d in varianty:
        troj = dvojice(d, a.plan)
        if troj is None:
            print(f"{d.name:12s} NEMERENO (chybi item_{a.plan}/ref/stin)")
            continue
        v = zmer(d.name, *troj)
        vse[d.name] = v
        _radek(v)
    # baseline z _rawlit (soucasna lit sada) - aby se dalo overit, ze `lit`
    # varianta dava TOTEZ (jinak by laborator meril neco jineho)
    if (RAW / f"item_{a.plan}.png").exists():
        v = zmer("_rawlit(baseline)", RAW / f"item_{a.plan}.png",
                 RAW / f"_ref_item_{a.plan}.png", RAW / f"_stin_item_{a.plan}.png")
        vse["_rawlit_baseline"] = v
        _radek(v, "_rawlit(basel)")
    if a.json:
        Path(a.json).write_text(json.dumps(vse, ensure_ascii=False, indent=1,
                                           sort_keys=True) + "\n", encoding="utf-8")
        print(f"ZAPIS {a.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
