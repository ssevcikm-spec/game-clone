#!/usr/bin/env python3
"""G14 check-state-float - zadny float ve STAVU simulace (docs/01 §1.5 bod 3).

Invarianta (docs/01 §1.5 bod 3, docs/09 §9.10, docs/10 P13): **skilly
v desetinach (int), cas v ms (int), pozice v dlazdicich (int), z v jednotkach
sveta (int)** - float je jen pro VYKRESLOVANI.

PROC TENHLE BRANA EXISTUJE: invarianta do 2026-10-10 nemela vlastni branu.
`check-layers.py` (G2) zakazuje jen cesty a `Input./Time./OS./randf(/randi(`
a `core/hash.gd` floaty ZAMERNE zpracuje (`"f:" + roundi(v*1e6)`), aby vada
neshodila beh. Dusledek: volny pohyb (pixely misto dlazdic) by prosEL
zelenymi branami a rozbil se az v replayi nebo v ulozene hre.

CO BRANA MERI:
  * R1 - clenska promenna typu `float`, ktera **vstupuje do stavu** (jeji jmeno
    se objevuje v tele funkce `state()`), je VADA: hash, save a replaye stoji
    na tom, ze stav je cely cislo.
  * R2 - `Vector2(`/`Vector3(` kdekoliv v `sim/**` je VADA: pozice a svet jsou
    `Vector2i`/`Vector3i`; float vektor v sim je presne tvar vady, kterou by
    prinesl volny pohyb.

CO BRANA ZAMERNE NEMERI (aby nehlasila vadu o spravnem kode - docs/08
„nastrazene brany", mereno 2026-10-10):
  * **lokalni float ve vypoctu** je dovoleny: `craft.gd` pocita sanci jako
    float a vysledek prevadi na int (`int(round(...))`), `harvest.gd` rolluje
    float, `skill_gain.gd` vraci float ze `_gain_chance`, `regen.gd` ma float
    koeficient. Plosny zakaz floatu v `sim/` by z toho udelal desitky
    falesnych nalezU.
  * **clenska promenna float, ktera do stavu NEJDE** (konfigurace nactena
    z dat) je dovolena - namEReno: `sim/systems/skill_gain.gd:113`
    `var _failure_weight: float = 0.0` je vaha neuspechu z `era.skill_gain`
    a do `state()` nevstupuje.
  Pocet obou povolenych veci se **vypisuje do merenI**, aby bylo videt, ze
  brana neni slepa a co presne toleruje.

Mimo rozsah: `core/`, `app/`, `ui/`, `render/` (tam float patri) a
`core/hash.gd` (deliberatne podporuje float).

Spousteni:
  python tools/gates/check-state-float.py [--root .] [--json cesta]
  python tools/gates/check-state-float.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, code_without_comments, read_text, selftest_cli,
)

NAME = "check-state-float"

# Clenska promenna (na zacatku radku, tj. bez odsazeni) typu float nebo
# inicializovana float literálem. `@export`/`static` se pripousti jako prefix.
MEMBER_FLOAT = re.compile(
    r"^(?:@\w+\s+)?(?:static\s+)?var\s+(\w+)\s*(?::\s*float\b|:=\s*[+-]?\d+\.\d)"
)
# Float vektor: `Vector2(`/`Vector3(` - ale NE `Vector2i(`/`Vector3i(`.
FLOAT_VECTOR = re.compile(r"\bVector2\s*\(|\bVector3\s*\(")
# Cokoli floatoveho (jen pro merenI povoleneho, NENI vada).
ANY_FLOAT = re.compile(r":\s*float\b|(?<![\w.])\d+\.\d+")


def state_body(code: str) -> str:
    """Text tela funkce `state()` (do dalsi top-level `func`), jinak ""."""
    m = re.search(r"^func\s+state\s*\(", code, re.M)
    if m is None:
        return ""
    rest = code[m.end():]
    nxt = re.search(r"^func\s", rest, re.M)
    return rest[: nxt.start()] if nxt else rest


def sim_files(root: Path) -> list[Path]:
    sim = root / "sim"
    if not sim.is_dir():
        return []
    return sorted(p for p in sim.rglob("*.gd") if p.is_file())


def check(root: Path, gate: Gate) -> None:
    files = sim_files(root)
    gate.measure("sim_souboru", len(files))
    if not files:
        gate.pending("sim/ neobsahuje zadny .gd soubor - kontrola stavu nema co merit")
        return

    in_state = 0
    config_floats = 0
    vector_hits = 0
    local_float_lines = 0
    for path in files:
        rel = path.relative_to(root).as_posix()
        code = code_without_comments(read_text(path), "gd")
        body = state_body(code)
        for i, line in enumerate(code.splitlines(), 1):
            if ANY_FLOAT.search(line):
                local_float_lines += 1
            if FLOAT_VECTOR.search(line):
                vector_hits += 1
                gate.error(f"{rel}:{i}: float vektor v sim/ "
                           f"(pouzij Vector2i/Vector3i) ({line.strip()[:70]})")
            if line[:1].isspace() or not line.strip():
                continue                      # odsazene = lokalni, dovoleno
            m = MEMBER_FLOAT.match(line)
            if m is None:
                continue
            name = m.group(1)
            if name in body:
                in_state += 1
                gate.error(f"{rel}:{i}: clenska promenna '{name}' je float "
                           f"A VSTUPUJE DO STAVU (funkce state()) - stav musi byt int "
                           f"({line.strip()[:60]})")
            else:
                config_floats += 1

    gate.measure("clenskych_floatu_ve_stavu", in_state)
    gate.measure("float_vektoru", vector_hits)
    gate.measure("radku_s_floatem_celkem", local_float_lines)
    gate.measure("clenskych_floatu_mimo_stav", config_floats)
    gate.note(f"povoleno (nehlasi se): lokalni float ve vypoctu "
              f"({local_float_lines} radku v {len(files)} souborech) a clenska "
              f"konfigurace ve floatu, ktera do stavu nejde ({config_floats}x)")


def selftest() -> int:
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-state-float"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, sim_code: str | None) -> Path:
        root = base / label
        root.mkdir(parents=True, exist_ok=True)
        if sim_code is not None:
            (root / "sim").mkdir(parents=True, exist_ok=True)
            (root / "sim" / "systems.gd").write_text(sim_code, encoding="utf-8")
        return root

    clean = ("extends RefCounted\n"
             "var hp: int = 87\n"
             "var pos: Vector3i = Vector3i.ZERO\n"
             "func state() -> Dictionary:\n"
             "\treturn {\"hp\": hp}\n"
             "func sance(v: int) -> int:\n"
             "\tvar p: float = float(v) / 10.0\n"       # lokalni float je OK
             "\treturn int(round(p))\n")
    # clen float, ktery do stavu NEJDE (konfigurace) - dovoleno
    config_only = clean + "var _vaha: float = 0.2\n"
    # clen float, ktery do stavu JDE - vada
    state_float = ("extends RefCounted\n"
                   "var koef: float = 0.5\n"
                   "func state() -> Dictionary:\n"
                   "\treturn {\"koef\": koef}\n")
    cases = [
        ("dobry", fixture("dobry", clean), OK),
        ("konfigurace_mimo_stav", fixture("konfigurace_mimo_stav", config_only), OK),
        ("clen_ve_stavu", fixture("clen_ve_stavu", state_float), VADA),
        ("vadny_vektor", fixture("vadny_vektor",
                                 clean + "func p():\n\treturn Vector2(1.0, 2.0)\n"), VADA),
        ("komentar_neni_vada", fixture(
            "komentar_neni_vada",
            "# pozor: `var koef: float` v sim by byla vada\n" + clean), OK),
        ("bez_sim", fixture("bez_sim", None), NEMERENO),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G14 zadny float ve stavu simulace")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    gate = Gate(NAME)
    check(Path(args.root).resolve(), gate)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
