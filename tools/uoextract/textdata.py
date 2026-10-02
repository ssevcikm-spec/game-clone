#!/usr/bin/env python3
"""Textova a pravidlova data z instalace UO -> data/*.json (granule assets.textdata).

Zdroje a vystupy (docs/03 §3.6) - tvary jsou MERENE, ne hadane:

  doors.txt     tab-separated, hlavicka "Category Piece1..Piece8 FeatureMask Comment"
                -> data/doors.json      (docs: 37 kategorii)
  stairs.txt    "Category Block N E S W Squared1/2 Rounded1/2 MultiN/E/S/W ... FeatureMask Comment"
                -> data/stairs.json     (docs: 19 kategorii)
  teleprts.txt  "Category F1..F16 FeatureMask Comment" -> data/teleports.json
  misc.txt      "Category Style TID Piece1..Piece8 FeatureMask Comment" -> data/misc.json
  mobtypes.txt  "ID TYPE FLAGS" (radky s # jsou komentar) -> data/mobtypes.json
  body.def, Corpse.def, Anim1.def     "<orig> {<new>} <hue>"
  Bodyconv.def, Equipconv.def         radky intu
                -> data/defs.json
  skills.mul    58x [1 B flag][NUL-ukoncene jmeno] - model spotrebuje CELY soubor
  skillgrp.mul  u32 hlavicka + 6x 17 B jmeno + 58x u32 (skupina pro kazdy skill)
                -> data/skill_groups.json

  skills.mul se do data/skills.json NEPISE: ten vlastni granule data.skills.
  Tenhle nastroj pro nej dava funkce `skills()` a `skill_groups()`.

Pouziti:
  python tools/uoextract/textdata.py --install "<UO>" --out data
  python tools/uoextract/textdata.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
INT_RE = re.compile(r"-?\d+")
BODY_DEF_RE = re.compile(r"^\s*(-?\d+)\s*\{\s*(-?\d+)\s*\}\s*(-?\d+)")
EXPECTED = {"doors": 37, "stairs": 19, "skills": 58, "skill_groups": 6}


def _lines(path: Path) -> list[str]:
    return path.read_text(encoding="latin-1").splitlines()


def parse_table(path: Path) -> list[dict]:
    """Tab-separated tabulka s hlavickou zacinajici 'Category'."""
    rows: list[dict] = []
    header: list[str] = []
    for line in _lines(path):
        cells = line.split("\t")
        if not header:
            if cells and cells[0].strip().lower() == "category":
                header = [c.strip().lower() for c in cells]
            continue
        if not cells or not INT_RE.fullmatch(cells[0].strip() or "x"):
            continue
        row: dict = {}
        for i, cell in enumerate(cells):
            key = header[i] if i < len(header) else f"col{i}"
            value = cell.strip()
            if INT_RE.fullmatch(value or "x"):
                row[key] = int(value)
            elif value:
                row[key] = value
        rows.append(row)
    return rows


def parse_mobtypes(path: Path) -> list[dict]:
    out: list[dict] = []
    for line in _lines(path):
        line = line.split("#", 1)[0].strip()
        parts = line.split()
        if len(parts) >= 3 and all(INT_RE.fullmatch(p) for p in (parts[0], parts[2])):
            out.append({"id": int(parts[0]), "type": parts[1], "flags": int(parts[2])})
    return out


def parse_def(path: Path) -> tuple[list[dict], str]:
    """body.def / Corpse.def / Anim1.def ('<o> {<n>} <hue>') i *conv.def (radky intu)."""
    rows: list[dict] = []
    shape = "unknown"
    for line in _lines(path):
        line = line.split("#", 1)[0].strip().strip('"').strip()
        if not line:
            continue
        found = BODY_DEF_RE.match(line)
        if found:
            shape = "orig {new} hue"
            rows.append({"orig": int(found.group(1)), "new": int(found.group(2)),
                         "hue": int(found.group(3))})
            continue
        values = [int(v) for v in INT_RE.findall(line)]
        if values:
            shape = "radky intu" if shape == "unknown" else shape
            rows.append({"values": values})
    return rows, shape


def _nul_string(raw: bytes, start: int) -> tuple[str, int]:
    end = raw.find(b"\x00", start)
    if end < 0:
        # Chybejici ukoncovaci NUL znamena, ze model nesedi (self-test to hlida).
        raise ValueError(f"zaznam na offsetu {start - 1} nema ukoncovaci NUL")
    return raw[start:end].decode("latin-1"), end + 1


def skills(path: Path) -> list[dict]:
    """[1 B flag][NUL-ukoncene jmeno] - model musi spotrebovat CELY soubor."""
    raw = path.read_bytes()
    out: list[dict] = []
    i = 0
    while i < len(raw):
        flag = raw[i]
        name, i = _nul_string(raw, i + 1)
        out.append({"flag": flag, "name": name})
    if i != len(raw):
        raise ValueError(f"skills.mul: model nesedi, dosel na {i} z {len(raw)} B")
    return out


def _is_text(raw: bytes) -> bool:
    return bool(raw) and all(32 <= b <= 126 for b in raw)


def skill_groups(path: Path, skill_count: int) -> dict:
    """u32 hlavicka + N x 17 B jmeno + M x u32 (skupina pro kazdy skill).

    Jmena se berou jen dokud je zaznam TEXT (binarni tabulka id zacina hned po
    nich) - jinak by se prvni 4 bajty tabulky precetly jako "jmeno" a model by
    tvrdil 7 skupin misto 6 (namEReno 2026-10-02)."""
    raw = path.read_bytes()
    header = struct.unpack_from("<I", raw, 0)[0]
    names: list[str] = []
    off = 4
    while off + 17 <= len(raw):
        candidate = raw[off:off + 17].split(b"\x00")[0]
        if not _is_text(candidate):
            break
        names.append(candidate.decode("latin-1"))
        off += 17
    count = (len(raw) - off) // 4
    groups = list(struct.unpack_from(f"<{count}I", raw, off))
    return {"header": header, "names": names, "skill_groups": groups,
            "consumed": off + count * 4, "bytes": len(raw), "skills": skill_count}


def write_json(path: Path, payload: dict, note: str) -> None:
    payload = dict(payload)
    payload["_note"] = note
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    print(f"[textdata] {path} ({len(text)} B, sha256 {hashlib.sha256(text.encode()).hexdigest()[:16]}…)")


def self_test() -> int:
    import tempfile
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[textdata] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / "doors.txt").write_text(
            "int\tint\tstring\n\nCategory\tPiece1\tFeatureMask\tComment\n"
            "0\t1657\t0\tMetal Door\n1\t1721\t0\tWood Door\n", encoding="latin-1")
        rows = parse_table(root / "doors.txt")
        check(len(rows) == 2 and rows[0]["category"] == 0 and rows[0]["comment"] == "Metal Door",
              f"tabulka: {len(rows)} radku, prvni {rows[0] if rows else None}")
        check("featuremask" in rows[0] and rows[0]["featuremask"] == 0, "tabulka: nazvy sloupcu z hlavicky")

        (root / "skills.mul").write_bytes(b"\x00Alchemy\x00\x01Anatomy\x00")
        parsed = skills(root / "skills.mul")
        check(len(parsed) == 2 and parsed[1]["name"] == "Anatomy" and parsed[1]["flag"] == 1,
              f"skills: {parsed}")
        check(parsed[0]["flag"] == 0, "skills: flag se zachova")

        (root / "broken.mul").write_bytes(b"\x00BezKonce")
        try:
            skills(root / "broken.mul")
            check(False, "skills: chybejici NUL ma vyhodit chybu")
        except ValueError as exc:
            check(True, f"skills: chybejici NUL je odhalen ({exc})")

        raw = bytearray()
        raw += struct.pack("<I", 7)
        for name in ("Combat", "Magic"):
            raw += name.encode("latin-1").ljust(17, b"\x00")
        raw += struct.pack("<3I", 0, 1, 6)
        (root / "skillgrp.mul").write_bytes(bytes(raw))
        groups = skill_groups(root / "skillgrp.mul", 3)
        check(groups["names"] == ["Combat", "Magic"] and groups["skill_groups"] == [0, 1, 6],
              f"skillgrp: {groups['names']} / {groups['skill_groups']}")
        check(groups["consumed"] == groups["bytes"], "skillgrp: model spotrebuje cely soubor")

    print(f"[textdata] self-test: 6 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="textová data UO -> data/*.json")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--out", default="data")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    inst = Path(args.install)
    out = Path(args.out)
    found: dict[str, int] = {}
    failures: list[str] = []

    def need(name: str, expected_key: str | None = None) -> Path | None:
        path = inst / name
        if not path.exists():
            failures.append(f"{name} v instalaci chybi")
            return None
        return path

    tables = {"doors.txt": "doors", "stairs.txt": "stairs",
              "teleprts.txt": "teleports", "misc.txt": "misc"}
    for source, target in tables.items():
        path = need(source)
        if path is None:
            continue
        rows = parse_table(path)
        found[target] = len(rows)
        write_json(out / f"{target}.json", {"source": source, "rows": rows},
                   "Tabulka z instalace UO (docs/03 §3.6); sloupce jsou z hlavicky souboru.")

    path = need("mobtypes.txt")
    if path is not None:
        rows = parse_mobtypes(path)
        found["mobtypes"] = len(rows)
        write_json(out / "mobtypes.json", {"source": "mobtypes.txt", "rows": rows},
                   "ID TYPE FLAGS - typ pro AI a animacni skupinu tela (docs/03 §3.6).")

    defs: dict[str, dict] = {}
    for name in ("body.def", "Corpse.def", "Bodyconv.def", "Equipconv.def", "Anim1.def"):
        path = inst / name
        if not path.exists():
            continue
        rows, shape = parse_def(path)
        defs[name] = {"shape": shape, "rows": rows}
        found[name] = len(rows)
    if defs:
        write_json(out / "defs.json", {"sources": defs},
                   "Prevodniky tela/výbavy. U radku intu jsou nazvy poli v docs/03 §3.6; "
                   "tvar je vzdy uvedeny u zdroje, nic se nedomysli.")

    skills_path = need("skills.mul")
    group_path = need("skillgrp.mul")
    if skills_path is not None:
        try:
            parsed_skills = skills(skills_path)
        except ValueError as exc:
            failures.append(str(exc))
            parsed_skills = []
        found["skills"] = len(parsed_skills)
        if group_path is not None and parsed_skills:
            groups = skill_groups(group_path, len(parsed_skills))
            found["skill_groups"] = len(groups["names"])
            found["skill_group_ids"] = (max(groups["skill_groups"]) + 1) if groups["skill_groups"] else 0
            if len(groups["skill_groups"]) != len(parsed_skills):
                failures.append(
                    f"skillgrp: {len(groups['skill_groups'])} skupinovych id != "
                    f"{len(parsed_skills)} skillu")
            write_json(out / "skill_groups.json", {
                "source": "skillgrp.mul", "groups": groups,
                "skills": [s["name"] for s in parsed_skills],
            }, "Skupiny skillu. POZOR: tabulka pouziva i id, ktera jmeno nemaji "
               "(docs/03 §3.6 rika 6 skupin) - konzument to musi zvladnout.")

    for key, expected in EXPECTED.items():
        got = found.get(key)
        print(f"[textdata] {key}: {got} (docs/03 §3.6 ocekava {expected})")
        if got != expected:
            failures.append(f"{key}: namEReno {got}, ocekavano {expected}")
    for key in ("teleports", "misc", "mobtypes"):
        print(f"[textdata] {key}: {found.get(key)} radku (docs pocet neuvadi)")

    if failures:
        for f in failures:
            print(f"[textdata] CHYBA: {f}")
        return 1
    print("[textdata] OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
