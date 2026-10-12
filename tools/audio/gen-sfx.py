#!/usr/bin/env python3
"""gen-sfx - vyrobi zvuky hry a zapise k nim manifest (vsechno vlastni, CC0).

PROC GENEROVANE A NE STAZENE: `ZADANI-27-POCIT.md` §5 rika, ze se smi pouzit
jen volne zvuky (CC0/CC-BY) a NIKDY zvuk z instalace UO. Generovany zvuk je
"volny" bez cizi licence, je **reprodukovatelny** (`--check` da stejne bajty)
a nikdo u nej nemusi dohledavat puvod. Kdyby chtel uzivatel lepsi (nahravany)
zvuk, staci vymenit soubor a v manifestu zmenit `source` - kontrakt (`id` ->
soubor, 44,1 kHz stereo) zustava.

KONTRAKT (docs/04 §4.2, `app/sound.gd`; zmereno v ClassicUO `SoundsLoader.cs:266`):
  * 44 100 Hz, 2 kanaly (stereo), 16 bitu - na tomhle formatu stoji prehravac,
  * kazdy zvuk ma v manifestu `id` (male ASCII), `file`, `popis`, `license`,
    `source`, rozmery a `sha256` (aby se dalo overit, ze soubor je ten, ktery
    manifest popisuje).

Spousteni:
  $env:PYTHONIOENCODING='utf-8'
  python tools/audio/gen-sfx.py            # vyrobi assets/sounds/ + manifest
  python tools/audio/gen-sfx.py --check    # premer: soubory musi sedet s manifestem
"""

from __future__ import annotations

import argparse
import array
import hashlib
import json
import math
import random
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[2]
SADA = ROOT / "assets" / "sounds"
MANIFEST = SADA / "manifest.json"
MIX_RATE = 44100
CHANNELS = 2
BITS = 16
# Strop peaku: -3 dBFS = 0,7079 plne skaly. Zvuky se normalizuji na tuhle
# hodnotu, aby se daly michat (a aby soubor nebyl ticho - "nula neni uspech").
PEAK_CIL = 0.7079


def ozvuk(doba_s: float, frekvence: float, rozpad_s: float, hlasitost: float,
          faze: float = 0.0) -> list[float]:
    """Umiraceny sinus (jedna slozka kovoveho zvuku)."""
    n = int(doba_s * MIX_RATE)
    return [hlasitost * math.sin(2.0 * math.pi * frekvence * (i / MIX_RATE) + faze)
            * math.exp(-(i / MIX_RATE) / rozpad_s) for i in range(n)]


def mix(slozky: list[list[float]], doba_s: float) -> list[float]:
    # POZOR: jmenuje se `mix`, ne `sum` - funkce `sum` je v Pythonu vestavena
    # a prekrytim by spadl `premer()` (nalezeno hned pri prvnim behu).
    n = int(doba_s * MIX_RATE)
    out = [0.0] * n
    for s in slozky:
        for i, v in enumerate(s[:n]):
            out[i] += v
    return out


def sum_noise(doba_s: float, rozpad_s: float, hlasitost: float, seed: int,
              dolnipropust: float = 0.35) -> list[float]:
    """Sirokopasmovy trhlavy sum (dopad, trhani) s jednoduchym dolnim filtrem."""
    rnd = random.Random(seed)
    n = int(doba_s * MIX_RATE)
    out = [0.0] * n
    pred = 0.0
    for i in range(n):
        bily = rnd.uniform(-1.0, 1.0)
        pred = pred + dolnipropust * (bily - pred)      # 1. rad low-pass
        out[i] = hlasitost * pred * math.exp(-(i / MIX_RATE) / rozpad_s)
    return out


def obalka(tvar: list[float], attack_s: float = 0.004) -> list[float]:
    """Attack (aby to nelupalo) + normalizace na PEAK_CIL."""
    n = len(tvar)
    a = max(1, int(attack_s * MIX_RATE))
    for i in range(min(a, n)):
        tvar[i] *= i / a
    vrchol = max((abs(v) for v in tvar), default=0.0)
    if vrchol <= 0.0:
        raise ValueError("zvuk je ticho - generator nema co zapsat")
    return [v * (PEAK_CIL / vrchol) for v in tvar]


# -- jednotlive zvuky ------------------------------------------------------
# `id` je male ASCII (docs/09: hodnota pro program), `popis` je pro cloveka.
def zvuk_hit() -> list[float]:
    # Uder: suchy dopad + kovovy cvaknuti.
    return mix([
        sum_noise(0.16, 0.035, 1.0, seed=11, dolnipropust=0.5),
        ozvuk(0.16, 190.0, 0.045, 0.55),
        ozvuk(0.10, 1650.0, 0.018, 0.30),
        ozvuk(0.10, 2450.0, 0.012, 0.18),
    ], 0.16)


def zvuk_hurt() -> list[float]:
    # Dostaneme zasah: nizsi, tupnejsi - hrac ma poznat "to jsem ja".
    return mix([
        sum_noise(0.24, 0.06, 0.7, seed=23, dolnipropust=0.25),
        ozvuk(0.24, 92.0, 0.07, 0.8),
        ozvuk(0.18, 138.0, 0.05, 0.35),
    ], 0.24)


def zvuk_mine() -> list[float]:
    # Tezba (krumpac do skaly): kratky kamenny tresk.
    return mix([
        sum_noise(0.22, 0.03, 0.6, seed=37, dolnipropust=0.7),
        ozvuk(0.22, 420.0, 0.03, 0.5),
        ozvuk(0.14, 1180.0, 0.015, 0.25),
    ], 0.22)


def zvuk_smith() -> list[float]:
    # Kovadlina: neharmonicke parcialy = "cinknuti" kovu.
    return mix([
        ozvuk(0.42, 812.0, 0.16, 0.55),
        ozvuk(0.42, 1218.0, 0.12, 0.40),
        ozvuk(0.42, 1834.0, 0.09, 0.28),
        ozvuk(0.42, 2477.0, 0.06, 0.16),
        sum_noise(0.05, 0.008, 0.5, seed=41, dolnipropust=0.9),
    ], 0.42)


def zvuk_death() -> list[float]:
    # Smrt: klesajici ton + posledni vydech sumu.
    doba = 0.75
    n = int(doba * MIX_RATE)
    klesa = [0.6 * math.sin(2.0 * math.pi * (210.0 - 130.0 * (i / n)) * (i / MIX_RATE))
             * math.exp(-(i / MIX_RATE) / 0.45) for i in range(n)]
    return mix([klesa, sum_noise(doba, 0.5, 0.35, seed=53, dolnipropust=0.2)], doba)


ZVUKY = [
    ("hit", "uder do nekoho (udeřili jsme my)", zvuk_hit),
    ("hurt", "uder dostaneme (my)", zvuk_hurt),
    ("mine", "tezba - krumpac do rudy/kamene", zvuk_mine),
    ("smith", "kovadlina - kovarska prace", zvuk_smith),
    ("death", "smrt bytosti", zvuk_death),
]


def wav_bajty(vzorky: list[float]) -> bytes:
    """16bit PCM stereo WAV - zapisujeme bajty, ne pres knihovnu wave (BOM/CRLF
    v textovem rezimu by zmenily obsah a `--check` by lhal)."""
    telo = array.array("h")
    for v in vzorky:
        x = max(-32768, min(32767, int(round(v * 32767.0))))
        telo.append(x)
        telo.append(x)                     # stereo = dva stejne kanaly
    data = telo.tobytes()
    blok = CHANNELS * BITS // 8
    hlavicka = b"RIFF" + (36 + len(data)).to_bytes(4, "little") + b"WAVE"
    hlavicka += b"fmt " + (16).to_bytes(4, "little")
    hlavicka += (1).to_bytes(2, "little")                  # PCM
    hlavicka += CHANNELS.to_bytes(2, "little")
    hlavicka += MIX_RATE.to_bytes(4, "little")
    hlavicka += (MIX_RATE * blok).to_bytes(4, "little")
    hlavicka += blok.to_bytes(2, "little")
    hlavicka += BITS.to_bytes(2, "little")
    hlavicka += b"data" + len(data).to_bytes(4, "little")
    return hlavicka + data


def premer(vzorky: list[float]) -> dict:
    # POZOR: `vzorky` je MONO seznam (do souboru jde kazdy vzorek dvakrat).
    # Delit `CHANNELS` je vada - prvni verze tim hlasila pulku delky (namEReno:
    # "hit 80 ms" misto 160 ms). Delka se pocita z MONO poctu vzorku.
    vrchol = max((abs(v) for v in vzorky), default=0.0)
    rms = math.sqrt(sum(v * v for v in vzorky) / max(1, len(vzorky)))
    return {
        "frames": len(vzorky),
        "duration_ms": int(round(1000.0 * len(vzorky) / MIX_RATE)),
        "peak": round(vrchol, 4),
        "rms": round(rms, 4),
    }


def vyrob() -> int:
    SADA.mkdir(parents=True, exist_ok=True)
    zaznamy = []
    for ident, popis, tvurce in ZVUKY:
        vzorky = obalka(tvurce())
        bajty = wav_bajty(vzorky)
        jmeno = f"{ident}.wav"
        (SADA / jmeno).write_bytes(bajty)
        m = premer(vzorky)
        zaznamy.append({
            "id": ident, "file": jmeno, "popis": popis,
            "mix_rate": MIX_RATE, "channels": CHANNELS, "bits": BITS,
            "frames": m["frames"], "duration_ms": m["duration_ms"],
            "peak": m["peak"], "rms": m["rms"],
            "sha256": hashlib.sha256(bajty).hexdigest(),
            "license": "CC0-1.0 (vygenerovano timto skriptem, zadny cizi vzorek)",
            "source": "tools/audio/gen-sfx.py",
        })
        print(f"[gen-sfx] {jmeno}: {m['duration_ms']} ms, peak {m['peak']}, "
              f"rms {m['rms']}, sha {zaznamy[-1]['sha256'][:12]}")
    data = {
        "version": 1,
        "generator": "tools/audio/gen-sfx.py",
        "kanal": "app/sound.gd (`audio.playback`)",
        "format": f"{MIX_RATE} Hz, {CHANNELS} kanaly, {BITS} bitu (PCM)",
        "poznamka": "Kdo chce nahravany zvuk, vymeni soubor a v manifestu zmeni "
                    "`source`/`license` - id a format zustavaji.",
        "sounds": zaznamy,
    }
    MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    MANIFEST.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8", newline="\n")
    print(f"[gen-sfx] manifest: {MANIFEST.relative_to(ROOT).as_posix()} "
          f"({len(zaznamy)} zvuku)")
    return 0


def zkontroluj() -> int:
    """Premer: soubor musi byt bajtove ten, ktery manifest popisuje - a mit
    predepsany format. Nula a 'nezmereno' tady nejsou uspech."""
    chyby: list[str] = []
    if not MANIFEST.exists():
        print("[gen-sfx] CHYBA: manifest neexistuje - spust generator")
        return 1
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))
    zvuky = data.get("sounds", [])
    if not zvuky:
        chyby.append("manifest nema zadny zvuk (prazdny seznam neni uspech)")
    soubory = sorted(p.name for p in SADA.glob("*.wav"))
    if soubory != sorted(z["file"] for z in zvuky):
        chyby.append(f"v {SADA.name}/ jsou jine soubory nez v manifestu: "
                     f"{soubory} vs {sorted(z['file'] for z in zvuky)}")
    for z in zvuky:
        cesta = SADA / str(z["file"])
        if not cesta.exists():
            chyby.append(f"{z['id']}: soubor {z['file']} chybi")
            continue
        bajty = cesta.read_bytes()
        if hashlib.sha256(bajty).hexdigest() != str(z["sha256"]):
            chyby.append(f"{z['id']}: {z['file']} neodpovida manifestu (sha256)")
        if bytes(bajty[:4]) != b"RIFF" or bytes(bajty[8:12]) != b"WAVE":
            chyby.append(f"{z['id']}: {z['file']} neni WAV")
            continue
        kanaly = int.from_bytes(bajty[22:24], "little")
        rate = int.from_bytes(bajty[24:28], "little")
        bitu = int.from_bytes(bajty[34:36], "little")
        if (rate, kanaly, bitu) != (MIX_RATE, CHANNELS, BITS):
            chyby.append(f"{z['id']}: format je {rate} Hz / {kanaly} kan. / {bitu} b, "
                         f"ceka se {MIX_RATE} / {CHANNELS} / {BITS}")
        if int(z.get("duration_ms", 0)) < 20:
            chyby.append(f"{z['id']}: zvuk je kratsi nez 20 ms ({z.get('duration_ms')})")
        if float(z.get("rms", 0.0)) <= 0.0:
            chyby.append(f"{z['id']}: rms je 0 - soubor je ticho")
    print(f"[gen-sfx] MERENO: zvuku {len(zvuky)}, souboru {len(soubory)}, "
          f"chyb {len(chyby)}")
    for ch in chyby:
        print(f"[gen-sfx] CHYBA: {ch}")
    print(f"[gen-sfx] {'OK (exit 0)' if not chyby else 'VADA (exit 1)'}")
    return 0 if not chyby else 1


def main() -> int:
    ap = argparse.ArgumentParser(description="generator zvuku hry (CC0)")
    ap.add_argument("--check", action="store_true", help="jen premer hotove zvuky")
    a = ap.parse_args()
    return zkontroluj() if a.check else vyrob()


if __name__ == "__main__":
    raise SystemExit(main())
