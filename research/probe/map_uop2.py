import os, sys, struct, collections
sys.path.insert(0, r"E:\Workspaces\game-clone\research\probe")
sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from uop_final import Uop, hashlittle2

UODIR = r"D:\Games\Electronic Arts\Ultima Online Classic"
for fn, pat in (("map0LegacyMUL.uop", "build/map0legacymul/{:08d}.dat"),
                ("map1LegacyMUL.uop", "build/map1legacymul/{:08d}.dat"),
                ("map2LegacyMUL.uop", "build/map2legacymul/{:08d}.dat"),
                ("map3LegacyMUL.uop", "build/map3legacymul/{:08d}.dat"),
                ("map4LegacyMUL.uop", "build/map4legacymul/{:08d}.dat"),
                ("map5LegacyMUL.uop", "build/map5legacymul/{:08d}.dat"),
                ("map0xLegacyMUL.uop", "build/map0legacymul/{:08d}.dat")):
    p = os.path.join(UODIR, fn)
    if not os.path.exists(p):
        print(f"{fn}: MISSING"); continue
    u = Uop(p)
    names = {}
    for i in range(8192):
        names.setdefault(hashlittle2(pat.format(i)), i)
    present = sorted(names[h] for h in u.entries if h in names)
    runs = []
    if present:
        s = prev = present[0]
        for v in present[1:]:
            if v != prev + 1:
                runs.append((s, prev)); s = v
            prev = v
        runs.append((s, prev))
    dl = collections.Counter(e["dlen"] for e in u.entries.values())
    hd = collections.Counter(e["hlen"] for e in u.entries.values())
    uniq = names and len(set(present))
    print(f"{fn}: size={u.size} ver={u.version} nextBlock={u.nextblock} count={u.count} "
          f"blocks={len(u.blocks)} entries={len(u.entries)}")
    print(f"   pattern matches={len(present)} unique={uniq}")
    print(f"   dlen histogram (top3)={dl.most_common(3)}  hlen={dict(hd)}")
    print(f"   index runs ({len(runs)}): {runs[:8]}{' ...' if len(runs) > 8 else ''}")
    print(f"   min={present[0] if present else None} max={present[-1] if present else None}")
