import os, sys, struct, collections
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
d = open(r"D:\Games\Electronic Arts\Ultima Online Classic\animdata.mul", "rb").read()
n = len(d)
print("animdata.mul size:", n)
print("candidate divisors with remainder 0:")
for s in range(1, 5000):
    if n % s == 0 and s >= 64:
        print(f"   stride {s:6} -> {n//s} records")
print("\nfirst 96 bytes:", d[:96].hex(" "))
print("as u16:", [struct.unpack_from("<H", d, 2*i)[0] for i in range(24)])
print("as u8 :", list(d[:48]))

# ClassicUO AnimDataLoader is tiny; reproduce its documented shape and see what fits:
# 68 bytes per body type is the documented model. Check the 68-stride structure.
for S in (68, 72, 76, 88, 132, 548, 1028):
    print(f"\n=== stride {S}: n/S = {n/S}")
    for k in range(3):
        o = k * S
        if o + 32 > n:
            break
        print(f"   rec[{k}] @{o}: {d[o:o+32].hex(' ')}")
