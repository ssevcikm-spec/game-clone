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
    python tools/gates/gen-content.py --only skills --check
Navazující (a nejdřív) krok: `python tools/uoextract/tiledata.py --extract assets/uo`
(u `--only skills` staci `data/skill_groups.json` z `tools/uoextract/textdata.py`).

Co je hotové a co ne, se NEPÍŠE RUČNĚ: `POZADAVKY` níž má u každého cíle
`True`/`False` a cíl s `False` jde do `content-report.json` jako
"generator jeste neni napsany" - nikdy ticha zelena.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
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
    "recipes.json": (True, "research/04-craft-data.json + Cliloc.enu (nazvy)"),
    "weapons.json": (True, "research/_src/weapons3.json"),
    "armor.json": (True, "research/_src/armor_raw.json"),
    "spells.json": (False, "research/03 (spells_raw.json)"),
    "item_properties.json": (True, "research/_src/itemprops_table.tsv"),
    "monsters.json": (True, "research/06 §3.1 tabulky (Tier 1 + Tier 2)"),
    "spawns.json": (True, "rozhodnuti D2 + research/06 §4.8 F (hřbitov)"),
    "vendors.json": (True, "research/06 §2.2.1 + §2.4.1 (NPC/shopy)"),
    "regions.json": (False, "research/06"),
    "moongates.json": (False, "research/06"),
    "dungeons.json": (False, "research/06"),
    "professions.json": (False, "Prof.txt + research/profese.json"),
    "skills.json": (True, "data/skill_groups.json (skills.mul + skillgrp.mul, "
                          "extract textdata.py) + research/02-skills.md §3.9"),
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


def slug(jmeno: str) -> str:
    """`iron ore` -> `iron_ore`; IDENTITA predmetu (`type`), ne popis pro hrace.

    ⚠ 20. session (2026-10-08): `type` je odpoved na to, co bylo do teto session
    jen na artech - "co ta vec JE". Sdili ho VSECHNY arty tehoz jmena, takze
    "vsechna ruda je ruda" je vlastnost DAT, ne seznam artu v kódu.
    UO znacka pluralu (`%s`, `%`) NENI soucast jmena - `iron ingot%s` je
    `iron ingot` (viz `je_platne_jmeno`, ktera ji popisuje); kdyby zustala,
    vznikl by z ingotu druhy typ a pravidla by se rozesla."""
    zaklad = jmeno.replace("%s", "").replace("%", "")
    out: list[str] = []
    for ch in zaklad.lower():
        out.append(ch if (ch.isalnum() and ord(ch) < 128) else "_")
    text = "".join(out)
    while "__" in text:
        text = text.replace("__", "_")
    return text.strip("_")


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

    # ⚠⚠ PLURAL: `board%s` a `boards` je TATAZ VEC (jiny art tehoz predmetu).
    # `slug` u `%s`/`%` vyhodi UO znacku pluralu, ale hole `boards` zustane
    # "boards" - a pak ma jeden predmet DVA typy (namEReno: 33 takovych dvojic:
    # board/boards, log/logs, copper_ingot/copper_ingots, feather/feathers...).
    # Dusledek by byl TICHY: recept vyreseny na `log%s` by nenasel hromadu typu
    # `logs`, takze by vyroba rekla "chybi material", i kdyz ho hrac ma.
    # Sjednocuje se na JEDNOTNE cislo, kdyz v datech existuje (deterministicke:
    # rozhoduje mnozina vsech jmen, ne poradi souboru).
    vsechny_typy: set[str] = {slug(rec["name"]) for rec in predmety if je_platne_jmeno(rec)}
    kanonicky: dict[str, str] = {}
    for typ in vsechny_typy:
        kanonicky[typ] = typ[:-1] if (typ.endswith("s") and typ[:-1] in vsechny_typy) else typ
    typ_podle_jmena: dict[str, str] = {
        rec["name"].lower(): kanonicky[slug(rec["name"])]
        for rec in predmety if je_platne_jmeno(rec)
    }

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
            # `type` = IDENTITA PREDMETU: vsechny arty tehoz jmena ji sdili
            # (a po sjednoceni pluralu i `board%s` s `boards`), takze pravidla
            # ("pouzij rudu na vyhen") se ptají typu, ne cisla artu. Art zustava
            # INDEX pro kresleni a `tiledata`.
            "type": typ_podle_jmena.get(rec["name"].lower(), slug(rec["name"])),
        })

    for role, jmeno in list(NASTROJE.items()) + [(m, m) for m in SUROVINY]:
        nalezy = najdi(podle_jmena, jmeno)
        if not nalezy:
            nenalezene.append({"role": role, "hledano": jmeno,
                               "kategorie": "tool" if role in NASTROJE else "material",
                               "duvod": "jmeno v tiledata neni"})
            continue
        # ⚠⚠ 20. session (2026-10-08) - ROLE PATRI VSEM NOSENYM ARTUM TEHOZ
        # JMENA, ne jen prvnimu. Do teto session tu stalo "u vicero shod (dva
        # arty tehoz predmetu) ber prvni", takze `role: "iron ore"` mel JEDEN
        # ze ctyr artu rudy (tiledata 6583 = art 0x59B7) a ruda, kterou hra
        # opravdu vytezi (`sim.harvest.ORE_ART = 0x59B8`), roli NEMELA - hrac s
        # ni nemohl pouzit vyhen (`sim.interaction.use_on` vraci `no_pair`).
        # NAMERENO (`.cache/over-role-vsechny-arty.py`): VSECHNY shody by pridaly
        # roli 130 artum - z toho 33 "forge", 34 "sand" a 20 "bottle" s vahou
        # 255, coz jsou STATICKE DEKORACE (generator je o par radku niz
        # vynechava: `weight == 255` neni noseny predmet). Proto:
        #   * prvni shoda jako dosud (i kdyz ma vahu 255 - je v datech uz dnes
        #     a ubrat zaznam by znamenalo zmenu, ktera sem nepatri),
        #   * k ni vsechny dalsi shody, ktere jsou NOSENE (weight != 255).
        pridej(nalezy[0], "tiledata-exact-name", role)
        for shoda in nalezy[1:]:
            if shoda["weight"] != 255:
                pridej(shoda, "tiledata-exact-name", role)

    # vse ostatni podle vlastnosti
    for rec in predmety:
        if rec["tile"] in pouzite_tile or not je_platne_jmeno(rec):
            continue
        if rec["weight"] == 255:
            continue                      # statika/dekorace, ne noseny predmet
        pridej(rec, "tiledata-by-properties")

    zaznamy.sort(key=lambda r: r["tile"])          # deterministicke poradi
    # SJEDNOCENI KATEGORIE V RAMCI TYPU (20. session): jeden typ = jedna vec,
    # takze jeho arty NESMI mit jinou kategorii - jinak se tyz predmet chova
    # podle grafiky jinak (`sim.interaction` routuje z kategorie: `dagger` byl
    # u nekterych artu "weapon" a u jinych "misc", `wooden box` container/misc).
    # Pravidlo (merene, ne vymyslene): ROLE > VLASTNOST (layer/jmeno/flag) >
    # fallback `layer0-other`/`other`. Kdyz maji vsechny arty typu jen fallback,
    # je kategorie uz stejna a nic se nemeni.
    FALLBACK_RULES = {"layer0-other", "other"}
    for typ in sorted({r["type"] for r in zaznamy}):
        skupina = [r for r in zaznamy if r["type"] == typ]
        kandidati = [r for r in skupina if r["category_rule"] not in FALLBACK_RULES]
        if not kandidati:
            continue
        role_kandidati = [r for r in kandidati if r["category_rule"] == "role"]
        vybrany = min(role_kandidati or kandidati, key=lambda r: r["tile"])
        for r in skupina:
            if r["category"] != vybrany["category"]:
                r["category"] = vybrany["category"]
                r["category_rule"] = "type:" + vybrany["category_rule"]
    # KONTROLA TYPU (20. session): jeden `type` = jedna vec, takze se jeho
    # zaznamy NESMI rozejit v NEPRAZDNE roli ani v kategorii. Kdyz se rozejdou,
    # je to rozpor DAT (dva arty tehoz jmena znamenaji neco jineho) a hlasi se
    # to - ticha volba "vyhral prvni" by byla presne ta vada, kterou resime.
    # Prazdna role u ostatnich artu téhož typu NENI rozpor: role se prirazuje
    # jen vybranym jmenum (`NASTROJE`/`SUROVINY`), ale typ ji sdili cely.
    podle_typu: dict[str, list[dict]] = {}
    for r in zaznamy:
        podle_typu.setdefault(r["type"], []).append(r)
    for typ, zaznamy_typu in sorted(podle_typu.items()):
        role = {r["role"] for r in zaznamy_typu if r["role"]}
        kat = {r["category"] for r in zaznamy_typu}
        if len(role) > 1 or len(kat) > 1:
            nenalezene.append({
                "duvod": "jeden typ ma vic roli/kategorii (art se rozesel)",
                "type": typ,
                "role": sorted(role),
                "kategorie": sorted(kat),
                "arty": [r["tile"] for r in zaznamy_typu],
            })
    raw = json.dumps(zaznamy, ensure_ascii=False, sort_keys=True,
                     separators=(",", ":")).encode("utf-8")
    return raw, nenalezene


# =============================================================================
# recipes.json - recepty (granule data.recipes)
# =============================================================================
# ZDROJ: research/04-craft-data.json (11 remesel, 1053 receptu). Ani jmeno
# vysledku, ani jmeno suroviny v nem NENI - je to C# typ ("GoldRing") a cislo
# kliloku (["expr", "1044176 + offset"]). Text da Cliloc.enu, tile da items.json.
#
# POZOR (namEReno 2026-10-04): v teto instalaci se prelozi jen CAST receptu -
# 354 z 1053 vysledku a 1100 materialu. Zbytek v tiledata opravdu NENI (je to
# obsah pozdejsich eras: "platemail (tunic)", "turquoise", "blank scroll").
# Nerozresene nejde do fiktivniho tile, ale do content-report.json.
CLILOC_INSTALL = Path(r"D:\Games\Electronic Arts\Ultima Online Classic")


def klilok(spec, zaznamy: dict[int, str]) -> str | None:
    """['expr'|'cliloc', '1044176 + offset'] -> text z `Cliloc.enu` (None, kdyz neni)."""
    if not (isinstance(spec, list) and len(spec) >= 2 and spec[0] in ("expr", "cliloc")):
        return None
    match = re.match(r"\s*(\d+)", str(spec[1]))
    return zaznamy.get(int(match.group(1))) if match else None


def camel_jmeno(nazev: str) -> str:
    """'GoldRing' -> 'gold ring' (rozdeleni pred velikym pismenem)."""
    return re.sub(r"(?<!^)(?=[A-Z])", " ", nazev).strip().lower()


def gen_recipes(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/recipes.json`, seznam nevyresenych referenci).

    POZADAVKY na zaznam (docs/04 §4.5, hlida je G5 check-content): `id`,
    `skill`, `min_skill`, `result`, `materials`. `tile` je nepovinny a kdyz
    neni, brana ten odkaz vúbec nemeri - proto nesmime vypisat vymysleny tile."""
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "uoextract"))
    from cliloc import Cliloc                                   # noqa: PLC0415

    predmety = json.loads(gen_items(root)[0])
    podle_jmena: dict[str, list[dict]] = {}
    for rec in predmety:
        podle_jmena.setdefault(rec["name"].lower(), []).append(rec)
    texty = Cliloc(CLILOC_INSTALL).cliloc_all()
    craft = json.loads((root / "research/04-craft-data.json").read_text(encoding="utf-8"))

    def najdi(jmeno: str) -> dict | None:
        for k in (jmeno, jmeno + "%s", jmeno + "s", jmeno + "%"):
            if podle_jmena.get(k):
                return podle_jmena[k][0]
        return None

    def ref(kind: str, rec: dict) -> dict:
        """Jeden material/vysledek. Poradi: text kliloku -> C# typ.

        ⚠ 20. session: zaznam nese i `item_type` - IDENTITU z `data/items.json`
        (slug jmena, ktere se v instalaci naslo). `craft` pak hleda material
        podle TYPU, ne podle artu, takze se do receptu pocita i hromada s jinou
        grafikou (prkna 4 arty, klada 4 arty). Kdyz se jmeno nenajde, `item_type`
        se NEVYPISUJE - vymyslena identita, ktera se s zadnym predmetem nemuze
        potkat, je horsi nez zadna (a `tile` tam taky neni)."""
        text = klilok(rec.get("cliloc") or rec.get("name"), texty)
        nalezeny = None
        for kandidat in (text, camel_jmeno(str(rec.get("type", "")))):
            if not kandidat:
                continue
            nalezeny = najdi(kandidat.lower())
            if nalezeny is not None:
                out = {"name": kandidat.lower(), "tile": nalezeny["tile"],
                       "item_type": str(nalezeny["type"])}
                break
        else:
            out = {"name": (text or camel_jmeno(str(rec.get("type", "")))).lower()}
        out["type"] = rec.get("type")
        # `res_amount` je v research/04 u 4 receptu null (namEReno) - tam jde
        # o 1 kus; null neni "0" a nesmi se vypisat jako 0.
        pocet = rec.get("amount")
        out["amount"] = int(pocet) if isinstance(pocet, (int, float)) else 1
        out["kind"] = kind
        return out

    zaznamy: list[dict] = []
    nevyresene: list[dict] = []
    for skill in sorted(craft):
        zdroj = craft[skill].get("file", "")
        for rec in craft[skill]["items"]:
            vysledek = ref("result", rec)
            materialy = [ref("material", {"type": rec["res_type"],
                                          "amount": rec["res_amount"]})]
            materialy += [ref("extra_material", e) for e in rec["extra_res"]]
            for ref_rec in [vysledek, *materialy]:
                if "tile" not in ref_rec:
                    nevyresene.append({"soubor": "recipes.json", "skill": skill,
                                       "kind": ref_rec["kind"], "nazev": ref_rec["name"],
                                       "duvod": "jmeno neni v items.json (v tiledata chybi)"})
            zaznamy.append({
                "id": len(zaznamy), "skill": skill, "type": rec["type"],
                "min_skill": rec["min_skill"], "max_skill": rec["max_skill"],
                "result": vysledek, "materials": materialy,
                "use_all_res": rec["use_all_res"], "era": rec["era"],
                "source": zdroj, "group": klilok(rec["group"], texty),
            })
    raw = bajty(zaznamy)
    return raw, nevyresene


# =============================================================================
# skills.json - 58 skillu (granule data.skills)
# =============================================================================
# ZDROJ 1 (jmena, poradi, skupiny): `data/skill_groups.json` = vystup nastroje
#   `tools/uoextract/textdata.py` z `skills.mul` (58 jmen v poradi klienta,
#   docs/11 §11.1) a `skillgrp.mul` (skupina pro kazdy skill). Generator cte
#   EXTRAKT, ne instalaci UO - stejne jako items.json cte `assets/uo/tiles.json`;
#   instalace v CI neni a `--check` musi projit i bez ni (docs/03 §3.7).
# ZDROJ 2 (staty): `research/02-skills.md` §3.9 - tabulka `SkillInfo.Table`
#   (ServUO pub57, docs/11 §11.3). Je to druhy, nezavisly zdroj.
#
# POZOR - PORADI 55-57 SE ROZCHAZI (overeno 2026-10-06 primym ctenim
# `skills.mul`: 704 B, model spotrebuje cely soubor): klient ma
# 55 Throwing / 56 Imbuing / 57 Mysticism (docs/11 §11.1), ale research/02 §3.9
# i §7.3 cisluji 55 Mysticism / 57 Throwing (poradi tridy `SkillInfo` ze
# serveru). Staty se proto berou podle JMENA, ne podle id - jmeno je jediny
# spolecny klic; rozchod jde do content-report.json, nikdy do ticha.
#
# POZOR (overeno v datech 2026-10-06): `skillgrp.mul` ma 7 ID skupin (0..6), ale
# jen 6 ma jmeno (hlavicka 7 = 6 jmen + implicitni skupina 0). Mapovani je
# 1-BAZNOVE: id k (1..6) -> jmena[k-1], id 0 = "Miscellaneous" (nema jmeno;
# research/02 §7.3). Dukaz z dat: id 6 maji presne 4 bard skilly a sesty nazev
# je "Bard"; id 4 = Animal Lore/Fishing ("Wilderness"), ne "Thieving" - takze
# 0-baznove mapovani je vyvracene. (docs/03 §3.9.3 tvrdi, ze "id 6" je bez
# jmena - to je vada dokumentu, hlasi se; viz poznamka v testu.)
SKILL_COUNT = 58
SKILL_GROUP_MISC = "Miscellaneous"
# Ktere skilly klon mechanicky NEimplementuje: docs/05 §5.16 = "48 klasickych
# (0-47) + Remove Trap; Necromancy/Bushido/Ninjitsu/Spellweaving/Throwing/
# Imbuing/Mysticism/Chivalry/Focus = implemented: false" -> DEVET jmen.
# ZADANI GRANULE uvadi z nich jen SEDM (bez Chivalry a Focus); je to rozpor
# zadani s dokumentem, ktery se HLASI (SKILL_FALSE_ZE_ZADANI niz), a rozhoduje
# dokument (docs/05 §5.16 + docs/11 §11.1: "u zbytku ma implemented: false +
# viditelnou hlasku v UI. Nikdy prazdny skill, ktery tvrdi, ze funguje.").
# Drzi se JMEN, ne id (viz rozchod poradi 55-57 vyse).
SKILL_NOT_IMPLEMENTED = ("Necromancy", "Focus", "Chivalry", "Bushido", "Ninjitsu",
                         "Spellweaving", "Mysticism", "Imbuing", "Throwing")
SKILL_FALSE_ZE_ZADANI = ("Necromancy", "Bushido", "Ninjitsu", "Spellweaving",
                         "Throwing", "Imbuing", "Mysticism")
# `implemented: false` ma byt presne u id 49-57 (§5.16 je vyjmenovava jako
# pozdni sadu); kdyby se klient rozešel, je to vada, ne ticha zmena.
SKILL_FALSE_IDS = set(range(49, 58))
# Era podle research/02 §7.2: Necromancy/Focus/Chivalry = AoS (2003-02-11),
# Bushido/Ninjitsu = SE (2004-11-02), Spellweaving = ML (2005-08-30),
# Mysticism/Imbuing/Throwing = SA (2009-09-08); zbytek je pre-AoS (klasicka
# sada, docs/05 §5.16). Test tuhle tabulku NEprebira - cte vetu z research/02
# a porovnava s daty, takze rozchod pozna (docs/08 §8.3).
SKILL_ERA = {"Necromancy": "aos", "Focus": "aos", "Chivalry": "aos",
             "Bushido": "se", "Ninjitsu": "se", "Spellweaving": "ml",
             "Mysticism": "sa", "Imbuing": "sa", "Throwing": "sa"}
SKILL_ERA_CLASSIC = "pre-aos"
SKILL_RESEARCH = "research/02-skills.md"
SKILL_TABLE_ANCHOR = "### 3.9"
SKILL_ROW = re.compile(
    r"^\|\s*(?P<id>\d+)\s*\|\s*(?P<name>[^|]+?)\s*\|"
    r"\s*(?P<primary>Str|Dex|Int)\s*\|\s*(?P<secondary>Str|Dex|Int)\s*\|")


def staty_skillu(root: Path) -> dict[int, tuple[str, str, str]]:
    """{id: (jmeno, primarni stat, sekundarni stat)} z tabulky research/02 §3.9.

    Bere se jen tabulka pod nadpisem `### 3.9` (dokud nezačne další `### `),
    aby se do ni nepletly ostatni tabulky téhož dokumentu (napr. §7.3, ktera ma
    stejny tvar sloupcu, ale jiný sloupec "Client grp")."""
    path = root / SKILL_RESEARCH
    if not path.exists():
        raise ValueError(f"{SKILL_RESEARCH} chybi - bez nej nelze urcit staty skillu")
    out: dict[int, tuple[str, str, str]] = {}
    v_tabulce = False
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith("### "):
            v_tabulce = line.startswith(SKILL_TABLE_ANCHOR)
            continue
        if not v_tabulce:
            continue
        match = SKILL_ROW.match(line)
        if match:
            out[int(match.group("id"))] = (
                match.group("name"), match.group("primary").lower(),
                match.group("secondary").lower())
    if sorted(out) != list(range(SKILL_COUNT)):
        raise ValueError(
            f"{SKILL_RESEARCH} §3.9: precteno {len(out)} radku, ocekavano "
            f"{SKILL_COUNT} s id 0..{SKILL_COUNT - 1}")
    return out


def gen_skills(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/skills.json`, seznam nevyresenych polozek)."""
    cesta = root / "data/skill_groups.json"
    if not cesta.exists():
        raise ValueError("data/skill_groups.json chybi - spust "
                         "`python tools/uoextract/textdata.py --install <UO> --out data`")
    extrakt = json.loads(cesta.read_text(encoding="utf-8"))
    jmena = extrakt.get("skills", [])
    skupiny = extrakt.get("groups", {})
    gids = skupiny.get("skill_groups", [])
    gnazvy = skupiny.get("names", [])
    if len(jmena) != SKILL_COUNT:
        raise ValueError(f"data/skill_groups.json: {len(jmena)} jmen z skills.mul, "
                         f"ocekavano {SKILL_COUNT}")
    if len(gids) != SKILL_COUNT:
        raise ValueError(f"data/skill_groups.json: {len(gids)} skupinovych id, "
                         f"ocekavano {SKILL_COUNT}")
    if skupiny.get("header") != len(gnazvy) + 1:
        raise ValueError(
            f"skillgrp.mul: hlavicka {skupiny.get('header')} != {len(gnazvy)} jmen + 1 "
            "-> mapovani skupin by nebylo 1-baznove (viz komentar vyse)")
    staty = staty_skillu(root)
    # Staty se hledaji podle JMENA: id 55/57 ma klientsky `skills.mul` opacne
    # nez research/02 §3.9 (viz POZOR v hlavicce bloku). Mnozina jmen musi
    # sedet presne - chybejici nebo prebyvajici jmeno je vada, ne ticha zmena.
    podle_jmena_tabulky = {v[0]: (v[1], v[2]) for v in staty.values()}
    chybejici = [j for j in jmena if j not in podle_jmena_tabulky]
    prebytecna = [j for j in podle_jmena_tabulky if j not in set(jmena)]
    if chybejici or prebytecna:
        raise ValueError(
            f"{SKILL_RESEARCH} §3.9 a skills.mul se neshoduji ve jmenech: "
            f"chybi {chybejici}, prebyva {prebytecna}")

    zaznamy: list[dict] = []
    for i, jmeno in enumerate(jmena):
        prim, sek = podle_jmena_tabulky[jmeno]
        gid = int(gids[i])
        if not 0 <= gid <= len(gnazvy):
            raise ValueError(f"id {i}: skupina {gid} je mimo 0..{len(gnazvy)}")
        zaznamy.append({
            "id": i, "name": jmeno, "group_id": gid,
            "group": gnazvy[gid - 1] if gid else SKILL_GROUP_MISC,
            "stat_primary": prim, "stat_secondary": sek,
            "implemented": jmeno not in SKILL_NOT_IMPLEMENTED,
            "era": SKILL_ERA.get(jmeno, SKILL_ERA_CLASSIC), "source": "skills.mul",
        })

    # Zadani granule musi platit: vsech 7 jmen z promptu je implemented: false.
    podle_jmena = {z["name"]: z["id"] for z in zaznamy}
    for jmeno in SKILL_FALSE_ZE_ZADANI:
        if jmeno not in podle_jmena:
            raise ValueError(f"{jmeno} (ze zadani granule) v skills.mul neni")
        if zaznamy[podle_jmena[jmeno]]["implemented"]:
            raise ValueError(f"{jmeno} ma byt implemented: false (zadani granule)")
    # ...a zaroven musi platit mnozina z dokumentu (docs/05 §5.16): presne 49-57.
    neimpl = {z["id"] for z in zaznamy if not z["implemented"]}
    if neimpl != SKILL_FALSE_IDS:
        raise ValueError(f"docs/05 §5.16: implemented: false ma byt u id "
                         f"{sorted(SKILL_FALSE_IDS)}, vyslo {sorted(neimpl)}")

    # Rozchod poradi mezi skills.mul a research/02 se NESMI zamlcet - jde do
    # content-report.json (neni to "nevyreseno", ale je to nalezeny rozpor).
    nenalezene: list[dict] = []
    nesedici = [i for i in range(SKILL_COUNT) if staty[i][0] != jmena[i]]
    if nesedici:
        nenalezene.append({
            "soubor": "skills.json", "kind": "poradi",
            "nazev": "; ".join(
                f"id {i}: skills.mul {jmena[i]} vs research/02 {staty[i][0]}"
                for i in nesedici),
            "duvod": "research/02 §3.9 cisluje tyto skilly jinak nez skills.mul teto "
                     "instalace; staty se berou podle JMENA, poradi z skills.mul "
                     "(docs/11 §11.1)",
        })
    return bajty(zaznamy), nenalezene


# =============================================================================
# vendors.json - vendori a obchody (granule data.vendors, docs/06 §6.6)
# =============================================================================
# ZDROJ: `research/06-world-content-npcs.md` §2.2.1 (klasicti shop vendori
# s seznamem SBInfo) a §2.4.1 (tabulky vsech SBInfo z `Scripts/VendorInfo/*.cs`).
#
# CENY JSOU DATA, NE KOD: berou se Z TABULEK (`GenericSellInfo.Add(type, price)`).
# `value` v `data/items.json` je odvozena z tiledata `count` a je nesmyslna -
# NAMERENO: iron ingot 1, dagger 20, longsword 6 (mec levnejsi nez dyka). Proto
# je `value * value_percent` jen FALLBACK pro predmet, ktery v tabulce neni.
# `buy = ceil(buy_percent/100 * sell)` plati vzdy (`GenericSell.cs:126-129`;
# research/06 §5.2). Restock 60 min a strop gumpu 250 radku: research/06 §2.3.
#
# POTREBUJE JEN `research/06` + `data/items.json` - NIKDY `assets/uo/` (v CI
# nejsou; proto `vendors.json` NENI v `potrebuji_tiles` v `main()`).
#
# Mapovani C# typu na predmet je podle JMENA z `data/items.json` (vlastnosti),
# ne podle poradi artu: `IronIngot` -> `iron ingot%s` -> typ `iron_ingot`.
# Co se nenajde, jde do `content-report.json` - nikdy fiktivni tile.
RESTOCK_MS = 60 * 60 * 1000
BUY_PERCENT = 190
VALUE_PERCENT = 100
GUMP_MAX_ROWS = 250
GOLD_ART = 0x4EED                      # zlato (`sim/entity/container.gd` case: GOLD)
VENDOR_ERA = "t2a"
VENDOR_SOURCE = "research/06 §2.2.1 + §2.4.1"

# Vendory z vyvojovych sad (AoS/SE/SA) - do klasickych shopu nepatri
# (research/06 §2.2.2). Kdyby zustaly, "vendors.json" by tvrdil pocet vcetne
# obsahu, ktery tato era nema.
SB_VYLOUCENE = {
    "SBNecromancer", "SBMystic", "SBKeeperOfBushido", "SBKeeperOfNinjitsu",
    "SBPlayerBarkeeper",
}

# Rucni aliasy pro odchylky jmen, ktere v `data/items.json` opravdu jsou pod
# jinym nazvem. Kazdy se overuje tim, ze se jmeno opravdu najde - jinak skonci
# v reportu jako nevyreseny (ticha nahrada by byla horsi nez zadna).
VENDOR_ALIASY = {"smith hammer": "smith's hammer"}

VENDOR_RADEK = re.compile(r"^\|\s*\*\*(?P<cls>[A-Za-z]+)\*\*")
VENDOR_SB = re.compile(r"`(SB[A-Za-z]+)`")
SB_NAZEV = re.compile(r"^#### `(SB[A-Za-z]+)`")
SB_STOCK = re.compile(r"\|\s*([A-Za-z][A-Za-z0-9]*)\s*\|\s*(\d+)\s*\|\s*(\d+)\s*\|")
SB_BUY = re.compile(r"\|\s*([A-Za-z][A-Za-z0-9]*)\s*\|\s*(\d+)\s*\|")


def parsuj_vendory(text: str) -> list[dict]:
    """§2.2.1 tabulka `Class | Title | Guild | ... | SBInfo | ...`."""
    v_oddilu = False
    out: list[dict] = []
    for radek in text.splitlines():
        if radek.startswith("#### "):
            if radek.startswith("#### 2.2.1"):
                v_oddilu = True
                continue
            if v_oddilu:
                break
        if not v_oddilu or not VENDOR_RADEK.match(radek):
            continue
        bunky = [b.strip() for b in radek.strip().strip("|").split("|")]
        if len(bunky) < 6:
            continue
        out.append({
            "class": bunky[0].replace("*", "").strip(),
            "title": bunky[1], "guild": bunky[2],
            "shops": VENDOR_SB.findall(bunky[5]),
        })
    return out


def parsuj_sb(text: str) -> dict:
    """§2.4.1 vsechny SBInfo: jmeno -> {stock: [(typ, cena, max)], buys: [(typ, cena)]}."""
    out: dict[str, dict] = {}
    aktualni: str | None = None
    for radek in text.splitlines():
        m = SB_NAZEV.match(radek)
        if m:
            aktualni = m.group(1)
            out[aktualni] = {"stock": [], "buys": []}
            continue
        if radek.startswith("### "):
            aktualni = None
            continue
        if aktualni is None:
            continue
        m3 = SB_STOCK.match(radek)
        if m3:
            out[aktualni]["stock"].append((m3.group(1), int(m3.group(2)), int(m3.group(3))))
            continue
        m2 = SB_BUY.match(radek)
        if m2:
            out[aktualni]["buys"].append((m2.group(1), int(m2.group(2))))
    return out


def vendor_kandidati(nazev: str) -> list[str]:
    """C# typ -> kandidati na jmeno v `data/items.json` (poradi je dane)."""
    zaklad = camel_jmeno(nazev).lower()
    kandidati = [zaklad]
    for role, jmeno in NASTROJE.items():
        if role == zaklad and jmeno.lower() != zaklad:
            kandidati.append(jmeno.lower())
    for klic, hodnota in VENDOR_ALIASY.items():
        if klic == zaklad and hodnota not in kandidati:
            kandidati.append(hodnota)
    return kandidati


def gen_vendors(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/vendors.json`, seznam nevyresenych referenci)."""
    cesta = root / "research/06-world-content-npcs.md"
    if not cesta.exists():
        raise ValueError("research/06-world-content-npcs.md chybi - bez nej vendory nelze vygenerovat")
    items_cesta = root / "data/items.json"
    if not items_cesta.exists():
        raise ValueError("data/items.json chybi - spust `--only items` (jmena predmetu)")
    text = cesta.read_text(encoding="utf-8")
    vendory = parsuj_vendory(text)
    sb = parsuj_sb(text)
    if not vendory:
        raise ValueError("research/06 §2.2.1: tabulka klasickych vendoru se neprecetla")
    if len(sb) < 50:
        raise ValueError(f"research/06 §2.4.1: precteno {len(sb)} SBInfo, ocekavano ~88")

    podle_jmena: dict[str, list[dict]] = {}
    for rec in json.loads(items_cesta.read_text(encoding="utf-8")):
        if isinstance(rec, dict) and rec.get("name"):
            podle_jmena.setdefault(str(rec["name"]).lower(), []).append(rec)

    nevyresene: list[dict] = []
    zaznamy: list[dict] = []

    def najdi_predmet(nazev: str) -> dict | None:
        for kandidat in vendor_kandidati(nazev):
            nalezy = najdi(podle_jmena, kandidat)
            if nalezy:
                return nalezy[0]
        return None

    def radek(rec: dict, cena: int, maximum: int | None) -> dict:
        out = {
            "type": str(rec.get("type", "")),
            "tile": int(rec["tile"]),          # TILEDATA ID (prostor `data/items.json`)
            "name": str(rec["name"]).replace("%s", "").replace("%", "").strip(),
            "price": cena,
        }
        if maximum is not None:
            out["max"] = maximum
        return out

    for v in vendory:
        stock: list[dict] = []
        buys: list[dict] = []
        videne_stock: set[str] = set()
        videne_buys: set[str] = set()
        pouzite: list[str] = []
        for jmeno_sb in v["shops"]:
            if jmeno_sb in SB_VYLOUCENE or jmeno_sb.startswith(("SBSE", "SBSA")):
                continue
            tabulka = sb.get(jmeno_sb)
            if tabulka is None:
                nevyresene.append({"soubor": "vendors.json", "kind": "sb",
                                   "nazev": f"{v['class']}/{jmeno_sb}",
                                   "duvod": "SBInfo v §2.4.1 neni"})
                continue
            pouzite.append(jmeno_sb)
            for nazev, cena, maximum in tabulka["stock"]:
                rec = najdi_predmet(nazev)
                if rec is None:
                    nevyresene.append({
                        "soubor": "vendors.json", "kind": "stock",
                        "nazev": f"{v['class']}/{jmeno_sb}/{nazev}",
                        "duvod": "jmeno neni v data/items.json (v instalaci chybi)"})
                    continue
                typ = str(rec.get("type", ""))
                if typ in videne_stock:
                    continue           # prvni vyskyt vyhrava (poradi SB je dane)
                videne_stock.add(typ)
                stock.append(radek(rec, cena, maximum))
            for nazev, cena in tabulka["buys"]:
                rec = najdi_predmet(nazev)
                if rec is None:
                    nevyresene.append({
                        "soubor": "vendors.json", "kind": "buys",
                        "nazev": f"{v['class']}/{jmeno_sb}/{nazev}",
                        "duvod": "jmeno neni v data/items.json (v instalaci chybi)"})
                    continue
                typ = str(rec.get("type", ""))
                if typ in videne_buys:
                    continue
                videne_buys.add(typ)
                buys.append(radek(rec, cena, None))
        if not stock or not buys:
            # Vendor bez zbozi nebo bez poptavky neni shop: do dat nepatri a
            # MUSI byt videt (jinak by "54 vendoru" bylo cislo z tabulky, ne z dat).
            nevyresene.append({
                "soubor": "vendors.json", "kind": "vendor",
                "nazev": f"{v['class']} ({','.join(pouzite) or '-'})",
                "duvod": f"nevyreseno: stock {len(stock)}, buys {len(buys)}"})
            continue
        zaznamy.append({
            "id": slug(v["class"]), "class": v["class"], "title": v["title"],
            "guild": v["guild"], "shops": pouzite, "restock_ms": RESTOCK_MS,
            "source": VENDOR_SOURCE, "era": VENDOR_ERA,
            "stock": stock, "buys": buys,
        })

    zaznamy.sort(key=lambda r: r["id"])        # deterministicke poradi
    data = {
        "config": {
            "buy_percent": BUY_PERCENT, "value_percent": VALUE_PERCENT,
            "restock_ms": RESTOCK_MS, "gump_max_rows": GUMP_MAX_ROWS,
            "gold_art": GOLD_ART, "source": VENDOR_SOURCE, "era": VENDOR_ERA,
            "_popis": [
                "Ceny jsou TADY (data), ne v kódu: `stock[].price` = tabulkova cena",
                "shopu (kolik dostane hrac za kus), `buys[].price` = tabulkova cena,",
                "`buy_price = ceil(buy_percent/100 * sell_price)` (`GenericSell.cs:126-129`).",
                "Predmet, ktery v tabulce neni, se oceni fallbackem `value_percent` z `value`",
                "v `data/items.json` - NAMERENE nespolehlive (longsword 6 vs dagger 20),",
                "proto je to fallback, ne zaklad. `restock_ms` = 60 min (research/06 §2.3).",
            ],
        },
        "vendors": zaznamy,
    }
    return bajty(data), nevyresene


# =============================================================================
# weapons.json — 134 zbrani (granule data.weapons, CONTRACT-M5 §3.1)
# =============================================================================
# ZDROJ: `research/_src/weapons3.json` (parsovano z `_src/servuo/.../Weapons/*.cs`
# skriptem `research/_src/parse_weapons3.py`). Je to EXTRAKT, ne instalace UO —
# `--check` proto projde i bez UO (docs/03 §3.7).
#
# ⚠⚠ ROZPOR `speed`, KTERY BYL ROZHODNUT (2026-10-10, `_analyza/p41-gen-m5.py`):
#   * `speed_raw` = `AosSpeed` ze zdroje. V datech je 22..56, median 37.
#   * CONTRACT-M5 §3.1 puvodne predepisoval `speed = 50 - speed_raw`. To byla
#     CHYBA MAPOVANI: `AosSpeed` JE uz ta rychlost, kterou ServUO dosadi do
#     `GetDelay` (`_src/servuo/.../BaseWeapon.cs:1541-1616`, `v = (Stam+100)*Speed`).
#     Po inverzi vyslo 128 ze 133 zbrani `speed <= 25` (14 i `<= 0`) a delay
#     4-100 s (median 8 s) — hra by se nedala hrat. `speed = speed_raw` dava
#     1,5-4,5 s (median 2,5 s).
#   * Prijimaci vzorec `max(floor(40000/((100+100)*speed))*500, 1250)` je
#     v poradku a beze zmeny: `speed=30 -> 3000 ms` (docs/04 §4.6.4).
# ROZHODNUTI: zapisuje se `speed = speed_raw` (`speed_source` to rika u kazdeho
# zaznamu). Inverze se NEZAPISUJE — data, ktera tvrdi nehratelne hodnoty, nejsou
# "obě varianty", jsou to hodnoty, ktere nikdo nepouzije.
# ⚠ Pozor: CONTRACT-M5 §3.1 ma k datu 2026-10-10 jeste PORAD text `50 - speed_raw`
# a priklad s `Dagger … speed_raw: 40, swing_delay_ms: 250` (coz neodpovida ani
# jednomu mapovani). Smlouva je vlastnictvi leada (`docs/**`, CONTRACT-M5) —
# opravit ji musi on; tenhle komentar je jen to, ze se to vi.
# ⚠ `speed <= 0` (Fukiya 0, PaladinSword 0) -> `swing_delay_ms: null` a zaznam
# `speed`/`swing_delay_ms` v `content-report.json`. To je vada ZDROJE, ne ticha
# nahrada: `GetDelay` by pro `speed = 0` vratil `TimeSpan.FromHours(1)`.
WEAPONS_SRC = "research/_src/weapons3.json"
WEAPONS_SOURCE = WEAPONS_SRC + " (parse _src/servuo Scripts/Items/Equipment/Weapons/*.cs)"
WEAPON_ERA = "aos"
# Kdo mapuje jmeno skillu, overi ho proti `data/skills.json` (`skill_source`).
# ServUO `DefSkill` nema stejna jmena jako klasicky klient: `Swords` (50 zbrani)
# je v `skills.json` `Swordsmanship`, `Macing` (41) je `Mace Fighting`.
WEAPON_SKILL_MAP = {
    "Swords": "Swordsmanship",
    "Macing": "Mace Fighting",
    "Fencing": "Fencing",
    "Archery": "Archery",
    "Wrestling": "Wrestling",
    "Throwing": "Throwing",
}
SPEED_DELAY_MS = 1250            # dolni mez swing delay (`BaseWeapon.cs:1613`)
TILEDATA_MASK = 0x3FFF           # `ItemID & 0x3FFF` = TILEDATA ID (docs/04 §4.5)


def slug_type(nazev: str) -> str:
    """`LeatherCap` -> `leather_cap` (typ = IDENTITA predmetu, jako v items.json)."""
    text = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", nazev)
    text = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", "_", text)
    return text.lower()


def swing_delay_ms(speed: int, stam: int = 100) -> int | None:
    """AoS swing delay (`_src/servuo/.../BaseWeapon.cs:1598-1615`).

    `v = (Stam + 100) * Speed`; `delay = floor(40000/v) * 500 ms`, dolni mez
    1250 ms. Pro `speed <= 0` vraci None: `GetDelay` by delil nulou nebo vysel
    zaporny — to neni "pomaly swing", to je nepouzitelny vstup."""
    if speed <= 0:
        return None
    return max(int(40000.0 // ((stam + 100) * speed)) * 500, SPEED_DELAY_MS)


def gen_weapons(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/weapons.json`, seznam nevyresenych veci)."""
    cesta = root / WEAPONS_SRC
    if not cesta.exists():
        raise ValueError(f"{WEAPONS_SRC} chybi - bez nej zbrane nelze vygenerovat")
    zdroj = json.loads(cesta.read_text(encoding="utf-8"))
    if not zdroj:
        raise ValueError(f"{WEAPONS_SRC}: prazdny seznam")
    # Skilly over proti `data/skills.json` (smlouva to pozaduje).
    skills_cesta = root / "data/skills.json"
    if not skills_cesta.exists():
        raise ValueError("data/skills.json chybi - spust `--only skills` "
                         "(mapovani skill_used se musi overit, ne uhodnout)")
    jmena_skillu = {r["name"] for r in json.loads(skills_cesta.read_text(encoding="utf-8"))}

    zaznamy: list[dict] = []
    nevyresene: list[dict] = []
    for rec in zdroj:
        cls = rec["class"]
        raw = rec.get("AosSpeed")
        if not isinstance(raw, (int, float)):
            nevyresene.append({"soubor": "weapons.json", "kind": "speed", "nazev": cls,
                               "duvod": "AosSpeed ve zdroji chybi -> speed nelze urcit"})
            raw = None
        # ⚠⚠ ROZHODNUTI 2026-10-10 (M5, po namERENI): `speed = AosSpeed`, NE
        # `50 - AosSpeed`. CONTRACT-M5 §3.1 mel inverzi a byla to CHYBA: ServUO
        # dosadi `AosSpeed` primo do `v = (Stam + 100) * Speed`
        # (`_src/servuo/Scripts/Items/Equipment/Weapons/BaseWeapon.cs:1598-1615`),
        # takze `Speed` JE ta rychlost. NamEReno: `50 - raw` dalo 128 ze 133
        # zbrani `speed <= 25` (14 dokonce `<= 0`) a `swing_delay_ms` 4-100 s,
        # zatimco `speed = raw` dava 1,5-4,5 s (median 2,5 s) - tedy hratelne
        # hodnoty a kriterium `speed=30 -> 3000 ms` z docs/04 §4.6.4 sedi.
        speed = int(raw) if raw is not None else None
        art = rec.get("itemid")
        art_src = "constructor"
        if not isinstance(art, int):
            kandidati = [a for a in (rec.get("art") or []) if isinstance(a, int)]
            art = kandidati[0] if kandidati else None
            art_src = "flipable" if art is not None else "pending-source"
        if art is None:
            nevyresene.append({"soubor": "weapons.json", "kind": "art", "nazev": cls,
                               "duvod": "art v konstruktoru ani [Flipable] neni"})
        # `itemid` je ART ID prostor (0x4000 = item); `art` v nasich datech je
        # TILEDATA ID (`ItemID & 0x3FFF`, docs/04 §4.5).
        tile = (art & TILEDATA_MASK) if isinstance(art, int) else None
        def_skill = rec.get("DefSkill")
        skill = WEAPON_SKILL_MAP.get(def_skill)
        skill_source = "DefSkill+" + WEAPONS_SRC
        if def_skill is None:
            skill_source = "pending-source"
            nevyresene.append({"soubor": "weapons.json", "kind": "skill", "nazev": cls,
                               "duvod": "DefSkill ve zdroji chybi"})
        elif skill is None:
            skill = def_skill
            skill_source = "DefSkill-unmapped+" + WEAPONS_SRC
            nevyresene.append({"soubor": "weapons.json", "kind": "skill", "nazev": cls,
                               "duvod": f"DefSkill {def_skill} neni v mape ani v skills.json"})
        elif skill not in jmena_skillu:
            nevyresene.append({"soubor": "weapons.json", "kind": "skill", "nazev": cls,
                               "duvod": f"mapovany skill {skill} v data/skills.json neni"})
        weight = rec.get("weight")
        zaznamy.append({
            "name": camel_jmeno(cls),
            "class": cls,
            "art": tile,
            "art_source": art_src if tile is not None else "pending-source",
            "skill_used": skill,
            "skill_source": skill_source,
            # `skill` a `damage` jsou TYTÉŽ hodnoty pod jmenem, ktere pozaduje
            # `check-content.py` (`REQUIRED_FIELDS` pro weapons.json: skill,
            # damage, speed, weight). CONTRACT-M5 §3.1 je pojmenovava
            # `skill_used`/`min_damage`/`max_damage`. Aby prosly obe brany a
            # nevznikly DVE pravdy, zapisuji se obe jmena se stejnou hodnotou.
            "skill": skill,
            "damage": [rec.get("AosMinDamage"), rec.get("AosMaxDamage")],
            "hands": 1 if (rec.get("DefMaxRange") == 1 or rec.get("DefMaxRange") is None)
                     else None,
            "min_damage": rec.get("AosMinDamage"),
            "max_damage": rec.get("AosMaxDamage"),
            "speed": speed,
            "speed_raw": int(raw) if raw is not None else None,
            "speed_source": ("AosSpeed+" + WEAPONS_SRC + "; `speed = AosSpeed` "
                             "(ServUO BaseWeapon.cs:1598-1615: `v = (Stam+100)*Speed`); "
                             "kriteria: speed 30 / stam 100 -> 3000 ms (docs/04 §4.6.4)"),
            "swing_delay_ms": swing_delay_ms(speed) if speed is not None else None,
            "swing_delay_source": "floor(40000/((stam+100)*speed))*500, min 1250 ms, "
                                  "stam=100 (_src/servuo .../BaseWeapon.cs:1598-1615)",
            "strength_req": rec.get("AosStrengthReq"),
            "weight": int(weight) if isinstance(weight, float) and weight == int(weight)
                      else weight,
            "durability": rec.get("InitMinHits"),
            "durability_max": rec.get("InitMaxHits"),
            "layer": None,
            "layer_source": "pending-tiledata",
            "special_move": rec.get("PrimaryAbility"),
            "special_move_secondary": rec.get("SecondaryAbility"),
            "anim": rec.get("DefAnimation"),
            "damage_type": rec.get("DefType"),
            "range": rec.get("DefMaxRange"),
            "material": None,
            "material_source": "pending-source",
            "era": WEAPON_ERA,
            "type": slug_type(cls),
            "source": WEAPONS_SOURCE,
        })
    zaznamy.sort(key=lambda r: (r["name"], r["class"]))     # deterministicke poradi
    # Souhrn rozporu `speed` (jeden zaznam, ne 134krat) - viz POZOR v hlavicce.
    male = [r["class"] for r in zaznamy if r["speed"] is not None and r["speed"] <= 0]
    if male:
        nevyresene.append({
            "soubor": "weapons.json", "kind": "speed-mapping",
            "nazev": f"{len(male)} zbrani se speed <= 0",
            "duvod": ("`AosSpeed` ve zdroji je 0 nebo zaporne - to je vada DAT, ne"
                      " mapovani (`speed = AosSpeed` je spravne, viz `speed_source`). "
                      "Priklady: " + ", ".join(sorted(male)[:8])),
        })
    return bajty(zaznamy), nevyresene


# =============================================================================
# armor.json — 165 zbroji (granule data.armor, CONTRACT-M5 §3.2)
# =============================================================================
# ZDROJ: `research/_src/armor_raw.json` (parse `Scripts/Items/Equipment/Armor/*.cs`).
#
# ⚠ `layer` a `slot` v serverovych zdrojich NEJSOU: ServUO bere vrstvu
# z tiledata (`Layer = (Layer)ItemData.Quality`), a `parse_armor.py` ji proto ma
# u vsech 165 zaznamu `null`. Do teto chvile plati `layer: null` +
# `layer_source: "pending-tiledata"` (docs/06 §6.4) — NIKDY nehadat.
# `slot` je ODVOZENY z nazvu tridy jen jako pojmenovani, ne jako vrstva:
# kazdy zaznam ma `slot_source`, aby bylo videt, ze to neni z tiledata.
ARMOR_SRC = "research/_src/armor_raw.json"
ARMOR_SOURCE = ARMOR_SRC + " (parse _src/servuo Scripts/Items/Equipment/Armor/*.cs)"
ARMOR_ERA = "aos"
# Poradi je dulezite: 'platelegs' musi byt pred 'legs' a 'plate' pred 'chest'.
ARMOR_SLOT_PRAVIDLA = (
    ("shield", ("shield", "buckler")),
    ("head", ("helm", "coif", "cap", "hat", "hood", "cowl", "circlet", "kabuto",
              "mask", "collar", "bonnet", "bandana")),
    ("neck", ("gorget", "collar")),
    ("chest", ("chest", "tunic", "torso", "hauberk", "breastplate", "plate", "robe",
               "surcoat", "dress")),
    ("arms", ("arms", "sleeves", "arm")),
    ("hands", ("gloves", "gauntlets")),
    ("legs", ("legs", "skirt", "kilt", "pants", "leggings", "leg")),
    ("feet", ("boots", "shoes", "sandals", "thigh")),
    ("waist", ("belt", "apron", "sash")),
    ("back", ("cloak", "cape", "quiver")),
)


def armor_slot(cls: str) -> tuple[str | None, str]:
    """`(slot, slot_source)` — ODVOZENO z nazvu tridy, nikdy z tiledata."""
    maly = slug_type(cls)
    if "shield" in maly or maly.endswith("buckler"):
        return "shield", "derived-classname"
    for slot, klice in ARMOR_SLOT_PRAVIDLA:
        if slot == "shield":
            continue
        if any(k in maly for k in klice):
            return slot, "derived-classname"
    return None, "pending-source"


def gen_armor(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/armor.json`, seznam nevyresenych veci)."""
    cesta = root / ARMOR_SRC
    if not cesta.exists():
        raise ValueError(f"{ARMOR_SRC} chybi - bez nej zbroje nelze vygenerovat")
    zdroj = json.loads(cesta.read_text(encoding="utf-8"))
    if not zdroj:
        raise ValueError(f"{ARMOR_SRC}: prazdny seznam")

    zaznamy: list[dict] = []
    nevyresene: list[dict] = []
    for rec in zdroj:
        cls = rec["class"]
        arts = [a for a in (rec.get("art_ids") or []) if isinstance(a, int)]
        tile = (arts[0] & TILEDATA_MASK) if arts else None
        if tile is None:
            nevyresene.append({"soubor": "armor.json", "kind": "art", "nazev": cls,
                               "duvod": "art_ids je prazdne (v .cs neni [Flipable] ani ctor ID)"})
        material = rec.get("material")
        material = material.split(".")[-1].lower() if isinstance(material, str) else None
        slot, slot_source = armor_slot(cls)
        ar = rec.get("armor_base")
        if ar is None:
            nevyresene.append({"soubor": "armor.json", "kind": "ar", "nazev": cls,
                               "duvod": "ArmorBase ve zdroji chybi -> ar: null"})
        if slot is None:
            nevyresene.append({"soubor": "armor.json", "kind": "slot", "nazev": cls,
                               "duvod": "slot se z nazvu tridy neodvodil -> null"})
        weight = rec.get("weight")
        str_req = rec.get("aos_str")
        zaznamy.append({
            "name": camel_jmeno(cls),
            "class": cls,
            "art": tile,
            "art_source": "art_ids+" + ARMOR_SRC if tile is not None else "pending-source",
            "slot": slot,
            "slot_source": slot_source,
            "layer": None,
            "layer_source": "pending-tiledata",
            "ar": ar,
            "ar_era": "aos",
            "resist": {
                "physical": rec.get("phys"), "fire": rec.get("fire"),
                "cold": rec.get("cold"), "poison": rec.get("pois"),
                "energy": rec.get("ener"),
            },
            "str_req": str_req,
            "str_req_source": "AosStrReq+" + ARMOR_SRC if str_req is not None
                              else "pending-source",
            "str_req_old": rec.get("old_str"),
            "weight": int(weight) if isinstance(weight, float) and weight == int(weight)
                      else weight,
            "durability": rec.get("init_min_hits"),
            "durability_max": rec.get("init_max_hits"),
            "material": material,
            "material_source": "MaterialType+" + ARMOR_SRC if material else "pending-source",
            "default_resource": (rec.get("def_resource") or "").split(".")[-1] or None,
            "meditation": (rec.get("med_allow") or "").split(".")[-1] or None,
            "era": ARMOR_ERA,
            "type": slug_type(cls),
            "source": ARMOR_SOURCE,
        })
    zaznamy.sort(key=lambda r: (r["name"], r["class"]))
    return bajty(zaznamy), nevyresene


# =============================================================================
# item_properties.json — 159 vlastnosti (granule data.item_properties, §3.3)
# =============================================================================
# ZDROJ: `research/_src/itemprops_table.tsv` (159 radku bez hlavicky, 6 sloupcu:
# id, enum, w, scale, start, max, per-slot stropy).
ITEMPROPS_SRC = "research/_src/itemprops_table.tsv"
ITEMPROPS_SOURCE = ITEMPROPS_SRC + " (parse _src/servuo Scripts/Misc/ItemProperty.cs)"
# Cisla jsou desetinna jen v `scale`/`max`; `id`/`start` jsou cela.
ITEMPROPS_SCOPE = re.compile(r"(?P<scope>[A-Za-z]+)\[scale=(?P<scale>-|\d+)"
                             r"\s+max=(?P<max>\d+)")


def gen_item_properties(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/item_properties.json`, seznam nevyresenych veci)."""
    cesta = root / ITEMPROPS_SRC
    if not cesta.exists():
        raise ValueError(f"{ITEMPROPS_SRC} chybi - bez nej vlastnosti nelze vygenerovat")
    radky = [x for x in cesta.read_text(encoding="utf-8").splitlines() if x.strip()]
    if not radky:
        raise ValueError(f"{ITEMPROPS_SRC}: zadne radky")

    zaznamy: list[dict] = []
    nevyresene: list[dict] = []
    for radek in radky:
        bunky = radek.split("\t")
        if len(bunky) < 6:
            nevyresene.append({"soubor": "item_properties.json", "kind": "radek",
                               "nazev": radek[:40],
                               "duvod": f"ocekavano 6 sloupcu, je {len(bunky)}"})
            continue
        cislo, enum, w, scale, start, maximum = (b.strip() for b in bunky[:6])
        m = re.fullmatch(r"w=(\d+)", w)
        ms = re.fullmatch(r"scale=(-?\d+)", scale)
        mst = re.fullmatch(r"start=(-?\d+)", start)
        mmax = re.fullmatch(r"max=(-?\d+)", maximum)
        if not (m and ms and mmax):
            nevyresene.append({"soubor": "item_properties.json", "kind": "sloupec",
                               "nazev": enum,
                               "duvod": f"sloupce se nectou: w='{w}' scale='{scale}' "
                                        f"max='{maximum}'"})
            continue
        scope = {}
        for shoda in ITEMPROPS_SCOPE.finditer(bunky[6] if len(bunky) > 6 else ""):
            scope[shoda.group("scope")] = {
                "max": int(shoda.group("max")),
                # `scale=-` znamena "v tomto scope se scale neuvadi" -> None,
                # NIKDY 0 (0 by tvrdilo "skaluje se nulou").
                "scale": (int(shoda.group("scale"))
                          if shoda.group("scale") != "-" else None)}
        nazev = enum.split(".")[-1]
        min_hodnota = int(mst.group(1)) if mst else 0
        max_hodnota = int(mmax.group(1))
        zaznamy.append({
            "id": int(cislo), "name": nazev, "enum": enum,
            "type": "int", "range": [min_hodnota, max_hodnota],
            "min": min_hodnota, "max": max_hodnota,
            "scale": int(ms.group(1)) != 0,
            "scales": int(ms.group(1)) != 0,
            "weight": int(m.group(1)),
            "scope": scope,
            "scope_source": ITEMPROPS_SRC,
            "source": ITEMPROPS_SOURCE,
        })
    zaznamy.sort(key=lambda r: r["id"])
    if len(zaznamy) != len(radky):
        nevyresene.append({"soubor": "item_properties.json", "kind": "pocet",
                           "nazev": f"{len(zaznamy)}/{len(radky)}",
                           "duvod": "ne vsechny radky se prevedly na zaznam"})
    return bajty(zaznamy), nevyresene


# =============================================================================
# monsters.json — monstra z `research/06` §3.1 (granule data.monsters, §3.4)
# =============================================================================
# ZDROJ: `research/06-world-content-npcs.md` §3.1 (tabulky Tier 1 + Tier 2;
# Tier 3/4 se berou tez, protoze tabulky jsou strojove a zdarma — rozhodnuti D2).
# Tabulky jsou 【C】 parsovane ze `Scripts/Mobiles/Normal/*.cs`.
#
# ⚠ `loot_pack` je PER MONSTRUM (sloupec Loot), NIKDY z fame — fame vybira loot
# jen paragonum (`_src/servuo/Scripts/Mobiles/Normal/BaseCreature.cs:5386-5408`,
# P18 v `PLAN-NPC-A-SOUBOJ-2026-10-08.md`).
# ⚠ `anim.walk/attack/die` = CISLO AKCE v `anim.mul`, ne poradi v abstraktni
# akci klienta (0=walk/1=run/2=attack/3=death/4=idle z CONTRACT-M5 §2).
#   `high` (tělo < 200) = `HighAnimationGroup`: Walk=0 (AnimationsLoader.cs:1696),
#                           Attack1=4 (:1700), Die1=2 (:1698)
#   `low`  (200..399)     = `LowAnimationGroup`:  Walk=0 (:1763), Attack1=5 (:1768),
#                           Die1=8 (:1771)
# Cisla jsou i v `tools/uoextract/anim.py:110-118` (`HIGH_GROUP_ACTIONS`,
# `LOW_GROUP_ACTIONS`); generator je cte odtamtud, aby existoval JEDEN zdroj.
MONSTERS_SRC = "research/06-world-content-npcs.md"
MONSTERS_SOURCE = (MONSTERS_SRC + " §3.1 (ServUO Scripts/Mobiles/Normal/*.cs); "
                   "anim = AnimationsLoader.cs:1694-1777")
ANIM_PY = "tools/uoextract/anim.py"
TIER_NAZEV = re.compile(r"^#### (Tier \d+)")
TIER_ANCHOR = "### 3.1"
MONSTERS_SKILLS_ANCHOR = "Skills:"
NOTORIETY_CAN_BE_ATTACKED = 3     # `_src/servuo/Server/Notoriety.cs:8` (výčet v research/06 §4.5)
LOOT_PACK_NAZVY = {
    "poor": "poor", "meager": "meager", "average": "average", "rich": "rich",
    "filthyrich": "filthy_rich", "ultrarich": "ultra_rich", "superboss": "super_boss",
    "gems": "gems", "potions": "potions", "lowscrolls": "low_scrolls",
    "medscrolls": "med_scrolls", "highscrolls": "high_scrolls",
}
# Zlato v pre-AoS pacich (`Old*`) — kostky PRIMO z `_src/servuo/Scripts/Misc/
# LootPack.cs`. Hodnoty se overuji CTENIM toho souboru (`over_loot_pack`):
# kdyby je zdroj zmenil, generator to hlasi, nez aby tise napsal stara cisla.
LOOTPACK_CS = "_src/servuo/Scripts/Misc/LootPack.cs"
LOOT_GOLD = {
    "poor": ("1d25", 422), "meager": ("5d10+25", 428), "average": ("10d10+50", 437),
    "rich": ("10d10+250", 447), "filthy_rich": ("2d125+400", 457),
    "ultra_rich": ("5d100+500", 468), "super_boss": ("5d100+500", 481),
}


def over_loot_pack(root: Path) -> list[dict]:
    """Overi zlato v `Old*` pacich proti zdroji `LootPack.cs` (jen cteni)."""
    cesta = root / LOOTPACK_CS
    if not cesta.exists():
        return [{"soubor": "monsters.json", "kind": "loot-pack",
                 "nazev": LOOTPACK_CS,
                 "duvod": "zdroj loot packu chybi — kostky zlata nelze overit"}]
    radky = cesta.read_text(encoding="utf-8").splitlines()
    vady: list[dict] = []
    for pack, (kostky, radek) in LOOT_GOLD.items():
        if radek - 1 >= len(radky):
            vady.append({"soubor": "monsters.json", "kind": "loot-pack", "nazev": pack,
                         "duvod": f"{LOOTPACK_CS} ma jen {len(radky)} radku, odkaz na {radek}"})
            continue
        if f'"{kostky}"' not in radky[radek - 1]:
            vady.append({"soubor": "monsters.json", "kind": "loot-pack", "nazev": pack,
                         "duvod": f"{LOOTPACK_CS}:{radek} neobsahuje \"{kostky}\" — "
                                  f"kostky zlata se rozešly se zdrojem"})
    return vady
# Skilly se v tabulkach pisi ZKRATKOU tridy (`MagicResist`), ale `data/skills.json`
# ma klasicka jmena (`Resisting Spells`). Kdo mapuje, overi to proti souboru;
# co v mape neni, se hlasi jako nevyresene (nikdy ticha nahrada).
MONSTER_SKILL_MAP = {
    "magicresist": "Resisting Spells", "evalint": "Evaluating Intelligence",
    "spiritspeak": "Spirit Speak", "detecthidden": "Detecting Hidden",
    "swords": "Swordsmanship", "macing": "Mace Fighting", "parry": "Parrying",
}
AI_MAPA = {"AI_Melee": "melee", "AI_Animal": "animal", "AI_Mage": "mage",
           "AI_NecroMage": "necro_mage", "AI_Berserk": "berserk", "AI_Healer": "healer"}
# Flagy z prozy §3.1 (kdo je undead, kdo ma jed).
UNDEAD = {"skeleton", "zombie", "ghoul", "bone_magi", "wraith", "spectre", "lich",
          "mummy", "shade", "skeletal_knight"}
POISON_HIT = {"slime": "lesser", "snake": "lesser", "giant_spider": "regular",
              "frost_spider": "regular", "scorpion": "greater", "giant_serpent": "greater",
              "dread_spider": "lethal"}
TAMABLE = {"rat": 0.1, "slime": 231, "snake": 591, "giant_spider": 591, "scorpion": 591}
# ⚠ NEUPLNOST ZDROJE (namEReno 2026-10-10): proza §3.1 VYPISUJE skilly jen
# u casti monster — chybi Scorpion a Harpy (Tier 2) a Wisp (Tier 3), ktere
# tabulka naopak ma. Rok 2026-10-10: `research/06` §3.1 tabulka uvadi
# "Wisp EvalInt/Magery/MagicResist/Tactics/Wrestling all 80.0" jednou vetou,
# ktera se neda precist strojove jako ostatni. Pro tato monstra (a pro
# OgreLord/ArcticOgreLord, kde je proza jen u Tier 4 jmen) se skilly berou
# z `SetSkill(SkillName.X, lo, hi)` v extraktu `.cache/analysis/monsters.tsv`
# (vystup `extract-monsters.ps1`, stejny zdroj jako tabulky §3.1). Kazdy
# takovy zaznam ma `skills_source` s tou cestou — nic se netvrdi jako z tabulky.
MONSTERS_TSV = ".cache/analysis/monsters.tsv"
SETSKILL = re.compile(r"SetSkill\(\s*SkillName\.(?P<skill>\w+)\s*,\s*"
                      r"(?P<lo>\d+(?:\.\d+)?)\s*(?:,\s*(?P<hi>\d+(?:\.\d+)?)\s*)?\)")


def skilly_z_tsv(root: Path, jmena_skillu: dict[str, str]) -> dict[str, dict]:
    """{typ monstra: {skill: [lo, hi]}} z extraktu `monsters.tsv` (fallback).

    Bere se JEN pro monstra, ktera v proze §3.1 skilly nemaji — a kazdy zaznam
    to priznava pres `skills_source`. Kdyz soubor chybi, vraci se prazdny
    slovnik (a monstrum zustane bez skillu, coz se hlasi — nikdy ticha nula)."""
    cesta = root / MONSTERS_TSV
    if not cesta.exists():
        return {}
    import csv
    import io
    out: dict[str, dict] = {}
    with io.open(cesta, encoding="utf-8-sig", newline="") as f:
        for radek in csv.DictReader(f, delimiter="\t"):
            cls = (radek.get("Class") or "").strip()
            if not cls:
                continue
            skilly: dict[str, list[int]] = {}
            for m in SETSKILL.finditer(radek.get("Skills") or ""):
                jmeno = jmena_skillu.get(m.group("skill").lower())
                if jmeno is None:
                    continue
                lo = desetiny(m.group("lo"))
                hi = desetiny(m.group("hi")) if m.group("hi") else lo
                skilly[jmeno] = [lo, hi]
            if skilly:
                out[MONSTER_ALIASY.get(cls, slug_type(cls))] = skilly
    return out
# ⚠ 13. rada tabulky §3.1 ma prvni bunku `**Bird** ("a crow")` — kdyby se
# `cls` bral z cele bunky, vyjde typ `birdacrow` a monstrum se nespari se svym
# radkem v tabulce skillu (namEReno). Bere se proto jen tucne jmeno.
MONSTER_CLS = re.compile(r"\*\*(?P<cls>[A-Za-z0-9]+)\*\*")
# Jmena trid, ktera se v tabulkach pisou jinak nez trida v ServUO.
MONSTER_ALIASY = {"BoneMagi": "bone_mage", "SewerRat": "sewer_rat"}


def monstrum_typ(bunka: str) -> str | None:
    """`'**Bird** ("a crow")'` -> `'bird'`; `'**GiantSerpent**'` -> `'giant_serpent'`."""
    m = MONSTER_CLS.search(bunka)
    if not m:
        return None
    cls = m.group("cls")
    return MONSTER_ALIASY.get(cls, slug_type(cls))
SNIPPET = re.compile(r"^\s*(?P<stat>STR|DEX|INT|Hits|Mana|Damage|"
                     r"BasePhysicalResistance|BaseFireResistance|BaseColdResistance|"
                     r"BasePoisonResistance|BaseEnergyResistance|VirtualArmor|"
                     r"SetDamage|AddLoot)\s*[=:(]")


def anim_groups() -> dict:
    """Mapa `{'high': {...}, 'low': {...}}` PRECTENA z `tools/uoextract/anim.py`.

    Cte se TEXT, ne import: `anim.py` importuje `uop.py` a pri importu saha na
    instalaci UO, ktera v CI neni (docs/03 §3.7). Kdyz se cisla v `anim.py`
    zmeni, generator to pozna jako rozpor — ticha kopie by byla horsi."""
    cesta = ROOT / ANIM_PY
    if not cesta.exists():
        raise ValueError(f"{ANIM_PY} chybi - cisla akci animaci nelze overit")
    text = cesta.read_text(encoding="utf-8")
    out: dict[str, dict[str, int]] = {}
    m = re.search(r"ABSTRACT_GROUPS\s*=\s*\{(.*?)\n\}", text, re.S)
    if not m:
        raise ValueError(f"{ANIM_PY}: ABSTRACT_GROUPS se necte")
    for nazev_skupiny, telo in re.findall(r'"(high|low|people)"\s*:\s*\{([^}]*)\}', m.group(1)):
        if nazev_skupiny == "people":
            continue
        polozky = dict(re.findall(r'"(\w+)"\s*:\s*(\d+)', telo))
        out[nazev_skupiny] = {k: int(v) for k, v in polozky.items()}
    if set(out) != {"high", "low"}:
        raise ValueError(f"{ANIM_PY}: ABSTRACT_GROUPS nema high/low ({sorted(out)})")
    return out


def anim_group(body: int) -> str:
    """`tools/uoextract/anim.py:group_kind` — tělo < 200 high, 200..399 low."""
    if body < 200:
        return "high"
    if body < 400:
        return "low"
    return "people"


def rozsah(bunka: str) -> list[int] | None:
    """`'56, 80'` -> `[56, 80]`; `'9'` -> `[9, 9]`; chybejici -> None."""
    cisla = [int(x) for x in re.findall(r"-?\d+", bunka)]
    if not cisla:
        return None
    return [cisla[0], cisla[-1]] if len(cisla) > 1 else [cisla[0], cisla[0]]


def prvni_cislo(bunka: str) -> int | None:
    """`'50 or 56 (random)'` -> 50; `'0x15'` -> 21; `'-450'` -> -450.

    ⚠ Znamenko se nesmi zahodit: `karma` je zaporna (namEReno — bez `-?` vyslo
    `karma: 450`, tedy monstrum "hodne")."""
    text = bunka.strip().replace("\u2212", "-")
    hexa = re.search(r"0x([0-9A-Fa-f]+)", text)
    m = re.search(r"-?\d+", text)
    if hexa and (m is None or hexa.start() <= m.start()):
        return int(hexa.group(1), 16)
    return int(m.group(0)) if m else None


def desetiny(text: str) -> int:
    """`'45.1'` -> 451; `'80'` -> 800 (skilly v `entity.skills` jsou desetiny)."""
    return int(round(float(text) * 10))


def parsuj_skilly(blok: str, jmena_skillu: dict[str, str]) -> dict[str, list[int]]:
    """`'MagicResist 4, Tactics 4, Wrestling 4'` -> `{'Resisting Spells':[40,40], ...}`.

    Jmena skillu se matchuji pres `MONSTER_SKILL_MAP` + normalizovane jmeno z
    `data/skills.json` (bez mezer, case-insensitive), takze slovo z prozy
    (`Wisp ... Wrestling all 80.0` -> `all`) se nikdy nevyrobi jako skill.
    Co se nenajde, se zahodi a hlasi vyssi."""
    out: dict[str, list[int]] = {}
    for m in re.finditer(r"(?P<jmeno>[A-Za-z][A-Za-z]*)\s+"
                         r"(?P<lo>\d+(?:\.\d+)?)\s*(?:[–\-]\s*(?P<hi>\d+(?:\.\d+)?))?",
                         blok):
        jmeno = m.group("jmeno").lower()
        klic = (MONSTER_SKILL_MAP.get(jmeno)
                or jmena_skillu.get(jmeno))
        if klic is None:
            continue
        lo = desetiny(m.group("lo"))
        hi = desetiny(m.group("hi")) if m.group("hi") else lo
        out[klic] = [lo, hi]
    return out


def monstrum_jmeno(cells: list[str], cls: str) -> str:
    """`'**BoneMagi** ("a bone mage")'` -> `'a bone mage'`."""
    bunka = cells[0]
    m = re.search(r'\(([^)]*)\)', bunka)
    if m:
        return m.group(1).strip().strip('"')
    return cls.lower()


def parsuj_monstra(root: Path) -> tuple[list[dict], list[dict]]:
    """Vraci (zaznamy, nevyresene). Cte tabulky z `research/06` §3.1."""
    cesta = root / MONSTERS_SRC
    if not cesta.exists():
        raise ValueError(f"{MONSTERS_SRC} chybi - bez nej monstra nelze vygenerovat")
    radky = cesta.read_text(encoding="utf-8").splitlines()
    text = (root / MONSTERS_SRC).read_text(encoding="utf-8")
    skills_cesta = root / "data/skills.json"
    if not skills_cesta.exists():
        raise ValueError("data/skills.json chybi - spust `--only skills` "
                         "(skilly monster se musi overit, ne uhodnout)")
    jmena_skillu = {r["name"].lower().replace(" ", ""): r["name"]
                    for r in json.loads(skills_cesta.read_text(encoding="utf-8"))}
    # Klic = jmeno, jak je v tabulce (`magicresist`), hodnota = jmeno z
    # `data/skills.json`. Mapa je lokalni kopie, aby se globalni konstanta
    # nemenila podle toho, co je na disku.
    mapa_skillu = dict(MONSTER_SKILL_MAP)
    for klic, jmeno in jmena_skillu.items():
        mapa_skillu.setdefault(klic, jmeno)
    jmena_skillu = mapa_skillu        # jedina mapa, se kterou se v tomto bloku pracuje

    zaznamy: list[dict] = []
    nevyresene: list[dict] = []
    v_oddilu, tier = False, None
    hlavicky: list[str] = []
    for i, radek in enumerate(radky):
        if radek.startswith("### "):
            v_oddilu = radek.startswith(TIER_ANCHOR)
            tier = None
            continue
        if not v_oddilu:
            continue
        m = TIER_NAZEV.match(radek)
        if m:
            tier = m.group(1)
            continue
        if radek.startswith("#### ") or not radek.startswith("|"):
            if radek.startswith("#### "):
                tier = None
            continue
        bunky = [b.strip() for b in radek.strip().strip("|").split("|")]
        if not any(bunky):
            continue
        if set("".join(bunky)) <= set("-: "):
            continue                       # oddelovac tabulky
        if tier is None:
            continue
        if bunky[0] == "Monster":
            # ⚠ V §3.1 jsou DVE tabulky se sloupcem "Monster": hlavni (Body, STR…)
            # a hned pod ni uzka "Monster | Skills" pro Tier 1. Kdyby se hlavicka
            # prepsala, `bunka["Body"]` spadne (namEReno) — hlavickou hlavni
            # tabulky proto pozna a uzka tabulka se ignoruje (skilly Tier 1 se
            # berou zvlast nize).
            if "Body" in bunky:
                hlavicky = bunky
            else:
                hlavicky, tier = [], None
            continue
        if not hlavicky or len(bunky) != len(hlavicky):
            nevyresene.append({"soubor": "monsters.json", "kind": "radek",
                               "nazev": radek[:50],
                               "duvod": f"sloupcu {len(bunky)} != hlavicka {len(hlavicky)}"})
            continue
        bunka = dict(zip(hlavicky, bunky))
        typ = monstrum_typ(bunky[0])
        if typ is None:
            nevyresene.append({"soubor": "monsters.json", "kind": "radek",
                               "nazev": radek[:50], "duvod": "jmeno monstra neni tucne"})
            continue
        cls = re.sub(r"[^A-Za-z0-9]", "", MONSTER_CLS.search(bunky[0]).group("cls"))
        body = prvni_cislo(bunka["Body"])
        if body is None:
            nevyresene.append({"soubor": "monsters.json", "kind": "body", "nazev": cls,
                               "duvod": f"body se necte z '{bunka['Body']}'"})
            continue
        skupina = anim_group(body)
        if skupina not in ("high", "low"):
            nevyresene.append({"soubor": "monsters.json", "kind": "anim_group",
                               "nazev": f"{cls} (body {body})",
                               "duvod": "body 400+ = People (lidska skupina) - "
                                        "`anim` z High/Low enumu by lhal"})
            continue
        va = rozsah(bunka.get("VA", ""))
        zaznamy.append({
            "type": typ, "id": typ, "class": cls,
            "name": monstrum_jmeno(bunky, cls),
            "body": body,
            "body_source": f"research/06 §3.1 {tier}, sloupec Body: '{bunka['Body']}'",
            "anim_group": skupina,
            "anim_group_source": "tools/uoextract/anim.py:group_kind (tělo < 200 high, "
                                 "200..399 low)",
            "tier": int(tier.split()[1]),
            "ai": AI_MAPA.get("AI_" + bunka.get("AI / FightMode", "").split("/")[0].strip()),
            "ai_raw": bunka.get("AI / FightMode"),
            "fight_mode": (bunka.get("AI / FightMode", "").split("/") + [""])[1].strip() or None,
            "str": rozsah(bunka["STR"]), "dex": rozsah(bunka["DEX"]),
            "int": rozsah(bunka["INT"]), "int_": rozsah(bunka["INT"]),
            "hits": rozsah(bunka["Hits"]),
            "mana": rozsah(bunka.get("Mana", "")),
            "damage": rozsah(bunka["Damage"]),
            "virtual_armor": va[0] if va else None,
            "virtual_armor_source": f"research/06 §3.1 {tier}, sloupec VA",
            "resist": None,
            "resist_source": "pending-source (tabulky §3.1 resisty nemaji; "
                             "docs/05 §5.16 = pre-AoS pouziva VirtualArmor)",
            "fame": prvni_cislo(bunka["Fame"]),
            "karma": prvni_cislo(bunka["Karma"]),
            "loot_pack": LOOT_PACK_NAZVY.get(
                re.sub(r"[^a-z]", "", bunka.get("Loot", "").split("+")[0].lower()), None),
            "loot_raw": bunka.get("Loot") or None,
            "loot": None,                      # doplni se nize (kostky z LootPack.cs)
            "loot_source": f"research/06 §3.1 {tier}, sloupec Loot (per monstrum, NIKDY z fame)",
            "notoriety": NOTORIETY_CAN_BE_ATTACKED,
            "notoriety_source": "research/06 §4.5 `Server/Notoriety.cs:8` — "
                                "CanBeAttacked = 3 (nepritele, ne zlocinec)",
            "flags": [], "taming_difficulty": TAMABLE.get(typ),
            "source": MONSTERS_SOURCE,
        })
    if not zaznamy:
        raise ValueError(f"{MONSTERS_SRC} §3.1: necte se zadna tabulka (Tier 1/2)")

    # --- skilly: tabulka Tier 1 + proza Tier 2 (viz hlavicka bloku) ---
    podle_typu = {r["type"]: r for r in zaznamy}
    # 1) Tier 1 ma vlastni tabulku `| Monster | Skills |`
    m = re.search(r"Skills for tier 1.*?\n(.*?)\n\n", text, re.S)
    if not m:
        raise ValueError(f"{MONSTERS_SRC}: tabulka 'Skills for tier 1' se necte")
    for radek in m.group(1).splitlines():
        if not radek.startswith("|") or set(radek.strip().strip("|")) <= set("-: |"):
            continue
        bunky = [b.strip() for b in radek.strip().strip("|").split("|")]
        if len(bunky) != 2 or bunky[0] == "Monster":
            continue
        typ = slug_type(re.sub(r"[^A-Za-z0-9]", "", bunky[0]))
        rec = podle_typu.get(typ)
        if rec is None:
            nevyresene.append({"soubor": "monsters.json", "kind": "skill",
                               "nazev": bunky[0], "duvod": "monstrum neni v tabulce §3.1"})
            continue
        rec["skills"] = parsuj_skilly(bunky[1], jmena_skillu)
        rec["skills_source"] = f"research/06 §3.1 tabulka 'Skills for tier 1'"
    # 2) Tier >= 2 ma skilly v proze ZA tabulkou (segmenty oddelene '·').
    # ⚠⚠ Blok NESMI zacinat hned za nadpisem: mezi tabulkou a radkem `Skills:`
    # stoji jeste nadpis druhe tabulky téhož tieru (`| **Lizardman** |`), ktery
    # je TAKY `**Jmeno**` — bez tohoto filtru se Lizardmanovi priradily skilly
    # OrcCaptaina (namEReno). Bere se proto az text od radku `Skills:`.
    # A hranice NESMI byt `^### ` — vnorene nadpisy `#### Tier N` maji taky 3+
    # `#`, takze by se do bloku Tier 2 nacetl i text Tier 3.
    for tier in (2, 3, 4):
        m = re.search(r"^#### Tier " + str(tier) + r"\b.*?$(.*?)(?=^#{3,} )",
                      text, re.S | re.M)
        if not m:
            raise ValueError(f"{MONSTERS_SRC}: blok 'Tier {tier}' se necte "
                             f"(hranice prozy se rozbila)")
        proza = m.group(1).split(MONSTERS_SKILLS_ANCHOR, 1)[-1]
        for segment in proza.split("·"):
            casti = segment.split()
            if not casti:
                continue
            typ = monstrum_typ(f"**{casti[0]}**")
            rec = podle_typu.get(typ) if typ else None
            if rec is None:
                continue
            # Zapisuje se JEN neprazdny vysledek: segment muze byt i z tabulky
            # taming (`Drake 84.3 (2)`) nebo z prozy o immunite — kdyby se
            # zapsal prazdny, PREPSAL by spravne skilly z tabulky Tier 3.
            skilly = parsuj_skilly(segment, jmena_skillu)
            if not skilly:
                continue
            rec["skills"] = skilly
            rec["skills_source"] = f"research/06 §3.1 proza za tabulkou Tier {tier}"
    # 3) fallback pro monstra, ktera proza §3.1 NEVYPISUJE (Scorpion, Harpy,
    # Wisp, OgreLord…): skilly z `SetSkill(...)` v `.cache/analysis/monsters.tsv`.
    tsv = skilly_z_tsv(root, jmena_skillu)
    for rec in zaznamy:
        if rec.get("skills") or rec["type"] not in tsv:
            continue
        rec["skills"] = tsv[rec["type"]]
        rec["skills_source"] = (f"{MONSTERS_TSV} (extract-monsters.ps1) — proza "
                                f"§3.1 skilly u tohoto monstra nevypisuje")
        nevyresene.append({"soubor": "monsters.json", "kind": "skills-fallback",
                           "nazev": rec["class"],
                           "duvod": "skilly vzaty z SetSkill v .cache/analysis/monsters.tsv "
                                    "(proza §3.1 je u tohoto monstra nevypisuje)"})
    # 4) kdo skilly nema ani po fallbacku, to se NESMI zamlcet
    for rec in zaznamy:
        if not rec.get("skills"):
            nevyresene.append({"soubor": "monsters.json", "kind": "skills",
                               "nazev": rec["class"],
                               "duvod": "skilly se z §3.1 ani z " + MONSTERS_TSV + " nacetly"})
        else:
            for jmeno, hodnoty in rec["skills"].items():
                if jmeno.lower().replace(" ", "") not in jmena_skillu:
                    nevyresene.append({"soubor": "monsters.json", "kind": "skill",
                                       "nazev": f"{rec['class']}/{jmeno}",
                                       "duvod": "skill neni v data/skills.json"})
        if rec["fame"] is None or rec["karma"] is None:
            nevyresene.append({"soubor": "monsters.json", "kind": "fame/karma",
                               "nazev": rec["class"], "duvod": "fame nebo karma se necte"})
        if rec["loot_pack"] is None and rec["loot_raw"]:
            nevyresene.append({"soubor": "monsters.json", "kind": "loot",
                               "nazev": f"{rec['class']}: {rec['loot_raw']}",
                               "duvod": "loot pack neni v LOOT_PACK_NAZVY"})
    # 5b) `loot` pro `check-content` (`REQUIRED_FIELDS`, docs/04 §4.5) — kostky
    # zlata z `LootPack.cs`, overene ctenim zdroje. Pre-AoS `Old*` (docs/05 §5.16).
    nevyresene.extend(over_loot_pack(root))
    for rec in zaznamy:
        pack = rec["loot_pack"]
        if pack is None:
            continue
        if pack in LOOT_GOLD:
            kostky, radek = LOOT_GOLD[pack]
            rec["loot"] = {"pack": pack, "gold_dice": kostky,
                           "gold_source": f"{LOOTPACK_CS}:{radek}",
                           "era": "pre-aos", "source": rec["loot_source"]}
        else:
            # Utility packy (gems, potions, scrolls) zlato NEMAJI.
            rec["loot"] = {"pack": pack, "gold_dice": None, "era": "pre-aos",
                           "source": rec["loot_source"],
                           "note": "utility pack (LootPack.Gems/Potions/…): zlato nema"}
    # 5) flagy z prozy §3.5 (undead / poison hit) — s ODKAZEM na odstavec,
    # ktery to tvrdi. Kdo si hodnotu overuje, ma ji odkud precist.
    for rec in zaznamy:
        if rec["type"] in UNDEAD:
            rec["flags"].append("undead")
            rec["flags_source"] = ("research/06 §3.5 (proza 'Undead flag': Skeleton, "
                                   "Zombie, Ghoul, Lich, BoneMagi, Wraith, Spectre, "
                                   "Mummy, Shade, SkeletalKnight)")
        if rec["type"] in POISON_HIT:
            rec["flags"].append("poisonous")
            rec["hit_poison"] = POISON_HIT[rec["type"]]
            rec["hit_poison_source"] = ("research/06 §3.5 (proza 'Poisoning (HitPoison)': "
                                        "Slime/Snake Lesser, GiantSpider Regular, "
                                        "Scorpion/GiantSerpent Greater, DreadSpider Lethal)")
    if not UNDEAD or not POISON_HIT:
        nevyresene.append({"soubor": "monsters.json", "kind": "flags", "nazev": "undead/poison",
                           "duvod": "tabulka flagu je prazdna - flagy by chybely vsem"})
    # 5) animace: cisla z `anim.py` (overeny zdroj), s uvedenim radku enumerace
    skupiny = anim_groups()
    radky_a = {"high": {"walk": 1696, "attack": 1700, "die": 1698},
               "low": {"walk": 1763, "attack": 1768, "die": 1771}}
    zdroj_enum = "_src/classicuo/src/ClassicUO.Assets/AnimationsLoader.cs"
    for rec in zaznamy:
        cisla = skupiny[rec["anim_group"]]
        rec["anim"] = {"walk": cisla["walk"], "attack": cisla["attack"], "die": cisla["die"]}
        rec["anim_source"] = (
            f"{zdroj_enum}:{min(radky_a[rec['anim_group']].values())}-"
            f"{max(radky_a[rec['anim_group']].values())} "
            f"({'High' if rec['anim_group'] == 'high' else 'Low'}AnimationGroup) "
            f"+ {ANIM_PY}:ABSTRACT_GROUPS")
    zaznamy.sort(key=lambda r: r["type"])
    return zaznamy, nevyresene


def gen_monsters(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/monsters.json`, seznam nevyresenych veci)."""
    zaznamy, nevyresene = parsuj_monstra(root)
    return bajty(zaznamy), nevyresene


# =============================================================================
# spawns.json — spawn tabulky (granule data.spawns, CONTRACT-M5 §3.5)
# =============================================================================
# ROZSAH M5 (rozhodnuti D2 v `PLAN-NPC-A-SOUBOJ-2026-10-08.md:178`): JEDNA
# tabulka — hrbitov u Britainu, monstra skeleton/zombie/rat. Souradnice jsou
# STRED HRBITOVA, ne "prvni tabulka, ktera se nasla":
#   * `docs/04 §4.6.7` (prodleva 5-10 min, refill `max((max-spawned)/3, 1)`),
#   * `research/06` §4.4/§4.8 F (Hrbitov: Skeleton 30, Zombie 24, ... respawn 6-12 min;
#     v M5 se berou tri monstra z D2, proto `monsters` obsahuje prave je),
#   * `research/06`:4362/4692 — Britain Graveyard je region `1333,1441 82x82`.
# Souradnice stredu regionu je odvozena z 82x82 boxu a je oznacena
# `position_source`, aby bylo videt, ze neni z `Spawns/felucca.xml`.
SPAWNS_SRC = "docs/04 §4.6.7 + research/06 §4.8 F (hřbitov; region 1333,1441 82x82)"
SPAWNS_SOURCE = SPAWNS_SRC
SPAWN_GRAVEYARD = {
    "id": "graveyard_britain",
    "region": "Britain Graveyard",
    "x": 1374, "y": 1482, "z": 0, "radius": 6,
    "max": 3,
    "delay_ms": [300000, 600000],
    "refill": "max((max - spawned) / 3, 1)",
    "monsters": ["skeleton", "zombie", "rat"],
    "monster_source": "rozhodnuti D2 (PLAN-NPC-A-SOUBOJ-2026-10-08.md:178) — "
                      "skeleton/zombie/rat; vaha dle research/06 §4.8 F "
                      "(Skeleton 30, Zombie 24, Rat z téhož hřbitova)",
    "weights": {"skeleton": 30, "zombie": 24, "rat": 18},
    "delay_source": "docs/04 §4.6.7 (prodleva 5-10 min; Spawner.cs:41, SpawnEntry.cs:536)",
    "position_source": "research/06:4362,4692 — region Britain Graveyard "
                       "1333,1441 82x82; střed regionu (1374,1482). "
                       "NENÍ z `Spawns/felucca.xml` (to je M7)",
    "source": SPAWNS_SOURCE,
}


def gen_spawns(root: Path) -> tuple[bytes, list[dict]]:
    """Vraci (bajty `data/spawns.json`, seznam nevyresenych veci)."""
    nevyresene: list[dict] = []
    # Monstra musi opravdu existovat v `data/monsters.json` - jinak spawn
    # odkazuje na monstrum, ktere hra nezna (a `check-content` to nezmeri).
    cesta = root / "data/monsters.json"
    if not cesta.exists():
        raise ValueError("data/monsters.json chybi - spust `--only monsters` "
                         "(spawn tabulka se musi overit proti datum monster)")
    typy = {r["type"] for r in json.loads(cesta.read_text(encoding="utf-8"))}
    for typ in SPAWN_GRAVEYARD["monsters"]:
        if typ not in typy:
            nevyresene.append({"soubor": "spawns.json", "kind": "monster", "nazev": typ,
                               "duvod": "monstrum neni v data/monsters.json"})
    if not SPAWN_GRAVEYARD["monsters"]:
        raise ValueError("spawns.json: zadna monstra v tabulce")
    data = {
        "config": {
            "tick_ms": 10000,
            "refill_rule": "max((max - spawned) / 3, 1)",
            "no_spawn_in_town": True,
            "source": SPAWNS_SOURCE,
        },
        "points": [SPAWN_GRAVEYARD],
    }
    return bajty(data), nevyresene


# =============================================================================
# rozdeleni prace: generatory, report, zapis
# =============================================================================
GENERATORY = {"items.json": gen_items, "recipes.json": gen_recipes,
              "skills.json": gen_skills, "vendors.json": gen_vendors,
              "weapons.json": gen_weapons, "armor.json": gen_armor,
              "item_properties.json": gen_item_properties,
              "monsters.json": gen_monsters, "spawns.json": gen_spawns}


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

    # `assets/uo/tiles.json` potrebuji jen generatory, ktere z nej vychazeji
    # (items a na nich zavisle recepty). `--only skills` na assets/uo vubec
    # nesaha - a `assets/uo/` v gitu NENI (docs/03 §3.8), takze bez tehle
    # podminky by `--only skills --check` nad spravnymi daty vyslo NEMERENO.
    potrebuji_tiles = [n for n in cil if n in ("items.json", "recipes.json")]
    if potrebuji_tiles and not (root / "assets/uo/tiles.json").exists():
        print("[gen] CHYBA: assets/uo/tiles.json neexistuje - spust napred "
              "`python tools/uoextract/tiledata.py --extract assets/uo`")
        return NEMERENO

    vada, nemereno, report = 0, 0, {"unresolved": [], "bez_generatoru": []}
    souhrn: dict[str, int] = {}
    for name in cil:
        hotovy, zdroj = POZADAVKY.get(name, (False, "?"))
        if not hotovy or name not in GENERATORY:
            report["bez_generatoru"].append({"soubor": name, "zdroj": zdroj,
                                             "duvod": "generator jeste neni napsany"})
            nemereno += 1
            print(f"[gen] NEMERENO {name}: generator chybi (zdroj by byl {zdroj})")
            continue
        try:
            raw, nenalezene = GENERATORY[name](root)
        except ValueError as exc:
            # Zdroj generatoru je rozbity (chybi extrakt, tabulka se necte, dva
            # zdroje si odporuji) - to je VADA s vetou, co je spatne, ne
            # traceback, ze ktereho `--check` nic neprecte (docs/08 §8.6).
            print(f"[gen] VADA {name}: {exc}")
            vada += 1
            continue
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
        # Sjednoceny tvar nevyresenych: items hlasi kategorie/role, recepty
        # soubor/kind/nazev. Bez toho by tisk spadl na cizi klice (namEReno).
        # POZOR: u receptu je nevyresenych REFERENCE tisice - vypis po jedne
        # zaplni obrazovku a schova vysledek (namEReno 2026-10-04). Souhrn + ukazky.
        for u in nenalezene:
            popis = (f"{u['kategorie']}/{u['role']}" if "role" in u
                     else f"{u['soubor']}/{u['kind']}: {u['nazev']}")
            souhrn[popis] = souhrn.get(popis, 0) + 1
        for popis, pocet in sorted(souhrn.items(), key=lambda kv: (-kv[1], kv[0]))[:25]:
            print(f"[gen]   NENALEZENO {'x' if pocet == 1 else f'x{pocet}'}: {popis}")
        if len(nenalezene) > 20:
            print(f"[gen]   ... celkem {len(nenalezene)} nevyresenych referenci "
                  f"({len(souhrn)} ruznych), zde top 25; plne v content-report.json")

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

    # Ukazky receptu: pocet bez tile muze sedet a vyber byt spatny (viz zadani
    # receptu, ktere v teto instalaci chybi - mereno 2026-10-04).
    recepty = root / "data/recipes.json"
    if recepty.exists():
        try:
            recs = json.loads(recepty.read_text(encoding="utf-8"))
        except (ValueError, OSError) as exc:
            print(f"[gen] ukazky receptu nelze vypisat ({exc}) - vysledek behu vyse plati")
        else:
            s_tiles = sum(1 for r in recs if "tile" in r["result"])
            m_tiles = sum(1 for r in recs for m in r["materials"] if "tile" in m)
            print(f"[gen] receptu {len(recs)}; vysledek ma tile {s_tiles}, "
                  f"material ma tile {m_tiles}/{sum(len(r['materials']) for r in recs)}")
            for r in recs[:4]:
                print(f"[gen]   {r['skill']}/{r['type']}: "
                      f"{r['result']['name']} <- "
                      + ", ".join(f"{m['amount']}x {m['name']}" for m in r["materials"]))

    if vada:
        return VADA
    return NEMERENO if nemereno else OK


if __name__ == "__main__":
    raise SystemExit(main())
