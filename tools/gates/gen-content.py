#!/usr/bin/env python3
"""Generátor `data/*.json` (granule data.gen_content, docs/06 §6.1).

Obsah se NEPÍŠE RUČNĚ. Tento skript ho převádí z toho, co už existuje:
`assets/uo/tiles.json` (výstup assets.tiledata) a `research/*.json`.

Pravidla, která tady platí:
  * **idempotence** - dva běhy dají shodné bajty; `--check` to bez zápisu ověří
    a spadne, když je soubor na disku jiný, než by generátor vyrobil,
  * **determinismus** - stejný vstup, stejné výstupní pořadí (sort_keys + sort
    podle `tile`), žádné časové razítko,
  * **nic se netiskne tiše** - co se nepodařilo vyřešit, jde do
    `assets/uo/content-report.json` a na výstup (docs/03 §3.7),
  * co generátor neumí vygenerovat, hlásí jako chybějící, ne jako hotové.

Spouštění:
    python tools/gates/gen-content.py            # vygeneruje (přepíše) data/*.json
    python tools/gates/gen-content.py --check    # jen ověří shodu, nic nezapisuje
    python tools/gates/gen-content.py --only items
Navazující (a nejdřív) krok: `python tools/uoextract/tiledata.py --extract assets/uo`
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import NEMERENO, OK, VADA, ROOT  # noqa: E402  (sjednocene vystupy bran)

# --- cilove soubory: co generujeme a odkud (docs/06 §6.1) --------------------
# Klic = cesta v data/, hodnota = (zabudovany generator?, zdroj).
# Generator, ktery jeste neni, NENI ticha zelena - jde do content-report.json.
POZADAVKY: dict[str, tuple[bool, str]] = {
    "items.json": (True, "assets/uo/tiles.json (vlastnosti) + research/05 (flagy)"),
    "recipes.json": (False, "research/04-craft-data.json"),
    "weapons.json": (False, "research/03 (weapons3.json)"),
    "armor.json": (False, "research/03 (armor_raw.json)"),
    "spells.json": (False, "research/03 (spells_raw.json)"),
    "item_properties.json": (False, "research/03 (itemprops_table.tsv)"),
    "monsters.json": (False, "research/06 (tabulky monst)"),
    "spawns.json": (False, "research/06 (regiony)"),
    "vendors.json": (False, "research/06 (NPC/shopy)"),
    "regions.json": (False, "research/06"),
    "moongates.json": (False, "research/06"),
    "dungeons.json": (False, "research/06"),
    "professions.json": (False, "Prof.txt + research/profese.json"),
    "skills.json": (False, "skills.mul + research/02"),
    "balance.json": (False, "rozhodnuti (docs/05)"),
}

# --- flagy: research/05-data-formats.md, bity 0-35 ---------------------------
F_CONTAINER = 0x00200000
F_LIGHTSOURCE = 0x00800000          # bit 23 - sviti
F_WEARABLE = 0x00400000

# --- role nastroju (docs/06 §6.2) -> PRESNE jmeno, jak je v tiledata ---------
# Klic = role v zadani, hodnota = jmeno, ktere hledame (case-insensitive).
# Co tu neni, se hlasi do content-report.json - nikdy tise.
NASTROJE = {
    "pickaxe": "pickaxe", "shovel": "shovel", "hatchet": "hatchet", "axe": "axe",
    "smith hammer": "smith's hammer", "tongs": "tongs", "sewing kit": "sewing kit",
    "scissors": "scissors", "saw": "saw", "tinker tools": "tinker's tools",
    "mortar and pestle": "mortar and pestle", "scribe pen": "pen and ink",
    "fishing pole": "fishing pole", "butcher knife": "butcher knife",
    "rolling pin": "rolling pin", "flour sifter": "flour sifter",
    "anvil": "anvil", "forge": "forge",
}
# Role, ktere v TEJTO instalaci v tiledata NEJSOU (namEReno 2026-10-03):
#   skillet (je `frypan`), flour mill (je `millstone`), spinning wheel, loom,
#   oven, bellows. Je to mereni, ne vada kodu - viz docs/06 §6.2.
# --- suroviny: jmena, ktera data MAJI (sonda probe-dosuroviny.py) ------------
SUROVINY = [
    "logs", "boards", "iron ore", "iron ingot", "gold ingot", "gold coin",
    "copper ingot", "cloth", "threads", "raw cotton", "feathers",
    "arrow shafts", "bottle", "dough", "sack of flour", "bowl of flour",
    "clean bandage", "scroll", "blank scroll", "sand",
]
# POZOR: `sand` (tile 9310) ma vahu 255 = statika, ale v `items.json` JE a bylo
# i predtim. Provereno: minulej verzi generatoru mela mrtvou sadu
# SUROVINY_VYLOUCENE = {"sand"}, ktera se nikde nepouzila. Generator musi
# data reprodukovat, takze to nechavam jak je a vadu resi az granule data.items
# (vybrat spravne: bud opravit data, nebo to opravdu je surovina).
# NEVYRESENO (namEReno 2026-10-04): `clean bandage` a `blank scroll` nejsou
# v tiledata pod timto jmenem - chybi do content-report.json.
PLACEHOLDERY = {"missing_name", "noname", "nodraw", "nodraw_hover", "default kr"}

# Slova, ktera rikaji "to je zbroj" / "to je zbran" - casti jmen, ktere v techto
# datech opravdu jsou (namEReno sondami probe-overit-bity.py / probe-dosuroviny.py).
ZBROJOVE_SLOVO = ("chest", "legs", "arms", "arm_", "gorget", "gloves", "boots",
                  "cap", "helm", "shield", "tunic", "leggings", "plate", "chain",
                  "ring", "bone", "studded", "scale")
ZBRANOVE_SLOVO = ("axe", "axes", "spear", "staff", "sword", "blade", "mace", "dagger",
                  "bow", "halberd", "bardiche", "kryss", "katana", "boomerang",
                  "talwar", "club", "fork", "scepter", "wand", "hammer", "pick",
                  "maul", "scimitar", "cutlass", "scythe")
SVETLOVE_SLOVO = ("candle", "torch", "lantern", "lamp")


# =============================================================================
# items.json - katalog predmetu (granule data.items)
# =============================================================================
def nacti_tiledata(root: Path) -> list[dict]:
    """Rozlozi `tiles.json` na seznam zaznamu s polem `tile` (index v `item`)."""
    tiles = json.loads((root / "assets/uo/tiles.json").read_text(encoding="utf-8"))
    fields = tiles["layout"]["item_fields"]
    out = []
    for tile, row in enumerate(tiles["item"]):
        rec = dict(zip(fields, row))
        rec["tile"] = tile
        out.append(rec)
    return out


def je_platne_jmeno(rec: dict) -> bool:
    """Jmeno musi byt pouzitelne jako nazev predmetu.

    POZOR (namEReno 2026-10-03): `%s` v jmene NENI vada - je to UO znacka
    pluralu ('iron ingot%s' je skutecny nazev ingotu). Vyradil by se vsechny
    ingoty, obvazy i sipy. Vyrazuji se jen SKUTECNE placeholdery."""
    n = rec["name"]
    if not n or not all(0x20 <= ord(c) < 0x7F for c in n):
        return False
    return n.lower() not in PLACEHOLDERY


def najdi(podle_jmena: dict[str, list[dict]], hledane: str) -> list[dict]:
    """Presna shoda, jinak singular/plural varianta.

    Poradi: '<jmeno>' -> '<jmeno>%s' (UO plural) -> '<jmeno>s' -> '<jmeno>%'.
    Tim 'iron ingot' chyti na 'iron ingot%s' a 'bandage' na 'clean bandage%s%'."""
    for k in (hledane, hledane + "%s", hledane + "s", hledane + "%"):
        nalezy = podle_jmena.get(k.lower(), [])
        if nalezy:
            return nalezy
    return []


def kategorie(rec: dict) -> tuple[str, str]:
    """Zaradi predmet podle VLASTNOSTI (docs/03 §3.3.1b). Vraci (kategorie, pravidlo).

    POZOR - flagove bity z research/05 NELZE pouzit jako kategorii: v techto
    datech ma bit 2 ("Weapon") nastaveny vsech 1268 Wearable predmetu (i
    'leather cap') a bit 27 ("Armor") jen 25 predmetu, z toho ZADNY neni zbroj.
    Kdo by kategorizoval podle nich, vyrobi 1126 "zbrani" vcetne kozene helmy.

    Proto: nejdriv role (nastroj/surovina, uz rozhodnuto vyberem podle jmena),
    pak `layer` (spolehlive pole, UO konvence) a uvnitr vrstvy jeste jmeno.
    """
    role = rec.get("_role", "")
    if role:
        return ("tool" if role in NASTROJE else "material"), "role"

    jmeno, flags, layer = rec["name"].lower(), rec["flags"], rec["layer"]
    if layer == 0:
        if flags & F_CONTAINER:
            return "container", "layer0-container"
        if flags & F_LIGHTSOURCE:
            return "light", "layer0-lightsource"
        return "misc", "layer0-other"
    if layer == 1:
        return "weapon", "layer1-hand"
    if layer == 2:
        if any(k in jmeno for k in ZBRANOVE_SLOVO):
            return "weapon", "layer2-weapon-name"
        if any(k in jmeno for k in SVETLOVE_SLOVO):
            return "light", "layer2-light-name"
        return "shield", "layer2-shield"
    if 3 <= layer <= 23 and (flags & F_WEARABLE):
        if any(k in jmeno for k in ZBROJOVE_SLOVO):
            return "armor", "wearable-armor-name"
        return "clothing", "wearable-clothing"
    return "misc", "other"


def hodnota(rec: dict) -> tuple[int, str]:
    """`tiledata` NEMA pole value - odvodime ho a priznam, odkud (docs/06 §6.2).

    Priorita: count > 0 (je soucasti zaznamu predmetu) > weight > 1, aby predmet
    mel vubec cenu. `value_source` to pise do kazdeho zaznamu."""
    if rec["count"] > 0:
        return rec["count"], "tiledata-count"
    if rec["weight"] > 0:
        return rec["weight"], "weight-fallback"
    return 1, "minimum"


def gen_items(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/items.json`, seznam nevyresenych roli)."""
    predmety = nacti_tiledata(root)
    podle_jmena: dict[str, list[dict]] = {}
    for rec in predmety:
        if je_platne_jmeno(rec):
            podle_jmena.setdefault(rec["name"].lower(), []).append(rec)

    zaznamy: list[dict] = []
    pouzite_tile: set[int] = set()
    nenalezene: list[dict] = []

    def pridej(rec: dict, zdroj: str, role: str = "") -> None:
        if rec["tile"] in pouzite_tile:
            return
        pouzite_tile.add(rec["tile"])
        rec["_role"] = role
        val, val_src = hodnota(rec)
        kat, pravidlo = kategorie(rec)
        zaznamy.append({
            "tile": rec["tile"], "name": rec["name"], "category": kat,
            "weight": rec["weight"], "value": val, "layer": rec["layer"],
            "flags": rec["flags"], "source": zdroj, "era": "t2a",
            "count": rec["count"], "value_source": val_src, "role": role,
            "category_rule": pravidlo,
        })

    for role, jmeno in list(NASTROJE.items()) + [(m, m) for m in SUROVINY]:
        nalezy = najdi(podle_jmena, jmeno)
        if not nalezy:
            nenalezene.append({"role": role, "hledano": jmeno,
                               "kategorie": "tool" if role in NASTROJE else "material",
                               "duvod": "jmeno v tiledata neni"})
            continue
        # u vicero shod (dva arty tehoz predmetu) ber prvni
        pridej(nalezy[0], "tiledata-exact-name", role)

    # vse ostatni podle vlastnosti
    for rec in predmety:
        if rec["tile"] in pouzite_tile or not je_platne_jmeno(rec):
            continue
        if rec["weight"] == 255:
            continue                      # statika/dekorace, ne noseny predmet
        pridej(rec, "tiledata-by-properties")

    zaznamy.sort(key=lambda r: r["tile"])          # deterministicke poradi
    raw = json.dumps(zaznamy, ensure_ascii=False, sort_keys=True,
                     separators=(",", ":")).encode("utf-8")
    return raw, nenalezene


# =============================================================================
# rozdeleni prace: generatory, report, zapis
# =============================================================================
GENERATORY = {"items.json": gen_items}


def bajty(json_obj) -> bytes:
    """Jediny zpusob, jakym tento skript zapisuje JSON - bez toho neni
    'determinismus' meratelny a dva běhy by se liskly."""
    return json.dumps(json_obj, ensure_ascii=False, indent=1,
                      sort_keys=True).encode("utf-8") + b"\n"


def main() -> int:
    ap = argparse.ArgumentParser(description="Generátor data/*.json (docs/06 §6.1)")
    ap.add_argument("--root", default=str(ROOT))
    ap.add_argument("--check", action="store_true",
                    help="nic nezapisuj; spadni (exit 1), kdyz je soubor jiný")
    ap.add_argument("--only", default=None, help="jen jeden cíl (napr. items)")
    args = ap.parse_args()
    root = Path(args.root).resolve()
    if args.only is None:
        only = None                                  # plny beh: vsechny cile
        cil = sorted(POZADAVKY)
    else:
        # `--only items` i `--only items.json` znamenaji to same (jinak by se to
        # tiche vytratilo z prehazovani a skoncilo by to NEMERENO bez vysvetleni).
        only = args.only.removesuffix(".json") + ".json"
        if only not in POZADAVKY:
            print(f"[gen] VADA: --only {args.only} neni znamy cil; zname: "
                  + ", ".join(sorted(POZADAVKY)))
            return VADA
        cil = [only]

    if not (root / "assets/uo/tiles.json").exists():
        print("[gen] CHYBA: assets/uo/tiles.json neexistuje - spust napred "
              "`python tools/uoextract/tiledata.py --extract assets/uo`")
        return NEMERENO

    vada, nemereno, report = 0, 0, {"unresolved": [], "bez_generatoru": []}
    for name in cil:
        hotovy, zdroj = POZADAVKY.get(name, (False, "?"))
        if not hotovy or name not in GENERATORY:
            report["bez_generatoru"].append({"soubor": name, "zdroj": zdroj,
                                             "duvod": "generator jeste neni napsany"})
            nemereno += 1
            print(f"[gen] NEMERENO {name}: generator chybi (zdroj by byl {zdroj})")
            continue
        raw, nenalezene = GENERATORY[name](root)
        report["unresolved"].extend(nenalezene)
        cesta = root / "data" / name
        sha = hashlib.sha256(raw).hexdigest()
        if args.check:
            if not cesta.exists():
                print(f"[gen] VADA {name}: soubor neexistuje (spust bez --check)")
                vada += 1
            elif cesta.read_bytes() != raw:
                print(f"[gen] VADA {name}: na disku je jina verze nez by generátor vyrobil")
                vada += 1
            else:
                print(f"[gen] OK {name}: shoda, sha256 {sha[:16]}…")
        else:
            cesta.parent.mkdir(parents=True, exist_ok=True)
            cesta.write_bytes(raw)
            print(f"[gen] zapsano data/{name}: {len(raw)} B, sha256 {sha[:16]}…")
        for u in nenalezene:
            print(f"[gen]   NENALEZENO {u['kategorie']}/{u['role']}: {u['duvod']}")

    # Co zustalo nevyresene, jde do reportu. POZOR (namEReno 2026-10-04):
    # `--only` NESMI prepisovat spravny `content-report.json` svym uzkym
    # vystupem - tichy by zneplatnil 14 "generator chybi". Casti běhu jde do
    # `.cache/gen-content/`, hlavni report piše jen plny beh.
    if not args.check:
        if args.only is None:
            rp = root / "assets/uo/content-report.json"
        else:
            rp = root / ".cache/gen-content" / f"{only.removesuffix('.json')}.json"
            print(f"[gen] POZOR: casti beh ({only}) - hlavni content-report.json "
                  f"se nedotkl, vysledek je v {rp.relative_to(root)}")
        rp.parent.mkdir(parents=True, exist_ok=True)
        rp.write_bytes(bajty(report))

    # Ukazky: pocet muze sedet a vyber byt spatny -> vzdy se na par podivej.
    # POZOR (namEReno 2026-10-04): tohle NESMI byt duvodem, aby beh skoncil
    # tracebackem - pri `--check` nad poskozzenym items.json to prave takhle
    # spadl a zadny navratovy kod neznamenal, co se vlastne zkontrolovalo.
    # Vypisky jsou vedlejsi produkt, ne mereni.
    cesta = root / "data/items.json"
    if cesta.exists():
        try:
            polozky = json.loads(cesta.read_text(encoding="utf-8"))
        except (ValueError, OSError) as exc:
            print(f"[gen] ukazky nelze vypisat ({exc}) - vysledek behu vyse plati")
        else:
            for kat, pocet in sorted(Counter(p["category"] for p in polozky).items()):
                print(f"[gen]   {kat:<10} {pocet:>5}  "
                      f"{[p['name'] for p in polozky if p['category'] == kat][:6]}")
            role = [(p["role"], p["tile"], p["name"]) for p in polozky if p["role"]]
            print(f"[gen] vybrane role: {len(role)} (u kazde musi sedet tile, ne podobne jmeno)")

    if vada:
        return VADA
    return NEMERENO if nemereno else OK


if __name__ == "__main__":
    raise SystemExit(main())
