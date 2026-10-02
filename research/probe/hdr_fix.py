import os, sys, struct
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop","tileart.uop","gumpartLegacyMUL.uop","AnimationFrame1.uop",
         "AnimationSequence.uop","MultiCollection.uop","MainMisc.uop","string_dictionary.uop",
         "map0LegacyMUL.uop","map1LegacyMUL.uop","map2LegacyMUL.uop","map3LegacyMUL.uop",
         "map4LegacyMUL.uop","map5LegacyMUL.uop","map0xLegacyMUL.uop","soundLegacyMUL.uop"]
print(f"{'file':<26}{'ver':>4}{'nextBlock(u64@12)':>20}{'u32@20':>10}{'i32@24':>10}{'u32@28':>10}")
for fn in NAMES:
    p = os.path.join(UODIR, fn)
    if not os.path.exists(p):
        print(f"{fn:<26} MISSING"); continue
    with open(p, "rb") as f:
        d = f.read(32)
    ver = struct.unpack_from("<I", d, 4)[0]
    nb  = struct.unpack_from("<Q", d, 12)[0]
    a20 = struct.unpack_from("<I", d, 20)[0]
    a24 = struct.unpack_from("<i", d, 24)[0]
    a28 = struct.unpack_from("<I", d, 28)[0]
    print(f"{fn:<26}{ver:>4}{nb:>20}{a20:>10}{a24:>10}{a28:>10}")
