"""
PROOF-DRIVEN layout determination for tiledata.mul items.

A record that starts at absolute offset S with the layout
    [u64 flags][u8 weight][u8 layer][i32 count][u16 animID][u16 hue][u16 light][u8 height][20 name]
     0..7        8           9          10..13      14..15      16..17    18..19       20      21..40
has its name at S+21 and is 41 bytes long.

DECISIVE self-consistency test (a name must match its numbers):
   The placeholder records in this file carry name "decimated_NoName" and
   count = 0xFFFF7801 = -34815 = -(0x37FF) ... i.e. count == -animID - 1.
   If our alignment is right this must hold for EVERY such record.
"""
import os, collections

UO = r"D:\Games\Electronic Arts\Ultima Online Classic"
data = open(os.path.join(UO, "tiledata.mul"), "rb").read()
N = len(data)
STRIDE, NAMEOFF, FLAGLEN = 41, 21, 8


def rec(S):
    return dict(
        flags=int.from_bytes(data[S:S+8], 'little'),
        weight=data[S+8], layer=data[S+9],
        count=int.from_bytes(data[S+10:S+14], 'little', signed=True),
        animID=int.from_bytes(data[S+14:S+16], 'little'),
        hue=int.from_bytes(data[S+16:S+18], 'little'),
        light=int.from_bytes(data[S+18:S+20], 'little'),
        height=data[S+20],
        name=data[S+21:S+41].split(b'\0')[0].decode('ascii', 'replace'),
    )


# The name "decimated_NoName" occurrences measured: 391908 and 391938 (30 apart)
# and a long run 30 apart from 403206.  Try both alignments and check the
# count == -(animID+1) identity.
print("=== test alignment via count == -(animID+1) identity ===")
for base in range(0, 41):
    for anchor in (391908, 403206):
        S0 = anchor - NAMEOFF - base*STRIDE
        hits = miss = 0
        k = 0
        while True:
            S = S0 + k*STRIDE
            if S < 0 or S+41 > N: break
            r = rec(S)
            if r['name'] == 'decimated_NoName':
                if r['count'] == -(r['animID']+1): hits += 1
                else: miss += 1
            k += 1
        if hits+miss > 5:
            print("  base=%2d anchor=%6d -> NoName records %3d, identity holds %3d, fails %3d"
                  % (base, anchor, hits+miss, hits, miss))
