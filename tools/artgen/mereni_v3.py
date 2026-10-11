# -*- coding: utf-8 -*-
"""mereni_v3.py - kolik stoji sada v3 (stin v3 + vypln) proti v2.

  python tools/artgen/mereni_v3.py
      -> tools/artgen/_casy-v3.json + tabulka na obrazovku

CO SE MERI (vsechno TADY a TEĎ, na stejne praci):
  1. **postprocess 9 spritu** (dyka + 8 framu smeru 0) IN-PROCESS:
     recept v2 (radialni ubytek) vs recept v3 (pas od obrysu + posun).
     To je jedina cast pipeline, ktera se u v3 ZMENILA ve zpracovani pixelu.
  2. **render 9 spritu** - dve vetve, kazda svym skriptem:
     `render_lit.py` (1 slunce) vs `render_v3.py` (1 slunce + vypln).
     Vypln je DRUHE svetlo, takze se ceká dražší render; cislo to overí.
  3. **cela sada 46 spritu**: render (3 plany) + zabaleni atlasu.

⚠ POZOR NA VYSLEDEK, KTERY VYPADA JAKO VADA A NENI: u v3 je `na 1 sprite`
  VYSSI hlavne kvuli postprocessu (v3 pocita vzdalenost od obrysu na vetsim
  platne), ne kvuli renderu - proto se obe casti hlasí ZVLAST.
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

TIMING_LIT = HERE / "_rawlit" / "_timing-lit"
TIMING_V3 = HERE / "_rawv3" / "_timing-v3"


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
    print(f"[mereniv3] {jmeno:44s} {trvani:7.2f} s  {'OK' if ok else 'CHYBA'}"
          + (f"  chybi: {chybejici}" if chybejici else ""))
    if passy:
        print("            " + "  ".join(f"{k}={v['soucet']}s/{v['pocet']}x"
                                         for k, v in sorted(passy.items())))
    if not ok:
        for radek in vystup.splitlines()[-20:]:
            print("   " + radek)
    return {"faze": jmeno, "sekund": round(trvani, 2), "ok": ok, "passy": passy,
            "navratovy_kode": p.returncode, "ocekavano": ocekavane}


def _origin(cesta: Path):
    o = json.loads(cesta.read_text(encoding="utf-8"))
    return (o["origin_x"], o["origin_y"])


def _postprocess(slozka: Path, recept: str) -> dict:
    """Postprocess 9 spritu (dyka + 8 framu) IN-PROCESS, bez zapisu."""
    import postprocess_lit as ppl
    ppl.nastav_recept_stinu(recept)
    t0 = time.perf_counter()
    p = ppl.priprav(slozka / "item_dagger.png",
                    _origin(slozka / "_origin_item_dagger.json"),
                    stin=slozka / "_stin_item_dagger.png",
                    ref=slozka / "_ref_item_dagger.png")
    s = ppl.meritko([p], obsah_vyska_px=ppl.acl.ITEMS[0]["uo_content"][1])
    sprity, meta = ppl.sestav([p], s, "item", popis="dagger")
    t_item = time.perf_counter() - t0
    o = _origin(slozka / "_origin_character.json")
    t1 = time.perf_counter()
    pripr = [ppl.priprav(slozka / f"char_d0_f{f}.png", o,
                         stin=slozka / f"_stin_char_d0_f{f}.png",
                         ref=slozka / "_ref_character.png")
             for f in range(ppl.acl.CHAR["frames"])]
    s = ppl.meritko(pripr, obsah_vyska_px=ppl.acl.CHAR["cil_obsah_px"])
    _sprity, meta_a = ppl.sestav(pripr, s, "anim", popis="character")
    t_anim = time.perf_counter() - t1
    return {"sekund": round(t_item + t_anim, 3), "item": round(t_item, 3),
            "anim_8_framu": round(t_anim, 3), "spritu": 1 + ppl.acl.CHAR["frames"],
            "box_item": list(sprity[0].size),
            "box_anim": sorted({(m["w"], m["h"]) for m in meta_a}),
            "stin_viditelne_px_item": meta[0]["stin_viditelne_px"],
            "stin_viditelne_px_anim": sorted({m["stin_viditelne_px"] for m in meta_a}),
            "recept": recept}


def postprocess_sada(recept: str) -> dict:
    """Postprocess CELE v3 sady (46 spritu) IN-PROCESS; zapisuje jen do pameti."""
    import pack_atlas_v3 as pk
    import postprocess_lit as ppl
    ppl.nastav_recept_stinu(recept)
    t0 = time.perf_counter()
    k1, s1, m1 = pk.davka_land()
    k2, s2, m2 = pk.davka_item()
    k3, s3, m3 = pk.davka_anim()
    n = len(k1) + len(k2) + len(k3)
    stin = [m["stin_viditelne_px"] for m in list(m2) + list(m3)]
    return {"sekund": round(time.perf_counter() - t0, 2), "spritu": n,
            "stin_viditelne_px": stin, "recept": recept, "ok": True}


def main() -> int:
    mereni: list[dict] = []
    if not TIMING_LIT.exists():
        raise SystemExit(f"chybi {TIMING_LIT} - spust `mereni_svetlo.py` (v2 casy)")
    if not TIMING_V3.exists():
        raise SystemExit(f"chybi {TIMING_V3} - spust nejdriv merici render:\n"
                         "  & blender.exe -b -P tools\\artgen\\render_v3.py -- "
                         "--plan timing --jen dagger\n"
                         "  & blender.exe -b -P tools\\artgen\\render_v3.py -- "
                         "--plan timing --jen character")
    start = spust("start Blenderu (bez prace)",
                  [BLENDER, "-b", "--python-expr", "print('START_OK')"], ["START_OK"])

    # 1) postprocess obou receptu na TECHZ vstupech (`_rawv3/`)
    post = {}
    for jmeno, recept in (("postprocess v2 recept (9 spritu)", "v2"),
                          ("postprocess v3 recept (9 spritu)", "v3")):
        t0 = time.perf_counter()
        v = _postprocess(TIMING_V3, recept)
        v["sekund"] = round(time.perf_counter() - t0, 3)
        post[recept] = v
        print(f"[mereniv3] {jmeno:44s} {v['sekund']:7.2f} s  OK  "
              f"stin item {v['stin_viditelne_px_item']} px, anim {v['stin_viditelne_px_anim']}")
        mereni.append({"faze": jmeno, "sekund": v["sekund"], "ok": True,
                       "passy": {}, "detail": v})

    # 2) cela sada - postprocess v obou receptech (in-process)
    sada = {}
    for recept in ("v2", "v3"):
        v = postprocess_sada(recept)
        sada[recept] = v
        print(f"[mereniv3] {'postprocess cele sady, recept ' + recept:44s} "
              f"{v['sekund']:7.2f} s  OK")
        mereni.append({"faze": f"postprocess cele sady, recept {recept}",
                       "sekund": v["sekund"], "ok": True, "passy": {}, "detail": v})
    import postprocess_lit as ppl
    ppl.nastav_recept_stinu("v2")     # global se vraci zpet

    # 3) render 9 spritu obema vetvemi
    for stary in TIMING_V3.glob("_ref_*.png"):
        stary.unlink()
    mereni.append(spust("render v3: dyka (1 sprite)",
                        [BLENDER, "-b", "-P", str(HERE / "render_v3.py"), "--",
                         "--plan", "timing", "--jen", "dagger"],
                        ["RENDER_OK_V3 timing"]))
    mereni.append(spust("render v3: postava (8 framu)",
                        [BLENDER, "-b", "-P", str(HERE / "render_v3.py"), "--",
                         "--plan", "timing", "--jen", "character"],
                        ["RENDER_OK_V3 timing"]))
    for stary in TIMING_LIT.glob("_ref_*.png"):
        stary.unlink()
    mereni.append(spust("render v2 (lit): dyka (1 sprite)",
                        [BLENDER, "-b", "-P", str(HERE / "render_lit.py"), "--",
                         "--plan", "dagger"], ["RENDER_OK lit dagger 1"]))
    mereni.append(spust("render v2 (lit): postava (8 framu)",
                        [BLENDER, "-b", "-P", str(HERE / "render_lit.py"), "--",
                         "--plan", "character0"], ["RENDER_OK lit character0 8"]))

    # 4) cela sada 46 spritu - render i zabaleni (zapisuje se do assets/own-v3/)
    for plan, ocek in (("tiles", "RENDER_OK_V3 tiles 2"),
                       ("items", "RENDER_OK_V3 items 4"),
                       ("character", "RENDER_OK_V3 character 40")):
        mereni.append(spust(f"render v3: {plan}",
                            [BLENDER, "-b", "-P", str(HERE / "render_v3.py"), "--",
                             "--plan", plan], [ocek]))
    mereni.append(spust("zabalit v3 atlas (46 spritu, zapis)",
                        [sys.executable, str(HERE / "pack_atlas_v3.py")], ["[checkv3]"]))

    def najdi(jmeno):
        return next((m for m in mereni if m["faze"] == jmeno), {})

    d3 = najdi("render v3: dyka (1 sprite)")
    d2 = najdi("render v2 (lit): dyka (1 sprite)")
    p3 = najdi("render v3: postava (8 framu)")
    p2 = najdi("render v2 (lit): postava (8 framu)")
    pp2, pp3 = post.get("v2", {}), post.get("v3", {})
    souhrn = {
        "start_blenderu_sekund": start["sekund"],
        "render_dyka_v2_sekund": d2.get("sekund"), "render_dyka_v3_sekund": d3.get("sekund"),
        "render_postava8_v2_sekund": p2.get("sekund"),
        "render_postava8_v3_sekund": p3.get("sekund"),
        "render_dyka_passy_v3": d3.get("passy", {}),
        "render_postava_passy_v3": p3.get("passy", {}),
        "postprocess_9_v2_sekund": pp2.get("sekund"),
        "postprocess_9_v3_sekund": pp3.get("sekund"),
        "postprocess_9_v2_detail": pp2, "postprocess_9_v3_detail": pp3,
        "postprocess_sada_v2_sekund": sada.get("v2", {}).get("sekund"),
        "postprocess_sada_v3_sekund": sada.get("v3", {}).get("sekund"),
        "render_v3_cela_sada_sekund": round(sum(
            najdi(j).get("sekund", 0.0) for j in ("render v3: tiles", "render v3: items",
                                                  "render v3: character")), 2),
        "zabaleni_v3_atlasu_sekund": najdi("zabalit v3 atlas (46 spritu, zapis)").get("sekund"),
    }
    if all(isinstance(souhrn[k], (int, float)) for k in
           ("render_dyka_v2_sekund", "render_dyka_v3_sekund",
            "render_postava8_v2_sekund", "render_postava8_v3_sekund")):
        souhrn["na_sprite_v2_sekund"] = round(
            (souhrn["render_dyka_v2_sekund"] + souhrn["render_postava8_v2_sekund"]
             + pp2.get("sekund", 0)) / 9.0, 3)
        souhrn["na_sprite_v3_sekund"] = round(
            (souhrn["render_dyka_v3_sekund"] + souhrn["render_postava8_v3_sekund"]
             + pp3.get("sekund", 0)) / 9.0, 3)
        souhrn["pomer_v3_proti_v2"] = round(
            souhrn["na_sprite_v3_sekund"] / souhrn["na_sprite_v2_sekund"], 3)

    (HERE / "_casy-v3.json").write_text(
        json.dumps({"mereni": mereni, "souhrn": souhrn}, ensure_ascii=False,
                   indent=1, sort_keys=True) + "\n", encoding="utf-8", newline="\n")
    print("\n[mereniv3] --- souhrn ---")
    for k in sorted(souhrn):
        print(f"[mereniv3] {k} = {souhrn[k]}")
    print(f"[mereniv3] vystup -> {HERE / '_casy-v3.json'}")
    spatne = [m for m in mereni if not m["ok"]]
    return 1 if spatne else 0


if __name__ == "__main__":
    raise SystemExit(main())
