"""
MYP0 UOP container reader - ported from ClassicUO src/ClassicUO.IO/UOFileUop.cs
SPDX-License-Identifier: BSD-2-Clause (ClassicUO). See report for licence notes.
"""
import struct, zlib

UOP_MAGIC = 0x0050594D


def create_hash(s: str) -> int:
    """Exact port of ClassicUO UOFileUop.CreateHash (in-place MD5 variant)."""
    M = 0xFFFFFFFF
    eax = ecx = edx = ebx = esi = edi = 0
    ln = len(s)
    ebx = edi = esi = (ln + 0xDEADBEEF) & M
    i = 0
    while i + 12 < ln:
        edi = (((ord(s[i+7]) << 24) | (ord(s[i+6]) << 16) | (ord(s[i+5]) << 8) | ord(s[i+4])) + edi) & M
        esi = (((ord(s[i+11]) << 24) | (ord(s[i+10]) << 16) | (ord(s[i+9]) << 8) | ord(s[i+8])) + esi) & M
        edx = (((ord(s[i+3]) << 24) | (ord(s[i+2]) << 16) | (ord(s[i+1]) << 8) | ord(s[i])) - esi) & M
        edx = ((edx + ebx) ^ (esi >> 28) ^ ((esi << 4) & M)) & M
        esi = (esi + edi) & M
        edi = ((edi - edx) ^ (edx >> 26) ^ ((edx << 6) & M)) & M
        edx = (edx + esi) & M
        esi = ((esi - edi) ^ (edi >> 24) ^ ((edi << 8) & M)) & M
        edi = (edi + edx) & M
        ebx = ((edx - esi) ^ (esi >> 16) ^ ((esi << 16) & M)) & M
        esi = (esi + edi) & M
        edi = ((edi - ebx) ^ (ebx >> 13) ^ ((ebx << 19) & M)) & M
        ebx = (ebx + esi) & M
        esi = ((esi - edi) ^ (edi >> 28) ^ ((edi << 4) & M)) & M
        edi = (edi + ebx) & M
        i += 12
    rem = ln - i
    if rem > 0:
        if rem >= 12: esi = (esi + (ord(s[i+11]) << 24)) & M
        if rem >= 11: esi = (esi + (ord(s[i+10]) << 16)) & M
        if rem >= 10: esi = (esi + (ord(s[i+9]) << 8)) & M
        if rem >= 9:  esi = (esi + ord(s[i+8])) & M
        if rem >= 8:  edi = (edi + (ord(s[i+7]) << 24)) & M
        if rem >= 7:  edi = (edi + (ord(s[i+6]) << 16)) & M
        if rem >= 6:  edi = (edi + (ord(s[i+5]) << 8)) & M
        if rem >= 5:  edi = (edi + ord(s[i+4])) & M
        if rem >= 4:  ebx = (ebx + (ord(s[i+3]) << 24)) & M
        if rem >= 3:  ebx = (ebx + (ord(s[i+2]) << 16)) & M
        if rem >= 2:  ebx = (ebx + (ord(s[i+1]) << 8)) & M
        if rem >= 1:  ebx = (ebx + ord(s[i])) & M
        esi = ((esi ^ edi) - ((edi >> 18) ^ ((edi << 14) & M))) & M
        ecx = ((esi ^ ebx) - ((esi >> 21) ^ ((esi << 11) & M))) & M
        edi = ((edi ^ ecx) - ((ecx >> 7) ^ ((ecx << 25) & M))) & M
        esi = ((esi ^ edi) - ((edi >> 16) ^ ((edi << 16) & M))) & M
        edx = ((esi ^ ecx) - ((esi >> 28) ^ ((esi << 4) & M))) & M
        edi = ((edi ^ edx) - ((edx >> 18) ^ ((edx << 14) & M))) & M
        eax = ((esi ^ edi) - ((edi >> 8) ^ ((edi << 24) & M))) & M
        return ((edi << 32) | eax) & 0xFFFFFFFFFFFFFFFF
    return ((esi << 32) | eax) & 0xFFFFFFFFFFFFFFFF


class UopEntry:
    __slots__ = ('offset', 'header_length', 'compressed_length', 'decompressed_length',
                 'hash', 'data_hash', 'flag')

    def __repr__(self):
        return ('UopEntry(off=%d hdr=%d clen=%d dlen=%d flag=%d)'
                % (self.offset, self.header_length, self.compressed_length,
                   self.decompressed_length, self.flag))


class UOFileUop:
    def __init__(self, path):
        self.path = path
        self.f = open(path, 'rb')
        self.entries = []           # list of UopEntry
        self.blocks = []            # (filesCount, nextBlock, first_entry_index)
        self._read_header()

    def _read_header(self):
        f = self.f
        f.seek(0)
        head = f.read(28)
        (magic, self.version, self.format_timestamp,
         self.next_block, self.block_size, self.count) = struct.unpack('<IIIqiI', head)
        if magic != UOP_MAGIC:
            raise ValueError('bad UOP magic 0x%08x' % magic)

    def read_entries(self):
        f = self.f
        nb = self.next_block
        while True:
            f.seek(nb)
            data = f.read(12)
            files_count, next_block = struct.unpack('<iq', data)
            self.blocks.append((files_count, next_block, len(self.entries)))
            blob = f.read(files_count * 34)
            for i in range(files_count):
                (offset, header_length, clen, dlen, h,
                 data_hash, flag) = struct.unpack_from('<qiiiQIH', blob, i*34)
                e = UopEntry()
                e.offset = offset
                e.header_length = header_length
                e.compressed_length = clen
                e.decompressed_length = dlen
                e.hash = h
                e.data_hash = data_hash
                e.flag = flag
                self.entries.append(e)
            if next_block == 0:
                break
            nb = next_block
        return self.entries

    def read_data(self, e: UopEntry):
        """Return the decompressed payload for an entry (or None)."""
        if e.offset == 0:
            return None
        real = e.offset + e.header_length
        self.f.seek(real)
        if e.flag == 1:
            raw = self.f.read(e.compressed_length)
            return zlib.decompress(raw)
        elif e.flag == 0:
            return self.f.read(e.decompressed_length)
        else:
            raise NotImplementedError('compression flag %d (3 = zlib+bwt) unsupported' % e.flag)
