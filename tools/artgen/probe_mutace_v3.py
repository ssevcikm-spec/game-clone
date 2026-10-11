# -*- coding: utf-8 -*-
"""probe_mutace_v3.py - MUTACNI TEST brany `pack_atlas_v3.py --check`.

  python tools/artgen/probe_mutace_v3.py

PROC: "Napsal jsi test? Vrať do kódu vadu a podívej se, že spadne." (skill
`overovani`). Brana, ktera se zelená, nemusi nic merit - proto se do HOTOVE sady
vlozi vzdy jedna vada, spusti se brana a ceka se, ze:
  1. skonci NENULOVYM kodem,
  2. a v textu bude KONKRETNI hlaska o vade (ne jen "neco spadlo").

⚠ MUTACE `plochy_stin_ztencen` JE SPECIFICKA PRO V3: z dyky (plochy predmet) se
stin zmensi na 1px lem - tedy PRESNE vada, ktera se opravovala. Kdyby brana
tuhle mutaci neodhalila, "stin placateho predmetu je opraveny" by nebylo nicim
kryte a oprava by se dala tise vratit.

Mutuje se VZDY jen jedna vec a po kazde mutaci se soubor vrati z bajtove zalohy
(`finally`), takze sada zustane nedotcena - na konci se to overi zelenou branou.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import artgen_common_lit as acl   # noqa: E402
import artgen_common_v3 as acv    # noqa: E402

OWN = acv.SADA
BRANA = HERE / "pack_atlas_v3.py"
PLOCHE_ID = 3921


def spust_branu() -> tuple[int, str]:
    p = subprocess.run([sys.executable, str(BRANA), "--check"],
                       cwd=str(HERE.parent.parent), capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    return p.returncode, (p.stdout or "") + (p.stderr or "")


def _stranka(kind: str = "item", ident: int = PLOCHE_ID):
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    s = next(x for x in m["sprites"] if x["kind"] == kind and x["id"] == ident)
    return OWN / s["page"], s


def _stin_maska(v: np.ndarray) -> np.ndarray:
    alfa = v[:, :, 3]
    barva = (v[:, :, :3] == np.array(acl.STIN_BARVA, dtype=np.uint8)).all(axis=2)
    return (alfa > 0) & (alfa < 200) & barva


def mutace_plochy_stin_ztencen() -> None:
    """Plochemu predmetu se stin zmensi na 1px lem (vada, ktera se opravovala)."""
    cesta, s = _stranka()
    img = Image.open(cesta).convert("RGBA")
    a = np.array(img)
    x, y, w, h = s["x"], s["y"], s["w"], s["h"]
    v = a[y:y + h, x:x + w]
    stin = _stin_maska(v)
    # nech jen pixely, ktere se dotykaji tela (1px lem)
    telo = v[:, :, 3] >= 200
    lem = stin & ndimage.binary_dilation(telo, iterations=1)
    v[:, :, 3] = np.where(stin & ~lem, 0, v[:, :, 3]).astype(np.uint8)
    a[y:y + h, x:x + w] = v
    Image.fromarray(a, "RGBA").save(cesta)


def mutace_plochy_stin_ztloustly() -> None:
    """Stin se prevede na plnou alfu - splyne s objektem (a rozjede obsah)."""
    cesta, s = _stranka()
    img = Image.open(cesta).convert("RGBA")
    a = np.array(img)
    x, y, w, h = s["x"], s["y"], s["w"], s["h"]
    v = a[y:y + h, x:x + w]
    v[:, :, 3] = np.where(_stin_maska(v), 255, v[:, :, 3]).astype(np.uint8)
    a[y:y + h, x:x + w] = v
    Image.fromarray(a, "RGBA").save(cesta)


def mutace_kotva_posunuta() -> None:
    cesta = OWN / "manifest.json"
    d = json.loads(cesta.read_text(encoding="utf-8"))
    s = next(x for x in d["sprites"] if x["kind"] == "item")
    s["oy"] = s["oy"] + 1
    cesta.write_text(json.dumps(d, ensure_ascii=False, sort_keys=True, indent=1) + "\n",
                     encoding="utf-8", newline="\n")


def mutace_recept_v_manifestu() -> None:
    """Do manifestu se zapise jina sila stinu, nez pouziva zivy recept."""
    cesta = OWN / "manifest.json"
    d = json.loads(cesta.read_text(encoding="utf-8"))
    d["source"]["svetlo_recept"]["stin_sila"] = 0.99
    cesta.write_text(json.dumps(d, ensure_ascii=False, sort_keys=True, indent=1) + "\n",
                     encoding="utf-8", newline="\n")


def mutace_manifest_zmenen() -> None:
    cesta = OWN / "manifest.json"
    cesta.write_bytes(cesta.read_bytes() + b" ")


def mutace_stranka_chybi() -> None:
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    cesta = OWN / m["pages"][0]["file"]
    cesta.rename(cesta.with_suffix(".png__mrizek"))


def vrat_stranku() -> None:
    for c in OWN.glob("atlas/*.png__mrizek"):
        c.rename(c.with_suffix("").with_suffix(".png"))


MUTACE = [
    ("plochy_stin_ztencen", "dyce se stin zmensi na 1px lem (vada z ZADANI-25 §11)",
     ("PLACHY predmet", "viditelny stin ma"), mutace_plochy_stin_ztencen, None),
    ("plochy_stin_ztloustly", "stin se prevede na plnou alfu (splyne s objektem)",
     ("plne pixely maji barvu stinu", "NENI videt kontaktni stin"),
     mutace_plochy_stin_ztloustly, None),
    ("kotva_posunuta", "v manifestu se posune oy o 1 px",
     ("neni vzorec UO",), mutace_kotva_posunuta, None),
    ("recept_v_manifestu", "manifest tvrdi jinou silu stinu, nez zivy recept",
     ("silu stinu",), mutace_recept_v_manifestu, None),
    ("manifest_zmenen", "do manifestu se prida bila mezera (determinismus)",
     ("determinismu",), mutace_manifest_zmenen, None),
    ("stranka_chybi", "stranka atlasu se prejmenuje",
     ("chybi stranka",), mutace_stranka_chybi, vrat_stranku),
]


def main() -> int:
    rc0, out0 = spust_branu()
    if rc0 != 0:
        print("[mutacev3] CHYBA: brana neni zelena ani pred mutacemi - "
              "mutacni test by meril neco jineho")
        print(out0[-2000:])
        return 1
    print("[mutacev3] pred mutacemi: brana zelena (0 chyb) - ted se vklada vada")

    vysledky = []
    for jmeno, popis, ocekavane, mutuj, uklid in MUTACE:
        cesta_manifestu = OWN / "manifest.json"
        cesta_stranky, _s = _stranka()
        zalohy = {cesta_manifestu: cesta_manifestu.read_bytes(),
                  cesta_stranky: cesta_stranky.read_bytes()}
        try:
            mutuj()
            rc, out = spust_branu()
            nalezene = [t for t in ocekavane if t in out]
            odhaleno = rc != 0 and bool(nalezene)
            vysledky.append({"mutace": jmeno, "popis": popis, "odhaleno": odhaleno,
                             "navratovy_kod": rc, "ocekavane_texty": list(ocekavane),
                             "nalezene_texty": nalezene})
            print(f"[mutacev3] {jmeno:22s} "
                  f"{'ODHALENO' if odhaleno else 'NEODHALENO':10s} (rc={rc}, "
                  f"hledano: {' | '.join(ocekavane)})")
            if not odhaleno:
                for radek in out.splitlines()[-12:]:
                    print("   " + radek)
        finally:
            for c, data in zalohy.items():
                c.write_bytes(data)
            if uklid is not None:
                uklid()

    rc1, out1 = spust_branu()
    print(f"[mutacev3] po vraceni zavad: brana {'zelena' if rc1 == 0 else 'CERVENA'}")
    if rc1 != 0:
        print(out1[-2000:])
    neodhalene = [v for v in vysledky if not v["odhaleno"]]
    print(f"[mutacev3] odhaleno {len(vysledky) - len(neodhalene)}/{len(vysledky)} mutaci")
    (HERE / "_mutace-v3.json").write_text(json.dumps(
        {"co_to_je": "mutacni test brany pack_atlas_v3.py --check",
         "mutace": vysledky}, ensure_ascii=False, indent=1, sort_keys=True) + "\n",
        encoding="utf-8", newline="\n")
    return 1 if (neodhalene or rc1 != 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
