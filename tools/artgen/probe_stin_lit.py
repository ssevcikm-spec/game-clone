# -*- coding: utf-8 -*-
"""probe_stin_lit.py - ZMERI kontaktni stin v hotove lit sade (nic nezapisuje).

  python tools/artgen/probe_stin_lit.py

Co meri (z pixelu atlasu, ne z reportu):
  * stin = polopruhledne pixely (0 < alfa < 200) MIMO siluetu objektu
    (silueta = alfa >= 200 rozsirena o 2 px, aby do stinu nepatril antialias
    hrany objektu - prvni verze brany to pletla a hlasila "barva stinu neni
    cerna" u 45 spritu, protoze antialias ma barvu objektu),
  * bbox stinu proti bboxu objektu a proti KOTVE (kontakt = `(w//2, h-22)`),
  * max krytí a pocet pixelu stinu, pomer stin/objekt,
  * zda stin dosahne na okraj spritu (pak by byl ukrojeny).

Pouziva se na to, aby brana v `pack_atlas_lit.py` netvrdila nic, co se
NEMERILO - a aby se cisla dala zapsat do `MERENI.md`.
"""
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

import artgen_common as ac1
import artgen_common_lit as acl

OWN = acl.SADA
OWN1X = Path("assets/own")


def masky(img: Image.Image) -> dict:
    """Masky spritu. STIN = pixely BARVY VRSTVY STINU s nizsi alfou.

    ⚠ PRVNI VERZE TOHLE DELALA SPATNE a stoji za zapsani: stin se hledal jako
    "polopruhledne pixely mimo siluetu objektu rozsirenou o 2 px". Tim se ale
    zahodil PRAVE TEN stin, ktery je videt - kontaktni stin u predmetu lezicich
    na zemi je 1 px siroka tmava linka TESNE u obrysu (u dyky 7 px, krytí do
    30/255) a dilatace ho smazala. Spravne rozliseni je podle BARVY: vrstva
    stinu je neutralni `STIN_BARVA`, kdezto antialias objektu ma barvu objektu.
    """
    a = np.array(img)
    alfa = a[:, :, 3]
    plna = alfa >= 200
    silueta = ndimage.binary_dilation(plna, iterations=2)
    cerno = (a[:, :, :3] == np.array(acl.STIN_BARVA, dtype=np.uint8)).all(axis=2)
    stin = (alfa > 0) & (alfa < 200) & cerno
    return {"a": a, "alfa": alfa, "plna": plna, "silueta": silueta, "stin": stin,
            # kontrola, ze maska nechyta TELO objektu (kdyby mel nektery material
            # skoro cernou barvu, byl by to falesny stin)
            "telo_barva_stinu": int((plna & cerno).sum()),
            "stin_mimo_siluetu": int((stin & ~silueta).sum())}


def bbox(m: np.ndarray):
    if not m.any():
        return None
    ys, xs = np.nonzero(m)
    return (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))


def obsah_1x(kind: str, ident: int):
    m = json.loads((OWN1X / "manifest.json").read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            img = Image.open(OWN1X / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
            a = np.array(img)[:, :, 3]
            bb = bbox(a > 0)
            return {"box": (img.width, img.height), "obsah": (bb[2] - bb[0] + 1,
                                                              bb[3] - bb[1] + 1)}
    return None


def ascii_dump(ids: list[int], jen_druh: str = "item") -> None:
    """Vypise sprite po pixelech: `.` prazdno, `#` objekt, `S` stin, `+` antialias.

    Duvod: "stin je ve sprite" se neda rozhodnout z jednoho cisla - je potreba
    videt, KDE ty pixely jsou (a jestli je stin schovany pod objektem).
    """
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    for s in m["sprites"]:
        if s["kind"] != jen_druh or (ids and s["id"] not in ids):
            continue
        img = Image.open(OWN / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
        a = np.array(img)
        alfa = a[:, :, 3]
        cerno = a[:, :, :3].max(axis=2) < 8
        stin = (alfa > 0) & (alfa < 200) & cerno
        anti = (alfa > 0) & (alfa < 200) & ~cerno
        print(f"--- {s['kind']} {s['id']} box {s['w']}x{s['h']} "
              f"kotva=({s['w'] // 2},{s['h'] - acl.GROUND_PX}) "
              f"S={int(stin.sum())} +(antialias tela)={int(anti.sum())} "
              f"max_alfa_stinu={int(alfa[stin].max()) if stin.any() else 0}")
        for y in range(s["h"]):
            radek = "".join("." if alfa[y, x] == 0 else
                            "#" if alfa[y, x] >= 200 else
                            "S" if cerno[y, x] else "+"
                            for x in range(s["w"]))
            print(f"{y:3d} {radek}")


def main() -> int:
    import argparse
    ap = argparse.ArgumentParser(description="mereni kontaktniho stinu v lit sade")
    ap.add_argument("--ascii", action="store_true", help="vypsat sprity po pixelech")
    ap.add_argument("--druh", default="item")
    ap.add_argument("--ids", default="", help="id oddelena carkou (prazdne = vsechny)")
    a = ap.parse_args()
    if a.ascii:
        ids = [int(v) for v in a.ids.split(",") if v.strip()]
        ascii_dump(ids, a.druh)
        return 0
    return mereni()


def mereni() -> int:
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    radky = []
    for s in m["sprites"]:
        img = Image.open(OWN / s["page"]).convert("RGBA").crop(tuple(s["rect"]))
        mk = masky(img)
        ax, ay = s["w"] // 2, s["h"] - acl.GROUND_PX
        ob = bbox(mk["plna"])
        sb = bbox(mk["stin"])
        # stin na okraji spritu = ukrojeny stin
        okraj = np.zeros_like(mk["stin"])
        okraj[0, :] = okraj[-1, :] = True
        okraj[:, 0] = okraj[:, -1] = True
        radek = {
            "kind": s["kind"], "id": s["id"], "box": (s["w"], s["h"]),
            "kotva": (ax, ay),
            "objekt": ob, "stin_px": int(mk["stin"].sum()),
            "stin_max_alfa": int(mk["alfa"][mk["stin"]].max()) if mk["stin"].any() else 0,
            "stin_mimo_siluetu": mk["stin_mimo_siluetu"],
            "telo_barva_stinu": mk["telo_barva_stinu"],
            "stin_na_okraji": int((mk["stin"] & okraj).sum()),
            "stin_pod_obrysem": int(mk["stin"][ob[3] + 1:, :].sum()) if ob else 0,
            "stin_vpravo_od_obrysu": (sb[2] - ob[2]) if (sb and ob) else None,
            "stin_vlevo_od_obrysu": (ob[0] - sb[0]) if (sb and ob) else None,
            "stin_dolu_od_obrysu": (sb[3] - ob[3]) if (sb and ob) else None,
            "stin_nahoru_od_obrysu": (ob[1] - sb[1]) if (sb and ob) else None,
        }
        if s["kind"] != "land":
            radky.append(radek)

    def r_(v):
        return "-" if v is None else f"{v:d}"

    print(f"{'druh':5s} {'id':>8s} {'box':>9s} {'objekt':>13s} {'stin_px':>8s} "
          f"{'max_a':>6s} {'okraj':>6s} {'pod_obr':>8s} {'vpravo':>7s} {'vlevo':>6s} "
          f"{'dolu':>5s} {'nahoru':>7s} {'mimo_sil':>9s} {'telo=stin':>9s}")
    for r in radky:
        o = r["objekt"]
        print(f"{r['kind']:5s} {r['id']:>8d} {str(r['box']):>9s} "
              f"{str((o[2]-o[0]+1, o[3]-o[1]+1)):>13s} {r['stin_px']:>8d} "
              f"{r['stin_max_alfa']:>6d} {r['stin_na_okraji']:>6d} "
              f"{r['stin_pod_obrysem']:>8d} {r_((r['stin_vpravo_od_obrysu'])):>7s} "
              f"{r_((r['stin_vlevo_od_obrysu'])):>6s} {r_((r['stin_dolu_od_obrysu'])):>5s} "
              f"{r_((r['stin_nahoru_od_obrysu'])):>7s} {r['stin_mimo_siluetu']:>9d} "
              f"{r['telo_barva_stinu']:>9d}")

    print("\n--- souhrn ---")
    for kind in ("item", "anim"):
        v = [r for r in radky if r["kind"] == kind]
        if not v:
            continue
        print(f"{kind}: spritu {len(v)}, stin_px min/max {min(r['stin_px'] for r in v)}/"
              f"{max(r['stin_px'] for r in v)}, max krytí {max(r['stin_max_alfa'] for r in v)}/255, "
              f"stin na okraji spritu: {sum(r['stin_na_okraji'] for r in v)} px, "
              f"pod obrysem: {sum(1 for r in v if r['stin_pod_obrysem'] > 0)}/{len(v)} spritu, "
              f"telo barvy stinu (falesny stin): {sum(r['telo_barva_stinu'] for r in v)} px")
    # geometrie proti 1x sade
    print("\n--- obsah objektu proti 1x sade (svetlo nema menit tvar) ---")
    for kind in ("item", "anim"):
        v = [r for r in radky if r["kind"] == kind]
        d = []
        for r in v:
            o1 = obsah_1x(r["kind"], r["id"])
            if o1 is None:
                continue
            o = r["objekt"]
            d.append((abs((o[2] - o[0] + 1) - o1["obsah"][0]),
                      abs((o[3] - o[1] + 1) - o1["obsah"][1])))
        if d:
            print(f"{kind}: max |rozdil obsahu| = ({max(x for x, _ in d)}, "
                  f"{max(y for _, y in d)}) px pres {len(d)} spritu")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
