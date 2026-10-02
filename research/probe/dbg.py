import sys, traceback
sys.path.insert(0, r"E:\Workspaces\game-clone\research\probe")
import uop2

p = r"D:\Games\Electronic Arts\Ultima Online Classic\artLegacyMUL.uop"
f = open(p, "rb")
head = f.read(32)
print("head32:", head.hex(" "))
import struct
magic, ver, fmt, misc = struct.unpack("<IIII", head[:16])
nextblock, blocksize, count = struct.unpack("<qII", head[16:32])
print("magic", hex(magic), "ver", ver, "fmt", hex(fmt), "misc", misc)
print("nextblock", nextblock, "blocksize", blocksize, "count", count)
f.seek(nextblock)
blk = f.read(12)
print("block read len", len(blk), blk.hex(" "))
cnt, nxt = struct.unpack("<iQ", blk)
print("filesCount", cnt, "nextBlock", nxt)
rec = f.read(34)
print("rec", rec.hex(" "))
print("parsed", struct.unpack("<QiIIQIh", rec))
