#!/usr/bin/env python3
"""F1 check-world-clock - "svet ma vlastni cas" (docs/08 §8.2, milnik MK).

Co meri (pet kontrol, headless, NULA prikazu od hrace):

  K1 svet se hybe bez hrace    - hash se zmeni A dobeh naplanuje casove udalosti
                                 (samotny posun hodin by "hýbal světem" i tak,
                                 ze se nic nedeje - proto se meri oboji)
  K2 je to reprodukovatelne    - tyz seed a tyz vstup dvakrat = tyz hash
  K3 neni to simulace agentu   - agentni systemy se behem dobehu NEtiknou,
                                 a ve svete pritom entity JSOU (bez nich by
                                 kontrola merila prazdno); navic plati strop
                                 dobehu
  K4 dobeh je idempotentni     - druhy dobeh na tyz cas nic nemeni a poprve se
                                 cas pricte PRESNE jednou (ne dvakrat)
  K5 nezalezi na davkovani     - jednim krokem == po hernich hodinach

Tri stavy: `0` mereno OK, `1` vada, `2` NEMERENO (`sim/offline.gd` neexistuje).
`2` se nikdy netvari jako zelena (`docs/08 §8.9`).

Bez assetu: dobeh se meri na FIXTURE mape (`tests/fixtures/world/map0`), takze
v CI - kde `assets/uo/` neni - brana MERI, misto aby hlasila NEMERENO.

Mutace (`--mutace`): pet vad, z nichz kazda MUSI tuhle branu shodit. Mutuje se
KOPIE v `.cache/gates/mutace/f1/` (original se nesmi zmenit - na konci se to
overi hashem) a cesty k mutantum jdou do probe jako VSTUP
(`--offline-script=`, `--world-script=`), takze se meri opravdu mutant.

Spousteni:
  python tools/gates/check-world-clock.py [--root .] [--json cesta]
  python tools/gates/check-world-clock.py --self-test   # offline fixtury
  python tools/gates/check-world-clock.py --mutace      # dukaz, ze umi selhat
"""

from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, Gate, selftest_cli  # noqa: E402
from sim_gates import run_probe, sim_pending  # noqa: E402

NAME = "check-world-clock"
OFFLINE = "sim/offline.gd"
WORLD = "sim/sim_world.gd"
MAP_SCRIPT = "res://sim/world/map.gd"
MAP_PREFIX = "res://tests/fixtures/world/map0"

HOURS = 720              # 30 hernich dni (1 herni hodina = 300 s casu)
START = 1700000000
MOBILES = 200            # entity ve svete: kontrola 3 bez nich meri prazdno
MAX_AGENT_TICKS = 500    # rozpocet na agenty behem dobehu (radove stovky)
MIN_MOBILES = 100

KLICE = (
    "hash_start", "hash_end", "events", "steps", "agent_ticks", "agent_systemu",
    "advanced_ms", "expected_ms", "mobiles", "map_blocks", "events_total",
    "pending", "hash_again", "events_again", "hash_batch", "events_batch",
    "agent_ticks_batch", "hash_after_first", "hash_repeat", "advanced_ms_repeat",
    "capped", "advanced_capped_ms", "cap_ms",
)

# (popis, klic souboru, presny text ve zdroji, cim se nahradi, ktera kontrola to ma chytit)
MUTACE = [
    ("M1 dobeh se vubec neprovede (prazdna funkce)",
     "offline",
     "\tvar from_ms: int = int(_world.world_time())",
     "\tvar from_ms: int = int(_world.world_time())\n\treturn _empty_report(0)",
     "K1"),
    # ⚠ POZOR (namEReno pri psani teto brany): nahodna hodnota v PAYLOADU
    # naplanovane udalosti se nechyti - udalost se v dobehu vyrize a z planovace
    # zmizi, takze se do hashe vubec nedostane. Mutace proto planuje nahodnou
    # BUDOUCI udalost: ta v planovaci zustane, a dva behy se rozejdou.
    ("M2 do dobehu vstoupi randf() (stav zavisi na nahode)",
     "offline",
     '\t\t\t\t{"why": str(row["why"]), "map_blocks": blocks})',
     '\t\t\t\t{"why": str(row["why"]), "map_blocks": blocks})\n'
     '\t\t\tscheduler.schedule("noise", target + 1 + int(randf() * 1000), {})',
     "K2"),
    ("M3 dobeh tikne VSECHNY systemy (simulace agentu)",
     "world",
     "\t_clock.advance(ms)\n\tvar out: Array[Dictionary] = []",
     "\t_clock.advance(ms)\n\tfor name in SYSTEM_ORDER:\n\t\tif systems.has(name):\n"
     "\t\t\t_tick_system(systems[name], ms)\n\tvar out: Array[Dictionary] = []",
     "K3"),
    ("M4 cas se pricte dvakrat (dobeh neni absolutni)",
     "offline",
     "_world.advance_offline(to_ms - current)", "_world.advance_offline(to_ms)",
     "K4"),
    ("M5 dobeh se pocita od aktualniho casu, ne absolutne (zavisi na davkach)",
     "offline",
     "var at: int = (from_ms / every + 1) * every", "var at: int = from_ms + every",
     "K5"),
]


def _cislo(values: dict[str, str], klic: str):
    """Hodnota z probe jako int, nebo None - `None` znamena NEMERENO, ne nulu."""
    try:
        return int(str(values[klic]).strip())
    except (KeyError, TypeError, ValueError):
        return None


def evaluate(gate: Gate, values: dict[str, str]) -> None:
    """Pet kontrol. `values` je strojovy vystup probe (`PROBE klic=hodnota`)."""
    chybejici = [k for k in KLICE if k not in values]
    if chybejici:
        gate.error("probe nevratil %d z %d hodnot (%s) - kontroly NEMERENY"
                   % (len(chybejici), len(KLICE), ", ".join(chybejici[:5])))
        return
    for klic in KLICE:
        gate.measure(klic, values[klic])

    # K1: svet se hybe bez hrace (a je to VIDET, ne jen posun hodin)
    if values["hash_end"] == values["hash_start"]:
        gate.error("K1 svet se bez hrace nehybe: hash pred == hash po (%s)"
                   % values["hash_start"][:12])
    if (_cislo(values, "events") or 0) < 1:
        gate.error("K1 dobeh nenaplanoval zadnou casovou udalost (events=%s) - "
                   "hash se zmenil jen posunem hodin" % values["events"])
    if (_cislo(values, "steps") or 0) < 1:
        gate.error("K1 dobeh neudelal ani jeden krok (steps=%s)" % values["steps"])

    # K2: reprodukovatelnost
    if values["hash_end"] != values["hash_again"]:
        gate.error("K2 dva stejne behy se rozejdou (%s vs %s) - dobeh neni "
                   "reprodukovatelny" % (values["hash_end"][:12], values["hash_again"][:12]))
    if values["events"] != values["events_again"]:
        gate.error("K2 dva stejne behy naplanuji jiny pocet udalosti (%s vs %s)"
                   % (values["events"], values["events_again"]))

    # K3: neni to simulace agentu (a kontrola neni prazdna) + strop
    if (_cislo(values, "mobiles") or 0) < MIN_MOBILES:
        gate.error("K3 ve svete je %s entit, cekano >= %d - kontrola 'netika cely "
                   "svet' by merila prazdno" % (values["mobiles"], MIN_MOBILES))
    if (_cislo(values, "agent_systemu") or 0) < 1:
        gate.error("K3 probe nezaregistroval zadny agentni system (agent_systemu=%s)"
                   % values["agent_systemu"])
    agentu = _cislo(values, "agent_ticks")
    if agentu is None or agentu > MAX_AGENT_TICKS:
        gate.error("K3 dobeh tiknul agenty %s x (rozpocet %d) - mimo obrazovku se "
                   "simuluje cely svet" % (values["agent_ticks"], MAX_AGENT_TICKS))
    if _cislo(values, "capped") != 1:
        gate.error("K3 rocni absence se nedobehla po strop (capped=%s)"
                   % values["capped"])
    if _cislo(values, "advanced_capped_ms") != _cislo(values, "cap_ms"):
        gate.error("K3 strop dobehu nesedi: %s != %s"
                   % (values["advanced_capped_ms"], values["cap_ms"]))

    # K4: idempotence (a cas se pricte presne jednou)
    if _cislo(values, "advanced_ms") != _cislo(values, "expected_ms"):
        gate.error("K4 dobeh se netrefil na cil: %s ms != %s ms"
                   % (values["advanced_ms"], values["expected_ms"]))
    if values["hash_repeat"] != values["hash_after_first"]:
        gate.error("K4 druhy dobeh na tyz cas zmenil stav (%s vs %s)"
                   % (values["hash_after_first"][:12], values["hash_repeat"][:12]))
    if _cislo(values, "advanced_ms_repeat") != 0:
        gate.error("K4 druhy dobeh na tyz cas posunul hodiny o %s ms"
                   % values["advanced_ms_repeat"])

    # K5: nezalezi na davkovani
    if values["hash_batch"] != values["hash_end"]:
        gate.error("K5 dobeh po davkach da jiny hash nez jednim krokem (%s vs %s)"
                   % (values["hash_batch"][:12], values["hash_end"][:12]))
    if values["events_batch"] != values["events_total"]:
        gate.error("K5 po davkach se naplanuje jiny pocet udalosti (%s vs %s)"
                   % (values["events_batch"], values["events_total"]))
    if (_cislo(values, "agent_ticks_batch") or 0) > MAX_AGENT_TICKS:
        gate.error("K5 davkovany dobeh tiknul agenty %s x (rozpocet %d)"
                   % (values["agent_ticks_batch"], MAX_AGENT_TICKS))


def _args(root: Path, offline: str, world: str) -> list[str]:
    return [
        f"--offline-script={offline}",
        f"--world-script={world}",
        f"--map-script={MAP_SCRIPT}",
        f"--map-prefix={MAP_PREFIX}",
        f"--hours={HOURS}",
        f"--start={START}",
        f"--mobiles={MOBILES}",
    ]


def check(root: Path, gate: Gate) -> None:
    if not (root / OFFLINE).exists():
        gate.pending(
            f"chybí {OFFLINE} (granule sim.offline) - dobeh sveta neexistuje; "
            "AŽ BUDE, tato brána spustí sim_probe.gd --mode=offline a změří "
            "skutečný doběh")
        return
    if sim_pending(root, gate):
        return
    rc, _, values = run_probe(root, "offline", _args(root, "res://" + OFFLINE,
                                                     "res://" + WORLD))
    gate.measure("exit_kod", rc)
    if rc != 0 and not values:
        gate.error(f"probe skoncil s exit {rc} a bez vystupu - dobeh NEMEREN")
        return
    evaluate(gate, values)


def _mereni(root: Path, jmeno: str, offline: str, world: str):
    """Spusti probe nad danymi cestami a vrati (gate, values, exit kod)."""
    rc, output, values = run_probe(root, "offline", _args(root, offline, world))
    gate = Gate(jmeno)
    gate.measure("exit_kod", rc)
    evaluate(gate, values)
    return gate, values, output


def _sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def _uri(root: Path, cesta: Path) -> str:
    return "res://" + cesta.relative_to(root).as_posix()


def _bez_class_name(text: str) -> str:
    """Kopie pro mutaci NESMI mit `class_name`.

    NAMERENO 2026-10-09 pri psani teto brany: kopie `sim/sim_world.gd` se
    `class_name SimWorld` se neda nacist -
    `Parse Error: Class "SimWorld" hides a global script class` - takze by
    "mutace spadla" z duvodu, ktery s merenou vadou nema nic spolecneho
    (a ani baseline by neprosel). `class_name` se proto v KOPII odstrani:
    probe skript nacita CESTou, ne jmenem tridy, takze se chovani nemeni.
    """
    return "\n".join(radek for radek in text.splitlines()
                     if not radek.startswith("class_name "))


def mutace(root: Path) -> int:
    """Dukaz, ze brana umi selhat: pet vad, kazda musi shodit svou kontrolu."""
    zdroje = {
        "offline": (root / OFFLINE).read_text(encoding="utf-8"),
        "world": (root / WORLD).read_text(encoding="utf-8"),
    }
    hashe = {k: _sha(v) for k, v in zdroje.items()}
    cil = root / ".cache" / "gates" / "mutace" / "f1"
    cil.mkdir(parents=True, exist_ok=True)
    cesta = {"offline": cil / "offline.gd", "world": cil / "world.gd"}

    def _zapis_originaly() -> None:
        for klic, soubor in cesta.items():
            soubor.write_text(_bez_class_name(zdroje[klic]), encoding="utf-8")

    _zapis_originaly()
    offline_uri = _uri(root, cesta["offline"])
    world_uri = _uri(root, cesta["world"])

    # 0) BASELINE: kopie originalu musi projit - bez toho by "mutace spadla"
    #    neznamenalo vubec nic.
    base, values, output = _mereni(root, f"{NAME}/mutace:baseline", offline_uri, world_uri)
    print(f"[{NAME}] mutace baseline: exit {base.verdict()}, hodnot {len(values)}")
    if base.verdict() != OK:
        print(f"[{NAME}] CHYBA: baseline (kopie originalu) neprosel:")
        for e in base.errors:
            print(f"[{NAME}]   {e}")
        print(output[-2000:])
        return 2

    # 0b) SMLOUVA O VSTUPU: neexistujici cesta MUSI mereni shodit (jinak probe
    #     bezi nad vychozim souborem a mutace by "prochazely").
    smlouva = True
    for klic, spatna in (("offline", "res://.cache/gates/mutace/f1/neexistuje.gd"),
                         ("world", "res://.cache/gates/mutace/f1/neexistuje.gd")):
        g, vals, _ = _mereni(root, f"{NAME}/mutace:smlouva-{klic}",
                             spatna if klic == "offline" else offline_uri,
                             spatna if klic == "world" else world_uri)
        ok = g.verdict() != OK
        smlouva = smlouva and ok
        print(f"[{NAME}] mutace smlouva vstupu ({klic}): neexistujici cesta -> "
              f"{'mereni selhalo (spravne)' if ok else 'PROBE POUZIL JINY SOUBOR - CHYBA'}"
              f" | hodnot {len(vals)}")

    vysledek = []
    for nazev, klic, stare, nove, kontrola in MUTACE:
        puvodni = zdroje[klic]
        if stare not in puvodni:
            print(f"[{NAME}] mutace {kontrola}: {nazev}: PATRANA VETA SE VE ZDROJI "
                  "NENASLA - mutace se neprovedla, nepocita se")
            vysledek.append((nazev, kontrola, False, False, ""))
            continue
        _zapis_originaly()
        mutant = puvodni.replace(stare, nove, 1)
        cesta[klic].write_text(_bez_class_name(mutant), encoding="utf-8")
        provedena = (mutant != puvodni
                     and cesta[klic].read_text(encoding="utf-8") == _bez_class_name(mutant))
        gate, vals, output = _mereni(root, f"{NAME}/mutace:{nazev}",
                                     offline_uri, world_uri)
        # PROBEHLALA = probe vratil VSECHNY hodnoty. Kdyz jich cast chybi, probe
        # spadl uprostred - a to NENI chycena mutace (brana by mela merit dal).
        probehla = all(k in vals for k in KLICE)
        sve = [e for e in gate.errors if e.startswith(kontrola)]
        # CHYCENA = mutace se opravdu provedla, probe dosel do konce a VADU
        # nasla KONTROLA, kvuli ktere mutace existuje. "Spadlo to nejak" nestaci:
        # jinak by se za dukaz dal vydavat i parse error mutanta.
        chycena = provedena and probehla and gate.verdict() == VADA and bool(sve)
        poznamka = sve[0][:110] if sve else (
            gate.errors[0][:110] if gate.errors else "bez chyby")
        vysledek.append((nazev, kontrola, provedena, chycena, poznamka))
        print(f"[{NAME}] mutace {kontrola}: {nazev}\n"
              f"          PROVEDENA {'ano' if provedena else 'NE'} ({_sha(mutant)}) | "
              f"PROBEHLALA {'ano' if probehla else 'NE'} (exit {gate.measured.get('exit_kod')}) | "
              f"{'CHYCENA' if chycena else 'NECHYCENA'}\n"
              f"          chytila kontrola {kontrola}: "
              f"{'ANO' if sve else 'NE'} | {poznamka}")
        if not probehla:
            for radek in output.splitlines()[-6:]:
                print(f"          probe: {radek.strip()[:150]}")

    zmenene = [k for k in zdroje
               if _sha((root / (OFFLINE if k == "offline" else WORLD)).read_text(
                   encoding="utf-8")) != hashe[k]]
    if zmenene:
        print(f"[{NAME}] CHYBA: original se zmenil u {', '.join(zmenene)} - "
              "mutuje se jen kopie, toto je vada nastroje")
        return 2

    chycene = sum(1 for _, _, p, c, _ in vysledek if p and c)
    slepe = [f"{k}/{n}" for n, k, p, c, _ in vysledek if not (p and c)]
    print(f"\n[{NAME}] mutace: {chycene} z {len(vysledek)} chyceno"
          + (f"; NECHYCENE: {', '.join(slepe)}" if slepe else "")
          + f"; smlouva vstupu: {'OK' if smlouva else 'CHYBA'}")
    return 0 if (not slepe and smlouva) else 1


def selftest() -> int:
    """Offline fixtury: znamy spravny i znamy vadny vstup pro KAZDOU kontrolu."""
    def dobra() -> dict:
        return {
            "hash_start": "aaa", "hash_end": "bbb", "events": "210", "steps": "720",
            "agent_ticks": "0", "agent_systemu": "3", "advanced_ms": "216000000",
            "expected_ms": "216000000", "mobiles": "200", "map_blocks": "6",
            "events_total": "210", "pending": "0",
            "hash_again": "bbb", "events_again": "210",
            "hash_batch": "bbb", "events_batch": "210", "agent_ticks_batch": "0",
            "hash_after_first": "bbb", "hash_repeat": "bbb", "advanced_ms_repeat": "0",
            "capped": "1", "advanced_capped_ms": "604800000", "cap_ms": "604800000",
        }

    def vada(upravy: dict) -> dict:
        d = dobra()
        d.update(upravy)
        return d

    cases = [
        ("dobry", dobra(), OK),
        ("vadny_bez_pohybu", vada({"hash_end": "aaa"}), VADA),
        ("vadny_bez_udalosti", vada({"events": "0"}), VADA),
        ("vadny_nedeterminismus", vada({"hash_again": "ccc"}), VADA),
        ("vadny_tiknul_cely_svet", vada({"agent_ticks": "2160"}), VADA),
        ("vadny_zadne_entity", vada({"mobiles": "0"}), VADA),
        ("vadny_strop_nedrzi", vada({"advanced_capped_ms": "1000"}), VADA),
        ("vadny_cas_dvakrat", vada({"advanced_ms": "432000000"}), VADA),
        ("vadny_druhy_dobeh_menil", vada({"hash_repeat": "ddd"}), VADA),
        ("vadny_zavisi_na_davkach", vada({"hash_batch": "eee"}), VADA),
        ("vadny_jiny_pocet_udalosti", vada({"events_batch": "209"}), VADA),
        ("vadny_bez_vystupu", {}, VADA),
        ("vadny_chybi_klic", {k: v for k, v in dobra().items() if k != "capped"}, VADA),
    ]
    vysledek = selftest_cli(
        NAME,
        lambda data, gate: evaluate(gate, data),
        [(label, expected) for label, _, expected in cases],
        fixtures=[(label, data) for label, data, _ in cases],
    )
    # TŘETÍ STAV: když brána nemá co měřit (`sim/offline.gd` není), musí to
    # ŘÍCT (2 = NEMĚŘENO), ne zezelenat. Cesta je záměrně NEEXISTUJÍCÍ, takže
    # se nic nezapisuje a test běží i v tom nejpřísnějším sandboxu.
    prazdno = Path(__file__).resolve().parents[2] / ".cache" / "gates" / "f1-neexistuje"
    gate = Gate(f"{NAME}/selftest:nemerene")
    check(prazdno, gate)
    # Podmínka je ZUŽENÁ na důvod: bez ní by test prošel i tehdy, kdyby pending
    # hlásila jiná chybějící věc (`sim/sim_world.gd`) - a to by nebyl důkaz
    # o téhle bráně. "NEMĚŘENO" musí pojmenovat, CO chybí (`docs/08 §8.6`).
    duvod = gate.pending_reason or ""
    ok = gate.verdict() == NEMERENO and OFFLINE in duvod
    print(f"[{NAME}] self-test nemereno (bez {OFFLINE}): ocekavano {NEMERENO} "
          f"s duvodem o {OFFLINE}, vyslo {gate.verdict()} ({duvod[:60]!r}) "
          f"{'OK' if ok else 'CHYBA'}")
    if not ok:
        for e in gate.errors:
            print(f"[{NAME}]   duvod: {e}")
        print(f"[{NAME}]   pending: {gate.pending_reason}")
    return VADA if (vysledek != OK or not ok) else OK


def main() -> int:
    ap = argparse.ArgumentParser(description="F1 svet ma vlastni cas")
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    ap.add_argument("--json", default=None)
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--mutace", action="store_true",
                    help="dukaz, ze brana umi selhat (mutuje KOPIE)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    if args.self_test:
        return selftest()
    if args.mutace:
        return mutace(root)
    gate = Gate(NAME)
    check(root, gate)
    return gate.finish(Path(args.json) if args.json else None)


if __name__ == "__main__":
    raise SystemExit(main())
