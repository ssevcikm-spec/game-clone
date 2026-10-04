# Ponaučení, nástroje a zkušenosti

> **Co sem patří:** co tahle práce naučila — chyby a jejich příčiny, postupy,
> které se osvědčily, vytvořené nástroje a čím jsou ověřené.
> **Co sem nepatří:** stav projektu (ten je v `HANDOFF.md`), zadání (`docs/`)
> a naměřená data (`research/`) — na ty se odkazuje, nekopírují se sem.
>
> **Pravidlo:** každá session, která udělá práci, sem přidá záznam **hned**
> (ne až na konci), a to i když nic nevyšlo — *hlavně* když nic nevyšlo.
> Zápis bez měření je dohad; patří k němu soubor, číslo a datum.

## Jak psát záznam

```markdown
### RRRR-MM-DD — krátký název (typ)
**Co se stalo:** jedna až tři věty, konkrétně.
**Doklad:** soubor/commit/číslo, které to dokazuje.
**Ponaučení:** co z toho plyne pro příští práci (ne „dávat pozor", ale co udělat).
```

Typy: `chyba` (moje vada) · `past-nástroje` (prostředí/nástroj, ne logika) ·
`postup` (co se osvědčilo) · `nástroj` (nový nástroj a čím je ověřený) ·
`vada-zadani` (co je potřeba opravit ve `docs/`).

---

### 2026-10-04 — `map0.land` se čte o 4 bajty vedle (chyba)
**Co se stalo:** `map.gd` četl blok od `key * 196`, ale numpy reference
(`worldmap.py:287`) kreslí z `key * 196 + 4` — do bufferu se mi 4B hlavička bloku
a poslední 4B bloku chyběly. **Kontrola rozsahu to nechytila**: `z` lezlo v
`-128..127` i po chybě, protože posun o 4 B dává pořád plausibilní bajty.
Statiky prošly (jiný soubor, `.idx`/`.bin`), takže 60 statiků v Britainu bylo
správně a jen land byl posunutý.
**Doklad:** `.cache/analysis/probe-map-python.py` (numpy) vs `probe-map.gd`;
před opravou land id v okolí Britainu lezlo do **65521**, po opravě **1..16379**,
shoda `True`; sonda `.cache/analysis/probe-map.gd` 18/18.
**Ponaučení:** rozsahová kontrola je slabá brána — **porovnej bajty s druhou
implementací** (`seek(offset); get_buffer(12)` proti `cells[b][inner]`) a piš do
hlavičky souboru, **proč je ten offset správně** (`+LAND_HEADER_BYTES`), ne jen
kolik je.

### 2026-10-04 — Godot s nerozjetým skriptem VÍSÍ, ne selže (past-nástroje)
**Co se stalo:** překlep v konstantě (`STATIC_INDEX_PATH` místo
`STATICS_INDEX_PATH`) → `Parse Error` → skript se nenačte → `_initialize` spadne
na `Nonexistent function 'new'` → Godot běží dál v prázdné smyčce. Běžel **8 minut
s 0,05 s CPU a 6,8 MB paměti**; bez `--quit-after` by visel do konce session.
**Doklad:** `.cache/dbg-map.log` (log) a `Get-Process Godot*` → `CPU=0.047`.
**Ponaučení:** každý `--script` běh pouštěj **s `--quit-after N`** a rozhoduj
podle **obsahu logu**, ne podle exit kódu. Navíc `& $godot ... | Select-Object
-Last 40` **bufferuje do konce** — při visícím procesu neuvidíš vůbec nic;
přesměruj do souboru (`| Out-File $log`) a ten čti.

### 2026-10-04 — `.uid` vzniká jen při `--import`, ne při `--script` (postup)
**Co se stalo:** nový `sim/world/map.gd` neměl `.uid` ani po spuštění testů i
všech bran. `sim/world/tiledata.gd` (granule z předchozí session) ho neměl taky.
**Doklad:** `godot --headless --path . --import` → vznik `map.gd.uid`
(`uid://6xjky2sxuae0`) i `tiledata.gd.uid`; po tom `git status` = 3 položky.
**Ponaučení:** po novém `.gd` pusti `--import` a zkontroluj `git status`, že
`.uid` je mezi změnami. Oba chybějící `.uid` byly důsledkem toho, že past #5
z HANDOFFu není součástí kroku „granule hotová".

### 2026-10-04 — Mutační test musí jít proti matematice, ne proti souboru (postup)
**Co se stalo:** po opravě offsetu jsem záměrně otočil index bloku na
`by * blocks_x + bx` a spustil sondu. Spadla 3 kontroly včetně
`britansky blok ma 60 statiku (naměřeno 0)` — přesně symptom z `docs/03 §3.9.1`.
**Doklad:** `.cache/probe-map-mutace.log` (15 kontrol, 3 selhání).
**Ponaučení:** mutuj **vztah**, ne výstup. „Sondě to vadí" je nejlepší důkaz, že
sonda měří to, co má — a mutační zápis zůstává v logu, takže ho nemusíš
vymýšlet znovu.

---

### 2026-10-03 — Sedmnáct sond na formát animací místo přečtení repu (chyba)
**Co se stalo:** `anim.mul` jsem se snažil rozluštit vlastními sondami, jednu po
druhé; pokaždé jsem uvěřil číslům, která vypadala rozumně, a stavěl na nich další
sondu. Formát ve skutečnosti popisují **dva referenční zdroje, které v repu už
byly** (`research/refs/UOFiddler/Ultima/Animations.cs`, `_src/classicuo/.../AnimationsLoader.cs`).
**Doklad:** commity `f9d143e`, `b271373`; sondy `.cache/probe-anim*.py` (1–37);
konečné zjištění („prvních 512 B bloku je ve všech blocích stejných") vzniklo
POROVNÁNÍM bloků, ne další sondou.
**Ponaučení:** než začnu luštit binární formát, **projdu `research/refs/` a `_src/`**
(`grep` na název souboru nebo klíčové slovo). Teprve když tam nic není, píšu sondu —
a první sonda má být **rozdíl dvou vzorků**, ne další hypotéza o jediném vzorku.

### 2026-10-03 — `git checkout -- <soubor>` smazal i rozdělané opravy (chyba)
**Co se stalo:** po mutačním testu jsem chtěl vrátit vloženou vadu a použil
`git checkout -- tools/uoextract/anim.py`. Vrátil se ale **celý soubor z posledního
commitu** — tedy i tři opravy, které jsem měl rozdělané a netestované.
**Doklad:** `b271373` (opravy se musely psát znovu); `git status` před tím byl čistý,
takže „vrátit vadu" znamenalo vrátit i všechno ostatní.
**Ponaučení:** mutaci **nedělej editorem a `checkout`em**, ale vlož ji a vrať
**ze zálohy proměnné** v jednom běhu (`$orig = Get-Content …; …; WriteAllText $orig`)
— nebo ji dělej až po commitu, kdy je `checkout` bezpečný.

### 2026-10-03 — Mutační test odhalil, že ověření netestuje pravidlo (chyba)
**Co se stalo:** obrátil jsem pořadí zdrojů animací (UOP před MUL) a `--verify`
zůstalo **zelené**. Pravidlo `zdroj()` se testovalo jen na živých datech, a ta
jsou pomalá, takže kontrola mohla snadno minout.
**Doklad:** `b271373`; po přidání čtyř offline kontrol (`mul_f`/`uop_f` slovník)
mutace padá na `exit 1`, po vrácení je zelená.
**Ponaučení:** u každého pravidla, které není jen „soubor existuje", napiš
**offline test s umělými daty** — jinak se ověření dá minout a nikdo to nepozná.
Mutaci dělej u každé nové kontroly, ne jen u bran.

### 2026-10-03 — Výsledek je „co je ve všech vzorcích stejné" (postup)
**Co se stalo:** rozhodující průlom v animacích nebyl v dekódování, ale v tom, že
jsem **porovnal první 512 B u tří různých těl a akcí** — byly bit po bitu shodné,
takže pixely nemají vlastní paletu. Tím padly tři hypotézy naráz.
**Doklad:** `research/anim-mereni.md`, `research/anim_pokryti.json`.
**Ponaučení:** když nerozumím formátu, **vezmi dva až tři vzorky a udělej rozdíl**
(stejné / různé). „Co je stejné" řekne o formátu víc než další rozbor jednoho vzorku.

### 2026-10-03 — Sandbox zablokoval pracovní složku, vypadalo to jako mrtvý nástroj (past-nástroje)
**Co se stalo:** první příkaz v session spadl na
`SetNamedSecurityInfoW failed (Win32 5): grantWrite(E:\Workspaces\game-clone)`.
Nebyla to vada projektu ani příkazu — sandbox nemohl složce přidělit práva.
**Doklad:** opraveno skriptem ze skillu `diagnose-windows-sandbox-acl`; poté
`git log` i brány běžely bez změny čehokoli v repu.
**Ponaučení:** když selže **každý** příkaz stejnou hláškou, není to kód —
načti `dsh-prostredi` a `diagnose-windows-sandbox-acl` **dřív**, než začnu hledat
chybu v datech. A `powershell.exe -ExecutionPolicy Bypass -File` je potřeba,
protože `& skript.ps1` na této stanici neprojde.

### 2026-10-03 — Brána odhalila vadu dřív než člověk (postup)
**Co se stalo:** do G6 (`check-assets.py`) jsem přidal měření manifestu animací;
hned první běh ohlásil `anim-manifest.json nemá žádné tělo` — protože `--out`
zapisoval starý formát. Vada vznikla při psaní nástroje a **našla ji brána**.
**Doklad:** `f9d143e`; po opravě G6 `OK`, souhrn `9 měřeno / 2 čekají / 0 chyb`.
**Ponaučení:** nová kontrola se vyplatí okamžitě — piš ji **zároveň** s nástrojem,
ne až po něm. A když brána hlásí vadu hned po přidání, je to důkaz, že měří.

### 2026-10-03 — `git ls-files`, ne `Test-Path` (past-nástroje)
**Co se stalo:** ověřoval jsem, že nové soubory jsou v gitu, a `.gitignore`
s vzorem `*.idx`/`*.mul` je case-insensitive — tedy i `*.py` nástroj se stejným
jménem může tiše vypadnout.
**Doklad:** `git check-ignore -v tools/uoextract/anim.py` → nenalezeno (exit 1);
`git ls-files tools/uoextract/` → `anim.py` tam je.
**Ponaučení:** „soubor existuje" neznamená „je v commitu". Po každém novém souboru
pustit `git ls-files <cesta>`; `check-ignore` je rychlá předzvěst.

---

### 2026-10-03 — Sandbox `workspace-write` zakázal i zápis DO workspace; vypadalo to jako vada ukládání (past-nástroje)
**Co se stalo:** první běh testů hlásil `[test] FAIL sim.world_loop: save() vraci true`
a **238 kontrol, 1 selhání**. Vypadalo to jako vada ukládání v `sim/sim_world.gd`.
Nebyla to vada kódu: sonda ukázala, že v tom režimu **nešel zapsat žádný soubor** —
ani `user://`, ani `res://` (Godot `err=12`), a **stejně tak Python**
(`PermissionError: [Errno 13]` i na `core/`). Po přepnutí file policy na
`danger-full-access` byly testy **238 / 0** bez jakékoli změny kódu. Druhá část
pasti: skript `diagnose-windows-sandbox-acl` skončil `NOT_THIS_CLASS` (exit 2),
protože cesta, kterou jsem mu dal, **neexistovala** — sonda po sobě soubor uklidila.
**Doklad:** `save()` = `FileAccess.get_open_error()` 12 vs. 7; po přepnutí policy
`[test] 238 kontrol, 0 selhani` (exit 0).
**Ponaučení:** když **jeden** test selže na práci se souborem, **nejdřív zjisti, jestli
jde zapsat vůbec něco** (sonda na `user://` + `res://` + Pythonem) — a teprve pak
hledej chybu v kódu. A pro `diagnose-windows-sandbox-acl` je nutné dát cestu, která
**skutečně existuje** (ne takovou, kterou předchozí sonda smazala).

### 2026-10-03 — Bootstrap i W0 už byly hotové; „udělej je znovu" by byla práce navíc (postup)
**Co se stalo:** zadání znělo „udělej bootstrap granule a pak vlnu W0". Všechny čtyři
bootstrap granule i `core.const`, `core.iso`, `core.rng` **v repu byly** a procházely
(`check-docs-refs` 128 odkazů, `check-zadani` 11 dokumentů/101 granulí,
`roadmap-gen --check`, testy **238/0**, brány **9 měřeno / 2 NEMĚŘENO / 0 chyb**,
self-testy **19/0**). Místo přepisování funkčních souborů jsem každou funkci **zavolal**
a změřil (28 naměřených hodnot, 1 NEMĚŘENO, 0 vad).
**Doklad:** `.cache/analysis/bootstrap-verify.py` → `bootstrap-vysledek.json`;
`core/const.gd` 59 ř., `core/iso.gd` 38 ř., `core/rng.gd` 78 ř. — všechny v `git ls-files`.
**Ponaučení:** granule se neposuzuje podle toho, co je v zadání za úkol, ale podle
toho, **co je v repu a co projde měřením**. Když je hotová, řekni to a jdi dál —
„udělat znovu" by rozbilo zelené kontroly a nepřineslo nic.

### 2026-10-03 — Chybějící PRODUCENT, ne chybějící kód: W1 neměla z čeho stavět (vada-zadani)
**Co se stalo:** `world.tiledata` (W1) má podle smlouvy číst `data/tiles.json`, ale
**takový soubor neměl kdo vyrobit**. `tools/uoextract/tiledata.py` uměl jen
`--verify` a **nic nezapisoval**, zatímco `worldmap.py` i `hues.py` do `assets/uo/`
zapisují. Celá W1 tím byla zablokovaná: `world.tiledata` → `world.map` →
`render.sort`, a `data.items` → `world.tiledata`. Zároveň **`data.items` deklaruje
`depends_on: [assets.tiledata]`**, ale samotné čtení tiledata žádný artefakt nevyrábí —
v DAGu tedy chyběl krok „extrakce zapíše data".
**Doklad:** `docs/04 §4.2` slibuje `data/tiles.json`; v repu byl jen
`assets/uo/world/*` a `hues.json`; `--help` nástroje neměl `--extract`.
**Ponaučení:** než začnu psát granuli, ověř, že **všechny její vstupy mají producenta**
(`depends_on` říká „hotové a funkční", ne „existuje jméno v DAGu"). Chybějící vstup
není důvod si ho domyslet — je to nález do `HANDOFF.md`.

### 2026-10-03 — Dokumentovaná tabulka bitů na TATO data nesedí; každý bit se musí ověřit (chyba)
**Co se stalo:** kategorizoval jsem předměty podle tabulky `TileFlag` z
`research/05-data-formats.md` (bit 2 = `Weapon`, bit 27 = `Armor`). Na datech to
vyšlo **1126 „zbraní"** — včetně `leather cap` a `gargoyle_leather_chest`, protože
bit 2 má nastavený **všech 1268** Wearable předmětů. Bit 27 (`Armor`) má jen 25
předmětů a **ani jeden není zbroj**.
**Doklad:** `probe-overit-bity.py`: bit 2 → 1177 předmětů (184 se slovem zbraně,
218 se slovem zbroje); po přepisu na `layer` + jméno vyšlo 673 zbraní / 204 štítů /
269 zbrojí / 18 nástrojů.
**Ponaučení:** **každý použitý bit se ověří na jménech, která o sobě něco říkají**
(„chest" má být zbroj, „sword" zbraň). Tabulka v `research/` je zdroj, ne důkaz —
a stejná chyba se dá udělat dvakrát, když se ověří jen jeden bit.

### 2026-10-03 — `%s` v jménech UO je znak plurálu, ne vada dat (past-nástroje)
**Co se stalo:** generator vyřazoval jména obsahující `%` jako „placeholdery" — a tím
zahodil **všechny ingoty** (`iron ingot%s`), obvazy (`clean bandage%s%`), šípy
(`shaft%s`) a další. Skutečné placeholdery jsou jen `Missing_Name` (92×), `NoName`
(29×), `nodraw` (19×) — celkem 142 záznamů.
**Doklad:** `probe-dosuroviny.py`: `'iron ingot'` přesně → 0 nálezů, ale
`'iron ingot%s'` a `'iron ingots'` existují; po opravě `items.json` ingoty obsahuje.
**Ponaučení:** než něco vyřadím jako „rozbité", podívám se, **kolik toho je a jak to
vypadá** — 5 podezřelých jmen a 142 záznamů proti tisícům skutečných předmětů.
Filtr podle jednoho znaku (`%`) je příliš hrubý; vyřazuje se **konkrétní seznam**.

### 2026-10-03 — Hledání podřetězcem vybírá smetí; jména se hledají přesně (chyba)
**Co se stalo:** kategorie jsem plnil hledáním podřetězce. `log` chytil 113 nálezů
(`log wall`, `log post`), `hide` chytil `hide wall`, `loom` chytil `Bloom Firework`,
`pan` chytil `pants`, `cap` by chytil `capacity`. Výsledkem byl katalog plný zdí.
**Doklad:** `probe-vzorky-jmen.py`; po přechodu na přesná jména + varianty
`jmeno`/`jmeno%s`/`jmenos` se vybírá `logs` (7134), `boards` (7128), `cloth` (5989).
**Ponaučení:** jméno předmětu se hledá **přesně** (a u UO i s variantou plurálu).
Podřetězec je přijatelný jen tam, kde je předem vidět, co všechno chytí — a to se
u 65 536 předmětů nedá udržet v hlavě.

### 2026-10-03 — `Measure-Object -Line` nepočítá prázdné řádky (past-nástroje)
**Co se stalo:** `anim.py` měl podle `HANDOFF.md` 451 řádků, `Measure-Object -Line`
dalo 451 a Python `splitlines()` **516**. Nebyl to spor: soubor **nekončí newline**
a obě metriky měří jinou věc. `HANDOFF` uváděl **neprázdné** řádky (451, 192, 118),
skutečné délky souborů jsou **516, 232, 137**.
**Doklad:** `probe-radky.py` — `anim.py`: všech 516, neprázdných 451, prázdných 65.
**Ponaučení:** `size_lines` se měří **všemi řádky** (Python `splitlines()`), protože
deklarace je o velikosti souboru. `Measure-Object -Line` je na tohle špatný nástroj
a jeho číslo je potřeba pojmenovat („neprázdné řádky"), ne přepsat.

### 2026-10-03 — Statická kontrola si sama naletěla na komentář (chyba)
**Co se stalo:** do vlastní ověřovací sondy jsem dal kontrolu „nejsou v `project.godot`
herní konstanty?" a hledal `TILE_W|ISO_STEP|WALK_MS` v **celém textu** — našlo to
komentář, který vysvětluje, že tam být **nemají**. Sonda hlásila `True` (vada), i když
konstanty v konfiguraci nejsou. Přesně past z `docs/09` §9.6.2, kterou ten soubor sám
popisuje.
**Doklad:** `probe-project-konstanty.py`: s komentáři `True`, bez komentářů `False`,
12 klíčů a mezi nimi žádná herní konstanta.
**Ponaučení:** komentáře se odstraňují **i ve vlastní sondě**, ne jen v branách
(`ln.split(";", 1)[0]` u `.godot` ini, `#` u Pythonu). Kdo si myslí, že se ho to
netýká, píše právě tu chybu.

### 2026-10-03 — Zápis do podsložek blokuje INTEGRITNÍ LABEL, ne ACL (past-nástroje)
**Co se stalo:** v režimu `workspace-write` selhával zápis do **všech existujících**
podsložek workspace (`PermissionError`), ale do **kořene** a do **nově vytvořené**
složky procházel. Vypadalo to na rozbité ACL — a skript
`diagnose-windows-sandbox-acl` tomu odpovídal: udělal 14 grantů (WRITE_DAC/WRITE_OWNER),
všechny **ověřené**, 0 odmítnutých, rollback nebyl potřeba — a **původní operace
selhala dál**. Oprava tedy byla správná, ale neúčinná: příčina je v SACL, ne v DACL.
**Doklad (měření, ne dohad):** `whoami /groups` v sandboxu → `Mandatory Label\Low
Mandatory Level (S-1-16-4096)`; `icacls <kořen>` → `Mandatory Label\Low Mandatory
Level:(OI)(CI)(NW)`, ale `icacls tools`, `sim`, `.cache`, `app` → **žádný label**;
nová složka v kořeni label zdědí a zápis do ní projde. Sonda `_analyza/sonda-zapisu.py`:
před opravou **1/19**, po přepnutí na plný přístup **19/19** (token je pak `Medium`).
Důsledek pro brány: G3 i G7 hlásily `VADA` (`save()/load() … save=false`), i když byl
kód v pořádku — `tools/gates/gate_common.py:219` posílá `APPDATA` natvrdo do
`.cache/godot-appdata`, kam Low proces nesmí. Po přepnutí: G3 OK, G7 OK, **9/2/0**.
**Ponaučení:** když zápis selže v podsložkách a v kořeni ne, **změř nejdřív integritní
label** (`icacls <cesta> | Select-String Mandatory` + `whoami /groups`), ne ACL. Low
proces nesmí zapsat do objektu bez Low labelu **bez ohledu na DACL** — samotné přidání
práv to nevyřeší a vypadá to jako neúčinná oprava. Label potřebuje právo, které sandbox
nemá (`icacls /setintegritylevel` v něm skončil `Access is denied`), takže jediná
dostupná cesta je plný přístup pro session. Druhý důsledek téhož: nástroje harnessu
(`write`/`edit`) **nejdou přes sandbox** — zapisují i tam, kam podproces nesmí, ale
smazat odtud nejde (dědičný `Everyone DENY (DeleteSubdirectoriesAndFiles)`), takže
sonda zanechá soubor, který musí uklidit až session s plným přístupem.

---

## Vytvořené nástroje (co, kde a čím ověřené)

| Nástroj | K čemu | Ověření |
|---|---|---|
| `tools/uoextract/tiledata.py --extract` | **nově**: zapíše `assets/uo/tiles.json` (land+item, 81 920 záznamů) | `--self-test` **15 kontrol** (7 nových offline); živý běh 2 405 685 B |
| `data/items.json` (granule `data.items`) | katalog 8 748 předmětů s `source`, `value_source`, `category_rule` | G5 `check-content` OK (`items.json_zaznamu: 8748`) |
| `sim/world/tiledata.gd` (granule `world.tiledata`) | vlastnosti dlaždic/předmětů z JSONu, dvě id prostranství (0x4000) | sonda `probe-tiledata.gd` **18 kontrol, 0 selhání** |
| `.cache/analysis/bootstrap-verify.py` | měří bootstrap granule zavoláním (28 hodnot) | `bootstrap-vysledek.json`, 0 vad, 1 NEMĚŘENO |
| `.cache/analysis/gen-items.py` | generator `data/items.json` (běh ze session) | idempotentní; kategorie+role se vypisují k pohledu |
| `tools/uoextract/anim.py` | zdroj animací (`anim.mul` vs `AnimationFrame*.uop`), tabulky framů | `--self-test` 22 kontrol, `--verify` 22 kontrol proti instalaci |
| `research/probe/anim_pokryti.py` | reprodukovatelné měření pokrytí těl | dává 270 / 318 těl, prunik 2 — zapsáno v `research/anim-mereni.md` |
| `tools/gates/check-assets.py` (G6) | nově měří i manifest animací | `--self-test` 4 případy; běh nad repem `OK` |
| `tools/gates/run-all.py --self-test` | nově pouští i `anim.py` | 19 self-testů (10 bran + 9 extrakčních nástrojů), 0 chyb |
| `_analyza/sonda-zapisu.py` (gitignore) | zapíše a smaže soubor v 19 cestách stromu — rozliší „nejde zapsat nic" od „nejde zapsat do podsložek" | před opravou 1/19, po přepnutí na plný přístup 19/19 |
| `_analyza/acl/` (gitignore) | zálohy ACL + protokol `acl-report-*.jsonl` (14 grantů, všechny ověřené) | `RECAP` v protokolu: `GRANTED=14 REFUSED=0 RESTORED=0` |
