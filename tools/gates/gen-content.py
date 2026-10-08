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
            # `type` = IDENTITA PREDMETU (20. session): vsechny arty tehoz jmena
            # ji sdili, takze pravidla ("pouzij rudu na vyhen") se ptají typu,
            # ne cisla artu. Art zustava INDEX pro kresleni a `tiledata`.
            "type": slug(rec["name"]),
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
    podle_jmena: dict[str, list[int]] = {}
    for rec in predmety:
        podle_jmena.setdefault(rec["name"].lower(), []).append(rec["tile"])
    texty = Cliloc(CLILOC_INSTALL).cliloc_all()
    craft = json.loads((root / "research/04-craft-data.json").read_text(encoding="utf-8"))

    def najdi(jmeno: str) -> int | None:
        for k in (jmeno, jmeno + "%s", jmeno + "s", jmeno + "%"):
            if podle_jmena.get(k):
                return podle_jmena[k][0]
        return None

    def ref(kind: str, rec: dict) -> dict:
        """Jeden material/vysledek. Poradi: text kliloku -> C# typ."""
        text = klilok(rec.get("cliloc") or rec.get("name"), texty)
        for kandidat in (text, camel_jmeno(str(rec.get("type", "")))):
            if not kandidat:
                continue
            tile = najdi(kandidat.lower())
            if tile is not None:
                out = {"name": kandidat.lower(), "tile": tile}
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
# rozdeleni prace: generatory, report, zapis
# =============================================================================
GENERATORY = {"items.json": gen_items, "recipes.json": gen_recipes,
              "skills.json": gen_skills}


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
