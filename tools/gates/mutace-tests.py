#!/usr/bin/env python3
"""Mutacni dukaz testu z tests/cases/ (docs/09 §9.6 bod 3).

PROC: zeleny test bez mutace neznamena, ze test meri. Kazda mutace vraci do
kódu VADU a test ji musi chytit. U KAZDE mutace se overuji TRI veci ZVLAST
(bez nich je "spadlo" jen dohad):

  1. PROVEDENA  - text se zmenil a na DISKU je opravdu mutant (hash),
  2. PROBEHLALA - testovaci sada vubec probehla: "N kontrol, M selhani" s N > 0,
  3. CHYCENA    - exit != 0 a aspon jeden radek "[test] FAIL <modul> ...",
                  tedy selhala KONTROLA toho modulu (ne neco jineho).

Navic se overuje SMLOUVA O VSTUPU: test musi brat merenou cestu z argumentu
(`-- --sort-script=...`, `-- --map-script=...`). Dokazuje se to tim, ze se
preda NEEXISTUJICI cesta - test na to MUSI selhat. Kdyby neselhal, meril by
porad vychozi soubor a mutace by "prochazely" (HANDOFF 2026-10-06, past 2).

Baseline (bez mutace) se pousti PRVNI a musi dat 0 selhani - jinak by
"mutace spadla" neznamenalo nic. Nakonec se overi, ze se original na disku
NEZMENIL (mutuje se jen kopie v .cache/gates/mutace/).

SEZNAM MUTACI JE ZAMERNE JEN TO, CO TESTY OPRAVDU CHYTI. NamEReno 2026-10-06:
mutace `_lower` `return a[0] < b[0]` -> `return a[0] <= b[0]` se u Godotu
neprojevi (1000 objektu se stejnym klicem i 200 smisenych dalo stejne poradi
jako spravny kod), takze v seznamu NENI - tvrdit u ni "CHYCENA" by bylo
tvrzeni o nemerenem. Kdo ji tam prida, dostane PROSLA a vi, ze je to slepe
misto, ne vada testu.

  python tools/gates/mutace-tests.py            # vsechny moduly
  python tools/gates/mutace-tests.py --only sort
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import godot_bin, godot_run  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TESTS = "res://tests/run_tests.gd"
MUTANT_DIR = ROOT / ".cache" / "gates" / "mutace"
SOUHRN = re.compile(r"(\d+)\s+kontrol,\s*(\d+)\s+selh")

# klic -> soubor, ktery se mutuje, prefix FAIL radku a prepinac testu
MODULY = {
    "sort": {
        "soubor": ROOT / "render" / "sort.gd",
        "prefix": "render.sort",
        "prepinac": "--sort-script",
        "mutace": [
            ("vrstvy prohozene (static jako mobilni)",
             '"static": LAYER_STATIC', '"static": LAYER_MOBILE'),
            ("item mimo mobilni vrstvu",
             '"item": LAYER_MOBILE', '"item": LAYER_STATIC'),
            ("land jako mobilni",
             '"land": LAYER_LAND', '"land": LAYER_MOBILE'),
            ("neznamy kind jako land",
             "else LAYER_MOBILE", "else LAYER_LAND"),
            ("z descendo",
             "(z - Const.Z_MIN)", "(Const.Z_MAX - z)"),
            ("z vraceno, ne z",
             "(z - Const.Z_MIN)", "(z + Const.Z_MIN)"),
            ("z se nesveruje",
             'clampi(int(obj.get("z", 0)), Const.Z_MIN, Const.Z_MAX)',
             'int(obj.get("z", 0))'),
            ("diagonala x-y",
             'int(obj.get("x", 0)) + int(obj.get("y", 0))',
             'int(obj.get("x", 0)) - int(obj.get("y", 0))'),
            ("nestabilni razeni (rovna se vraci false)",
             "return a[1] < b[1]", "return false"),
            ("spatny radix vrstev (LAYERS 3 -> 2)",
             "const LAYERS: int = 3", "const LAYERS: int = 2"),
        ],
    },
    "map": {
        "soubor": ROOT / "sim" / "world" / "map.gd",
        "prefix": "world.map",
        "prepinac": "--map-script",
        "mutace": [
            ("z zpet na offset +3 (= lokalni y)",
             '"z": data.decode_s8(at + 4)', '"z": data.decode_s8(at + 3)'),
            ("x cte bajt y",
             '"x": data.decode_u8(at + 2)', '"x": data.decode_u8(at + 3)'),
            ("x se neprecte (vsechny statiky na x = 0)",
             '"x": data.decode_u8(at + 2)', '"x": 0'),
            ("bunka v bloku po sloupcich",
             "return (y % Const.BLOCK_SIZE) * Const.BLOCK_SIZE + (x % Const.BLOCK_SIZE)",
             "return (x % Const.BLOCK_SIZE) * Const.BLOCK_SIZE + (y % Const.BLOCK_SIZE)"),
            ("index bloku y-major",
             "var key := bx * _blocks_y + by", "var key := by * _blocks_x + bx"),
            ("hlavicka bloku v .land se preskoci",
             "_land.seek(key * (LAND_HEADER_BYTES + want) + LAND_HEADER_BYTES)",
             "_land.seek(key * (LAND_HEADER_BYTES + want))"),
            ("z_at cte bajt dlazdice misto z",
             "return cells.decode_s8(_cell_at(x, y) * CELL_BYTES + 2)",
             "return cells.decode_s8(_cell_at(x, y) * CELL_BYTES)"),
            ("land_at cte posunuty bajt",
             "return cells.decode_u16(_cell_at(x, y) * CELL_BYTES)",
             "return cells.decode_u16(_cell_at(x, y) * CELL_BYTES + 1)"),
            ("statics_at vraci jen prvni zaznam",
             'out = entry["statics"]', 'out = entry["statics"].slice(0, 1)'),
            ("zaporna y se nekontroluji",
             "if x < 0 or y < 0:", "if x < 0:"),
            ("blocks_x se cte z blocks_y",
             '_blocks_x = int(meta.get("blocks_x", 0))',
             '_blocks_x = int(meta.get("blocks_y", 0))'),
        ],
    },
    "walk": {
        "soubor": ROOT / "sim" / "world" / "walk.gd",
        "prefix": "world.walk",
        "prepinac": "--walk-script",
        "mutace": [
            ("krok nahoru jen o 1 (STEP_HEIGHT ignorovan)",
             "if dz > vyska_kroku:", "if dz > 1:"),
            ("voda neblokuje",
             "if _tiledata.flags(land) & F_WET != 0:", "if false:"),
            ("diagonala symetricka i pro hrace",
             "if dx != 0 and dy != 0 and is_player:", "if false:"),
            ("statik s Impassable neblokuje",
             "func _blokuje_statik(x: int, y: int, z: int, height: int) -> bool:",
             "func _blokuje_statik(x: int, y: int, z: int, height: int) -> bool:\n\treturn false\n"),
            ("surface_z ignoruje flag Surface",
             "if _flags(tile) & F_SURFACE == 0:", "if true:"),
            ("statik se bere z celeho bloku (ignoruje lokalni x,y)",
             'if int(s["x"]) == x % Const.BLOCK_SIZE and int(s["y"]) == y % Const.BLOCK_SIZE:',
             "if true:"),
            # NamEReno 2026-10-07: tahle mutace je PRESNE vada, ktera v kódu byla -
            # statik se cetl syrovym id a tiledata u nej vratila tabulku LAND
            # (1717 -> 'grass'/0x0 misto 'wooden door'/0x20006050). V realne mape
            # tim proslo 1325 kroku do dlazdice s Impassable statikem.
            ("statik se cte bez +0x4000 (tabulka LAND)",
             "return _tiledata.flags(tile + ITEM_OFFSET)",
             "return _tiledata.flags(tile)"),
            ("vyska statiku se cte z tabulky LAND (schody maji vysku 0)",
             "return _tiledata.height(tile + ITEM_OFFSET)",
             "return _tiledata.height(tile)"),
            ("dvere jako dvere (stav se ignoruje, vsechny blokuji)",
             "		if flags & F_DOOR != 0:", "		if false:"),
            ("kazde dvere jsou otevrene (zavrene neblokuji)",
             "			if _doors.is_open(tile):\n				continue",
             "			if true:\n				continue"),
            ("vyskove pasmo statiku se ignoruje (blokuje se vzdy)",
             "if do > z and nase_do > od:", "if true:"),
            ("schod se chova jako plosina (vyska kroku = STEP_HEIGHT)",
             "			vyska = maxi(vyska, _height(tile))", "			vyska = Const.STEP_HEIGHT"),
        ],
    },
    "doors": {
        "soubor": ROOT / "sim" / "world" / "doors.gd",
        "prefix": "world.doors",
        "prepinac": "--doors-script",
        "mutace": [
            # Konvence paru je ZMERENA 2026-10-07 (8. session): art z doors.txt
            # je zavreny, jeho +1 otevreny. Tahle mutace vraci presne tu vadu,
            # ktera v modulu byla do 8. session (index +- 4 = jiny smer).
            ("toggle vraci druhy SMER misto otevreniho artu (stary omyl index + 4)",
             "\tif _by_tile.has(tile):\n\t\treturn tile + 1",
             "\tif _by_tile.has(tile):\n\t\tvar e: Dictionary = _by_tile[tile]\n"
             "\t\treturn int(_categories[int(e[\"category\"])][\"tiles\"][(int(e[\"index\"]) + 4) % PIECES])"),
            ("otevreno = sudy art (parita misto clenstvi v doors.txt)",
             "\treturn not _by_tile.has(tile) and _by_tile.has(tile - 1)",
             "\treturn tile % 2 == 0"),
            ("otevreny art se hleda jako +1 (opacny smer dvojice)",
             "\treturn not _by_tile.has(tile) and _by_tile.has(tile - 1)",
             "\treturn not _by_tile.has(tile) and _by_tile.has(tile + 1)"),
            ("vratna cesta z otevreneho artu vraci +1",
             "\t\treturn tile - 1", "\t\treturn tile + 1"),
            ("is_door plati jen pro art z doors.txt (pootoceny ne)",
             "\treturn found != null or _by_tile.has(tile - 1)",
             "\treturn found != null"),
            ("kategorie/orientace otevreneho artu se nenajde",
             "\treturn _by_tile.get(tile - 1)", "\treturn null"),
            ("orientace zpet na 'index % 4' (stary omyl)",
             "\treturn -1 if found == null else int(found[\"index\"])",
             "\treturn -1 if found == null else int(found[\"index\"]) % 4"),
            ("open_tile zapomene +1 (vrati zavreny art)",
             "\treturn 0 if closed == 0 else closed + 1", "\treturn closed"),
        ],
    },
    "registry": {
        "soubor": ROOT / "sim" / "entity" / "registry.gd",
        "prefix": "sim.entity_registry",
        "prepinac": "--registry-script",
        "mutace": [
            ("neznamy serial vraci mobil 0",
             "return _mobily.get(serial)", "return _mobily.get(0)"),
            ("all() vraci v poradi vlozeni (ne podle serialu)",
             "var serialy: Array = _mobily.keys()\n\tserialy.sort()",
             "var serialy: Array = _mobily.keys()"),
            ("remove maze podle klice 0, ne podle serialu",
             "_mobily.erase(serial)", "_mobily.erase(0)"),
            ("registr prijme i mobil bez kladneho serialu",
             "if m == null or int(m.serial) <= 0:", "if m == null:"),
        ],
    },
    "pathfind": {
        "soubor": ROOT / "sim" / "world" / "pathfind.gd",
        "prefix": "sim.pathfind",
        "prepinac": "--pathfind-script",
        "mutace": [
            ("cil se nikdy netrefi (cesta vzdy prazdna)",
             "if cur.x == to.x and cur.y == to.y and cur.z == to.z:",
             "if false:"),
            ("diagonala stoji jako ortogonala (cena 200 misto 141)",
             "var cost: int = COST_STEP if dir % 2 == 0 else COST_DIAG",
             "var cost: int = COST_STEP if dir % 2 == 0 else 2 * COST_STEP"),
            ("frontier se nevybira podle ceny (bere se prvni uzel)",
             "var index := _best(frontier, g, to)", "var index := 0"),
            ("heuristika je neprustezna (Chebyshev * 141 prekroci cenu)",
             "\treturn diagonal * COST_DIAG + rovne * COST_STEP + dz * COST_Z",
             "\treturn maxi(dx, dy) * COST_DIAG + dz * COST_Z"),
            ("rozpocet uzlu se nikdy nevycerpa (_nodes zacina na -1000000)",
             "	_nodes = 0", "	_nodes = -1000000"),
            ("predchudce se neuklada (cesta se neda poskladat)",
             "			parent[nxt] = cur\n", ""),
        ],
        # CO TU ZAMERNE NENI (a proc):
        #   * "cena uzlu se neporovnava obracene" (`<=` -> `>`) ZKOUSENA a do
        #     seznamu NEPATRI: hledani se zacykli v rekonstrukci cesty, Godot
        #     nedobehne do 900 s, harness hlasi "SADA VUBEC NEPROBEHLA (0 kontrol)"
        #     - a to NENI dukaz, ze test meri (ne rozlisuje zaseknuti od pomaleho
        #     behu). Je to otevrena vec 53 v HANDOFF.md, ne zelená.
        #   * "diagonala stoji jako ortogonala" ve VERZI, ktera meni jen cenu
        #     (200 misto 141): testy na POCET KROKU ji nechyti, protoze A* i s ni
        #     dojde stejnou trasou - chyti ji az kontrola `cost_last()` (a ta tam
        #     je). Kdyby se vyhodila, byla by to slepá kontrola.
    },
    "textures": {
        "soubor": ROOT / "render" / "texture_cache.gd",
        "prefix": "render.textures",
        "prepinac": "--textures-script",
        "mutace": [
            # Tahle mutace vraci VADU, ktera 2026-10-07 shodila hru na 1-2 FPS:
            # nova `AtlasTexture` na kazde volani (0,118 ms x 5767 objektu).
            ("texture() vraci novou instanci (ztrata cache oken)",
             "\t_wrapped[art_id] = out\n\treturn out", "\treturn out"),
            ("na stranku se nepta cache (nacte ji znovu pokazde)",
             "	var cached = _pages.get(path)\n	if cached != null:\n		_touch(path)\n		return cached",
             "	var cached = _pages.get(path)"),
            ("chybejici art se pocita jako nula (missing se nemeri)",
             "		_missing += 1\n", ""),
        ],
    },
    "item": {
        "soubor": ROOT / "sim" / "entity" / "item.gd",
        "prefix": "sim.entity.item",
        "prepinac": "--item-script",
        "mutace": [
            ("predmet na zemi se hlasi jako v kontejneru (parent obracene)",
             "return parent == 0", "return parent != 0"),
            ("vaha hromady ignoruje mnozstvi",
             "return unit_weight * amount", "return unit_weight"),
            ("mnozstvi se z konstruktoru neprevezme (vzdy 1)",
             "amount = amount_value", "amount = 1"),
            ("same_pile ignoruje hue (sloucil by ruzne barvy)",
             "tile == other.tile and hue == other.hue", "tile == other.tile"),
            ("same_pile vraci true i pro prazdnou hromadu",
             "and other.amount > 0", "and true"),
        ],
    },
    "container": {
        "soubor": ROOT / "sim" / "entity" / "container.gd",
        "prefix": "sim.entity.container",
        "prepinac": "--container-script",
        "mutace": [
            ("limit predmetu se vubec nekontroluje",
             "if _obsah.get(c, []).size() >= _max_items:", "if false:"),
            ("limit predmetu je o jedna vyssi (>= -> >)",
             "if _obsah.get(c, []).size() >= _max_items:",
             "if _obsah.get(c, []).size() > _max_items:"),
            ("vaha se nekontroluje",
             "if has_weights() and weight_of(c) + _vaha(item) > _max_weight:", "if false:"),
            ("limit hromady (MAX_STACK) se nekontroluje",
             "if int(item.amount) > Const.MAX_STACK:", "if false:"),
            ("predmet muze byt ve DVOU kontejnerech (predchozi se nevyjme)",
             "if int(item.parent) != 0 and int(item.parent) != c:\n\t\t_vyjmi(int(item.parent), item)",
             "if false:\n\t\t_vyjmi(int(item.parent), item)"),
            ("hromady se neslucuji",
             "var cil = _cil_slouceni(c, item)\n\tif cil != null:", "var cil = null\n\tif cil != null:"),
            ("slouceni prekroci MAX_STACK",
             "var prevedeno: int = mini(int(item.amount), Const.MAX_STACK - int(cil.amount))",
             "var prevedeno: int = int(item.amount)"),
            ("plna hromada se povazuje za cil slouceni",
             "if predmet.same_pile(item) and int(predmet.amount) < Const.MAX_STACK:",
             "if predmet.same_pile(item):"),
            ("stackable flag se cte obracene",
             "(int(_tiledata.flags(tile)) & F_STACKABLE) != 0",
             "(int(_tiledata.flags(tile)) & F_STACKABLE) == 0"),
            ("vaha hromady ignoruje mnozstvi",
             "return int(_tiledata.weight(int(predmet.tile))) * int(predmet.amount)",
             "return int(_tiledata.weight(int(predmet.tile)))"),
            ("remove vraci 0, i kdyz predmet odstranil",
             "\treturn brat", "\treturn 0"),
            ("contents vraci poradi vlozeni (ne serazene)",
             "\tserialy.sort()", "\tpass"),
            ("stejny predmet se prida dvakrat (duplikat v obsahu)",
             "if _najdi(c, int(item.serial)) != null:", "if false:"),
            ("predmet bez serialu se prijme",
             "if int(item.serial) <= 0:", "if false:"),
            ("bez tiledata se vaha hlasi jako namERena",
             "# Bez tiledata se vaha nemeri - volajici to musi poznat (nula neni uspech).\n	return _tiledata != null",
             "# Bez tiledata se vaha nemeri - volajici to musi poznat (nula neni uspech).\n	return true"),
        ],
    },
    "movement": {
        "soubor": ROOT / "sim" / "systems" / "movement.gd",
        "prefix": "sim.movement",
        "prepinac": "--movement-script",
        "mutace": [
            ("chuze ma prodlevu behu (200 misto 400)",
             "return Const.RUN_MS if run else Const.WALK_MS", "return Const.RUN_MS"),
            ("krok se vykona hned (prodleva 0)",
             '"due_ms": _now() + delay', '"due_ms": _now()'),
            ("druhy krok v letu se neodmitne",
             'if _pending.has(m):', "if false:"),
            ("beh nebere staminu",
             '\tif run or _drain_model == "emulator":\n\t\tconsume_stamina(m, 1)',
             "\tif false:\n\t\tconsume_stamina(m, 1)"),
            ("emulator zapomina zbytek kroku",
             "var celkem: int = int(_carry.get(m, 0)) + steps",
             "var celkem: int = steps"),
            ("is_player se nepredava (kazdy je hrac)",
             "m == player_serial", "true"),
            ("bez staminy se porad bezi",
             "if use_run and mob.stam <= 0:", "if false:"),
        ],
    },
    "interaction": {
        "soubor": ROOT / "sim" / "systems" / "interaction.gd",
        "prefix": "sim.interaction",
        "prepinac": "--interaction-script",
        "mutace": [
            # Kovadlina a vyhen maji v datech `category == "tool"`, ale jsou to
            # CÍLE - tahle mutace z nich udela nastroje (a `use` na ne zacne
            # delat "cekam na cil" misto "nic se nedeje").
            ("kovadlina se bere jako nastroj (TARGET_ROLES se ignoruje)",
             'elif cat == "tool" and not (role in TARGET_ROLES):', 'elif cat == "tool":'),
            # Dvere se poznavaji z artu (`world.doors.is_door`) - bez toho je
            # dvojklik na ne "neznamy predmet".
            ("dvere se nepoznaji (is_door se ignoruje)",
             "\t\tif _is_door(tile):", "\t\tif false:"),
            # Hlaska je jedina obrana proti tichu ("neznamy predmet -> hlaska").
            ("hlaska se nikam neposle (ticho)",
             '\t_event("message", {"text": text, "kind": "system"})',
             "\tpass"),
            # Chybejici system MUSI byt videt - nesmi vypadat jako uspech.
            ("chybejici system vypada jako uspech",
             '\t\treturn _fail("not_available")\n\tvar res = system.callv(method, args)',
             '\t\treturn {"ok": true, "action": akce, "reason": ""}\n\tvar res = system.callv(method, args)'),
            # Dynamicky routing: kdyz se system nenajde, nezavola se nikdy.
            ("system se v SimWorld.systems nikdy nenajde",
             "\tif systems is Dictionary and systems.has(name):", "\tif false:"),
            # Parova tabulka musi porovnavat OBE strany (jinak se kladivo chová
            # jako by cil byl anvil, i kdyz je to zlato).
            ("par se porovnava jen podle zdroje (cil se ignoruje)",
             '\t\tif str(par["od"]) == str(od.get("role", "")) and str(par["na"]) == hledane_na:',
             '\t\tif str(par["od"]) == str(od.get("role", "")):'),
            # Slouceni hromad se musi zastavit na MAX_STACK (docs/05 §5.4).
            ("slouceni prekroci MAX_STACK",
             "\tvar prevedeno: int = mini(int(zdroj.amount), Const.MAX_STACK - int(cil.amount))",
             "\tvar prevedeno: int = int(zdroj.amount)"),
            # Slouci se jen STEJNA hromada (tile + hue).
            ("slouci se i jina hromada (same_pile se ignoruje)",
             "\tif cil == null or zdroj == null or not zdroj.same_pile(cil):",
             "\tif cil == null or zdroj == null:"),
            # Prepnuti dveri je `toggle` z world.doors (konvence z 8. session).
            ("dvere se prepnou na opacny clen dvojice",
             "\tvar novy: int = int(_doors.toggle(tile))", "\tvar novy: int = int(tile) - 1"),
            # Id prostory: `entity.item.tile` je ART ID, data maji TILEDATA ID.
            ("id prostor se neprevadi (art id se hleda jako tiledata id)",
             "\t\tvar rec = _by_tile.get(tile - ITEM_OFFSET)", "\t\tvar rec = _by_tile.get(tile)"),
            # Neznamy cil NESMI skoncit jako uspech.
            ("neznamy cil se tvari jako uspech",
             '\treturn _fail("unknown")\n\n\nfunc _toggle_door',
             '\treturn {"ok": true, "action": "nothing", "reason": ""}\n\n\nfunc _toggle_door'),
            # Cislo, ktere klient zna (research/01 §2.4).
            ("paperdoll ma spatne cislo klienta",
             "const ENTRY_PAPERDOLL := 0x0193", "const ENTRY_PAPERDOLL := 0x0194"),
            # Batoh bez `backpack` se nema otevrit prazdny.
            ("batoh se otevre i bez `backpack`",
             "\t\t\tif mob == null or int(mob.backpack) <= 0:",
             "\t\t\tif mob == null or int(mob.backpack) < 0:"),
        ],
    },
}


def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:12]


def uri(cesta: Path) -> str:
    return "res://" + cesta.relative_to(ROOT).as_posix()


def spust(extra: str | None) -> tuple[int, str, int, int]:
    args = ["--script", TESTS]
    if extra:
        args += ["--", extra]
    rc, vystup = godot_run(ROOT, args, timeout=900)
    match = SOUHRN.search(vystup)
    checks, failures = (int(match.group(1)), int(match.group(2))) if match else (0, 0)
    return rc, vystup, checks, failures


def fail_radky(vystup: str, prefix: str) -> list[str]:
    return [line.strip() for line in vystup.splitlines()
            if line.strip().startswith("[test] FAIL") and prefix in line]


def main() -> int:
    ap = argparse.ArgumentParser(description="Mutacni dukaz testu")
    ap.add_argument("--only", default=None,
                    help="sort, map, walk, doors, movement, registry, pathfind, textures, "
                         "item, container, interaction (nebo vic carkami)")
    args = ap.parse_args()
    if godot_bin() is None:
        print("CHYBA: Godot nenalezen (nastav $GODOT) - mutace by nic nemerily")
        return 2
    klice = list(MODULY) if not args.only else [k.strip() for k in args.only.split(",")]

    puvodni = {k: MODULY[k]["soubor"].read_text(encoding="utf-8") for k in MODULY}
    hash_pred = {k: sha(v) for k, v in puvodni.items()}

    # 0) baseline: bez mutace musi sada projit a NECO zmerit
    rc, vystup, checks, failures = spust(None)
    print(f"[mutace] baseline: {checks} kontrol, {failures} selhani, exit {rc}")
    if rc != 0 or failures != 0 or checks == 0:
        print("[mutace] CHYBA: baseline neprosel - mutace by nemerily nic")
        print(vystup[-2500:])
        return 2

    # 0b) smlouva o vstupu: neexistujici cesta MUSI shodit test daneho modulu
    smlouva_ok = True
    for klic in klice:
        modul = MODULY[klic]
        neexistuje = f"res://.cache/gates/mutace/neexistuje-{klic}.gd"
        rc, vystup, checks, failures = spust(f"{modul['prepinac']}={neexistuje}")
        chyceno = bool(fail_radky(vystup, modul["prefix"])) and rc != 0
        smlouva_ok = smlouva_ok and chyceno
        print(f"[mutace] smlouva vstupu {klic}: neexistujici cesta -> "
              f"{'test selhal (spravne)' if chyceno else 'TEST JI NEVIDI - CHYBA'}"
              f" | {checks} kontrol, exit {rc}")

    MUTANT_DIR.mkdir(parents=True, exist_ok=True)
    vysledek: list[tuple[str, str, bool, bool, bool, int, str]] = []
    for klic in klice:
        modul = MODULY[klic]
        zdroj = puvodni[klic]
        cesta = MUTANT_DIR / f"mutante-{klic}.gd"
        for nazev, stare, nove in modul["mutace"]:
            if stare not in zdroj:
                print(f"[mutace] {klic}: {nazev}: PATRANA VETA SE VE ZDROJI NENASLA - "
                      "mutace se neprovedla, nepocita se")
                vysledek.append((klic, nazev, False, False, False, 0, "neprovedena"))
                continue
            mutant = zdroj.replace(stare, nove, 1)
            cesta.write_text(mutant, encoding="utf-8")
            na_disku = cesta.read_text(encoding="utf-8")
            # PROVEDENA = na disku je PRESNE zamysleny text a neco se zmenilo.
            # Pozor: `stare not in mutant` tu BYT NESMI - nektere mutace obsahuji
            # puvodni text jako predponu (`.slice(0, 1)`) a jine meni jen PRVNI
            # z nekolika vyskytu (dve stejne kontroly v land_at/z_at). Obe by
            # jinak vysly jako "neprovedena", i kdyz se mutace provedla.
            provedena = mutant != zdroj and nove in mutant and na_disku == mutant
            if not provedena:
                print(f"[mutace] {klic}: {nazev}: ZMENA SE NA DISKU NEPROVEDLA")
                vysledek.append((klic, nazev, False, False, False, 0, "neoverena"))
                continue

            rc, vystup, checks, failures = spust(f"{modul['prepinac']}={uri(cesta)}")
            probehla = checks > 0
            chycena = rc != 0 and probehla and bool(fail_radky(vystup, modul["prefix"]))
            radky = fail_radky(vystup, modul["prefix"])
            if not probehla:
                poznamka = "SADA VUBEC NEPROBEHLA (0 kontrol)"
            elif radky:
                poznamka = radky[0][:110]
            else:
                poznamka = "sada selhala, ale bez FAIL tohoto modulu"
            vysledek.append((klic, nazev, provedena, probehla, chycena, checks, poznamka))
            print(f"[mutace] {klic}: {nazev}\n"
                  f"          PROVEDENA {'ano' if provedena else 'NE'} ({sha(mutant)}) | "
                  f"PROBEHLALA {'ano' if probehla else 'NE'} ({checks} kontrol, "
                  f"{failures} selhani, exit {rc}) | "
                  f"{'CHYCENA' if chycena else 'PROSLA - TEST JE SLEPY'}\n"
                  f"          {poznamka}")

    for soubor in MUTANT_DIR.glob("mutante-*.gd"):
        soubor.unlink()

    # strom se NESMI zmenit: mutuje se jen kopie, original zustava
    zmenene = [k for k in MODULY
               if sha(MODULY[k]["soubor"].read_text(encoding="utf-8")) != hash_pred[k]]
    if zmenene:
        print(f"[mutace] CHYBA: original se zmenil u {', '.join(zmenene)} - "
              "mutuje se jen kopie, toto je vada nastroje")
        return 2

    chycene = sum(1 for _, _, p, pr, c, _, _ in vysledek if p and pr and c)
    slepe = [f"{k}/{n}" for k, n, p, pr, c, _, _ in vysledek if not (p and pr and c)]
    print(f"\n[mutace] {chycene} z {len(vysledek)} mutaci chyceno"
          + (f"; NECHYCENE: {', '.join(slepe)}" if slepe else "")
          + f"; smlouva vstupu: {'OK' if smlouva_ok else 'CHYBA'}")
    return 0 if (not slepe and smlouva_ok) else 1


if __name__ == "__main__":
    sys.exit(main())
