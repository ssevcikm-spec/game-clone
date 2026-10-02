#!/usr/bin/env python3
"""hues.mul -> assets/uo/hues.json (granule assets.hues).

Layout (docs/03 §3.2b; znovu overeno 2026-10-02 primym ctenim):
  375 skupin x (4 B hlavicka + 8 x 88 B) = 3000 sad = 265 500 B PRESNE.
  zaznam = 32 barev (u16) + start (u16) + end (u16) + 20 B jmeno, ktere
  u vetsiny sad zni "Hue (start->end)".

POZOR (docs/10 P24): plochy model (4 + k*88) sedi na velikost souboru a na
PRVNICH OSMI sadach - proto se pouziva jen jako negativni kontrola. Rozhoduje
semanticka shoda na CELEM souboru: text v zaznamu vs. pole start/end.

Pouziti:
  python tools/uoextract/hues.py --install "<UO>" --out assets/uo/hues.json
  python tools/uoextract/hues.py --self-test
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

RECORD = 88
GROUP_SIZE = 4 + 8 * RECORD
SETS = 3000
GROUPS = SETS // 8
NAME_RE = re.compile(r"Hue \((\d+)->(\d+)\)")


def read_sets(raw: bytes, grouped: bool = True) -> list[dict]:
    """Precte vsech 3000 sad. `grouped=False` je plochy model (negativni kontrola)."""
    out: list[dict] = []
    for k in range(SETS):
        off = (k // 8) * GROUP_SIZE + 4 + (k % 8) * RECORD if grouped else 4 + k * RECORD
        colors = list(struct.unpack_from("<32H", raw, off))
        start, end = struct.unpack_from("<HH", raw, off + 64)
        name = raw[off + 68:off + RECORD].split(b"\x00")[0].decode("latin-1")
        out.append({"set": k, "group": k // 8, "start": start, "end": end,
                    "name": name, "colors": colors})
    return out


def semantic(sets: list[dict]) -> tuple[int, int, list[str]]:
    """(shody, kandidatu, priklady neshod): text 'Hue (X->Y)' musi sedet s start/end."""
    matches = 0
    candidates = 0
    bad: list[str] = []
    for s in sets:
        found = NAME_RE.search(s["name"])
        if not found:
            continue
        candidates += 1
        if int(found.group(1)) == s["start"] and int(found.group(2)) == s["end"]:
            matches += 1
        elif len(bad) < 3:
            bad.append(f"sada {s['set']}: text '{s['name']}' vs start={s['start']} end={s['end']}")
    return matches, candidates, bad


def _synthetic() -> bytes:
    """375 skupin s vyplnenymi sadami; jedna skupina ma schvalne rozbity start."""
    raw = bytearray(GROUPS * GROUP_SIZE)
    for g in range(GROUPS):
        base = g * GROUP_SIZE
        for i in range(8):
            k = g * 8 + i
            off = base + 4 + i * RECORD
            for c in range(32):
                struct.pack_into("<H", raw, off + 2 * c, (k * 7 + c) % 65535)
            start, end = 100 + k, 200 + k
            struct.pack_into("<HH", raw, off + 64, start, end)
            text = f"Hue ({start}->{end})".encode("latin-1")
            raw[off + 68:off + 68 + len(text)] = text
    broken = 50 * 8 + 3
    struct.pack_into("<H", raw, (broken // 8) * GROUP_SIZE + 4 + (broken % 8) * RECORD + 64, 999)
    return bytes(raw)


def self_test() -> int:
    raw = _synthetic()
    grouped = read_sets(raw, True)
    flat = read_sets(raw, False)
    gm, gc, gbad = semantic(grouped)
    fm, fc, _ = semantic(flat)
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[hues] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    check(len(grouped) == SETS, f"skupinovy model precte {len(grouped)} sad (cekano {SETS})")
    check(gm == gc - 1, f"rozbita sada je odhalena: shod {gm} z {gc} kandidatu (cekano o 1 mene)")
    check(len(gbad) == 1, f"neshoda je pojmenovana ({gbad[:1]})")
    check(gm > fm, f"skupinovy model ({gm}) je nad plochym ({fm}) - negativni kontrola")
    check(semantic(read_sets(raw, True))[0] == gm, "vysledek je deterministicky (druhy pruchod)")
    print(f"[hues] self-test: {5} kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="hues.mul -> JSON (assets.hues)")
    ap.add_argument("--install", default=r"D:\Games\Electronic Arts\Ultima Online Classic")
    ap.add_argument("--out", default="assets/uo/hues.json")
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    src = Path(args.install) / "hues.mul"
    if not src.exists():
        print(f"[hues] CHYBA: {src} neexistuje")
        return 1
    raw = src.read_bytes()
    expected = GROUPS * GROUP_SIZE
    if len(raw) != expected:
        print(f"[hues] CHYBA: velikost {len(raw)} B != ocekavanych {expected} B")
        return 1

    grouped = read_sets(raw, True)
    gm, gc, bad = semantic(grouped)
    fm, fc, _ = semantic(read_sets(raw, False))
    print(f"[hues] sad: {len(grouped)}, soubor {len(raw)} B, skupin {GROUPS}")
    print(f"[hues] semanticka shoda SKUPINOVY model: {gm}/{gc}")
    print(f"[hues] semanticka shoda PLOCHY model:    {fm}/{fc}  (negativni kontrola, docs/10 P24)")

    payload = {
        "version": 1,
        "source": {"file": "hues.mul", "bytes": len(raw),
                   "sha256": hashlib.sha256(raw).hexdigest()},
        "layout": {"groups": GROUPS, "records": 8, "record_bytes": RECORD},
        "sets": grouped,
    }
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"[hues] zapsano {out} ({out.stat().st_size} B, sha256 {hashlib.sha256(text.encode()).hexdigest()})")

    if gc == 0:
        print("[hues] CHYBA: zadny zaznam nema text 'Hue (X->Y)' - kontrola NEPROBĚHLA")
        return 1
    if gm != gc:
        print(f"[hues] CHYBA: {gc - gm} sad ma text, ktery nesedi s start/end ({bad})")
        return 1
    if not gm > fm:
        print(f"[hues] CHYBA: skupinovy model ({gm}) neni nad plochym ({fm}) - model je nejisty")
        return 1
    print(f"[hues] OK: {gm} shod, plochy model jen {fm}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
