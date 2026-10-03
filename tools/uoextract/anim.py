#!/usr/bin/env python3
"""anim(body, action, dir) - animace tela a ROZHODNUTI o zdroji (granule assets.anim).

ROZHODNUTI O ZDROJI (docs/03 §3.5.1, O3) - UDELANO MERENIM 2026-10-03,
ne podle doporuceni v dokumentu. Dokument radil "UOP, MUL jen jako fallback";
mEReni to vyvraci:

    anim*.mul .......... 270 tela / 7 165 akci (monstra, zvirata, LIDE 400+)
    AnimationFrame*.uop  318 tela / 10 989 akci (nova tela 400+, gargoyle)
    prunik ................ 2 tela (826, 990)

Tela se tedy temER nepotkavaji a je nutne pouzit OBA zdroje. MUL je povinny:
telo 400 (muz) a 401 (zena) maji v MUL 35 akci x 5 smeru = 175 bloku, v UOP
NULA - bez anim.mul se hrac nepohne. Pravidlo: blok v MUL -> MUL, jinak UOP
(stejne jako ClassicUO pres `UseUopAnimation` a UOFiddler pres `IsUopBody`).

Mereni a surova data: research/anim-mereni.md, research/anim-pokryti.json,
reprodukce: python research/probe/anim_pokryti.py

CO JE OVERENE (a co ne) - docs/10 zada "nemERene = nestavet":
  OVERENO  anim.idx = 148 810 slotu x 12 B, offset po skupinach (soucet sedi
           presne na velikost souboru); tabulka framu v bloku = [u32 pocet] na
           bajtu 512 + pocet x u32 offset od 516; terminátor RLE 0x7FFF7FFF
           lezi 4 B pred koncem framu (overeno na vsech 10 framech bloku).
  OVERENO  Prvnich 512 B bloku je ve VSECH blocich STEJNYCH (tela 400/200/9,
           ruzne akce - bit po bitu) -> pixely tela NEMAJI vlastni paletu;
           barva jde z animdata.mul/hues.mul (research/05-data-formats.md §5.2).
  OVERENO  UOP zaznam se adresuje jmenem
           "build/animationlegacyframe/{telo:06d}/{akce:02d}.bin" a hashem
           create_hash (z uop.py): 4 747 nalezenych na vzorku 700 tela x 80 akci,
           zatimco jenkins_pc_pb 0.
  NEOVERENO tvar hlavicky framu a kódovani indexu v RLE proudu. `x` z hlavicky
           behu vychazi 1020..1023, tedy MIMO rozmer framu (24x64). Pixely se
           proto ZAMERNE neextrahuji - vrací se jen to, co je zmerene.

Pouziti:
  python tools/uoextract/anim.py --verify            # zmer vsechna tela
  python tools/uoextract/anim.py --body 400          # detail jednoho tela
  python tools/uoextract/anim.py --self-test         # offline test se znamym vzorkem
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from uop import UopFile, create_hash  # noqa: E402

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"
IDX_BLOCK = 12
DIRS = 5
MAX_BODIES = 2048
MAX_ACTIONS = 80            # UOP: "gargoyle is like 78" (ClassicUO MAX_ACTIONS)
HIGH_ACTIONS = 22           # monstra (telo < 200)
LOW_ACTIONS = 13            # zvirata (200..399)
PEOPLE_ACTIONS = 35         # lide (400+)
UOP_NAME = "build/animationlegacyframe/{0:06d}/{1:02d}.bin"
MUL_TERMINATOR = 0x7FFF7FFF
FRAME_TABLE_OFFSET = 512    # [u32 pocet framu] hned za prvnimi 512 B bloku


def mul_slot(body: int, action: int, direction: int) -> tuple[int, int]:
    """(offset v anim.idx, pocet akci skupiny) pro (telo, akce, smer)."""
    if body < 200:
        return body * 110 * IDX_BLOCK + (action * DIRS + direction) * IDX_BLOCK, HIGH_ACTIONS
    if body < 400:
        return (((body - 200) * 65 + 22000) * IDX_BLOCK
                + (action * DIRS + direction) * IDX_BLOCK), LOW_ACTIONS
    return (((body - 400) * 175 + 35000) * IDX_BLOCK
            + (action * DIRS + direction) * IDX_BLOCK), PEOPLE_ACTIONS


class MulAnim:
    """anim.idx + anim.mul pro jedno telo (smycka A je v souboru bez cisla)."""

    PRAZDNY = 0xFFFFFFFF      # prazdny slot v anim.idx je (-1,-1,-1) - mEReno

    def __init__(self, install: str | Path, loop: str = "") -> None:
        self.install = Path(install)
        # smycka 1 je v instalaci bez cisla: anim.idx / anim.mul (ClassicUO i UOFiddler)
        self.loop = loop
        self.nazev = f"anim{loop}" if loop else "anim"
        self.idx = (self.install / f"{self.nazev}.idx").read_bytes()
        self.mul_size = (self.install / f"{self.nazev}.mul").stat().st_size

    def block(self, body: int, action: int, direction: int = 0) -> dict | None:
        """Blok animace: {offset, size, frames:[{cx,cy,w,h}], zdroj: 'mul'}."""
        poz, akci = mul_slot(body, action, direction)
        if action >= akci or poz + IDX_BLOCK > len(self.idx):
            return None
        off, size, _u = struct.unpack_from("<III", self.idx, poz)
        if (size == 0 or off == 0 or off == self.PRAZDNY or _u == self.PRAZDNY
                or off + size > self.mul_size):
            return None
        data = self._blok(off, size)
        if data is None:
            return None
        frames = frames_of(data)
        if not frames:
            # Slot ma data, ale tabulka framu se necte -> pro pokryti to NENI
            # akce s obsahem (jinak by pocet akci nesedel s mERenim v sonde).
            return None
        return {"offset": off, "size": size, "frames": frames,
                "source": f"{self.nazev}.mul"}

    def _blok(self, off: int, size: int) -> bytes | None:
        with open(self.install / f"{self.nazev}.mul", "rb") as f:
            f.seek(off)
            data = f.read(size)
        return data if len(data) == size else None


def frames_of(block: bytes) -> list[dict]:
    """Tabulka framu z bloku anim.mul - MERENA cast (rozmery a offsety).

    Tabulka je [u32 pocet] na bajtu 512 a `pocet x u32` offsetu od 516.
    Hlavicka framu se cte na `516+offset-4` (overeno na vsech framech bloku:
    rozmer vychazi 24x64, 26x60, ... a terminátor lezi 4 B pred koncem framu).
    """
    if len(block) < FRAME_TABLE_OFFSET + 8:
        return []
    pocet = struct.unpack_from("<I", block, FRAME_TABLE_OFFSET)[0]
    if not (1 <= pocet <= 200):
        return []
    tabulka = FRAME_TABLE_OFFSET + 4
    if tabulka + pocet * 4 > len(block):
        return []
    offsety = struct.unpack_from(f"<{pocet}I", block, tabulka)
    if any(offsety[i] <= offsety[i - 1] for i in range(1, pocet)):
        return []
    frames = []
    for i, o in enumerate(offsety):
        start = tabulka + o
        konec = tabulka + offsety[i + 1] if i + 1 < pocet else len(block)
        if start - 4 < 0 or start + 4 > konec:
            return []
        cx, cy = struct.unpack_from("<2h", block, start - 4)
        w, h = struct.unpack_from("<2H", block, start)
        # Strop je 512: mERene framy jsou i 447x157 a 453x163 (velka monstra),
        # mensi strop 400 zahodil 13 bloku, ktere ve skutecnosti v poradku jsou.
        if not (1 <= w <= 512 and 1 <= h <= 512):
            return []
        termin = False
        p = start + 4
        while p + 4 <= konec:
            (header,) = struct.unpack_from("<I", block, p)
            p += 4
            if header == MUL_TERMINATOR:
                termin = True
                break
            p += header & 0x0FFF
        frames.append({"cx": cx, "cy": cy, "w": w, "h": h, "terminator": termin})
    return frames


class UopAnim:
    """AnimationFrame1..10.uop - zaznamy se hledaji hashem jmena (create_hash)."""

    def __init__(self, install: str | Path) -> None:
        self.install = Path(install)
        self.files: list[tuple[int, UopFile, set[int]]] = []
        # Index hash -> (cislo souboru, zaznam). Bez nej je kazde hledani linearni
        # pruchod vsemi zaznamy (dohromady ~11 tisic) a mEReni pokryti trva
        # minuty - a to je u brany, ktera se pousti po kazde zmene, moc.
        self.index: dict[int, tuple[int, object]] = {}
        for i in range(1, 11):
            cesta = self.install / f"AnimationFrame{i}.uop"
            if not cesta.exists():
                continue
            u = UopFile(cesta)
            u.read_entries()
            self.files.append((i, u, {e.hash for e in u.entries if e.hash}))
            for e in u.entries:
                if e.hash:
                    self.index.setdefault(e.hash, (i, e))

    def entry(self, body: int, action: int):
        """(index souboru, UopFile, UopEntry) nebo (None, None, None)."""
        hodnota = create_hash(UOP_NAME.format(body, action))
        nalezeny = self.index.get(hodnota)
        if nalezeny is None:
            return None, None, None
        cislo, zaznam = nalezeny
        for i, u, _hashe in self.files:
            if i == cislo:
                return i, u, zaznam
        return None, None, None

    def actions(self, body: int) -> list[int]:
        return [a for a in range(MAX_ACTIONS) if self.entry(body, a)[0] is not None]

    def block(self, body: int, action: int) -> dict | None:
        """Zaznam v UOP: velikosti a seznam framu (rozmery zatim NEOVERENE)."""
        i, u, e = self.entry(body, action)
        if e is None:
            return None
        return {"file": f"AnimationFrame{i}.uop", "flag": e.flag,
                "compressed": e.compressed_length, "raw": e.decompressed_length,
                "frames": uop_frames(u.read_data(e)), "source": "uop"}


def uop_frames(data: bytes | None) -> list[dict]:
    """Hlavicky framu z UOP zaznamu - MERENA cast (skupina, id, pixelOffset).

    Telo zaznamu: [32 B hlavicka][i32 pocet framu][u32 dataStart], na dataStart
    `pocet x 16 B` = [u16 group][u16 frameId][u64][u32 pixelOffset].
    POZOR: rozmer framu se z pixelOffset v teto instalaci nepodarilo overit
    (viz research/anim-mereni.md) - proto se sem rozmery nevyrabi.
    """
    if data is None or len(data) < 36:
        return []
    pocet, data_start = struct.unpack_from("<iI", data, 32)
    if not (1 <= pocet <= 400) or data_start + pocet * 16 > len(data):
        return []
    frames = []
    for k in range(pocet):
        g, fid, _u64, pixoff = struct.unpack_from("<HHQI", data, data_start + k * 16)
        frames.append({"group": g, "frame_id": fid, "pixel_offset": pixoff})
    return frames


def pokryti(install: str | Path) -> dict:
    """Kolik tela ma obsah v MUL a kolik v UOP - rozhodnuti se o to opira."""
    mul = MulAnim(install)
    uop = UopAnim(install)
    mul_tela = {}
    for body in range(MAX_BODIES):
        akce = [a for a in range(mul_slot(body, 0, 0)[1])
                if mul.block(body, a) is not None]
        if akce:
            mul_tela[body] = akce
    uop_tela = {}
    for body in range(MAX_BODIES):
        akce = uop.actions(body)
        if akce:
            uop_tela[body] = akce
    return {"mul": mul_tela, "uop": uop_tela,
            "prunik": sorted(set(mul_tela) & set(uop_tela))}


def zdroj(body: int, mul_tela: dict, uop_tela: dict) -> str:
    """Pravidlo rozhodnuti: blok v MUL -> MUL, jinak UOP, jinak zadny."""
    if body in mul_tela:
        return "mul"
    return "uop" if body in uop_tela else "zadny"


def verify(install: str | Path) -> tuple[int, list[str]]:
    checks = 0
    errors: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(text)

    idx = (Path(install) / "anim.idx").read_bytes()
    check(len(idx) == 148810 * IDX_BLOCK,
          f"anim.idx ma {len(idx)} B, ocekavano {148810 * IDX_BLOCK} (148 810 slotu)")

    p = pokryti(install)
    mul_t, uop_t = p["mul"], p["uop"]
    print(f"[anim] MUL: tela {len(mul_t)}, akci {sum(len(v) for v in mul_t.values())}")
    print(f"[anim] UOP: tela {len(uop_t)}, akci {sum(len(v) for v in uop_t.values())}")
    print(f"[anim] prunik: {p['prunik']}")

    check(len(mul_t) > 250, f"MUL vraci jen {len(mul_t)} tel (mEReno 270)")
    akci_mul = sum(len(v) for v in mul_t.values())
    check(akci_mul >= 7100,
          f"MUL vraci {akci_mul} akci s obsahem; mEReno 7 144 Parsitelnych "
          f"z 7 162 bloku (18 ma jinou tabulku framu - docs/03 §3.5.1)")
    check(len(uop_t) > 200, f"UOP vraci jen {len(uop_t)} tel (mEReno 318)")
    for telo in (400, 401, 404):
        check(len(mul_t.get(telo, [])) == PEOPLE_ACTIONS,
              f"telo {telo} ma v MUL {len(mul_t.get(telo, []))} akci, mEReno {PEOPLE_ACTIONS}")
        check(telo not in uop_t,
              f"telo {telo} je i v UOP - pak je rozhodnuti o zdroji jinak, nez rika docs/03")
    for telo in (130, 334, 666):
        check(telo not in mul_t and telo in uop_t,
              f"telo {telo} ma byt jen v UOP (MUL={telo in mul_t}, UOP={telo in uop_t})")

    blok = MulAnim(install).block(400, 4)
    check(blok is not None, "blok tela 400 akce 4 (stand) se nenacetl")
    if blok:
        check(len(blok["frames"]) == 1,
              f"stand ma {len(blok['frames'])} framu, mEReno 1")
        if blok["frames"]:
            f = blok["frames"][0]
            check(f["w"] == 26 and f["h"] == 60,
                  f"stand ma rozmer {f['w']}x{f['h']}, mEReno 26x60")
            check(f["terminator"], "RLE proud framu nema terminátor 0x7FFF7FFF")
    walk = MulAnim(install).block(400, 0)
    check(walk is not None and len(walk["frames"]) == 10,
          f"walk ma {len(walk['frames']) if walk else 0} framu, mEReno 10")
    if walk:
        check(all(f["terminator"] for f in walk["frames"]),
              "ne vsechny framy walk maji terminátor (mEReno: vsech 10 ma)")

    z = zdroj(400, mul_t, uop_t)
    check(z == "mul", f"telo 400 vyslo jako zdroj '{z}', musi byt 'mul'")
    check(zdroj(334, mul_t, uop_t) == "uop", "telo 334 musi byt zdroj 'uop'")
    check(zdroj(9999, mul_t, uop_t) == "zadny", "neexistujici telo musi byt 'zadny'")

    print(f"[anim] {checks} kontrol, {len(errors)} chyb")
    for e in errors:
        print(f"[anim] CHYBA: {e}")
    return checks, errors


def _synthetic_block() -> bytes:
    """Blok se tremi framy pro offline test (bez instalace UO).

    Sklada se presne podle overene struktury: 512 B prefixu (obsah je jedno,
    jen delka), pak [u32 pocet][u32 offsety], pak framy s hlavickou a RLE.
    """
    pref = bytes(512)
    frames = []
    for i, (cx, cy, w, h) in enumerate(((12, -11, 24, 64), (13, -8, 25, 63), (12, -4, 25, 59))):
        hlavicka = struct.pack("<2h2H", cx, cy, w, h)
        beh = struct.pack("<I", 8) + bytes([1 + i] * 8)     # jeden beh: run 8 od (0,0)
        termin = struct.pack("<I", MUL_TERMINATOR)
        frames.append(hlavicka + beh + termin)
    tabulka = 4 + 3 * 4
    offsety = []
    poz = tabulka
    for f in frames:
        offsety.append(poz)
        poz += len(f)
    return (pref + struct.pack("<I", 3) + struct.pack("<3I", *offsety) + b"".join(frames))


def self_test() -> int:
    failures = 0
    checks = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures, checks
        checks += 1
        print(f"[anim] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    # 1) anim.idx ma 148 810 slotu; skupiny tela by potrebovaly 323 400, takze
    # tela nad ~1249 uz v idx vubec nejsou. Prazdny slot je (-1,-1,-1) -
    # MERENO: telo 605, 666, 744, 747, 748 maji vsechny tri hodnoty 0xFFFFFFFF.
    slotu = 200 * 110 + 200 * 65 + 1648 * 175
    check(slotu == 323400, f"skupiny daji {slotu} slotu, ocekavano 323 400")
    check(MulAnim.PRAZDNY == 0xFFFFFFFF, "prazdny slot je 0xFFFFFFFF")
    check(mul_slot(605, 0, 0)[0] < 148810 * IDX_BLOCK,
          "telo 605 ma slot jeste uvnitr idx - prazdno je hodnotou (-1), ne chybejicim slotem")
    check(mul_slot(1249, 0, 0)[0] >= 148810 * IDX_BLOCK,
          "telo 1249 uz je mimo idx (soubor ma 148 810 slotu)")
    check(mul_slot(199, 21, 4)[0] < mul_slot(200, 0, 0)[0],
          "skupina monster konci pred skupinou zvirata")
    check(mul_slot(399, 12, 4)[0] < mul_slot(400, 0, 0)[0],
          "skupina zvirat konci pred skupinou lidi")
    check(mul_slot(400, 1, 0)[0] - mul_slot(400, 0, 0)[0] == DIRS * IDX_BLOCK,
          "dalsi akce je o 5 slotu dal (5 smeru x 12 B)")

    # 2) jmeno zaznamu v UOP a hash
    jmeno = UOP_NAME.format(400, 4)
    check(jmeno == "build/animationlegacyframe/000400/04.bin",
          f"jmeno zaznamu je '{jmeno}'")
    check(create_hash(jmeno) != create_hash(UOP_NAME.format(400, 5)),
          "ruzne akce maji ruzny hash")

    # 2b) PRAVIDLO ROZHODNUTI musi byt testovane OFFLINE. Mutační test to
    # odhalil: s obracenym poradim zdroju (UOP pred MUL) bylo `--verify` zelene,
    # protoze se pravidlo zkouselo jen na zivych datech - a ta jsou pomalá.
    mul_f, uop_f = {400: [0], 826: [0]}, {334: [0], 826: [0]}
    check(zdroj(400, mul_f, uop_f) == "mul", "telo jen v MUL -> 'mul'")
    check(zdroj(334, mul_f, uop_f) == "uop", "telo jen v UOP -> 'uop'")
    check(zdroj(826, mul_f, uop_f) == "mul",
          "telo v OBOU -> 'mul' (MUL ma prednost)")
    check(zdroj(9999, mul_f, uop_f) == "zadny", "telo v nicem -> 'zadny'")

    # 3) tabulka framu na syntetickem bloku
    blok = _synthetic_block()
    frames = frames_of(blok)
    check(len(frames) == 3, f"synteticky blok dal {len(frames)} framu, cekano 3")
    if frames:
        check((frames[0]["cx"], frames[0]["cy"], frames[0]["w"], frames[0]["h"])
              == (12, -11, 24, 64), f"prvni frame ma {frames[0]}")
        check(frames[2]["w"] == 25 and frames[2]["h"] == 59,
              f"treti frame ma {frames[2]['w']}x{frames[2]['h']}, cekano 25x59")
        check(all(f["terminator"] for f in frames), "vsechny framy maji terminátor")

    # 4) vadny vstup: rozbita tabulka (offsety nerostou) -> zadne framy, ne vyjimka
    rozbity = bytearray(blok)
    struct.pack_into("<I", rozbity, 516, 999)      # prvni offset vysoky
    struct.pack_into("<I", rozbity, 520, 1)        # druhy nizsi -> nerostou
    check(frames_of(bytes(rozbity)) == [],
          "rozbita tabulka vraci prazdny seznam (ne vyjimku)")
    check(frames_of(b"") == [], "prazdny blok vraci prazdny seznam")

    # 5) UOP hlavicky framu na syntetickem zaznamu
    telo = bytearray(32) + struct.pack("<iI", 2, 64) + b"\x00" * 64
    struct.pack_into("<HHQI", telo, 64, 0, 1, 0, 800)
    struct.pack_into("<HHQI", telo, 80, 0, 2, 0, 2775)
    fr = uop_frames(bytes(telo))
    check(len(fr) == 2, f"synteticky UOP zaznam dal {len(fr)} framu, cekano 2")
    if len(fr) == 2:
        check(fr[1]["frame_id"] == 2 and fr[1]["pixel_offset"] == 2775,
              f"druhy frame ma {fr[1]}")
    check(uop_frames(None) == [], "None vraci prazdny seznam")

    print(f"[anim] self-test: {checks} kontrol, {failures} chyb")
    return 1 if failures else 0


def zapis_manifest(install: str | Path, out: str | Path) -> dict:
    """Zapise manifest animaci: zdroj pro kazde telo, pokryti a SHA-256 vstupu.

    Manifest je to, co jde merit branou (G6) a co si precte `assets.atlas`:
    u kazdeho tela je RECENO, odkud se bere (rozhodnuti se tak da overit),
    a u vstupu je hash, takze zmena instalace je videt.
    """
    import hashlib

    install = Path(install)
    p = pokryti(install)
    mul_t, uop_t = p["mul"], p["uop"]
    tela = {}
    for body in sorted(set(mul_t) | set(uop_t)):
        zdroj_tela = zdroj(body, mul_t, uop_t)
        akce = mul_t.get(body, []) if zdroj_tela == "mul" else uop_t.get(body, [])
        zaznam = {"source": "anim.mul" if zdroj_tela == "mul" else "AnimationFrame.uop",
                  "actions": akce}
        if zdroj_tela == "mul":
            blok = MulAnim(install).block(body, 0)
            if blok and blok["frames"]:
                f = blok["frames"][0]
                zaznam["first_frame"] = {"w": f["w"], "h": f["h"]}
        tela[str(body)] = zaznam
    vstupy = {}
    for nazev in ("anim.idx", "anim.mul"):
        cesta = install / nazev
        if cesta.exists():
            vstupy[nazev] = hashlib.sha256(cesta.read_bytes()).hexdigest()
    for i in range(1, 11):
        cesta = install / f"AnimationFrame{i}.uop"
        if cesta.exists():
            vstupy[cesta.name] = hashlib.sha256(cesta.read_bytes()).hexdigest()
    data = {
        "version": 1,
        "install": str(install),
        "decision": ("blok v anim.mul -> anim.mul, jinak AnimationFrame*.uop "
                     "(docs/03 §3.5.1; mereni v research/anim-mereni.md)"),
        "sources": {"anim*.mul": {"bodies": len(mul_t),
                                  "actions": sum(len(v) for v in mul_t.values())},
                    "AnimationFrame*.uop": {"bodies": len(uop_t),
                                            "actions": sum(len(v) for v in uop_t.values())},
                    "both": p["prunik"]},
        "sha256": vstupy,
        "bodies": tela,
        "pixels_decoded": False,   # NEOVERENO - viz research/anim-mereni.md
    }
    cesta = Path(out)
    cesta.parent.mkdir(parents=True, exist_ok=True)
    cesta.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return data


def main() -> int:
    ap = argparse.ArgumentParser(description="animace tela (granule assets.anim)")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--body", type=int, default=None)
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if not (Path(args.install) / "anim.idx").exists():
        print(f"[anim] CHYBA: {args.install} neobsahuje anim.idx")
        return 1
    if args.body is not None:
        p = pokryti(args.install)
        telo = args.body
        print(f"[anim] telo {telo}: zdroj {zdroj(telo, p['mul'], p['uop'])}")
        print(f"[anim]   MUL akce: {p['mul'].get(telo, [])}")
        print(f"[anim]   UOP akce: {p['uop'].get(telo, [])}")
        blok = MulAnim(args.install).block(telo, 4)
        if blok:
            print(f"[anim]   MUL stand: {blok['source']} offset {blok['offset']} "
                  f"size {blok['size']} framu {len(blok['frames'])}")
            for f in blok["frames"]:
                print(f"[anim]     frame cx={f['cx']} cy={f['cy']} {f['w']}x{f['h']} "
                      f"terminator={f['terminator']}")
        blok = UopAnim(args.install).block(telo, 1)
        if blok:
            print(f"[anim]   UOP akce 1: {blok['file']} flag {blok['flag']} "
                  f"framu {len(blok['frames'])}")
        return 0
    if not args.verify:
        print("[anim] bez --verify nebo --body se nic nemERilo")
        return 1
    checks, errors = verify(args.install)
    if args.out:
        data = zapis_manifest(args.install, args.out)
        print(f"[anim] zapsano {args.out}: tel {len(data['bodies'])}, "
              f"zdroje {data['sources']}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
