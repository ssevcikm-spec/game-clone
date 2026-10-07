#!/usr/bin/env python3
"""Vygeneruje maly fixture animace pro test render.anim (tests/fixtures/anim/).

PROC: `assets/uo/` je v .gitignore, takze v CI zadny export animaci NENI - test
`tests/cases/render_anim.gd` by tam nepridal ani jednu kontrolu a mutace na
`render/anim_player.gd` by prosly. Fixture je mala, deterministicka a V GITU,
takze se format i chovani meri VZDY (i v CI).

FORMAT (cteny z `tools/uoextract/anim.py:export_sheets` a z `render/anim_player.gd`;
je STEJNY jako `python tools/uoextract/anim.py --export assets/uo/anim`):
  * `anim-sheets.json` = `{version, decoder, anchor, actions, sprites, chyby}`,
  * `sprites["telo/akce/smer"]` = `{file, action, frames, source}`, kde `smer` je
    smer v anim.mul 0..4 (NE smer hry 0..7 - ty se na nej mapuji pres `DIR_MAP`),
  * frame = `{rect, cx, cy, w, h, pixely_mimo}`; `rect` je BOX PILu
    `[levy, horni, pravy, dolni]` (ne `[x, y, w, h]`) - `anim_player.gd` z nej
    bere `region = Rect2(rect[0], rect[1], w, h)`,
  * `cx`, `cy` jsou posuny z hlavicky framu; kotva je `(cx, cy + h)`.

CO JE TU ZAMERNE (aby vada nebyla k nerozeznani od spravne hodnoty):
  * pocet framu je JINY nez v realnem exportu (2 az 4, ne 10) a u kazdeho
    sprite smeru JINY - prohozeny klic se pozna na `frame_count` i na `rect`,
  * `400/0/*` je vsech 5 sprite smeru, takze mapovani 8 smeru hry na 5 spritu
    (`DIR_MAP`) se da merit na skutecnych datech a vsech 5 spritech,
  * `400/1/*` (run) a telo 401 tu ZAMERNE NEJSOU - test na nich meri
    `ok:false` + `texture:null` (zadne tiche prazdno, docs/08 §8.6),
  * `cx` je pro kazdy sprite jiny a `cy` pro kazdy frame jiny - kotva
    `(cx, cy + h)` ani `mirror_x = w - cx` se neda trefit nahodou,
  * `sheet0.png` je pro akci 0 (pet radku, jeden na sprite smer) a `sheet1.png`
    pro akci 4 (idle) s JINOU vyskou framu (24, ne 16) - kdyby kod bral rozmery
    odjinud nez z JSONu, pozna se to,
  * pixely: kazdy frame ma vlastni barvu (sprite, frame) a vlastni znacku
    (bily pruh na sloupci `1 + 2 * frame`) - prohozene framy je VIDET.

  python tests/fixtures/anim/make_fixture.py           # zapise soubory
  python tests/fixtures/anim/make_fixture.py --check   # jen overi (pro CI)
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
import sys
from pathlib import Path

DIR = Path(__file__).resolve().parent

FRAME_W = 16        # sirka framu v PNG
FRAME_H = 16        # vyska framu akce 0 (walk)
IDLE_H = 24         # vyska framu akce 4 (idle) - ZAMERNE jina nez FRAME_H
SHEET_W = 64        # sirka obou PNG (4 framy vedle sebe)
CX0 = 3             # cx sprite smeru 0 (dalsi +1, aby se prohozeni spritu videli)
CY0 = -8            # cy framu 0 (dalsi -1, aby se prohozeni framu videli)

# Jeden radek PNG = jeden klic `telo/akce/smer`; `frames` je pocet framu v radku.
KEYS: list[dict] = [
    {"klic": "400/0/0", "file": "sheet0.png", "action": "walk",
     "sprite": 0, "frames": 2, "w": FRAME_W, "h": FRAME_H, "row": 0},
    {"klic": "400/0/1", "file": "sheet0.png", "action": "walk",
     "sprite": 1, "frames": 3, "w": FRAME_W, "h": FRAME_H, "row": 1},
    {"klic": "400/0/2", "file": "sheet0.png", "action": "walk",
     "sprite": 2, "frames": 2, "w": FRAME_W, "h": FRAME_H, "row": 2},
    {"klic": "400/0/3", "file": "sheet0.png", "action": "walk",
     "sprite": 3, "frames": 4, "w": FRAME_W, "h": FRAME_H, "row": 3},
    {"klic": "400/0/4", "file": "sheet0.png", "action": "walk",
     "sprite": 4, "frames": 2, "w": FRAME_W, "h": FRAME_H, "row": 4},
    {"klic": "400/4/1", "file": "sheet1.png", "action": "idle",
     "sprite": 1, "frames": 1, "w": FRAME_W, "h": IDLE_H, "row": 0},
]


def frame_zaznam(k: dict, i: int) -> dict:
    """Zaznam jednoho framu - presne klice, ktere pouziva `anim_player.gd`."""
    x, y = i * k["w"], k["row"] * k["h"]
    return {"rect": [x, y, x + k["w"], y + k["h"]],
            "cx": CX0 + k["sprite"], "cy": CY0 - i,
            "w": k["w"], "h": k["h"], "pixely_mimo": 0}


def zaznam(k: dict) -> dict:
    """Zaznam jednoho spritu (jeden radek PNG)."""
    return {"file": k["file"], "action": k["action"],
            "frames": [frame_zaznam(k, i) for i in range(k["frames"])],
            "source": "fixture"}


def manifest() -> dict:
    return {
        "version": 1,
        "decoder": ("fixture (tests/fixtures/anim/make_fixture.py) - NENI to "
                    "export z instalace UO; format je stejny jako "
                    "`python tools/uoextract/anim.py --export assets/uo/anim`"),
        "anchor": ("obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); "
                   "rect je [levy, horni, pravy, dolni]"),
        "actions": {"0": "walk", "4": "idle"},
        "sprites": {k["klic"]: zaznam(k) for k in KEYS},
        "chyby": [],
    }


def png_rozmery(soubor: str) -> tuple[int, int]:
    """(sirka, vyska) platna pro vsechny framy souboru - z KEYS, ne opsane."""
    return (SHEET_W, max((k["row"] + 1) * k["h"] for k in KEYS if k["file"] == soubor))


def pixel(k: dict, i: int, x: int, y: int) -> tuple[int, int, int, int]:
    """Barva pixelu framu `i` spritu `k` na lokalnich souradnicich framu.

    Nad linkou zeme (`cy + h`) je telo, na sloupci `1 + 2 * i` je bila znacka
    framu - prohozene framy nebo prohozeny sprite je proto VIDET ocima.
    """
    linka = (CY0 - i) + k["h"]          # cy + h = linka zeme v radcich framu
    if y >= linka:
        return (0, 0, 0, 0)
    if x == 1 + 2 * i:
        return (255, 255, 255, 255)
    if 4 <= x <= k["w"] - 5:
        return (40 + 40 * k["sprite"], 40 + 40 * i, 220 - 30 * k["sprite"], 255)
    return (0, 0, 0, 0)


def png_bytes(soubor: str) -> bytes:
    """PNG se vsemi framy jednoho souboru (kazdy klic je jeden radek)."""
    from PIL import Image

    sirka, vyska = png_rozmery(soubor)
    obrazek = Image.new("RGBA", (sirka, vyska), (0, 0, 0, 0))
    pixely = obrazek.load()
    for k in KEYS:
        if k["file"] != soubor:
            continue
        for i in range(k["frames"]):
            f = frame_zaznam(k, i)
            for y in range(k["h"]):
                for x in range(k["w"]):
                    pixely[f["rect"][0] + x, f["rect"][1] + y] = pixel(k, i, x, y)
    buf = io.BytesIO()
    obrazek.save(buf, format="PNG")
    return buf.getvalue()


def manifest_bytes() -> bytes:
    return json.dumps(manifest(), ensure_ascii=False, indent=1).encode("utf-8")


def soubory() -> dict[Path, bytes]:
    return {
        DIR / "sheet0.png": png_bytes("sheet0.png"),
        DIR / "sheet1.png": png_bytes("sheet1.png"),
        DIR / "anim-sheets.json": manifest_bytes(),
    }


def pixely(data: bytes) -> tuple:
    """(rozmer, RGBA bajty) - obsah PNG nezavisly na kompresi."""
    from PIL import Image

    obrazek = Image.open(io.BytesIO(data)).convert("RGBA")
    return (obrazek.size, obrazek.tobytes())


def shoda(path: Path, data: bytes) -> tuple[bool, str]:
    """(sedi, popis). U PNG rozhoduje OBSAH (pixely), u JSONu bajty.

    Ruzne verze zlib/Pillow daji jiny komprimovany proud, ale stejny obrazek -
    a to neni rozdil fixture, ktery by mel shodit `--check`.
    """
    hash_new = hashlib.sha256(data).hexdigest()[:12]
    if not path.exists():
        return False, f"CHYBI na disku (generator {hash_new})"
    disk = path.read_bytes()
    hash_disk = hashlib.sha256(disk).hexdigest()[:12]
    if disk == data:
        return True, f"disk {hash_disk}, generator {hash_new}"
    if path.suffix == ".png":
        if pixely(disk) == pixely(data):
            return True, (f"stejne pixely, jine bajty (disk {hash_disk}, "
                          f"generator {hash_new})")
        return False, f"JINE PIXELY (disk {hash_disk}, generator {hash_new})"
    return False, f"JINE BAJTY (disk {hash_disk}, generator {hash_new})"


def main() -> int:
    ap = argparse.ArgumentParser(description="Fixture pro render.anim")
    ap.add_argument("--check", action="store_true", help="jen overit, nezapisovat")
    args = ap.parse_args()
    chyby = 0
    for path, data in soubory().items():
        if args.check:
            ok, popis = shoda(path, data)
            chyby += 0 if ok else 1
            print(f"[fixture] {'OK  ' if ok else 'JINA'} {path.name}: {popis}")
        else:
            path.write_bytes(data)
            print(f"[fixture] zapsano {path.name}: {len(data)} B, "
                  f"sha256 {hashlib.sha256(data).hexdigest()[:12]}")
    if args.check and chyby:
        print(f"[fixture] {chyby} souboru neodpovida generatoru "
              f"(spust bez --check a projdi `git status`)")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
