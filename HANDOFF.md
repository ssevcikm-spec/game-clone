# Předání — UO-klon (stav po naměření `assets.anim`)

> Tento soubor je pro **další session agenta**. Všechno podstatné je v repu
> a v `git log`; tady je jen to, co by jinak stálo hodiny znovuobjevování.
> Datum: 2026-10-03 (předchozí verze byla ze 2026-10-02 a v číslech zastarala).

## Kde co je

| Věc | Cesta / příkaz |
|---|---|
| Projekt | `E:\Workspaces\game-clone` (git, `main`) |
| Testy | `godot --headless --path . --script res://tests/run_tests.gd` → **238 kontrol / 0 selhání** |
| Brány | `python tools/gates/run-all.py` → **9 měřeno / 2 NEMĚŘENO / 0 chyb** (exit 2 = něco neměřeno) |
| Self-testy bran | `python tools/gates/run-all.py --self-test` → 10 bran + **9 extrakčních nástrojů** |
| Godot (binárka) | **KOPIE ve workspace**: `.cache/godot/Godot_v4.7.2-stable_win64_console.exe` |
| Python | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` |
| Instalace UO | `D:\Games\Electronic Arts\Ultima Online Classic` (jen čtení) |
| Roadmapa | `.forge/roadmap.json` (101 granul; `done` je u všech `false` — stav se pozná jen měřením) |

## Co je hotové a ověřené (ne „soubor existuje")

bootstrap 4 · W0 8 · M0 5 · M1 8 (**uop, tiledata, art, gump, worldmap, hues,
textdata, cliloc**) · M2 4 (world.doors, world.stairs, entity.stats, world.time) ·
**assets.anim 1 (rozhodnutí o zdroji + extraktor)**.

## `assets.anim` — co je hotové a co NE (přečti, než na tom začneš stavět)

Měření a rozhodnutí: **`research/anim-mereni.md`** (surová data
`research/anim-pokryti.json`, reprodukce `research/probe/anim_pokryti.py`).
Nástroj `tools/uoextract/anim.py` (22 kontrol `--verify`, 18 `--self-test`).

**Rozhodnutí o zdroji (měřeno, ne opsané z dokumentu):** dokument radil
„UOP, MUL jen fallback" — **měření to vyvrací**. Těla se téměř nepotkávají:

| Zdroj | Těl | Akcí | Co v něm je |
|---|---|---|---|
| `anim*.mul` | 270 | 7 144 | monstra, zvířata, **lidé 400+ (175 bloků na tělo)** |
| `AnimationFrame*.uop` | 318 | 10 989 | nová těla 400+ (282), gargoyle |
| průnik | **2** (826, 990) | — | — |

Tělo 400 (hráč) a 401 mají v MUL 35 akcí × 5 směrů, v UOP **nula** → MUL je
povinný. Pravidlo: **blok v MUL → MUL, jinak UOP** (jako ClassicUO/UOFiddler).

**Co je ověřené:** sloty v `anim.idx` (148 810 slotů; prázdný slot = `-1,-1,-1`);
tabulka framů = `[u32 počet]` na bajtu 512 + offsety od 516; terminátor RLE
`0x7FFF7FFF` 4 B před koncem framu; jméno UOP záznamu
`build/animationlegacyframe/{tělo:06d}/{akce:02d}.bin` + hash `create_hash`
(4 747 nálezů; `jenkins_pc_pb` 0); **prvních 512 B bloku je ve VŠECH blocích
stejných** → pixely těl nemají vlastní paletu (barva jde z `animdata`/`hues`).

**Co ověřené NENÍ (a co z toho plyne):** tvar hlavičky framu a kódování indexů
v RLE proudu. `x` z hlavičky běhu vychází 1020–1023, tedy mimo rozměr framu
(24×64). **Pixely těl se proto neextrahují** a `anim.py` je záměrně nevyrábí.
Kdo staví `assets.atlas` nebo `render.anim`, staví na **otevřené otázce** —
ne na hotovém dekodéru. 18 z 7 162 bloků má navíc jinou tabulku framu (offsety
nerostou / rozměr 0×0); nástroj je přeskočí a je to vidět v `--verify`.

## Další kroky (v tomto pořadí)

1. **Pixely animací** — dorazit hlavičku framu a kódování indexů (viz výše).
   Je to **blokátor pro `assets.atlas`** v části `anim`.
2. **`data.items`** — katalog podle **vlastností** (v této instalaci NEJSOU
   klasická jména: `gold`, `bandage`, `iron ingot`, `log` neexistují). Každá
   položka musí mít `source`.
3. **`world.tiledata`**, **`world.map`**, pak **`render.*`** (tím se zapne G10,
   které je teď NEMĚŘENO) a **`assets.atlas`** (bez něj je G6 v části atlasu slepá).

## Jak to dělat (co se osvědčilo)

- **Každou granuli ověřit měřením**; „soubor existuje" ani `done: true`
  v roadmapě nic neznamená.
- **Dívat se na obrázky** (`read_image`) — u animací to bylo poprvé, co se
  měření a realita rozešly (rozměry framu seděly, pixely ne).
- **Když se dvě měření rozcházejí, hledej, čím se liší** — ne které je „správné".
- **Mutační test u každé brány** (vlož vadu → musí spadnout).

## Pasti, které už někoho stály čas (naměřené)

1. **Godot z `C:\...\orchestra\tools\godot` NEMŮŽE ZAPISOVAT** (sandbox) a přitom
   lže `err=0`. Řešení: kopie ve workspace (`.cache/godot/`, gitignore);
   brány si ji připraví (`gate_common.godot_bin()`).
2. **`JSON.parse_string` vrací VŠECHNA čísla jako `float`** — u int64 stavu RNG
   to tiše poškodilo data. Vždy `int()`; hodnoty > 2^53 jako řetězec.
3. **`.gitignore` je na Windows case-insensitive** — vzor `Cliloc.*` pohltil
   `tools/uoextract/cliloc.py`. Kontroluj `git ls-files`, ne `Test-Path`.
4. **`class_name` je známý jen přes cache importu** (`.godot/global_script_class_cache.cfg`).
5. **`Measure-Object -Line` nepočítá prázdné řádky** — počty řádků měř Pythonem.
6. **Brána, která nic nezměří, není zelená** — `run-all.py` vrací 2 = NEMĚŘENO.
7. **Zápis „mezi tím" do souboru, který čte jiný běh, vypadá jako změna souboru**
   — `write` pak odmítne zápis; soubor znovu přečti a zapiš znovu.
8. **U nové pasti: zapiš ji sem i do `research/`** — příští session ji jinak
   objeví znovu (starý HANDOFF tvrdil „13 commitů / 241 souborů", obojí jinak).

## Vady ZADÁNÍ, které je potřeba opravit (agent je needituje)

1. **`docs/03` §3.4 — index bloku mapy**: správně je `bx * blocks_y + by`
   (x-major), ne `by * blocks_x + bx`. `MapLoader.cs:623`.
2. **`docs/03` §3.4 — záznam statiky**: `[u16 tile][u8 x][u8 y][i8 z][u16 hue]`
   (7 B), ne `[u16][u16][u16][i8]`.
3. **`docs/03` §3.4 — Britain**: blok (1495,1630) má **60** statiků (ne 20).
4. **`docs/03` §3.5.4 — R1/R2/R3**: uzavřeno měřením (`create_hash` 43 760/43 760;
   všech 5 579 gumpů má flag 3 = zlib **+ BWT**; 112 chunků = celý svět).
5. **`docs/03` §3.3.1 — „LAND blok: offset 4"**: je to offset prvního *záznamu*.
6. **`docs/03` §3.5.1 — doporučení „UOP, MUL jako fallback"**: **naměřeno obráceně**
   (viz `research/anim-mereni.md`); text v `docs/03` je už opravený a
   `research/05-data-formats.md` §5.2 má místo variant výsledek měření.
7. **`.forge/roadmap.json` (generátor)**: `sim.world_loop` deklaruje `<= 60`, ale
   má ~192 řádků; podobně `sim.commands` (118) a `app.input` (89).
   **Nově naměřeno: `assets.anim` deklaruje `<= 150`, soubor má 451 řádků**
   (`tools/uoextract/anim.py`, počítáno Pythonem). Buď deklaraci uvolnit, nebo
   granuli rozdělit — teď je to stejná vada jako u `sim.world_loop`, jen větší.
   Nástroj je záměrně „učebnicový" (komentáře nesou naměřená čísla), takže
   dělení na `anim.py` + `anim_uop.py` by šlo bez ztráty.
8. **`app/main.tscn` nemá vlastníka** v roadmapě.

## Prostředí a konvence

- Kód česky v komentářích, identifikátory anglicky (docs/02 §2.6.8).
- Píšu **jen do `owns`** své granule; `tests/`, `tools/gates/`,
  `project.godot`, `.forge/`, `docs/` needituju (výjimkou jsou bootstrap granule).
- `python tools/check-docs-refs.py`, `check-zadani.py`, `roadmap-gen.py --check`
  musí procházet (exit 0) — po každé změně spustit.
- `run-all.py` vrací 0 = vše změřeno, 1 = vada, **2 = něco NEMĚŘENO** (to není
  zelená). `--strict` dělá z NEMĚŘENO vadu (pro M8).
