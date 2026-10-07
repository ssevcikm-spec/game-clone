#!/usr/bin/env python3
"""texmap(id) -> RGBA obrazek (granule `assets.texmaps`).

K cemu to je: UO kresli TEREN DVEma zpusoby (ClassicUO `LandView.cs:58-96`):
  * rovna dlazdice  -> land ART (diamant 44x44, `assets.art`),
  * svah (soused ma jinou vysku) -> TEXMAP natazeny pres ctyrrohy dlazdice
    (a prave tim se zaplni mezera, ktera je dnes u pobrezi videt jako "sedy pas").
Ktera cesta se pouzije, rozhoduje `tiledata.land.texture` (TexID):
  * `TexID == 0 && Wet` ... voda = art (ClassicUO `Land.cs:48`),
  * TexID bez zaznamu v texmaps ... art (`Land.cs:98`),
  * jinak ... texmap, ale JEN kdyz se lisi vyska nektereho ze 4 sousedu
    (`CalculateNormal`, `Land.cs:158-161`); rovna plocha zustava art.

FORMAT JE MERENY / portovany z ClassicUO (`TexmapsLoader.cs`, BSD-2):
  `texidx.mul` = 12 B na zaznam `[u32 offset][u32 delka][u32 extra]`,
  `texmaps.mul` = data: `u16` na pixel (RGB555, horni bit neni pruhlednost -
  alfa je VZDY 255, `TexmapsLoader.cs:88`).
  Delka 0x2000 = 64x64, 0x8000 = 128x128 (`:79`).
  `TexTerr.def` (285 radku, `index {zdroj}`) PREMAPOVAVA pixely: ClassicUO
  zkopiruje zaznam zdroje na dany index (`:31-66`). Je to aplikovane tady -
  jinak by se u tech indexu kreslila jina textura, nez kresli klient.

Pouzeti:
  python tools/uoextract/texmaps.py --verify
  python tools/uoextract/texmaps.py --dump assets/uo/texmap-preview
  python tools/uoextract/texmaps.py --self-test
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
MAX_TEXMAP = 0x4000
IDX_ENTRY = 12
# Vzorky pro lidskou kontrolu: index -> co to ma byt (podle jmena land dlazdice,
# ktera texmap pouziva - hodnoty se berou z tiledata, ne z hlavy)
KNOWN = {
    "trava": 3,        # land 3 'grass' ma texture 3
    "pisek": 34,       # land 34 'sand'
    "hlina": 76,       # land 81..100 (NoName, svah u pobrezi) ma texture 76
}


def c16(value: int) -> tuple[int, int, int]:
    return (((value >> 10) & 0x1F) * 255 // 31,
            ((value >> 5) & 0x1F) * 255 // 31,
            (value & 0x1F) * 255 // 31)


class TexmapArchive:
    """Cteni texmaps.mul + texidx.mul (+ remap z TexTerr.def)."""

    def __init__(self, install: str | Path = DEFAULT_INSTALL,
                 raw: tuple[bytes, bytes] | None = None) -> None:
        zaklad = Path(install)
        if raw is None:
            self.idx = (zaklad / "texidx.mul").read_bytes()
            self.mul = (zaklad / "texmaps.mul").read_bytes()
        else:
            self.idx, self.mul = raw
        self.entries = self._entried()
        self.remap: dict[int, int] = self._textterr(zaklad)
        for cil, zdroj in self.remap.items():
            if 0 <= cil < MAX_TEXMAP and 0 <= zdroj < len(self.entries):
                self.entries[cil] = self.entries[zdroj]

    def _entried(self) -> list[tuple[int, int]]:
        out: list[tuple[int, int]] = []
        for i in range(len(self.idx) // IDX_ENTRY):
            off, ln, _extra = struct.unpack_from("<III", self.idx, i * IDX_ENTRY)
            out.append((off, ln))
        return out

    def _textterr(self, zaklad: Path) -> dict[int, int]:
        cesta = zaklad / "TexTerr.def"
        if not cesta.exists():
            return {}
        out: dict[int, int] = {}
        for radek in cesta.read_text(encoding="latin-1", errors="replace").splitlines():
            casti = radek.replace("{", " ").replace("}", " ").split()
            if len(casti) < 2:
                continue
            try:
                cil = int(casti[0])
            except ValueError:
                continue
            for text in casti[1:]:
                try:
                    out[cil] = int(text)     # posledni v skupine vyhrava (jako ClassicUO)
                except ValueError:
                    continue
        return out

    def payload(self, index: int) -> bytes | None:
        if not 0 <= index < len(self.entries):
            return None
        off, ln = self.entries[index]
        if ln not in (0x2000, 0x8000) or off + ln > len(self.mul):
            return None
        return self.mul[off:off + ln]

    def texmap(self, index: int):
        """(w, h, pixely) nebo None - pixely jsou radky (r, g, b, 255)."""
        data = self.payload(index)
        if data is None:
            return None
        rozmer = 64 if len(data) == 0x2000 else 128
        pixely = []
        for y in range(rozmer):
            radek = []
            for x in range(rozmer):
                r, g, b = c16(struct.unpack_from("<H", data, (y * rozmer + x) * 2)[0])
                radek.append((r, g, b, 255))
            pixely.append(radek)
        return rozmer, rozmer, pixely

    def rozsah(self) -> list[int]:
        return [i for i in range(MAX_TEXMAP) if self.payload(i) is not None]


def to_image(width: int, height: int, pixely):
    from PIL import Image
    obrazek = Image.new("RGBA", (width, height))
    obrazek.putdata([pixely[y][x] for y in range(height) for x in range(width)])
    return obrazek


def verify(archive: TexmapArchive, limit: int | None = None) -> tuple[int, list[str]]:
    kontroly = 0
    chyby: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal kontroly
        kontroly += 1
        if not ok:
            chyby.append(text)

    vsechny = archive.rozsah()
    check(len(vsechny) > 1000, f"texmap zaznamu jen {len(vsechny)} (ocekavano tisice)")
    velikosti: dict[int, int] = {}
    for i in (vsechny if limit is None else vsechny[:limit]):
        vysledek = archive.texmap(i)
        if vysledek is None:
            chyby.append(f"texmap {i} se nerozbalil")
            continue
        w, h, pixely = vysledek
        velikosti[w] = velikosti.get(w, 0) + 1
        if w != h or any(p[3] != 255 for radek in pixely for p in radek):
            chyby.append(f"texmap {i}: rozmer {w}x{h} nebo pruhledny pixel")
    check(len(chyby) == 0, f"rozbalene texmapy maji chyby: {chyby[:3]}")
    check(set(velikosti) <= {64, 128}, f"podezrele velikosti: {velikosti}")
    check(archive.remap != {}, "TexTerr.def se nenacetl (remap je prazdny)")
    return kontroly, chyby


def dump(archive: TexmapArchive, out_dir: Path) -> int:
    (out_dir).mkdir(parents=True, exist_ok=True)
    for jmeno, index in KNOWN.items():
        vysledek = archive.texmap(index)
        if vysledek is None:
            print(f"[texmaps] {jmeno} ({index}) nema data")
            continue
        w, h, pixely = vysledek
        cesta = out_dir / f"texmap_{jmeno}_{index:05d}.png"
        to_image(w, h, pixely).save(cesta)
        print(f"[texmaps] {jmeno} ({index}) -> {cesta} ({w}x{h})")
    return 0


def self_test() -> int:
    """Offline: synteticky archiv (zadna instalace UO)."""
    kontroly = 0
    chyby: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal kontroly
        kontroly += 1
        if not ok:
            chyby.append(text)

    # dva zaznamy: 64x64 s jednou barvou, 128x128 s jinou; + remap 2 -> 0
    def telo(rozmer: int, barva: int) -> bytes:
        return struct.pack(f"<{rozmer * rozmer}H", *([barva] * (rozmer * rozmer)))

    mul = telo(64, 0b11111_00000_00000) + telo(128, 0b00000_11111_00000) + telo(64, 0)
    idx = struct.pack("<III", 0, 0x2000, 0) + struct.pack("<III", 0x2000, 0x8000, 0) \
        + struct.pack("<III", 0x2000 + 0x8000, 0x2000, 0) + b"\x00" * (9 * IDX_ENTRY)
    archiv = TexmapArchive(raw=(idx, mul))
    check(len(archiv.rozsah()) == 3, f"rozsah ma {len(archiv.rozsah())} misto 3")
    w, h, pixely = archiv.texmap(0)
    check(w == 64 and h == 64, f"texmap 0 ma {w}x{h} (cekano 64x64)")
    check(pixely[0][0] == (255, 0, 0, 255), f"texmap 0 pixel {pixely[0][0]}")
    w2, h2, pixely2 = archiv.texmap(1)
    check(w2 == 128 and pixely2[0][0] == (0, 255, 0, 255),
          f"texmap 1 ma {w2}x{pixely2[0][0]}")
    check(archiv.payload(16383) is None, "index mimo data vraci None")
    print(f"[texmaps] self-test: {kontroly} kontrol, {len(chyby)} chyb")
    for chyba in chyby:
        print(f"[texmaps] CHYBA: {chyba}")
    return 1 if chyby else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="texmaps.mul -> obrazky")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--limit", type=int, default=None)
    ap.add_argument("--dump", default=None)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    archiv = TexmapArchive(args.install)
    print(f"[texmaps] zaznamu: {len(archiv.rozsah())} z {MAX_TEXMAP}, "
          f"remap z TexTerr.def: {len(archiv.remap)}")
    if args.dump:
        return dump(archiv, Path(args.dump))
    kontroly, chyby = verify(archiv, args.limit)
    print(f"[texmaps] overeno: {kontroly} kontrol, {len(chyby)} chyb")
    for chyba in chyby[:10]:
        print(f"[texmaps] CHYBA: {chyba}")
    return 1 if chyby else 0


if __name__ == "__main__":
    raise SystemExit(main())
