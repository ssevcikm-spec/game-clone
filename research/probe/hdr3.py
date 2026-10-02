import struct, os
UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
NAMES = ["artLegacyMUL.uop", "tileart.uop", "gumpartLegacyMUL.uop", "AnimationFrame1.uop",
         "AnimationFrame2.uop", "AnimationFrame3.uop", "AnimationFrame4.uop", "AnimationFrame6.uop",
         "AnimationSequence.uop", "MultiCollection.uop", "MainMisc.uop", "string_dictionary.uop"]
print(f"{'file':<26}{'ver':>4}{'hashCap':>10}{'nextBlock':>12}{'blockSize':>11}  htEnd    firstBlock@")
for fn in NAMES:
    p = os.path.join(UODIR, fn)
    if not os.path.exists(p):
        print(f"{fn:<26} MISSING")
        continue
    with open(p, "rb") as f:
        d = f.read(32)
    ver = struct.unpack_from("<I", d, 4)[0]
    cap = struct.unpack_from("<I", d, 12)[0]
    nb = struct.unpack_from("<I", d, 20)[0]
    bs = struct.unpack_from("<I", d, 28)[0]
    print(f"{fn:<26}{ver:>4}{cap:>10}{nb:>12}{bs:>11}  {32+16*cap:<8} {nb}")
