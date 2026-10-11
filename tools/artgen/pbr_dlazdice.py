#!/usr/bin/env python3
"""PBR sada (basecolor+normal+AO) -> dlazdice do hry (44x44, kosoctverec 1:1).

PROC TENHLE NASTROJ EXISTUJE: uzivatel stahuje volne PBR sady do
`E:\\Workspaces\\assets\\3d_sample` a chce je nasazovat bez rucni prace. Postup
("zapeč dlazdici, zapis manifest, pridej vrstvu do `assets/own-art.json`") byl
drive jen v gitignorovane `_analyza/` - tedy nebyl v repu a nedal se zopakovat.
Tenhle nastroj je ta cesta v repu.

CO DELA: z barevne mapy + normaly + ambient occlusion zapeče 2D dlazdici v NASE
projekci (kosoctverec 44x44, krok 22 px, svisle nezkracene - viz
`RESERSE-ART-PIPELINE-2026-10-11.md` §11) a zapise atlas + manifest ve STEJNEM
kontraktu, jaky pouziva `render/texture_cache.gd` a `assets/own-lit/`.

DVE VECI, KTERE SE NESMI MENIT BEZ MERENI (cisla jsou namERena, ne odhad):
  * SVETLO: smer je zapečeny z normaly (`N.L`, L zleva) a AO ho jen ztmavi
    (0.55 + 0.45*AO). UO kresli svetlo zleva-shora; na 1003 to vychazi +4,4.
  * JAS: dlazdice se srovnava na `TARGET=58`, protoze UO dlazdice v okoli
    Britainu maji prumer 57-59 (namEReno). Kdo to zmeni, rozjede se mu teren.

Pouziti:
  python tools/artgen/pbr_dlazdice.py --seznam
  python tools/artgen/pbr_dlazdice.py --sada Stone_Path_007 --id 1001,1002,1003,1004 \
      --vystup assets/stone-path
  python tools/artgen/pbr_dlazdice.py --kontrola assets/stone-path   # determinismus

Po zapečeni je potreba JESTE rict, ktera (kind, id) se z vrstvy berou a odkud:
`assets/own-art.json` (a pro varianty podle souradnic bunky klic `groups`).
"""
from __future__ import annotations

import argparse
import glob
import hashlib
import json
import os
import sys
import zipfile
from pathlib import Path

import numpy as np
from PIL import Image

STEP, CELL = 22, 44          # krok mrizky a velikost dlazdice (core/iso.gd)
GRAIN = 1.4                  # zvetseni textur pred vzorkovanim (mene sumu v 44 px)
TARGET = 58.0                # jas, na ktery se dlazdice srovnava (UO okoli 57-59)
L = np.array([-0.7071, 0.0, 0.7071])   # smer svetla ZLEVA (y=0 -> konvence zeleneho kanalu nerozhoduje)
# Vychozi vyrezy textury pro 4 varianty (v jednotkach dlazdic). Jsou PEVNE, aby
# byl zapek deterministicky - nahoda za behu by rozbila replaye a snimky v CI.
VZORKY = [(7.0, 11.0), (23.0, 5.0), (13.0, 27.0), (31.0, 19.0)]


def _maska() -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    yy, xx = np.mgrid[0:CELL, 0:CELL]
    dx, dy = xx - CELL / 2 + 0.5, yy - CELL / 2 + 0.5
    alfa = np.where(np.abs(dx) + np.abs(dy) <= STEP + 0.2, 255, 0).astype(np.uint8)
    a = (dx + dy) / (2 * STEP)
    b = (dy - dx) / (2 * STEP)
    return alfa, a, b


ALFA, A_, B_ = _maska()


def nacti(p: Path) -> np.ndarray:
    im = Image.open(p).convert("RGB")
    if GRAIN != 1.0:
        im = im.resize((im.width, int(im.height * GRAIN)), Image.LANCZOS)
    return np.asarray(im).astype(np.float32)


def vzorkuj(img: np.ndarray, cx: float, cy: float, s: float) -> np.ndarray:
    """Bilinearni odber dlazdice z textury; textura se omota dokola (bezevne)."""
    sx = ((cx + 0.5 + A_) * s) % img.shape[1]
    sy = ((cy + 0.5 + B_) * s) % img.shape[0]
    x0, y0 = np.floor(sx).astype(int), np.floor(sy).astype(int)
    fx, fy = sx - x0, sy - y0
    x1, y1 = (x0 + 1) % img.shape[1], (y0 + 1) % img.shape[0]
    return ((img[y0, x0] * (1 - fx)[..., None] + img[y0, x1] * fx[..., None]) * (1 - fy)[..., None]
            + (img[y1, x0] * (1 - fx)[..., None] + img[y1, x1] * fx[..., None]) * fy[..., None])


def najdi(slozka: Path, klic: str) -> Path | None:
    for p in sorted(glob.glob(str(slozka / "**" / "*"), recursive=True),
                    key=lambda q: os.path.getsize(q), reverse=True):
        if os.path.isfile(p) and klic in os.path.basename(p).lower():
            return Path(p)
    return None


def rozbal(zdroj: Path, kam: Path) -> None:
    """ZIPy se rozbalaji pod jmenem archivu (ne indexem) - jinak by se dve sady michaly."""
    kam.mkdir(parents=True, exist_ok=True)
    for z in sorted(glob.glob(str(zdroj / "*.zip"))):
        d = kam / os.path.splitext(os.path.basename(z))[0][:44]
        if not d.is_dir():
            with zipfile.ZipFile(z) as f:
                f.extractall(d)


def sady(zdroj: Path, kam: Path) -> list[tuple[str, Path, Path | None, Path | None, Path]]:
    """[(jmeno, basecolor, normal, AO, puvod)] - ze slozek i z rozbalitych ZIPu."""
    rozbal(zdroj, kam)
    out, videno = [], set()
    for d in sorted([Path(p) for p in glob.glob(str(kam / "*")) if os.path.isdir(p)]
                    + [zdroj]):
        col = najdi(d, "basecolor") or najdi(d, "albedo")
        if col is None:
            continue
        jmeno = jmeno_sady(col.name)
        if jmeno.lower() in videno:
            continue
        videno.add(jmeno.lower())
        # PUVOD do manifestu: kdyz se sada nasla v rozbalenem ZIPu, patri tam
        # original (uzivateluv archiv), ne cesta do `.cache/`.
        puvod = col
        if kam in col.parents:
            puvod = zdroj / (col.relative_to(kam).parts[0] + ".zip")
        out.append((jmeno, col, najdi(col.parent, "normal"),
                    najdi(col.parent, "ambientocclusion"), puvod))
    return out


def jmeno_sady(nazev: str) -> str:
    """`Stone_Path_007_basecolor.jpg` -> `Stone_Path_007` (bez ohledu na velikost pismen)."""
    for suf in ("_basecolor", "_albedo", "_diffuse", "_color", "_col"):
        i = nazev.lower().find(suf)
        if i > 0:
            return nazev[:i]
    return nazev.rsplit(".", 1)[0]


def pitch(a: np.ndarray) -> float:
    """Heuristika "kolik svetlych useku je v radku" - odhad kroku textury."""
    g = np.asarray(Image.fromarray(a.astype(np.uint8)).convert("L")).astype(np.float32)
    thr = np.percentile(g, 35)
    c = []
    for y in range(g.shape[0] // 8, g.shape[0] - g.shape[0] // 8, max(1, g.shape[0] // 40)):
        row, runs, prev = g[y] > thr, 0, False
        for b in row:
            if b and not prev:
                runs += 1
            prev = b
        if runs > 2:
            c.append(runs)
    return float(np.median(c)) if c else 1.0


def zapek(col: Path, nrm: Path | None, ao: Path | None, s: float | None):
    """Vrati funkci (cx, cy) -> Image 44x44 RGBA a pouzity krok `s`."""
    im = Image.open(col).convert("RGB")
    base = nacti(col)
    if s is None:
        s = float(np.clip(560.0 * (im.width / 1024.0) * (23.0 / max(pitch(base), 1.0)),
                          60, im.width))
    if nrm is not None:
        n = nacti(nrm) / 127.5 - 1.0
        sh = 0.35 + 0.85 * np.clip(n[:, :, 0] * L[0] + n[:, :, 2] * L[2], 0, 1)
        if ao is not None:
            sh = sh * (0.55 + 0.45 * (nacti(ao).mean(axis=2) / 255.0))
        base = np.clip(base * sh[..., None], 0, 255)

    def jedna(cx: float, cy: float) -> Image.Image:
        c = vzorkuj(base, cx, cy, s)
        c = np.clip(c * (TARGET / max(1e-6, c.mean())), 0, 255)
        return Image.fromarray(np.dstack([c, ALFA]).astype(np.uint8), "RGBA")
    return jedna, s


def zapis_sadu(jedna, ids: list[int], vystup: Path) -> bytes:
    """Zapise atlas + manifest; vraci bajty atlasu (pro kontrolu)."""
    (vystup / "atlas").mkdir(parents=True, exist_ok=True)
    stranka = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    sprites = []
    for i, aid in enumerate(ids):
        t = jedna(*VZORKY[i % len(VZORKY)])
        x = i * (CELL + 1)
        stranka.alpha_composite(t, (x, 0))
        sprites.append({"id": aid, "kind": "land", "page": "atlas/land_0.png",
                        "x": x, "y": 0, "w": CELL, "h": CELL, "ox": 0, "oy": 0,
                        "rect": [x, 0, x + CELL, CELL]})
    cesta = vystup / "atlas" / "land_0.png"
    stranka.save(cesta)
    man = {
        "version": 1,
        "material": "pbr",
        "generator": "tools/artgen/pbr_dlazdice.py",
        "zdroj": "",
        "comment": ("Zapek PBR sady do dlazdic 1:1 (krok 22 px), svetlo N.L zleva, "
                    "jas srovnan na TARGET=58. `material: pbr` rika brane G16, ze "
                    "tahle sada neni pixel art z tools/artgen/styl.py - misto reportu "
                    "o stylu se u ni meri tvrda alfa."),
        "pad": 1,
        "page_size": 256,
        "pages": [{"file": "atlas/land_0.png", "w": 256, "h": 256, "count": len(sprites)}],
        "sprites": sprites,
    }
    with open(vystup / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(man, f, indent=1, ensure_ascii=False)
    return cesta.read_bytes()


def hash_bajtu(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser(description="PBR sada -> dlazdice 1:1 pro tuhle hru")
    ap.add_argument("--zdroj", default=r"E:\Workspaces\assets\3d_sample",
                    help="odkud brat PBR sady (slozky i ZIPy)")
    ap.add_argument("--rozbaleno", default=None,
                    help="kam rozbalit ZIPy (vychozi: <repo>/.cache/pbr-sady - do zdroje se nesaha)")
    ap.add_argument("--seznam", action="store_true", help="jen vypis rozpoznanych sad")
    ap.add_argument("--sada", default=None, help="podretezec jmena sady (napr. Stone_Path_007)")
    ap.add_argument("--id", default=None, help="land id pro varianty, napr. 1001,1002,1003,1004")
    ap.add_argument("--vystup", default=None, help="kam zapsat (napr. assets/stone-path)")
    ap.add_argument("--S", type=float, default=None,
                    help="px textury na dlazdici (vychozi: heuristika; u zvetrych textur ji nastav okem)")
    ap.add_argument("--kontrola", default=None,
                    help="jen over, ze zapek do teto slozky je reprodukovatelny (nezapisuje)")
    args = ap.parse_args()

    zdroj = Path(args.zdroj)
    repo = Path(__file__).resolve().parents[2]
    # ZIPy se rozbaluji DO WORKSPACE (`.cache/` je v .gitignore), ne do zdrojove
    # slozky uzivatele - a nikdy do systemoveho tempu (namEReno: nastroj, ktery
    # "zapsal do tempu", tam soubor nemel).
    rozbaleno = Path(args.rozbaleno) if args.rozbaleno else repo / ".cache" / "pbr-sady"

    if args.kontrola:
        vystup = Path(args.kontrola)
        man = json.loads((vystup / "manifest.json").read_text(encoding="utf-8"))
        puvod = (vystup / "atlas" / "land_0.png").read_bytes()
        if args.sada is None:
            print("[pbr] --kontrola potrebuje i --sada (podle ni se hleda zdroj)")
            return 2
        sada = [s for s in sady(zdroj, rozbaleno) if args.sada.lower() in s[0].lower()]
        if len(sada) != 1:
            print("[pbr] sada '%s' se nenasla jednoznacne (%d)" % (args.sada, len(sada)))
            return 2
        jmeno, col, nrm, ao, _puvod = sada[0]
        jedna, s = zapek(col, nrm, ao, args.S)
        tmp = repo / ".cache" / "artgen-kontrola"
        tmp.mkdir(parents=True, exist_ok=True)
        nove = zapis_sadu(jedna, [int(x) for x in args.id.split(",")]
                          if args.id else [sp["id"] for sp in man["sprites"]], tmp)
        stejne = hash_bajtu(nove) == hash_bajtu(puvod)
        print("[pbr] kontrola %s: S=%.0f, atlas %s (%s)"
              % (jmeno, s, "SHODNY" if stejne else "JINY",
                 hash_bajtu(nove)[:16]))
        return 0 if stejne else 1

    seznam = sady(zdroj, rozbaleno)
    if args.seznam or args.sada is None:
        print("[pbr] %d sad v %s" % (len(seznam), zdroj))
        for jmeno, col, nrm, ao, _puvod in seznam:
            im = Image.open(col)
            base = nacti(col)
            s = float(np.clip(560.0 * (im.width / 1024.0) * (23.0 / max(pitch(base), 1.0)),
                              60, im.width))
            print("   %-34s %4dx%-4d  normal=%-5s AO=%-5s S~%3.0f  jas textury %.1f"
                  % (jmeno, im.width, im.height, bool(nrm), bool(ao), s, base.mean()))
        if args.seznam:
            return 0

    if args.sada is None or args.id is None or args.vystup is None:
        print("[pbr] --sada, --id a --vystup jsou potreba pro zapečeni")
        return 2

    vybrane = [s for s in seznam if args.sada.lower() in s[0].lower()]
    if len(vybrane) != 1:
        print("[pbr] sada '%s' se nenasla jednoznacne (%d kandidatu: %s)"
              % (args.sada, len(vybrane), [v[0] for v in vybrane]))
        return 2
    jmeno, col, nrm, ao, puvod = vybrane[0]
    ids = [int(x) for x in args.id.split(",")]
    jedna, s = zapek(col, nrm, ao, args.S)
    vystup = Path(args.vystup)
    data = zapis_sadu(jedna, ids, vystup)
    # `zdroj` se dopise az tady: u rozbaleneho ZIPu patri do manifestu ARCHIV
    # (uzivateluv original), ne cesta do `.cache/`.
    man_cesta = vystup / "manifest.json"
    man = json.loads(man_cesta.read_text(encoding="utf-8"))
    man["zdroj"] = "%s: %s" % (jmeno, puvod.as_posix())
    man_cesta.write_text(json.dumps(man, indent=1, ensure_ascii=False), encoding="utf-8")
    print("[pbr] %s: S=%.0f -> %s, id %s, atlas %s"
          % (jmeno, s, vystup.as_posix(), ids, hash_bajtu(data)[:16]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
