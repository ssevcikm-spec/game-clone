#!/usr/bin/env python3
"""G19 check-sound - zvuk se OPRAVDU prehraje (ZADANI-27 §4 C1; docs/08 §8.2).

Proc existuje: `tests/cases/sound.gd` meri ROZHODNUTI modulu (`app/sound.gd`),
ale to, ze zvuk **doopravdy hraje**, se takto merit NEDÁ - `AudioStreamPlayer`
mimo bezici scenu neprehraje (a modul to vraci jako `false`). NamEReno
2026-10-12: modul byl zapojeny, ale nic nehral (`prehrano 0`), protoze znal
hrace `0` - vsechny zvuky utlumil na ticho. Zelene testy to nechytily.

Brana spusti REALNOU scenu pres `tools/gates/sound_probe.gd` a pozaduje:
  * `prehrano > 0` (ne "soubor existuje" a ne "modul vraci true"),
  * vsech pet zvuku ve `podle_id` (hit, hurt, death, mine, smith) - sonda je
    vyvolava z realnych systemu (souboj, tezba, kovani),
  * `chyb == 0` (zadna nehlásená vada).

NEMERENO (ne zelena): chybi-li sonda nebo Godot.

Spousteni:
  python tools/gates/check-sound.py [--root .] [--json cesta]
  python tools/gates/check-sound.py --self-test
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, godot_bin, godot_run  # noqa: E402

NAME = "check-sound"
PROBE = "res://tools/gates/sound_probe.gd"
SOUHRN = re.compile(r"SOUHRN: prehrano (\d+), podle id \{(.*?)\}, ticho (\d+), chyb (\d+)")
# Zvuky, ktere musi probe vyvolat: `hit`/`hurt` (souboj), `death` (smrt),
# `mine` (tezba), `smith` (kovani). Sonda je vyvolava PRIMO pres systemy, takze
# to neni nahoda - chybejici zvuk je vada zapojeni.
POVINNE = ("hit", "hurt", "death", "mine", "smith")


def vyhodnot(output: str) -> dict:
    """Precte souhrn ze sondy. `nalezeno: False` = sonda nic nenahlasila."""
    m = SOUHRN.search(output)
    if m is None:
        return {"nalezeno": False}
    podle: dict[str, int] = {}
    for kus in m.group(2).split(","):
        if ":" not in kus:
            continue
        klic, hodnota = kus.split(":", 1)
        klic = klic.strip().strip('"')
        try:
            podle[klic] = int(hodnota.strip().strip('"').strip() or 0)
        except ValueError:
            continue
    return {
        "nalezeno": True,
        "prehrano": int(m.group(1)),
        "podle_id": podle,
        "ticho": int(m.group(3)),
        "chyb": int(m.group(4)),
    }


def chyby_z_mereni(d: dict) -> list[str]:
    """Verdikt z jednoho mereni - pouziva ho brana i self-test."""
    if not d.get("nalezeno", False):
        return ["ze sondy nelze precist souhrn (sonda neprobihla nebo spadla)"]
    chyby: list[str] = []
    if int(d.get("prehrano", 0)) <= 0:
        chyby.append("zvuk se NEPREHRAL ani jednou - modul je zapojeny, ale nic nehraje")
    chybi = [i for i in POVINNE if int(d.get("podle_id", {}).get(i, 0)) <= 0]
    if chybi:
        chyby.append("tyto zvuky se neozvaly: " + ", ".join(chybi)
                     + " (sonda je vyvolava pres realne systemy)")
    if int(d.get("chyb", 0)) > 0:
        chyby.append(f"modul hlasil {d['chyb']} chyb pri prehravani")
    return chyby


def check(root: Path, gate: Gate) -> None:
    sonda = root / "tools" / "gates" / "sound_probe.gd"
    if not sonda.exists():
        gate.pending(f"chybí sonda {sonda.relative_to(root).as_posix()} - není co měřit")
        return
    if godot_bin() is None:
        gate.skip("Godot není k dispozici (nastav $GODOT nebo dodej binárku do .cache/godot)")
        return
    rc, output = godot_run(root, ["--fixed-fps", "60", "--script", PROBE], timeout=600)
    d = vyhodnot(output)
    gate.measure("probe_exit", rc)
    if not d.get("nalezeno", False):
        gate.error(f"ze sondy nelze přečíst souhrn (exit {rc})")
        for line in output.splitlines()[-5:]:
            gate.note(line.strip()[:120])
        return
    gate.measure("prehrano", d["prehrano"])
    gate.measure("podle_id", json.dumps(d["podle_id"], ensure_ascii=False))
    gate.measure("ticho", d["ticho"])
    gate.measure("chyb", d["chyb"])
    if rc != 0:
        gate.error(f"sonda skončila s exit {rc} (výstup se čte i přesto)")
    for ch in chyby_z_mereni(d):
        gate.error(ch)


def selftest() -> int:
    """Znamy spravny i znamy chybny vstup - offline, bez Godotu."""
    pripady = [
        ("vsechno_hraje", {"nalezeno": True, "prehrano": 5, "ticho": 0, "chyb": 0,
                           "podle_id": {k: 1 for k in POVINNE}}, 0),
        ("nic_se_neprehralo", {"nalezeno": True, "prehrano": 0, "ticho": 2, "chyb": 0,
                               "podle_id": {}}, 2),
        ("chybi_smrt", {"nalezeno": True, "prehrano": 4, "ticho": 1, "chyb": 0,
                        "podle_id": {"hit": 1, "hurt": 1, "mine": 1, "smith": 1}}, 1),
        ("sonda_mlci", {"nalezeno": False}, 1),
        ("chyba_v_modulu", {"nalezeno": True, "prehrano": 5, "ticho": 0, "chyb": 1,
                            "podle_id": {k: 1 for k in POVINNE}}, 1),
    ]
    chyb = 0
    for jmeno, mereni, ocekavano in pripady:
        vyslo = len(chyby_z_mereni(mereni))
        ok = vyslo == ocekavano
        chyb += 0 if ok else 1
        print(f"[{NAME}] self-test {jmeno}: ocekavano {ocekavano} chyb, vyslo {vyslo}"
              f" {'OK' if ok else 'CHYBA'}")
    print(f"[{NAME}] self-test: {len(pripady)} případů, {chyb} chyb")
    return VADA if chyb else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G19 kontrola, že se zvuk opravdu přehraje")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    a = ap.parse_args()
    if a.self_test:
        return selftest()
    gate = Gate(NAME)
    check(Path(a.root).resolve(), gate)
    return gate.finish(Path(a.json) if a.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
