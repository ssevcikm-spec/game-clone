"""Spolecne jadro bran (docs/08-brany-a-overovani.md).

Pravidla, ktera tenhle modul vynucuje:
  * brana, ktera nic nezmERila, NIKDY nekonci 0 (docs/08 §8.6),
  * navratove kody: 0 = mereno a bez vady, 1 = vada, 2 = nemereno/skip,
  * kazda brana vypise, co namERila, a zapise strojovy JSON (docs/08 §8.7),
  * staticke kontroly ctou KOD, ne komentare (docs/08 §8.1.3).

Kazda brana je skript v tools/gates/check-*.py s funkci `check(root, gate)`
a prepinacem --self-test (offline test se znamym spravnym i vadnym vstupem).
"""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / ".cache" / "gates"

OK = 0
VADA = 1
NEMERENO = 2

GODOT_STATION = Path(r"C:\Users\Ssevc\Local-Deepseek\orchestra\tools\godot")
GODOT_LOCAL = ROOT / ".cache" / "godot"
GODOT_ENGINE = "Godot_v4.7.2-stable_win64.exe"
GODOT_CONSOLE = "Godot_v4.7.2-stable_win64_console.exe"


class Gate:
    """Sber mereni, chyb a stavu 'nemereno' pro jednu branu."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.measured: dict[str, object] = {}
        self.errors: list[str] = []
        self.notes: list[str] = []
        self.skipped: list[str] = []
        self.pending_reason: str | None = None

    # -- vstupy ------------------------------------------------------------
    def measure(self, key: str, value: object) -> None:
        self.measured[key] = value

    def note(self, text: str) -> None:
        self.notes.append(text)

    def error(self, text: str) -> None:
        self.errors.append(text)

    def skip(self, text: str) -> None:
        """Prostredi nema vstup (napr. chybi instalace UO) - viditelne v logu."""
        self.skipped.append(text)

    def pending(self, reason: str) -> None:
        """Cil brany jeste neexistuje. NEMERENO - nikdy zelena."""
        self.pending_reason = reason

    # -- vystup ------------------------------------------------------------
    def verdict(self) -> int:
        if self.errors:
            return VADA
        if self.pending_reason or self.skipped:
            return NEMERENO
        if not self.measured:
            # Brana nic nezmerila a nic neoznamila -> slepa zelena, to je vada.
            self.errors.append(
                "brana nic nezmERila a nenahlasila NEMERENO (docs/08 §8.6)"
            )
            return VADA
        return OK

    def finish(self, out_path: Path | None = None) -> int:
        code = self.verdict()
        label = {OK: "OK", VADA: "VADA", NEMERENO: "NEMERENO"}[code]
        print(f"[{self.name}] MERENO: {self.measured}")
        for n in self.notes:
            print(f"[{self.name}]   - {n}")
        for s in self.skipped:
            print(f"[{self.name}] SKIP: {s}")
        if self.pending_reason:
            print(f"[{self.name}] NEMERENO: {self.pending_reason}")
        for e in self.errors:
            print(f"[{self.name}] CHYBA: {e}")
        print(f"[{self.name}] {label} (exit {code})")
        record = {
            "gate": self.name,
            "verdict": label,
            "exit": code,
            "measured": self.measured,
            "notes": self.notes,
            "skipped": self.skipped,
            "pending": self.pending_reason,
            "errors": self.errors,
        }
        target = out_path or (OUT_DIR / f"{self.name}.json")
        try:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                json.dumps(record, ensure_ascii=False, indent=1), encoding="utf-8"
            )
        except OSError as exc:  # zapis JSONu nesmi shodit branu
            print(f"[{self.name}] POZOR: JSON neulozen ({exc})")
        return code


# -- prace se soubory ------------------------------------------------------

def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def code_without_comments(text: str, lang: str = "gd") -> str:
    """Odstrani komentare (a u GDScriptu i stringy), aby kontrola nemerila text
    v komentari - komentar popisujici vadu jinak vypada jako vada (docs/08 §8.1.3)."""
    if lang == "gd":
        text = re.sub(r'"""(?:.|\n)*?"""', '""', text)
        text = re.sub(r"'''(?:.|\n)*?'''", "''", text)
    text = re.sub(r'"(?:\\.|[^"\\\n])*"', '""', text)
    text = re.sub(r"'(?:\\.|[^'\\\n])*'", "''", text)
    lines = []
    for line in text.splitlines():
        if lang == "gd":
            line = re.sub(r"#.*$", "", line)
        elif lang == "py":
            line = re.sub(r"#.*$", "", line)
        lines.append(line)
    return "\n".join(lines)


def load_json(path: Path):
    return json.loads(read_text(path))


def roadmap(root: Path) -> dict:
    return load_json(root / ".forge" / "roadmap.json")


def grains_by_id(root: Path) -> dict[str, dict]:
    return {g["id"]: g for g in roadmap(root)["grains"]}


def grain_files_exist(root: Path, grain: dict) -> bool:
    for own in grain.get("owns", []):
        p = root / own.rstrip("/")
        if p.is_dir():
            if any(p.rglob("*")):
                return True
        elif p.exists():
            return True
    return False


def scope_files(root: Path, grain_ids: list[str]) -> list[Path]:
    """Soubory granul z daneho rozsahu, ktere v repu existuji."""
    by_id = grains_by_id(root)
    out: list[Path] = []
    for gid in grain_ids:
        grain = by_id.get(gid)
        if grain is None:
            continue
        for own in grain.get("owns", []):
            p = root / own.rstrip("/")
            if p.is_file():
                out.append(p)
            elif p.is_dir():
                out.extend(sorted(q for q in p.rglob("*") if q.is_file()))
    return out


# -- Godot -----------------------------------------------------------------

def godot_bin() -> Path | None:
    """Cesta ke Godotu. Na teto stanici plati (namEReno 2026-10-02): engine
    spusteny z C:\\... nemuze zapisovat soubory ani vytvaret adresare - sandbox
    ho blokuje a Godot u toho nekdy vraci 'uspech'. Kopie ve workspace funguje,
    proto ji tady jednou pripravime (172 MB, .cache/ je v .gitignore)."""
    env = os.environ.get("GODOT")
    if env and Path(env).exists():
        return Path(env)
    local = GODOT_LOCAL / GODOT_ENGINE
    if not local.exists() and GODOT_STATION.exists():
        GODOT_LOCAL.mkdir(parents=True, exist_ok=True)
        for name in (GODOT_ENGINE, GODOT_CONSOLE):
            src = GODOT_STATION / name
            if src.exists():
                shutil.copy2(src, GODOT_LOCAL / name)
    return local if local.exists() else None


def godot_run(root: Path, args: list[str], timeout: int = 180) -> tuple[int, str]:
    """Spusti Godot headless s presmerovanym APPDATA (docs/02 §2.1) a vrati
    (exit kod, vystup). Cesta k projektu je root."""
    binary = godot_bin()
    if binary is None:
        return 127, "GODOT nenalezen (nastav $GODOT)"
    userdata = root / ".cache" / "godot-appdata"
    (userdata / "Godot" / "app_userdata").mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["APPDATA"] = str(userdata)
    cmd = [str(binary), "--headless", "--path", str(root)] + args
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=timeout, env=env,
        )
    except subprocess.TimeoutExpired:
        return 124, f"Godot prekrocil timeout {timeout}s"
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def selftest_cli(
    name: str,
    check,
    cases: list[tuple[str, int]],
    fixtures: list[tuple[str, Path]] | None = None,
) -> int:
    """Offline test brany (docs/08 §8.1.5): kazdy pripad je (jmeno, ocekavany verdikt).

    Kdyz jsou zadane `fixtures` (jmeno -> koren falesneho projektu), vola se
    `check(root, gate)`; jinak `check(gate)`. Pri chybe skonci 1 - self-test,
    ktery neumi selhat, nema cenu (docs/08 §8.1)."""
    roots = dict(fixtures or [])
    bad = 0
    for label, expected in cases:
        gate = Gate(f"{name}/selftest:{label}")
        if fixtures is None:
            check(gate)
        else:
            check(roots[label], gate)
        got = gate.verdict()
        ok = got == expected
        if not ok:
            bad += 1
        print(f"[{name}] self-test {label}: ocekavano {expected}, vyslo {got}"
              f" {'OK' if ok else 'CHYBA'}")
        if not ok:
            for e in gate.errors:
                print(f"[{name}]   duvod: {e}")
            if gate.pending_reason:
                print(f"[{name}]   pending: {gate.pending_reason}")
    print(f"[{name}] self-test: {len(cases)} pripadu, {bad} chyb")
    return VADA if bad else OK
