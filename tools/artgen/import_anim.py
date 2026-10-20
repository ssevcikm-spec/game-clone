#!/usr/bin/env python3
"""IMPORT animovane sady od producenta (`_tools/tovarna/animace`) do formatu hry.

CO TO DELA (a proc)
-------------------
Producent (paralelni session v `dsh-dev\\_tools\\tovarna\\animace`) vyrabi animovane
sprity postav ve VLASTNIM formatu: `manifest.json` + `frames/d<dir>_f<frame>.png`,
jedno platno na smer, kotva jako souradnice v platne. Hra (`render/anim_player.gd`)
cte JINY format: `anim-sheets.json` + jeden pruh PNG na smer, klic `telo/skupina/smer`,
frame s `rect`/`cx`/`cy`/`w`/`h` a kresli `anchor = (cx, cy + h)`.

Tenhle skript je ten jediny prevod. Nic v hre nemeni, jen pise soubory:
`assets/own-anim/<sada>/anim-sheets.json` + `<sada>-<telo>-<skupina>-<smer>.png`.
Zapojeni do hry je JINA vec (jedna vrstva v `assets/own-art.json`) a tady se
NEDELA - viz HANDOFF a `docs/04` §4.6.9.

MAPOVANI SMERU (proc zrovna takhle)
-----------------------------------
Producent rendruje `N` smeru po `360/N` stupnich, kamera na azimutu
`azimut_zacatek_deg (45) + krok*d`. Jeho vlastni namerena tabulka
(`animace/ZJISTENI-ANIMACE.md` §10) rika, ze u 4 smeru se `d0` diva
**dolu-vlevo**; to je stejne, jako kdyz se uhel na obrazovce pocita
`uhel(d) = 45 - krok*d + 90*posun_smeru` (kruh, pocitano po smeru hodinovych
rucicek od vychodu; `posun_smeru` je deklarovana odchylka modelu po 90 st.).
Tabulka nize to overuje PIXELOVE (zrcadlove dvojice, `--overit-zrcadla`).

Zrcadlove dvojice na obrazovce: zrcadleni mapuje uhel `a -> 180 - a`. Pro 4 smery
s fazi 225 st. to jsou dvojice (d0,d3) a (d1,d2) - NAMERENO na obou realnych
sadach (IoU masky 0,996 / 0,994 po posunu o pul cyklu; ostatni dvojice 0,53-0,67).
Tim je faze prstence dana `mod 180`; zbylých 180 st. bere skript z `posun_smeru`.

Herni strana je odvozena ze ZDROJU, ne opsana: `DIR_MAP` z `render/anim_player.gd`
a `DIR_DX`/`DIR_DY` z `core/const.gd`; projekce `screen = ((x-y), (x+y))`
(`core/iso.gd`, ISO_STEP se krati). Z toho vyjde, pod jakym uhlem na obrazovce
se ktery svetovy smer kresli, a ktery sprite smer (= `DIR_MAP`) ho obsluhuje.

DULEZITE (namEReno, ne odhad): 4-směrná sada pokryje jen sprite smery 1 a 3
(viz `--sada` vystup: `kryto`). Hrdina hry potrebuje vsech 5 (0..4), takze
4-směrná sada hrdinu NAHRADIT NEMUZE - skript to vypise a skonci kodem 2
(`--pro-hrdinu` to povyší na vadu, kod 1).

POUZITI
-------
    python tools/artgen/import_anim.py "<sada>/<anim>" --nazev rodina-walk
    python tools/artgen/import_anim.py "<sada>/<anim>" --akce attack --vystup .tmp/x
    python tools/artgen/import_anim.py --overit-zrcadla "<sada>/<anim>"

NAVRATOVE KODY (docs/08 §8.9)
    0 = import OK a pokryto vsech 5 sprite smeru (hrdinu lze nahradit)
    1 = VADA vstupu (nic se nezapisuje) - nebo 4 smery s `--pro-hrdinu`
    2 = import OK, ale NECIPLNY (pokryto mene nez 5 smeru; hrdinu nahradit nelze)
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

from PIL import Image  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
ANIM_PLAYER = ROOT / "render" / "anim_player.gd"
CONST_GD = ROOT / "core" / "const.gd"
UO_MANIFEST = ROOT / "assets" / "uo" / "anim" / "anim-sheets.json"
VYSTUP_VYCHOZI = ROOT / "assets" / "own-anim"

# Smer na obrazovce pro herni sprite smery 0..4 (overeno nize proti DIR_MAP).
# 0 = celni (svet SE/dir 7) ... 4 = zadni (svet NW/dir 3); viz `render/anim_player.gd`.
SMERU_HRY = 5


# ---------------------------------------------------------------- zdroje ----
def _cist(cesta: Path) -> str:
    return cesta.read_text(encoding="utf-8", errors="replace")


def nacti_dir_map(cesta: Path = ANIM_PLAYER) -> list[tuple[int, bool]]:
    """`DIR_MAP` z anim_player.gd: smer hry 0..7 -> [sprite smer, zrcadlit].

    Cte se ze ZDROJE (ne opisuje), aby se dve kopie tabulky nemohly rozejit.
    Kdyz se tabulka neda precist, je to VADA - ticha nahrada by vyrobila
    animaci, ktera se diva jinam, nez se hybe.
    """
    text = _cist(cesta)
    m = re.search(r"const\s+DIR_MAP\s*:?=\s*\[(.*?)\]\s*\n", text, re.S)
    if not m:
        raise SystemExit(f"VADA: v {cesta} se nenasel 'const DIR_MAP'")
    dvojice = re.findall(r"\[\s*(\d+)\s*,\s*(true|false)\s*\]", m.group(1))
    if len(dvojice) != 8:
        raise SystemExit(f"VADA: DIR_MAP ma {len(dvojice)} smeru, cekam 8 ({cesta})")
    return [(int(a), b == "true") for a, b in dvojice]


def nacti_smerove_vektory(cesta: Path = CONST_GD) -> list[tuple[int, int]]:
    """`DIR_DX`/`DIR_DY` z const.gd: svetovy vektor smeru hry 0..7."""
    text = _cist(cesta)
    out = []
    for jmeno in ("DIR_DX", "DIR_DY"):
        m = re.search(rf"const\s+{jmeno}\s*:?=\s*\[([^\]]*)\]", text)
        if not m:
            raise SystemExit(f"VADA: v {cesta} se nenasel 'const {jmeno}'")
        out.append([int(x) for x in m.group(1).split(",") if x.strip()])
    if not (len(out[0]) == 8 and len(out[1]) == 8):
        raise SystemExit(f"VADA: DIR_DX/DIR_DY nemaji 8 slozek ({len(out[0])}/{len(out[1])})")
    return list(zip(out[0], out[1]))


def uhel_svetoveho_smeru(dx: int, dy: int) -> float:
    """Uhel svetoveho smeru NA OBRAZOVCE ve stupnich (0 = vpravo, 90 = nahoru).

    Projekce hry (`core/iso.gd`): `screen.x = (x-y)*ISO_STEP`,
    `screen.y = (x+y)*ISO_STEP - z*Z_SCALE`. ISO_STEP se krati. Osa `y`
    obrazovky jde v Godotu DOLU, proto znamenko u `sin`.
    """
    sx = dx - dy
    sy = dx + dy
    return math.degrees(math.atan2(-sy, sx)) % 360.0


def tabulka_smeru() -> dict:
    """Co je v kodu hry: uhel obrazovky -> (sprite smer, zrcadlit).

    Cesty se predavaji VYSLOVNE: vychozi hodnota argumentu se vyhodnocuje pri
    importu modulu, takze `--root` by se do ni nepropsal (chytila to mutace
    brany - kopie konvertoru hledala zdroje pod sebou).
    """
    dir_map = nacti_dir_map(ANIM_PLAYER)
    vektory = nacti_smerove_vektory(CONST_GD)
    if len(dir_map) != len(vektory):
        raise SystemExit("VADA: DIR_MAP a DIR_DX/DIR_DY maji ruznou delku")
    polozky = []
    for w, ((dx, dy), (sprite, mirror)) in enumerate(zip(vektory, dir_map)):
        polozky.append({"svet": w, "uhel": uhel_svetoveho_smeru(dx, dy),
                        "sprite": sprite, "zrcadlit": mirror})
    return {"polozky": polozky}


def sprite_pro_uhel(uhel: float, tabulka: dict) -> tuple[int, bool]:
    """Nejblizsi svetovy smer -> (sprite smer, zrcadlit). Vzdalenost <= 22,5 st."""
    nej = None
    for p in tabulka["polozky"]:
        rozdil = abs((p["uhel"] - uhel + 180.0) % 360.0 - 180.0)
        if nej is None or rozdil < nej[0]:
            nej = (rozdil, p)
    if nej is None or nej[0] > 22.5 + 1e-6:
        raise SystemExit(f"VADA: uhel {uhel:.1f} st. nesedi na zadny smer hry")
    return int(nej[1]["sprite"]), bool(nej[1]["zrcadlit"])


def uhel_producenta(d: int, n: int, posun_smeru: int) -> float:
    """Uhel, pod kterym se producentuv smer `d` kresli na obrazovce.

    Odvozeno z merene tabulky (ZJISTENI-ANIMACE §10): pri 4 smerech a
    `posun_smeru = 2` se `d0` diva dolu-vlevo (225 st.), takze
    `uhel = 45 - krok*d + 90*posun_smeru`.
    """
    krok = 360.0 / float(n)
    return (45.0 - krok * d + 90.0 * posun_smeru) % 360.0


def skupiny_z_uo(telo: int) -> dict:
    """Cisla skupin `anim.mul` pro telo z exportu UO (jen ke cteni).

    `assets/uo/` je v .gitignore, takze v cerstvem klonu chybi. Kdyz chybi,
    vrati se prazdny slovnik a cisla se berou z `zalozni_skupiny()` -
    a je to VIDET ve vystupu (`groups_zdroj`).
    """
    if not UO_MANIFEST.exists():
        return {}
    try:
        data = json.loads(_cist(UO_MANIFEST))
    except json.JSONDecodeError:
        return {}
    mapa = (data.get("groups") or {}).get(str(telo))
    return dict(mapa) if isinstance(mapa, dict) else {}


def zalozni_skupiny(telo: int) -> dict:
    """Nouzova cisla, kdyz export UO neni k dispozici.

    Pro telo 400 (clovek) plati `PeopleAnimationGroup`: 0 = walk, 4 = idle,
    9 = attack, 21 = die (ClassicUO `AnimationsLoader.cs:1721`, viz hlavicka
    `render/anim_player.gd`). Pro jina tela se cisla NEHADA - viz `main()`.
    """
    if telo == 400:
        return {"walk": 0, "idle": 4, "attack": 9, "die": 21}
    return {}


# ---------------------------------------------------------------- vstup -----
def nacti_sadu(sada: Path) -> dict:
    """Precte a ZKONTROLUJE producentskou sadu; pri vade skonci kodem 1."""
    manifest_cesta = sada / "manifest.json"
    if not manifest_cesta.exists():
        raise Vada(f"v {sada} neni manifest.json")
    try:
        m = json.loads(_cist(manifest_cesta))
    except json.JSONDecodeError as exc:
        raise Vada(f"manifest.json se necte: {exc}") from exc
    chyby = []
    for klic in ("framu", "smery", "platna", "kotvy", "frame_ms"):
        if klic not in m:
            chyby.append(f"manifest nema '{klic}'")
    if chyby:
        raise Vada("; ".join(chyby))
    framu = int(m["framu"])
    smery = [int(d) for d in m["smery"]]
    if framu < 1:
        raise Vada(f"framu={framu} (cekam >= 1)")
    if not smery:
        raise Vada("smery je prazdny seznam")
    if smery != sorted(smery) or smery != list(range(len(smery))):
        raise Vada(f"smery={smery} - cekam 0..{len(smery) - 1} (klic 'd<cislo>')")
    slozka = sada / "frames"
    if not slozka.is_dir():
        raise Vada(f"v {sada} neni slozka frames/")
    platna, kotvy, obrazky = {}, {}, {}
    for d in smery:
        if f"d{d}" not in m["platna"] or f"d{d}" not in m["kotvy"]:
            raise Vada(f"manifest nema 'platna.d{d}' nebo 'kotvy.d{d}'")
        w, h = (int(round(float(v))) for v in m["platna"][f"d{d}"])
        if w < 1 or h < 1:
            raise Vada(f"platna.d{d} = {w}x{h} (cekam kladne)")
        platna[d] = (w, h)
        kx, ky = (float(v) for v in m["kotvy"][f"d{d}"])
        if not (0.0 < kx < w):
            raise Vada(f"kotvy.d{d} x={kx} neni uvnitr platna 0..{w}")
        if not (0.0 < ky <= h):
            raise Vada(f"kotvy.d{d} y={ky} neni uvnitr platna 0..{h}")
        obrazky[d] = []
        for f in range(framu):
            cesta = slozka / f"d{d}_f{f}.png"
            if not cesta.exists():
                raise Vada(f"chybi frame {cesta.name}")
            im = Image.open(cesta).convert("RGBA")
            if im.size != (w, h):
                raise Vada(f"{cesta.name} ma {im.size[0]}x{im.size[1]}, "
                           f"manifest plati {w}x{h} - jedno platno na smer")
            if im.getchannel("A").getbbox() is None:
                raise Vada(f"{cesta.name} je prazdny (zadny pixel)")
            obrazky[d].append(im)
        kotvy[d] = (kx, ky)
    if len(set(platna.values())) > 1:
        # Ruzna platna mezi smery = postava pri otoceni poskoci. Hra to unese
        # (kotva je per frame), ale je to vada dat - hlasime ji.
        raise Vada(f"platna se lisi mezi smery: {platna}")
    return {"manifest": m, "framu": framu, "smery": smery, "platna": platna,
            "kotvy": kotvy, "obrazky": obrazky,
            "posun_smeru": int(m.get("posun_smeru", 0) or 0),
            "frame_ms": int(m["frame_ms"])}


class Vada(Exception):
    """Vada vstupu - skript konci kodem 1 a nic nezapise."""


# ---------------------------------------------------------------- prevod ----
def naplanuj(sada: dict, tabulka: dict, konvence: str) -> dict:
    """Ktery producentuv smer plni ktery herni sprite smer (a ktere jsou navic)."""
    n = len(sada["smery"])
    posun = sada["posun_smeru"]
    plan: dict[int, dict] = {}
    navic = []
    for d in sada["smery"]:
        if konvence == "uo5":
            # 5 smeru = primo mrizka UO (0..4). Je to DEKLAROVANA konvence,
            # ne odvozena - proto se zapisuje do vystupu.
            sprite, mirror = (d, False) if d < SMERU_HRY else (d % SMERU_HRY, True)
        else:
            uhel = uhel_producenta(d, n, posun)
            sprite, mirror = sprite_pro_uhel(uhel, tabulka)
        if sprite in plan:
            # Druhy smer na stejny sprite = zrcadlova varianta. Hra si zrcadli
            # sama (`DIR_MAP`), takze se do vystupu bere NAPRED nezrcadleny.
            if plan[sprite]["zrcadleno"] and not mirror:
                navic.append({"smer": plan[sprite]["smer"], "sprite": sprite,
                              "duvod": "zrcadlova varianta, nahrazena nezrcadlenou"})
                plan[sprite] = {"smer": d, "zrcadleno": mirror,
                                "uhel": uhel_producenta(d, n, posun)}
            else:
                navic.append({"smer": d, "sprite": sprite,
                              "duvod": "zrcadlova varianta" if mirror else "duplicitni smer"})
            continue
        plan[sprite] = {"smer": d, "zrcadleno": mirror,
                        "uhel": uhel_producenta(d, n, posun)}
    return {"plan": plan, "navic": navic, "konvence": konvence}


def zapis(sada: dict, plan: dict, tabulka: dict, args, vystup: Path) -> dict:
    """Zapise pruhy PNG a `anim-sheets.json` ve formatu hry."""
    vystup.mkdir(parents=True, exist_ok=True)
    telo = args.telo
    akce = args.akce
    skupiny = skupiny_z_uo(telo) or zalozni_skupiny(telo)
    zdroj_skupin = "assets/uo/anim/anim-sheets.json" if skupiny_z_uo(telo) else "zalozni_tabulka"
    if akce not in skupiny:
        # `work` v `anim.mul` pro lidi neexistuje (hra ji resi fallbackem -
        # `GROUP_FALLBACK` v anim_player.gd). Cislo musi byt volne, aby si hra
        # nepletla dve animace; bere se prvni volne >= 5.
        volna = [c for c in range(5, 64) if c not in set(skupiny.values())]
        if not volna:
            raise Vada(f"pro telo {telo} neni volne cislo skupiny pro '{akce}'")
        skupiny = dict(skupiny)
        skupiny[akce] = volna[0]
        zdroj_skupin += f" + volne cislo {volna[0]} pro '{akce}'"
    cislo_skupiny = int(skupiny[akce])

    sprites: dict[str, dict] = {}
    for sprite in sorted(plan["plan"]):
        d = plan["plan"][sprite]["smer"]
        w, h = sada["platna"][d]
        kx, ky = sada["kotvy"][d]
        pruh = Image.new("RGBA", (w * sada["framu"], h), (0, 0, 0, 0))
        framy = []
        for f, im in enumerate(sada["obrazky"][d]):
            pruh.alpha_composite(im, (f * w, 0))
            framy.append({
                "rect": [f * w, 0, f * w + w, h],
                "cx": round(kx, 2),
                "cy": round(ky - h, 2),     # hra kresli anchor = (cx, cy + h)
                "w": int(w), "h": int(h),
            })
        jmeno = f"{args.nazev}-{telo}-{cislo_skupiny}-{sprite}.png"
        pruh.save(vystup / jmeno)
        sprites[f"{telo}/{cislo_skupiny}/{sprite}"] = {
            "action": akce, "file": jmeno, "frames": framy,
            "source": f"producent:{args.nazev}",
        }

    kryto = sorted(plan["plan"])
    # `frame_ms`: producent ma 84/42 ms, hra 80 ms (`Const.TURN_MS`,
    # docs/05 §5.1.1) a `frame_ms(action)` je konstanta - data ji ZATIM
    # nectou. Zapise se to, aby to bylo videt a dalo se to zapnout.
    cyklus = sada["framu"] * sada["frame_ms"]
    vystup_data = {
        "version": 1,
        "decoder": "tools/artgen/import_anim.py (import producentske sady "
                   f"'{args.nazev}'; smlouva {sada['manifest'].get('smlouva', '?')})",
        "anchor": "obrazek se kresli na (tile_x - cx, tile_y - (cy + h)); "
                  "cy = kotva_y - h, takze (cx, cy+h) je producentova kotva",
        "actions": {str(cislo_skupiny): akce},
        "groups": {str(telo): {akce: cislo_skupiny}},
        "groups_zdroj": zdroj_skupin,
        "sprites": sprites,
        "chyby": [],
        "import": {
            "sada": args.nazev,
            "zdroj": str(sada["manifest"].get("zdroj_raw", "")),
            "akce": akce,
            "telo": telo,
            "skupina": cislo_skupiny,
            "framu": sada["framu"],
            "smery_vstup": len(sada["smery"]),
            "kryto_sprite_smeru": kryto,
            "chybi_sprite_smeru": [s for s in range(SMERU_HRY) if s not in kryto],
            "konvence_smeru": plan["konvence"],
            "posun_smeru": sada["posun_smeru"],
            "tabulka_smeru": [
                {"sprite": s, "producent_smer": p["smer"], "uhel": p["uhel"],
                 "zrcadleno": p["zrcadleno"]} for s, p in sorted(plan["plan"].items())
            ],
            "smery_navic": plan["navic"],
            "platno": {"w": sada["platna"][sada["smery"][0]][0],
                       "h": sada["platna"][sada["smery"][0]][1]},
            "kotva": {"x": sada["kotvy"][sada["smery"][0]][0],
                      "y": sada["kotvy"][sada["smery"][0]][1]},
            "frame_ms": sada["frame_ms"],
            "frame_ms_hra": 80,
            "cyklus_ms": cyklus,
            "cyklus_ms_hra": sada["framu"] * 80,
            "casovani": "hra ma `frame_ms(action) = Const.TURN_MS (80 ms)` jako "
                        f"konstantu; sada ma {sada['frame_ms']} ms/frame, takze "
                        f"cyklus {cyklus} ms se prehraje za {sada['framu'] * 80} ms. "
                        "Zapnuti skutecneho frame_ms je zmena hry (data-driven "
                        "casovani), ne importu.",
        },
    }
    (vystup / "anim-sheets.json").write_text(
        json.dumps(vystup_data, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    return vystup_data


# ------------------------------------------------- overeni zrcadlovych paru --
def over_zrcadla(sada: dict) -> list[tuple[int, int, float, bool]]:
    """Zrcadlove dvojice s posunem o pul cyklu - meri FAZI prstence smeru.

    Zrcadleni postavy vymeni levou a pravou nohu, takze zrcadlo framu `f`
    odpovida framu `f + N/2`. Bez toho posunu vyjde nejvyssi IoU na spatne
    dvojici (NAMERENO: 0,71 vs 0,996) - proto se posun dela.
    """
    import numpy as np

    n = len(sada["smery"])
    framu = sada["framu"]
    masky = {}
    for d in sada["smery"]:
        for f, im in enumerate(sada["obrazky"][d]):
            masky[(d, f)] = np.asarray(im)[:, :, 3] > 8
    vysledky = []
    for i in range(n):
        for j in range(i + 1, n):
            hodnoty = []
            for f in range(framu):
                a = masky[(i, f)]
                b = np.fliplr(masky[(j, (f + framu // 2) % framu)])
                sjed = np.logical_or(a, b).sum()
                if sjed:
                    hodnoty.append(float(np.logical_and(a, b).sum() / sjed))
            prumer = sum(hodnoty) / len(hodnoty) if hodnoty else float("nan")
            ocekavano = abs(((uhel_producenta(i, n, sada["posun_smeru"])
                              + uhel_producenta(j, n, sada["posun_smeru"]))) % 360.0
                            - 180.0) < 1.0
            vysledky.append((i, j, prumer, ocekavano))
    return vysledky


# ------------------------------------------------------------------ main ----
def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description="Import animovane sady od producenta do formatu hry "
                    "(assets/own-anim/<sada>/anim-sheets.json + pruhy PNG)")
    ap.add_argument("sada", type=Path, help="adresar sady producenta (manifest.json + frames/)")
    ap.add_argument("--nazev", default=None, help="jmeno sady ve vystupu (vychozi: nazev adresare)")
    ap.add_argument("--telo", type=int, default=400, help="cislo tela hry (vychozi 400 = hrdina)")
    ap.add_argument("--akce", default="walk", choices=["walk", "attack", "work"],
                    help="herni akce (vychozi walk)")
    ap.add_argument("--vystup", type=Path, default=None,
                    help="kam zapsat (vychozi assets/own-anim/<nazev>)")
    ap.add_argument("--konvence", default="auto", choices=["auto", "ring", "uo5"],
                    help="vyklad smeru: ring = prstenec 360/N, uo5 = 5 smeru je primo "
                         "mrizka UO (auto: 5 -> uo5, jinak ring)")
    ap.add_argument("--pro-hrdinu", action="store_true",
                    help="vyzaduj pokryti vsech 5 sprite smeru (jinak kod 2, s timto kodem 1)")
    ap.add_argument("--overit-zrcadla", action="store_true",
                    help="jen zmer zrcadlove dvojice smeru (faze prstence) a skonci")
    ap.add_argument("--json", action="store_true", help="vypis strojovy souhrn na konec")
    ap.add_argument("--root", type=Path, default=None,
                    help="koren projektu (vychozi: odvozeny z cesty tohoto skriptu). "
                         "Pouziva brana, kdyz pousti KOPII konvertoru z jineho adresare - "
                         "kopie by jinak hledala zdroje hry pod sebou a spadla by z jineho "
                         "duvodu, nez je sabotaz (namEReno pri psani mutaci).")
    args = ap.parse_args(argv)

    # Cesty ke zdrojum hry. `--root` je tu kvuli mutacnim kopiim konvertoru.
    if args.root is not None:
        global ANIM_PLAYER, CONST_GD, UO_MANIFEST, VYSTUP_VYCHOZI
        koren = args.root if args.root.is_absolute() else (Path.cwd() / args.root)
        ANIM_PLAYER = koren / "render" / "anim_player.gd"
        CONST_GD = koren / "core" / "const.gd"
        UO_MANIFEST = koren / "assets" / "uo" / "anim" / "anim-sheets.json"
        VYSTUP_VYCHOZI = koren / "assets" / "own-anim"

    sada_cesta = args.sada if args.sada.is_absolute() else (Path.cwd() / args.sada)
    if not sada_cesta.is_dir():
        print(f"VADA: {sada_cesta} neni adresar")
        return 1
    # Vychozi jmeno = jmeno SADY (adresar nad animaci: `rodina_walk/walk` -> `rodina_walk`).
    nazev = args.nazev
    if nazev is None:
        nazev = sada_cesta.parent.name or sada_cesta.name
    args.nazev = re.sub(r"[^A-Za-z0-9._-]+", "-", nazev)

    try:
        sada = nacti_sadu(sada_cesta)
        tabulka = tabulka_smeru()
        if args.overit_zrcadla:
            print(f"[import] zrcadlove dvojice ({args.nazev}, {len(sada['smery'])} smeru, "
                  f"posun_smeru={sada['posun_smeru']}):")
            spatne = 0
            for i, j, iou, ocekavano in over_zrcadla(sada):
                stav = "OK" if (iou >= 0.85) == ocekavano else "CHYBA"
                spatne += 0 if stav == "OK" else 1
                print(f"[import]   d{i}~zrc(d{j}): IoU={iou:.3f} "
                      f"ocekavano_dvojice={'ano' if ocekavano else 'ne'} {stav}")
            return 0 if spatne == 0 else 1
        konvence = args.konvence
        if konvence == "auto":
            konvence = "uo5" if len(sada["smery"]) == SMERU_HRY else "ring"
        plan = naplanuj(sada, tabulka, konvence)
        vystup = args.vystup or (VYSTUP_VYCHOZI / args.nazev)
        data = zapis(sada, plan, tabulka, args, vystup)
    except Vada as exc:
        print(f"VADA: {exc}")
        return 1

    imp = data["import"]
    kryto = imp["kryto_sprite_smeru"]
    chybi = imp["chybi_sprite_smeru"]
    print(f"[import] {args.nazev}: {imp['framu']} framu x {imp['smery_vstup']} smeru -> "
          f"{len(kryto)} sprite smeru {kryto} (chybi {chybi})")
    print(f"[import]   vystup: {vystup} (akce {imp['akce']}, skupina {imp['skupina']}, "
          f"platno {imp['platno']['w']}x{imp['platno']['h']}, kotva {imp['kotva']})")
    for pol in imp["tabulka_smeru"]:
        print(f"[import]   sprite {pol['sprite']} <- producentsky d{pol['producent_smer']} "
              f"(uhel {pol['uhel']:.0f} st.{', zrcadleno' if pol['zrcadleno'] else ''})")
    for nav in imp["smery_navic"]:
        print(f"[import]   smer d{nav['smer']} nepouzit: {nav['duvod']}")
    print(f"[import]   casovani: {imp['frame_ms']} ms/frame (cyklus {imp['cyklus_ms']} ms) "
          f"vs. hra 80 ms/frame (cyklus {imp['cyklus_ms_hra']} ms)")
    if args.json:
        print(json.dumps({"kryto": kryto, "chybi": chybi, "vystup": str(vystup),
                          "skupina": imp["skupina"], "framu": imp["framu"],
                          "smery_vstup": imp["smery_vstup"]}, ensure_ascii=False))
    if chybi:
        print(f"[import] NECIPLNE: sada pokryva {len(kryto)}/5 sprite smeru - HRDINU "
              f"NAHRADIT NEMUZE (chybi sprite smery {chybi}; hra je 8smerna a potrebuje "
              f"0..4). Dodej 8 smeru po 45 st. (nebo 5 smeru na uhlech 270/225/180/135/90).")
        if args.pro_hrdinu:
            print("[import] --pro-hrdinu: neciplna sada je VADA (kod 1)")
            return 1
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
