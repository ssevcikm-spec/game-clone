#!/usr/bin/env python3
"""G4 check-wiring - mrtvy kod (docs/08 §8.2, §8.3).

Meri dve veci:
  1. kazde deklarovane `provides` je odnekud volane; reference se hledaji
     v PRODUKCNIM kode, ne jen v testech (presne ta vada, kterou docs/08 §8.3
     popisuje: "funkce zmíněná jen v testu se počítala za použitou"),
  2. kazdy handler `_on_*` je pripojeny k signalu.

Rozsah bere z roadmapy:
  * "wiring" v `acceptance` = u te granule se zapojeni VYZADUJE (jinak VADA),
  * u ostatnich granul je nevolane API viditelna poznamka (ZATIM NEINTEGROVANO),
    protoze jejich `acceptance` zapojeni nepozaduje - vymyslet si tvrdsi pravidlo
    by znamenalo merit neco jineho, nez co je ve smlouvě.

Spousteni:
  python tools/gates/check-wiring.py [--root .] [--json cesta]
  python tools/gates/check-wiring.py --self-test
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, VADA, Gate, code_without_comments, grain_files_exist,
    grains_by_id, read_text, selftest_cli,
)

NAME = "check-wiring"
PROD_DIRS = ("core", "sim", "ui", "render", "app")
TEST_DIRS = ("tests",)


def provides_names(provides: list[str]) -> list[str]:
    """Z 'Craft.recipes_for(m, skill) -> Array' vytahne 'recipes_for';
    z 'TILE_W, TILE_H' konstanty. Prozu bez identifikatoru preskoci.

    Pozn.: text v `provides` je i proza ("... s přesměrovaným APPDATA a importem"),
    takze kandidati se jeste filtruji tim, ze se jmeno musi vyskytovat ve
    vlastnim souboru granule - jinak by brana hlasila vadu u slova z vety
    (namEReno 2026-10-02: falesny pozitiv 'boot.ci_env.APPDATA')."""
    names: list[str] = []
    for entry in provides:
        for m in re.finditer(r"([A-Za-z_][A-Za-z0-9_]*)\s*\(", entry):
            names.append(m.group(1))
        for m in re.finditer(r"\b([A-Z][A-Z0-9_]{2,})\b", entry):
            names.append(m.group(1))
    seen: list[str] = []
    for n in names:
        if n not in seen:
            seen.append(n)
    return seen


DECL_PATTERNS = (
    r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)",     # GDScript
    r"\bconst\s+([A-Za-z_][A-Za-z0-9_]*)",
    r"\bvar\s+([A-Za-z_][A-Za-z0-9_]*)",
    r"\bsignal\s+([A-Za-z_][A-Za-z0-9_]*)",
    r"\bdef\s+([A-Za-z_][A-Za-z0-9_]*)",      # Python
    r"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)",
)


def declared_symbols(root: Path, grain: dict) -> set[str]:
    """Jmena, ktera soubor granule opravdu DEKLARUJE (func/const/def/...).

    Text v `provides` je z casti proza ("... s přesměrovaným APPDATA a importem"),
    takze kandidat se pocita jen kdyz je deklarovany. Jinak by brana hlasila
    vadu u slova z vety (namEReno 2026-10-02: falesny pozitiv 'boot.ci_env.APPDATA',
    ktery se do souboru dostal jen jako `export APPDATA=...`)."""
    symbols: set[str] = set()
    for own in grain.get("owns", []):
        path = root / own.rstrip("/")
        files = [path] if path.is_file() else (
            [f for f in sorted(path.rglob("*")) if f.is_file() and f.suffix in (".gd", ".py")] if path.is_dir() else []
        )
        for f in files:
            if f.suffix not in (".gd", ".py"):
                continue
            code = code_without_comments(read_text(f), "gd")
            for pattern in DECL_PATTERNS:
                symbols.update(re.findall(pattern, code))
    return symbols


def declared_names(root: Path, grain: dict) -> tuple[list[str], list[str]]:
    """Rozdeli kandidaty na deklarovane a na ty, ktere jsou jen z prozy."""
    symbols = declared_symbols(root, grain)
    declared, prose = [], []
    for name in provides_names(grain.get("provides", [])):
        (declared if name in symbols else prose).append(name)
    return declared, prose


def gd_files(root: Path, dirs: tuple[str, ...]) -> list[Path]:
    out: list[Path] = []
    for d in dirs:
        base = root / d
        if base.is_dir():
            out.extend(sorted(p for p in base.rglob("*.gd") if p.is_file()))
    return out


def references(root: Path, name: str, dirs: tuple[str, ...], exclude: Path) -> int:
    pattern = re.compile(rf"(?<![\w]){re.escape(name)}(?![\w])")
    hits = 0
    for path in gd_files(root, dirs):
        if path == exclude:
            continue
        hits += len(pattern.findall(code_without_comments(read_text(path), "gd")))
    return hits


def check(root: Path, gate: Gate) -> None:
    by_id = grains_by_id(root)
    implemented = {
        gid: g for gid, g in by_id.items()
        if g.get("kind") in ("code", "data", "bootstrap") and grain_files_exist(root, g)
    }
    gate.measure("granuli_s_hotovym_souborem", len(implemented))

    if not implemented:
        gate.pending("v repu není žádný soubor z roadmapy - zapojení nemá co měřit")
        return

    required: list[tuple[str, str]] = []
    optional: list[tuple[str, str]] = []
    test_only: list[tuple[str, str]] = []
    wired = 0

    for gid, grain in sorted(implemented.items()):
        names, prose = declared_names(root, grain)
        if prose:
            gate.note(f"{gid}: z `provides` vypadají jako próza (nejsou v souboru): "
                      + ", ".join(prose[:6]) + (" …" if len(prose) > 6 else ""))
        if not names:
            gate.note(f"{gid}: `provides` neobsahuje volatelné jméno (kontrola zapojení se ho netýká)")
            continue
        own = [root / o for o in grain.get("owns", [])]
        own_files = [p for p in own if p.is_file()]
        needs_wiring = "wiring" in grain.get("acceptance", [])
        # U granuli, jejichz soubory jsou v tests/ nebo tools/ (harness, brany),
        # je "produkce" to, co je vola odtamtud - jinak by brana hlasila vadu
        # u kazdeho testovaciho helperu.
        tooling = any(o.replace("\\", "/").startswith(("tests/", "tools/"))
                      for o in grain.get("owns", []))
        prod_dirs = PROD_DIRS + TEST_DIRS if tooling else PROD_DIRS
        for name in names:
            prod = 0
            for path in own_files:
                prod += references(root, name, prod_dirs, path)
            tests = 0
            for path in own_files:
                tests += references(root, name, TEST_DIRS, path)
            if prod:
                wired += 1
            elif tests:
                test_only.append((gid, name))
            elif needs_wiring:
                required.append((gid, name))
            else:
                optional.append((gid, name))

    total_names = wired + len(test_only) + len(required) + len(optional)
    gate.measure("provides_jmen", total_names)
    gate.measure("volanych_z_produkce", wired)
    gate.measure("jen_z_testu", len(test_only))
    gate.measure("neintegrovano", len(optional))

    wiring_grains = {gid for gid, g in implemented.items() if "wiring" in g.get("acceptance", [])}
    for gid, name in test_only:
        # docs/08 §8.3: reference jen z testu neni dukaz zapojeni.
        if gid in wiring_grains:
            gate.error(f"{gid}.{name}: volá ho jen tests/ - u granule s 'wiring' v acceptance to nestačí")
        else:
            gate.note(f"{gid}.{name}: volá ho jen tests/ - čeká na integraci (acceptance nežádá 'wiring')")
    for gid, name in required:
        gate.error(f"{gid}.{name}: deklarováno v `provides` a nikde se nevolá (acceptance žádá 'wiring')")
    for gid, name in optional:
        gate.note(f"{gid}.{name}: zatím nevolané z produkce (granule nežádá 'wiring' - čeká na integraci)")

    # handlery _on_* musi byt pripojene k signalu
    handlers: list[str] = []
    for path in gd_files(root, PROD_DIRS):
        code = code_without_comments(read_text(path), "gd")
        for m in re.finditer(r"func\s+(_on_[A-Za-z0-9_]+)\s*\(", code):
            handlers.append(f"{path.relative_to(root).as_posix()}:{m.group(1)}")
    gate.measure("handleru_on", len(handlers))
    connected = 0
    for item in handlers:
        path_str, handler = item.rsplit(":", 1)
        code_all = "\n".join(code_without_comments(read_text(p), "gd")
                             for p in gd_files(root, PROD_DIRS))
        if re.search(rf"connect\s*\([^)]*{re.escape(handler)}", code_all):
            connected += 1
        else:
            gate.error(f"{item}: handler _on_* není připojený k signálu")
    gate.measure("handleru_pripojeno", connected)

    if total_names == 0 and not gate.errors:
        gate.pending("žádné `provides` s volatelným jménem - zapojení nemá co měřit")


def selftest() -> int:
    import json
    import shutil

    base = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "selftest-wiring"
    shutil.rmtree(base, ignore_errors=True)

    def fixture(label: str, files: dict[str, str], grains: list[dict]) -> Path:
        root = base / label
        (root / ".forge").mkdir(parents=True, exist_ok=True)
        (root / ".forge" / "roadmap.json").write_text(
            json.dumps({"milestones": [], "grains": grains}, ensure_ascii=False), encoding="utf-8")
        for rel, content in files.items():
            path = root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8")
        return root

    def grain(gid: str, owns: list[str], provides: list[str], deps: list[str],
              acceptance: list[str], kind: str = "code") -> dict:
        return {"id": gid, "kind": kind, "owns": owns, "depends_on": deps,
                "provides": provides, "consumes": [], "acceptance": acceptance}

    cases = [
        ("dobry", fixture("dobry",
                          {"core/a.gd": "extends RefCounted\nfunc foo() -> int:\n\treturn 1\n",
                           "app/main.gd": "extends Node\ndef _ready() -> void:\n\tA.foo()\n"},
                          [grain("core.a", ["core/a.gd"], ["A.foo() -> int"], [], ["wiring"])]), OK),
        # deklarovane a nevolane, pritom acceptance zadá 'wiring' -> VADA
        ("vadny_nevolane", fixture("vadny_nevolane",
                                   {"core/a.gd": "extends RefCounted\nfunc foo() -> int:\n\treturn 1\n"},
                                   [grain("core.a", ["core/a.gd"], ["A.foo() -> int"], [], ["wiring"])]), VADA),
        # volane jen z testu u granule s 'wiring' -> VADA (docs/08 §8.3)
        ("vadny_jen_test", fixture("vadny_jen_test",
                                   {"core/a.gd": "extends RefCounted\nfunc foo() -> int:\n\treturn 1\n",
                                    "tests/x.gd": "extends RefCounted\nfunc t() -> int:\n\treturn A.foo()\n"},
                                   [grain("core.a", ["core/a.gd"], ["A.foo() -> int"], [], ["wiring"])]), VADA),
        # nevolane, ale granule 'wiring' nezada -> jen poznamka, mereno
        ("caka_na_integraci", fixture("caka_na_integraci",
                                      {"core/a.gd": "extends RefCounted\nfunc foo() -> int:\n\treturn 1\n",
                                       "app/main.gd": "extends Node\n"},
                                      [grain("core.a", ["core/a.gd"], ["A.foo() -> int"], [], ["tests"])]), OK),
        # nepripojeny handler -> VADA
        ("vadny_handler", fixture("vadny_handler",
                                  {"app/main.gd": "extends Node\nfunc _on_use_pressed() -> void:\n\tpass\n"},
                                  [grain("app.main", ["app/main.gd"], [], [], ["tests"])]), VADA),
        # zadny soubor z roadmapy -> NEMERENO
        ("prazdny_repo", fixture("prazdny_repo", {},
                                 [grain("core.a", ["core/a.gd"], ["A.foo() -> int"], [], ["wiring"])]), NEMERENO),
    ]
    return selftest_cli(NAME, check, [(l, e) for l, _, e in cases],
                        fixtures=[(l, f) for l, f, _ in cases])


def main() -> int:
    ap = argparse.ArgumentParser(description="G4 kontrola zapojení (mrtvý kód)")
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
