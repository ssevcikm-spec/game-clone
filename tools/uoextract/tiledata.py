#!/usr/bin/env python3
"""tiledata.mul -> vlastnosti dlazdic a predmetu (granule assets.tiledata).

LAYOUT JE VYRESENY (docs/03 §3.3.1) - nehleda se znovu, jen se pouziva:
  LAND  offset 4,        512 skupin x (4 B hlavicka + 32 x 30 B)
        zaznam = [u64 flags][u16 texture][20 B jmeno]
  ITEM  offset 493 568, 2048 skupin x (4 B hlavicka + 32 x 41 B)
        zaznam = [u64 flags][u8 weight][u8 layer][i32 count][u16 anim_id]
                 [u16 hue][u16 light][u8 height][20 B jmeno]   (jmeno na +21)
  4 + 512*(4+32*30) + 2048*(4+32*41) = 3 188 736 B = presna velikost souboru
  65 536 predmetu (2048 skupin, 4x vic nez klasickych 0x4000).

POZOR: tahle instalace NEMA klasicka jmena predmetu (docs/03 §3.3.1b) - obsah
se vybira podle VLASTNOSTI (vrstva, vaha, flagy), ne podle klasickych seznamu.

Tenhle soubor nahrazuje puvodni vyzkumnou sondu stejneho jmena. Ta mela spravny
land blok i offset item bloku, ale item blok cetla pres `range(LAND_GROUPS)`,
tedy 512 skupin -> jen 16 384 z 65 536 predmetu (25 %), pri importu tiskla
a nemela smluvni API `land()`/`item()`. Sondy *tiledata*.py zustavaji jako
historie mereni.

Pouziti:
  python tools/uoextract/tiledata.py --install "<UO>" --extract assets/uo
  python tools/uoextract/tiledata.py --install "<UO>" --verify
  python tools/uoextract/tiledata.py --self-test
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

DEFAULT_INSTALL = r"D:\Games\Electronic Arts\Ultima Online Classic"

LAND_OFF, LAND_GROUPS, PER_GROUP, LAND_REC = 0, 512, 32, 30
ITEM_OFF = LAND_OFF + LAND_GROUPS * (4 + PER_GROUP * LAND_REC)
ITEM_GROUPS, ITEM_REC = 2048, 41
TOTAL = ITEM_OFF + ITEM_GROUPS * (4 + PER_GROUP * ITEM_REC)
LAND_COUNT = LAND_GROUPS * PER_GROUP
ITEM_COUNT = ITEM_GROUPS * PER_GROUP

# Pozn. k offsetum (namEReno 2026-10-02): docs/03 §3.3.1 pise "LAND blok:
# offset 4" - to je offset prvniho ZAZNAMU (za 4 B hlavickou prvni skupiny),
# ne zacatek bloku. Blok zacina na 0 a prvni zaznam je na 4; teprve tak vyjde
# 512*964 + 2048*1316 = 3 188 736 B = presna velikost souboru. Kdyby se do
# ITEM_OFF pricetly jeste 4 B, vyslo by 3 188 740 B a nacteni by spadlo.

FLAG_WEARABLE = 0x00400000
LAYER_LIMIT = 0x20

# Kontrolni vzorky z docs/03 §3.3.1: jmeno -> ocekavana vrstva
KNOWN_LAYERS = {
    "leather cap": 6,
    "backpack": 21,
    "dagger": 1,
    "longsword": 1,
    "katana": 1,
}


def _record_offset(base: int, record: int, index: int) -> int:
    group = index // PER_GROUP
    return base + group * (4 + PER_GROUP * record) + 4 + (index % PER_GROUP) * record


def _name(raw: bytes, start: int, length: int = 20) -> str:
    return raw[start:start + length].split(b"\x00")[0].decode("latin-1").strip()


class TileData:
    """Cteni tiledata.mul. `raw` je jen pro offline testy (self-test)."""

    def __init__(self, install: str | Path | None = None, raw: bytes | None = None) -> None:
        if raw is None:
            if install is None:
                raise ValueError("je potreba --install nebo raw")
            raw = (Path(install) / "tiledata.mul").read_bytes()
        if len(raw) != TOTAL:
            raise ValueError(f"tiledata.mul: {len(raw)} B != ocekavanych {TOTAL} B")
        self.raw = raw

    def land(self, tile: int) -> dict:
        if not 0 <= tile < LAND_COUNT:
            raise IndexError(f"land id {tile} mimo 0..{LAND_COUNT - 1}")
        off = _record_offset(LAND_OFF, LAND_REC, tile)
        return {
            "flags": struct.unpack_from("<Q", self.raw, off)[0],
            "texture": struct.unpack_from("<H", self.raw, off + 8)[0],
            "name": _name(self.raw, off + 10),
        }

    def item(self, tile: int) -> dict:
        if not 0 <= tile < ITEM_COUNT:
            raise IndexError(f"item id {tile} mimo 0..{ITEM_COUNT - 1}")
        off = _record_offset(ITEM_OFF, ITEM_REC, tile)
        return {
            "flags": struct.unpack_from("<Q", self.raw, off)[0],
            "weight": self.raw[off + 8],
            "layer": self.raw[off + 9],
            "count": struct.unpack_from("<i", self.raw, off + 10)[0],
            "anim_id": struct.unpack_from("<H", self.raw, off + 14)[0],
            "hue": struct.unpack_from("<H", self.raw, off + 16)[0],
            "light": struct.unpack_from("<H", self.raw, off + 18)[0],
            "height": self.raw[off + 20],
            "name": _name(self.raw, off + 21),
        }

    def find_item(self, name: str) -> tuple[int, dict] | None:
        wanted = name.lower()
        for tile in range(ITEM_COUNT):
            rec = self.item(tile)
            if rec["name"].lower() == wanted:
                return tile, rec
        return None


def verify(td: TileData) -> tuple[int, list[str]]:
    """Kontrola podle prijimacich kriterii granule. Vraci (pocet kontrol, chyby)."""
    checks = 0
    errors: list[str] = []

    def check(ok: bool, text: str) -> None:
        nonlocal checks
        checks += 1
        if not ok:
            errors.append(text)

    check(len(td.raw) == TOTAL, f"velikost souboru {len(td.raw)} != {TOTAL}")
    check(ITEM_OFF == 493568, f"item blok zacina na {ITEM_OFF}, docs/03 §3.3.1 rika 493568")
    check(ITEM_COUNT == 65536, f"predmetu {ITEM_COUNT}, docs/03 §3.3.1 rika 65536")
    check(LAND_COUNT == 16384, f"land dlazdic {LAND_COUNT}, ocekavano 16384")

    wearable = 0
    wearable_without_layer = 0
    layers_in_range = 0
    named = 0
    for tile in range(ITEM_COUNT):
        rec = td.item(tile)
        if rec["name"]:
            named += 1
        if rec["flags"] & FLAG_WEARABLE:
            wearable += 1
            if rec["layer"] == 0:
                wearable_without_layer += 1
            if rec["layer"] < LAYER_LIMIT:
                layers_in_range += 1
    check(wearable > 1000, f"Wearable predmetu jen {wearable} (docs/03 §3.3.1 meri 1268)")
    check(wearable_without_layer == 0,
          f"{wearable_without_layer} Wearable predmetu ma vrstvu 0 (kriterium granule)")
    check(wearable == 0 or layers_in_range * 100 >= wearable * 90,
          f"vrstev v rozsahu 0..0x1F je {layers_in_range}/{wearable} (<90 %)")
    check(named > 10000, f"pojmenovanych predmetu jen {named} (docs/03 §3.3.1 meri 13 113)")

    for name in sorted(KNOWN_LAYERS):
        found = td.find_item(name)
        if found is None:
            checks += 1
            errors.append(f"predmet '{name}' v datech neni (docs/03 §3.3.1 ho uvadi)")
            continue
        tile, rec = found
        check(rec["layer"] == KNOWN_LAYERS[name],
              f"'{name}' (id {tile}) ma vrstvu {rec['layer']}, docs/03 §3.3.1 rika {KNOWN_LAYERS[name]}")

    anvil = td.find_item("anvil")
    if anvil is None:
        checks += 1
        errors.append("predmet 'anvil' v datech neni (docs/03 §3.3.1 ho uvadi)")
    else:
        tile, rec = anvil
        check(rec["weight"] == 255 and rec["layer"] == 0,
              f"'anvil' (id {tile}) ma weight={rec['weight']} layer={rec['layer']}, cekano 255/0")

    lands_named = sum(1 for tile in range(LAND_COUNT) if td.land(tile)["name"])
    check(lands_named > 1000, f"pojmenovanych land dlazdic jen {lands_named}")

    # POZOR na dve ruzna pocitadla téhoz jmena (docs/10 P12): "cistych jmen"
    # v docs/03 §3.3.1 je 13 113, ale to bylo 16 384 zaznamu a jen ASCII jmena.
    # Tady se pocita ASCII-cistych v PRVNICH 16 384 (srovnatelne s dokumentem)
    # a zvlast vsech pojmenovanych z 65 536 (jina mnozina i jiny filtr).
    ascii_first = 0
    for tile in range(16384):
        name = td.item(tile)["name"]
        if name and all(0x20 <= ord(c) < 0x7F for c in name):
            ascii_first += 1
    print(f"[tiledata] ASCII-cistych jmen v prvnich 16 384 predmetech: {ascii_first} "
          f"(docs/03 §3.3.1 meri 13 113 na stejne mnozine)")
    print(f"[tiledata] land: {LAND_COUNT} ({lands_named} pojmenovanych), "
          f"item: {ITEM_COUNT} ({named} pojmenovanych celkem), Wearable: {wearable}, "
          f"z toho s vrstvou: {wearable - wearable_without_layer}")
    return checks, errors


# Polozky zaznamu v tiles.json. Poradi je ZAVAZNE - je to schema souboru,
# ne nahoda: hra cte `land[i][2]` podle téhož poradi (docs/04 §4.2 world.tiledata).
LAND_FIELDS = ("flags", "texture", "name")
ITEM_FIELDS = ("flags", "weight", "layer", "count", "anim_id", "hue", "light",
               "height", "name")


def _presnost_ok(hodnota: int) -> bool:
    """Projde hodnota cestou JSON -> float -> int beze zmeny?

    Godotuv `JSON.parse_string` vraci VSECHNA cisla jako float a `int()` z nej
    udela zpet cele cislo. To je presne tehdy, kdyz `int(float(x)) == x`.
    Cislo NAD 2^53 pritom vubec nemusi byt problem (0x4E55000000000000 ma
    53 nulovych bitu na konci, takze float64 ho drzi presne) - proto se to
    OVERUJE pro kazdou hodnotu, ne odhaduje z meze.
    """
    return int(float(hodnota)) == hodnota


def extract(install: str | Path, out_dir: str | Path, raw: bytes | None = None) -> int:
    """Zapise `tiles.json` - land i item zaznamy vcetne flagu a jmen.

    Proč soubor vznika tady a ne ve hre: hra nesmi cist .mul (docs/09 §9.10.2),
    takze vlastnosti dlazdic se musi prevest do JSONu jednou, tady.

    `raw` je jen pro offline self-test (stejne jako u `TileData`).
    """
    if raw is None:
        src = Path(install) / "tiledata.mul"
        if not src.exists():
            print(f"[tiledata] CHYBA: {src} neexistuje")
            return 1
        raw = src.read_bytes()
    td = TileData(raw=raw)

    land: list[list] = []
    item: list[list] = []
    nepresne: list[str] = []

    for tile in range(LAND_COUNT):
        rec = td.land(tile)
        for key in LAND_FIELDS:
            if key == "flags" and not _presnost_ok(rec[key]):
                nepresne.append(f"land[{tile}].flags={rec[key]}")
        land.append([rec[k] for k in LAND_FIELDS])

    for tile in range(ITEM_COUNT):
        rec = td.item(tile)
        if not _presnost_ok(rec["flags"]):
            nepresne.append(f"item[{tile}].flags={rec['flags']}")
        item.append([rec[k] for k in ITEM_FIELDS])

    # Pojistka: kdyby nekdy nejaka hodnota pres float neprosla, tise by se
    # poskodila. Radsi spadni s jasnou hlaskou, nez abys vyrobil spatna data.
    if nepresne:
        print(f"[tiledata] CHYBA: {len(nepresne)} hodnot nejde pres JSON presne "
              f"(napr. {nepresne[0]}) - flagy by musely byt desetinne retezce")
        return 1

    payload = {
        "version": 1,
        "source": {
            "file": "tiledata.mul",
            "bytes": len(raw),
            "sha256": hashlib.sha256(raw).hexdigest(),
            "install_version": "1.25.35",
        },
        "layout": {
            "land_fields": list(LAND_FIELDS),
            "item_fields": list(ITEM_FIELDS),
            "land_count": LAND_COUNT,
            "item_count": ITEM_COUNT,
        },
        "land": land,
        "item": item,
    }
    # Deterministicky vystup (docs/03 §3.7): serazene klice, bez casovych znamek.
    text = json.dumps(payload, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"))
    out = Path(out_dir) / "tiles.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"[tiledata] zapsano {out} ({out.stat().st_size} B, "
          f"sha256 {hashlib.sha256(text.encode()).hexdigest()[:16]}..., "
          f"land {len(land)}, item {len(item)})")
    print(f"[tiledata] vsechny flagy jdou pres JSON presne (overeno pro "
          f"{len(land) + len(item)} zaznamu)")
    return 0


def _synthetic(corrupt: bool = False) -> bytes:
    """Buffer presne o TOTAL bajtech s par znamymi predmety (offline test)."""
    raw = bytearray(TOTAL)

    def put_land(tile: int, texture: int, name: str) -> None:
        off = _record_offset(LAND_OFF, LAND_REC, tile)
        struct.pack_into("<Q", raw, off, 0x40)
        struct.pack_into("<H", raw, off + 8, texture)
        raw[off + 10:off + 30] = b"\x00" * 20          # jmeno se plni celym polem
        raw[off + 10:off + 10 + len(name)] = name.encode("latin-1")

    def put_item(tile: int, layer: int, weight: int, flags: int, name: str) -> None:
        off = _record_offset(ITEM_OFF, ITEM_REC, tile)
        struct.pack_into("<Q", raw, off, flags)
        raw[off + 8] = weight
        raw[off + 9] = layer
        raw[off + 21:off + 41] = b"\x00" * 20          # jmeno se plni celym polem
        raw[off + 21:off + 21 + len(name)] = name.encode("latin-1")

    for tile in range(1200):
        put_land(tile, tile, f"land{tile}")
    for tile in range(11000):
        put_item(tile, 0, 1, 0, f"item{tile}")
    for i in range(1268):                      # jako realna data: 1268 Wearable
        put_item(20000 + i, 1 + (i % 0x1F), 3, FLAG_WEARABLE, f"wear{i}")
    put_item(7609, 5 if corrupt else 6, 2, FLAG_WEARABLE, "leather cap")
    put_item(2482, 21, 3, FLAG_WEARABLE, "backpack")
    put_item(3922, 1, 1, FLAG_WEARABLE, "dagger")
    put_item(3909, 1, 7, FLAG_WEARABLE, "longsword")
    put_item(3911, 1, 6, FLAG_WEARABLE, "katana")
    put_item(4015, 0, 255, 0, "anvil")
    return bytes(raw)


def self_test() -> int:
    failures = 0

    def check(ok: bool, text: str) -> None:
        nonlocal failures
        print(f"[tiledata] {'OK  ' if ok else 'CHYBA'} {text}")
        if not ok:
            failures += 1

    good = TileData(raw=_synthetic())
    checks, errors = verify(good)
    check(not errors, f"cisty buffer: {checks} kontrol, 0 chyb (namEReno {len(errors)}: {errors[:2]})")
    check(good.item(2482)["layer"] == 21, "cteni vrstvy: backpack je 21")
    check(good.land(3)["texture"] == 3, "cteni land: texture id sedi")
    check(good.item(4015)["weight"] == 255, "cteni vahy: anvil je 255")
    check(good.find_item("DAGGER") is not None, "hledani jmena je case-insensitive")

    broken_layer = TileData(raw=_synthetic())
    broken_layer.raw = bytearray(_synthetic())
    broken_layer.raw[_record_offset(ITEM_OFF, ITEM_REC, 7609) + 9] = 5
    _, layer_errors = verify(broken_layer)
    check(any("leather cap" in e for e in layer_errors),
          f"vada (leather cap s vrstvou 5) je odhalena: {[e for e in layer_errors if 'leather cap' in e]}")

    zero_layer = bytearray(_synthetic())
    off = _record_offset(ITEM_OFF, ITEM_REC, 20000)
    struct.pack_into("<Q", zero_layer, off, FLAG_WEARABLE)
    zero_layer[off + 9] = 0
    _, zero_errors = verify(TileData(raw=bytes(zero_layer)))
    check(any("vrstvu 0" in e for e in zero_errors),
          f"vada (Wearable s vrstvou 0) je odhalena: {[e for e in zero_errors if 'vrstvu 0' in e]}")

    try:
        TileData(raw=b"kratke")
        check(False, "kratsi buffer ma vyhodit chybu")
    except ValueError as exc:
        check(True, f"kratsi buffer je odhalen ({exc})")

    # --- extract(): offline test zapisu tiles.json ---------------------------
    # Bez nej by se "zapis funguje" overovalo jen na zive instalaci (pomale
    # a v CI nedostupne) - presne ta vada, na kterou upozornuje docs/08 §8.1.5.
    import json as _json
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        rc = extract("", tmp, raw=_synthetic())
        check(rc == 0, f"extract() na syntetickem bufferu vraci 0 (namEReno {rc})")
        out = Path(tmp) / "tiles.json"
        check(out.exists(), "extract() zapsal tiles.json")
        data = _json.loads(out.read_text(encoding="utf-8"))
        check(data["layout"]["land_count"] == LAND_COUNT,
              f"tiles.json ma land_count {LAND_COUNT}")
        check(data["layout"]["item_count"] == ITEM_COUNT,
              f"tiles.json ma item_count {ITEM_COUNT}")
        check(len(data["land"]) == LAND_COUNT and len(data["item"]) == ITEM_COUNT,
              f"tiles.json ma {len(data['land'])} land a {len(data['item'])} item zaznamu")
        # POZOR: poradi poli je schema souboru - hra cte podle nej.
        check(data["layout"]["land_fields"] == list(LAND_FIELDS),
              f"poradi land poli sedi: {data['layout']['land_fields']}")
        check(data["layout"]["item_fields"] == list(ITEM_FIELDS),
              f"poradi item poli sedi: {data['layout']['item_fields']}")
        # zapsana hodnota musi po ceste JSON -> float -> int vyjit stejna
        fi = ITEM_FIELDS.index("flags")
        li = LAND_FIELDS.index("texture")
        check(int(float(data["land"][3][li])) == 3,
              "land[3].texture prezilo zapis (3)")
        check(int(float(data["item"][2482][fi])) == FLAG_WEARABLE,
              "item[2482].flags prezilo zapis (Wearable)")
        # a hlavne: zapis je DETERMINISTICKY (docs/03 §3.7)
        prvni = out.read_bytes()
        extract("", tmp, raw=_synthetic())
        check(out.read_bytes() == prvni, "dva behy extract() daji bajtove shodny soubor")

    # hodnota, ktera pres float NEPROJDE, musi extract() odmitnout (ne tise poskodit)
    neexaktni = bytearray(_synthetic())
    off = _record_offset(ITEM_OFF, ITEM_REC, 0)
    struct.pack_into("<Q", neexaktni, off, (1 << 53) + 1)      # 2^53+1 neni ve float64
    with tempfile.TemporaryDirectory() as tmp:
        rc = extract("", tmp, raw=bytes(neexaktni))
        check(rc == 1, f"extract() odmitne flag, ktery nejde pres JSON (namEReno {rc})")

    print(f"[tiledata] self-test: 15 kontrol, {failures} chyb")
    return 1 if failures else 0


def main() -> int:
    ap = argparse.ArgumentParser(description="tiledata.mul -> vlastnosti dlaždic a předmětů")
    ap.add_argument("--install", default=DEFAULT_INSTALL)
    ap.add_argument("--extract", default=None, help="vystupni adresar (assets/uo)")
    ap.add_argument("--verify", action="store_true")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--sample", type=int, default=0, help="vypiš N vzorků")
    args = ap.parse_args()
    if args.self_test:
        return self_test()
    if args.extract:
        return extract(args.install, Path(args.extract))

    try:
        td = TileData(args.install)
    except Exception as exc:
        print(f"[tiledata] CHYBA: {exc}")
        return 1

    for tile in range(args.sample):
        print(f"[tiledata] land {tile}: {td.land(tile)}")
        print(f"[tiledata] item {tile}: {td.item(tile)}")

    if not args.verify:
        print("[tiledata] (bez --verify se jen nacte soubor; nic se nemERilo)")
        return 0

    checks, errors = verify(td)
    for e in errors:
        print(f"[tiledata] CHYBA: {e}")
    print(f"[tiledata] {checks} kontrol, {len(errors)} chyb")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
