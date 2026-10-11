# -*- coding: utf-8 -*-
"""styl.py - pixel-artovy styl vlastni sady (2026-10-11).

PROC TENHLE MODUL EXISTUJE (namERena vada, ne dojem): vlastni sprite mel
**473 ruznych barev v 556 pixelech** a **197 polopruhlednych pixelu**, kdezto
UO sprite téhož druhu **61 barev a 0 polopruhlednych**. To je presne to, co
uzivatel vidi jako "rozmazany a bez detailu": hladky antialiasovany 3D render
misto pixel artu. Prvni integrace (2026-10-11) to jen prenesla do hry.

RESI TO TRI VECI (v tomto poradi):

  1. DOOSTRENI (`doostri`) - UnsharpMask na MALEM spritu (po Lanczosu, pred
     kvantizaci). Vrati ostrost hrany; namEReno na prototypu 26,8 -> 48,7
     (UO ma 41,4).
  2. TVRDA ALFA (`tvrda_alfa`) - na SILUETE je alfa 0/255 (pixel art nema
     pruhledne okraje). Kontaktni stin zustava MEKKY - je to stin, ne silueta,
     a jeho mekkost je zamer (viz `postprocess_lit.vrstva_stinu`).
  3. PALETA (`postav_paletu`, `na_paletu`) - kvantizace na N barev. Paleta se
     stavi z TOHO, CO SE OPRAVDU KRESLI (`SadaPalety.pridej` dostava pixely po
     doostreni a jen tam, kde bude pixel videt), takze neni opsana z palety UO
     a sedi na nasi svetelnou sestavu.

CO SE ZAMERNE NEDELA: obrys/outline (to je jina zmena - nesmi pohnout kotvou
ani boxem) a dither (u 44px dlazdice by z nej byl sum).

Pouziti (viz `pack_atlas_lit.py`):
    sber = styl.SadaPalety()
    ... sestav(pripravene, s, druh, sber=sber)          # 1. pruchod: jen vzorky
    paleta = sber.postav()
    ... sestav(pripravene, s, druh, paleta=paleta, tvrda_alfa=True)
"""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

# Prah, od ktereho je pixel na siluete "plny". 128 = pulka krytí, tedy presne
# misto, kde antialiasovana hrana prechazi; vyssi prah by siluetu ohlodal,
# nizsi by nechal 1px svetly lem.
ALFA_TVRDA_PRAH = 128
# Cilovy pocet barev na jednu DAVKU (davka = jeden model: 40 framu postavy,
# jedna dlazdice, jeden predmet). Neni to "celych 46 spritu" - viz docstring
# `SadaPalety`.
PALETA_BAREV = 40
# UnsharpMask na malem spritu. ⚠ POZOR (namEReno POHLEDEM 2026-10-11): i maly
# UnsharpMask dela na TENKE DIAGONALE (rukojet krumpace) stridave svetle/tmave
# pixely - Lanczos tam nechava krouzkovani a doostreni ho zesili; paleta to pak
# zpevni na dve barvy a rukojet vypada jako teckovana. Proto je doostreni
# VYPNUTE (0) a ostrost dela TVRDA ALFA + PALETA. Kdo ho zapne, at se na vysledek
# PODIVA na 8x zvetsenem spritu, ne jen na cislo ostrosti.
DOOSTRENI_PROCENT = 0


def doostri(img: Image.Image, procent: int = DOOSTRENI_PROCENT) -> Image.Image:
    """Doostri RGB (alfu NECHÁVÁ být - ostri se jen barva)."""
    if procent <= 0:
        return img.convert("RGB")
    rgb = img.convert("RGB")
    return rgb.filter(ImageFilter.UnsharpMask(radius=1, percent=procent, threshold=0))


def tvrda_alfa(alfa: np.ndarray, gate: np.ndarray,
               prah: int = ALFA_TVRDA_PRAH) -> np.ndarray:
    """Z MEKKE alfy udela 0/255 uvnitr `gate` (pixel art silueta).

    ⚠ HYSTEREZE, NE JEDEN PRAH (namEReno POHLEDEM 2026-10-11): u tenkych
    diagonal (rukojet krumpace, ~1 px) krytí na střídavých pixelech padá pod
    prah, takze se silueta rozpadne na tecky - a pod ni prosvita kontaktni stin.
    Proto se k pixelum nad `prah` pripoji i pixely nad POLOVINOU prahu, ktere se
    jich dotykaji (8-okoli). Vysledek je porad 0/255, ale tenky prvek zustane
    cely. `gate` (maska rozsirena o 2 px v meritku renderu) brani tomu, aby se
    do siluety pritahl obal z Lanczosu daleko od tvaru.
    """
    silne = (alfa >= prah) & gate
    if not silne.any():
        return np.zeros(alfa.shape, dtype=np.uint8)
    slabe = (alfa >= max(1, prah // 2)) & gate & ~silne
    if slabe.any():
        dotyk = ndimage.binary_dilation(silne, iterations=1) & slabe
        silne = silne | dotyk
    # ⚠ ZADNE `binary_closing`: drivejsi "teckovana rukojet" NEBYLA dira v alfe,
    # ale krouzkovani z UnsharpMasku (viz `DOOSTRENI_PROCENT`). Zavirani jen
    # pritahlo svetly obal z Lanczosu dovnitr siluety (namEReno POHLEDEM: svetly
    # lem kolem postavy). Kdo sem chce zpet "spojovani der", at nejdriv dolozi
    # MERENIM, ze diry v alfe opravdu jsou.
    return np.where(silne, 255, 0).astype(np.uint8)


class SadaPalety:
    """Sbere vzorky z cele davky a postavi z nich jednu paletu.

    PROC DAVKA, NE CELA SADA: `sestav` se vola po modelech (davka = 40 framu
    postavy, jedna dlazdice, jeden predmet) a paleta z CELÉ sady by musela
    protahnout vzorky pres orchestrator. Paleta z jedne davky drzi pohon
    pohromade (vsech 40 framu postavy ma TUTEZ paletu - to je to, co by
    rozjete barvy mezi framy odhalilo) a pritom se nic neprepisuje ve dvou
    mistech. Je to ZMERENE rozhodnuti, ne opomenuti; kdyby sada potrebovala
    jednu paletu pro vsech 46 spritu, je to zmena v `pack_atlas_*.py`.
    """

    def __init__(self, pocet: int = PALETA_BAREV) -> None:
        self.pocet = pocet
        self._vzorky: list[np.ndarray] = []
        self._px = 0

    def pridej(self, rgb: np.ndarray, alfa: np.ndarray) -> None:
        """Prida vzorky jen tam, kde bude pixel VIDET (alfa >= prah)."""
        mask = alfa >= ALFA_TVRDA_PRAH
        if not mask.any():
            return
        v = rgb[mask]
        self._vzorky.append(v.astype(np.uint8))
        self._px += int(v.shape[0])

    def postav(self) -> Image.Image | None:
        """Vrati paletovy obrazek (mod "P") nebo None, kdyz nejsou vzorky."""
        if not self._vzorky:
            return None
        vse = np.concatenate(self._vzorky, axis=0)
        if vse.shape[0] < self.pocet:
            # Mene vzorku nez barev: kvantizace by vratila mene barev, nez je
            # pozadovano - to je v poradku, ale musi to byt videt v reportu.
            self.pocet = max(1, int(vse.shape[0]))
        img = Image.fromarray(vse.reshape(1, -1, 3), "RGB")
        return img.quantize(colors=self.pocet, method=Image.Quantize.MEDIANCUT)

    def pocet_vzorku(self) -> int:
        return self._px


def na_paletu(rgb: np.ndarray, paleta: Image.Image) -> np.ndarray:
    """Namapuje barvy na paletu (bez ditheru - u 44px dlazdice by byl sum)."""
    if paleta is None:
        return rgb
    img = Image.fromarray(rgb.astype(np.uint8), "RGB")
    return np.asarray(img.quantize(palette=paleta, dither=Image.Dither.NONE).convert("RGB"))


def barvy_palety(paleta: Image.Image) -> list[list[int]]:
    """Paleta jako seznam RGB - pro report do manifestu (aby se dala overit)."""
    if paleta is None:
        return []
    raw = paleta.getpalette() or []
    vyuzite = paleta.getcolors(maxcolors=1 << 24) or []
    out: list[list[int]] = []
    for _pocet, idx in sorted(vyuzite, key=lambda d: -d[0]):
        out.append([int(raw[3 * idx]), int(raw[3 * idx + 1]), int(raw[3 * idx + 2])])
    return out
