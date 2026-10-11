# -*- coding: utf-8 -*-
"""probe_determinismus_v3.py - DVA BEHY v3 pipeline a jejich porovnani.

  python tools/artgen/probe_determinismus_v3.py
      -> tools/artgen/_determinismus-v3.json   (a pregeneruje `_rawv3/`)

PROC: brana `pack_atlas_v3.py --check` nema jak zjistit, jestli je sada
deterministicka - bezi nad hotovym vystupem. Tenhle skript oba behy SKUTECNE
provede (build -> render -> pack) a porovna manifest i pixely.

⚠ CO JE PROTI v2 SNIMKU JINE (a je to namERene, ne opomenute): maze se i
`_stin_*.png`, ne jen `_ref_*.png`. `render_v3.render_ref` hotovy ref PRESKOCI
(rovina se mezi framy nemeni), ale `render_stin` pise VZDY - kdyby se ref
nechal stary a stin se prepsal, porovnavaly by se dva behy, z nichz jeden ma
cast vstupu z behu minuleho.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
sys.path.insert(0, str(HERE))

import artgen_common_v3 as acv  # noqa: E402

OWN = acv.SADA
RAW = HERE / "_rawv3"
VYSTUP = HERE / "_determinismus-v3.json"
# Tolerance v urovnich barvy/alfy na pixel. Kvantizace na paletu zesiluje sum
# EEVEE (1 uroven v renderu -> az 5 v atlase); cislo se proto VZDY hlasi.
PIXEL_TOLERANCE = 6


def sha(cesta: Path) -> str:
    return hashlib.sha256(cesta.read_bytes()).hexdigest()


def pixely_sha(img: Image.Image) -> str:
    return hashlib.sha256(np.asarray(img.convert("RGBA"), dtype=np.uint8).tobytes()).hexdigest()


def snimek() -> dict:
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    stranky = {}
    for p in m["pages"]:
        c = OWN / p["file"]
        img = Image.open(c).convert("RGBA")
        stranky[p["file"]] = {"sha": sha(c), "pixely_sha": pixely_sha(img),
                              "size": list(img.size)}
    anim = {c.name: {"sha": sha(c),
                     "pixely_sha": pixely_sha(Image.open(c).convert("RGBA"))}
            for c in sorted((OWN / "anim").glob("*.png"))}
    return {"manifest_sha": sha(OWN / "manifest.json"), "stranky": stranky,
            "anim": anim, "spritu": len(m["sprites"]),
            "stranky_pixely": {k: np.asarray(Image.open(OWN / k).convert("RGBA"),
                                             dtype=np.int16) for k in stranky}}


def spust(jmeno: str, cmd: list[str], ocekavane: str) -> dict:
    t0 = time.perf_counter()
    p = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    vystup = (p.stdout or "") + (p.stderr or "")
    ok = p.returncode == 0 and ocekavane in vystup
    print(f"[detv3] {jmeno:30s} {time.perf_counter() - t0:7.2f} s  "
          f"{'OK' if ok else 'CHYBA'}")
    if not ok:
        for radek in vystup.splitlines()[-25:]:
            print("   " + radek)
    return {"faze": jmeno, "ok": ok, "sekund": round(time.perf_counter() - t0, 2)}


def main() -> int:
    if not (OWN / "manifest.json").exists():
        raise SystemExit(f"chybi {OWN/'manifest.json'} - nejdriv spust celou v3 "
                         "pipeline (build_model_v3.py, render_v3.py, pack_atlas_v3.py)")
    print("[detv3] 1. beh - stav na disku (baseline)")
    a = snimek()

    print("[detv3] 2. beh - znovu postavit, vyrenderovat a zabalit")
    for stary in list(RAW.glob("_ref_*.png")) + list(RAW.glob("_stin_*.png")):
        stary.unlink()                    # vynuti znovu vyrenderovat oba pruchody
    faze = [
        spust("build modely (v3)", [BLENDER, "-b", "-P", str(HERE / "build_model_v3.py"),
                                    "--", "--plan", "all"], "BUILD_OK_V3"),
        spust("render dlazdice", [BLENDER, "-b", "-P", str(HERE / "render_v3.py"),
                                  "--", "--plan", "tiles"], "RENDER_OK_V3 tiles 2"),
        spust("render predmety", [BLENDER, "-b", "-P", str(HERE / "render_v3.py"),
                                  "--", "--plan", "items"], "RENDER_OK_V3 items 4"),
        spust("render postava", [BLENDER, "-b", "-P", str(HERE / "render_v3.py"),
                                 "--", "--plan", "character"], "RENDER_OK_V3 character 40"),
        spust("zabalit atlas", [sys.executable, str(HERE / "pack_atlas_v3.py")],
              "[checkv3]"),
    ]
    b = snimek()

    rozdily, max_pixel, pixely_po_strankach = [], 0, {}
    if a["manifest_sha"] != b["manifest_sha"]:
        rozdily.append(f"manifest SHA: {a['manifest_sha'][:12]} vs {b['manifest_sha'][:12]}")
    for k in sorted(set(a["stranky"]) | set(b["stranky"])):
        if k not in a["stranky"] or k not in b["stranky"]:
            rozdily.append(f"{k}: stranka v jednom z behu chybi")
            continue
        d = np.abs(a["stranky_pixely"][k] - b["stranky_pixely"][k])
        kdekoli = d.max(axis=2)
        pixely_po_strankach[k] = {
            "max_rozdil": int(kdekoli.max()),
            "pixelu_s_rozdilem": int((kdekoli > 0).sum()),
            "max_rozdil_alfa": int(d[:, :, 3].max()),
            "max_rozdil_rgb": int(d[:, :, :3].max()),
            "sha_shodne": a["stranky"][k]["sha"] == b["stranky"][k]["sha"]}
        max_pixel = max(max_pixel, int(kdekoli.max()))
        if a["stranky"][k]["sha"] != b["stranky"][k]["sha"]:
            rozdily.append(f"{k}: SHA souboru se lisi")
        if kdekoli.max() != 0:
            rozdily.append(f"{k}: pixely se lisi u {int((kdekoli > 0).sum())} px, "
                           f"max|rozdil| = {int(kdekoli.max())}")
    for k in sorted(set(a["anim"]) | set(b["anim"])):
        if a["anim"].get(k, {}).get("sha") != b["anim"].get(k, {}).get("sha"):
            rozdily.append(f"anim/{k}: SHA se lisi")

    shodne_manifest = a["manifest_sha"] == b["manifest_sha"]
    shodne_pixely = max_pixel <= PIXEL_TOLERANCE
    vystup = {
        "co_to_je": "determinismus v3 sady: dva behy cele pipeline (build+render+pack)",
        "co_se_porovnava": ["sha256(manifest.json)", "sha256(stranky PNG)",
                            "sha256(pixelu stranek)", "max|rozdil| pixelu",
                            "sha256(anim listu)"],
        "pixel_tolerance": PIXEL_TOLERANCE,
        "baseline": {k: v for k, v in a.items() if k != "stranky_pixely"},
        "druhy_beh": {k: v for k, v in b.items() if k != "stranky_pixely"},
        "pixely_po_strankach": pixely_po_strankach,
        "max_pixel_rozdil": max_pixel,
        "shodne_manifest": shodne_manifest,
        "shodne_pixely": shodne_pixely,
        "rozdiely": rozdily,
        "shodne": shodne_manifest and shodne_pixely,
        "faze": faze,
    }
    VYSTUP.write_text(json.dumps(vystup, ensure_ascii=False, indent=1,
                                 sort_keys=True) + "\n", encoding="utf-8",
                      newline="\n")
    print(f"[detv3] manifest SHA 1. {a['manifest_sha'][:16]} 2. {b['manifest_sha'][:16]}")
    print(f"[detv3] max|rozdil| pixelu = {max_pixel} (tolerance {PIXEL_TOLERANCE})")
    for k, v in sorted(pixely_po_strankach.items()):
        print(f"[detv3]   {k}: px s rozdilem {v['pixelu_s_rozdilem']}, "
              f"max {v['max_rozdil']} (rgb {v['max_rozdil_rgb']}, "
              f"alfa {v['max_rozdil_alfa']}), SHA: {v['sha_shodne']}")
    print(f"[detv3] {'SHODNE' if vystup['shodne'] else 'ROZDILNE'}: {VYSTUP}")
    for r in rozdily:
        print(f"[detv3]   ROZDIL: {r}")
    spatne = [f for f in faze if not f["ok"]]
    return 1 if (spatne or not vystup["shodne"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
