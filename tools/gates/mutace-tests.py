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
             "clampi(priority_z(obj), Const.Z_MIN, Const.Z_MAX)",
             "priority_z(obj)"),
            # PRIORITY_Z (vada V6, `REVIZE-POHYB-2026-10-07.md` §2.6): poradova
            # vyska statiku. Kdyz se ignoruje, plocha mostu a jeho zabradli maji
            # stejny klic a rozhoduje poradi v souboru mapy.
            ("priority_z se ignoruje (radi se podle holeho z)",
             "clampi(priority_z(obj), Const.Z_MIN, Const.Z_MAX)",
             'clampi(int(obj.get("z", 0)), Const.Z_MIN, Const.Z_MAX)'),
            ("priority_z vraci vzdy nulu",
             'return int(obj.get("priority_z", obj.get("z", 0)))',
             "return 0"),
            ("diagonala x-y",
             'int(obj.get("x", 0)) + int(obj.get("y", 0))',
             'int(obj.get("x", 0)) - int(obj.get("y", 0))'),
            ("nestabilni razeni (poradi vstupu se do klice neda)",
             "klice[i] = (sort_key(obj) << shift) | i",
             "klice[i] = sort_key(obj) << shift"),
            ("spatny radix vrstev (LAYERS 3 -> 2)",
             "const LAYERS: int = 3", "const LAYERS: int = 2"),
            # ⚠ 18. session: dve veci, na kterych stoji vady ze snimku
            # ("zed pres strechu", "svah pres schody/most"). Obji museji byt
            # chycene, jinak se vada vrati a testy zustanou zelene.
            ("krok mrizky 300 -> 769 (z neprebije ani jednu diagonalou)",
             "const K_PER_DIAGONAL: int = 300", "const K_PER_DIAGONAL: int = 769"),
            ("land ztrati vlastni pruchod (svah muze pres schody)",
             "pruchod * PASS_SPAN + diagonal * K_PER_DIAGONAL",
             "diagonal * K_PER_DIAGONAL"),
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
            # ⚠ PREDELANO 2026-10-07 (14. session, V4/V5): pravidla vysky se
            # prepsala z `dz <= STEP_HEIGHT` na HORNI HRANY (`Movement.cs:170-171,
            # 319-321`), takze dve puvodni mutace odkazovaly na text, ktery uz
            # v souboru neni (`if dz > vyska_kroku:`, `F_WET != 0:`) - harness je
            # hlasil jako "PATRANA VETA SE NENASLA". Nahrazuji je mutace nize.
            ("krok nahoru jen o 1 (STEP_HEIGHT ignorovan)",
             "var vyska: int = Const.STEP_HEIGHT", "var vyska: int = 1"),
            ("voda neblokuje (mokry land je kandidat)",
             "if land >= 0 and _tiledata.flags(land) & (F_IMPASSABLE | F_WET) == 0:",
             "if land >= 0:"),
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
            # --- V4 (svah, 14. session): vyska z ROHU dlazdice, ne z jednoho `z`
            ("svah se meri z NEJVYSSIHO rohu (nejnizsi se ignoruje)",
             "if strop >= _low(c):", "if strop >= _top(c):"),
            ("stojna vyska svahu je z dlazdice, ne prumer rohu",
             "return _floor_avg(z_top, z_bottom)", "return z_top"),
            ("vzestup se pocita z MEHO z, ne z horni hrany (startTop)",
             "return maxi(_top(c), from.z)", "return from.z"),
            ("dolu se vraci limit (krok dolu je omezeny)",
             "var ber: bool = true",
             "var ber: bool = from_z - _center(c) <= Const.STEP_HEIGHT"),
            # --- V4 bod 3 + V5 (most, 14. session)
            ("Bridge nepuli vysku (CalcHeight se ignoruje)",
             "if _flags(tile) & F_BRIDGE != 0:\n\t\treturn _height(tile) / 2",
             "if false:\n\t\treturn _height(tile) / 2"),
            ("strop statiku se bere i u mostu (itemTop += vyska)",
             "if flags & F_BRIDGE == 0:\n\t\t\titem_top += _height(tile)",
             "if true:\n\t\t\titem_top += _height(tile)"),
            ("statik se `Surface` se vubec nezkusi (most nad vodou neni)",
             "if flags & F_SURFACE == 0 or flags & F_IMPASSABLE != 0 or flags & F_WET != 0:\n\t\t\tcontinue",
             "if true:\n\t\t\tcontinue"),
            ("pruchozi povrch se pri IsOk ignoruje (land pod schodem projde)",
             "if flags & F_SURFACE != 0 and flags & F_IMPASSABLE == 0:", "if false:"),
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
             '"due_ms": start + delay,', '"due_ms": start,'),
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
             "if use_run and mob.stam <= 1:", "if false:"),
            # --- V2/V4 (14. session): krok musi klientovi rict, KDY zacal, a
            # stojna vyska se musi zapsat do `pos.z` (vada V4 - jinak se na
            # svahu kazdy dalsi krok meri proti stare vysce).
            ("pending_step vraci prazdny slovnik (klient nevidi krok)",
             "return (_pending[serial] as Dictionary).duplicate()", "return {}"),
            ("krok si nepamatuje cas zacatku (klient nema z ceho pocitat)",
             '"start_ms": start,', '"start_ms": 0,'),
            ("stojna vyska se do pos.z nezapise (vada V4)",
             'z = int(_pending[m]["z"])       # stojna vyska z `can_step` (vada V4)',
             "z = int(mob.pos.z)"),
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
    "skill_gain": {
        "soubor": ROOT / "sim" / "systems" / "skill_gain.gd",
        "prefix": "sim.skill_gain",
        "prepinac": "--skill-gain-script",
        "mutace": [
            ("rust je podmíněný úspěchem (klíčové pravidlo 2026-10-07)",
             "\tvar gained: bool = _gain(mob, skill, value, chance, success)",
             "\tif not success:\n\t\treturn _result(false, false, value, \"\")\n"
             "\tvar gained: bool = _gain(mob, skill, value, chance, success)"),
            ("zámky skillu se ignorují",
             "if mob.skills.lock(skill) != LOCK_UP:",
             "if false and mob.skills.lock(skill) != LOCK_UP:"),
            ("strop jednotlivého skillu se ignoruje",
             "if value >= mob.skills.cap(skill):",
             "if false and value >= mob.skills.cap(skill):"),
            ("GGS v sekundách místo minut (mez mimo rozsah)",
             "return int(GGS_TABLE[row][column]) * MS_PER_MINUTE",
             "return int(GGS_TABLE[row][column]) * 1000"),
        ],
    },
    # POZOR na vyber mutaci u UI: meni se TELA metod, ne signatury. Kdyby
    # mutant zmenil pocet argumentu, `has_method` ho pusti, volani spadne na
    # "Invalid call" a case zmeri 0 kontrol - v CELOSADOVEM souctu to vypada
    # jako "PROSLA" (namEReno 11. session: `only_case.gd` u ciziho souboru
    # hlasi `0 kontrol, 0 selhani`, exit 0). Ochrana v case souborech je
    # pritomnost celeho API pred volanim, ne signatury.
    "hud": {
        "soubor": ROOT / "ui" / "hud.gd",
        "prefix": "ui.hud",
        "prepinac": "--hud-script",
        "mutace": [
            ("set_position pozici nezapamatuje",
             "\tif not _positions.has(id):\n\t\treturn false\n\t_positions[id] = pos",
             "\tif not _positions.has(id):\n\t\treturn false"),
            ("layout() vraci ZIVY slovnik misto kopie",
             "return _positions.duplicate()", "return _positions"),
            ("position_of vraci (0,0) pro neznama okna",
             "return _positions.get(id)", "return Vector2.ZERO"),
        ],
    },
    "status_bar": {
        "soubor": ROOT / "ui" / "status_bar.gd",
        "prefix": "ui.status_bar",
        "prepinac": "--status-bar-script",
        "mutace": [
            ("vaha se vypise bez maxima",
             'parts.append("weight=%d/%d" % [_num(values, "weight"), _num(values, "weight_max")])',
             'parts.append("weight=%d" % _num(values, "weight"))'),
            ("apply_event prijme i cizi udalost",
             '!= "stats_changed"', '!= "stats"'),
            ("update() nenastavi text Labelu",
             "_ensure_label().text = text_for(_values)", "_ensure_label()"),
            ("zahodi se alias max_hp z udalosti",
             "return _num(values, key) if values.has(key) else _num(values, alias)",
             "return _num(values, key)"),
        ],
    },
    "chunk_renderer": {
        "soubor": ROOT / "render" / "chunk_renderer.gd",
        "prefix": "render.chunk",
        "prepinac": "--chunk-script",
        "mutace": [
            ("art_id bez posunu 0x4000 (dva id prostory)",
             "const ITEM_OFFSET: int = 0x4000", "const ITEM_OFFSET: int = 0"),
            # SVAHY (2026-10-07): bez `texmap` a `z_corners` se svah kresli jako
            # rovna plocha - presne vada, kterou uzivatel videl jako diru.
            ("texmap se do seznamu nedava",
             '"texmap": _tiledata.texture(land) if _tiledata != null else 0,',
             '"texmap": 0,'),
            ("z_corners berou vlastni vysku misto sousedu",
             '"z_corners": [z, zrohy[radek + 1], zrohy[radek + sirka],\n'
             "\t\t\t\t\tzrohy[radek + sirka + 1]]}",
             '"z_corners": [z, z, z, z]}'),
            # PRIORITY_Z (vada V6, `REVIZE-POHYB-2026-10-07.md` §2.6): plocha
            # mostu (podlaha) musi jit PRED jeho zabradlim. Kdyz se podlaha
            # neodečte nebo vyska nepricte, na molu u Britannie vyjde poradi
            # opacne (namEReno: 30 dlazdic).
            ("podlaha nedostane -1 (zabradli zustane pod dlazdici)",
             "if _tiledata.flags(art_id) & F_BACKGROUND != 0:\n\t\tv -= 1",
             "if false:\n\t\tv -= 1"),
            ("statik s vyskou nedostane +1",
             "if _tiledata.height(art_id) != 0:\n\t\tv += 1",
             "if false:\n\t\tv += 1"),
            ("priority_z se do seznamu vubec nedava",
             '"priority_z": _priorita(art_id, z_statiku),',
             '"priority_z": z_statiku,'),
            ("podlaha se pozna podle spatneho flagu",
             "const F_BACKGROUND: int = 0x00000001",
             "const F_BACKGROUND: int = 0x00000004"),
        ],
    },
    # CHUZE DRZENIM (12. session, rozhodnuti uzivatele 2026-10-07). Testy meri
    # presny interval (`now_ms` je vstup), takze se kazda z techto vad pozna.
    "input": {
        "soubor": ROOT / "app" / "input_map.gd",
        "prefix": "app.input",
        "prepinac": "--input-script",
        "mutace": [
            ("drzeni se neopakuje (pta se jen na just_pressed)",
             "if not Input.is_action_pressed(input_action):",
             "if not Input.is_action_just_pressed(input_action):"),
            ("krok se vyda pri kazdem pollu (prodleva se ignoruje)",
             "if now_ms - minule < prodleva:",
             "if false:"),
            ("pusteni nevynuluje prodlevu (prvni krok po pusteni se ztrati)",
             "\t\t\t_krok_ms.erase(action)\n",
             ""),
            ("drzene prave tlacitko ignoruje vzdalenost kurzoru",
             "return (mouse_position - view_size / 2.0).length() >= MOUSE_RUN_PX",
             "return always_run"),
            ("hranice behu je ostre vetsi (na 190 px se jde krokem)",
             ".length() >= MOUSE_RUN_PX",
             ".length() > MOUSE_RUN_PX"),
            ("jednorazove akce se drzenim opakuji (war kazdy poll)",
             'if str(command.get("t", "")) != "move":\n\t\treturn {}',
             "if false:\n\t\treturn {}"),
            # SMER Z MYSI JE OBRAZKOVY (vada V3, `REVIZE-POHYB-2026-10-07.md` §2.3)
            ("rovina vodorovna se nikdy nevybere (vse je uhlopricka)",
             "if ay * float(MOUSE_RATIO_DEN) <= ax * float(MOUSE_RATIO_NUM):",
             "if false:"),
            ("rovina svisla se nikdy nevybere (vse je uhlopricka)",
             "if ay * float(MOUSE_RATIO_NUM) >= ax * float(MOUSE_RATIO_DEN):",
             "if false:"),
            ("stred pro smer je stred okna, ne hrac na obrazovce",
             "player_screen_position(player, camera_offset, z), mouse_position)",
             "view_size / 2.0, mouse_position)"),
            ("kurzor na hraci se posle jako krok (a spali prodlevu)",
             "if smer < 0:\n\t\t\t\tcontinue\n",
             ""),
        ],
    },
    # PORADI V TICKU (vada V1, `REVIZE-POHYB-2026-10-07.md` §2.1). Modul je tu
    # proto, ze se mutuje JINY soubor nez `sim.movement` - a kadence kroku
    # vzniká prave timto poradim. Test je v `tests/cases/movement.gd` (sekce 12)
    # a cestu k SimWorld bere z `--sim-script`.
    "world_loop": {
        "soubor": ROOT / "sim" / "sim_world.gd",
        "prefix": "sim.world_loop",
        "prepinac": "--sim-script",
        "mutace": [
            ("prikazy se dispatchuji PRED systemy (krok v tomto ticku vraci 'busy')",
             "\tfor name in SYSTEM_ORDER:\n\t\tif systems.has(name):\n\t\t\t_tick_system(systems[name], ms)\n\tfor command in batch:\n\t\t_commands.dispatch(self, command)",
             "\tfor command in batch:\n\t\t_commands.dispatch(self, command)\n\tfor name in SYSTEM_ORDER:\n\t\tif systems.has(name):\n\t\t\t_tick_system(systems[name], ms)"),
        ],
    },
    "player_controller": {
        "soubor": ROOT / "app" / "player_controller.gd",
        "prefix": "player_controller",
        "prepinac": "--controller-script",
        "mutace": [
            ("vazba na drzene prave tlacitko chybi (mys nechodi)",
             '"walk_to": "walk_to_cursor",', ""),
            ("prepinac chuze/beh chybi (beh se neda vypnout)",
             '"run_toggle": "run_toggle",', ""),
            ("prave tlacitko se zaregistruje jako klavesa",
             "var klik := InputEventMouseButton.new()\n\t\tklik.button_index = MOUSE[action]",
             "var klik := InputEventKey.new()\n\t\tklik.keycode = KEY_F1"),
            # --- V2 (14. session): posun a animace v jedne fazi
            ("krok v letu necha akci idle (animace startuje az po skoku)",
             '_action = ACTION_RUN if bool(_step["run"]) else ACTION_WALK',
             "_action = ACTION_IDLE"),
            # ⚠ 18. session: posun se uz NEKVANTUJE po 80 ms (byla to vada
            # "trhavost, ktera je plynula"). Mutace vadi 80ms kvantizaci ZPET.
            ("posun se kvantuje po 80ms framech (trhavy pohyb)",
             "return clampf(float(maxi(elapsed_ms, 0)) / float(delay_ms), 0.0, 1.0)",
             "return clampf(float((maxi(elapsed_ms, 0) / ANIM_FRAME_MS) * ANIM_FRAME_MS) / float(delay_ms), 0.0, 1.0)"),
            ("posun postavy mezi dlazdicemi se nekresli (offset vzdy nula)",
             "return Vector2(roundf(posun.x), roundf(posun.y))", "return Vector2.ZERO"),
            ("posun se nezaokrouhli na cely pixel (subpixelovy sum)",
             "return Vector2(roundf(posun.x), roundf(posun.y))", "return posun"),
            ("controller bezi pred smyckou (cte stav pred tickem)",
             "\tprocess_priority = 1", "\tprocess_priority = 0"),
        ],
    },
    "world_view": {
        "soubor": ROOT / "app" / "world_view.gd",
        "prefix": "app.world_view",
        "prepinac": "--world-view-script",
        "mutace": [
            ("kamera ignoruje vysku (z = 0)",
             "to_screen(tile.x, tile.y, z)", "to_screen(tile.x, tile.y, 0)"),
            # SVAH (2026-10-07): bez rozhodnuti o svahu se svah kresli jako rovna
            # plocha (dira v terenu), a s prohozenymi rohy se nakloni na spatnou stranu.
            ("svah se nikdy nevyhodnoti jako svah (dira)",
             "func is_slope(obj: Dictionary) -> bool:",
             "func is_slope(obj: Dictionary) -> bool:\n\treturn false"),
            # ⚠ "rohy svahu prohozene" tady BYLA do M9 - geometrie svahu se
            # 15. session presunula do `render/chunk_mesh.gd` (potrebuje ji i
            # dávka), takze mutace je odtud PRYC a je v modulu `chunk_mesh`
            # (`slope_polygon`). Nechat ji tady by znamenalo "neprovedenou
            # mutaci", ktera se tvari jako hotova kontrola.
            # ODDALENA PRESTAVBA (2026-10-07): s prestavbou pri kazdem kroku
            # prichazi 44 ms seknuti 2,5x za sekundu.
            ("seznam se prestavuje pri kazdem kroku",
             "or absi(center_tile.y - _list_center.y) >= RECENTER_TILES:",
             "or absi(center_tile.y - _list_center.y) >= 1:"),
            # V2 (14. session): posun kroku se do kresleni postavy musi pricist.
            ("posun kroku se do kresleni postavy neprida (V2)",
             "+ Vector2(Const.ISO_STEP, Const.TILE_H / 2) + _player_offset",
             "+ Vector2(Const.ISO_STEP, Const.TILE_H / 2)"),
            # M9 (15. session): davka se NESMI preskocit - jinak zustane
            # `mesh_stats()` prazdny a `tests/cases/world_view.gd` (sekce 12)
            # to vidi. (Kresleni `_draw()` se v headless testu volat neda -
            # Godot dovoli `draw_*` jen v NOTIFICATION_DRAW - takze se meri
            # PRIPRAVA dávky.)
            ("davka se nikdy nezahaji (mesh zustane prazdny)",
             "_mesh.zacni(seznam)", "pass"),
            # ⚠ 18. session: ROZPOČET STAVBY NA FRAME. Kdyby byl obri, udelala by
            # se cela stavba (~150 ms) v jednom framu - presne vada, kterou R6
            # opravuje. Chyti to test "davka se stavi PO CASTECH" (pocita framy,
            # ve kterych stavba OPRAVDU bezela).
            ("stavba dostane obri rozpocet na frame (jeden dlouhy frame)",
             "const _STAVBA_MS: float = 8.0", "const _STAVBA_MS: float = 1000000.0"),
            # ⚠ 18. session: kamera se posouva o cerny pas pro GUI - bez toho by
            # hrac stal pod pasem (mimo viditelny svet). Meri se klicem hrace
            # v `tests/cases/world_view.gd` (sekce 5c).
            ("kamera ignoruje cerny pas pro GUI (hrac pod pasem)",
             "+ offset + gui_odsazeni", "+ offset"),
        ],
    },
    # M9 (15. session): davkove kresleni. Mutace miri na GEOMETRII, PORADI
    # a KOPII SPRITU - na tech stoji "stejny obraz" (podminka milniku M9).
    "chunk_mesh": {
        "soubor": ROOT / "render" / "chunk_mesh.gd",
        "prefix": "render.chunk_mesh",
        "prepinac": "--chunk-mesh-script",
        "mutace": [
            ("land s art_id <= 2 se kresli (nodraw se ignoruje)",
             "if kind == \"land\" and art_id <= VOID_LAND_MAX:",
             "if kind == \"land\" and art_id <= 0:"),
            ("svah se kresli jako rovna plocha (dira v terenu)",
             "if kind == \"land\" and je_svah(obj, _textures):",
             "if false:"),
            ("rohy svahu prohozene (pravy za levy)",
             "krok + float(z - int(obj[\"z_corners\"][1])) * zs",
             "krok + float(z - int(obj[\"z_corners\"][2])) * zs"),
            ("dira dostane bilou barvu misto magenta (zmizi)",
             "barva = HOLE_COLOR", "barva = Color.WHITE"),
            ("druhy trojuhelnik kvadru je spatne (geometrie se rozsype)",
             "_verts[b + 3] = body2", "_verts[b + 3] = body0"),
            ("UV se pocitaji bez posunu ve spritu (rozsypany atlas)",
             "var ux: float = float(slot.position.x) / stranka_f",
             "var ux: float = 0.0"),
            ("sprite se do runtime atlasu nekresli (jen UV)",
             "\"pos\": Vector2(r.position), \"tex\": tex,",
             "\"pos\": Vector2(r.position), \"tex\": null,"),
            ("po zmene stranky se dávka pouzije hned (prazdna textura)",
             "_hold = HOLD_FRAMU", "_hold = 0"),
            ("split radi podle spatne hranice (hrac je jinde)",
             "if _klic[stred] <= klic_hrace:", "if _klic[stred] < klic_hrace:"),
            ("pretek stranky se nehlasi (ticha degradace)",
             "if _y + vyska > _velikost:", "if _y + vyska > _velikost * 1000:"),
            ("do klice kvadru se zapise nula (split prestane fungovat)",
             "_klic[_q] = _sort.sort_key(obj)", "_klic[_q] = 0"),
            # ⚠ 18. session: "stavba se nedeli do framu" tu BYLA, ale gate ji
            # oznacil za NECHYCENOU - a měl pravdu: i kdyz se cas v geometrii
            # nekontroluje, `krok` se presto zastavi na konci faze 1 (sloty),
            # takze se stavba porad deli. Skutecne riziko je v ROZPOCTU
            # (`_STAVBA_MS` ve `world_view`) - a to hlida mutace tam.
            # Mrtvou mutaci NENECHÁVÁME: brána, která nemá jak selhat, je horší
            # nez zadna (LESSONS 2026-10-08).
            # ⚠ 18. session: vynechany objekt kvuli NACTENI STRANKY neni dira -
            # kdyby se to pletlo, kazda pomalejsi stranka by blikla magenta.
            ("ceka stranka se kresli jako dira (magenta)",
             "if tex == null and _textures.page_pending(art_id):",
             "if false:"),
            # ⚠ 18. session: barva svahu (reference stinuje jen stretched land).
            ("svah se kresli bez ztmaveni (jina svetlost nez rovina)",
             "barva = SVAH_BARVA       # viz `SVAH_JAS` v hlavicce",
             "barva = Color.WHITE"),
        ],
    },
    # M9 (15. session): typovana konfigurace. Mutace miri na to, co ma byt
    # VIDET: neznamy klic, spatny typ, rozsah, normalizace cisel z JSONu.
    "config": {
        "soubor": ROOT / "app" / "config.gd",
        "prefix": "app.config",
        "prepinac": "--config-script",
        "mutace": [
            ("neznamy klic v datech se nehlasi (preklep projde)",
             "if not SCHEMA.has(klic) and not _je_dokumentacni(str(klic)):",
             "if false:"),
            ("spatny typ se nehlasi",
             "if typeof(hodnota) != typ:", "if false:"),
            ("hodnota mimo rozsah se nehlasi",
             "if int(hodnota) < mini_ or int(hodnota) > maxi_:", "if false:"),
            ("neznamy klic vrati null misto predaneho defaultu",
             "return default", "return null"),
            ("cela cisla z JSONu zustanou float (kazdy int klic hlasi typ)",
             "return int(roundf(float(hodnota)))", "return hodnota"),
            ("known_keys() se neradi",
             "\tvar out: Array = SCHEMA.keys()\n\tout.sort()",
             "\tvar out: Array = SCHEMA.keys()"),
            ("dokumentacni klice se hlasí jako preklepy",
             "for cast in casti:", "for cast in []:"),
        ],
    },
    # M9 (15. session): mereni vykonu. Mutace miri na to, aby cisla nebyla
    # "nula a prazdno" a aby se meritelne menila oknem.
    "metrics": {
        "soubor": ROOT / "app" / "metrics.gd",
        "prefix": "app.metrics",
        "prepinac": "--metrics-script",
        "mutace": [
            ("prazdny modul hlasi 1 ms misto NEMERENO",
             "if _casy.is_empty():\n\t\treturn 0.0", "if _casy.is_empty():\n\t\treturn 1.0"),
            ("fps vraci frame_ms (neprepocitane)",
             "return 0.0 if ms <= 0.0 else 1000.0 / ms", "return ms"),
            ("okno se v ticku neuplatnuje (pocita se i stare)",
             "while _casy.size() > _okno:\n\t\t_casy.remove_at(0)\n\t_drawn = drawn",
             "_drawn = drawn"),
            ("drawn_objects vraci neco jineho nez posledni tick",
             "_drawn = drawn", "_drawn = drawn + 1"),
            ("report() hlasi nula vzorku i po mereni",
             '"vzorku": _casy.size(),', '"vzorku": 0,'),
            ("reset() nevymaze vzorky",
             "\n\t_casy = PackedFloat32Array()", "\n\t_casy = _casy"),
        ],
    },
    # DATA se mutuji po bajtech: mutant je kopie JSON s priponou `.gd`
    # v `.cache` (ta ma `.gdignore`, takze ho Godot neimportuje) a case ho
    # cte pres `--recipes-path=`, protoze cteni na pripone nezalezi.
    "recipes": {
        "soubor": ROOT / "data" / "recipes.json",
        "prefix": "data.recipes",
        "prepinac": "--recipes-path",
        "mutace": [
            ("vysledek ztrati kind = result",
             '"kind": "result"', '"kind": "output"'),
            ("odkaz na neexistujici tile",
             '"tile": 3621', '"tile": 999999'),
        ],
    },
    # 16. session: sber surovina (docs/05 §5.7). Mutace miri na to, co ma byt
    # VIDET: dlaždice, art, vydej, fallback na zelezo, casek a respawn banky.
    "harvest": {
        "soubor": ROOT / "sim" / "systems" / "harvest.gd",
        "prefix": "sim.harvest",
        "prepinac": "--harvest-script",
        "mutace": [
            ("hora se nepozna (kope se na jakoukoli land dlazdici)",
             "if land >= 0 and _in_ranges(land, MINE_LAND):", "if land >= 0:"),
            ("ruda je jiny art (0x59B7 misto 0x59B8)",
             "const ORE_ART := 0x59B8", "const ORE_ART := 0x59B7"),
            ("log je art bez flagu Generic (hromady se neslouci)",
             "const LOG_ART := 0x5BDD", "const LOG_ART := 0x5BDE"),
            ("z dreva se vyda 1 log misto 10",
             '"respawn_min": 20, "respawn_max": 30, "yield": 10', '"respawn_min": 20, "respawn_max": 30, "yield": 1'),
            ("skill pod ReqSkill dostane barevnou rudu",
             'if value < int(r["req"]) or value < int(r["min"]):', "if false:"),
            ("casek se nikdy nenastavi (dva sběry v jednom okamziku)",
             '_busy_until[kind] = now + int(p["swing_ms"])', "_busy_until[kind] = 0"),
            ("neuspesny sber tvrdi, ze skill nerostl",
             '"gained": zisk, "success": false, "tile": tile', '"gained": false, "success": false, "tile": tile'),
            ("rybolov netrva 8 s",
             '"yield": 1, "swing_ms": 8000, "range": 4', '"yield": 1, "swing_ms": 0, "range": 4'),
            ("respawn banku nevrati (zustane prazdna)",
             'bank["current"] = int(bank["max"])', 'bank["current"] = 0'),
        ],
    },
    # 16. session: vyroba (docs/05 §5.8). Mutace miri na sance, materialy,
    # stanici, znacku vyrobce a na to, ze vysledek je v ART prostoru.
    "craft": {
        "soubor": ROOT / "sim" / "systems" / "craft.gd",
        "prefix": "sim.craft",
        "prepinac": "--craft-script",
        "mutace": [
            ("sance se neinterpoluje (zustane jen floor)",
             "return floor_chance + (float(value - min_d) / float(max_d - min_d)) * (1.0 - floor_chance)",
             "return floor_chance"),
            ("na maximalnim skillu neni 100 %",
             "if value >= max_d:\n\t\treturn 1.0", "if value >= max_d:\n\t\treturn 0.5"),
            ("neuspech spali jen polovinu materialu",
             "if not uspech and use_all:", "if not uspech:"),
            ("dostupnost materialu se nekontroluje (vyroba z niceho)",
             "if not _has_materials(mob, materialy, davka):", "if false:"),
            ("kovadlina se nekontroluje",
             "if not _station_near(mob, str(role)):", "if false:"),
            ("kovadlina/vyhen jako PREDMET se neuzna",
             "if item != null and _role_of_tile(int(item.tile)) == role",
             "if false and _role_of_tile(int(item.tile)) == role"),
            ("znacka vyrobce i pod 100,0 skillu",
             "if exceptionalni and hodnota >= 1000:", "if exceptionalni:"),
            ("vysledek zustane v TILEDATA prostoru (bez +0x4000)",
             "var item = _add(mob, result_tile + ITEM_OFFSET, amount, 0)",
             "var item = _add(mob, result_tile, amount, 0)"),
            ("taveni rudy neda 1:1",
             "var ingotu: int = mnozstvi", "var ingotu: int = mnozstvi / 2"),
            ("exceptionalita se nikdy nevyhodnoti",
             "var exceptionalni: bool = _rng.chance(_exceptional_chance(system, hodnota, sance))",
             "var exceptionalni: bool = false"),
        ],
    },
    # 16. session: zurnal (docs/04 §4.2). Mutace miri na davkove prebaveni
    # textu (to je meritelne "nezpomali frame"), strop fronty a barvy.
    "journal": {
        "soubor": ROOT / "ui" / "journal.gd",
        "prefix": "ui.journal",
        "prepinac": "--journal-script",
        "mutace": [
            ("text se prebavi po KAZDE zprave (ne jednou za davku)",
             "\t_dirty = true\n\treturn true", "\tflush()\n\treturn true"),
            ("fronta se neomezuje (roste bez limitu)",
             "while _lines.size() > MAX_LINES:", "while false:"),
            ("zahozene zpravy se nepocitaji",
             "_dropped += 1", "pass"),
            ("bere i cizi udalosti",
             'if str(event.get("name", "")) != "message" or not (event.get("data") is Dictionary):\n\t\treturn false',
             'if str(event.get("name", "")) != "message" or not (event.get("data") is Dictionary):\n\t\treturn true'),
            ("vsechny typy maji stejnou barvu",
             "KIND_COMBAT: Color(0.90, 0.30, 0.25),", "KIND_COMBAT: Color(1.0, 0.85, 0.40),"),
            ("neznamy typ zustane bez barvy",
             "return COLORS.get(kind, COLORS[KIND_SYSTEM])", "return COLORS.get(kind, Color(0, 0, 0))"),
            ("BBCode se neescapuje",
             'text.replace("[", "[lb]")', "text"),
            ("zurnal nema velikost (text se nevykresli)",
             "label.custom_minimum_size = velikost\n\t\tlabel.size = velikost",
             "label.custom_minimum_size = Vector2.ZERO\n\t\tlabel.size = Vector2.ZERO"),
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
                         "item, container, interaction, skill_gain, hud, status_bar, "
                         "chunk_renderer, world_view, input, player_controller, chunk_mesh, "
                         "config, metrics, harvest, craft, journal (nebo vic carkami)")
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
