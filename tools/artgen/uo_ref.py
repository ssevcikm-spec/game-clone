# -*- coding: utf-8 -*-
"""uo_ref.py - precte PUVODNI sprite z `assets/uo/atlas/` podle manifestu.

`assets/uo/` je jen ke CTENI (jsou to data z instalace UO, ZADANI-25 §5).
Tenhle modul je jedine misto, kde se z originalu neco vyndava - pouziva ho
`contact_sheet.py` (vlastni vedle puvodniho) i `pack_atlas.py --check`
(kontrola, ze srovnavame tutez velikost).

Nic se tu nepocita "od oka": `obsah()` vraci NAMERENY bounding box obsahu
(alpha > 0), protoze UO art ma v boxu prazdne okraje (mereno 2026-10-10:
dyka 3921 ma box 22x26 a obsah jen 11x11 px).
"""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

UO = Path("assets/uo")


def nacti_manifest(cesta: Path = None) -> dict:
    cesta = Path(cesta) if cesta else UO / "manifest.json"
    return json.loads(cesta.read_text(encoding="utf-8"))


def zaznam(manifest: dict, kind: str, ident: int) -> dict | None:
    for s in manifest["sprites"]:
        if s["kind"] == kind and s["id"] == ident:
            return s
    return None


class Stranky:
    """Lena cache stranek atlasu (jedna stranka = 16 MB, nechceme ji cist 2x)."""

    def __init__(self, zaklad: Path = UO) -> None:
        self.zaklad = Path(zaklad)
        self._cache: dict[str, Image.Image] = {}

    def stranka(self, soubor: str) -> Image.Image:
        if soubor not in self._cache:
            self._cache[soubor] = Image.open(self.zaklad / soubor).convert("RGBA")
        return self._cache[soubor]

    def sprite(self, zaznam: dict) -> Image.Image:
        """Vyreze sprite z jeho stranky (rect je [levy, horni, pravy, dolni] jako v PILu)."""
        return self.stranka(zaznam["page"]).crop(tuple(zaznam["rect"]))


def obsah(img: Image.Image) -> tuple[int, int, int, int] | None:
    """Bounding box obsahu (alpha > 0) nebo None, kdyz je sprite prazdny."""
    return img.split()[3].getbbox()


def zmensene(img: Image.Image, kolik: int) -> Image.Image:
    """Nearest upscale - na kontrolu pixelu pohledem (Lanczos by rozmazal)."""
    return img.resize((img.width * kolik, img.height * kolik), Image.NEAREST)


def _font(size: int):
    from PIL import ImageFont
    for p in (r"C:\Windows\Fonts\arial.ttf", r"C:\Windows\Fonts\arialbd.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default()


def zoom_list(cesta: Path, kind: str, ids: list[int], kolik: int = 8,
              zaklad: Path = UO) -> int:
    """Zvetseny prehled originalu (na navrh modelu: tvar, orientace, pruhlednost)."""
    from PIL import ImageDraw
    from artgen_common import TILE
    m = nacti_manifest(Path(zaklad) / "manifest.json")
    st = Stranky(zaklad)
    bunka = TILE * kolik
    w = bunka * len(ids)
    h = bunka + 28
    plachta = Image.new("RGBA", (w, h), (28, 30, 36, 255))
    d = ImageDraw.Draw(plachta)
    f = _font(14)
    for i, ident in enumerate(ids):
        z = zaznam(m, kind, ident)
        if z is None:
            d.text((i * bunka + 6, 6), f"{kind} {ident}: CHYBI", font=f,
                   fill=(255, 120, 120, 255))
            continue
        s = st.sprite(z)
        bb = obsah(s)
        d.text((i * bunka + 6, 6), f"{kind} {ident}  box {s.width}x{s.height} "
               f"obsah {bb[2]-bb[0]}x{bb[3]-bb[1]}", font=f, fill=(220, 220, 220, 255))
        plachta.alpha_composite(zmensene(s, kolik), (i * bunka + (bunka - s.width * kolik) // 2, 28))
    plachta.convert("RGB").save(cesta)
    print(f"[uo_ref] zoom list: {cesta} ({len(ids)} spritu, x{kolik})")
    return 0


if __name__ == "__main__":
    import argparse
    from artgen_common import ITEMS, LAND
    ap = argparse.ArgumentParser(description="nahled originalu z assets/uo")
    ap.add_argument("--out", default="tools/artgen/_uo-refs.png")
    ap.add_argument("--zoom", type=int, default=8)
    ap.add_argument("--kinds", default="item,land")
    a = ap.parse_args()
    rc = 0
    druhy = a.kinds.split(",")
    for kind in druhy:
        ids = [i["uo_id"] for i in (ITEMS if kind == "item" else LAND)]
        cesta = Path(a.out)
        if len(druhy) > 1:
            cesta = cesta.with_name(cesta.stem + f"-{kind}" + cesta.suffix)
        rc |= zoom_list(cesta, kind, ids, a.zoom)
    raise SystemExit(rc)
