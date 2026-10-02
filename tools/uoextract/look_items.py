"""Look at the real record structure around known item strings (anvil, leather, stone stairs)."""
import os

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
print("size", N)
print("N mod 41 =", N % 41, " N mod 30 =", N % 30, " N mod 37 =", N % 37, " N mod 26 =", N % 26)


def hexdump(a, b, base=None):
    base = a if base is None else base
    for off in range(a, b, 16):
        chunk = data[off:off+16]
        print("  %8d %08x  %-47s |%s|" % (off, off,
            " ".join("%02x" % c for c in chunk),
            "".join(chr(c) if 0x20 <= c < 0x7f else "." for c in chunk)))


print("\n=== region around 658708 ('anvil' x2, 41 apart) ===")
hexdump(658640, 658880)

print("\n=== region around 525227 ('leather' x6, 41 apart) ===")
hexdump(525180, 525460)

print("\n=== region around 534963 ('stone stairs' x6, 41 apart) ===")
hexdump(534900, 535180)
