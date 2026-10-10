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
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gate_common import godot_bin, godot_run  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TESTS = "res://tests/run_tests.gd"
# ⚠ SOUBEZNY BEH (namEReno 2026-10-10, teammate `zaklady`): dva behy harnessu
# si mutanty v tomhle adresari navzajem premazavaji a vzniknou FALESNE "slepe"
# vysledky (mutant se v pulce cteni zmeni). Kdo potrebuje merit soubezne,
# nastavi `MUTACE_DIR` na vlastni adresar:
#   $env:MUTACE_DIR='E:\Workspaces\game-clone\.cache\mutace-moje'
MUTANT_DIR = Path(os.environ.get("MUTACE_DIR") or (ROOT / ".cache" / "gates" / "mutace"))
SOUHRN = re.compile(r"(\d+)\s+kontrol,\s*(\d+)\s+selh")

# klic -> soubor, ktery se mutuje, prefix FAIL radku a prepinac testu
MODULY = {
    # ⚠ POZOR PRI SLOUČOVÁNÍ DVOU SESSION (namEReno 2026-10-08): tenhle soubor
    # edituje VÍC session najednou a je snadné si vzory navzájem smazat.
    # Pravidla:
    #   * před zápisem soubor ZNOVU PŘEČTI (ne jen `git diff`) a hledej, jestli
    #     tam už není vzor od někoho jiného,
    #   * vzory se PŘIDÁVAJÍ na konec seznamu `mutace` daného modulu, nikdy se
    #     nepřepisuje celý seznam,
    #   * nový vzor musí být OVĚŘENÝ, že s ním testy spadnou (bez toho je to
    #     jen text v souboru).
    # A druhá věc: **brány se NESMÍ pouštět souběžně se zápisem do `sim/` nebo
    # `app/`.** Nástroj to pozná (kontrola na konci běhu, řádek ~1058) a skončí
    # hláškou "original se zmenil u …" - to je SPRÁVNĚ fungující self-check,
    # ne vada nástroje. Výsledek takového běhu je nepoužitelný a musí se zopakovat.
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
            # ⚠ 19. session: `klic_nad_diagonalou` je ZALOHA klice hrace pro
            # pripad, ze volajici nema seznam objektu. ZKOUSENO a ODSTRANENO:
            # mutace "vraci nulu" vychazela jako **SLEPA** (namEReno pri behu
            # mutaci 2026-10-08) - zadny test ji neodhali, protoze klic hrace se
            # v realnem kode pocita z REALNYCH objektu a fallback nastane jen pri
            # prazdnem seznamu, kde se neda overit nic jineho nez "je to kladne".
            # Mrtva metrika se NEMÁ nechat lezet (budi dojem pokryti); az bude
            # mit fallback vlastni test s presnym cislem, vzor se vrati.
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
            # ⚠ 19. session - POZOR NA KONTEKST TOHOHLE VZORU (namEReno): stejny
            # text je v souboru DVAKRAT (`_start_top` a `_vyber_povrch`), takze
            # `replace(..., 1)` mutoval jen ten PRVNI - a test na "do vody se
            # nesmi" pak mutaci NEODHALIL (kandidat na povrch dal vodu porad
            # blokoval). Vzor proto obsahuje nasledujici radek z `_vyber_povrch`,
            # aby byl jednoznacny. Kdo trosku zmeni okolni kod, uvidí to jako
            # "PATRANA VETA SE NENASLA" - a to je spravne, ne tise.
            ("voda neblokuje (mokry land je kandidat)",
             "if land >= 0 and _tiledata.flags(land) & (F_IMPASSABLE | F_WET) == 0:\n"
             "\t\tvar c: Array = _corners(to.x, to.y)\n\t\tif strop >= _low(c):",
             "if land >= 0:\n"
             "\t\tvar c: Array = _corners(to.x, to.y)\n\t\tif strop >= _low(c):"),
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
            # ⚠ 19. session - VZOR BYL MRTVY (namEReno pri behu mutaci): cílil
            # `return maxi(_top(c), from.z)`, ktery po oprave V11 v souboru uz
            # NENI (`_start_top` dnes sklada `z_top` z landu I ze statiku pod
            # nohama). Nahrazeny vzorem, ktery meri TOTEZ na novem kode: kdyz se
            # horni hrana pocita jen z landu (a statiky pod nohama se ignoruji),
            # krok na molo je blokovany ("height") - presne vada V11.
            ("vzestup se pocita jen z landu (statik pod nohama se ignoruje)",
             "\t\tif from.z >= _center(c):\n\t\t\tz_center = _center(c)\n\t\t\tz_top = _top(c)\n\t\t\tis_set = true",
             "\t\tif from.z >= _center(c):\n\t\t\tz_center = _center(c)\n\t\t\tz_top = from.z\n\t\t\tis_set = true"),
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
            # --- V11 (19. session): "Hra mi neumozni jit na most." NAMERENO:
            # `_start_top` ignoroval statiky POD NOHAMI (prkno mostu), takze strop
            # kroku vysel o 2 niz a krok na molo byl blokovany ("height").
            ("statiky pod nohama se do startTop nepocitaji (na most se nevejde)",
             "for s in _statiky(from.x, from.y):", "for s in []:"),
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
            # ⚠ 2026-10-09 (granule `sim.offline`): registr je stavovy zdroj.
            # Vzory meri case `entity_state` (`--registry-script`).
            ("state() vraci mobily v poradi vlozeni (ne podle serialu)",
             "\tfor m in all():", "\tfor m in _mobily.values():"),
            ("restore() nevyprázdní stary stav",
             "\t_mobily.clear()\n", ""),
            ("restore() mobily vubec neprevezme",
             "\t\tif int(m.serial) > 0:\n\t\t\t_mobily[int(m.serial)] = m", "\t\tpass"),
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
            # ⚠ 20. session: `same_pile` uz neporovnava `tile`, ale `type`
            # (identita z `data/items.json`); vzor proto miri na novy text.
            # Kdyby zustal stary, mutace by se TISE neprovedla (a to je slepe
            # misto, ne zelena) - presne to harness sam pozna a hlasi.
            ("same_pile ignoruje hue (sloucil by ruzne barvy)",
             "hue == other.hue and amount > 0", "amount > 0"),
            ("same_pile porovnava ART misto TYPU (hromady tehoz predmetu s jinou grafikou se nesliji)",
             'var muj: String = type if type != "" else str(tile)',
             'var muj: String = str(tile)'),
            ("same_pile vraci true i pro prazdnou hromadu",
             "and other.amount > 0", "and true"),
            # ⚠ 20. session: ID PROSTORY (art id vs tiledata id) prebiral
            # `sim.interaction._record`; ten je pryc a prevadi je `Item.type_of`.
            # Vzor se sem presunul s nim - jinak by platilo, ze se "id prostor
            # neprevadi", a nikdo by to nemeril.
            ("id prostor se neprevadi (tiledata id se nenajde)",
             "\tif tile_hodnota < ITEM_OFFSET and _typ_podle_artu.has(tile_hodnota + ITEM_OFFSET):",
             "\tif false:"),
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
            # --- V15a (19. session): OTOCENI NA MISTE. `turn` je jedina cesta,
            # jak zmenit smer bez kroku - kdyz se `mob.dir` nezapise, klient
            # vykresli stary smer (vada "postava se neumi otacet").
            ("turn nezapise smer (otoceni se neprovede)",
             "\tmob.dir = dir\n\t_events_push(\"mobile_turned\"",
             "\t_events_push(\"mobile_turned\""),
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
            # Id prostory (art vs tiledata id) se od 20. session prevadeji
            # v `sim/entity/item.gd` (`type_of`) - vzor se tam presunul, tady
            # by uz nemel co mutovat (a harness to hlasi jako mrtvy vzor).
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
            # --- 19. session, zadani 19 (V12/V16/V17) -----------------------------------
            # Patra: filtr patra je SJEDNOCENI dvou pravidel - `z >= strop_patra`
            # (reference `UpdateMaxDrawZ`, GameSceneDrawingSorting.cs:57-213) NEBO
            # stara podminka "jsem pod strechou a je to strop". Vsechny ctyri
            # mutace jsou overene, ze testy spadnou (zaznam v `_analyza/p22-patra-mutace.txt`).
            ("strop patra propusti objekt na sve urovni (patro zustane videt)",
             "if z_statiku >= _max_z:", "if z_statiku > _max_z:"),
            ("krytí se pozna jen z kandidata (strecha bez Surface nad hracem zustane)",
             "bool(s[\"kandidat\"]) or pod_strechou(px, py, pz)",
             "bool(s[\"kandidat\"])"),
            ("zadny kandidat = strop 0 (skryje se vsechno)",
             "const STROP_NIC: int = 127", "const STROP_NIC: int = 0"),
            ("Surface+Background uz neni strop (schod na mem patre zmizi)",
             "((f & F_SURFACE) != 0 and (f & F_BACKGROUND) != 0)",
             "((f & F_SURFACE) != 0 and true)"),
        ],
    },
    # CHUZE DRZENIM (12. session, rozhodnuti uzivatele 2026-10-07). Testy meri
    # presny interval (`now_ms` je vstup), takze se kazda z techto vad pozna.
    "input": {
        "soubor": ROOT / "app" / "input_map.gd",
        "prefix": "app.input",
        "prepinac": "--input-script",
        "mutace": [
            # ⚠ 19. session - DVA VZORY BYLY MRTVE (namEReno pri behu mutaci):
            # kod se pri V14 prepsal, takze puvodni texty (`if not
            # Input.is_action_pressed(...)` a `player_screen_position(...)` ve
            # volani `direction_from_screen`) v souboru uz nejsou. Nahrazuji je
            # vzory na TOTEZ v novem kode, aby pokryti nezmizelo.
            ("drzeni se neopakuje (pta se jen na just_pressed)",
             "var stisknuto: bool = Input.is_action_pressed(input_action)",
             "var stisknuto: bool = Input.is_action_just_pressed(input_action)"),
            ("stred pro smer je stred okna, ne hrac na obrazovce",
             "center_for(player, camera_offset, z), mouse_position)",
             "view_size / 2.0, mouse_position)"),
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
            # ⚠ 19. session - vzor vyse (puvodni text `player_screen_position(
            # player, camera_offset, z), mouse_position)`) byl MRTVY: V14 zavedla
            # `center_for(...)`, ktery presnou pozici hrace dostava od klienta.
            # Vzor na TOTEZ v novem kode je u modulu vyse.
            ("kurzor na hraci se posle jako krok (a spali prodlevu)",
             "if smer < 0:\n\t\t\t\tcontinue\n",
             ""),
            # --- 19. session, zadani 19 -------------------------------------------------
            # V14: klient posila PRESNOU pozici hrace (`player_screen`); kdyz se
            # ignoruje, pocita se stred z `z = 0`, ktery je o 40 px jinde
            # (namEReno: 4 473 z 11 163 pozic kurzoru vratilo jiny smer).
            ("presna pozice hrace se ignoruje (stred z z=0)",
             "if player_screen != Vector2.INF:", "if false:"),
            # V4: auto-run se rusi NOVYM stiskem praveho tlacitka; bez te vetve
            # neexistuje cesta, jak bezet zastavit (Esc je jen doplnkovy).
            ("auto-run se neda zastavit pravym klikem",
             'elif bool(vstup.get("right_just", false)):', "elif false:"),
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
            # --- 19. session, zadani 19 -------------------------------------------------
            # V14: klient musi poslat PRESNOU pozici hrace pro smer z mysi.
            ("klient neposila pozici hrace pro smer z mysi",
             "\t_publish_center()\n", ""),
            # V15a: otoceni na miste se musi projevit i v KRESLENI - kdyz klient
            # pri prazdnem kroku neprebere `player.dir`, nakresli stary smer.
            ("otoceni na miste se v kresleni neprojevi",
             "if player != null and _view_dir != int(player.dir):",
             "if false:"),
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
            # --- 19. session, zadani 19 (V1, V5, V9) ------------------------------------
            # V5 "pri pohybu cela obrazovka zrni": NAMERENO, ze pri zoomu != 1 se
            # svetovy pixel mapuje na ZLOMEK pixelu obrazovky (52,27 % pixelu se
            # zmeni i pri cistem posunu; `snap_na_pixely` to srazi na 0,23 %).
            ("snap na mrizku obrazovky vypnuty (pri zoomu != 1 obraz zrni)",
             "if not snap_na_pixely or is_equal_approx(zoom, 1.0):", "if true:"),
            ("snap vraci vstup (zaokrouhleni se neprovede)",
             "return (p * zoom).round() / zoom", "return p"),
            # V9: okno seznamu objektu MUSI rust s oddalenim, jinak obrazovka
            # prestane byt pokryta a u okraju vzniknou DIRY.
            ("okno seznamu ignoruje zoom (pri oddaleni vzniknou diry)",
             "\t# tedy viewport / zoom - pri oddaleni okno roste presne o `1 / zoom`.\n"
             "\tvar rozmer: Vector2 = svet_rozmer()",
             "\t# tedy viewport / zoom - pri oddaleni okno roste presne o `1 / zoom`.\n"
             "\tvar rozmer: Vector2 = get_viewport_rect().size"),
            ("zoom se oreze na spatne meze (hodnota utece)",
             "var omezene: float = clampf(novy, ZOOM_MIN, ZOOM_MAX)",
             "var omezene: float = novy"),
            # ⚠ NAMERENO 2026-10-09: tahle mutace drive SMAZALA jediny prikaz
            # v `if _camera != null:` (world_view.gd:450-452), takze vznikl
            # PRAZDNY BLOK = parse error. Mutant se vubec nenacetl a case to
            # hlasil jako "NENI HOTOV" - a harness to (do opravy vys) pocital
            # jako CHYCENO. Telo bloku se proto nahrazuje `pass`, ne prazdnem.
            ("kamera nedostane zoom (svet se nezmensi)",
             "\t\t_camera.zoom = Vector2(zoom, zoom)\n", "\t\tpass\n"),
            ("vychozi zoom je 1,0 (rozhled se nezvetsi)",
             "const ZOOM_VYCHOZI: float = 0.75", "const ZOOM_VYCHOZI: float = 1.0"),
            ("cerny pas se deli spatnym zoomem (hrac mimo stred)",
             "+ offset + gui_odsazeni / zoom", "+ offset + gui_odsazeni"),
            # V1 "propadam se do textury mostu": klic hrace musi byt ZA vsim,
            # co ho muze prekryt (statik na jeho dlazdici, plosina pod nim).
            # Kdyz se bere jen klic mobila na jeho dlazdici, kryje hrace
            # statik s vetsim `priority_z` (namEReno: 187 px z 804).
            ("klic hrace se pocita jen z jeho dlazdice (prekryje ho statik)",
             "return nejvyssi + 1", "return _sort.sort_key({\"kind\": \"mobile\", \"x\": int(_player.pos.x), \"y\": int(_player.pos.y), \"z\": int(_player.pos.z)})"),
            # ⚠ 19. session - text `return nejvyssi + 1` je v souboru DVAKRAT
            # (v `_sort_key_of_player` a v `klic_hrace_stats`), takze vzor vyse
            # mutuje jen PRVNI vyskyt - a ten druhy se v novem kodu ani nepouzije.
            # Tenhle vzor cili ZALOHU pro prazdny seznam; text musi byt
            # jednoznacny, jinak je mutace ticha (namEReno: s obecnym textem
            # vyslo "SLEPY", protoze se zaloha nemutovala).
            ("zaloha klice hrace vraci nulu (pri prazdnem seznamu je hrac pred vsim)",
             "return _sort.klic_nad_diagonalou(diagonal) + 1", "return 0"),
            # --- 19. session: VYMENA TEXTUR ZA BEHU (`nastav_vymenu`)
            # Kdyby se nahrady nepredaly DÁVCE, projevila by se vymena jen na
            # puvodni ceste kresleni a na svazich (kde se bere texmap) ne -
            # presne to je past, kterou ma tenhle test chytit.
            ("vymena textur se dávce nepreda (na svazich se neprojevi)",
             "\t\t_mesh.vymena = nahrady\n", ""),
            ("prazdna vymena dávku nevypne (stare nahrady zustanou)",
             "\tvymena_textur = nahrady\n", "\tvymena_textur = {}\n"),
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
            # ⚠ 19. session (task-5): STINOVANI SVAHU PODLE NORMALY. Do teto
            # session tu byl vzor `barva = SVAH_BARVA  # viz SVAH_JAS v hlavicce`,
            # ale ten radek se prepsal na `barva = svah_barva(obj)`, takze se
            # mutace TISE neprovadela ("PATRANA VETA SE NENASLA"). Nahrazeny jsou
            # dva vzory od teammate „svetlo" (overene rucnim behem, kazdy ma
            # v dokladu pocet selhani): vypnuti stinovani a zruseni normaly.
            ("svah se kresli bez stinovani podle normaly (jedna barva)",
             "var base: float = maxf(n.dot(SVETLO_SMER.normalized()), 0.0) / 2.0 + 0.5",
             "var base: float = SVAH_JAS"),
            ("normala svahu je vzdy svisla (zadny sklon)",
             "return (r - l).cross(b - t).normalized()",
             "return Vector3(0.0, 0.0, 1.0)"),
            ("svetlo sviti z opacne strany (stin na spatne strane)",
             "const SVETLO_SMER := Vector3(0.0, 1.0, 1.0)",
             "const SVETLO_SMER := Vector3(0.0, -1.0, 1.0)"),
            ("jas se neořezává na 1.0 (textura se muze preexponovat)",
             "var j: float = clampf(svah_jas(obj, brightlight), 0.0, 1.0)",
             "var j: float = svah_jas(obj, brightlight)"),
            # ⚠ 19. session: ZKOUSENO a ODSTRANENO (stejna rodina jako u `sort`):
            # vetev `if j == SVAH_JAS: return SVAH_BARVA` vraci PRESNE tutez
            # barvu, kterou by dala i cesta pres `Color(j, j, j, 1.0)`. Zkousene
            # mutace ("vetev nikdy", "vrat 0.8535534") testy NEODHALI (namEReno
            # `_analyza/p22-mutace-trate7.txt`), protoze `Color` se v GDScriptu
            # uklada jako float32 a 0.8535534 i 0.85355339 zkola na tutez
            # float32 hodnotu. Neni to slepa BRANA (test na identitu existuje
            # a chyti zmenu prahu, napr. SVAH_JAS 0.85), ale je to mrtva METRIKA -
            # a mrtva metrika se nema nechat lezet. Az bude mit vetev vlastni
            # test na bitovou presnost (pres `PackedByteArray`), vzor se vrati.
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
            # ⚠ 20. session: MATERIAL RECEPTU SE HLEDA PODLE TYPU (identita),
            # ne podle artu - jeden typ ma vic artu (prkna 4, klada 6).
            # Kdyby se porovnaval jen art, hromada s jinou grafikou by se do
            # receptu NEPOCITALA (kryje to case `item_type`, sekce 3).
            ("material se porovnava jen podle artu (jiny art tehoz typu se nenajde)",
             '\tif hledany != "" and str(item.type) != "":\n\t\treturn str(item.type) == hledany',
             '\tif false:\n\t\treturn false'),
            # ⚠ 20. session: STANICE MUZE BYT I PREDMET NA ZEMI (tak ji klade
            # `app/main._postav_stanice`; v okoli Britainu neni statik).
            # Kdyby se ptala jen mapy, kliknuti na vyhen by vracelo `no_pair`
            # (namEReno sondou `p24-vyroba.gd`, kryje to case `interact`, O2).
            ("stanice se hleda jen v mape (predmet na zemi se ignoruje)",
             '\tif _items is Dictionary:\n\t\tfor serial in _items:\n\t\t\tvar item = _items[serial]\n\t\t\tif item == null or int(item.parent) != 0:',
             '\tif false:\n\t\tfor serial in _items:\n\t\t\tvar item = _items[serial]\n\t\t\tif item == null or int(item.parent) != 0:'),
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
    # --- 2026-10-09: druha cast milniku MK (`sim.offline`, stav entit) --------
    # Vzory pro `sim/offline.gd`: kazda vada musi chytit case `offline`
    # (`--offline-script`). Brana F1 ma vlastni mutacni dukaz
    # (`check-world-clock.py --mutace`); tenhle seznam dokazuje, ze to same
    # odhali i TESTY (dve nezavisla mereni tehoz).
    "offline": {
        "soubor": ROOT / "sim" / "offline.gd",
        "prefix": "sim.offline",
        "prepinac": "--offline-script",
        "mutace": [
            ("dobeh se vubec neprovede",
             "\tvar from_ms: int = int(_world.world_time())",
             "\tvar from_ms: int = int(_world.world_time())\n\treturn _empty_report(0)"),
            ("dobeh se pocita od aktualniho casu, ne absolutne (zavisi na davkach)",
             "var at: int = (from_ms / every + 1) * every", "var at: int = from_ms + every"),
            ("cas se pricte dvakrat (dobeh neni absolutni)",
             "_world.advance_offline(to_ms - current)", "_world.advance_offline(to_ms)"),
            ("strop dobehu se ignoruje (rok absence se dobehne cely)",
             "if target > from_ms + MAX_CATCHUP_MS:", "if false:"),
            ("dobeh se ohlasí jako 0 kroku",
             "\t\tsteps += 1", "\t\tsteps += 0"),
        ],
    },
    # Vzory pro `sim/entity/mobile.gd` (stav mobila). Chytá je case
    # `entity_state` (`--mobile-script`).
    "mobile": {
        "soubor": ROOT / "sim" / "entity" / "mobile.gd",
        "prefix": "entity.mobile",
        "prepinac": "--mobile-script",
        "mutace": [
            ("state() ztrati pozici",
             '"pos": [pos.x, pos.y, pos.z],', '"pos": [0, 0, 0],'),
            ("state() necte strop skillu (legendarni svitek se ztrati)",
             "caps.append(skills.cap(i) - SkillsScript.CAP_DEFAULT)", "caps.append(0)"),
            ("restore() necte pozici z JSONu",
             "if p is Array and p.size() >= 3:", "if false:"),
            ("state() zapomene equip",
             '"equip": _equip_state(),', '"equip": [],'),
        ],
    },
    # --- 2026-10-09 (ZADANI-24): treti cast milniku MK ----------------------
    # Vzory pro `sim/policy.gd` (pravidla s podminkami). Chytá je case
    # `policy` (`--policy-script`). Kazda vada vraci do kódu to, co by udelalo
    # z "hra provede, co hrac rozhodl" "hra rozhodne za hrace".
    "policy": {
        "soubor": ROOT / "sim" / "policy.gd",
        "prefix": "sim.policy",
        "prepinac": "--policy-script",
        "mutace": [
            ("podminka se vyhlasi za splnenou, i kdyz neni",
             "var ok: bool = (have < need) if kind == \"item_below\" else (have >= need)",
             "var ok: bool = true"),
            ("priorita se ignoruje (rozhoduje poradi v datech)",
             "\tvar pa: int = priority_of(a)\n\tvar pb: int = priority_of(b)",
             "\tvar pa: int = 0\n\tvar pb: int = 0"),
            ("chybejici stav se cte jako nula (pravidlo se vyhodi z niceho)",
             "if not state.has(\"inventory\"):\n\t\treturn _met(false, \"stav nezna: inventory\")",
             "if not state.has(\"inventory\"):\n\t\tstate[\"inventory\"] = {}"),
            ("duvod preskoceni se nevyplni (zustane jen akce)",
             "_skipped.append({\"rule_id\": str(rule[\"id\"]), \"why\": why})",
             "_skipped.append({\"rule_id\": str(rule[\"id\"]), \"why\": \"\"})"),
            ("vadna data se prijmou (neznamy druh podminky)",
             "if not (when.get(\"kind\", \"\") in CONDITION_KINDS):",
             "if false:"),
        ],
    },
    # Vzory pro `sim/executor.gd` (rozhodnuti -> `Command`). Chytá je case
    # `executor` (`--executor-script`).
    "executor": {
        "soubor": ROOT / "sim" / "executor.gd",
        "prefix": "sim.executor",
        "prepinac": "--executor-script",
        "mutace": [
            ("prikaz se neposle (jen se to rozhodne)",
             "\tout.append(command)", "\tpass"),
            ("neplatny prikaz se posle do sveta",
             "if not bool(verdict.get(\"ok\", false)):", "if false:"),
            ("vykonavatel saha na stav (meni ho)",
             "\tvar decisions: Array = _policy.evaluate(state)",
             "\tvar decisions: Array = _policy.evaluate(state)\n\tif state is Dictionary:\n\t\tstate[\"vynulovano\"] = true"),
            ("zastaveni se ignoruje (stop nezastavi)",
             "\tif _stopped:", "\tif false:"),
            ("nizsi priorita se zahodi TISE (bez duvodu)",
             "_skip(str(decisions[i].get(\"rule_id\", \"\")), \"lower priority (decided: \" + _last_rule + \")\")",
             "_skip(str(decisions[i].get(\"rule_id\", \"\")), \"\")"),
        ],
    },
    # Vzory pro `sim/decision_log.gd` (duvod a historie). Chytá je case
    # `decision_log` (`--decision-log-script`).
    "decision_log": {
        "soubor": ROOT / "sim" / "decision_log.gd",
        "prefix": "sim.decision_log",
        "prepinac": "--decision-log-script",
        "mutace": [
            ("duvod se nezapise (zustane jen pravidlo)",
             "\t\t\"why\": why,", "\t\t\"why\": \"\","),
            ("since() vraci i starsi zaznamy, nez se ptal",
             "if int(e.get(\"tick\", 0)) >= int(tick_value):",
             "if int(e.get(\"tick\", 0)) >= 0:"),
            ("strop se ignoruje (log roste bez omezeni)",
             "while _entries.size() > MAX_ENTRIES:", "while false:"),
            ("stejna zprava se do zurnalu sype porad",
             "if text == _published:\n\t\treturn", "if false:\n\t\treturn"),
        ],
    },
    # Vzory pro ZAPOJENI politiky do `SimWorld` (`sim/sim_world.gd`). Chytá je
    # case `policy_hook` (`--world-script`, prefix `sim.policy_hook`) - proto
    # je to samostatny modul: `world_loop` meri tick systemu, tenhle zmenu
    # chovani pri nactene politice. Mutuje se TYZ SOUBOR, ale jiny vzor.
    "policy_hook": {
        "soubor": ROOT / "sim" / "sim_world.gd",
        "prefix": "sim.policy_hook",
        "prepinac": "--world-script",
        "mutace": [
            ("vykonavatel se v ticku vubec nevola (politika nic nedela)",
             "\tif executor != null:", "\tif false:"),
            ("prikaz politiky se tvari jako prikaz hrace (src)",
             "\t\t\tcommand[\"src\"] = \"policy\"", "\t\t\tcommand[\"src\"] = \"player\""),
            ("prikaz hrace se neoznaci (puvod se neda rozlisit)",
             "if not c.has(\"src\"):\n\t\t\tc[\"src\"] = \"player\"",
             "if false:\n\t\t\tc[\"src\"] = \"player\""),
            ("politika se zaregistruje jako stavovy zdroj (zmeni se hash)",
             "\tpolicy = new_policy\n\texecutor = null if policy == null else SimExecutor.new(policy, decision_log)",
             "\tpolicy = new_policy\n\texecutor = null if policy == null else SimExecutor.new(policy, decision_log)\n\tif policy != null:\n\t\tregister_state_source(\"policy\", _scheduler)"),
        ],
    },
    # --- 2026-10-09: D3 jako HUD (`ui/policy_panel.gd`) ----------------------
    # Uzivatel rekl "D3 prijmu jen jako HUD": pravidla se z `user://policy.json`
    # konecne daji VIDET ve hre, ale jen CTENI (okno nic needituje ani neuklada).
    # Chytá je case `policy_panel` (`--policy-panel-script`).
    #
    # ⚠ Kazda vada je v CHOVANI, ne v textu (docs/09 §9.6): kdyz se zmeni jen
    # text hlasky, test to chytit NEMA - proto se mutuje plneni radku, poradi,
    # duvod a uvolnovani uzlu.
    #
    # ⚠ PORADI V TESTU JE "NAHODNE" (priorita 10 pred 50) ZAMERNE: kdyby test
    # mel vstup uz setrideny, vada "UI tridi podle priority" by prosla - a to
    # je presne to, co UI delat NESMI (tridi `sim.policy`, ne UI).
    "policy_panel": {
        "soubor": ROOT / "ui" / "policy_panel.gd",
        "prefix": "ui.policy_panel",
        "prepinac": "--policy-panel-script",
        "mutace": [
            ("duvod pravidla se do radku vubec neda (okno ukaze jen '-')",
             '"reason": str(radek.get("reason", "")),', '"reason": "",'),
            ("UI si pravidla prehazi (poradi rozhoduje, ne priorita v sim)",
             '\t\t})\n\t_stav = stav.duplicate(true) if stav is Dictionary else {}',
             '\t\t})\n\t_radky.reverse()\n\t_stav = stav.duplicate(true) if stav is Dictionary else {}'),
            ("prazdny seznam se tvari jako chybejici stav (neni videt, ze nic neni)",
             "const BEZ_PRAVIDEL: String = \"(zadna pravidla)\"",
             "const BEZ_PRAVIDEL: String = \"(stav nevykonavatele neni znamy)\""),
            # ⚠ Nasel verifikator 2026-10-09 (nepresny komentar, ktery se tvaril
            # jako hotova vec): okno melo v prazdnem stavu "rovnou pripomenout
            # `user://policy.json`", ale vykreslovalo jen "(zadna pravidla)" -
            # hrac se tedy nedozvedel, KAM pravidla psat (a to je presne duvod,
            # proc bylo D3 prijato "jen jako HUD"). Vzor tu vetu odstrani.
            ("prazdne okno nerekne, kam se pravidla pisou",
             "\t\tvar kde := Label.new()\n\t\tkde.name = \"KdePravidla\"\n\t\tkde.text = KDE_PRAVIDLA\n\t\tbox.add_child(kde)\n",
             ""),
            ("radek ztrati prioritu (rozhodnuti se neda dohledat)",
             "return \"#%d %s - %s\" % [", "return \"%s - %s\" % ["),
            # ⚠ ZDE BYLY DVE MUTACE, KTERE PROSLY (obe namERene 2026-10-09, a
            # kazda z jineho duvodu - viz `LESSONS.md`):
            #   (a) "stare radky zustanou v okne" = `child.free()` -> `pass`.
            #       NEBYLA to chyba testu: `_vycisti` vola `remove_child()` PRED
            #       `free()`, takze uzel je z `get_child_count()` pryc i bez
            #       uvolneni - mutace menila jen pamet, ne obsah.
            #   (b) "do okna se dostane jen prvni pravidlo" = zkraceni smyčky
            #       v `flush()`. Byla to CHYBA TESTU: pritomna kontrola
            #       porovnavala text uzlu s `telo_text()`, a ten se skladá
            #       z TÉŽ smyčky - obe strany se zkratily stejne. Opraveno
            #       kontroli "v okne jsou OBA radky", ktera cte UZLY (nezavisly
            #       zdroj); vzor je proto tady znovu a tentokrat musi projit.
            ("do okna se dostane jen prvni pravidlo (seznam se ztrati)",
             "for radek in _radky:\n\t\tvar radek_uzel := Label.new()",
             "for radek in _radky.slice(0, 1):\n\t\tvar radek_uzel := Label.new()"),
            # ⚠ Nasel verifikator 2026-10-09 (slepa kontrola, 0 selhani z 1671):
            # obsah zacinal o 3 px vys nez konci hlavicka (konstanta 20 px vs
            # skutecnych 23 px textu) a prvni radek se s ni prekryl. Vzor vraci
            # presne tuhle vadu - pozice se pocita z hlavicky.
            ("obsah se posune nahoru (kresli se pres hlavicku)",
             "\tvar pod_hlavickou: float = maxf(HLAVICKA_VYSKA, hlavicka.get_combined_minimum_size().y)\n\tbox.position = Vector2(0.0, pod_hlavickou + MEZERA)",
             "\tbox.position = Vector2(0.0, 0.0)"),
            # ⚠ POZOR: vada V1 ("prazdny vstup se nevykresli") je v
            # `app/main.gd` (`poprve`), a ten NEMA vlastni mutacni modul - do
            # tohohle seznamu nepatri, protoze by se hledal vzor v jinem
            # souboru. Jeji doklad je jiny: `tests/cases/policy_panel.gd`
            # ("prazdny vstup se VYKRESLI") + sonda `_analyza/p33-panel-ve-hre.gd`
            # v CELE hre bez `user://policy.json` (okno ukazalo
            # "PRAVIDLA (0) | (stav nevykonavatele neni znamy)" a "(zadna pravidla)").
        ],
    },
    # --- 2026-10-10: vlna 1 zakladu pro demo (D10, `ROZHODNUTI-...-VECER-DEMO.md`) --
    # Vzory pripravil teammate `zaklady` a OVERIL rucnim behem (27 z 27 chyceno,
    # doklad `.tmp/zaklady/mutace-vysledek.txt`); tady jsou zapsane do sdileneho
    # harnessu. Provedeni a verdikt u kazdeho vzoru hlasi az HARNESS - slaby vzor
    # se pozna tak, ze PROSEL (a pak se opravuje TEST, ne vzor).
    #
    # `sim.regen`: intervaly jsou MERENE hodnoty (docs/05 §5.14, research/01
    # §1.4), takze kazda zmena cisla musi shodit case `regen`.
    "regen": {
        "soubor": ROOT / "sim" / "systems" / "regen.gd",
        "prefix": "sim.regen",
        "prepinac": "--regen-script",
        "mutace": [
            ("stamina se doplnuje 2x pomaleji (10 s misto 5 s)",
             "const STAM_MS := 5000", "const STAM_MS := 10000"),
            ("hp se doplnuje 2x rychleji (5 s misto 10 s)",
             "const HITS_MS := 10000", "const HITS_MS := 5000"),
            ("koeficient meditace i pod 100,0 (0,0275 misto 0,025)",
             "const COEF_LOW := 0.025", "const COEF_LOW := 0.0275"),
            ("hlad uz nezdrzuje hp (multiplier 1)",
             "const HUNGRY_HP_MULT := 2", "const HUNGRY_HP_MULT := 1"),
            ("mrtvy mobil regeneruje",
             "\t\tif mob == null or not mob.alive():\n\t\t\tcontinue",
             "\t\tif mob == null:\n\t\t\tcontinue"),
            ("hlad se aplikuje vzdy (i pri level 6)",
             "\treturn int(_hunger.level(int(mob.serial))) <= 0", "\treturn true"),
        ],
    },
    # `entity.equipment`: pravidla vrstev z reference a invariant "prave jeden
    # rodic"; posledni vzor je nalez pro `entity.container` (`remove()` predmet
    # spotrebuje), ktery si modul oboustranne obnovuje.
    "equipment": {
        "soubor": ROOT / "sim" / "entity" / "equipment.gd",
        "prefix": "sim.entity.equipment",
        "prepinac": "--equipment-script",
        "mutace": [
            ("stit pri dvourucne zbrani se povoli",
             "\tif layer == LAYER_TWO_HANDED and _je_stit(item):", "\tif false:"),
            ("obsazena vrstva se prehledne",
             "\tif obsazeno != 0:", "\tif false:"),
            ("jednorucni + dvourucni zbran se povoli",
             "\tif _konflikt_dvourucni(mob, item, layer):", "\tif false:"),
            ("vrstva mimo uzivatelsky rozsah se prijme",
             "\tif layer < LAYER_FIRST or layer > LAYER_LAST_USER:",
             "\tif layer < LAYER_FIRST:"),
            ("vaha nasazeneho predmetu ignoruje mnozstvi",
             "\t\t\tsoucet += int(_tiledata.weight(int(item.tile))) * int(item.amount)",
             "\t\t\tsoucet += int(_tiledata.weight(int(item.tile)))"),
            ("bonus se pocita i z predmetu v batohu",
             "\tfor serial in _serials(mob):\n\t\tvar item = _item(serial)\n"
             "\t\tif item != null and item.props is Dictionary:",
             "\tfor serial in _items.keys():\n\t\tvar item = _item(serial)\n"
             "\t\tif item != null and item.props is Dictionary:"),
            ("vyjmuty predmet ztrati mnozstvi (amount 0)",
             "\t\tif _container.remove(p, int(item.serial), pocet) > 0:\n"
             "\t\t\titem.amount = pocet",
             "\t\tif _container.remove(p, int(item.serial), pocet) > 0:\n\t\t\tpass"),
        ],
    },
    # `world.regions`: dnes NEMERENA data - mutace musi shodit jak "neumi rict
    # neznam", tak merene chovani nad fixtures.
    "regions": {
        "soubor": ROOT / "sim" / "world" / "regions.gd",
        "prefix": "world.regions",
        "prepinac": "--regions-script",
        "mutace": [
            ("nemerena data se tvari jako zmerena",
             "\t_known = not _regions.is_empty()", "\t_known = true"),
            ("mimo region se vraci prvni region (meze se nekontroluji)",
             "\t\tif x >= r[0] and y >= r[1] and x < r[0] + r[2] and y < r[1] + r[3]:",
             "\t\tif x >= r[0] and y >= r[1]:"),
            ("okno regionu je uzavrene (hranice patri obema)",
             "x < r[0] + r[2] and y < r[1] + r[3]",
             "x <= r[0] + r[2] and y <= r[1] + r[3]"),
            ("plocha mimo `area` se ignoruje",
             "\tvar src: Dictionary = area if area is Dictionary else rec",
             "\tvar src: Dictionary = area if area is Dictionary else {}"),
            ("pri prekryvu vyhrava POSLEDNI zaznam",
             "\t\t\t_regions.append(rec)", "\t\t\t_regions.push_front(rec)"),
            ("zaznam bez `name` se prijme (skipped se nemeri)",
             "\t\tif rec is Dictionary and str(rec.get(\"name\", \"\")) != \"\":",
             "\t\tif rec is Dictionary:"),
        ],
    },
    # `ui.skill_list`: tenky klient - mutace nesmi projit ani na formatovani,
    # ani na zamky, ani na "prazdno je videt", ani na "UI nemeni stav".
    "skill_list": {
        "soubor": ROOT / "ui" / "skill_list.gd",
        "prefix": "ui.skill_list",
        "prepinac": "--skill-list-script",
        "mutace": [
            ("hodnota se zaokrouhli na cele (desetiny se ztrati)",
             "\treturn \"%s%d.%d\" % [znamenko, v / 10, v % 10]",
             "\treturn \"%s%d.0\" % [znamenko, v / 10]"),
            ("zamek `down` se tvari jako `lock`",
             "\tif zamek == LOCK_DOWN:\n\t\treturn \"down\"",
             "\tif zamek == LOCK_DOWN:\n\t\treturn \"lock\""),
            ("neznamy zamek se tvari jako `lock`",
             "\treturn \"?\"", "\treturn \"lock\""),
            ("prazdny vstup se nevykresli (ticho)",
             "\tif _radky.is_empty():\n\t\t_pridej_label(\"Prazdno\", BEZ_SKILLU)\n", ""),
            ("preskocene (vadne) radky se nepocitaji",
             "\t\t\t_skipped += 1", "\t\t\tpass"),
            ("tlacitko use posle vzdy skill -1",
             "\tvar skill: int = int(radek.get(\"id\", radek.get(\"skill\", -1)))",
             "\tvar skill: int = -1"),
            ("UI pri stisku meni obsah okna (nemeni se jen ohlasi)",
             "\tuse_pressed.emit(skill)",
             "\tuse_pressed.emit(skill)\n\t_box.get_child(0).get_child(1).text = \"99.9\""),
            ("update vykresli jen prvni radek",
             "\tfor radek in rows:", "\tfor radek in rows.slice(0, 1):"),
        ],
    },
    # --- 2026-10-10: obchod (vlakna `ekonom`, D10) ---------------------
    # Vzory pripravil teammate `ekonom` a OVERIL rucnim behem (25 z 25
    # chyceno); tady jsou prenesene PRIMO z jeho zdroje, ne prepsane rucne.
    "vendor": {
        "soubor": ROOT / "sim" / "systems" / "vendor.gd",
        "prefix": "sim.vendor",
        "prepinac": "--vendor-script",
        "mutace": [
            ('cena se neodečte (nakup nic nestoji)',
             '\t_odeber_zlato(mob, celkem)',
             '\tpass'),
            ('prodej da DVAKRAT vic zlata, nez ma byt',
             '\t\tcelkem += kus * mnozstvi\n\t\tprodej.append(',
             '\t\tcelkem += kus * mnozstvi * 2\n\t\tprodej.append('),
            ('prodej odebere predmet, ale ZLATO NEPRIDA',
             '\tvar vlozeno: bool = _container.add(int(mob.backpack), zlato)',
             '\tvar vlozeno: bool = false'),
            ('prodej predmet VUBEC neodebere',
             '\t\tvzato += _odeber_art(mob, int(p["art"]), int(p["amount"]))',
             '\t\tpass'),
            ('restock nikdy nedoplni sklad',
             '\t_dopln(id, rec)',
             '\tpass'),
            ('sklad se pri nakupu neodečte',
             '\t\t_uber_stock(v, str(n["type"]), int(n["amount"]))',
             '\t\tpass'),
            ('kontrola skladu se preskoci (proda se i co neni)',
             '\t\tif _stock_of(v, typ) < mnozstvi:',
             '\t\tif false:'),
            ('kontrola zlata se preskoci (nakup i bez penez)',
             '\tif _gold(mob) < celkem:',
             '\tif false:'),
            ('buy_price nema koeficient 1,90 (prodava za nakupni cenu)',
             '\treturn (zaklad * percent + 99) / 100',
             '\treturn zaklad'),
            ('zlato se da prodat (sell_price zlata neni 0)',
             '\tif typ == GOLD_TYPE:\n\t\treturn 0',
             '\tif false:\n\t\treturn 0'),
            ('cena predmene, ktery vendor jen prodava, se bere z `value` (ne z tabulky)',
             '\tif not e.is_empty() and int(e.get("price", 0)) > 0:\n\t\treturn maxi(1, (int(e["price"]) * 100) / percent)',
             '\tif false:\n\t\treturn maxi(1, (int(e["price"]) * 100) / percent)'),
            ('strop proti arbitrazi se ignoruje (koupit u kovare, prodat u krejciho)',
             '\tif strop > 0 and cena > strop:\n\t\tcena = strop',
             '\tif false:\n\t\tcena = strop'),
            ('state() zapomene sklad (save/load ztrati obchod)',
             '\treturn {"stock": sklad, "restock": _restock.duplicate()}',
             '\treturn {"stock": {}, "restock": _restock.duplicate()}'),
            # ⚠ POZOR: `_dosah` guard je v souboru 2x (nakup i prodej).
            # `replace(..., 1)` mutuje jen PRVNI vyskyt, proto je tenhle vzor
            # rozsireny kontextem NAKUPU (`var nakup`) a vzor nize kontextem
            # PRODEJE (`var prodej`) - jinak by kazdy meril jen pulku cesty.
            ('dosah se nekontroluje (obchodovat jde z cele mapy)',
             '\tif not _dosah(mob, v):\n\t\treturn _fail("too_far" if _pozice.has(_vid(v)) else "no_vendor_pos")\n\t_restock_if_due(v)\n\tvar nakup: Array = []',
             '\tif false:\n\t\treturn _fail("no_vendor_pos")\n\t_restock_if_due(v)\n\tvar nakup: Array = []'),
            ("neznama pozice vendora se hlasi jako 'too_far' (nejde rozlisit proc)",
             '\t\treturn _fail("too_far" if _pozice.has(_vid(v)) else "no_vendor_pos")\n\t_restock_if_due(v)\n\tvar prodej: Array = []',
             '\t\treturn _fail("too_far")\n\t_restock_if_due(v)\n\tvar prodej: Array = []'),
            ('dosah je z cele mapy (100 dlazdic misto 2)',
             'const VENDOR_RANGE := 2',
             'const VENDOR_RANGE := 100'),
        ],
    },
    "vendor_gump": {
        "soubor": ROOT / "ui" / "vendor_gump.gd",
        "prefix": "ui.vendor_gump",
        "prepinac": "--vendor-gump-script",
        "mutace": [
            ('potvrzeni posle i PRAZDNY vyber',
             '\tif not (s in ["buy", "sell"]) or vybranych(s) <= 0:\n\t\treturn false',
             '\tif false:\n\t\treturn false'),
            ('mnozstvi se neoreze na to, co je k dispozici',
             '\tvar orezene: int = clampi(amount, 0, int(radek.get("amount", 0)))',
             '\tvar orezene: int = amount'),
            ('soucet ignoruje cenu (celkem je jen pocet kusu)',
             '\t\tsoucet += mnozstvi(smer, art) * int(radek.get("price", 0))',
             '\t\tsoucet += mnozstvi(smer, art)'),
            ("okno prijme i cizi gump (`gump_open{gump:'craft'}`)",
             '\tif str(obal.get("gump", "")) != "vendor":\n\t\treturn false',
             '\tif false:\n\t\treturn false'),
            ('radek bez `item` se prijme (v gumpu je nabidka, ktera neexistuje)',
             '\t\tif art <= 0:\n\t\t\tcontinue',
             '\t\tif false:\n\t\t\tcontinue'),
            ("potvrzeni vzdy posle `action:'buy'` (prodej se nikdy neposle)",
             '\t_pozadavek = {"t": "vendor", "action": s, "vendor": _vendor, "lines": lines}',
             '\t_pozadavek = {"t": "vendor", "action": "buy", "vendor": _vendor, "lines": lines}'),
            ('novy seznam necha STARY vyber (potvrdi se, co hrac nevidel)',
             '\t_vyber = {"buy": {}, "sell": {}}',
             '\tpass'),
            ('stare uzly se pri prebaveni NEUVOLNI (`free()` chybi)',
             '\t\t\tchild.free()',
             '\t\t\tpass'),
            ("prazdny seznam prodeje rekne '(nothing to buy)'",
             '\t\tprazdny.text = "(nothing to buy)" if _smer == "buy" else "(nothing to sell)"',
             '\t\tprazdny.text = "(nothing to buy)"'),
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


def _bez_class_name(text: str) -> str:
    """Mutant NESMI mit `class_name` - jinak se vubec nenacte.

    NAMERENO 2026-10-09 (nalez pri praci na bráně F1): kopie souboru, ktery ma
    `class_name` (`sim/sim_world.gd`, `sim/save.gd`, `sim/scheduler.gd`), skonci
    v Godotu na `Parse Error: Class "SimWorld" hides a global script class`.
    Test pak zahlasi "soubor chybi" - a harness to do dneska pocital jako
    CHYCENO, i kdyz se mutovany kod nikdy nespustil (modul `world_loop`).
    `class_name` se proto v KOPII odstrani; testy nacitaji cestou, ne jmenem
    tridy, takze se merene chovani nemeni.
    """
    return "\n".join(radek for radek in text.splitlines()
                     if not radek.startswith("class_name "))


def main() -> int:
    ap = argparse.ArgumentParser(description="Mutacni dukaz testu")
    ap.add_argument("--only", default=None,
                    help="sort, map, walk, doors, movement, registry, pathfind, textures, "
                         "item, container, interaction, skill_gain, hud, status_bar, "
                         "chunk_renderer, world_view, input, player_controller, chunk_mesh, "
                         "config, metrics, harvest, craft, journal, policy, executor, "
                         "decision_log, policy_hook (nebo vic carkami)")
    args = ap.parse_args()
    if godot_bin() is None:
        print("CHYBA: Godot nenalezen (nastav $GODOT) - mutace by nic nemerily")
        return 2
    klice = list(MODULY) if not args.only else [k.strip() for k in args.only.split(",")]

    puvodni = {k: MODULY[k]["soubor"].read_text(encoding="utf-8") for k in MODULY}
    hash_pred = {k: sha(v) for k, v in puvodni.items()
}

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
            mutant = _bez_class_name(zdroj.replace(stare, nove, 1))
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
            radky = fail_radky(vystup, modul["prefix"])
            # ⚠ NAMERENO 2026-10-09: MUTANT, KTERY SE NENACTE, NENI CHYCENA VADA.
            # Kopie souboru s `class_name` se v Godotu neda nacist
            # (`Parse Error: Class "SimWorld" hides a global script class`),
            # takze case zahlasi "soubor chybi" - a to ma v sobe PREFIX modulu,
            # takze to harness do teto chvile pocital jako CHYCENO, i kdyz se
            # mutovany kod vubec nespustil (`world_loop`). Dnes se to pozna:
            # mutant je na DISKU, ale FAIL rika, ze soubor chybi / nejde nacist.
            nenacetl = any(uri(cesta) in radek and (
                "chybi" in radek or "nejde nacist" in radek or "nelze nacist" in radek
                or "NENI HOTOVA" in radek) for radek in radky)
            chycena = (rc != 0 and probehla and bool(radky) and not nenacetl)
            if not probehla:
                poznamka = "SADA VUBEC NEPROBEHLA (0 kontrol)"
            elif nenacetl:
                poznamka = ("MUTANT SE NENACTL (parse error?) - to NENI chycena vada"
                            + (": " + radky[0][:70] if radky else ""))
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
