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
  OVERENO  UOP zaznam se adresuje jmenem
           "build/animationlegacyframe/{telo:06d}/{akce:02d}.bin" a hashem
           create_hash (z uop.py): 4 747 nalezenych na vzorku 700 tela x 80 akci,
           zatimco jenkins_pc_pb 0.
  OVERENO  Pixely JSOU dekodovane (2026-10-06). Tvar bloku a RLE je prevzaty
           z referencni implementace a overeny merenim:
             * hlavicka framu `[i16 cx][i16 cy][i16 w][i16 h]` na `512 + offset`,
             * RLE hlavicka `[u32]`: `run = h & 0xFFF`, `x` a `y` jsou
               ZNAMENKOVE desetibitove hodnoty z `(h >> 22)` a `(h >> 12)`
               (`x += cx`, `y += cy + h`), pixel = 1 bajt = index do 256barevne
               palety v PRVNICH 512 B bloku, terminátor `0x7FFF7FFF`,
             * overeno na telo 400/401, akce walk/run/idle, vsech 5 smeru:
               **0 pixelu mimo frame** (drivejsi dojem "hlavicka je neznama"
               vznikl tim, ze 1020..1023 je ve znamenkove desetibite soustave
               -4..-1; proto take kazda hlavicka konci bajtem 0xFF).
           Reference: `_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs`
           (`ReadMULAnimationFrames`, `ReadSpriteData`). Dukazy, ktere jsou
           v gitu: `--self-test` (35 kontrol), `--verify` (0 pixelu mimo frame
           na 30 blocich) a `tools/gates/mutace-anim.py` (8/8 mutaci chyceno).
           Mutační harness odhalil dve slepa mista (maska behu 12 bitu,
           paleta z offsetu 0) - proto pribyly kontroly s behem 300 pixelu.
           Puvodni objevne sondy jsou v `_analyza/` (gitignore, lokalni):
           `anim-rle-sonda.py`, `anim-rle-hledani.py`, `anim-dekod.py`.
           Pomer: `research/anim-mereni.md` (doplneno 2026-10-06).
  POZOR    Prvnich 512 B bloku JE paleta (driv se usoudilo, ze "je ve vsech
           blocich stejna, takze paleta neexistuje" - je to vychozi sedy ramp).
           Naked telo je proto sede; barvu kuze v UO dela az hue z `hues.mul`
           (granule `render.hue`).

   CISLA AKCI (2026-10-09)  Export bere akce 0 = walk, **2 = run**, 4 = idle.
           Do 2026-10-09 tu bylo `1:run`, coz je u CLOVEKA NECO JINEHO:
           reference `_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs:1721`
           (`PeopleAnimationGroup`) dava 0 = WalkUnarmed, 1 = **WalkArmed**,
           2 = **RunUnarmed**, 3 = RunArmed. ("0 = walk, 1 = run" plati jen pro
           zvirata a monstra.) NAMERENO POHLEDEM (2026-10-09,
           `_analyza/p25-groups-montaz.py` + export `_analyza/p25-groups`, telo
           400, vsech 5 smeru): skupiny 2 a 3 jsou BEH (predklon, pokrcene
           paze), 0 a 1 jsou CHUZE. Klientska strana ma stejne cislo
           (`sim/systems/movement.gd` `ACTION_RUN`, `app/player_controller.gd`);
           kdo ho zmeni, MUSI preexportovat `assets/uo/anim`, jinak beh nema
           sprite a postava zmizi.

Pouziti:
  python tools/uoextract/anim.py --verify            # zmer vsechna tela
  python tools/uoextract/anim.py --body 400          # detail jednoho tela
  python tools/uoextract/anim.py --self-test         # offline test se znamym vzorkem
  python tools/uoextract/anim.py --export assets/uo/anim          # PNG + JSON pro klienta
  python tools/uoextract/anim.py --export-check assets/uo/anim    # kontrola exportu
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

    Tabulku (offsety) cte `frame_offsets`, aby existoval JEDEN vyklad tvaru
    bloku; tady se k offsetum pridavaji rozmery a overuje terminátor.
    Hlavicka framu je `[i16 cx][i16 cy][i16 w][i16 h]` na `512 + offset`
    (ClassicUO `ReadSpriteData`), tedy `cx,cy` 4 B pred `516 + offset`.
    """
    offsety = frame_offsets(block)
    if not offsety:
        return []
    tabulka = FRAME_TABLE_OFFSET + 4
    frames = []
    for i, o in enumerate(offsety):
        start = tabulka + o
        konec = tabulka + offsety[i + 1] if i + 1 < len(offsety) else len(block)
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


PALETA_BAJTU = 512                  # prvnich 512 B bloku = 256 x u16 ARGB1555
PALETA_BAREV = 256


def paleta_z_bloku(block: bytes) -> tuple[int, ...]:
    """Paleta z prvnich 512 B bloku.

    Dřívější mEReni (`research/anim-mereni.md`) usoudilo, ze prvnich 512 B je
    "ve vsech blocich stejnych -> pixely nemaji vlastni paletu". Prvni pulka
    plati (je to vychozi sede ramp), druha je omyl: JE to paleta a pouziva ji
    i ClassicUO (`ReadMULAnimationFrames` -> `ReadSpriteData`). Naked telo je
    proto sede - barvu kuze v UO dela az hue z `hues.mul` (granule `render.hue`).
    """
    if len(block) < PALETA_BAJTU:
        return ()
    return struct.unpack_from(f"<{PALETA_BAREV}H", block, 0)


def znamenko10(v: int) -> int:
    """Desetibitove pole hlavicky je ZNAMENKOVE (ClassicUO `ReadSpriteData`).

    Presne tady vznikl dojem "hlavicka je neznama": `x` vychazelo 1020..1023,
    tedy mimo rozmer framu - jenze 1020..1023 je ve znamenkove desetibite
    soustave -4..-1. Proto take kazda hlavicka konci bajtem 0xFF (horni bity
    zaporneho cisla).
    """
    return v - 1024 if v & 0x200 else v


def barva16(v: int) -> tuple[int, int, int]:
    """ARGB1555 -> (r, g, b), rozsireni 5 bitu na 8 (jako ClassicUO)."""
    r = (v >> 10) & 0x1F
    g = (v >> 5) & 0x1F
    b = v & 0x1F
    return ((r << 3) | (r >> 2), (g << 3) | (g >> 2), (b << 3) | (b >> 2))


def decode_frame(block: bytes, offset: int) -> dict | None:
    """Jeden frame bloku na RGBA pixely.

    Tvar podle `_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs`
    (`ReadSpriteData`): frame zacina na `512 + offset`,
    `[i16 cx][i16 cy][i16 w][i16 h]`, pak RLE:
    `[u32 header]` = `run = header & 0xFFF`, `x`/`y` = znamenkove 10 bity
    z `(header >> 22)` a `(header >> 12)`, `x += cx`, `y += cy + h`,
    nasleduje `run` bajtu = indexu do palety. Terminátor `0x7FFF7FFF`.
    Pixel se zapisuje na `y * w + x`; co RLE nepokryje, zustava pruhledne.
    """
    paleta = paleta_z_bloku(block)
    p = FRAME_TABLE_OFFSET + offset          # 512 + offset (ClassicUO)
    if not paleta or p + 8 > len(block):
        return None
    cx, cy, w, h = struct.unpack_from("<4h", block, p)
    if not (1 <= w <= 512 and 1 <= h <= 512):
        return None
    p += 8
    pixely = bytearray(w * h * 4)
    behu = 0
    mimo = 0
    termin = False
    while p + 4 <= len(block):
        (header,) = struct.unpack_from("<I", block, p)
        p += 4
        if header == MUL_TERMINATOR:
            termin = True
            break
        run = header & 0x0FFF
        x = znamenko10((header >> 22) & 0x3FF) + cx
        y = znamenko10((header >> 12) & 0x3FF) + cy + h
        behu += 1
        for k in range(run):
            if p >= len(block):
                break
            index = block[p]
            p += 1
            px = x + k
            if 0 <= px < w and 0 <= y < h:
                r, g, b = barva16(paleta[index])
                o = (y * w + px) * 4
                pixely[o] = r
                pixely[o + 1] = g
                pixely[o + 2] = b
                pixely[o + 3] = 255
            else:
                mimo += 1
    return {"cx": cx, "cy": cy, "w": w, "h": h, "pixels": bytes(pixely),
            "behu": behu, "pixely_mimo": mimo, "terminator": termin}


def decode_block(block: bytes) -> list[dict]:
    """Vsechny framy bloku (co nejde precist, se preskoci - ne vyjimka)."""
    out = []
    for offset in frame_offsets(block):
        frame = decode_frame(block, offset)
        if frame is not None:
            out.append(frame)
    return out


def frame_offsets(block: bytes) -> list[int]:
    """Offsety framu z tabulky bloku (`[u32 pocet]` na 512, pak `pocet x u32`)."""
    if len(block) < FRAME_TABLE_OFFSET + 8:
        return []
    pocet = struct.unpack_from("<I", block, FRAME_TABLE_OFFSET)[0]
    if not (1 <= pocet <= 200) or FRAME_TABLE_OFFSET + 4 + pocet * 4 > len(block):
        return []
    offsety = list(struct.unpack_from(f"<{pocet}I", block, FRAME_TABLE_OFFSET + 4))
    if any(offsety[i] <= offsety[i - 1] for i in range(1, pocet)):
        return []
    return offsety


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

    # Pixely (2026-10-06): hlavni invariant je, ze RLE NIKDY nezapisuje mimo
    # frame - to je to, co drivejsi vyklad (x bez znamenka) nesplnoval.
    m = MulAnim(install)

    def blok_pixelu(telo: int, cislo: int, smer: int) -> bytes | None:
        info = m.block(telo, cislo, smer)
        return None if info is None else m._blok(info["offset"], info["size"])

    for telo in (400, 401):
        for cislo in (0, 1, 4):
            for smer in range(ANIM_SMERY):
                blok = blok_pixelu(telo, cislo, smer)
                framy = decode_block(blok) if blok else []
                mimo = sum(f["pixely_mimo"] for f in framy)
                bez_terminu = sum(1 for f in framy if not f["terminator"])
                check(bool(framy) and mimo == 0 and bez_terminu == 0,
                      f"{telo}/{cislo}/{smer}: framu {len(framy)}, pixelu mimo "
                      f"{mimo}, framu bez terminatoru {bez_terminu} (ocekavano >0, 0, 0)")
    blok400 = blok_pixelu(400, 0, 0)
    paleta = paleta_z_bloku(blok400) if blok400 else ()
    check(len(paleta) == PALETA_BAREV and any(paleta),
          f"paleta ma {len(paleta)} barev, nenulovych {sum(1 for v in paleta if v)}")
    check(znamenko10(1020) == -4 and znamenko10(1022) == -2 and znamenko10(5) == 5,
          "znamenkove desetibitove pole nefunguje (1020 musi byt -4, 1022 -> -2, 5 -> 5)")
    idle_blok = blok_pixelu(400, 4, 0)
    idle = decode_block(idle_blok) if idle_blok else []
    if idle:
        check((idle[0]["w"], idle[0]["h"]) == (26, 60),
              f"idle frame ma {idle[0]['w']}x{idle[0]['h']}, mEReno 26x60")

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

    # 6) DEKODER PIXELU na syntetickem bloku. Hlavni vec, ktera se tu merit:
    # znamenkove x/y a to, ze se zapisuje na `y * w + x`. Kdyby se x cetlo bez
    # znamenka (drivejsi omyl), pixel by spadl mimo frame a `pixely_mimo` > 0.
    def _blok_s_behem(cx: int, cy: int, w: int, h: int, x: int, y: int, run: int,
                      index: int = 1) -> bytes:
        paleta = bytearray(512)
        struct.pack_into("<H", paleta, index * 2, 0x7C00)   # cervena (ARGB1555)
        hlavicka = struct.pack("<4h", cx, cy, w, h)
        pole = (x & 0x3FF) << 22 | (y & 0x3FF) << 12 | (run & 0xFFF)
        beh = struct.pack("<I", pole) + bytes([index] * run)
        frame = hlavicka + beh + struct.pack("<I", MUL_TERMINATOR)
        # offset je relativne k 512 (ClassicUO `dataStart + frameOffset[i]`):
        # paleta 512 B + [u32 pocet] + [u32 offset] = 520, tedy offset 8.
        return bytes(paleta) + struct.pack("<I", 1) + struct.pack("<I", 8) + frame

    # run 4 na relativnim (0,0): x = cx, y = cy + h  -> radek `cy + h`, sloupce 12..15
    blok = _blok_s_behem(12, -11, 24, 64, 0, 0, 4)
    fr = decode_frame(blok, 8)
    check(fr is not None and fr["w"] == 24 and fr["h"] == 64,
          f"synteticky frame ma {fr['w'] if fr else None}x{fr['h'] if fr else None}, cekano 24x64")
    if fr:
        pix = fr["pixels"]
        radek = fr["cy"] + fr["h"]          # relativni y = 0 je linka zeme

        def _a(px: int, py: int) -> int:
            return pix[(py * 24 + px) * 4 + 3]
        check(all(_a(12 + k, radek) == 255 for k in range(4)),
              f"run 4 na (0,0) musi dat 4 neprusvitne pixely na radku {radek} od sloupce 12")
        check(_a(11, radek) == 0 and _a(16, radek) == 0 and _a(12, radek - 1) == 0,
              "kolem runu musi byt pruhledno")
        check(fr["pixely_mimo"] == 0 and fr["terminator"],
              f"mimo={fr['pixely_mimo']} terminator={fr['terminator']} (cekano 0, True)")
        check((pix[(radek * 24 + 12) * 4], pix[(radek * 24 + 12) * 4 + 1]) == (255, 0),
              "barva z palety musi byt cervena (0x7C00)")

    # zaporny offset: x = -4 (v hlavicce 1020) -> zacatek 4 px vlevo od stredu
    blok = _blok_s_behem(12, -11, 24, 64, 1020, 0, 3)
    fr = decode_frame(blok, 8)
    if fr:
        pix = fr["pixels"]
        radek = fr["cy"] + fr["h"]
        check(all(pix[(radek * 24 + 8 + k) * 4 + 3] == 255 for k in range(3)),
              "x = 1020 (znamenkove -4) musi zapsat na sloupce 8..10 (12 - 4)")

    # run, ktery pretece vpravo: 2 pixely se zapisou, 2 museji byt hlaseny jako mimo
    blok = _blok_s_behem(0, 0, 10, 10, 8, 1014, 4)      # 1014 = -10 -> radek 0
    fr = decode_frame(blok, 8)
    if fr:
        check(fr["pixely_mimo"] == 2,
              f"run pres okraj ma hlasit 2 pixely mimo, hlasil {fr['pixely_mimo']}")
        check(sum(1 for i in range(0, len(fr["pixels"]), 4) if fr["pixels"][i + 3]) == 2,
              "pres okraj se smi zapsat jen 2 pixely")

    # DELKA BEHU: `run` je 12 bitu (0..4095). Mutační test nasel, ze se to nijak
    # nemerilo: beh >= 256 se s maskou 0xFF tise zkrati a kontroly to nepoznaly
    # (vsechny behy v datech jsou < 100). Frame je proto siroky 400 px, aby se
    # beh 300 vesel do JEDNOHO radku (beh je vzdy vodorovny).
    blok = _blok_s_behem(0, 0, 400, 1, 0, 1023, 300)    # 1023 = -1 -> radek 0
    fr = decode_frame(blok, 8)
    if fr:
        zapsano = sum(1 for i in range(0, len(fr["pixels"]), 4) if fr["pixels"][i + 3])
        check(zapsano == 300,
              f"beh 300 pixelu musi zapsat 300 pixelu, zapsal {zapsano} "
              f"(maska behu musi byt 12 bitu, ne 8)")

    # rozbity vstup: prazdny blok a blok bez palety -> None, ne vyjimka
    check(decode_frame(b"", 0) is None, "prazdny blok vraci None")
    check(decode_frame(bytes(600), 0) is None,
          "blok bez platne hlavicky vraci None (nula rozmery)")
    check(decode_block(_synthetic_block()) != [], "decode_block projde synteticky blok")
    check(decode_block(b"") == [], "decode_block nad prazdnym blokem vraci []")

    print(f"[anim] self-test: {checks} kontrol, {failures} chyb")
    return 1 if failures else 0


ANIM_SMERY = 5                      # anim.mul ma 5 smeru (8 smeru hry se z nich sklada)


def export_sheets(install: str | Path, out_dir: str | Path, bodies: list[int],
                  akce: dict[int, str], smery: int = ANIM_SMERY) -> dict:
    """Zapise animace jako PNG (framy v jedne rade) + JSON s metadaty.

    Kazda (telo, akce, smer) je jeden PNG a jeden zaznam v `anim-sheets.json`.
    `rect` je ve tvaru PILu `[levy, horni, pravy, dolni]` - stejna konvence jako
    `assets.atlas` (`tools/uoextract/atlas.py`), aby se to nepletlo.
    `cx`, `cy` jsou posuny z hlavicky framu: obrazek se kresli na
    `(tile_x - cx, tile_y - (cy + h))`, tedy `cy + h` je linka zeme.

    Vysledek je REPRODUKOVATELNY z instalace UO (`--export`), do gitu nepatri.
    """
    from PIL import Image

    install = Path(install)
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    m = MulAnim(install)
    zaznamy: dict[str, dict] = {}
    chyby: list[str] = []
    for body in bodies:
        for cislo, nazev in sorted(akce.items()):
            for smer in range(smery):
                info = m.block(body, cislo, smer)
                if info is None:
                    chyby.append(f"{body}/{cislo}/{smer}: blok v anim.mul neni")
                    continue
                blok = m._blok(info["offset"], info["size"])
                if blok is None:
                    chyby.append(f"{body}/{cislo}/{smer}: blok se necte")
                    continue
                framy = decode_block(blok)
                if not framy:
                    chyby.append(f"{body}/{cislo}/{smer}: zadny frame se nedekodoval")
                    continue
                sirka = sum(f["w"] for f in framy)
                vyska = max(f["h"] for f in framy)
                plocha = Image.new("RGBA", (sirka, vyska), (0, 0, 0, 0))
                popis = []
                x = 0
                for f in framy:
                    plocha.paste(Image.frombytes("RGBA", (f["w"], f["h"]), f["pixels"]), (x, 0))
                    popis.append({"rect": [x, 0, x + f["w"], f["h"]],
                                  "cx": f["cx"], "cy": f["cy"], "w": f["w"], "h": f["h"],
                                  "pixely_mimo": f["pixely_mimo"]})
                    x += f["w"]
                jmeno = f"anim-{body}-{cislo}-{smer}.png"
                plocha.save(out_dir / jmeno)
                zaznamy[f"{body}/{cislo}/{smer}"] = {
                    "file": jmeno, "action": nazev, "frames": popis,
                    "source": f"{info['source']}+{info['source'].replace('.mul', '.idx')}",
                }
    data = {
        "version": 1,
        "decoder": ("tools/uoextract/anim.py decode_frame - podle "
                    "_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs "
                    "(ReadSpriteData): [i16 cx][i16 cy][i16 w][i16 h], RLE hlavicka "
                    "[run:12][y:10 signed][x:10 signed], pixel = bajt indexu do "
                    "512B palety v bloku, terminátor 0x7FFF7FFF"),
        "anchor": "obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); rect je [levy, horni, pravy, dolni]",
        "actions": {str(k): v for k, v in sorted(akce.items())},
        "sprites": zaznamy,
        "chyby": chyby,
    }
    (out_dir / "anim-sheets.json").write_text(
        json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    return data


def over_export(out_dir: str | Path) -> tuple[int, list[str]]:
    """Zkontroluje exportovane PNG proti JSON - soubor musi byt a mit velikost.

    Tohle je meritelna brana nad exportem: chybejici nebo ustrizene PNG se
    pozna bez instalace UO (a tedy i v CI, pokud by assety byly).
    """
    from PIL import Image

    out_dir = Path(out_dir)
    soubor = out_dir / "anim-sheets.json"
    if not soubor.exists():
        return 0, [f"chybi {soubor}"]
    data = json.loads(soubor.read_text(encoding="utf-8"))
    kontroly = 0
    chyby: list[str] = []
    for klic, zaznam in sorted(data.get("sprites", {}).items()):
        cesta = out_dir / zaznam["file"]
        kontroly += 1
        if not cesta.exists():
            chyby.append(f"{klic}: chybi {zaznam['file']}")
            continue
        obrazek = Image.open(cesta)
        for i, f in enumerate(zaznam["frames"]):
            kontroly += 1
            levy, horni, pravy, dolni = f["rect"]
            if pravy - levy != f["w"] or dolni - horni != f["h"]:
                chyby.append(f"{klic} frame {i}: rect nesedi na w/h")
            if pravy > obrazek.width or dolni > obrazek.height:
                chyby.append(f"{klic} frame {i}: rect je mimo PNG "
                             f"({obrazek.width}x{obrazek.height})")
    return kontroly, chyby


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
        "pixels_decoded": True,
        "pixels_recipe": ("[i16 cx][i16 cy][i16 w][i16 h] na 512+offset; RLE "
                          "hlavicka [run:12][y:10 signed][x:10 signed]; pixel = bajt "
                          "indexu do 512B palety v bloku; terminátor 0x7FFF7FFF "
                          "(ClassicUO AnimationsLoader.ReadSpriteData)"),
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
    ap.add_argument("--export", default=None,
                    help="slozka pro PNG framu + anim-sheets.json (napr. assets/uo/anim)")
    ap.add_argument("--export-check", default=None,
                    help="zkontroluje export bez instalace UO (PNG proti JSON)")
    ap.add_argument("--bodies", default="400,401",
                    help="tela pro --export (vychozi 400,401 = muz, zena)")
    ap.add_argument("--actions", default="0:walk,2:run,4:idle",
                    help="akce pro --export jako cislo:nazev,... (vychozi 0:walk,2:run,4:idle)")
    ap.add_argument("--dirs", type=int, default=ANIM_SMERY,
                    help="kolik smeru exportovat (anim.mul ma 5)")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if args.export_check:
        kontroly, chyby = over_export(args.export_check)
        for e in chyby:
            print(f"[anim] CHYBA: {e}")
        print(f"[anim] export-check: {kontroly} kontrol, {len(chyby)} chyb")
        if not kontroly:
            print("[anim] NEMERENO: chybi anim-sheets.json - export se jeste nedelal")
            return 2
        return 1 if chyby else 0
    if not (Path(args.install) / "anim.idx").exists():
        print(f"[anim] CHYBA: {args.install} neobsahuje anim.idx")
        return 1
    if args.export:
        akce = {}
        for cast in args.actions.split(","):
            cislo, _, nazev = cast.partition(":")
            akce[int(cislo)] = nazev or f"akce{cislo}"
        tela = [int(x) for x in args.bodies.split(",") if x.strip()]
        data = export_sheets(args.install, args.export, tela, akce, args.dirs)
        print(f"[anim] export: {len(data['sprites'])} spritu do {args.export}"
              f" ({sum(len(z['frames']) for z in data['sprites'].values())} framu)")
        for e in data["chyby"]:
            print(f"[anim] CHYBA: {e}")
        return 1 if data["chyby"] else 0
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
