# -*- coding: utf-8 -*-
"""mereni_2x.py - co stoji 2x varianta NAVIC (render i postprocess).

  python tools/artgen/mereni_2x.py
      -> tools/artgen/_casy-2x.json  + tabulka na obrazovku

PROC VZNIKL: `MERENI.md` ma casy 1x pilotu, ale z JINEHO DNE a pro JINOU praci
(46 spritu ze 7 modelu). "Kolik stoji 2x" se z nich spocitat neda. Tenhle
skript meri OBE varianty TADY a TEĎ, na stejne praci:

    dyka:      1 sprite           (1x i 2x)
    postava:   8 framu smeru 0    (1x i 2x)
    postprocess: techtez 9 spritu (1x i 2x)

Cim se meri:
  * render - `subprocess` + `perf_counter` (cely beh Blenderu vcetne startu);
    skript pritom vypisuje `CAS pass=...`, takze se z toho da ODCISTAT start
    Blenderu a rozdelit kreativni pruchod / stin / referenci.
  * postprocess - `perf_counter` IN-PROCESS (zadny start Pythonu, zadny zapis),
    aby se porovnavalo to same: `priprav` + `sestav` pro 9 spritu.

⚠ 1x vetev se pri mereni NEMENI: render 1x jde do `raw2x/_timing1x/` a je to
presne to, co dela `render_sprites.py` (otevrit .blend a vyrenderovat) - proto
se vysledek POROVNAVA hashs se snimkem z pilotu (`raw/item_dagger.png`).
Kdyby se lisil, meri se neco jineho, nez pilot delal.
"""
from __future__ import annotations

import json
import re
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

RAW1X = HERE / "raw"
RAW2X = HERE / "_raw2x"
TIMING1X = RAW2X / "_timing1x"


def hash_(p: Path) -> str:
    import hashlib
    return hashlib.sha256(p.read_bytes()).hexdigest()[:12] if p.exists() else "CHYBI"


def spust(jmeno: str, cmd: list[str], ocekavane: list[str]) -> dict:
    t0 = time.perf_counter()
    p = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    trvani = time.perf_counter() - t0
    vystup = (p.stdout or "") + (p.stderr or "")
    chybejici = [v for v in ocekavane if v not in vystup]
    ok = p.returncode == 0 and not chybejici
    # `CAS pass=X sekund=Y` umi Blender vypsat VICEKRAT (kazdy frame) - scitame
    # je a pocitame, aby se z toho dalo rict "kolik stoji JEDEN snimek", ne
    # "kolik stoji posledni snimek" (prvni verze tohohle mereni si dictem
    # prepsala hodnoty a vypadalo to, ze 8 framu stoji 0,3 s).
    soucet: dict[str, float] = {}
    pocet: dict[str, int] = {}
    for m in re.finditer(r"CAS pass=(\w+) sekund=([\d.]+)", vystup):
        soucet[m.group(1)] = soucet.get(m.group(1), 0.0) + float(m.group(2))
        pocet[m.group(1)] = pocet.get(m.group(1), 0) + 1
    passy = {k: {"soucet": round(v, 2), "pocet": pocet[k],
                 "na_kus": round(v / pocet[k], 3)} for k, v in soucet.items()}
    print(f"[mereni] {jmeno:34s} {trvani:7.2f} s  {'OK' if ok else 'CHYBA'}"
          + (f"  chybi: {chybejici}" if chybejici else ""))
    if passy:
        print("           " + "  ".join(
            f"{k}={v['soucet']}s/{v['pocet']}x" for k, v in sorted(passy.items())))
    if not ok:
        for radek in vystup.splitlines()[-20:]:
            print("   " + radek)
    return {"faze": jmeno, "sekund": round(trvani, 2), "ok": ok, "passy": passy,
            "navratovy_kod": p.returncode}


def _origin(cesta: Path) -> tuple[float, float]:
    o = json.loads(cesta.read_text(encoding="utf-8"))
    return (o["origin_x"], o["origin_y"])


def postprocess_1x() -> dict:
    """1x postprocess 9 spritu IN-PROCESS (nic nezapisuje, nic nemeni)."""
    import artgen_common as ac1
    import postprocess as pp
    t0 = time.perf_counter()
    p = pp.priprav(RAW1X / "item_dagger.png", _origin(RAW1X / "_origin_item_dagger.json"))
    s = pp.meritko([p], obsah_vyska_px=ac1.ITEMS[0]["uo_content"][1])
    sprity, _m = pp.sestav([p], s, "item", popis="dagger")
    t_item = time.perf_counter() - t0
    o = _origin(RAW1X / "_origin_character.json")
    t1 = time.perf_counter()
    pripr = [pp.priprav(RAW1X / f"char_d0_f{f}.png", o) for f in range(ac1.CHAR["frames"])]
    s = pp.meritko(pripr, obsah_vyska_px=ac1.CHAR["cil_obsah_px"])
    pp.sestav(pripr, s, "anim", popis="character")
    t_anim = time.perf_counter() - t1
    return {"sekund": round(t_item + t_anim, 3), "item": round(t_item, 3),
            "anim_8_framu": round(t_anim, 3), "spritu": 1 + ac1.CHAR["frames"],
            "box_item": list(sprity[0].size), "ok": True}


def postprocess_2x() -> dict:
    """2x postprocess týchž 9 spritu IN-PROCESS (vcetne stinu)."""
    import pack_atlas_2x as pa
    t0 = time.perf_counter()
    klice, sprity, _meta = pa.davka_item()
    t_item = time.perf_counter() - t0
    t1 = time.perf_counter()
    _k, sprity_a, _m = pa.davka_anim()
    t_anim = time.perf_counter() - t1
    return {"sekund": round(t_item + t_anim, 3), "item": round(t_item, 3),
            "anim_8_framu": round(t_anim, 3), "spritu": len(klice) + len(sprity_a),
            "box_item": list(sprity[0].size), "ok": True}


def main() -> int:
    mereni: list[dict] = []

    def bl(skript: str, args: list[str], ocek: list[str]):
        return [BLENDER, "-b", "-P", str(HERE / skript), "--", *args], ocek

    # 0) start Blenderu bez prace - aby se dal odcistat z kazdeho renderu
    start = spust("start Blenderu (bez prace)",
                  [BLENDER, "-b", "--python-expr", "print('START_OK')"], ["START_OK"])

    # 1) render 1x (dyka + postava) - do _timing1x, 1x sadu to nemeni
    c, o = bl("render_2x.py", ["--meritko", "1x", "--plan", "dagger"],
              ["RENDER_OK 1x dagger 1"])
    mereni.append(spust("render 1x: dyka (1 sprite)", c, o))
    c, o = bl("render_2x.py", ["--meritko", "1x", "--plan", "character0"],
              ["RENDER_OK 1x character0 8"])
    mereni.append(spust("render 1x: postava (8 framu)", c, o))

    # 2) render 2x - reference stinu se maze, aby se meril i ten pruchod
    for stary in RAW2X.glob("_ref_*.png"):
        stary.unlink()
    c, o = bl("render_2x.py", ["--meritko", "2x", "--plan", "dagger"],
              ["RENDER_OK 2x dagger 1"])
    mereni.append(spust("render 2x: dyka (1 sprite)", c, o))
    c, o = bl("render_2x.py", ["--meritko", "2x", "--plan", "character0"],
              ["RENDER_OK 2x character0 8"])
    mereni.append(spust("render 2x: postava (8 framu)", c, o))

    # 3) postprocess obou variant (in-process, stejna prace)
    t0 = time.perf_counter()
    pp1 = postprocess_1x()
    pp1["sekund"] = round(time.perf_counter() - t0, 3)
    print(f"[mereni] {'postprocess 1x (9 spritu)':34s} {pp1['sekund']:7.2f} s  OK")
    t0 = time.perf_counter()
    pp2 = postprocess_2x()
    pp2["sekund"] = round(time.perf_counter() - t0, 3)
    print(f"[mereni] {'postprocess 2x (9 spritu, +stin)':34s} {pp2['sekund']:7.2f} s  OK")

    # 4) cele zabaleni 2x sady (vcetne zapisu stranek a manifestu)
    mereni.append(spust("2x: zabaleni atlasu (zapis)",
                        [sys.executable, str(HERE / "pack_atlas_2x.py")], ["[check2x]"]))
    mereni.append(spust("2x: brana --check",
                        [sys.executable, str(HERE / "pack_atlas_2x.py"), "--check"],
                        ["[check2x]"]))
    mereni.append(spust("srovnavaci list 1x vs 2x",
                        [sys.executable, str(HERE / "srovnani_1x_2x.py")], ["[srovnani]"]))

    # 5) kontrola, ze 1x merici vetev dela TOTÉZ co pilot
    #    ⚠ NEMERI SE HASH SOUBORU: dva behy Blenderu daji RŮZNÉ bajty PNG
    #    (namEReno 2026-10-10: `d324e127828a` vs `f2d92a536d63` pro tentýž blend),
    #    a přitom PIXELY jsou shodné na 0. Hash souboru tedy o obsahu nevypovida;
    #    kontrola proto porovnava pixely.
    kontrola = {"pixely_shodne_s_pilotem": True, "max_rozdil_rgb": 0,
                "bbox_shodne": True, "souborove_hashy_odlisne": False}
    for dvojice in [(TIMING1X / "item_dagger.png", RAW1X / "item_dagger.png")] + \
                   [(TIMING1X / f"char_d0_f{f}.png", RAW1X / f"char_d0_f{f}.png")
                    for f in range(8)]:
        if hash_(dvojice[0]) != hash_(dvojice[1]):
            kontrola["souborove_hashy_odlisne"] = True
        a = Image.open(dvojice[0]).convert("RGBA")
        b = Image.open(dvojice[1]).convert("RGBA")
        if a.split()[3].getbbox() != b.split()[3].getbbox():
            kontrola["bbox_shodne"] = False
        rozdil = int(np.abs(np.asarray(a, dtype=np.int16)
                            - np.asarray(b, dtype=np.int16)).max())
        kontrola["max_rozdil_rgb"] = max(kontrola["max_rozdil_rgb"], rozdil)
        if rozdil != 0:
            kontrola["pixely_shodne_s_pilotem"] = False

    # 6) souhrn "kolik stoji 2x"
    def najdi(jmeno):
        return next((m for m in mereni if m["faze"] == jmeno), {})

    r1d, r2d = najdi("render 1x: dyka (1 sprite)"), najdi("render 2x: dyka (1 sprite)")
    r1p, r2p = najdi("render 1x: postava (8 framu)"), najdi("render 2x: postava (8 framu)")
    souhrn = {
        "start_blenderu_sekund": start["sekund"],
        "render_1x_dyka_sekund": r1d.get("sekund"),
        "render_2x_dyka_sekund": r2d.get("sekund"),
        "render_1x_postava8_sekund": r1p.get("sekund"),
        "render_2x_postava8_sekund": r2p.get("sekund"),
        "render_2x_dyka_passy": r2d.get("passy", {}),
        "render_2x_postava_passy": r2p.get("passy", {}),
        "postprocess_1x_9_spritu": pp1,
        "postprocess_2x_9_spritu": pp2,
        "kontrola_1x_proti_pilotu": kontrola,
    }
    (HERE / "_casy-2x.json").write_text(
        json.dumps({"mereni": mereni, "souhrn": souhrn}, ensure_ascii=False,
                   indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")

    print("\n[mereni] --- souhrn ---")
    for k in sorted(souhrn):
        print(f"[mereni] {k} = {souhrn[k]}")
    print(f"[mereni] vystup -> {HERE / '_casy-2x.json'}")
    spatne = [m for m in mereni if not m["ok"]]
    if not kontrola["pixely_shodne_s_pilotem"] or not kontrola["bbox_shodne"]:
        spatne.append({"faze": "1x merici vetev se lisi od pilotu", "ok": False})
    return 1 if spatne else 0


if __name__ == "__main__":
    raise SystemExit(main())
