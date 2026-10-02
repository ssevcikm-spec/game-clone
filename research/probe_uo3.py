"""Treti sonda: primy pohled na bajty tam, kde modelovani layoutu selhalo."""
import re
import struct
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

UO = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")


def hexdump(data, start, length, base=0, group=1):
    end = min(start + length, len(data))
    for off in range(start, end, 16):
        chunk = data[off:off + 16]
        hexs = " ".join(chunk[i:i + group].hex() for i in range(0, len(chunk), group))
        text = "".join(chr(c) if 32 <= c < 127 else "." for c in chunk)
        print(f"{off:>9} (+{off - base:>7}) {hexs:<48} |{text}|")


print("=" * 78)
print("TILEDATA.MUL — prvnich 320 B (land blok?)")
print("=" * 78)
td = (UO / "tiledata.mul").read_bytes()
hexdump(td, 0, 320)

print()
print("=" * 78)
print("kde jsou zname retezce")
print("=" * 78)
for needle in (b"anvil", b"forge", b"stone stairs", b"leather", b"ore", b"pickaxe",
               b"UNUSED", b"VOID!!!!!!", b"NODRAW", b"grass", b"water"):
    offs = [m.start() for m in re.finditer(re.escape(needle), td)][:6]
    print(f"   {needle!r:16} offsety={offs}")

print()
print("=" * 78)
print("okolí retezce 'stone stairs' — jak vypada zaznam pred nazvem?")
print("=" * 78)
m = re.search(rb"stone stairs", td)
if m:
    print(f"offset {m.start()}")
    hexdump(td, max(0, m.start() - 96), 176, base=m.start())

print()
print("=" * 78)
print("okolí retezce 'anvil'")
print("=" * 78)
m2 = re.search(rb"anvil", td)
if m2:
    print(f"offset {m2.start()}")
    hexdump(td, max(0, m2.start() - 96), 176, base=m2.start())

print()
print("=" * 78)
print("HUES.MUL — struktura")
print("=" * 78)
hu = (UO / "hues.mul").read_bytes()
print("prvnich 192 B:")
hexdump(hu, 0, 192)
vals = struct.unpack_from(f"<{min(len(hu)//2, 400)}H", hu, 0)
print("\nprvnich 120 uint16:", [hex(v) for v in vals[:120]])
print("\nuint16 na offsetu 64 B (index 32):", [hex(v) for v in vals[32:32 + 40]])
print("uint16 na offsetu 88 B (index 44):", [hex(v) for v in vals[44:44 + 40]])
print("uint16 na offsetu 90 B (index 45):", [hex(v) for v in vals[45:45 + 40]])
print("konec souboru (poslednich 64 B):")
hexdump(hu, len(hu) - 64, 64)

print()
print("=" * 78)
print("ANIMINFO.MUL / drobne soubory")
print("=" * 78)
ai = (UO / "animinfo.mul").read_bytes()
print("animinfo.mul prvnich 96 B:")
hexdump(ai, 0, 96)
print("animinfo.mul jako uint16:", [hex(v) for v in struct.unpack_from("<24H", ai, 0)])
