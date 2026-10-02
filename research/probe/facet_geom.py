import os, sys, struct
sys.path.insert(0, r"E:\Workspaces\game-clone\research\probe")
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from uop_verified import Uop, hashlittle2

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
CHUNK = 0xC4000            # 802816 = 4096 blocks of 196 bytes
BLOCKS_PER_CHUNK = 4096

# staidx gives the authoritative block grid
print("=== facet geometry from staidx*.mul (12 B/block) ===")
for i in range(6):
    for suffix, label in (("", "statics facet"), ("x", "statics x-layer")):
        f = f"staidx{i}{suffix}.mul"
        p = os.path.join(UODIR, f)
        if not os.path.exists(p):
            print(f"  {f:<16} MISSING"); continue
        s = os.path.getsize(p)
        nb = s / 12
        # solve blocksX, blocksY: prefer published widths
        cand = [(bx, nb / bx) for bx in (896, 768, 512, 288, 256, 192, 144, 128, 96)
                if nb % bx == 0]
        print(f"  {f:<16} {s:>10} B  blocks={int(nb):>7}  "
              f"factorisations={[(bx, int(by)) for bx, by in cand]}")

print("\n=== map UOP chunk counts and nominal facet size ===")
for i in range(6):
    for suffix in ("", "x"):
        fn = f"map{i}{suffix}LegacyMUL.uop"
        p = os.path.join(UODIR, fn)
        if not os.path.exists(p):
            continue
        u = Uop(p)
        pat = f"build/map{i}legacymul/{{:08d}}.dat"
        present = [k for k in range(8192) if u.get(pat.format(k))]
        nch = len(present)
        nominal = nch * CHUNK
        # the last chunk dlen tells us the leftover blocks
        last = u.get(pat.format(max(present)))
        leftover_blocks = last["dlen"] // 196
        total_blocks = (nch - 1) * BLOCKS_PER_CHUNK + leftover_blocks
        print(f"{fn:<24} size={u.size:>10} chunks={nch:<4} nominal(nch*0xC4000)={nominal:>10} "
              f"lastChunkBlocks={leftover_blocks:<5} totalBlocks={total_blocks}")
