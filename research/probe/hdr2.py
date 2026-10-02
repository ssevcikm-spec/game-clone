import struct, os
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop", "tileart.uop", "gumpartLegacyMUL.uop", "AnimationFrame1.uop",
         "AnimationSequence.uop", "MultiCollection.uop", "MainMisc.uop", "string_dictionary.uop"]
print(f"{'file':<26}{'u32@8':>12}{'u32@12':>12}{'u64@16':>16}{'u32@24':>10}{'u32@28':>10}   blk@u64off16")
for fn in NAMES:
    p = os.path.join(UODIR, fn)
    with open(p, "rb") as f:
        d = f.read(64)
    a = struct.unpack_from("<I", d, 8)[0]
    b = struct.unpack_from("<I", d, 12)[0]
    c = struct.unpack_from("<Q", d, 16)[0]
    e = struct.unpack_from("<I", d, 24)[0]
    g = struct.unpack_from("<I", d, 28)[0]
    print(f"{fn:<26}{a:>12}{b:>12}{c:>16}{e:>10}{g:>10}")
    print(f"   raw[0:32] = {d[:32].hex(' ')}")
