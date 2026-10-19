#!/usr/bin/env python3
"""G20 check-loop - hrac PROJDE kratkou smyckou na realne scene (docs/08 §8.2).

Proc existuje: projekt umi merit podsoucasti (tezba v `tests/cases/harvest.gd`,
kovani ve `sim.craft`, prodej ve `sim.vendor`), ale ZADNA brana nemerila, ze
hrac projde celou smycku tezit -> vyrobit -> prodat NA REALNE SCENE. Presne ta
trida vady uz jednou prosla zelenymi testy: okno obchodu nemelo prepinac na
prodej, takze prodej byl dosazitelny jen sondou, ne hrou (session D,
2026-10-11). Testy to nechytily, protoze volaji systemy primo.

Brana spusti REALNOU scenu pres `tools/gates/loop_probe.gd` a pozaduje:
  * ctyri kroky v poradi tezba -> taveni -> vyroba -> prodej, kazdy `ok`,
  * u kazdeho kroku HRACOVI VIDITELNY nasledek: aspon jedna nova zprava
    v zurnalu A ocekavane slovo v ni ("gather", "smelt", "create", "sell"),
  * konkretni hodnoty: ruda 0 -> >0, ingoty 0 -> >=3, dyka 0 -> >0,
    zlato se ZVYSI a dyka z batohu ZMIZI,
  * cestu hrace: prikaz tezby je `interact` s cilem `{kind:"tile"}` (ne prime
    volani akcnich systemu `sim/`) a kroky 3 a 4 jdou KLIKEM na skutecne
    `Button` uzly oken (`tlacitko_*`) se pripojenym signalem (`signal_*`);
    bez nich krok neprojde - jinak by brana prosla i na kopye, kde je
    `Button` nahrazeny `Label` (presne historicka vada, kvuli ktere vznikla).

SNIMKY (vizualni dokaz, `--snimky`): sonda umi ulozit 3-4 PNG; brana vyzaduje
ALESPOŇ 2 ruzne (`MIN_SNIMKU`). V headless to NEJDE - `root.get_texture().
get_image()` vrati null (namEReno 2026-10-19), proto `--snimky` spusti sondu
v okne (`--rendering-driver opengl3`) a PNG zkontroluje (vic nez 10 kB, platna
hlavicka PNG, aspon 2 ruzne snimky). Kdyz je `--snimky` pozadano, brana
VYZADUJE `snimky_zadany == true`, prazdne `snimky_chyba` a >= MIN_SNIMKU
snimku - jinak je to VADA (fail-closed, ne "nemereno"). Bez `--snimky` se
snimky NEMERI a brana to rekne (`snimky: nemereno`), nikdy netvrdi uspech.

NEMERENO (ne zelena): chybi-li sonda nebo Godot.

Spousteni:
  python tools/gates/check-loop.py [--root .] [--json cesta]
  python tools/gates/check-loop.py --snimky [--snimky-dir .tmp/g20-smycka]
  python tools/gates/check-loop.py --self-test   # offline, bez Godotu
  python tools/gates/check-loop.py --mutace      # dukaz, ze brana UMI selhat
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, OUT_DIR, VADA, Gate, ensure_import, godot_bin, godot_run,
)

NAME = "check-loop"
PROBE = "res://tools/gates/loop_probe.gd"
# Kroky smycky V PORADI. Chybejici krok neni "preskoceny", je to VADA: brana
# ma merit celou smycku, ne tu cast, ktera vysla.
KROKY = ("tezba", "taveni", "vyroba", "prodej")
ZNACKA = "[smycka] SOUHRN "
MIN_SNIMKU = 2
MIN_BYTU = 10_000          # prazdny/black snimek se takhle velky nezkomprimuje


def _json_ze_zbytku(zbytek: str):
    """Vytahne prvni vyvážený objekt {...} (i kdyby ho engine zalomil)."""
    hloubka = 0
    for i, ch in enumerate(zbytek):
        if ch == "{":
            hloubka += 1
        elif ch == "}":
            hloubka -= 1
            if hloubka == 0:
                try:
                    return json.loads(zbytek[: i + 1])
                except json.JSONDecodeError:
                    return None
    return None


def vyhodnot(output: str) -> dict:
    """Precte SOUHRN ze sondy. `nalezeno: False` = sonda nic nenahlasila."""
    idx = output.rfind(ZNACKA)
    if idx < 0:
        return {"nalezeno": False}
    data = _json_ze_zbytku(output[idx + len(ZNACKA):])
    if data is None:
        return {"nalezeno": False}
    return {"nalezeno": True, "data": data}


def _cislo(slovnik: dict, klic: str) -> int:
    try:
        return int(slovnik.get(klic, 0))
    except (TypeError, ValueError):
        return 0


def _tlacitko_chyba(krok: str, hodnoty: dict, jmeno: str, popis: str) -> str:
    """Vada D1: krok musi projit KLIKEM na skutecne `Button` (a mit `pressed`).

    Sonda hlasi `tlacitko_<jmeno>` (nasla Button uzel) a `signal_<jmeno>`
    (má pripojeny `pressed`). Kdyz chybi kterekoli, hrac se ke kroku nedostane
    kliknutim - i kdyby ho sonda umela zavolat bokem.
    """
    tl = bool(hodnoty.get(f"tlacitko_{jmeno}", False))
    sg = bool(hodnoty.get(f"signal_{jmeno}", False))
    if tl and sg:
        return ""
    return (f"{krok}: {popis} neni kliknute skutecne tlacitko "
            f"(tlacitko_{jmeno}={tl}, signal_{jmeno}={sg}; "
            f"sonda: {hodnoty.get('tlacitko_chyba', '') or 'bez udani'})")


def chyby_z_mereni(d: dict, snimky_zadano: bool = False) -> list[str]:
    """Verdikt z jednoho mereni - pouziva ho brana, self-test i mutace.

    `snimky_zadano` = uzivatel pozadal o `--snimky`; pak se snimky VYZADUJI
    (fail-closed). Bez toho se snimky nemeri a brana to jen poznamena.
    """
    if not d.get("nalezeno", False):
        return ["ze sondy nelze precist SOUHRN (sonda neprobihla nebo spadla)"]
    data = d["data"]
    chyby: list[str] = []
    if str(data.get("duvod", "")) != "":
        chyby.append("sonda hlasi duvod: " + str(data["duvod"]))
    kroky = data.get("kroky")
    if not isinstance(kroky, list) or not kroky:
        return chyby + ["sonda nevratila zadny krok smycky (nemereno)"]
    podle = {str(k.get("id", "")): k for k in kroky if isinstance(k, dict)}
    poradi = [str(k.get("id", "")) for k in kroky if isinstance(k, dict)]
    if poradi != list(KROKY):
        chyby.append("kroky nejsou v poradi smycky: " + str(poradi))
    for krok in KROKY:
        if krok not in podle:
            chyby.append(f"krok '{krok}' sonda vubec nemerila")
    if chyby:
        return chyby

    for krok in KROKY:
        z = podle[krok]
        hodnoty = z.get("hodnoty", {}) if isinstance(z.get("hodnoty"), dict) else {}
        if not bool(z.get("ok", False)):
            chyby.append(f"krok {krok} neprosel: {hodnoty}")
        if _cislo(z, "zurnal_po") <= _cislo(z, "zurnal_pred"):
            chyby.append(f"krok {krok}: hrac nevidel ZADNOU zpravu v zurnalu "
                         f"({_cislo(z, 'zurnal_pred')} -> {_cislo(z, 'zurnal_po')})")
        # Slovo se overuje Z TEXTU zprav, ne z booleana sondy: boolean muze
        # tvrdit `true` a text ho nemit (a naopak) - pak je to VADA.
        hledany = str(z.get("zurnal_hledany", "")).strip().lower()
        nove = [str(x) for x in (z.get("zurnal_nove") or [])]
        textem = bool(hledany) and any(hledany in radek.lower() for radek in nove)
        sonda_tvrdi = bool(z.get("zurnal_klice", False))
        if not sonda_tvrdi or not textem:
            chyby.append(f"krok {krok}: v zurnalu neni '{hledany or '?'}' "
                         f"(textem: {'ano' if textem else 'ne'}, sonda tvrdi: "
                         f"{sonda_tvrdi}); zpravy: "
                         + " | ".join(nove[:3]))

    tezba = podle["tezba"].get("hodnoty", {})
    if str(tezba.get("prikaz", "")) != "interact":
        chyby.append("tezba nesla pres klienta: prikaz neni 'interact'")
    if '"kind": "tile"' not in str(tezba.get("cil", "")):
        chyby.append("tezba: klient neposlal cil {kind:'tile'} (cil: "
                     + str(tezba.get("cil", ""))[:60] + ")")
    if _cislo(tezba, "ruda_po") <= _cislo(tezba, "ruda_pred"):
        chyby.append(f"tezba: ruda v batohu se nezvysila "
                     f"({_cislo(tezba, 'ruda_pred')} -> {_cislo(tezba, 'ruda_po')})")

    taveni = podle["taveni"].get("hodnoty", {})
    if _cislo(taveni, "ingot_po") <= _cislo(taveni, "ingot_pred"):
        chyby.append(f"taveni: ingoty se nezvysily "
                     f"({_cislo(taveni, 'ingot_pred')} -> {_cislo(taveni, 'ingot_po')})")
    if _cislo(taveni, "ingot_po") < 3:
        chyby.append(f"taveni: na vyrobu dyky je potreba 3 ingotu, namereno "
                     f"{_cislo(taveni, 'ingot_po')}")

    vyroba = podle["vyroba"].get("hodnoty", {})
    if _cislo(vyroba, "dyka_po") <= _cislo(vyroba, "dyka_pred"):
        chyby.append(f"vyroba: dyka v batohu neni "
                     f"({_cislo(vyroba, 'dyka_pred')} -> {_cislo(vyroba, 'dyka_po')})")
    if not bool(vyroba.get("okno_otevrene", False)):
        chyby.append("vyroba: okno vyroby se neotevrelo (interact na kovadlinu nic)")
    if not bool(vyroba.get("kliknuto", False)):
        chyby.append(f"vyroba: recept {vyroba.get('recept', '?')} v okne neni "
                     f"(receptu {vyroba.get('receptu', 0)})")
    ch = _tlacitko_chyba("vyroba", vyroba, "recept", "radek receptu")
    if ch:
        chyby.append(ch)

    prodej = podle["prodej"].get("hodnoty", {})
    if _cislo(prodej, "zlato_po") <= _cislo(prodej, "zlato_pred"):
        chyby.append(f"prodej: zlato se nezvysilo "
                     f"({_cislo(prodej, 'zlato_pred')} -> {_cislo(prodej, 'zlato_po')})")
    if not bool(prodej.get("prepnuto_na_sell", False)):
        chyby.append("prodej: okno obchodu neslo prepnout na 'sell'")
    for jmeno, popis in (("smer", "prepinac 'Smer'"),
                         ("radek", "radek s vyrobkem"),
                         ("potvrdit", "tlacitko 'Potvrdit'")):
        ch = _tlacitko_chyba("prodej", prodej, jmeno, popis)
        if ch:
            chyby.append(ch)
    if _cislo(prodej, "dyka_po") >= _cislo(prodej, "dyka_pred"):
        chyby.append(f"prodej: dyka zustala v batohu "
                     f"({_cislo(prodej, 'dyka_pred')} -> {_cislo(prodej, 'dyka_po')})")

    inv = data.get("inv", {}) if isinstance(data.get("inv"), dict) else {}
    if _cislo(inv, "zlato") <= 0:
        chyby.append("inv: hrac nema po smycce zadne zlato")
    if _cislo(inv, "hp") <= 0:
        chyby.append("inv: hrac je po smycce mrtvy (hp <= 0)")
    if _cislo(data, "zurnal_celkem") <= 0:
        chyby.append("zurnal: hrac nevidel ani jednu zpravu")

    snimky = data.get("snimky") or []
    if snimky_zadano:
        # FAIL-CLOSED (vada D3): `--snimky` je pozadavek na DUKAZ, takze sonda
        # musi potvrdit, ze snimky chtela, nesmi mit chybu a musi jich byt
        # aspon MIN_SNIMKU. Kdyz sonda adresar nevytvori, vynuluje `_snimky_dir`
        # a posle `snimky_zadany:false` - to je VADA, ne "nemereno".
        if not bool(data.get("snimky_zadany", False)):
            chyby.append("snimky: pozadovany, ale sonda hlasi snimky_zadany=false "
                         f"(sonda: {data.get('snimky_chyba', '') or 'bez udani'})")
        if str(data.get("snimky_chyba", "")) != "":
            chyby.append("snimky: sonda hlasi chybu: " + str(data["snimky_chyba"]))
        if len(snimky) < MIN_SNIMKU:
            chyby.append(f"snimky: pozadovany, ale ulozeno {len(snimky)} "
                         f"(minimum {MIN_SNIMKU}; chyba: "
                         f"{data.get('snimky_chyba', '')})")
    elif bool(data.get("snimky_zadany", False)) and len(snimky) < MIN_SNIMKU:
        chyby.append(f"snimky: sonda je vykazala, ale ulozeno {len(snimky)} "
                     f"(minimum {MIN_SNIMKU}; chyba: {data.get('snimky_chyba', '')})")
    return chyby


def _png_hlavicka(path: Path) -> tuple[int, int] | None:
    """Rozmer z IHDR - bez knihoven (snimek musi byt skutecny PNG, ne soubor)."""
    try:
        data = path.read_bytes()[:24]
    except OSError:
        return None
    if len(data) < 24 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", data[16:24])


def _cesta_snimku(root: Path, cesta: str) -> Path:
    """`res://x` -> soubor v projektu (sonda hlasi cesty v `res://`)."""
    if cesta.startswith("res://"):
        return root / cesta[len("res://"):]
    return Path(cesta)


def zkontroluj_snimky(root: Path, paths: list[str]) -> list[str]:
    chyby: list[str] = []
    velikosti: set[int] = set()
    for p in paths:
        cesta = _cesta_snimku(root, p)
        if not cesta.exists():
            chyby.append(f"snimek {p} neexistuje (sonda ho jen ohlasila)")
            continue
        velikost = cesta.stat().st_size
        velikosti.add(velikost)
        if velikost < MIN_BYTU:
            chyby.append(f"snimek {p} ma jen {velikost} B - prazdny obraz")
        rozmer = _png_hlavicka(cesta)
        if rozmer is None:
            chyby.append(f"snimek {p} neni PNG")
        elif rozmer[0] < 320 or rozmer[1] < 200:
            chyby.append(f"snimek {p} je {rozmer[0]}x{rozmer[1]} - male okno")
    if len(velikosti) < 2:
        chyby.append(f"snimky maji stejnou velikost ({velikosti}) - nejspis je to "
                     "jeden a ten samy obraz")
    return chyby


def _vystup_pro_gate(gate: Gate, d: dict) -> None:
    data = d["data"]
    gate.measure("kroky", len(data.get("kroky") or []))
    for krok in data.get("kroky") or []:
        if not isinstance(krok, dict):
            continue
        gate.measure(f"krok_{krok.get('id', '?')}", "PASS" if krok.get("ok") else "VADA")
        hodnoty = krok.get("hodnoty", {})
        gate.note(f"krok {krok.get('id', '?')}: "
                  f"{'PASS' if krok.get('ok') else 'VADA'} {json.dumps(hodnoty, ensure_ascii=False)}")
        gate.note(f"  zurnal {krok.get('zurnal_pred')} -> {krok.get('zurnal_po')}"
                  f" (hledany '{krok.get('zurnal_hledany')}' "
                  f"{'NALEZEN' if krok.get('zurnal_klice') else 'NENALEZEN'})")
        hod = krok.get("hodnoty", {}) if isinstance(krok.get("hodnoty"), dict) else {}
        tlacitka = {k: v for k, v in hod.items()
                    if str(k).startswith(("tlacitko_", "signal_"))}
        if tlacitka:
            gate.note(f"  tlacitka: {json.dumps(tlacitka, ensure_ascii=False)}")
        for radek in (krok.get("zurnal_nove") or [])[:4]:
            gate.note(f"    zurnal: {radek}")
    inv = data.get("inv", {})
    gate.measure("inv", json.dumps(inv, ensure_ascii=False))
    gate.measure("zurnal_celkem", data.get("zurnal_celkem", 0))
    gate.measure("prekryv_cilu", data.get("prekryv", -1))
    gate.measure("snimky", len(data.get("snimky") or []))


def _godot_okno(root: Path, args: list[str], timeout: int = 900) -> tuple[int, str]:
    """Godot S OKNEM (pro snimky) - headless nema viewport texturu."""
    binary = godot_bin()
    if binary is None:
        return 127, "GODOT nenalezen (nastav $GODOT)"
    ensure_import(root)
    userdata = root / ".cache" / "godot-appdata"
    (userdata / "Godot" / "app_userdata").mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["APPDATA"] = str(userdata)
    cmd = [str(binary), "--path", str(root), "--rendering-driver", "opengl3",
           "--resolution", "1280x720"] + args
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8",
                              errors="replace", timeout=timeout, env=env)
    except subprocess.TimeoutExpired:
        return 124, f"Godot (okno) prekrocil timeout {timeout}s"
    return proc.returncode, (proc.stdout or "") + (proc.stderr or "")


def check(root: Path, gate: Gate, snimky_dir: Path | None = None) -> None:
    sonda = root / "tools" / "gates" / "loop_probe.gd"
    if not sonda.exists():
        gate.pending(f"chybí sonda {sonda.relative_to(root).as_posix()} - není co měřit")
        return
    if godot_bin() is None:
        gate.skip("Godot není k dispozici (nastav $GODOT nebo dodej binárku do .cache/godot)")
        return
    args = ["--fixed-fps", "60", "--script", PROBE]
    if snimky_dir is None:
        rc, output = godot_run(root, args, timeout=900)
    else:
        # `--snimky` = vizualni dokaz: sonda dostane cil ve `res://` a bezi v okne.
        cil = snimky_dir / "loop"
        cil.mkdir(parents=True, exist_ok=True)
        for stary in cil.glob("*.png"):
            stary.unlink()
        try:
            relativni = cil.resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            gate.error(f"adresář snímků {cil} není uvnitř projektu - res:// ho nevidí")
            return
        rc, output = _godot_okno(root, args + ["--", f"--snimky=res://{relativni}"], timeout=900)
    d = vyhodnot(output)
    gate.measure("probe_exit", rc)
    if not d.get("nalezeno", False):
        gate.error(f"ze sondy nelze přečíst SOUHRN (exit {rc})")
        for line in output.splitlines()[-5:]:
            gate.note(line.strip()[:160])
        return
    _vystup_pro_gate(gate, d)
    if rc != 0:
        gate.error(f"sonda skončila s exit {rc} (výstup se čte i přesto)")
    for ch in chyby_z_mereni(d, snimky_zadano=snimky_dir is not None):
        gate.error(ch)
    if snimky_dir is not None:
        snimky = [str(s) for s in (d["data"].get("snimky") or [])]
        if len(snimky) >= MIN_SNIMKU:
            for ch in zkontroluj_snimky(root, snimky):
                gate.error(ch)
        # elif: chybu "malo snimku" uz nahlasi `chyby_z_mereni`
    else:
        # Snimek se NEMERIL - musi to byt videt ve MERENO, ne jen v poznamce.
        gate.measure("snimky", "nemereno (headless nema viewport texturu)")
        gate.note("snímky: NEMĚŘENO (headless) - vizuální důkaz dělá "
                  "`check-loop.py --snimky`; kroky a žurnál se měří i tak")


def selftest() -> int:
    """Znamy spravny i znamy chybny vstup - offline, bez Godotu."""
    dobry = {
        "ok": True, "duvod": "", "zurnal_celkem": 39, "snimky_zadany": False,
        "inv": {"ruda": 1, "ingot": 4, "dyka": 0, "zlato": 70, "hp": 83, "hp_max": 87},
        "kroky": [
            {"id": "tezba", "ok": True, "zurnal_pred": 12, "zurnal_po": 33,
             "zurnal_klice": True, "zurnal_hledany": "gather",
             "zurnal_nove": ["You gather some iron ore."],
             "hodnoty": {"ruda_pred": 0, "ruda_po": 8, "prikaz": "interact",
                         "cil": '{ "kind": "tile", "x": 1496, "y": 1631, "z": 10 }'}},
            {"id": "taveni", "ok": True, "zurnal_pred": 33, "zurnal_po": 35,
             "zurnal_klice": True, "zurnal_hledany": "smelt",
             "zurnal_nove": ["You smelt 2 iron ingots."],
             "hodnoty": {"ingot_pred": 0, "ingot_po": 7}},
            {"id": "vyroba", "ok": True, "zurnal_pred": 35, "zurnal_po": 38,
             "zurnal_klice": True, "zurnal_hledany": "create",
             "zurnal_nove": ["You create a dagger."],
             "hodnoty": {"dyka_pred": 0, "dyka_po": 1, "okno_otevrene": True,
                         "kliknuto": True, "recept": 114, "receptu": 196,
                         "tlacitko_recept": True, "signal_recept": True,
                         "tlacitko_chyba": ""}},
            {"id": "prodej", "ok": True, "zurnal_pred": 38, "zurnal_po": 39,
             "zurnal_klice": True, "zurnal_hledany": "sell",
             "zurnal_nove": ["You sell a dagger for 10 gold."],
             "hodnoty": {"zlato_pred": 60, "zlato_po": 70, "dyka_pred": 1, "dyka_po": 0,
                         "prepnuto_na_sell": True,
                         "tlacitko_smer": True, "signal_smer": True,
                         "tlacitko_radek": True, "signal_radek": True,
                         "tlacitko_potvrdit": True, "signal_potvrdit": True,
                         "tlacitko_chyba": ""}},
        ],
    }

    def kopie():
        return json.loads(json.dumps(dobry))

    # (jmeno, mereni, ocekavany pocet chyb, zada se --snimky)
    pripady: list[tuple[str, dict, int, bool]] = []
    pripady.append(("vsechno_proslo", dobry, 0, False))

    z = kopie()
    z["kroky"][3]["hodnoty"]["zlato_po"] = 60          # prodej nic nevydelal
    z["kroky"][3]["hodnoty"]["dyka_po"] = 1            # a dyka zustala
    z["kroky"][3]["ok"] = False
    pripady.append(("prodej_nefunguje", z, 3, False))

    z = kopie()
    z["kroky"][0]["hodnoty"]["ruda_po"] = 0            # tezba nic nevytEZila
    z["kroky"][0]["ok"] = False
    z["kroky"][0]["zurnal_klice"] = False
    pripady.append(("tezba_nefunguje", z, 3, False))

    z = kopie()
    z["kroky"][2]["hodnoty"]["okno_otevrene"] = False   # okno vyroby se neotevrelo
    z["kroky"][2]["hodnoty"]["dyka_po"] = 0
    z["kroky"][2]["ok"] = False
    pripady.append(("okno_vyroby_se_neotevrelo", z, 3, False))

    z = kopie()
    z["kroky"].pop(2)                                   # krok vubec chybi
    pripady.append(("krok_chybi", z, 2, False))

    z = kopie()
    z["kroky"][1]["zurnal_po"] = z["kroky"][1]["zurnal_pred"]   # zadna zprava
    z["kroky"][1]["zurnal_klice"] = False
    pripady.append(("zurnal_mlci", z, 2, False))

    z = kopie()
    z["kroky"][0]["hodnoty"]["prikaz"] = "mine"          # obchazeni klienta
    pripady.append(("obchazeni_klienta", z, 1, False))

    # Vada D4: boolean tvrdi "slovo je v zurnalu", ale TEXT ho neobsahuje.
    z = kopie()
    z["kroky"][1]["zurnal_klice"] = True
    z["kroky"][1]["zurnal_nove"] = ["Nothing happens here."]
    pripady.append(("zurnal_boolean_lze", z, 1, False))

    # Vada D1: tlacitko existuje, ale nema pripojeny signal -> klik nic neudela.
    z = kopie()
    z["kroky"][3]["hodnoty"]["signal_smer"] = False
    z["kroky"][3]["hodnoty"]["tlacitko_chyba"] = "Button 'Smer' nema signal 'pressed'"
    pripady.append(("tlacitko_odpojene", z, 1, False))

    # Vada D1b: v okne neni Button vubec (historicka vada: Button -> Label).
    z = kopie()
    z["kroky"][3]["hodnoty"]["tlacitko_smer"] = False
    z["kroky"][3]["hodnoty"]["signal_smer"] = False
    z["kroky"][3]["hodnoty"]["tlacitko_chyba"] = "v okne obchodu neni Button 'Smer'"
    pripady.append(("tlacitko_chybi", z, 1, False))

    z = kopie()
    z["kroky"][2]["hodnoty"]["tlacitko_recept"] = False
    z["kroky"][2]["hodnoty"]["signal_recept"] = False
    pripady.append(("recept_bez_tlacitka", z, 1, False))

    # Vada D3: --snimky pozadano, ale sonda adresar nevytvorila -> vsechno false.
    z = kopie()
    z["snimky_zadany"] = False
    z["snimky"] = []
    z["snimky_chyba"] = "adresar pro snimky nejde vytvorit (19)"
    pripady.append(("snimky_se_nevykazaly", z, 3, True))

    z = kopie()
    z["snimky_zadany"] = True
    z["snimky"] = ["res://.tmp/a.png", "res://.tmp/b.png"]
    z["snimky_chyba"] = "viewport nema obraz (headless)"
    pripady.append(("snimky_hlasi_chybu", z, 1, True))

    z = kopie()
    z["snimky_zadany"] = True
    z["snimky"] = ["res://.tmp/a.png"]
    pripady.append(("snimky_chybi", z, 1, True))

    chyb = 0
    for jmeno, mereni, ocekavano, snimky_zadano in pripady:
        vyslo = len(chyby_z_mereni({"nalezeno": True, "data": mereni},
                                   snimky_zadano=snimky_zadano))
        ok = vyslo == ocekavano
        chyb += 0 if ok else 1
        print(f"[{NAME}] self-test {jmeno}: ocekavano {ocekavano} chyb, vyslo {vyslo}"
              f" {'OK' if ok else 'CHYBA'}")
        if not ok:
            for ch in chyby_z_mereni({"nalezeno": True, "data": mereni},
                                     snimky_zadano=snimky_zadano):
                print(f"[{NAME}]   duvod: {ch}")
    # Sonda, ktera nic nenahlasila, nesmi projit.
    vyslo = len(chyby_z_mereni({"nalezeno": False}))
    ok = vyslo == 1
    chyb += 0 if ok else 1
    print(f"[{NAME}] self-test sonda_mlci: ocekavano 1 chyb, vyslo {vyslo}"
          f" {'OK' if ok else 'CHYBA'}")
    print(f"[{NAME}] self-test: {len(pripady) + 1} případů, {chyb} chyb")
    return VADA if chyb else OK


# -- mutace: dokaz, ze brana UMI selhat ---------------------------------------

SMAZ_FUNKCI = "<SMAZ_FUNKCI>"
# Jedna sabotaz = jeden beh brany na kopii. Kdyz se brana na kopii zasekne,
# je to chyba mutace (ne "vadu nevidela") a ceka se na ni jen takhle dlouho.
MUTACE_TIMEOUT = 600

# Co se v sabotovane kopii rozbije. Kazda sabotaz = seznam zmen
# `(soubor, hledat, nahradit)`; prazdne `nahradit` znamena "smaz", sentinel
# `SMAZ_FUNKCI` znamena "smaz celou funkci od radku s hlavickou".
SABOTAZE: list[tuple[str, list[tuple[str, str, str]]]] = [
    # 1) vypnuty system: early return na zacatku funkce
    ("prodej_vypnuty", [(
        "sim/systems/vendor.gd",
        "func sell(m: int, v: int, lines: Array) -> Dictionary:",
        "func sell(m: int, v: int, lines: Array) -> Dictionary:\n\treturn _fail(\"sabotaz\")",
    )]),
    ("tezba_vypnuta", [(
        "sim/systems/harvest.gd",
        "func _harvest(kind: String, m: int, x: int, y: int) -> Dictionary:",
        "func _harvest(kind: String, m: int, x: int, y: int) -> Dictionary:\n"
        "\treturn _fail(kind, \"sabotaz\")",
    )]),
    # 2) HISTORICKA VADA (session D): okno obchodu melo misto `Button` jen `Label`
    # a prodej se dal udelat jen bokem pres API - presne vada, kvuli ktere G20
    # vznikla. Sabotaz ji vraci: `Button` -> `Label` a odstranene handlery
    # u vsech tri tlacitek (Smer, radek, Potvrdit) i u radku receptu.
    # Sonda, ktera macka skutecna tlacitka, to MUSI videt (exit 1).
    ("historicka_vada_button_label", [
        ("ui/vendor_gump.gd", "var popis := Button.new()", "var popis := Label.new()"),
        ("ui/vendor_gump.gd", "func _on_smer_pressed() -> void:", SMAZ_FUNKCI),
        ("ui/vendor_gump.gd", "\tpopis.pressed.connect(_on_smer_pressed)\n", ""),
        ("ui/vendor_gump.gd", "var tlacitko := Button.new()", "var tlacitko := Label.new()"),
        ("ui/vendor_gump.gd",
         '\t\ttlacitko.pressed.connect(stiskni_radek.bind(_smer, int(radek["item"])))\n', ""),
        ("ui/vendor_gump.gd", "var potvrzeni := Button.new()", "var potvrzeni := Label.new()"),
        ("ui/vendor_gump.gd",
         "\tpotvrzeni.pressed.connect(stiskni_potvrzeni.bind(_smer))\n", ""),
        ("ui/craft_gump.gd", "var tlacitko := Button.new()", "var tlacitko := Label.new()"),
        ("ui/craft_gump.gd",
         '\t\ttlacitko.pressed.connect(stiskni.bind(int(rec["id"])))\n', ""),
    ]),
]
KOPIRUJ = ("app", "core", "sim", "ui", "render", "data", "assets", "tools/gates", ".godot")


def _postav_kopii(root: Path, cil: Path) -> None:
    """Kopie projektu s HARD LINKY (data se nekopiruji, jen jmena).

    Hardlink je jen na cteni: kdo chce soubor zmenit, musi ho nejdriv odpojit
    (`_prepis`), jinak by zmenil ORIGINAL - to je past, na kterou se u
    hardlinkovych kopii zapomina.
    """
    if cil.exists():
        shutil.rmtree(cil)
    cil.mkdir(parents=True)
    for jmeno in ("project.godot",):
        shutil.copy2(root / jmeno, cil / jmeno)
    for jmeno in KOPIRUJ:
        zdroj = root / jmeno
        if not zdroj.is_dir():
            continue
        for p in zdroj.rglob("*"):
            relativni = p.relative_to(root)
            target = cil / relativni
            if p.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            try:
                os.link(p, target)
            except OSError:
                shutil.copy2(p, target)


def _prepis(path: Path, text: str) -> None:
    """Zapis DO KOPIE: hardlink se nejdriv odpoji, aby se nezmenil original."""
    if path.exists():
        path.unlink()
    path.write_text(text, encoding="utf-8", newline="\n")


def _odstran_funkci(text: str, hlavicka: str) -> str:
    """Smaze funkci od radku s hlavickou do dalsiho `func ` (vcetne tela)."""
    out: list[str] = []
    preskocit = False
    for radek in text.splitlines(keepends=True):
        if not preskocit and radek.startswith(hlavicka):
            preskocit = True
            continue
        if preskocit:
            if radek.startswith("func ") or radek.startswith("# --"):
                preskocit = False
                out.append(radek)
            continue
        out.append(radek)
    return "".join(out)


def _zasad_vadu(kopie: Path, zmeny: list[tuple[str, str, str]]) -> str:
    """Vlozi vadu do kopie a OVERI, ze se opravdu zapsala (ticha mutace lze)."""
    for soubor, hledat, nahradit in zmeny:
        cesta = kopie / soubor
        if not cesta.exists():
            return f"soubor {soubor} v kopii neni"
        text = cesta.read_text(encoding="utf-8")
        if hledat not in text:
            return f"v {soubor} neni '{hledat[:60]}'"
        if nahradit == SMAZ_FUNKCI:
            _prepis(cesta, _odstran_funkci(text, hledat))
        elif nahradit == "":
            _prepis(cesta, text.replace(hledat, "", 1))
        else:
            if nahradit in text:
                return f"vada uz v {soubor} je (mutace by se neprovedla)"
            _prepis(cesta, text.replace(hledat, nahradit, 1))
    # Kontrola PO zapisu: co melo zmizet, zmizelo; co melo vzniknout, existuje.
    for soubor, hledat, nahradit in zmeny:
        text = (kopie / soubor).read_text(encoding="utf-8")
        if nahradit == "" or nahradit == SMAZ_FUNKCI:
            if hledat in text:
                return f"v {soubor} zustalo '{hledat[:60]}' (vada se nezapsala)"
        elif nahradit not in text:
            return f"v {soubor} neni '{nahradit[:60]}' (vada se nezapsala)"
    return ""


def mutace(root: Path) -> int:
    """Sabotovana kopie -> brana MUSI skoncit 1 (jinak je slepa)."""
    if godot_bin() is None:
        print(f"[{NAME}] mutace: NEMERENO - Godot neni k dispozici")
        return NEMERENO
    zaklad = root / ".cache" / "gates" / "loop-mutace"
    chyb = 0
    print(f"[{NAME}] mutace: sabotovane kopie v {zaklad}")
    for jmeno, zmeny in SABOTAZE:
        kopie = zaklad / jmeno
        _postav_kopii(root, kopie)
        problem = _zasad_vadu(kopie, zmeny)
        if problem:
            # Vada, ktera se TISE neprovede, tvrdi totez co vada, ktera projde.
            print(f"[{NAME}] mutace {jmeno}: CHYBA - {problem}")
            chyb += 1
            continue
        try:
            proc = subprocess.run(
                [sys.executable, str(Path(__file__).resolve()), "--root", str(kopie)],
                capture_output=True, text=True, encoding="utf-8", errors="replace",
                timeout=MUTACE_TIMEOUT,
            )
        except subprocess.TimeoutExpired:
            # Visici brana neni "vada, kterou nevidela" - je to chyba mutace.
            print(f"[{NAME}] mutace {jmeno}: CHYBA - brana na kopii visela "
                  f"({MUTACE_TIMEOUT}s)")
            chyb += 1
            continue
        log = zaklad / f"{jmeno}.log"
        log.write_text(proc.stdout + ("\n--- stderr ---\n" + proc.stderr if proc.stderr else ""),
                       encoding="utf-8")
        chyby_brany = [ln for ln in proc.stdout.splitlines() if "CHYBA:" in ln]
        spadla = proc.returncode == VADA
        chyb += 0 if spadla else 1
        print(f"[{NAME}] mutace {jmeno}: brana skoncila exit {proc.returncode}"
              f" ({'SPRAVNE - VADA' if spadla else 'CHYBA - brana vadu NEVIDI'})")
        for radek in chyby_brany[:4]:
            print(f"[{NAME}]   {radek.strip()[:150]}")
        print(f"[{NAME}]   log: {log}")
    print(f"[{NAME}] mutace: {len(SABOTAZE)} sabotaze, {chyb} chyb")
    return VADA if chyb else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="G20 kontrola, že hráč projde krátkou smyčkou")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--mutace", action="store_true",
                    help="sabotovana kopie: brana musi spadnout (exit 1)")
    ap.add_argument("--snimky", action="store_true",
                    help="vizuální důkaz: sonda běží v okně a uloží 3-4 PNG")
    ap.add_argument("--snimky-dir", default=None,
                    help="kam ukládat snímky (výchozí .cache/gates/loop-snimky)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    if args.self_test:
        return selftest()
    if args.mutace:
        return mutace(root)
    snimky = None
    if args.snimky:
        snimky = Path(args.snimky_dir).resolve() if args.snimky_dir else OUT_DIR / "loop-snimky"
    gate = Gate(NAME)
    check(root, gate, snimky)
    if args.json:
        return gate.finish(Path(args.json))
    return gate.finish()


if __name__ == "__main__":
    raise SystemExit(main())
