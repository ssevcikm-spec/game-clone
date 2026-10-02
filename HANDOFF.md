# Předání — UO-klon (stav po 13 commitech)

> Tento soubor je pro **další session agenta**. Všechno podstatné je v repu
> a v `git log`; tady je jen to, co by jinak stálo hodiny znovuobjevování.
> Datum: 2026-10-02. Větev `main`, strom čistý, 241 souborů v gitu.

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| Projekt | `E:\Workspaces\game-clone` (git, `main`, 13 commitů) |
| Testy | `godot --headless --path . --script res://tests/run_tests.gd` → **222 kontrol / 0 selhání** |
| Brány | `python tools/gates/run-all.py` → **8 měří / 3 NEMĚŘENO / 0 chyb** |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → 10 bran, 0 chyb |
| Self-testy extrakce | `python tools/uoextract/<nástroj>.py --self-test` → 60/60 celkem |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` (viz past 1) |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` (101 granul; hotovo ~26, zbytek M1–M8) |

## Co je hotové a ověřené (ne „soubor existuje")

bootstrap 4 · W0 8 (const, iso, rng, clock, events, hash, serial, balance) ·
M0 5 (sim.commands, sim.world_loop, app.input, app.loop, app.main) ·
M1 6 (uop, tiledata, art, gump, worldmap, hues, textdata, cliloc) ·
M2 3 (world.doors, world.stairs, entity.stats).

Extrakce funguje nad skutečnou instalací: art (land 4244 dlaždic × přesně 1012
pixelů), gump (5579 záznamů, BWT), mapa (29 360 128 dlaždic, statiky 20 386 415 B),
hues (1000/1000), textdata (37/19/58/6), cliloc (124 433 záznamů).

## Další kroky (v tomto pořadí)

1. **`assets.anim`** — změřit pokrytí těl v `anim*.mul` vs `AnimationFrame*.uop`
   a rozhodnout zdroj (docs/03 §3.5.1, O3). Rozhoduje měření, ne dokument.
2. **`data.items`** — katalog podle **vlastností** (v této instalaci NEJSOU
   klasická jména: `gold`, `bandage`, `iron ingot`, `log` neexistují; z 113
   dokumentovaných jmen jich je 79). Musí mít `source` u každé položky.
3. **`world.time`**, **`world.tiledata`**, **`world.map`**, pak `render.*`
   (tím se zapne G6 a G10, které jsou teď NEMĚŘENO).
4. **`assets.atlas`** (manifest) — bez něj je G6 slepá.

## Jak to dělat (a co se už osvědčilo)

- **Každou granuli ověřit měřením**: spustit funkci, dostat konkrétní hodnotu.
  „Soubor existuje" nestačí — u `assets.tiledata` existovala sonda, která měla
  25 % dat a žádné smluvní API, a Fronta ji počítala za hotovou.
- **Dívat se na obrázky** (`read_image`): pruhovaný náhled Britainu odhalil dvě
  chyby v zadání, které čísla neodhalila.
- **Nepřítomnost věci není vada nástroje**: 364 chybějících artů a 34 prázdných
  gumpů jsou vlastnosti dat, ne chyby dekodéru. Počítej je zvlášť.
- **Mutační test u každé brány** (vlož vadu → musí spadnout). Hotové příklady:
  `ISO_STEP=23`, rozbitý posun v RNG, `Input.` v `sim/`, Godot 3 API,
  `rng_state` bez převodu na řetězec.

## Pasti, které už někoho stály čas (naměřené)

1. **Godot spuštěný z `C:\...\orchestra\tools\godot` NEMŮŽE ZAPISOVAT** — sandbox
   ho blokuje a Godot přitom u `res://`/`user://` lže `err=0`. Řešení: **kopie
   ve workspace** (`.cache/godot/`, 172 MB, gitignore); brány si ji samy připraví
   (`gate_common.godot_bin()`). Bez toho nejdou G7/G10/G13.
2. **`JSON.parse_string` vrací VŠECHNA čísla jako `float`.** U ukládání to tiše
   poškodilo int64 stav RNG (`…107324 → …107264`), v `world.doors`/`world.stairs`
   to zahodilo všechny řádky (0 kategorií, bez chyby). Vždy `int()`; hodnoty
   > 2^53 ukládat jako řetězec.
3. **`.gitignore` je na Windows case-insensitive** — vzor `Cliloc.*` pohltil
   `tools/uoextract/cliloc.py`. Soubor existoval, testy procházely, ale **v gitu
   nebyl** („nothing to commit"). Kontroluj `git ls-files`, ne `Test-Path`.
4. **`Measure-Object -Line` nepočítá prázdné řádky** (62 vs 74 u téhož souboru).
   Počty řádků měř Pythonem.
5. **`class_name` je známý jen přes cache importu** (`.godot/global_script_class_cache.cfg`)
   — v čerstvém stromu spadne parse. Brány si import samy zajistí.
6. **`PackedInt32Array` nejde použít jako `const`** a **`Input.get_mouse_position()`
   v Godotu 4 neexistuje** (pozici myši dává viewport).
7. **Mutační důkaz na necommitnutém souboru nic nevrátí** — `git checkout` u
   netrackovaného souboru tiše neudělá nic. Mutuj až po commitu.
8. **Godot zapisuje do klonů v `_src/`/`research/refs/` při importu** — pomáhají
   `.gdignore` v těch složkách (už zavedeno).

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03` §3.4 — index bloku mapy**: správně je `bx * blocks_y + by`
   (x-major), ne `by * blocks_x + bx`. `MapLoader.cs:623`.
2. **`docs/03` §3.4 — záznam statiky**: je `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`
   (7 B), ne `[u16][u16][u16][i8]`. `StaticsBlock` v ClassicUO.
   (Při špatném čtení vycházejí „souřadnice" 251, 513…)
3. **`docs/03` §3.4 — Britain**: blok (1495,1630) má **60** statiků (ne 20);
   v okolí ±6 bloků 9 329 statiků. Vodní dlaždice: id 168,169,170,171,310,311.
4. **`docs/03` §3.5.4 — R1**: uzavřeno měřením. `create_hash` (ClassicUO) pokrývá
   **43 760/43 760** záznamů archivu; varianta `(pc<<32)|pb` 0/43 760.
   Dokumentovaných „1636/2000" je **jiné počítadlo** (indexy, ne záznamy):
   364 chybějících artů v této instalaci není.
5. **`docs/03` §3.5.4 — R2**: „zlib stačí" NEPLATÍ — všech 5 579 gumpů má flag 3
   (zlib + BWT); bez BWT se nerozbalí ani jeden.
6. **`docs/03` §3.5.4 — R3**: 112 chunků je plných (458 752 bloků = přesně celý
   svět) + 113. chunk má 1 blok navíc.
7. **`docs/03` §3.3.1 — „LAND blok: offset 4"**: je to offset prvního *záznamu*
   (za hlavičkou první skupiny), ne začátek bloku.
8. **`.forge/roadmap.json` (generátor)**: `sim.world_loop` má deklarováno
   `<= 60 / any`, ale jeho vlastní prompt říká „size_lines > 60 → model strong";
   soubor má ~192 neprázdných řádků. Podobně přesahují `sim.commands` (118),
   `app.input` (89). Buď uvolnit deklarace, nebo granule rozdělit.
9. **`app/main.tscn` nemá vlastníka** v roadmapě (založil ho bootstrap).

## Prostředí a konvence

- Kód píšu česky v komentářích, identifikátory anglicky (docs/02 §2.6.8).
- Píšu **jen do `owns` své granule**; `tests/`, `tools/gates/`, `project.godot`,
  `.forge/`, `docs/` needituju (výjimkou byly bootstrap granule a `.gitignore`).
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py` vrací 0 = vše změřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není
  zelená). `--strict` dělá z NEMĚŘENO vadu (pro M8).
