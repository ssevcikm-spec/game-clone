#!/usr/bin/env python3
"""BRANA IMPORTU ANIMACI (`check-anim-assets.py`) - overuje konvertor
`tools/artgen/import_anim.py` na FIXTURACH a na REALNYCH datech producenta.

Proc tahle brana existuje
-------------------------
Konvertor je jedine misto, kde se producentsky format (`manifest.json` + `frames/`)
prevadi na format hry (`anim-sheets.json` + pruh PNG). Kdyz se v nem rozbije
kotva, `rect` nebo mapovani smeru, hra nakresli postavu o pixel jinam nebo
otomcenou - a NIC jineho to nezahlasi. Brana proto meri VYSTUP konvertoru, ne
jeho kod: pusti ho na syntetickych sadach se ZNAMYMI barvami a na realnych
sadach producenta a vysledek meri pixelove i geometricky.

CO MERI (a proc zrovna takhle)
------------------------------
  * pocet framu a smeru na vystupu (a ze kazdy frame ma svuj `rect`),
  * stejne platno ve smeru (`rect[2]-rect[0] == w`, `rect[3]-rect[1] == h`,
    `rect[0] == frame*w`) a stejna vyska vsech framu pruhu,
  * kotva: `cx` uvnitr platna, `cy + h` uvnitr platna, `cx` symetricka
    (`|cx - w/2| <= 0.5`) a PRESNE rovna kotve z producentskeho manifestu,
  * zadny prazdny frame (kreslila by se dira),
  * mapovani smeru 8 -> 5: kazdy producentuv smer ma v fixture VLASTNI BARVU,
    takze se da pixelove overit, KTERY smer skoncil v kterem sprite smeru;
    ocekavana tabulka je v `OCEKAVANE_MAPOVANI_8` jako LITERAL (ne prepocet
    z mereneho souboru - jinak by fixtura merila soubor sam proti sobe),
  * 4-směrná sada: konvertor ji pro hrdinu ODMITNE (kod 2, s `--pro-hrdinu`
    kod 1) a v textu je, ze hrdinu nahradit nelze,
  * realna data: zrcadlove dvojice smeru (posun o pul cyklu) - overuje FAZI
    prstence smeru, na ktere stoji cele mapovani.

TRI STAVY (docs/08 §8.9): 0 = mereno a OK, 1 = VADA, 2 = NEMERENO.
Nula zmerenych veci NENI uspech - brana to hodi jako vadu.

POUZITI
-------
    python tools/gates/check-anim-assets.py                  # mereni
    python tools/gates/check-anim-assets.py --self-test      # znamy dobry i vadny vstup
    python tools/gates/check-anim-assets.py --mutace         # sabotaze konvertoru
    python tools/gates/check-anim-assets.py --konvertor <cesta>   # jiny konvertor (mutace)

Brana NENI v `run-all.py`: nema jeste herni data (sada pro hrdinu ma 2 z 5
smeru), takze by v sérii hlásila NEMĚŘENO. Az producent doda 5/8 smeru,
prihlaseni je jeden radek v `tools/gates/run-all.py` - viz HANDOFF.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, OUT_DIR, ROOT, VADA, Gate  # noqa: E402

NAME = "check-anim-assets"
KONVERTOR = Path(__file__).resolve().parents[1] / "artgen" / "import_anim.py"
PRACOVNI = OUT_DIR / "anim-assets"
PRODUCENT = Path(r"E:\Workspaces\dsh-dev\_tools\tovarna\animace\vystup\hra")

# OCEKAVANE MAPOVANI pro 8 smeru a `posun_smeru = 2` (faze prstence 225 st.).
# LITERAL, ne prepocet: kdyby si brana tabulku pocitala ze stejneho vzorce
# jako konvertor, vysla by shoda i s vadenym vzorcem (LESSONS: fixtura nesmi
# cist ocekavani ze sebe sama). Odvozeni: uhel(d) = 45 - 225... viz
# `import_anim.uhel_producenta`; overeno pixelove na techto fixturach.
OCEKAVANE_MAPOVANI_8 = {0: 7, 1: 0, 2: 1, 3: 2, 4: 3}   # sprite -> producentuv smer
OCEKAVANE_MAPOVANI_4 = {1: 0, 3: 1}                      # sprite -> producentuv smer
# Zrcadlove dvojice (posun o pul cyklu) pro 4 smery a fazi 225 st.
OCEKAVANE_ZRCADLA_4 = [(0, 3), (1, 2)]

BARVA = (255, 0, 0, 255)          # barva bloku, ktery nese kazdy frame
BLOK = 3                          # velikost bloku v px


# --------------------------------------------------------------- fixtury ----
def _barva_smeru(d: int) -> tuple[int, int, int, int]:
    """Jednoznacna barva pro producentuv smer (0..7)."""
    return (30 + 25 * d, 60, 200 - 25 * d, 255)


def _zapis_sadu(cesta: Path, *, smery: int, framu: int, w: int, h: int,
                kotva: tuple[float, float], posun: int, vada: str | None = None,
                platna_po_smerech: bool = False) -> Path:
    """Synteticka producentska sada: barva smeru + blok na pevnem miste."""
    from PIL import Image

    if cesta.exists():
        shutil.rmtree(cesta)
    (cesta / "frames").mkdir(parents=True)
    platna, kotvy = {}, {}
    for d in range(smery):
        ww, hh = (w, h)
        if platna_po_smerech and d % 2 == 1:
            ww, hh = w + 2, h + 1          # vada: jine platno u licheho smeru
        platna[f"d{d}"] = [ww, hh]
        kotvy[f"d{d}"] = [kotva[0], kotva[1]]
        for f in range(framu):
            if vada == "chybi_frame" and d == 1 and f == framu - 1:
                continue                    # vada: chybejici frame
            im = Image.new("RGBA", (ww, hh), (0, 0, 0, 0))
            for y in range(BLOK):
                for x in range(BLOK):
                    im.putpixel((2 + x, 2 + y), _barva_smeru(d))
            if vada == "prazdny" and d == 1 and f == 0:
                im = Image.new("RGBA", (ww, hh), (0, 0, 0, 0))   # vada: prazdny frame
            im.save(cesta / "frames" / f"d{d}_f{f}.png")
    if vada == "kotva":
        kotvy["d0"] = [w + 3.5, kotva[1]]   # vada: kotva mimo platno
    manifest = {
        "sada": cesta.name, "animace": "walk", "framu": framu,
        "smery": list(range(smery)), "frame_ms": 84, "loop": True,
        "vrstvy": ["body"], "smlouva": "hra-48.json",
        "platna": platna, "kotvy": kotvy, "posun_smeru": posun,
        "c_frame": [w, h], "anchor": [kotva[0], kotva[1]],
    }
    (cesta / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1), encoding="utf-8")
    return cesta


def _pust_konvertor(konvertor: Path, sada: Path, vystup: Path, *dalsi: str) -> tuple[int, str]:
    # `--root` je nutny: kopie konvertoru z jineho adresare by zdroje hry hledala
    # pod sebou a spadla by z jineho duvodu, nez je sabotaz (to by branu tvarilo
    # jako uspesnou - namEReno pri prvnim behu mutaci).
    cmd = [sys.executable, str(konvertor), str(sada), "--vystup", str(vystup),
           "--root", str(ROOT), *dalsi]
    proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                          errors="replace", timeout=300)
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


# ------------------------------------------------------------- mereni -------
def _nacti_vystup(vystup: Path, gate: Gate, popis: str) -> dict | None:
    cesta = vystup / "anim-sheets.json"
    if not cesta.exists():
        gate.error(f"{popis}: vystup nema anim-sheets.json ({cesta})")
        return None
    try:
        return json.loads(cesta.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        gate.error(f"{popis}: anim-sheets.json se necte: {exc}")
        return None


def _zkontroluj_vystup(vystup: Path, data: dict, gate: Gate, popis: str,
                       *ocekavane: int) -> dict:
    """Geometrie vystupu: framy, rect, platno, kotva, prazdne framy."""
    from PIL import Image

    zprava: dict = {}
    sprites = data.get("sprites") or {}
    if not sprites:
        gate.error(f"{popis}: vystup nema zadny sprite (prazdno neni uspech)")
        return zprava
    smery = sorted(int(k.split("/")[2]) for k in sprites)
    zprava["sprite_smery"] = smery
    if ocekavane and list(ocekavane) != smery:
        gate.error(f"{popis}: sprite smery {smery}, cekam {list(ocekavane)}")
    framing = data.get("import") or {}
    kotva = framing.get("kotva") or {}
    if not ("x" in kotva and "y" in kotva):
        gate.error(f"{popis}: vystup nema 'import.kotva'")
        return zprava
    zprava["kotva"] = [kotva["x"], kotva["y"]]
    zprava["framu"] = {}
    for klic, zaznam in sprites.items():
        cesta = vystup / str(zaznam.get("file", ""))
        if not cesta.exists():
            gate.error(f"{popis}: {klic} -> PNG {cesta.name} neexistuje")
            continue
        im = Image.open(cesta).convert("RGBA")
        framy = zaznam.get("frames") or []
        zprava["framu"][klic] = len(framy)
        if not framy:
            gate.error(f"{popis}: {klic} nema zadny frame")
            continue
        w = int(framy[0]["w"])
        h = int(framy[0]["h"])
        if im.size != (w * len(framy), h):
            gate.error(f"{popis}: {klic} PNG {im.size} != ({w * len(framy)}, {h})")
        for i, fr in enumerate(framy):
            if int(fr["w"]) != w or int(fr["h"]) != h:
                gate.error(f"{popis}: {klic} frame {i} ma jine w/h ({fr['w']}x{fr['h']})")
            r = [int(v) for v in fr["rect"]]
            if r != [i * w, 0, i * w + w, h]:
                gate.error(f"{popis}: {klic} frame {i} rect {r} != "
                           f"{[i * w, 0, i * w + w, h]}")
            cx, cy = float(fr["cx"]), float(fr["cy"])
            if abs((cy + h) - float(kotva["y"])) > 0.01:
                gate.error(f"{popis}: {klic} frame {i}: cy+h={cy + h:.2f} != kotva.y "
                           f"{float(kotva['y']):.2f} (kotva se rozjela)")
            if abs(cx - float(kotva["x"])) > 0.01:
                gate.error(f"{popis}: {klic} frame {i}: cx={cx:.2f} != kotva.x "
                           f"{float(kotva['x']):.2f}")
            if not (0.0 < cx < w):
                gate.error(f"{popis}: {klic} frame {i}: cx={cx} mimo platno 0..{w}")
            if not (0.0 < cy + h <= h):
                gate.error(f"{popis}: {klic} frame {i}: kotva y={cy + h} mimo platno 0..{h}")
            if abs(cx - w / 2.0) > 0.5:
                gate.error(f"{popis}: {klic} frame {i}: cx={cx} neni symetricka "
                           f"(w/2={w / 2.0}) - zrcadleny sprite bude uskoceny")
            vyrez = im.crop((i * w, 0, i * w + w, h))
            if vyrez.getchannel("A").getbbox() is None:
                gate.error(f"{popis}: {klic} frame {i} je PRAZDNY (kreslila by se dira)")
    return zprava


def _barva_na(vystup: Path, data: dict, sprite: int, frame: int = 0):
    """Barva bloku ve vystupu - identifikuje, ktery producentuv smer to je."""
    from PIL import Image

    klic = next((k for k in data["sprites"] if k.split("/")[2] == str(sprite)), None)
    if klic is None:
        return None
    zaznam = data["sprites"][klic]
    im = Image.open(vystup / zaznam["file"]).convert("RGBA")
    w = int(zaznam["frames"][frame]["w"])
    return im.getpixel((frame * w + 3, 3))


def _smer_z_barvy(barva) -> int | None:
    for d in range(8):
        if tuple(barva) == _barva_smeru(d):
            return d
    return None


def _zrcadla(sada: Path) -> dict:
    """Zrcadlove dvojice s posunem o pul cyklu (faze prstence smeru)."""
    import numpy as np
    from PIL import Image

    m = json.loads((sada / "manifest.json").read_text(encoding="utf-8"))
    framu = int(m["framu"])
    masky = {}
    for d in m["smery"]:
        for f in range(framu):
            im = Image.open(sada / "frames" / f"d{d}_f{f}.png").convert("RGBA")
            masky[(int(d), f)] = np.asarray(im)[:, :, 3] > 8
    out = {}
    for i in range(len(m["smery"])):
        for j in range(i + 1, len(m["smery"])):
            hodnoty = []
            for f in range(framu):
                a = masky[(i, f)]
                b = np.fliplr(masky[(j, (f + framu // 2) % framu)])
                sjed = np.logical_or(a, b).sum()
                if sjed:
                    hodnoty.append(float(np.logical_and(a, b).sum() / sjed))
            out[(i, j)] = sum(hodnoty) / len(hodnoty) if hodnoty else float("nan")
    return out


# --------------------------------------------------------------- check ------
def check(gate: Gate, konvertor: Path = KONVERTOR, bez_realnych: bool = False) -> None:
    if not konvertor.exists():
        gate.error(f"konvertor {konvertor} neexistuje")
        return
    if PRACOVNI.exists():
        shutil.rmtree(PRACOVNI)
    PRACOVNI.mkdir(parents=True)
    W, H, FRAMU, KOTVA = 12, 20, 4, (6.0, 16.0)

    # ---- 5 smeru: primo mrizka UO -> vsech 5 sprite smeru, zadny fallback ---
    sada = _zapis_sadu(PRACOVNI / "fixtura-5dir", smery=5, framu=FRAMU, w=W, h=H,
                       kotva=KOTVA, posun=0)
    rc, log = _pust_konvertor(konvertor, sada, PRACOVNI / "vystup-5dir")
    gate.measure("fixtura_5dir_exit", rc)
    if rc != OK:
        gate.error(f"fixtura-5dir: konvertor skoncil {rc} (cekam 0)\n{log[-800:]}")
    else:
        data = _nacti_vystup(PRACOVNI / "vystup-5dir", gate, "fixtura-5dir")
        if data:
            z = _zkontroluj_vystup(PRACOVNI / "vystup-5dir", data, gate, "fixtura-5dir", 0, 1, 2, 3, 4)
            for sprite in range(5):
                d = _smer_z_barvy(_barva_na(PRACOVNI / "vystup-5dir", data, sprite) or (0, 0, 0, 0))
                if d != sprite:
                    gate.error(f"fixtura-5dir: sprite {sprite} nese barvu smeru {d} "
                               f"(5 smeru = mrizka UO, ma to byt {sprite})")
            gate.measure("fixtura_5dir_framu", z.get("framu"))

    # ---- 8 smeru: mapovani 8 -> 5 (overuje se BARVOU, ne vzorcem) ----------
    sada = _zapis_sadu(PRACOVNI / "fixtura-8dir", smery=8, framu=FRAMU, w=W, h=H,
                       kotva=KOTVA, posun=2)
    rc, log = _pust_konvertor(konvertor, sada, PRACOVNI / "vystup-8dir")
    gate.measure("fixtura_8dir_exit", rc)
    if rc != OK:
        gate.error(f"fixtura-8dir: konvertor skoncil {rc} (cekam 0)\n{log[-800:]}")
    else:
        data = _nacti_vystup(PRACOVNI / "vystup-8dir", gate, "fixtura-8dir")
        if data:
            z = _zkontroluj_vystup(PRACOVNI / "vystup-8dir", data, gate, "fixtura-8dir", 0, 1, 2, 3, 4)
            for sprite, ocekavany in OCEKAVANE_MAPOVANI_8.items():
                barva = _barva_na(PRACOVNI / "vystup-8dir", data, sprite)
                d = _smer_z_barvy(barva) if barva else None
                if d != ocekavany:
                    gate.error(f"fixtura-8dir: sprite {sprite} ma byt z producentskeho "
                               f"d{ocekavany}, ale nese barvu d{d} - mapovani smeru je jine")
            gate.measure("fixtura_8dir_mapovani", {s: _smer_z_barvy(
                _barva_na(PRACOVNI / "vystup-8dir", data, s) or (0, 0, 0, 0))
                for s in OCEKAVANE_MAPOVANI_8})

    # ---- 4 smery: hrdinu NAHRADIT NELZE -> kod 2, text to rekne ------------
    sada = _zapis_sadu(PRACOVNI / "fixtura-4dir", smery=4, framu=FRAMU, w=W, h=H,
                       kotva=KOTVA, posun=2)
    rc, log = _pust_konvertor(konvertor, sada, PRACOVNI / "vystup-4dir")
    gate.measure("fixtura_4dir_exit", rc)
    if rc != 2:
        gate.error(f"fixtura-4dir: konvertor skoncil {rc} (cekam 2 = neciply import)")
    if "NAHRADIT NEMUZE" not in log:
        gate.error("fixtura-4dir: chybi veta, ze hrdinu NAHRADIT NEMUZE (kod 2 bez "
                   "duvodu je stejne spatny jako 0)")
    data = _nacti_vystup(PRACOVNI / "vystup-4dir", gate, "fixtura-4dir")
    if data:
        z = _zkontroluj_vystup(PRACOVNI / "vystup-4dir", data, gate, "fixtura-4dir", 1, 3)
        for sprite, ocekavany in OCEKAVANE_MAPOVANI_4.items():
            d = _smer_z_barvy(_barva_na(PRACOVNI / "vystup-4dir", data, sprite) or (0, 0, 0, 0))
            if d != ocekavany:
                gate.error(f"fixtura-4dir: sprite {sprite} ma byt z d{ocekavany}, "
                           f"nese barvu d{d}")
        gate.measure("fixtura_4dir_framy", z.get("framu"))
    rc, log = _pust_konvertor(konvertor, sada, PRACOVNI / "vystup-4dir-hrdina", "--pro-hrdinu")
    gate.measure("fixtura_4dir_pro_hrdinu_exit", rc)
    if rc != VADA:
        gate.error(f"fixtura-4dir --pro-hrdinu: konvertor skoncil {rc} (cekam 1) - "
                   f"4-směrnou sadu nesmi poustet pro hrdinu")

    # ---- vadne vstupy: konvertor musi skoncit 1 a rict proc ---------------
    for jmeno, vada, popis in (
        ("vada-kotva", "kotva", "kotva mimo platno"),
        ("vada-prazdny", "prazdny", "prazdny frame"),
        ("vada-chybi-frame", "chybi_frame", "chybejici frame"),
        ("vada-platna", "platna", "ruzne platno mezi smery"),
    ):
        sada = _zapis_sadu(PRACOVNI / jmeno, smery=8, framu=FRAMU, w=W, h=H,
                           kotva=KOTVA, posun=2, vada=vada,
                           platna_po_smerech=(vada == "platna"))
        rc, log = _pust_konvertor(konvertor, sada, PRACOVNI / f"vystup-{jmeno}")
        gate.measure(f"{jmeno}_exit", rc)
        if rc != VADA:
            gate.error(f"{jmeno}: konvertor skoncil {rc} (cekam 1) - vstup '{popis}' "
                       f"proslo bez hlasky")
        elif "VADA" not in log:
            gate.error(f"{jmeno}: konvertor skoncil 1, ale nevypisal 'VADA: ...'")

    # ---- realna data producenta (kopie do .cache, producent jen ke cteni) --
    if bez_realnych:
        gate.note("realna data: preskocena (--bez-realnych)")
    elif not PRODUCENT.is_dir():
        gate.note(f"realna data: {PRODUCENT} neni (producent tu nebezi) - merit jen fixtury")
    else:
        realne = {}
        for sada_jmeno, ocekavane_framu, platno, kryto in (
            ("rodina_walk", 12, (41, 97), (1, 3)),
            ("valecnik_walk", 16, (42, 96), (1, 3)),
        ):
            zdroj = PRODUCENT / sada_jmeno / "walk"
            if not zdroj.is_dir():
                gate.note(f"realna data: {sada_jmeno} na disku neni")
                continue
            kopie = PRACOVNI / "real" / sada_jmeno
            shutil.copytree(zdroj / "frames", kopie / "frames")
            shutil.copy2(zdroj / "manifest.json", kopie / "manifest.json")
            rc, log = _pust_konvertor(konvertor, kopie, PRACOVNI / f"vystup-{sada_jmeno}",
                                      "--nazev", sada_jmeno)
            if rc != 2:
                gate.error(f"realna data {sada_jmeno}: konvertor skoncil {rc} (cekam 2 - "
                           f"4 smery pokryvaji 2 z 5)")
                continue
            data = _nacti_vystup(PRACOVNI / f"vystup-{sada_jmeno}", gate, sada_jmeno)
            if not data:
                continue
            z = _zkontroluj_vystup(PRACOVNI / f"vystup-{sada_jmeno}", data, gate,
                                   sada_jmeno, *kryto)
            m = json.loads((kopie / "manifest.json").read_text(encoding="utf-8"))
            if [int(m["framu"])] != list(set(z.get("framu", {}).values())):
                gate.error(f"{sada_jmeno}: vystup ma framy {z.get('framu')}, manifest "
                           f"{m['framu']}")
            kotva = data["import"]["kotva"]
            if abs(kotva["x"] - float(m["anchor"][0])) > 0.01 or \
                    abs(kotva["y"] - float(m["anchor"][1])) > 0.01:
                gate.error(f"{sada_jmeno}: kotva vystupu {kotva} != producentova "
                           f"{m['anchor']}")
            if tuple(data["import"]["platno"].values()) != platno:
                gate.error(f"{sada_jmeno}: platno {data['import']['platno']} != {platno}")
            # zrcadlove dvojice = faze prstence smeru, na ktere stoji mapovani
            iou = _zrcadla(kopie)
            for (i, j), hodnota in sorted(iou.items()):
                ma_byt = (i, j) in OCEKAVANE_ZRCADLA_4
                je = hodnota >= 0.85
                if ma_byt != je:
                    gate.error(f"{sada_jmeno}: dvojice (d{i},d{j}) IoU={hodnota:.3f}, "
                               f"ocekavano {'zrcadlova' if ma_byt else 'jina'} - faze "
                               f"prstence smeru nesedi s mapovanim")
            realne[sada_jmeno] = {"framy": int(m["framu"]), "platno": list(platno),
                                  "kotva": [float(m["anchor"][0]), float(m["anchor"][1])],
                                  "kryto_sprite": list(kryto),
                                  "zrcadla": {f"{i}-{j}": round(v, 3) for (i, j), v in iou.items()}}
        if realne:
            gate.measure("realna_data", realne)
        else:
            gate.note("realna data: zadna sada se nezkontrolovala")

    if not gate.measured:
        gate.error("brana nic nezmERila")


# ---------------------------------------------------------------- mutace ----
def _zkopiruj_konvertor(cil: Path, zmeny: list[tuple[str, str]]) -> str:
    """Kopie konvertoru s vlozenou vadou; OVERI, ze se vada opravdu zapsala."""
    text = KONVERTOR.read_text(encoding="utf-8")
    for hledat, nahradit in zmeny:
        if hledat not in text:
            return f"v konvertoru neni '{hledat[:60]}'"
        text = text.replace(hledat, nahradit, 1)
    for hledat, nahradit in zmeny:
        if hledat in text or nahradit not in text:
            return f"vada '{hledat[:40]}' se nezapsala"
    cil.parent.mkdir(parents=True, exist_ok=True)
    cil.write_text(text, encoding="utf-8", newline="\n")
    if cil.read_text(encoding="utf-8") == KONVERTOR.read_text(encoding="utf-8"):
        return "kopie konvertoru je shodna s originalem (vada se neprojevila)"
    return ""


MUTACE: list[tuple[str, list[tuple[str, str]]]] = [
    # M1 kotva: `cy` se posune o 1 px -> anchor uz neni producentova kotva.
    ("M1_kotva_posunuta", [(
        '"cy": round(ky - h, 2),',
        '"cy": round(ky - h + 1.0, 2),',
    )]),
    # M2 rect: frame zacina o pixel vedle -> `rect[0] != frame*w`.
    ("M2_rect_posunuty", [(
        '"rect": [f * w, 0, f * w + w, h],',
        '"rect": [f * w + 1, 0, f * w + w + 1, h],',
    )]),
    # M3 mapovani smeru: sprite smer se o jedno otoci -> 8->5 je jine.
    ("M3_mapovani_smeru", [(
        'return int(nej[1]["sprite"]), bool(nej[1]["zrcadlit"])',
        'return (int(nej[1]["sprite"]) + 1) % 5, bool(nej[1]["zrcadlit"])',
    )]),
    # M4 prazdny frame: konvertor prestane prazdny frame odmitat.
    ("M4_prazdny_frame_projde", [(
        'raise Vada(f"{cesta.name} je prazdny (zadny pixel)")',
        'pass',
    )]),
]


def mutace() -> int:
    """Kazda sabotaz konvertoru musi branu shodit (exit 1)."""
    zaklad = OUT_DIR / "anim-assets-mutace"
    if zaklad.exists():
        shutil.rmtree(zaklad)
    chyb = 0
    for jmeno, zmeny in MUTACE:
        kopie = zaklad / jmeno / "import_anim.py"
        problem = _zkopiruj_konvertor(kopie, zmeny)
        if problem:
            print(f"[{NAME}] mutace {jmeno}: CHYBA - {problem}")
            chyb += 1
            continue
        # Sabotaz musi nechat konvertor FUNKCNI, jinak brana spadne z jineho
        # duvodu, nez je vlozena vada (a vypada to jako chycena sabotaz).
        fixtura = _zapis_sadu(zaklad / jmeno / "fixtura", smery=5, framu=4, w=12, h=20,
                              kotva=(6.0, 16.0), posun=0)
        rc0, log0 = _pust_konvertor(kopie, fixtura, zaklad / jmeno / "vystup-zdravy")
        if rc0 != OK:
            print(f"[{NAME}] mutace {jmeno}: CHYBA - sabotovany konvertor nefunguje "
                  f"ani na zdravem vstupu (exit {rc0})\n{log0[-500:]}")
            chyb += 1
            continue
        proc = subprocess.run(
            [sys.executable, str(Path(__file__).resolve()), "--konvertor", str(kopie),
             "--bez-realnych"],
            capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
        (zaklad / jmeno / "brana.log").write_text(proc.stdout, encoding="utf-8")
        spadla = proc.returncode == VADA
        chyb += 0 if spadla else 1
        print(f"[{NAME}] mutace {jmeno}: brana skoncila exit {proc.returncode} "
              f"({'SPRAVNE - VADA' if spadla else 'CHYBA - brana vadu NEVIDI'})")
        for radek in [ln for ln in proc.stdout.splitlines() if "CHYBA:" in ln][:3]:
            print(f"[{NAME}]   {radek.strip()[:150]}")
    print(f"[{NAME}] mutace: {len(MUTACE)} sabotaze, {chyb} chyb")
    return VADA if chyb else OK


# -------------------------------------------------------------- self-test ---
def selftest() -> int:
    """Znamy dobry vstup (fixtury) i znamy vadny (sabotovany konvertor)."""
    chyb = 0
    dobra = Gate(f"{NAME}/selftest:ok")
    check(dobra, KONVERTOR, bez_realnych=True)
    vyslo = dobra.verdict()
    ok = vyslo == OK
    chyb += 0 if ok else 1
    print(f"[{NAME}] self-test dobry konvertor: ocekavano 0, vyslo {vyslo} "
          f"{'OK' if ok else 'CHYBA'}")
    for e in dobra.errors[:5]:
        print(f"[{NAME}]   duvod: {e}")

    kopie = OUT_DIR / "anim-assets-selftest" / "import_anim.py"
    problem = _zkopiruj_konvertor(kopie, MUTACE[2][1])   # M3 mapovani smeru
    if problem:
        print(f"[{NAME}] self-test: CHYBA pri priprave vady - {problem}")
        return VADA
    vadna = Gate(f"{NAME}/selftest:vadny")
    check(vadna, kopie, bez_realnych=True)
    vyslo = vadna.verdict()
    ok = vyslo == VADA
    chyb += 0 if ok else 1
    print(f"[{NAME}] self-test vadny konvertor: ocekavano 1, vyslo {vyslo} "
          f"{'OK' if ok else 'CHYBA'}")
    print(f"[{NAME}] self-test: 2 pripady, {chyb} chyb")
    return VADA if chyb else OK


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Brana importu animaci: overuje tools/artgen/import_anim.py "
                    "na fixturach a na realnych datech producenta")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--konvertor", default=str(KONVERTOR))
    ap.add_argument("--bez-realnych", action="store_true",
                    help="nepouzivej data producenta (mutace, self-test)")
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--mutace", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return selftest()
    if args.mutace:
        return mutace()
    gate = Gate(NAME)
    check(gate, Path(args.konvertor), args.bez_realnych)
    return gate.finish(Path(args.json)) if args.json else gate.finish()


if __name__ == "__main__":
    sys.exit(main())
