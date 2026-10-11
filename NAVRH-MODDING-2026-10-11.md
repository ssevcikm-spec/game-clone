# Návrh: modifikovatelná a rozšiřitelná hra (2026-10-11)

> **Co je tenhle soubor:** **NÁVRH + PLÁN** (ne stav projektu). Stav je
> v [`HANDOFF.md`](HANDOFF.md); tohle říká, **co je potřeba udělat, v jakém
> pořadí a proč**, a co z toho už hotové je.
>
> **Zadání:** [`DALSI-SESSION.md` §E](DALSI-SESSION.md) („švy, stabilní ID,
> pořadí načítání, verzované ukládání, sandbox skriptů").
> **Rozhodnutí, ze kterého to vychází:**
> [`ROZHODNUTI-2026-10-09-SMER.md`](ROZHODNUTI-2026-10-09-SMER.md) §3
> („modifikovatelnost dnes CHYBÍ") a §6.6 („až se rozhodne, co to znamená…
> je to samostatné zadání, protože mění smlouvy").
>
> **Datum spotřeby:** je to plán — **platí, dokud se kroky neprovedou.**
> **Touto session (2026-10-11) byl proveden krok S1** (§5). Kroky S1b a S2–S6
> jsou **PLÁN**: nic z nich není hotové a nic z nich se nesmí číst jako hotové.
> Kde je napsané číslo, je u něj i postup, kterým vzniklo.
>
> **Co tenhle dokument NEDĚLÁ:** nerozhoduje o prioritách za uživatele,
> nezapisuje nové granule do `.forge/roadmap.json` (`docs/07` §7.1 bod 5)
> a nepřidává brány (počet bran je součást smlouvy, `docs/08`).

---

## 1. Co je dnes naměřeno (a čím)

| Co | Hodnota | Jak to bylo změřeno |
|---|---|---|
| Testy | **2751 kontrol / 0 selhání**, 87 case souborů | `godot --headless --path . --script res://tests/run_tests.gd` (před touto session: 2696/0, 86) |
| Brány | **15 měřeno / 0 chyb** (G13 poradní) | `python tools/gates/run-all.py` |
| Replaye | **2/2 zelené, hashe se NEMUSELY přepnout** | tamtéž, `G9 check-replay` |
| Save: verze obálky | **`SAVE_VERSION = 2`**, `migrate()` umí 1→2, **novější verze se odmítne** | čteno v `sim/save.gd` (`SAVE_VERSION`, `migrate`) |
| Save: vztah k obsahu | **„všechno, nebo nic"**: `data_version` je hash dat a `load()` při rozchodu odmítne | `sim/sim_world.gd` (`data_version`, `load`) |
| Zadrátované cesty k datům | **18 produkčních `.gd`** má literál `res://data/*.json`; z toho **27 modulových konstant** a **17 literálů v `app/main`** | `_analyza/p59-kotvy-dat.py` (viz metoda níž) |
| Datové soubory | v kódu zmíněno **15** souborů, na disku **18**; **2 zmíněné na disku NEJSOU** (`data/poison.json`, `data/regions.json`) | tamtéž |
| Sev pro mody | **neexistoval** — žádný modul neodpovídal na „která vrstva vyhrává" | `sim/content.gd` vznikl touto session (§5) |

**Metoda k číslům o cestách** (bez skriptu, kdyby `_analyza/` nebyl po ruce):
projdi všechny `.gd` (walk, **ne** `grep` tool — ten z rodiče přeskakuje skryté
složky), **odstraň komentáře** (`#…`), pak hledej
`"res://data/<něco>.json"`. Kdo hledá i v komentářích, najde vadu, která
v kódu není (`docs/08 §8.1.3`). `_analyza/` je v `.gitignore`, takže skript
`p59` v repu není — metoda je proto tady.

**Druhé měření (kolik z těch konstant je přebitelných):**
`_analyza/p65-konstanty-param.py` hledá konstantu **uvnitř signatury funkce**
(napříč řádky). Vyšlo **17 konstant jako default parametru** (volající je může
přebít) a **11 čtených přímo**, z toho 2 v `app/main` jsou dnes vědomě
„základní fallback" (proto 9 modulových konstant zůstává nepřebitelných).
⚠ **První verze toho měření hledala konstantu na jednom řádku s `(` a u pěti
modulů hlásila „čte se přímo", i když šlo o default parametru** — statická
metrika, která nic nespustí, dělá falešné pozitivy. Opraveno hledáním přes
celou signaturu; číslo výše je z opravené verze.

---

## 2. Co to slovo znamená: pět vlastností a kde dnes chybí

`SMER` §3 vyjmenovává pět věcí. Tady je každá přeložená do kódu **a změřená**:

| Vlastnost | Co to v kódu znamená | Stav dnes | Kde je šev |
|---|---|---|---|
| **švy** | jedno místo, které odpovídá „odkud se bere obsah", místo cest zapečených v modulech | **27 konstant** zapečených, 17 literálů v `app/main` rozházených po voláních | **S1 ✅** `sim/content.gd` + `app/main._cesta()` |
| **stabilní ID** | (a) ID **zdroje** obsahu, (b) ID **záznamu** (předmět, monstrum, recept) | zdroj ID neměl; záznam má dnes `tile` = **art z UO**, ne naše ID | **S1 ✅** (zdroj), **S3** (záznam) |
| **pořadí načítání** | kdo vyhraje, když totéž poskytují dvě vrstvy — a je to **vyřčené**, ne náhodné | neexistovalo | **S1 ✅** (`order` + `id` jako rozhodčí) |
| **verzované ukládání** | save nese identitu obsahu, ze kterého vznikl | **obálka verzovaná JE** (v2 + migrace), ale vůči obsahu je save „všechno, nebo nic": instalace modu zneplatní **všechny** save soubory | **S2** (staví na S1) |
| **sandbox skriptů** | mod smí spustit vlastní logiku, ale nesmí sáhnout, kam nemá | **žádné skripty modů neexistují** — a Godot GDScript **sandbox nemá** (skript běží s plnými právy) | **S5** — a je to **rozhodnutí uživatele** (§6) |

**Co z toho plyne:** „verzované ukládání" není v projektu nula — je hotová
*obálka*. Chybí **identita obsahu**: save dnes neumí říct „byl jsem sehrán
s těmito vrstvami", takže jakákoli změna dat (i mod, který nic nepřebíjí)
udělá ze všech save souborů nečitelný soubor. To je přesně to, co modderovi
vadí, a je to jiná věc než `SAVE_VERSION`.

---

## 3. Pořadí, v jakém to má smysl dělat (a proč právě tak)

Pořadí **není** podle ceny, ale podle **závislostí**:

1. **S1 — vrstvy obsahu a ID zdroje** (hotovo). Bez toho, aby existovalo
   „co je načtené a v jakém pořadí", se nedá napsat ani manifest do save,
   ani rozhodnout, kdo vyhrál.
2. **S1b — dopnout zbytek modulů** na cesty z vrstev (9 konstant). Levné,
   ale nutné: jinak mod funguje u `balance.json` a ne u `items.json` — tedy
   **funguje zdánlivě**, což je nejhorší varianta.
3. **S2 — verzované ukládání vázané na identitu obsahu.** Save zapíše
   `manifest()` (co bylo načtené) a load při rozchodu pojmenuje **co** chybí
   nebo má jinou verzi. Stojí na S1 (manifest) a mění smlouvu `docs/04 §4.7`,
   takže potřebuje zápis v `docs/` a **rozhodnutí uživatele** (§6).
4. **S3 — ID záznamů a slučování.** Aby mod mohl **přidat** předmět nebo
   monstrum, potřebují záznamy stabilní string ID (dnes `tile` = art UO)
   a musí být rozhodnuto, co se stane při kolizi. Tohle je **největší** krok
   a mění datové smlouvy — proto patří uživateli zadat.
5. **S4 — ostatní druhy obsahu** (art, animace, zvuky, mapy). Vlastní art už
   svůj šev MÁ (`assets/own-art.json` + `render/own_art.gd`), ale je to jiný
   mechanismus než vrstevní; sjednotit je má smysl až po S3.
6. **S5 — sandbox skriptů.** Poslední **schválně**: bez S1–S3 není co
   spouštět, a hlavně — *čím* mod píše, je rozhodnutí, které mění celý
   kontrakt (viz §6 bod 3).

---

## 4. Kroky S1b–S6 (co, hotovo když, co to NEDÁ)

### S1b — dopnout 9 modulových konstant na cesty z vrstev

**Co:** `sim/entity/item.gd`, `sim/entity/skills.gd`, `sim/systems/craft.gd`
(2×), `sim/systems/interaction.gd`, `sim/systems/skill_gain.gd`,
`sim/world/doors.gd`, `sim/world/stairs.gd`, `sim/world/tiledata.gd` čtou
cestu přímo z konstanty. Vzor je už hotový: modul dostane cestu jako
**parametr konstruktoru** (jako `sim.systems.combat`) a rozhoduje `app/main`.

**Hotovo, když:** měření `p65` hlásí **0 konstant čtených přímo** (mimo
`sim/content.gd`, kde je deklarace) a **pro každou z nich existuje test, který
soubor vezme z jiné cesty než z konstanty**.

**Co to NEDÁ:** mod pořád jen **přebíjí celý soubor**; přidávat záznamy neumí.

### S2 — verzované ukládání vázané na identitu obsahu

**Co:** save nese `content` = `manifest()` (+ `format_version`); `load()`
porovná:
* vrstva, která byla při uložení a je `required` a dnes chybí / má jinou
  verzi → **odmítnout a pojmenovat ji**,
* vrstva navíc (mod přidaný později) → **povolit s hlášením** (aditivní mod
  nesmí zneplatnit rozehráno hru),
* `data_version` (hash) zůstává jako **druhá, přesnější zpráva** — dnes
  odmítá; návrh: hlásit **jmenovitě**, co se změnilo (což hash neumí).

**Hotovo, když:** testy měří všechny tři větve (chybí / jiná verze / navíc)
a **round-trip s modem** dá stejný `state_hash`; `docs/04 §4.7` je
aktualizovaná **a je u ní záznam, že se smlouva změnila a proč**.

**Co to NEDÁ:** neumí sloučit dva save soubory ani zachránit save, ze kterého
zmizel záznam, na který odkazuje stav světa (to je S3).

### S3 — stabilní ID záznamů a slučování

**Co:** dát záznamům v `data/*.json` stabilní string ID nezávislé na artu
(např. `recipe:iron_dagger`), rozhodnout **kolizní pravidlo** (mod přebíjí /
mod přidává / chyba) a naučit loader **slučovat seznamy**, ne jen přebíjet
soubor.

**Hotovo, když:** mod v `user://mods` přidá **jeden recept a jedno monstrum**
a hra je použije, aniž by se změnil `state_hash` bez modu; a je změřené, co
se stane při kolizi ID.

**Co to NEDÁ:** nevyřeší závislosti mezi mody (mod A potřebuje mod B) —
to je samostatné téma, které je lepší **odmítnout** než tiše ignorovat.

### S4 — ostatní druhy obsahu

**Co:** vrstevní i pro `assets/` (art, animace, zvuky) a `maps/`, se stejným
`order` a ID. Dnes má vlastní art vlastní seam — dva mechanismy pro jednu věc
jsou dluh.

**Hotovo, když:** existuje jeden `order` a jeden manifest pro **oba** druhy
a `G6`/`G15`/`G16` to vidí (brány se mění = uživatel).

### S5 — sandbox skriptů (rozhodnutí, ne úkol)

**Co:** dnes mod = **soubor**, ne kód. Kdyby měl mod spouštět logiku, jsou
tři cesty (a žádná není zdarma):

| Varianta | Co to znamená | Cena / riziko |
|---|---|---|
| **(a) žádné skripty** — jen data | mod umí obsah, ne chování; rozšíření = nová data + naše pravidla | **nejnižší**, a dnes už takhle funguje S1 |
| **(b) whitelist DSL** přes `Expression` | mod píše výrazy v omezené sadě funkcí, hra je vyhodnocuje | střední; „whitelist" se musí **vynutit** (Godot `Expression` umí i volání metod) |
| **(c) externí proces / protokol** | mod běží mimo hru a komunikuje přes rozhraní | vysoká; řeší bezpečnost, ale přidává proces a latenci |

**GDScript v Godotu 4 sandbox nemá** — „spustit cizí `.gd` bezpečně" není
konfigurace, kterou by šlo zapnout. Proto je S5 **rozhodnutí uživatele**
(§6 bod 3), ne implementační detail.

### S6 — dokumentace pro moddera + brána, která mod schválně rozbije

**Co:** `docs/` návod „jak napsat mod" (co je stabilní, co se nesmí, jak
poznat chybu), ukázkový mod v repu a **brána**, která spustí úmyslně rozbitý
mod a ověří, že se hra **ozve** a nespadne.

**Hotovo, když:** člověk, který hru nezná, napíše mod podle dokumentace
a pozná z výstupu, proč mu nefunguje. Nová brána = změna smlouvy → uživatel.

---

## 5. Co je hotové touto session (S1) — naměřeno

**Co se udělalo:** vznikl modul **`sim/content.gd`** (vrstvy obsahu: stabilní
ID, vyřčené pořadí, rozlišení souboru) a hra ho **opravdu používá**:

| Věc | Kde | Naměřeno |
|---|---|---|
| Vrstvy obsahu | `sim/content.gd` (nový) | `add()`, `path_for()`, `path_or_default()`, `providers()`, `missing_files()`, `manifest()`, `manifest_hash()`, `discover()`, `report()`; chyby **seznamem**, ne výjimkou |
| Deklarace základu | `data/content-layers.json` (nový) | **1 vrstva `base`, `order 0`, `required`, 18 souborů** — seznam se generuje z disku, ne ručně |
| Mod | `user://mods/<jmeno>/mod.json` + soubory | `mod.json` = `{id, version, order, files}`; `order` je **povinný**, neznámý klíč je **chyba**, vlastní `root` mod mít **nesmí** |
| Zapojení do hry | `app/main.gd` | `_nacti_obsah()` **před** `_load_data()`; **16 literálů** přeloženo na `_cesta(...)` + **3 konstanty** (`items_data`/`skills_data`/`help_data`); `--no-mods` = cesta zpět |
| Test modulu | `tests/cases/content.gd` (nový) | **55 kontrol / 0 selhání**; mimo jiné: `base` deklaruje **přesně** soubory, které v `data/` jsou; manifest **nenese cesty** (save nesmí záviset na umístění instalace) |
| Mutační důkaz testu | `_analyza/p62-mutace-content.py` | **8 z 8 chyceno** (obrácené pořadí, obrácená shoda `id`, ztracené hlášení chybějícího souboru, ignorovaný neznámý klíč, přijatá cesta s `..`, přijaté duplicitní ID, manifest s cestami, zastaralá deklarace) — po každé mutaci ověřeno, že **vznikla**, a po navrácení že **hash sedí** |
| E2E: hra bere soubor z modu | `_analyza/p63-mod-e2e.py` | **3 běhy hry**: bez modu `vrstev 1 (base), uvod 7`; s modem `vrstev 2 (base, e2e-test), překrytí 1, uvod 8`; s `--no-mods` zpět `1 / 7`. **0 vad.** Kdyby hra mod ignorovala, běh B by měl stejná čísla jako A |
| E2E umí selhat | `_analyza/p64-mutace-e2e.py` | s vrácenou vadou („mod se zaregistruje, ale soubor se nečte") E2E **skončilo 1** a vadu pojmenovalo |
| Nic se nerozbilo | `tests/run_tests.gd`, `run-all.py` | testy **2751/0**, brány **15/0**, replaye **2/2 bez přepnutí hashů**, G11 smoke **0 script error** |

**Vědomé meze S1 (pojmenované, ne tiché):**
1. Mod umí soubor **přebít**, ne do něj přidat záznam (to je S3).
2. **9 modulových konstant** se pořád čte přímo (§1) — tam mod zatím
   nefunguje; je to S1b.
3. Manifest **není v save** — identita obsahu se zatím jen počítá
   (`manifest_hash()`), nepoužívá se (to je S2).
4. `sim/content.gd` **nespouští žádný skript** modu.
5. Nový datový soubor `data/content-layers.json` **není v roadmapě** jako
   granule — `G4` o `sim/content.gd` nic netvrdí (stejná situace jako
   `render/own_art.gd`). Plán mění uživatel.
6. Vrstvy obsahu **nevstupují do `state_hash()`** — a to je **správně**: obsah
   není stav světa. Dokladem jsou replaye, které se nemusely přepnout.

---

## 6. Co potřebuje ROZHODNUTÍ uživatele (a proč to nemůže udělat agent)

1. **S2 — co má `load()` udělat, když obsah nesedí?** Dnes: odmítnout
   (hash). Návrh: `required` vrstvy odmítnout **jmenovitě**, přidané povolit
   s hlášením. Je to **zeslabení dnešní záruky** („data se nezměnila"), takže
   to patří tobě. Cena: ~1 session, mění `docs/04 §4.7`.
2. **S3 — mají mody PŘIDÁVAT záznamy, a jak vypadá ID záznamu?** Dnes je
   identita předmětu `tile` = **art z instalace UO**; to jako naše ID použít
   nejde. Cena: **největší** krok (datové smlouvy + `G5`/`G1`).
3. **S5 — smí mod obsahovat SKRIPT?** Pokud ano, v čem (data / DSL /
   externí proces). **GDScript sandbox v Godotu není**, takže „ano, ať je to
   bezpečné" není proveditelné zadání. Doporučení: **nejdřív (a) data-only**,
   skripty řešit, až bude co rozšiřovat.
4. **Smí vzniknout nová brána a nové granule v roadmapě?** Počet bran je
   součást smlouvy (`docs/08`) a plán mění uživatel (`docs/07` §7.1 bod 5).
   Agent to záměrně neudělal — S1 má **jen testy**, žádnou novou bránu.
5. **Licence:** mod, který distribuuje art z instalace UO, se distribuovat
   nesmí (`README`, `M4`). Má to být **vynucené** (kontrola v modu), nebo
   stačí pravidlo v dokumentaci pro moddery?

---

## 7. Rizika a co to nesmí rozbít

| Riziko | Proč to hrozí | Jak je to dnes ošetřené |
|---|---|---|
| **Determinismus a `state_hash`** | kdyby vrstvy vstoupily do stavu světa, replaye by se rozešly podle instalace | vrstvy do hashe **nevstupují**; doklad: replaye 2/2 **bez přepnutí** hashů |
| **Vrstvy vrstev (`G2`)** | `sim/content.gd` čte `user://` a mohl by sáhnout mimo `sim` | modul je v `sim/`, neodkazuje `ui`/`render`/`app`; `G2` OK |
| **Nový datový soubor** | `G1`/`G5` skenují `data/*.json` | `content-layers.json` je pro `G5` „soubor nastavení" (poznámka, ne vada); `G1` se ho netýká |
| **CI bez modů** | v CI žádné `user://mods` nejsou | `discover()` bez adresáře **není chyba** (0 modů = normální stav) — a test to měří |
| **Rozbitý mod** | modder udělá preklep | chyba se **ohlásí jmenovitě** (adresář modu), mod se přeskočí, hra jede dál; test to měří |
| **Bezpečnost** | dnes je mod soubor; po S5 by to byl kód | dnes žádné spouštění; `mod.json` nesmí mít vlastní `root` (mod nemůže utéct ze své složky) |

---

## 8. Cesta zpět

* **S1 se vypíná za běhu:** `HRA.cmd -- --no-mods` (bere se jen základní
  vrstva; nic se nemaže).
* **S1 se vrací commitem:** dotčené soubory jsou `sim/content.gd`,
  `data/content-layers.json`, `tests/cases/content.gd` a **jeden hunk**
  v `app/main.gd` (`_nacti_obsah()`, `_cesta()`, přeložené cesty, `--no-mods`).
* **S1 nemění** smlouvu save (`docs/04 §4.7`), `state_hash()`, replaye ani
  žádnou bránu — proto je cesta zpět čistá.
