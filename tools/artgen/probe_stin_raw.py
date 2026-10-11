# -*- coding: utf-8 -*-
"""probe_stin_raw.py - ZMERI kontaktni stin v SUROVYCH renderech (nic nezapisuje).

  python tools/artgen/probe_stin_raw.py

PROC SAMOSTATNA SONDA: `probe_stin_lit.py` meri stin v HOTOVE sade - a tim
odpovida na otazku "je stin videt". Tahle sonda meri to, z ceho stin VZNIKA:
pomer jasu `_stin_*.png` / `_ref_*.png` v `_rawlit/`. Rozdil je podstatny:

  * v surovem renderu je videt OPTICKA HUSTOTA objektu (jak moc zastinuje
    kontaktni rovinu) - a to je jedina velicina, ze ktere se da rozhodnout,
    jestli je problem v renderu (malo svetla/uhlu) nebo v postprocessu
    (radialni ubytek, prah, krytí);
  * hotova sada ma stin jen tam, kde ho videt JE (pod objektem ho prekryva).

Meri se (po kazdou davku):
  * sirka/vyska kontaktni roviny v px (`ref` alfa),
  * histogram hustoty `1 - jas_stin/jas_ref` pres pixely roviny -> quantily,
  * kolik pixelu ma hustotu > 0,25 / > 0,5 / > 0,75 (a jaky je to podil roviny),
  * jak daleko od OBJEKTU (alfa beauty) lezi pixely s hustotou > 0,5 -
    tedy "kolik px stinu je videt mimo predmet" (v surovem renderu).

⚠ ZADNA CISLA SE NEDOPISUJI: vsechno se pocita z pixelu. Kdyz render chybi,
sonda to rekne a skonci nenulove (chybejici vstup se nesmi tvarit jako nula).
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import artgen_common_lit as acl

RAW = Path(acl.RAW)
PRAHY = (0.10, 0.25, 0.50, 0.75)


def _nacti(cesta: Path) -> np.ndarray:
    if not cesta.exists():
        raise SystemExit(f"CHYBI vstup: {cesta} (spust render_lit.py --plan ...)")
    return np.asarray(Image.open(cesta).convert("RGBA"), dtype=np.float32)


def zmer(davka: str, beauty: Path, ref: Path, stin: Path) -> dict:
    a_b = _nacti(beauty)
    a_r = _nacti(ref)
    a_s = _nacti(stin)
    rovina = a_r[:, :, 3] > 127
    objekt = a_b[:, :, 3] > 127
    if not rovina.any():
        raise SystemExit(f"{ref}: v ref renderu neni videt kontaktni rovina")
    jas_r = a_r[:, :, :3].mean(axis=2)
    jas_s = a_s[:, :, :3].mean(axis=2)
    f = np.clip(jas_s / np.maximum(jas_r, 1e-3), 0.0, 1.0)
    hustota = np.where(rovina, 1.0 - f, np.nan)
    h = hustota[rovina]
    ys, xs = np.nonzero(rovina)
    # vzdalenost od objektu (v px) pro pixely, ktere maji hustotu > 0,25
    dal = ndimage.distance_transform_edt(~objekt)
    silne = rovina & (hustota > 0.25) & ~objekt
    stred = (int(xs.min() + xs.max()) // 2, int(ys.min() + ys.max()) // 2)
    return {
        "davka": davka,
        "rovina_px": int(rovina.sum()),
        "rovina_sirka": int(xs.max() - xs.min() + 1),
        "rovina_vyska": int(ys.max() - ys.min() + 1),
        "objekt_px": int(objekt.sum()),
        "hustota": {f"q{int(q*100):02d}": round(float(np.quantile(h, q)), 3)
                    for q in (0.05, 0.25, 0.5, 0.75, 0.95, 0.99)},
        "hustota_max": round(float(np.nanmax(h)), 3),
        "podil": {f">{p:.2f}": round(float((h > p).mean()), 3) for p in PRAHY},
        "silne_mimo_objekt_px": int(silne.sum()),
        "silne_mimo_objekt_max_vzdalenost": round(float(dal[silne].max()), 1)
        if silne.any() else None,
        "rovina_stred": stred,
    }


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser(description="mereni suroveho kontaktniho stinu")
    ap.add_argument("--raw", default=str(RAW), help="kde jsou rendery (default _rawlit)")
    a = ap.parse_args()
    raw = Path(a.raw)
    if not raw.exists():
        print(f"CHYBI slozka {raw} - neni co merit (nic se nedopocitava)")
        return 1
    dvojice = []
    for b in sorted(raw.glob("item_*.png")):
        j = b.stem
        s = raw / f"_stin_{j}.png"
        r = raw / f"_ref_{j}.png"
        if s.exists() and r.exists():
            dvojice.append((j, b, r, s))
    if (raw / "char_d0_f0.png").exists():
        dvojice.append(("char_d0_f0", raw / "char_d0_f0.png",
                        raw / "_ref_character.png", raw / "_stin_char_d0_f0.png"))
    if not dvojice:
        print(f"v {raw} nejsou zadne dvojice (beauty/ref/stin) - nic se nemerilo")
        return 1
    hlavicka = (f"{'davka':14s} {'rovina':>10s} {'objekt':>7s} "
                f"{'q25':>6s} {'q50':>6s} {'q75':>6s} {'max':>6s} "
                f"{'>0.10':>7s} {'>0.25':>7s} {'>0.50':>7s} {'>0.75':>7s} "
                f"{'silne_mimo':>11s} {'max_d':>6s}")
    print(hlavicka)
    for j, b, r, s in dvojice:
        v = zmer(j, b, r, s)
        print(f"{v['davka']:14s} "
              f"{str((v['rovina_sirka'], v['rovina_vyska'])):>10s} {v['objekt_px']:>7d} "
              f"{v['hustota']['q25']:>6.3f} {v['hustota']['q50']:>6.3f} "
              f"{v['hustota']['q75']:>6.3f} {v['hustota_max']:>6.3f} "
              f"{v['podil']['>0.10']:>7.3f} {v['podil']['>0.25']:>7.3f} "
              f"{v['podil']['>0.50']:>7.3f} {v['podil']['>0.75']:>7.3f} "
              f"{v['silne_mimo_objekt_px']:>11d} "
              f"{v['silne_mimo_objekt_max_vzdalenost']!s:>6s}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
