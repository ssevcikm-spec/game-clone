# 8. Brány a ověřování

> **Hlavní pravidlo celého projektu:** u každé brány se ptej
> **„proběhla skutečně?"**, ne jen **„neprotestovala?"**.
> Naměřeno vícekrát: brána, která se na nic nezeptala, hlásila zelenou
> (a někdy i `exit 0`) — a to je horší než brána, která spadne.

## 8.1 Co musí každá brána splňovat

1. **Umí selhat.** Napiš **mutační test**: vlož vadu a podívej se, že brána
   spadne. Bez toho brána není brána, jen dekorace.
2. **Vypíše, co změřila** (`kontrol: 57, selhání: 0`), a když je měřených
   objektů **nula**, **selže** (nebo výslovně napíše `NEMĚŘENO`).
3. **Čte kód, ne komentáře** (`radek.split("#", 1)[0]`), jinak komentář
   popisující vadu vypadá jako vada.
4. **Nepřeskočí tiše.** Když nemá vstupy (např. v CI nejsou assety), musí to
   být **vidět v logu** i v souhrnu.
5. **Má offline test** se známým správným **i** známým vadným vstupem.

## 8.2 Seznam bran

| # | Brána | Co měří | Kdy | Selže, když… |
|---|---|---|---|---|
| G1 | `check-schema.py` | **rozpor v zadání**: `docs/` + `data/*.json` + kód + atlas musí říkat totéž (tile 44, ISO_STEP 22, Z_SCALE 4, rozsahy id) | každý PR | některý zdroj tvrdí jiné číslo, nebo se číslo **nedá přečíst** |
| G2 | `check-layers.py` | **směry závislostí**: `sim/**` nesmí odkazovat `ui/`, `render/`, `app/`; nesmí obsahovat `Input.`, `Time.`, `OS.`, `randf(`, `randi(` | každý PR | jediný zakázaný odkaz (tvrdá brána) |
| **G14** | `check-state-float.py` (**přidáno 2026-10-10**) | **žádný float ve STAVU simulace** (`docs/01` §1.5 bod 3): členská proměnná typu `float`, která vstupuje do `state()`, a jakýkoli `Vector2(`/`Vector3(` v `sim/**`. **Lokální float ve výpočtu a členská konfigurace mimo stav jsou dovolené** a vypisují se do měření (naměřeno: 71 řádků s floatem ve výpočtu, 1 konfigurační člen) | každý PR | float ve stavu (rozbitý hash/save/replay) nebo float vektor v sim |
| G3 | `tests/run_tests.gd` | **chování simulace** (bez assetů, bez scény) | každý PR | kterákoli nepodmíněná kontrola spadne |
| G4 | `check-wiring.py` | **mrtvý kód**: každé deklarované `provides` je volané z **produkčního** kódu; každý `_on_*` je připojený k signálu | každý PR | funkce není volaná nebo handler není připojený |
| G5 | `check-content.py` | **obsah**: schémata `data/*.json`, existence art ID v manifestu, křížové odkazy (recept → materiál → předmět), počty C1–C10 | každý PR | chybí art, neplatný odkaz, nesplněný minimální počet |
| G6 | `check-assets.py` | **assety**: manifest vs. stránky atlasu, nulové/průhledné sprity, offsety zarovnání, shoda siluet framů animace; **od 2026-10-11 i VLASTNÍ art** (`assets/own-art.json`): stránky, prázdné sprity a invariant „nahrazení, ne přidání“ (každé vlastní id je i v UO manifestu) | každý PR s assety | nekonzistence manifestu nebo prázdný sprite |
| **G16** | `check-style.py` (**přidáno 2026-10-11**) | **vlastní art je PIXEL ART, ne rozmazaný render**: měří se na **spritech** (ne v reportu), že silueta je **0/255** (kontaktní stín se neposuzuje — jeho měkkost je záměr) a že paleta těla je pod stropem (80 barev; naměřeno 36–39 po stylu proti 472 před ním). Měří i **animace z anim listu** (jdou mimo atlas, takže by je jinak minula). Ostrost hrany se **hlásí, ale nehlídá** — naměřeno: ruda má po stylu 19,4 a je čitelnější; metrika, která trestá žádoucí vlastnost, není brána | každý PR s vlastním artem | silueta má poloprůhledné pixely (rozmazaný obrys) nebo se paleta vrátila k tisícům barev |
| **G17** | `check-land-variants.py` (**přidáno 2026-10-11**) | **jedno `land` id = N dlaždic podle souřadnic buňky** (`groups` ve vrstvě): měří se na **kreslicím seznamu** (`render.chunk`, ze kterého bere i dávka) podíl dlaždic shodných se sousedem — **bez `groups` musí vyjít přesně 100 %** (kalibrace na dnešní chování) a **s 16 variantami < 20 %**; dále že se vzor **neopakuje s periodou zarovnanou s mřížkou** (naivní `x*HASH_X ^ y*HASH_Y` dalo 100 %, naměřeno), že **dva nezávislé běhy dají stejný sha256** (determinismus), že **textura i offset jdou ze stejného záznamu** (fixture má u každé varianty jiný offset), že **dávka `render/chunk_mesh` má stejné varianty** (16 slotů vs. 1) a že konfigurace na disku má `groups` konzistentní s `sprites` | každý PR | varianty se nevybírají (nebo se vybírají pořád stejně / s periodou), textura a offset se rozejdou, dávka bere původní id, nebo je `groups` v konfiguraci nekonzistentní |
| **G15** | `check-own-art.py` (**přidáno 2026-10-11**) | **vlastní art se přepíná PO KUSECH**: každé `(kind, id)` z `assets/own-art.json` má texturu **i offset** z vlastního manifestu; id bez vlastního artu je **přesně totéž** jako s vypnutým vlastním artem; animace se přepíná po klíči (vlastní chůze vyhrává, co sada nemá, zůstává z UO); a **přepínač opravdu přepíná** (tentýž dotaz s vrstvami a bez nich dá jinou stránku). Měří se **voláním** `texture()`, `offset()`, `page_path()` a `sheet_file()` přes sondu `tools/gates/own_art_probe.gd`, výsledek se porovnává s manifesty na disku | každý PR | vlastní art se nepoužije (nebo se použije jen jako textura bez offsetu), fallback se změní, nebo přepínač nic nepřepne |
| G7 | `check-save.py` | **round-trip**: `save → load → state_hash` shodný | každý PR | hashe se liší nebo load selže |
| G8 | `check-determinism.py` | **determinismus**: dva běhy stejného skriptu příkazů (20 000 ticků) dají stejný hash | každý PR | hash se liší (float, neuspořádaná iterace, čas) |
| G9 | `check-replay.py` | **replaye**: `tests/replays/*.json` dají očekávaný hash | každý PR | odchylka (regrese mechaniky) |
| G10 | `check-render.py` | **vizuální korektnost měřená**: hra vykreslí mapu podle dat — správný počet dlaždic pro kameru, postava **není překrytá** (viditelné pixely v očekávané oblasti), jméno/HUD přítomny | každý PR | snímek neodpovídá datům (např. postava zmizí za zdí) |
| G11 | `smoke` | **běh**: hra se spustí headless na 300 framů bez `SCRIPT ERROR` | každý PR | jakákoli runtime chyba (Godot 3 API, `null`, chybějící uzel) |
| G12 | `bench_sim.gd` | **výkon**: tick ≤ 2 ms při 200 mobilech / 3000 předmětech | nightly | překročení limitu |
| G13 | `vision` (poradní) | **obsah vidí**: je na snímku město? je vidět postava se zbraní? | každý PR se snímkem | **neblokuje** — jen komentuje (falešný poplach je dražší) |
| **F1** | `check-world-clock.py` — **čeká na `MK`** | **svět má vlastní čas**: bez jediného příkazu od hráče se stav světa změní, dvakrát totéž dá totéž, netiká při tom celý svět, doběh je idempotentní a nezávisí na dávkování | každý PR (až bude `sim.offline`) | svět se bez hráče nehýbe, dva běhy se rozejdou, tikne celý svět, nebo doběh závisí na dávkách |
| **F4** | `check-no-waste.py` — **čeká na `MK`** | **nic není odpad**: každý výstup dosažitelný ve hře má konzumenta (recept / poptávku světa / propad) a odkaz na konzumenta vede na existující záznam | každý PR (až bude `data.vendors` a poptávka) | výstup bez konzumenta, **prázdný uzávěr** (nula měřených věcí), nebo konzument na neexistující id |
| **G18** | `check-data-paths.py` (**přidáno 2026-10-12**) | **cesta k datům je PARAMETR, ne zapečená konstanta** (`S1b`): pouští `tools/check-data-paths.py` a v `sim/` (mimo `sim/content.gd`, kde je deklarace zakladu) požaduje **nula** konstant čtených v těle funkce; konstanta smí být **jen default parametru**. `app/` se měří a vypisuje jako „volající“, ale za vadu se nepovažuje. Self-test: dva fixture stromy (konstanta jen v parametru = OK, konstanta v těle = VADA) | každý PR | modul si čte konstantu sám → **mod ho nepřebije a funguje zdánlivě** (u `balance.json` ano, u `items.json` ne; naměřeno 2026-10-12: 11 „smíšených“ a jedna lež v `sim.poison.source()`) |
| **G19** | `check-sound.py` (**přidáno 2026-10-12**) | **zvuk se OPRAVDU přehraje**: pouští `tools/gates/sound_probe.gd` na **živé scéně** a požaduje `prehrano > 0`, **všech pět zvuků** ve `podle_id` (`hit`, `hurt`, `death`, `mine`, `smith`) a `chyb == 0`. Sonda je vyvolává **skutečnými systémy** (souboj, smrt těla, těžba rudy, tavení u výhně), ne voláním modulu | každý PR | modul je zapojený, ale nic nehraje (naměřeno 2026-10-12: znal hráče `0` → `prehrano 0`, testy přitom zelené), nebo se některý zvuk po změně přestal ozývat |
| **G20** | `check-loop.py` (**přidáno 2026-10-19**) | **hráč projde krátkou smyčkou na REÁLNÉ scéně** (těžit → vytavit → vykovat → prodat). **Co je která cesta:** COMMAND cesta (od klienta do sim jednou branou `sim.enqueue` → `sim.tick` → `sim.commands.dispatch`) jsou kroky 1–2 (`interact` vyrábí `app.input_map`) a pak požadavky oken, které vyzvedne `app.main` (`craft`, `vendor`); KLIK na **skutečné `Button` uzly** jsou kroky 3–4 — sonda u každého ověří připojený signál `pressed` a ten **vyšle** (handler nikdy nevolá). Žádné **akční** systémy `sim/` se nevolají — sonda sahá jen na `sim.enqueue`, `sim.tick` a čtení (`sim.vendor.gold_of`). Sonda `tools/gates/loop_probe.gd` u **každého** kroku požaduje **hráčem viditelný následek**: novou zprávu v žurnálu a v ní očekávané slovo (`gather`, `smelt`, `create`, `sell`) — **ověřené z TEXTU** zpráv, ne z booleana sondy; plus hodnoty: ruda 0 → >0, ingoty 0 → ≥3, dýka 0 → >0, zlato 60 → 70 a dýka z batohu zmizí. **Skill Mining a Blacksmithy sonda zvedá na 1000** — měří se **průchodnost** smyčky, ne balance (s výchozím skillem umí tavení i výroba náhodně selhat). `prekryv` cílů interakce se **vypisuje, ale nehlídá**. Bez `--snimky` se snímky **neměří** a brána to řekne; `--snimky` spustí sondu **v okně**, sonda umí uložit 3–4 PNG a brána **vyžaduje alespoň 2** (`MIN_SNIMKU = 2`; velikost, hlavička PNG, dvě různé) — když sonda snímky nemůže vykázat (`snimky_zadany:false` / `snimky_chyba`), je to **VADA**, ne „neměřeno" (fail-closed) | každý PR | některý krok neprojde, hráč nevidí zprávu, hodnoty se nezmění, **krok 3/4 nemá klik na skutečné `Button` se signálem `pressed`** (naměřeno 2026-10-19: kopie s `Button` → `Label` a smazaným `_on_smer_pressed` = `exit 1`), `--snimky` nedodá 2 PNG, vypnutý prodej i vypnutá těžba = `exit 1`, nebo sonda nic nenahlásí |

**Dvě brány z pocitu (`F1`, `F4`) jsou od 2026-10-09 součástí smlouvy**
(rozhodnutí uživatele; návrh včetně kontrol a mutací:
`NAVRH-BRAN-FEEL-2026-10-09.md`). Vycházejí z poznatků `F1` a `F4` v `docs/01`
§1.8. **Aktuální stav (2026-10-10, ověřeno v `run-all.py`):**
**`F1` je zapojená** — soubor `tools/gates/check-world-clock.py` existuje,
`sim.offline` taky, a `F1` je v závazném pořadí za `G9`. **`F4`
(`check-no-waste.py`) soubor ještě nemá** — v tabulce je proto, aby se na ni
nezapomnělo, a do `run-all.py` se zapíše, až vznikne. Když brána nemá co měřit,
vrací `2` (`NEMĚŘENO`) a **nikdy** se to netváří jako zelená (§8.9).

**Pořadí v CI je závazné** (stav 2026-10-19, shodné s `run-all.py`):
G1 → **G3** → G5 → G2 → **G14** → **G18** → G4 → G6 → **G15** → **G16** → **G17**
→ G7 → G8 → G9 → **F1** → G11 → **G19** → **G20** → G10.
`G13` (vision) je **poradní** a jde mimo pořadí — nikdy neshodí běh, ale nesmí
být ticho (když není implementovaná, hlásí se to). Schéma je první, protože je
nejlevnější a rozpor v zadání zneplatňuje všechno ostatní. **`G15` jde hned za
`G6`**: `G6` měří assety jako soubory, `G15` měří, že je hra **opravdu bere**.
**`G17` jde za `G15`/`G16`**: `G15` měří, KTERÁ vrstva sprite dodává, `G16`, JAK
vypadá, a `G17`, že se sprity **střídají podle buňky** (a nepravidelně).
**`G20` jde za `G19` a před `G10`**: je to **integrační** brána — měří celou
smyčku, takže patří až za všechny podsoučásti (G1–G19); jejich vada by ji jinak
shodila z důvodu, který už má vlastní bránu. S `G19` se drží u sebe, protože
obě pouští **reálnou scénu**; `G10` zůstává poslední (čte snímek, nic nespouští).

## 8.3 Tři brány, které mají největší cenu

### G1 `check-schema.py` — rozpor v zadání je objektivní fakt

Měří, že **čtyři zdroje** říkají totéž:
`docs/02` (konstanty) ↔ `data/balance.json` ↔ `core/const.gd` ↔
`render/chunk_renderer.gd` (skutečné kreslení).

```python
# příklad kontroly (kostra)
TILE = read_const("core/const.gd", "TILE_W")          # 44
ISO  = read_const("core/const.gd", "ISO_STEP")        # 22
assert TILE == 44 * 2 // 2, "TILE_W nesedí s artem"
assert ISO == TILE // 2, "ISO_STEP musí být TILE_W/2"
# a hlavně: když se konstanta NEDÁ přečíst, je to VADA, ne prázdný seznam
if TILE is None:
    fail("TILE_W se nepodařilo přečíst — kontrola NEPROBĚHLA")
```

### G4 `check-wiring.py` — „funguje to, ale nic to nedělá"

Hledá volání **v produkčním kódu** (`sim/`, `ui/`, `render/`, `app/`),
ne v `tests/`. Naměřeno na jiném projektu: kontrola hledala použití v celém
repu **včetně testů**, takže funkce zmíněná jen v testu se počítala za
použitou, i když ji hra nikdy nezavolala.

### G10 `check-render.py` — vizuální změna se neověřuje testy

Naměřeno: hráč **nebyl na obrazovce** (dlaždice měly `z_index` 0 a vyšší,
hráč +5, takže ho překryly), a přitom byly testy, schéma i assety zelené.
Chybu našel až **pohled na snímek**. Proto G10 měří „je postava vidět"
přímo v pixelech a G13 se na snímek **dívá** (vision / `read_image`).

#### 8.3.1 Snímek je VSTUP — a musí být dnešní (DOPLNĚNO 2026-10-12)

`run-all.py` snímek **negeneruje**; G10 čte, co je na disku
(`.cache/render/snapshot.png`). Naměřeno 12. 10. 2026: ten snímek byl
z **10:06 předchozího dne** (26,4 h), zatímco `assets/own-lit/` i vrstva
`stone-path` byly přepsané večer — G10 tedy měřila obraz, který už ve hře
nebyl, a byla **zelená**. Proto G10 od 2026-10-12:

* **VADA**, když je snímek starší než kterýkoli **vstup obrazu**
  (`assets/own-art.json`, vrstvy vlastního artu včetně atlasů, `assets/uo/**`),
* **poznámka** (ne vada), když je starší než **kód kreslení**
  (`render/*.gd`, `app/world_view.gd`, `app/main.gd`) — kód se mění často
  a obraz měnit nemusí, ale má být vidět, že snímek může být ze staršího obrazu,
* u **cizího** snímku (`--snapshot`) se stáří neposuzuje (je to vstup pro A/B).

**Jak snímek vyrobit (kanonicky, od 2026-10-12):**

```bash
tools/gates/ci-godot.sh                        # v CI i lokálně (Xvfb na Linuxu)
# nebo ručně:
godot --path . --rendering-driver opengl3 --fixed-fps 60 \
      --write-movie .cache/render/chuze/frame.png \
      --script res://tools/gates/snapshot-walk.gd
cp .cache/render/chuze/frame00000150.png .cache/render/snapshot.png
```

**Proč z chůze a proč `--fixed-fps`:** vlastní postavu kreslí hra jen
v některých animacích (v klidu padá na UO art), takže snímek ve stoje nemá
**ani jeden** pixel vlastní postavy a G10 správně hlásí vadu o hře, která je
v pořádku (naměřeno: frame 130 = 0 px, frame 150 = 366 px přesně / 267 po
erozi). Bez `--fixed-fps` není obraz reprodukovatelný (naměřeno na témž stavu:
0,17 % rozdílu s `--fixed-fps`, 3,14 % bez něj u scény bez řidiče, 71 % u běhu
bez `--fixed-fps` s pohybujícími se mobily) — a každé „A/B" by pak měřilo šum.

#### 8.3.2 G20 — smyčka se měří CELÁ, ne po dílech (PŘIDÁNO 2026-10-19)

Naměřeno (session D, 2026-10-11): každá podsoučást měla zelený test — těžba,
tavení, výroba i prodej — a přesto se hráč k **prodeji nedostal**, protože okno
obchodu nemělo přepínač na „sell". Prodej uměla jen sonda, ne hra. Zelené testy
to nechytily, protože volají systémy `sim/` přímo a **cesta hráče v nich není**.

Co G20 dělá:

* `tools/gates/loop_probe.gd` spustí **reálnou scénu** (`app/main.tscn`). Cesty
  jsou dvě a dokumentují se **po jménech**, ne jako jedno slovo „cesta hráče":
  * **COMMAND cesta** (kroky 1–2 a pak požadavky oken): `interact` vyrábí
    **klient** (`app.input_map.interact_command`, stejná cesta jako klávesa E/T)
    a posílá ho `sim.enqueue`; `app.main._process` si vyzvedne požadavek okna a
    pošle `Command{t:"craft"}` / `{t:"vendor"}`.
  * **KLIK** (kroky 3–4): sonda najde **skutečný `Button` uzel** v okně
    („Smer", řádek s výrobkem / řádek receptu, „Potvrdit"), ověří, že má
    připojený signál `pressed` (`get_signal_connection_list`), a **signál vyšle**
    (`pressed.emit()`); **handler se nikdy nevolá přímo** a výsledek se čte
    z okna (`smer()`, `mnozstvi()`, počet řádků). **Mez (naměřeno nezávislou
    re-verifikací 2026-10-19):** sonda **nekontroluje klikatelnost** tlačítka
    (viditelnost, `mouse_filter`, `disabled`, velikost) — na kopii s
    `visible=false` i s `MOUSE_FILTER_IGNORE` brána prošla (`exit 0`).
    Skutečná myš/`InputEventMouseButton` cesta se neměří; je to otevřený bod
    **N1** v `HANDOFF.md`.
  * Sonda **nikdy** nevolá akční systémy `sim/` (`sim.harvest.mine`,
    `sim.craft.smelt`, `sim.vendor.sell`) — jinak by měřila totéž co testy.
    Ze `sim/` sahá jen na `sim.enqueue`, `sim.tick` (tikání) a čtení
    (`sim.vendor.gold_of`).

  **Proč to musí být klik:** první verze sondy volala
  `vendor_gump.nastav_smer/stiskni_radek/stiskni_potvrzeni` přímo a prošla
  i na kopii, kde byl `Button` nahrazen `Label` a handler `_on_smer_pressed`
  smazaný — tedy na **přesně té historické vadě**, kvůli které G20 vznikla
  (naměřeno 2026-10-19 verifikátorem: `exit 0`, `krok prodej: PASS`). Od
  2026-10-19 sonda kliká na uzly, hlásí `tlacitko_*` / `signal_*` a brána
  **bez nich krok nenechá projít**.
* Po každém kroku se měří **důsledek pro hráče**, ne „systém vrátil ok": nová
  zpráva v žurnálu (`ui.journal`) a v ní očekávané slovo **ověřené z TEXTU
  zpráv** (ne z booleana sondy — ten se porovnává s textem a nesoulad je vada),
  inventář (`container.contents` + `Item.type_of`) a zlato (`sim.vendor.gold_of`).
  Naměřeno 2026-10-19: ruda 0 → 8, ingoty 0 → 7, dýka 0 → 1, zlato 60 → 70,
  žurnál 12 → 39 zpráv; každý krok přidal aspoň jednu zprávu.
* Sonda **zvedá skill Mining a Blacksmithy na 1000**. Měří průchodnost smyčky,
  ne balance: s výchozím skillem umí tavení i výroba náhodně selhat („failed")
  a z měření by se stalo měření hodu kostkou (stejná mez jako u
  `sound_probe.gd`).
* `prekryv` (kolize cílů interakce) se **vypisuje, ale nehlídá** — přiznané
  omezení: kdyby se dlaždice překryly, kroky samy spadnou na hodnotách.

Dva režimy (a proč):

* **headless** (CI, `run-all.py`): měří kroky, žurnál a hodnoty. Snímky
  v headless **nejdou** — naměřeno 2026-10-19: `root.get_texture().get_image()`
  vrátí `null` (`ERROR: Parameter "t" is null`) a `save_png` nemá co uložit.
  Brána to napíše (`snímky: NEMĚŘENO (headless)`), nikdy netvrdí úspěch.
* **`--snimky`** (vizuální důkaz): spustí sondu **v okně**
  (`--rendering-driver opengl3 --resolution 1280x720`). Sonda umí uložit
  3–4 PNG (jeden po každém kroku); brána **vyžaduje alespoň `MIN_SNIMKU = 2`**
  a kontroluje existenci, > 10 kB, platnou hlavičku PNG, rozměr ≥ 320×200
  a **aspoň dvě různé velikosti** (jinak je to jeden a týž obraz). Když je
  `--snimky` žádáno, musí sonda vykázat `snimky_zadany:true`, prázdné
  `snimky_chyba` a ≥ 2 PNG — jinak je to **VADA** (fail-closed); dřív stačilo,
  že sonda adresář nevytvořila a sama sebe umlčela (`.tmp/g20-d3-*`). Snímky se
  ukládají mimo git (`.tmp/` nebo `.cache/`).

Mutační důkaz (`python tools/gates/check-loop.py --mutace`): vytvoří **kopii
projektu s hardlinky** (data se nekopírují) a v ní zanese vadu. **Tři sabotáže:**

1. `return _fail(...)` na začátku `sim.vendor.sell`,
2. `return _fail(...)` na začátku `sim.harvest._harvest`,
3. **historická vada** (nová 2026-10-19): v `ui/vendor_gump.gd` a
   `ui/craft_gump.gd` se `Button` nahradí `Label` a smažou se handlery
   (`_on_smer_pressed` i `pressed.connect(...)`) — sonda, která kliká na
   skutečné uzly, to musí vidět (`exit 1`). Skript po zápisu vady **ověří, že
   se opravdu zapsala** (tichá mutace tvrdí totéž co úspěšná).

Naměřeno 2026-10-19: **všechny tři sabotáže daly `exit 1`**. Offline
`--self-test` má 15 případů (známý správný i známý vadný vstup, včetně
„boolean tvrdí slovo, text ho nemá", „tlacitko existuje, signal chybí"
a „snímky se nevykázaly") a `run-all.py --self-test` ho pouští spolu
s ostatními branami.

## 8.4 CI vs. lokálně (a co v CI není)

| Věc | Lokálně | V CI |
|---|---|---|
| Instalace UO | **je** | **není** → G6 a extraktor se **přeskočí s viditelnou poznámkou** |
| Godot | `--headless --script` | totéž, ale s přesměrovaným `APPDATA` (§2.1) |
| `.godot/` import cache | je | **není** → před testy spustit import, jinak „regresují" assety (P8) |
| Snímek hry | `read_image` | `vision.mjs` (Gemini klíč v secrets), `exit 1` běh nezhodí |
| Blender | je | není → render spritů se dělá lokálně a commituje |

**Pravidlo:** „v CI to nejde" není důvod k tichému přeskočení. Brána vypíše
`SKIP: assety nejsou v CI, kontrola NEPROBĚHLA` a v souhrnu to je vidět.

## 8.5 Lidská kontrola (a proč ji nejde nahradit)

| Co | Jak |
|---|---|
| Je to ta postava? Je vidět zbraň? Nevypadá krajina jako šum? | `read_image` (v session) / `vision` (v CI) |
| Sedí styl? Není sprite useknutý? | totéž; brána to nepozná |
| Je město na svém místě (Britain 1495,1630)? | snímek porovnaný s očekáváním |

**Cache schválených snímků** (baseline) je užitečná, ale má dvě pasti
(naměřeno): percepční hash je **slepý na barvu** a **degeneruje u jednolitého
obrázku** → ukládej i barevný podpis a při degeneraci porovnávej `sha256`.
A pozor: cache platí jen pro obrázky **uvnitř repa** — v CI se modelu posílá
vždy (což je správně).

## 8.6 Zakázané podoby brány (katalog, každá naměřená)

| Podoba | Příklad | Čím to nahradit |
|---|---|---|
| Ptá se na **přítomnost** | `_check(n.has_method("gather"), …)` | zavolej a měř výsledek |
| **Tiše přeskočí** | `if load(path) != null:` | nepodmíněná kontrola, nebo viditelný „čeká se" stav |
| **Zelená nad prázdnem** | regexy nenašly nic → cyklus nad `[]` | „NEMĚŘENO" = vada |
| **Čte komentáře** | našel zakázaný vzor v komentáři, který ho popisuje | odstranit komentáře před hledáním |
| **Statická metrika místo běhu** | počet testů spočítaný ze zdrojáku (42) vs. skutečný běh (36) | čti výsledek běhu |
| **Měří jinou otázku** | „soubor existuje" místo „funkce funguje" | formuluj kontrolu jako tvrzení o chování |
| **Zelená nad nulou souborů** | `check-wiring` bez `scripts/*.gd` → „vše v pořádku", `exit 0` | když je měřených objektů 0, selž |

## 8.7 Formát výstupu brány

Každá brána vypíše **lidský souhrn** a zapíše **strojový JSON**:

```
[G5 check-content] PŘEDMĚTŮ: 312, RECEPTŮ: 1150 (dostupných 640), MONSTER: 88
[G5 check-content] CHYBY: 3
   - recipes.json: recept 412 odkazuje na materiál 0x1BEF, který není v items.json
   - items.json: předmět "katana" nemá art v manifestu (tile 0x13FE)
   - C4 NESPLNĚNO: dostupných receptů 118 < 600
EXIT 1
```
```json
{"gate": "check-content", "measured": {"items": 312, "recipes": 1150,
 "recipes_available": 640, "monsters": 88}, "errors": [ ... ], "skipped": []}
```

## 8.8 Mutační testy bran (povinné)

Postup: **vrať vadu** do kopie projektu, spusť bránu, ověř, že **spadne**.
Když nespadne, brána je slabá — oprav bránu, ne test.

| Brána | Záměrná vada | Musí nastat |
|---|---|---|
| G1 | změň `ISO_STEP` na 23 v `const.gd` | chyba „nesedí s TILE_W/2" |
| G2 | přidej `Input.` do `sim/systems/movement.gd` | chyba „sim nesmí používat Input" |
| G14 | přidej do `sim/` členský `var koef: float` a vlož ho do `state()` | chyba „je float A VSTUPUJE DO STAVU" |
| G14 | použij v `sim/` `Vector2(` místo `Vector2i(` | chyba „float vektor v sim/" |
| G3 | rozbij `swing_delay_ms` (vrať 0) | selhání testu boje |
| G4 | odpoj `_on_use_pressed` od signálu | chyba „handler není připojen" |
| G5 | smaž položku z `items.json`, na kterou odkazuje recept | chyba „neplatný odkaz" |
| G6 | v manifestu uveď neexistující stránku atlasu | chyba „stránka chybí" |
| G7 | po načtení neobnov `rng_state` | rozdílný hash |
| G8 | použij `randf()` v `sim/craft.gd` | rozdílný hash mezi běhy |
| G10 | nastav všem dlaždicím `z_index` nad postavou | chyba „postava není vidět" |
| G11 | zavolej Godot 3 API (`margin_left`) | `SCRIPT ERROR` |
| G20 | vypni `sim.vendor.sell` (early `return _fail(...)`) — dělá `check-loop.py --mutace` | „krok prodej neprošel", „zlato se nezvýšilo", „dýka zůstala v batohu" |
| G20 | vypni `sim.harvest._harvest` (early `return _fail(...)`) — dělá `check-loop.py --mutace` | „krok tezba neprošel", „v žurnálu není 'gather'" |
| G20 | **historická vada**: v oknech `Button` → `Label` a smaž handlery (`_on_smer_pressed`, `pressed.connect(...)`) — dělá `check-loop.py --mutace` | „v okne obchodu neni Button 'Smer'", „prepinac 'Smer' neni kliknute skutecne tlacitko", `exit 1` |
| G20 | `--snimky` v headless (sonda snímky nevykáže) | „snimky: pozadovany, ale sonda hlasi snimky_zadany=false", `exit 1` |
| každá | **odeber vstup** (smaž soubor, vyprázdni seznam) | `NEMĚŘENO` + nenulový exit |

## 8.9 Co znamená „zelená"

Zelená je **jen** tehdy, když platí všechny tři věci:

1. brána **proběhla** (má nenulový počet měřených objektů),
2. **neselhala**,
3. její **mutační test** prokazatelně spadne (tj. brána má zuby).

Když chybí kterýkoli bod, výsledek se hlásí jako **NEMĚŘENO** — a to není
úspěch, to je otevřená práce.
