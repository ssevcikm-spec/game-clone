#!/usr/bin/env python3
"""G21 `check-feel.py` - VADY Z REALNEHO HRANI (ZADANI-28-HRAC, B1-B6).

CO MERI (a proc zrovna takhle)
------------------------------
Pet vad nasel hrac pri hrani (2026-10-19) a zadna z nich neni o systemech
`sim/`: vsechny jsou o tom, co hrac VIDI a NA CO KLIKA:

  B1 animace utoku      - hrac pri utoku ZMIZEL, protoze skupina utoku neni
                          v exportu animaci a `play()` vratilo `ok:false`
  B2 animace tezby      - pri praci se kreslil POSTOJ (zadny pracovni stav)
  B3 klik na stanici    - klik na KRESLENOU kovadlinu poslal dlazdici o 2 pole
                          jinam a interakce selhala ("You see nothing special.")
  B4 zavreni okna       - okno obchodu nemelo zavreni (ani tlacitko, ani klavesu)
  B5 vendor na vyhni    - prodavac stal na jine dlazdici, ale jeho SPRITE se
                          s vyhni prekryval o 799 px^2
  B6 ruda na dlazdici   - po slouceni hromady zustal ve svete "spotrebovany"
                          objekt a kreslil se na dlazdici, kde se tezilo

Brana NEMERI systemy `sim/` primo - pousti sondu `tools/gates/feel_probe.gd`,
ktera jde cestou klienta (`app.input_map.interact_command`/`attack_command`,
skutecne `Button` uzly oken) a kresleni se ptá `app.world_view` na TOTEZ
hodnoty, ktere kresleni opravdu pouziva. Kazda podminka nize je odvozena
z NAMERENE hodnoty, ne z tvaru kodu - proto ji lze splnit jen tim, ze se
chovani opravdu zmeni.

TRI STAVY (docs/08 §8.9): 0 = vse mereno a OK, 1 = VADA, 2 = NEMERENO
(chybi Godot nebo sonda). Nula merenych veci NENI uspech.

POUZITI
-------
    python tools/gates/check-feel.py                 # mereni (headless)
    python tools/gates/check-feel.py --snimky        # vizualni dokaz (okno)
    python tools/gates/check-feel.py --self-test     # offline: znamy dobre/spatne
    python tools/gates/check-feel.py --mutace        # sabotaze: musi spadnout
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import (  # noqa: E402
    NEMERENO, OK, OUT_DIR, VADA, Gate, ensure_import, godot_bin, godot_run,
)

NAME = "check-feel"
PROBE = "res://tools/gates/feel_probe.gd"
ZNACKA = "[feel] SOUHRN "
# Vady, ktere sonda musi zmerit. Chybejici mereni neni "preskocene", je VADA:
# brana ma merit vsech sest, ne tu cast, ktera vysla.
VADY = ("B1_hrac", "B1_cizi", "B2", "B3", "B4", "B4_esc", "B5", "B6")
# Snímky: kazda vizualni vada ma mit svuj obrazek. Pet je minimum, protoze
# B1/B2/B3/B5/B6 se kresli kazda zvlast (B4 je okno).
MIN_SNIMKU = 5
MIN_BYTU = 10_000          # prazdny/cerng snimek se takhle velky nezkomprimuje

SMAZ_FUNKCI = "<SMAZ_FUNKCI>"
MUTACE_TIMEOUT = 900


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


def _cislo(slovnik, klic: str) -> int:
    try:
        return int((slovnik or {}).get(klic, 0))
    except (TypeError, ValueError):
        return 0


def chyby_z_mereni(d: dict, snimky_zadano: bool = False) -> list[str]:
    """Verdikt z jednoho mereni - pouziva ho brana, self-test i mutace.

    Kazda podminka je odvozena z NAMERENE hodnoty. Kdyz sonda neco nezmeri,
    je to VADA (`nemerene`), ne ticho - "0 selhani" nad prazdnym merenim
    je nejhorsi varianta (docs/08 §8.6).
    """
    if not d.get("nalezeno", False):
        return ["ze sondy nelze precist SOUHRN (sonda neprobihla nebo spadla)"]
    data = d["data"]
    chyby: list[str] = []
    if str(data.get("duvod", "")) != "":
        chyby.append("sonda hlasi duvod: " + str(data["duvod"]))
    vysledky = data.get("vysledky")
    if not isinstance(vysledky, dict) or not vysledky:
        return chyby + ["sonda nevratila zadne mereni (nemereno)"]
    for vada in VADY:
        if vada not in vysledky:
            chyby.append(f"{vada}: sonda tuto vadu vubec nemerila")
    for ch in (data.get("nemerene") or []):
        chyby.append("nemereno: " + str(ch))
    if chyby:
        return chyby

    # -- B1: animace utoku hrace -----------------------------------------
    b1 = vysledky.get("B1_hrac", {})
    hrac = b1.get("hrac", {}) if isinstance(b1.get("hrac"), dict) else {}
    v1 = b1.get("vzorky", {}) if isinstance(b1.get("vzorky"), dict) else {}
    if not str(b1.get("anim_of", "")).strip("{ }"):
        chyby.append("B1_hrac: sim.combat.anim_of po utoku nic nevraci "
                     "(utok se vubec nespustil)")
    if not bool(hrac.get("ok", False)):
        chyby.append("B1_hrac: postava pri utoku NEMA sprite "
                     f"(ok={hrac.get('ok')}, skupina {hrac.get('skupina')}, "
                     f"soubor '{hrac.get('soubor')}') - presne to hrac videl jako "
                     "'zadna animace utoku'")
    if not str(hrac.get("soubor", "")):
        chyby.append("B1_hrac: kresleni nevi, z ktereho anim listu utok bere "
                     "(soubor prazdny) - fallback na dostupne framy nefunguje")
    if _cislo(v1, "ruznych_framu") < 2:
        chyby.append(f"B1_hrac: behem okna utoku se nevystridaly aspon 2 framy "
                     f"(namereno {_cislo(v1, 'ruznych_framu')}) - animace neni videt")
    if _cislo(v1, "svih_max") < 1:
        chyby.append("B1_hrac: utok nema kresleny svih (0 ctverecku) - utok by byl "
                     "jen jina chuze")

    # -- B1: animace utoku cizich postav ---------------------------------
    b1c = vysledky.get("B1_cizi", {})
    v1c = b1c.get("vzorky", {}) if isinstance(b1c.get("vzorky"), dict) else {}
    if not bool(b1c.get("ok", False)):
        chyby.append(f"B1_cizi: utok cizi postavy neni videt (serial "
                     f"{b1c.get('serial')}, anim_of {b1c.get('anim_of')})")
    if _cislo(v1c, "ruznych_framu") < 2:
        chyby.append(f"B1_cizi: behem okna utoku se nevystridaly aspon 2 framy "
                     f"(namereno {_cislo(v1c, 'ruznych_framu')})")

    # -- B2: pracovni animace pri tezbe ----------------------------------
    b2 = vysledky.get("B2", {})
    v2 = b2.get("vzorky", {}) if isinstance(b2.get("vzorky"), dict) else {}
    if not bool(b2.get("harvest_anim_of", False)):
        chyby.append("B2: `sim.harvest` nema `anim_of` - pracovni stav neni "
                     "v SIMULACI (klient by si ho musel vymyslet)")
    if not bool(b2.get("pracovni_akce", False)):
        chyby.append("B2: behem prace se nekresli pracovni akce")
    if _cislo(v2, "ruznych_framu") < 2:
        chyby.append(f"B2: behem prace se nevystridaly aspon 2 framy "
                     f"(namereno {_cislo(v2, 'ruznych_framu')})")
    if _cislo(v2, "svih_max") < 1:
        chyby.append("B2: prace nema kresleny svih (0 ctverecku) - hrac by jen stal")

    # -- B3: klik na KRESLENOU stanici -----------------------------------
    b3 = vysledky.get("B3", {})
    if not bool(b3.get("okno_po_kliku_na_obraz", False)):
        chyby.append("B3: klik doprostred KRESLENE kovadliny neotevrel okno vyroby "
                     f"(prikaz {b3.get('prikaz_obraz')}, zurnal "
                     f"{b3.get('zurnal_po_obraz')})")
    if str(b3.get("tile_obraz", "")) != str(b3.get("kovadlina_tile", "?")):
        chyby.append(f"B3: klik na kreslenou kovadlinu poslal dlazdici "
                     f"{b3.get('tile_obraz')}, kovadlina je na "
                     f"{b3.get('kovadlina_tile')} - hit-test kreslenych predmetu "
                     f"nesedi")
    if not bool(b3.get("vytaveno", False)):
        chyby.append(f"B3: klik na kreslenou vyhen nevytavil rudu "
                     f"(ingoty {b3.get('ingot_pred')} -> {b3.get('ingot_po')}, "
                     f"zurnal {b3.get('zurnal_po_vyhni')})")
    if str(b3.get("tile_vyhen", "")) != str(b3.get("vyhen_tile", "?")):
        chyby.append(f"B3: klik na kreslenou vyhen poslal dlazdici "
                     f"{b3.get('tile_vyhen')}, vyhen je na {b3.get('vyhen_tile')}")
    if not bool(b3.get("craft_api_zavri", False)) or not bool(b3.get("craft_tlacitko_close", False)):
        chyby.append("B3/B4: okno vyroby nema zavreni (API a/nebo tlacitko 'Close')")

    # -- B4: zavreni okna obchodu ----------------------------------------
    b4 = vysledky.get("B4", {})
    for klic, popis in (
        ("okno_otevrene", "okno obchodu se vubec neotevrelo"),
        ("api_zavri", "okno nema `zavri()`"),
        ("api_toggle", "okno nema `toggle()`"),
        ("tlacitko_close", "v okne neni tlacitko 'Close'"),
        ("tlacitko_zavrit_uzel", "tlacitko 'Zavrit' neni v uzlech okna"),
        ("signal_zavrit", "tlacitko 'Close' nema pripojeny signal `pressed`"),
        ("zavreno_klikem", "klik na 'Close' okno nezavrel"),
        ("znovu_otevreno", "zavrene okno nejde znovu otevrit"),
    ):
        if not bool(b4.get(klic, False)):
            chyby.append(f"B4: {popis} ({klic}=false)")
    if bool(b4.get("videt_po_zavreni", True)):
        chyby.append("B4: okno je po zavreni porad videt")
    if not bool(b4.get("vstup_odmitnut", False)):
        chyby.append("B4: ZAVRENE okno prijima vstupy (klik neco udelal)")
    # KLAVESA: Escape musi okno zavrit skutecnou UDALOSTI (ne primym volanim).
    b4e = vysledky.get("B4_esc", {})
    if not bool(b4e.get("ui_cancel_v_inputmap", False)):
        chyby.append("B4_esc: `ui_cancel` (Escape) neni v `InputMap`")
    if bool(b4e.get("po_udalosti_otevreno", True)):
        chyby.append("B4_esc: Escape okno nezavrel (udalost nedorazila do "
                     f"`_unhandled_input`; odeslano={b4e.get('odeslano')})")

    # -- B5: prodavac mimo stanici ---------------------------------------
    b5 = vysledky.get("B5", {})
    if bool(b5.get("prodejce_na_stanici", True)):
        chyby.append(f"B5: prodavac stoji NA DLAZDICI stanice "
                     f"(prodejce {b5.get('prodejce_tile')}, vyhen "
                     f"{b5.get('vyhen_tile')}, kovadlina {b5.get('kovadlina_tile')})")
    if _cislo(b5, "kolize_cilu") != 0:
        chyby.append(f"B5: cile interakce se prekryvaji na {_cislo(b5, 'kolize_cilu')} "
                     f"dlazdicich ({b5.get('kolize')})")
    for klic, popis in (("prekryv_vyhen_px", "vyhen"), ("prekryv_kovadlina_px", "kovadlinu")):
        px = b5.get(klic, -1)
        if px is None or int(px) < 0:
            chyby.append(f"B5: prekryv s {popis} se NEMERIL (chybi kresleny obraz)")
        elif int(px) > 0:
            chyby.append(f"B5: prodavac PREKRYVA {popis} o {int(px)} px^2 - hrac to "
                         f"vidi jako 'vendor stoji na vyhni'")

    # -- B6: po tezbe nezustane obrazek na dlazdici -----------------------
    b6 = vysledky.get("B6", {})
    if _cislo(b6, "ruda_po") <= _cislo(b6, "ruda_pred"):
        chyby.append(f"B6: tezba vubec neprinesla rudu ({b6.get('ruda_pred')} -> "
                     f"{b6.get('ruda_po')}) - mereni by bylo o prazdnu")
    if _cislo(b6, "ruda_na_zemi_pocet") != 0:
        chyby.append(f"B6: na zemi je {_cislo(b6, 'ruda_na_zemi_pocet')} obrazku rudy "
                     f"({b6.get('ruda_na_zemi')})")
    if _cislo(b6, "zbytky_pocet") != 0:
        chyby.append(f"B6: na zemi zustaly {_cislo(b6, 'zbytky_pocet')} spotrebovane "
                     f"objekty ({b6.get('zbytky_na_zemi')})")
    if _cislo(b6, "zbytky_v_itemech_pocet") != 0:
        chyby.append(f"B6: v registru predmetu zustalo "
                     f"{_cislo(b6, 'zbytky_v_itemech_pocet')} spotrebovanych objektu "
                     f"(zdroj vady: `sim.harvest._give`)")

    # -- snimky (jen kdyz byly zadane - fail-closed) ----------------------
    if snimky_zadano:
        if not bool(data.get("snimky_zadany", False)):
            chyby.append("snimky: `--snimky` bylo zadano, ale sonda snímky nevykazala")
        if str(data.get("snimky_chyba", "")) != "":
            chyby.append("snimky: sonda hlasi chybu: " + str(data["snimky_chyba"]))
        snimky = [str(s) for s in (data.get("snimky") or [])]
        if len(snimky) < MIN_SNIMKU:
            chyby.append(f"snimky: je jich {len(snimky)}, pozaduje se aspon {MIN_SNIMKU}")
    return chyby


def _png_hlavicka(path: Path) -> tuple[int, int] | None:
    try:
        with path.open("rb") as f:
            hlavicka = f.read(24)
    except OSError:
        return None
    if len(hlavicka) < 24 or hlavicka[:8] != b"\x89PNG\r\n\x1a\n":
        return None
    return (int.from_bytes(hlavicka[16:20], "big"), int.from_bytes(hlavicka[20:24], "big"))


def _cesta_snimku(root: Path, cesta: str) -> Path:
    """`res://` -> cesta na disku. Sonda vraci `res://` (ne souborovou cestu),
    a prvni verze G20 brala `res://...` jako disk misto projektu - vsechny
    snimky "neexistovaly" a brana spadla na spravnem behu (namEReno 2026-10-19).
    """
    if cesta.startswith("res://"):
        return root / cesta[len("res://"):].replace("\\", "/")
    return Path(cesta)


def zkontroluj_snimky(root: Path, cesty: list[str]) -> list[str]:
    """Snimek musi existovat, byt PNG, mit rozumny rozmer a velikost."""
    chyby: list[str] = []
    if len(cesty) < MIN_SNIMKU:
        return [f"snimku je {len(cesty)}, pozaduje se aspon {MIN_SNIMKU}"]
    rozliseni = set()
    for cesta in cesty:
        p = _cesta_snimku(root, cesta)
        if not p.exists():
            chyby.append(f"snimek {cesta} neexistuje (hledano {p})")
            continue
        velikost = p.stat().st_size
        if velikost < MIN_BYTU:
            chyby.append(f"snimek {p.name} ma {velikost} B (pod {MIN_BYTU}) - "
                         f"prazdny obraz")
        h = _png_hlavicka(p)
        if h is None:
            chyby.append(f"snimek {p.name} neni PNG")
            continue
        if h[0] < 320 or h[1] < 240:
            chyby.append(f"snimek {p.name} ma rozmer {h[0]}x{h[1]} (moc maly)")
        rozliseni.add(h)
    if len(rozliseni) > 1:
        chyby.append(f"snimky maji ruzna rozliseni {sorted(rozliseni)}")
    return chyby


def _vystup_pro_gate(gate: Gate, d: dict) -> None:
    data = d["data"]
    vysledky = data.get("vysledky", {})
    gate.measure("vad", len(vysledky))
    for vada in VADY:
        z = vysledky.get(vada, {})
        gate.measure(vada, "MERENO" if z else "NEMERENO")
        if vada == "B1_hrac":
            v = z.get("vzorky", {})
            gate.note(f"B1 hrac: akce {z.get('hrac', {}).get('action')}, "
                      f"fallback {z.get('hrac', {}).get('fallback')}, "
                      f"list {z.get('hrac', {}).get('soubor')}, framy "
                      f"{v.get('ruznych_framu')}, svih {v.get('svih_max')}")
        elif vada == "B1_cizi":
            v = z.get("vzorky", {})
            gate.note(f"B1 cizi: serial {z.get('serial')}, telo "
                      f"{z.get('klip', {}).get('telo')}, framy {v.get('ruznych_framu')}, "
                      f"svih {v.get('svih_max')}")
        elif vada == "B2":
            v = z.get("vzorky", {})
            gate.note(f"B2: harvest.anim_of {z.get('harvest_anim_of')}, pracovni akce "
                      f"{z.get('pracovni_akce')}, framy {v.get('ruznych_framu')}, "
                      f"svih {v.get('svih_max')}, ruda {z.get('ruda_pred')} -> "
                      f"{z.get('ruda_po')}")
        elif vada == "B3":
            gate.note(f"B3: klik na obraz -> dlazdice {z.get('tile_obraz')} "
                      f"(stanice {z.get('kovadlina_tile')}), okno "
                      f"{z.get('okno_po_kliku_na_obraz')}, vyhen -> "
                      f"{z.get('tile_vyhen')} (stanice {z.get('vyhen_tile')}), "
                      f"ingoty {z.get('ingot_pred')} -> {z.get('ingot_po')}")
        elif vada == "B4":
            gate.note(f"B4: okno {z.get('okno_otevrene')}, api_zavri {z.get('api_zavri')}, "
                      f"tlacitko {z.get('tlacitko_close')}, signal {z.get('signal_zavrit')}, "
                      f"zavreno {z.get('zavreno_klikem')}, vstup odmitnut "
                      f"{z.get('vstup_odmitnut')}, znovu {z.get('znovu_otevreno')}")
        elif vada == "B4_esc":
            gate.note(f"B4 esc: ui_cancel {z.get('ui_cancel_v_inputmap')}, po udalosti "
                      f"otevreno {z.get('po_udalosti_otevreno')}")
        elif vada == "B5":
            gate.note(f"B5: prodejce {z.get('prodejce_tile')} na stanici "
                      f"{z.get('prodejce_na_stanici')}, kolize {z.get('kolize_cilu')}, "
                      f"prekryv vyhen {z.get('prekryv_vyhen_px')} px^2, kovadlina "
                      f"{z.get('prekryv_kovadlina_px')} px^2")
        elif vada == "B6":
            gate.note(f"B6: ruda {z.get('ruda_pred')} -> {z.get('ruda_po')}, na zemi "
                      f"{z.get('ruda_na_zemi_pocet')} rudy, zbytky "
                      f"{z.get('zbytky_pocet')} / v registru "
                      f"{z.get('zbytky_v_itemech_pocet')}")
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
    sonda = root / "tools" / "gates" / "feel_probe.gd"
    if not sonda.exists():
        gate.pending(f"chybi sonda {sonda.relative_to(root).as_posix()} - neni co merit")
        return
    if godot_bin() is None:
        gate.skip("Godot neni k dispozici (nastav $GODOT nebo dodеj binarku do .cache/godot)")
        return
    args = ["--fixed-fps", "60", "--script", PROBE]
    if snimky_dir is None:
        rc, output = godot_run(root, args, timeout=900)
    else:
        cil = snimky_dir / "feel"
        cil.mkdir(parents=True, exist_ok=True)
        for stary in cil.glob("*.png"):
            stary.unlink()
        try:
            relativni = cil.resolve().relative_to(root.resolve()).as_posix()
        except ValueError:
            gate.error(f"adresar snimku {cil} neni uvnitr projektu - res:// ho nevidi")
            return
        rc, output = _godot_okno(root, args + ["--", f"--snimky=res://{relativni}"],
                                 timeout=900)
    d = vyhodnot(output)
    gate.measure("probe_exit", rc)
    if not d.get("nalezeno", False):
        gate.error(f"ze sondy nelze precist SOUHRN (exit {rc})")
        for line in output.splitlines()[-6:]:
            gate.note(line.strip()[:160])
        return
    _vystup_pro_gate(gate, d)
    chyby = chyby_z_mereni(d, snimky_zadano=snimky_dir is not None)
    for ch in chyby:
        gate.error(ch)
    if snimky_dir is not None:
        snimky = [str(s) for s in (d["data"].get("snimky") or [])]
        for ch in zkontroluj_snimky(root, snimky):
            gate.error(ch)
    else:
        gate.measure("snimky", "nemereno (headless nema viewport texturu)")
        gate.note("snimky: NEMERENO (headless) - vizualni dokaz dela "
                  "`check-feel.py --snimky`; vady se meri i tak")
    # `probe_exit` se cte i pri chybach: sonda muze skoncit nenulove a pritom
    # neco namerit (leaky RID na konci) - proto se chyby hlasí vys, ale
    # vystup se cte dal (stejna praxe jako u G20).


def selftest() -> int:
    """Znamy spravny i znamy chybny vstup - offline, bez Godotu.

    Kazda podminka verdiktu ma tady svuj "spatny" protipriklad: kdyby sla
    podminka splnit i vadou, self-test to ukaze jako chybu.
    """
    dobry = {
        "duvod": "", "nemerene": [], "snimky_zadany": False, "snimky": [],
        "snimky_chyba": "",
        "vysledky": {
            "B1_hrac": {
                "anim_of": '{ "action": 2, "left_ms": 350, "total_ms": 400 }',
                "hrac": {"ok": True, "action": 2, "fallback": True, "skupina": 0,
                         "soubor": "res://assets/own-v3/anim/ownv3-400-0-1.png"},
                "ok_hrac": True,
                "vzorky": {"ruznych_framu": 7, "ruznych_akci": 1, "svih_max": 8},
                "ok": True,
            },
            "B1_cizi": {"serial": 27, "anim_of": '{ "action": 2, "left_ms": 200 }',
                        "ok": True,
                        "klip": {"ok": True, "telo": 238, "fallback": False},
                        "vzorky": {"ruznych_framu": 4, "svih_max": 0}},
            "B2": {"harvest_anim_of": True, "pracovni_akce": True,
                   "ruda_pred": 0, "ruda_po": 1, "ok": True,
                   "vzorky": {"ruznych_framu": 8, "svih_max": 4}},
            "B3": {"okno_po_kliku_na_obraz": True, "okno_po_kliku_na_dlazdici": True,
                   "tile_obraz": "1495,1631", "kovadlina_tile": "1495,1631",
                   "tile_vyhen": "1496,1630", "vyhen_tile": "1496,1630",
                   "ingot_pred": 0, "ingot_po": 6, "vytaveno": True,
                   "craft_api_zavri": True, "craft_tlacitko_close": True, "ok": True},
            "B4": {"okno_otevrene": True, "api_zavri": True, "api_toggle": True,
                   "tlacitko_close": True, "tlacitko_zavrit_uzel": True,
                   "signal_zavrit": True, "zavreno_klikem": True,
                   "videt_po_zavreni": False, "vstup_odmitnut": True,
                   "znovu_otevreno": True, "ok": True},
            "B4_esc": {"ui_cancel_v_inputmap": True, "odeslano": True,
                       "po_udalosti_otevreno": False, "ok": True},
            "B5": {"prodejce_na_stanici": False, "kolize_cilu": 0, "kolize": [],
                   "prekryv_vyhen_px": 0, "prekryv_kovadlina_px": 0, "ok": True},
            "B6": {"ruda_pred": 1, "ruda_po": 7, "ruda_na_zemi_pocet": 0,
                   "zbytky_pocet": 0, "zbytky_v_itemech_pocet": 0, "ok": True},
        },
    }

    def kopie():
        return json.loads(json.dumps(dobry))

    testy: list[tuple[str, dict]] = []

    # 1) znamy spravny vstup -> zadna chyba
    testy.append(("dobry", {"nalezeno": True, "data": kopie()}))

    # 2) kazda vada musi branu shodit (jinak je podminka slepa)
    vady: list[tuple[str, callable]] = [
        ("B1 bez sprite", lambda d: d["data"]["vysledky"]["B1_hrac"]["hrac"].update({"ok": False})),
        ("B1 bez fallbacku", lambda d: d["data"]["vysledky"]["B1_hrac"]["hrac"].update({"soubor": ""})),
        ("B1 jeden frame", lambda d: d["data"]["vysledky"]["B1_hrac"]["vzorky"].update({"ruznych_framu": 1})),
        ("B1 bez svihu", lambda d: d["data"]["vysledky"]["B1_hrac"]["vzorky"].update({"svih_max": 0})),
        ("B1 cizi bez framu", lambda d: d["data"]["vysledky"]["B1_cizi"]["vzorky"].update({"ruznych_framu": 1})),
        ("B2 bez anim_of", lambda d: d["data"]["vysledky"]["B2"].update({"harvest_anim_of": False})),
        ("B2 bez svihu", lambda d: d["data"]["vysledky"]["B2"]["vzorky"].update({"svih_max": 0})),
        ("B3 okno neotevrene", lambda d: d["data"]["vysledky"]["B3"].update({"okno_po_kliku_na_obraz": False})),
        ("B3 spatna dlazdice", lambda d: d["data"]["vysledky"]["B3"].update({"tile_obraz": "1497,1631"})),
        ("B3 nevytaveno", lambda d: d["data"]["vysledky"]["B3"].update({"vytaveno": False})),
        ("B4 bez tlacitka", lambda d: d["data"]["vysledky"]["B4"].update({"tlacitko_close": False})),
        ("B4 zavrene prijima vstup", lambda d: d["data"]["vysledky"]["B4"].update({"vstup_odmitnut": False})),
        ("B4 nejde znovu otevrit", lambda d: d["data"]["vysledky"]["B4"].update({"znovu_otevreno": False})),
        ("B4 esc nezavrel", lambda d: d["data"]["vysledky"]["B4_esc"].update({"po_udalosti_otevreno": True})),
        ("B5 na stanici", lambda d: d["data"]["vysledky"]["B5"].update({"prodejce_na_stanici": True})),
        ("B5 prekryv", lambda d: d["data"]["vysledky"]["B5"].update({"prekryv_vyhen_px": 799})),
        ("B5 nemereno", lambda d: d["data"]["vysledky"]["B5"].update({"prekryv_vyhen_px": -1})),
        ("B6 ruda na zemi", lambda d: d["data"]["vysledky"]["B6"].update({"ruda_na_zemi_pocet": 1})),
        ("B6 zbytky", lambda d: d["data"]["vysledky"]["B6"].update({"zbytky_pocet": 5})),
        ("B6 zbytky v registru", lambda d: d["data"]["vysledky"]["B6"].update({"zbytky_v_itemech_pocet": 5})),
        ("B6 bez tezby", lambda d: d["data"]["vysledky"]["B6"].update({"ruda_po": 0, "ruda_pred": 0})),
        ("chybi mereni", lambda d: d["data"]["vysledky"].pop("B5")),
        ("sonda nic nenahlasila", lambda d: d.update({"nalezeno": False})),
        ("snimky zadane, ale nejsou", lambda d: d["data"].update({"snimky_chyba": "headless"})),
    ]
    for jmeno, zmena in vady:
        v = {"nalezeno": True, "data": kopie()}
        zmena(v)
        testy.append(("vada: " + jmeno, v))

    chyb = 0
    for jmeno, vstup in testy:
        chyby = chyby_z_mereni(vstup, snimky_zadano=("snimky" in jmeno))
        cekano_chyba = jmeno != "dobry"
        if cekano_chyba and not chyby:
            print(f"[{NAME}] self-test {jmeno}: CHYBA - brana vadu NEVIDI")
            chyb += 1
        elif not cekano_chyba and chyby:
            print(f"[{NAME}] self-test {jmeno}: CHYBA - brana hlasi vadu na spravnem "
                  f"vstupu: {chyby[:2]}")
            chyb += 1
        else:
            print(f"[{NAME}] self-test {jmeno}: OK "
                  f"({'vada nalezena' if cekano_chyba else 'bez chyby'})")
    print(f"[{NAME}] self-test: {len(testy)} pripadu, {chyb} chyb")
    return VADA if chyb else OK


# -- mutace: sabotovana kopie --------------------------------------------------
#
# Kazda sabotaz vrati JEDNU vadu, kterou hrac nasel - a brana ji musi videt
# (`exit 1`). Kdyz se vada nezapise, je to chyba mutace (ticha mutace tvrdi
# totez co mutace, ktera projde).

MUTACE: list[tuple[str, list[tuple[str, str, str]]]] = [
    # B1: zadny fallback na dostupne framy -> utok nema sprite (hrac zmizi).
    ("B1_bez_fallbacku", [(
        "render/anim_player.gd",
        '\tACTION_ATTACK: ["attack", "walk"],\n\tACTION_WORK: ["attack", "walk"],\n',
        "",
    )]),
    # B2: pracovni okno se nenastavi -> kresli se postoj.
    ("B2_bez_prace", [(
        "sim/systems/harvest.gd",
        '\t_pracuj(m, int(p["swing_ms"]))',
        "\tpass",
    )]),
    # B3: klient posila geometrickou dlazdici (zpet pred opravou hit-testu).
    ("B3_bez_hit_testu", [(
        "app/main.gd",
        "\t\tloop.input_map.hit_test = view.co_je_na_screen",
        "\t\tpass",
    )]),
    # B4: okno obchodu nema tlacitko "Close".
    ("B4_bez_zavreni", [(
        "ui/vendor_gump.gd",
        "\tvisible = false\n\t_ensure_close()",
        "\tvisible = false",
    )]),
    # B4: klavesa Escape okno nezavre.
    ("B4_bez_klavesy", [(
        "app/main.gd",
        "\tif _zavri_okna() > 0:\n\t\tget_viewport().set_input_as_handled()",
        "\tif false:\n\t\tget_viewport().set_input_as_handled()",
    )]),
    # B5: prodavac zpet na dlazdici vedle vyhne (sprite se prekryva).
    ("B5_vendor_na_vyhni", [(
        "app/main.gd",
        "\tvar pos := Vector3i(int(player.pos.x) + 1, int(player.pos.y) - 1,",
        "\tvar pos := Vector3i(int(player.pos.x) + 2, int(player.pos.y),",
    )]),
    # B6: spotrebovany objekt se zaregistruje -> kresli se ruda na dlazdici.
    ("B6_duch_rudy", [(
        "sim/systems/harvest.gd",
        "\tif int(item.amount) <= 0:\n\t\titem = _hromada_v_batohu(mob, item)",
        "\tif false:\n\t\titem = _hromada_v_batohu(mob, item)",
    )]),
]

KOPIRUJ = ("app", "core", "sim", "ui", "render", "data", "assets", "tools/gates", ".godot")


def _postav_kopii(root: Path, cil: Path) -> None:
    """Kopie projektu s HARD LINKY (data se nekopiruji, jen jmena).

    Hardlink je jen na cteni: kdo chce soubor zmenit, musi ho nejdriv odpojit
    (`_prepis`), jinak by zmenil ORIGINAL.
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


def _zasad_vadu(kopie: Path, zmeny: list[tuple[str, str, str]]) -> str:
    """Vlozi vadu do kopie a OVERI, ze se opravdu zapsala (ticha mutace lze)."""
    for soubor, hledat, nahradit in zmeny:
        cesta = kopie / soubor
        if not cesta.exists():
            return f"soubor {soubor} v kopii neni"
        text = cesta.read_text(encoding="utf-8")
        if hledat not in text:
            return f"v {soubor} neni '{hledat[:70]}'"
        if cesta.exists():
            cesta.unlink()
        cesta.write_text(text.replace(hledat, nahradit, 1), encoding="utf-8", newline="\n")
    for soubor, hledat, nahradit in zmeny:
        text = (kopie / soubor).read_text(encoding="utf-8")
        if hledat in text:
            return f"v {soubor} zustalo '{hledat[:70]}' (vada se nezapsala)"
        if nahradit != "" and nahradit not in text:
            return f"v {soubor} neni '{nahradit[:70]}' (vada se nezapsala)"
    return ""


def mutace(root: Path) -> int:
    """Sabotovana kopie -> brana MUSI skoncit 1 (jinak je slepa)."""
    if godot_bin() is None:
        print(f"[{NAME}] mutace: NEMERENO - Godot neni k dispozici")
        return NEMERENO
    zaklad = root / ".cache" / "gates" / "feel-mutace"
    chyb = 0
    print(f"[{NAME}] mutace: sabotovane kopie v {zaklad}")
    for jmeno, zmeny in MUTACE:
        kopie = zaklad / jmeno
        _postav_kopii(root, kopie)
        problem = _zasad_vadu(kopie, zmeny)
        if problem:
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
    print(f"[{NAME}] mutace: {len(MUTACE)} sabotaze, {chyb} chyb")
    return VADA if chyb else OK


def main() -> int:
    ap = argparse.ArgumentParser(
        description="G21 kontrola vad z realneho hrani (animace utoku/prace, klik na "
                    "kreslenou stanici, zavreni okna, vendor mimo vyhen, ruda na dlazdici)")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--mutace", action="store_true",
                    help="sabotovana kopie: brana musi spadnout (exit 1)")
    ap.add_argument("--snimky", action="store_true",
                    help="vizualni dokaz: sonda bezi v okne a ulozi snimky")
    ap.add_argument("--snimky-dir", default=None,
                    help="kam ukladat snimky (vychozi .cache/gates/feel-snimky)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    if args.self_test:
        return selftest()
    if args.mutace:
        return mutace(root)
    snimky = None
    if args.snimky:
        snimky = Path(args.snimky_dir).resolve() if args.snimky_dir else OUT_DIR / "feel-snimky"
    gate = Gate(NAME)
    check(root, gate, snimky)
    if args.json:
        return gate.finish(Path(args.json))
    return gate.finish()


if __name__ == "__main__":
    raise SystemExit(main())
