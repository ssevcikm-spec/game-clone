# -*- coding: utf-8 -*-
"""mereni_svetlo.py - kolik stoji SVETLO na 1x sade (render i postprocess).

  python tools/artgen/mereni_svetlo.py
      -> tools/artgen/_casy-svetlo.json  + tabulka na obrazovku

PROC VZNIKL: `MERENI.md` ma casy 1x pilotu (46 spritu, tri slunce, bez stinu)
a casy 2x vetve - ale "kolik stoji pridat svetlo do 1x" se z nich spocitat neda.
Tenhle skript meri OBE varianty TADY a TEĎ, na stejne praci:

    dyka:       1 sprite          (1x bez svetla  vs  1x se svetlem)
    postava:    8 framu smeru 0   (1x bez svetla  vs  1x se svetlem)
    postprocess: techtez 9 spritu (1x bez svetla  vs  1x se svetlem)
    + cela sada: 46 spritu se svetlem (render i zabaleni)

Cim se meri:
  * render - `subprocess` + `perf_counter` (cely beh Blenderu vcetne startu);
    skripty pritom vypisuji `CAS pass=...`, takze se z toho da odcistat start
    Blenderu a rozdelit kreativni pruchod / stin / referenci.
  * postprocess - `perf_counter` IN-PROCESS (zadny start Pythonu, zadny zapis),
    aby se porovnavalo to same.

⚠ 1x sada se NEMENI: "1x bez svetla" se renderuje vetvi, ktera uz existuje
(`render_2x.py --meritko 1x`, vystup do `_raw2x/_timing1x/`) a je overene, ze
dava pixel za pixel to, co `render_sprites.py` (2x vetev to zmerila: 9/9
snimku, max|rozdil| = 0). Do `raw/` ani do `assets/own/` se NESAHA.
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
sys.path.insert(0, str(HERE))

RAW1X = HERE / "raw"                       # jen CTEME (1x sada bez svetla)
TIMING1X = HERE / "_raw2x" / "_timing1x"   # 1x render z merici vetve 2x skriptu
TIMING_LIT = HERE / "_rawlit" / "_timing-lit"


def spust(jmeno: str, cmd: list[str], ocekavane: list[str]) -> dict:
    t0 = time.perf_counter()
    p = subprocess.run(cmd, cwd=str(REPO), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    trvani = time.perf_counter() - t0
    vystup = (p.stdout or "") + (p.stderr or "")
    chybejici = [v for v in ocekavane if v not in vystup]
    ok = p.returncode == 0 and not chybejici
    soucet: dict[str, float] = {}
    pocet: dict[str, int] = {}
    for m in re.finditer(r"CAS pass=(\w+) sekund=([\d.]+)", vystup):
        soucet[m.group(1)] = soucet.get(m.group(1), 0.0) + float(m.group(2))
        pocet[m.group(1)] = pocet.get(m.group(1), 0) + 1
    passy = {k: {"soucet": round(v, 2), "pocet": pocet[k],
                 "na_kus": round(v / pocet[k], 3)} for k, v in soucet.items()}
    print(f"[mereni] {jmeno:38s} {trvani:7.2f} s  {'OK' if ok else 'CHYBA'}"
          + (f"  chybi: {chybejici}" if chybejici else ""))
    if passy:
        print("           " + "  ".join(f"{k}={v['soucet']}s/{v['pocet']}x"
                                        for k, v in sorted(passy.items())))
    if not ok:
        for radek in vystup.splitlines()[-20:]:
            print("   " + radek)
    return {"faze": jmeno, "sekund": round(trvani, 2), "ok": ok, "passy": passy,
            "navratovy_kod": p.returncode, "ocekavano": ocekavane}


def _origin(cesta: Path) -> tuple[float, float]:
    o = json.loads(cesta.read_text(encoding="utf-8"))
    return (o["origin_x"], o["origin_y"])


def postprocess_1x() -> dict:
    """1x postprocess 9 spritu (dyka + 8 framu) IN-PROCESS, bez zapisu."""
    import artgen_common as ac1
    import postprocess as pp
    t0 = time.perf_counter()
    p = pp.priprav(TIMING1X / "item_dagger.png", _origin(TIMING1X / "_origin_item_dagger.json"))
    s = pp.meritko([p], obsah_vyska_px=ac1.ITEMS[0]["uo_content"][1])
    sprity, _m = pp.sestav([p], s, "item", popis="dagger")
    t_item = time.perf_counter() - t0
    o = _origin(TIMING1X / "_origin_character.json")
    t1 = time.perf_counter()
    pripr = [pp.priprav(TIMING1X / f"char_d0_f{f}.png", o) for f in range(ac1.CHAR["frames"])]
    s = pp.meritko(pripr, obsah_vyska_px=ac1.CHAR["cil_obsah_px"])
    pp.sestav(pripr, s, "anim", popis="character")
    t_anim = time.perf_counter() - t1
    return {"sekund": round(t_item + t_anim, 3), "item": round(t_item, 3),
            "anim_8_framu": round(t_anim, 3), "spritu": 1 + ac1.CHAR["frames"],
            "box_item": list(sprity[0].size), "ok": True}


def postprocess_lit() -> dict:
    """1x postprocess se svetlem, týchž 9 spritu, vcetne vrstvy stinu."""
    import artgen_common_lit as acl
    import postprocess_lit as ppl
    t0 = time.perf_counter()
    p = ppl.priprav(TIMING_LIT / "item_dagger.png", _origin(TIMING_LIT / "_origin_item_dagger.json"),
                    stin=TIMING_LIT / "_stin_item_dagger.png",
                    ref=TIMING_LIT / "_ref_item_dagger.png")
    s = ppl.meritko([p], obsah_vyska_px=acl.ITEMS[0]["uo_content"][1])
    sprity, meta = ppl.sestav([p], s, "item", popis="dagger")
    t_item = time.perf_counter() - t0
    o = _origin(TIMING_LIT / "_origin_character.json")
    t1 = time.perf_counter()
    pripr = [ppl.priprav(TIMING_LIT / f"char_d0_f{f}.png", o,
                         stin=TIMING_LIT / f"_stin_char_d0_f{f}.png",
                         ref=TIMING_LIT / "_ref_character.png")
             for f in range(acl.CHAR["frames"])]
    s = ppl.meritko(pripr, obsah_vyska_px=acl.CHAR["cil_obsah_px"])
    _sprity, meta_a = ppl.sestav(pripr, s, "anim", popis="character")
    t_anim = time.perf_counter() - t1
    return {"sekund": round(t_item + t_anim, 3), "item": round(t_item, 3),
            "anim_8_framu": round(t_anim, 3), "spritu": 1 + acl.CHAR["frames"],
            "box_item": list(sprity[0].size), "ok": True,
            "stin_viditelne_px_item": meta[0]["stin_viditelne_px"],
            "stin_viditelne_px_anim": sorted({m["stin_viditelne_px"] for m in meta_a}),
            "box_anim": sorted({(m["w"], m["h"]) for m in meta_a})}


def postprocess_sada(se_svetlem: bool) -> dict:
    """Postprocess CELE sady (46 spritu) IN-PROCESS - 1x sada se neZAPISUJE."""
    import artgen_common as ac1
    t0 = time.perf_counter()
    if se_svetlem:
        import pack_atlas_lit as pk
        klice, sprity, meta = pk.davka_land()
        k2, s2, m2 = pk.davka_item()
        k3, s3, m3 = pk.davka_anim()
        n = len(klice) + len(k2) + len(k3)
        stin = [m["stin_viditelne_px"] for m in list(m2) + list(m3)]
    else:
        import pack_atlas as pk1
        klice, sprity, meta = pk1.davka_land()
        k2, s2, m2 = pk1.davka_item()
        k3, s3, m3 = pk1.davka_anim()
        n = len(klice) + len(k2) + len(k3)
        stin = []
    return {"sekund": round(time.perf_counter() - t0, 2), "spritu": n,
            "stin_viditelne_px": stin, "ok": True}


def main() -> int:
    mereni: list[dict] = []

    def bl(skript: str, args: list[str], ocek: list[str]):
        return [BLENDER, "-b", "-P", str(HERE / skript), "--", *args], ocek

    # 0) start Blenderu bez prace - aby se dal odcistat z kazdeho renderu
    start = spust("start Blenderu (bez prace)",
                  [BLENDER, "-b", "--python-expr", "print('START_OK')"], ["START_OK"])

    # 1) render 1x BEZ svetla (dva pruchody: kreativni jen jednou - neni stin)
    c, o = bl("render_2x.py", ["--meritko", "1x", "--plan", "dagger"],
              ["RENDER_OK 1x dagger 1"])
    mereni.append(spust("render 1x bez svetla: dyka (1 sprite)", c, o))
    c, o = bl("render_2x.py", ["--meritko", "1x", "--plan", "character0"],
              ["RENDER_OK 1x character0 8"])
    mereni.append(spust("render 1x bez svetla: postava (8 framu)", c, o))

    # 2) render 1x SE svetlem (tri pruchody: kreativni + reference + stin)
    for stary in TIMING_LIT.glob("_ref_*.png") if TIMING_LIT.exists() else []:
        stary.unlink()                     # aby se meril i pruchod reference
    c, o = bl("render_lit.py", ["--plan", "dagger"], ["RENDER_OK lit dagger 1"])
    mereni.append(spust("render 1x se svetlem: dyka (1 sprite)", c, o))
    c, o = bl("render_lit.py", ["--plan", "character0"], ["RENDER_OK lit character0 8"])
    mereni.append(spust("render 1x se svetlem: postava (8 framu)", c, o))

    # 3) postprocess obou variant (in-process, stejna prace)
    for jmeno, fn in (("postprocess 1x bez svetla (9 spritu)", lambda: postprocess_1x()),
                      ("postprocess 1x se svetlem (9 spritu, +stin)",
                       lambda: postprocess_lit())):
        t0 = time.perf_counter()
        v = fn()
        v["sekund"] = round(time.perf_counter() - t0, 3)
        print(f"[mereni] {jmeno:38s} {v['sekund']:7.2f} s  OK")
        mereni.append({"faze": jmeno, "sekund": v["sekund"], "ok": True, "passy": {},
                       "detail": v})
        if jmeno.endswith("+stin)"):
            pp_lit = v

    # 4) postprocess CELE sady (46 spritu) v obou variantach, in-process
    t0 = time.perf_counter()
    sada1 = postprocess_sada(False)
    print(f"[mereni] {'postprocess cele 1x sady bez svetla (46)':38s} "
          f"{sada1['sekund']:7.2f} s  OK")
    mereni.append({"faze": "postprocess cele 1x sady bez svetla (46)",
                   "sekund": sada1["sekund"], "ok": True, "passy": {}, "detail": sada1})
    sada2 = postprocess_sada(True)
    print(f"[mereni] {'postprocess cele 1x sady se svetlem (46)':38s} "
          f"{sada2['sekund']:7.2f} s  OK")
    mereni.append({"faze": "postprocess cele 1x sady se svetlem (46)",
                   "sekund": sada2["sekund"], "ok": True, "passy": {}, "detail": sada2})

    # 5) render a zabaleni CELE sady se svetlem (zapis do assets/own-lit/)
    c, o = bl("render_lit.py", ["--plan", "tiles"], ["RENDER_OK lit tiles 2"])
    mereni.append(spust("render 1x se svetlem: dlazdice (2 sprity)", c, o))
    c, o = bl("render_lit.py", ["--plan", "items"], ["RENDER_OK lit items 4"])
    mereni.append(spust("render 1x se svetlem: predmety (4 sprity)", c, o))
    c, o = bl("render_lit.py", ["--plan", "character"], ["RENDER_OK lit character 40"])
    mereni.append(spust("render 1x se svetlem: postava (40 spritu)", c, o))
    mereni.append(spust("zabalit lit atlas (46 spritu, zapis)",
                        [sys.executable, str(HERE / "pack_atlas_lit.py")], ["[checklit]"]))

    def najdi(jmeno):
        return next((m for m in mereni if m["faze"] == jmeno), {})

    d1 = najdi("render 1x bez svetla: dyka (1 sprite)")
    d2 = najdi("render 1x se svetlem: dyka (1 sprite)")
    p1 = najdi("render 1x bez svetla: postava (8 framu)")
    p2 = najdi("render 1x se svetlem: postava (8 framu)")
    pp1 = najdi("postprocess 1x bez svetla (9 spritu)")
    pp2 = najdi("postprocess 1x se svetlem (9 spritu, +stin)")
    souhrn = {
        "start_blenderu_sekund": start["sekund"],
        "render_bez_svetla_dyka_sekund": d1.get("sekund"),
        "render_se_svetlem_dyka_sekund": d2.get("sekund"),
        "render_bez_svetla_postava8_sekund": p1.get("sekund"),
        "render_se_svetlem_postava8_sekund": p2.get("sekund"),
        "render_se_svetlem_dyka_passy": d2.get("passy", {}),
        "render_se_svetlem_postava_passy": p2.get("passy", {}),
        "render_bez_svetla_postava_passy": p1.get("passy", {}),
        "postprocess_bez_svetla_9_spritu": pp1.get("detail") or pp1,
        "postprocess_se_svetlem_9_spritu": pp2.get("detail") or pp2,
        "postprocess_bez_svetla_46_spritu": sada1,
        "postprocess_se_svetlem_46_spritu": sada2,
        "render_se_svetlem_cela_sada_sekund": round(sum(
            najdi(j).get("sekund", 0.0) for j in
            ("render 1x se svetlem: dlazdice (2 sprity)",
             "render 1x se svetlem: predmety (4 sprity)",
             "render 1x se svetlem: postava (40 spritu)")), 2),
        "zabaleni_lit_atlasu_sekund": najdi("zabalit lit atlas (46 spritu, zapis)").get("sekund"),
    }
    # prepocet na kus (bez startu Blenderu ~1,5 s na spusteni)
    if all(isinstance(souhrn[k], (int, float)) for k in
           ("render_bez_svetla_dyka_sekund", "render_se_svetlem_dyka_sekund",
            "render_bez_svetla_postava8_sekund", "render_se_svetlem_postava8_sekund")):
        souhrn["na_sprite_bez_svetla_sekund"] = round(
            (souhrn["render_bez_svetla_dyka_sekund"] + souhrn["render_bez_svetla_postava8_sekund"]
             + (pp1.get("detail") or pp1).get("sekund", 0)) / 9.0, 3)
        souhrn["na_sprite_se_svetlem_sekund"] = round(
            (souhrn["render_se_svetlem_dyka_sekund"] + souhrn["render_se_svetlem_postava8_sekund"]
             + (pp2.get("detail") or pp2).get("sekund", 0)) / 9.0, 3)
        souhrn["pomer_se_svetlem_proti_bez"] = round(
            souhrn["na_sprite_se_svetlem_sekund"] / souhrn["na_sprite_bez_svetla_sekund"], 3)

    (HERE / "_casy-svetlo.json").write_text(
        json.dumps({"mereni": mereni, "souhrn": souhrn}, ensure_ascii=False,
                   indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")

    print("\n[mereni] --- souhrn ---")
    for k in sorted(souhrn):
        print(f"[mereni] {k} = {souhrn[k]}")
    print(f"[mereni] vystup -> {HERE / '_casy-svetlo.json'}")
    spatne = [m for m in mereni if not m["ok"]]
    return 1 if spatne else 0


if __name__ == "__main__":
    raise SystemExit(main())
