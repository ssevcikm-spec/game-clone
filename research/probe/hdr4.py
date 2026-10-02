import os, struct
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop", "tileart.uop", "gumpartLegacyMUL.uop", "AnimationFrame1.uop",
         "AnimationSequence.uop", "MultiCollection.uop", "MainMisc.uop", "string_dictionary.uop"]
for fn in NAMES:
    with open(os.path.join(UODIR, fn), "rb") as f:
        d = f.read(48)
    print(fn)
    for i in range(0, 40, 4):
        print(f"   +{i:<3} {d[i:i+4].hex(' ')}   = {struct.unpack_from('<I', d, i)[0]}")
    print(f"   u64@16 = {struct.unpack_from('<Q', d, 16)[0]}   u64@20 = {struct.unpack_from('<Q', d, 20)[0]}")
    print()
