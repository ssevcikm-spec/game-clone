# -*- coding: utf-8 -*-
"""probe_mutace_lit.py - MUTACNI TEST brany `pack_atlas_lit.py --check`.

  python tools/artgen/probe_mutace_lit.py

PROC: "Napsal jsi test? Vrať do kódu vadu a podívej se, že spadne." (skill
`overovani`). Brana, která se zelená, nemusí nic měřit - proto se do HOTOVE sady
vloží vždy jedna vada, spustí se brana a čeká se, že:
  1. skončí NENULOVYM kodem,
  2. a v textu bude KONKRETNI hlaska o te vade (ne jen "neco spadlo" - jinak by
     mohlo jit o jinou chybu, ktera s mutaci nesouvisi).

Mutuje se VŽDY jen jedna vec a po kazde mutaci se soubor vrati z bajtove zalohy
(`finally`), takze sada zustane nedotcena - na konci se to overi zelenou branou.

Mutace (kazda odpovida vlastnosti, kterou brana tvrdi):
  * `stin_smazan`  - z jednoho predmetu se smaze vrstva stinu  -> "NENI videt
    kontaktni stin" (a rozchod s tim, co tvrdi manifest),
  * `stin_ztloustly` - stin se prevede na PLNOU alfu (byl by to "objem") ->
    obsah objektu se rozjede proti kotve,
  * `kotva_posunuta` - v manifestu se posune `oy` o 1 px -> kotva neni vzorec UO,
  * `manifest_zmenen` - do manifestu se prida bila mezera -> determinismus
    (baseline SHA) prestane sedet,
  * `stranka_chybi`  - stranka atlasu se prejmenuje -> brana to musi rict.

Vystup: tabulka na obrazovku; navratovy kod 0 = vsechny mutace byly odhaleny.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import artgen_common_lit as acl  # noqa: E402

OWN = acl.SADA
BRANA = HERE / "pack_atlas_lit.py"


def spust_branu() -> tuple[int, str]:
    p = subprocess.run([sys.executable, str(BRANA), "--check"], cwd=str(HERE.parent.parent),
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    return p.returncode, (p.stdout or "") + (p.stderr or "")


def _zaloha(cesta: Path) -> bytes:
    return cesta.read_bytes()


def _vrat(cesta: Path, data: bytes) -> None:
    cesta.write_bytes(data)


def _stranka_item() -> Path:
    m = json.loads((OWN / "manifest.json").read_text(encoding="utf-8"))
    s = next(x for x in m["sprites"] if x["kind"] == "item")
    return OWN / s["page"], s


def mutace_stin_smazan() -> None:
    cesta, s = _stranka_item()
    img = Image.open(cesta).convert("RGBA")
    a = np.array(img)
    x, y, w, h = s["x"], s["y"], s["w"], s["h"]
    v = a[y:y + h, x:x + w]
    alfa = v[:, :, 3]
    barva = (v[:, :, :3] == np.array(acl.STIN_BARVA, dtype=np.uint8)).all(axis=2)
    v[:, :, 3] = np.where((alfa > 0) & (alfa < 200) & barva, 0, alfa).astype(np.uint8)
    a[y:y + h, x:x + w] = v
    Image.fromarray(a, "RGBA").save(cesta)


def mutace_stin_ztloustly() -> None:
    cesta, s = _stranka_item()
    img = Image.open(cesta).convert("RGBA")
    a = np.array(img)
    x, y, w, h = s["x"], s["y"], s["w"], s["h"]
    v = a[y:y + h, x:x + w]
    alfa = v[:, :, 3]
    barva = (v[:, :, :3] == np.array(acl.STIN_BARVA, dtype=np.uint8)).all(axis=2)
    v[:, :, 3] = np.where((alfa > 0) & (alfa < 200) & barva, 255, alfa).astype(np.uint8)
    a[y:y + h, x:x + w] = v
    Image.fromarray(a, "RGBA").save(cesta)


def mutace_kotva_posunuta() -> None:
    cesta = OWN / "manifest.json"
    d = json.loads(cesta.read_text(encoding="utf-8"))
    s = next(x for x in d["sprites"] if x["kind"] == "item")
    s["oy"] = s["oy"] + 1
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
    ("stin_smazan", "z jednoho predmetu se smaze vrstva stinu",
     ("NENI videt kontaktni stin", "manifest tvrdi viditelny stin"),
     mutace_stin_smazan, None),
    ("stin_ztloustly", "stin se prevede na plnou alfu (splynou s objektem)",
     ("plne nepruhledne pixely maji barvu stinu", "NENI videt kontaktni stin"),
     mutace_stin_ztloustly, None),
    ("kotva_posunuta", "v manifestu se posune oy o 1 px",
     ("neni vzorec UO",), mutace_kotva_posunuta, None),
    ("manifest_zmenen", "do manifestu se prida bila mezera (determinismus)",
     ("determinismu",), mutace_manifest_zmenen, None),
    ("stranka_chybi", "stranka atlasu se prejmenuje",
     ("chybi stranka",), mutace_stranka_chybi, vrat_stranku),
]


def main() -> int:
    rc0, out0 = spust_branu()
    if rc0 != 0:
        print("[mutace] CHYBA: brana neni zelena ani pred mutacemi - "
              "mutacni test by meril neco jineho")
        print(out0[-2000:])
        return 1
    print("[mutace] pred mutacemi: brana zelena (0 chyb) - ted se vklada vada")

    vysledky = []
    for jmeno, popis, ocekavane, mutuj, ukliď in MUTACE:
        cesta_manifestu = OWN / "manifest.json"
        cesta_stranky, _s = _stranka_item()
        zalohy = {cesta_manifestu: _zaloha(cesta_manifestu),
                  cesta_stranky: _zaloha(cesta_stranky)}
        try:
            mutuj()
            rc, out = spust_branu()
            nalezene = [t for t in ocekavane if t in out]
            odhaleno = rc != 0 and bool(nalezene)
            vysledky.append({"mutace": jmeno, "popis": popis, "odhaleno": odhaleno,
                             "navratovy_kod": rc, "ocekavane_texty": list(ocekavane),
                             "nalezene_texty": nalezene})
            print(f"[mutace] {jmeno:18s} {'ODHALENO' if odhaleno else 'NEODHALENO':10s} "
                  f"(rc={rc}, hledano: {' | '.join(ocekavane)})")
            if not odhaleno:
                print("   --- vystup brany ---")
                for radek in out.splitlines()[-15:]:
                    print("   " + radek)
        finally:
            for c, data in zalohy.items():
                _vrat(c, data)
            if ukliď is not None:
                ukliď()

    rc1, out1 = spust_branu()
    print(f"[mutace] po vraceni zavad: brana {'zelena' if rc1 == 0 else 'CERVENA'}")
    if rc1 != 0:
        print(out1[-2000:])
    neodhalene = [v for v in vysledky if not v["odhaleno"]]
    print(f"[mutace] odhaleno {len(vysledky) - len(neodhalene)}/{len(vysledky)} mutaci")
    return 1 if (neodhalene or rc1 != 0) else 0


if __name__ == "__main__":
    raise SystemExit(main())
