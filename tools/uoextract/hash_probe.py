"""Determine the exact hash-input string form for the UO UOP archives (measured, not assumed)."""
import os, sys, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from uop import UOFileUop, create_hash

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"

for fn, pat in (("artLegacyMUL.uop", "build/artlegacymul/%08d.tga"),
                ("gumpartLegacyMUL.uop", "build/gumpartlegacymul/%08d.tga")):
    p = os.path.join(UO, fn)
    u = UOFileUop(p)
    print("=" * 78)
    print(fn)
    print("  magic ok, version=%d timestamp=%d nextBlock=%d block_size=%d count=%d"
          % (u.version, u.format_timestamp, u.next_block, u.block_size, u.count))
    ents = u.read_entries()
    print("  blocks=%d total entries=%d nonzero offsets=%d"
          % (len(u.blocks), len(ents), sum(1 for e in ents if e.offset != 0)))
    fl = {}
    for e in ents:
        fl[e.flag] = fl.get(e.flag, 0) + 1
    print("  compression flags:", fl)
    hashes = set(e.hash for e in ents if e.offset != 0)
    print("  distinct hashes:", len(hashes))

    # Candidate name forms. The C# code does string.Format then overwrites the last
    # 4 chars with the little-endian uint32 index bytes (each byte as its own char).
    def form_a(idx):          # classic: decimal in the %08d slot, then zero-pad tail
        return pat % idx
    def form_b(idx):          # index bytes written as chars at the {0} position (10 chars)
        b = struct.pack('<I', idx)
        s = list(pat % 0)
        # find the %08d slot start
        head = pat.split('%08d')[0]
        for k in range(4):
            s[len(head)+k] = chr(b[k])
        return ''.join(s)
    def form_c(idx):          # index written as LE u32 in the last 4 chars
        head = pat.rsplit('.', 1)[0]
        b = struct.pack('<I', idx)
        return head[:-4] + ''.join(chr(x) for x in b) + '.' + pat.rsplit('.', 1)[1]
    def form_d(idx):          # tail zeroed after index chars
        head = pat.split('%08d')[0]
        b = struct.pack('<I', idx)
        return head + ''.join(chr(x) for x in b) + '0000.tga'

    for label, fnc in (("A decimal", form_a), ("B le-bytes", form_b),
                       ("C le-bytes-tail", form_c), ("D le-bytes+0000", form_d)):
        hit = 0
        for idx in range(0, 2000):
            if create_hash(fnc(idx)) in hashes:
                hit += 1
        print("   form %-16s matched %4d / 2000" % (label, hit))
    print()
