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

### 2026-10-04 — Stabilita na 3 prvcích se neprokáže, na 1000 ano (postup)
**Co se stalo:** kontrola „tři mobily na jedné dlaždici se stejným `z` si drží
pořadí vstupu“ **prošla i s mutací**, která porovnává jen `a[0] < b[0]` (bez
stabilizace) — `sort_custom` na třech prvcích se chová jako stabilní. Po
doplnění stejné kontroly na **1000 objektů se stejným klíčem** mutace spadla.
**Doklad:** `.cache/analysis/mutace-sort.py`, mutace „nestabilni razeni“: před
posílením `18 kontrol, 0 selhani`; po posílení `FAIL 1000 objektu se stejnym
klicem: poradi vstupu se zachova`, exit 1.
**Ponaučení:** kontrolu stability dělej na seznamu, kde je **shoda hojná**, ne na
třech stejných prvcích. „Malý vstup prošel“ je u třídění totéž co „malý vstup se
chová jinak“.

### 2026-10-04 — Složený klíč: chyba je v přenosu mezi poli, ne v porovnání (postup)
**Co se stalo:** `sort_key` skládá `((x+y) * 3 + vrstva) * 256 + z`. Mutace
`LAYERS 3 → 2` **prošla**, protože kontrola porovnávala jen dvě země (obě ve
vrstvě land) a pár objektů na *jedné* dlaždici. S `LAYERS = 2` má mobilní na
diagonále `d` **stejný klíč** jako land na diagonále `d+1` a pořadí mezi nimi
rozhodne až pořadí vstupu. Padlo to až při kontrole „vše z diagonály 8 před vším
z diagonály 9“ (18 objektů = 3 vrstvy × 3 výšky `z`).
**Doklad:** táž mutace: před posílením `18 kontrol, 0 selhani`, po posílení
`FAIL vsechny objekty diagonaly 8 pred vsemi z diagonaly 9 (18 objektu)`, exit 1.
**Ponaučení:** když cpakuješ víc hodnot do jednoho `int`, **netestuj, že jsou pole
správně seřazená, ale že jedno pole nepřeteče do druhého**. Na to nestačí jeden
příklad na dlaždici — potřeba je sousední pole s **horší** hodnotou.

### 2026-10-04 — Mutace, která projde, nemusí být slepá kontrola (chyba)
**Co se stalo:** třetí z 7 mutací (`z - Z_MIN` → `z + Z_MIN`) **prošla** a nebyla
to chyba sondy: posun o konstantu pořadí nemění. Ukázala ale jinou věc — můj
komentář tvrdil, že se klíč dá použít jako `z_index`. **Nejde:** klíč roste s
`(x+y)` (pro mapu 7168×4096 až ~8,6 mil.) a Godot bere `z_index` jen
**−4096…4096**. Komentář jsem opravil, klíč je na porovnávání.
**Doklad:** `render/sort.gd:29-31` po opravě; sonda teď piny i význam čísla
(`klic 0 = dlazdice (0,0), vrstva land, z = Z_MIN`), takže smysl je zakotvený.
**Ponaučení:** když mutace projde, nepiš hned „kontrola je slepá“. Zeptej se
nejdřív, **zda je mutace vůbec vadná** (zde: ne, je zachovávající pořadí). Když
vadná není, hledej druhý důsledek — tady se v ní schovalo **nepravdivé tvrzení v
komentáři**, což je horší vada než neprohozená kontrola.

### 2026-10-04 — G10 přešla z NEMĚŘENO na VADA jen tím, že vznikl první `render/` (namereno)
**Co se stalo:** po `render/sort.gd` se G10 (`check-render.py`) poprvé dostala od
`render/ neobsahuje žádný .gd` k měření snímku a **spadla**: `snapshot.png
1280x720, barev 1` → „snímek je jednolitý — nic se nevykreslilo“. Ten snímek je
**stará artefakt z 2026-10-02 19:24** (uniformní `(77,77,77)`; v `.cache/render/`
leží i `frame*.png` a `frame.wav` po Movie Makeru z bootstrapu). Brána kontroluje
jen `exists()`, **ne stáří** — dnes tedy měří čtyři dny starý prázdný obrázek.
**Doklad:** `python tools/gates/run-all.py` → před změnou `NEMĚŚENO` (exit 2,
souhrn `měřeno 9, čeká 2, chyb 0`), po změně `G10 VADA` (exit 1, `měřeno 9,
čeká 1, chyb 1`); `LastWriteTime .cache/render/snapshot.png = 10/2/2026 7:24 PM`;
Pillow: 1 barva.
**Ponaučení:** červená G10 je **pravdivá** („na obrazovce nic není“), ale její
příčina není dnešní build. Dva závěry: (a) NEMĚŠENO u G10 znamenalo „chybí kód“,
ne „chybí měření“; (b) **uměřený soubor musí mít stáří**, jinak se včerejší
artefakt propírá jako dnešní měření. Patří do `tools/gates/check-render.py`
(agent ho nemá měnit) a do hlavičky `app/`, ať snímek vzniká při běhu.

### 2026-10-04 — `check-wiring` nerozliší volání od proměnné (namereno)
**Co se stalo:** po přidání `render/sort.gd` klesl `neintegrovano` z 26 na 25.
Měřením (soubor odložen → brána → soubor vrácen → rozdíl seznamů názvů) vyšlo,
že **`world.tiledata.layer` přestal být „mrtvý“ jen proto, že mám lokální
proměnnou `layer`** — brána hledá jméno slovem, ne voláním `layer(`. Současně
korektně přibyly dvě opravdu zapojené konstanty (`Z_MIN`, `Z_MAX`).
**Doklad:** `check-wiring.py` bez souboru `{… 'volanych_z_produkce': 26,
'neintegrovano': 26}`, s souborem `{… 29, … 25}`; `Compare-Object` názvů:
`+ render.sort.draw_order`, `+ render.sort.sort_key`, `− core.const.Z_MIN`,
`− core.const.Z_MAX`, `− world.tiledata.layer`.
**Ponaučení:** **proměnnou jsem nepřejmenoval** — kód je správný, chyba je v
nástroji a přejmenovat kvůli metrice je reflex, který pravidla zakazují.
Konkrétní oprava pro vlastníka bran: v `provides` rozlišit jména funkcí (`name(`)
od konstant a u funkcí hledat tvar volání. Zatím tento nález jen **zmenšuje**
počet „mrtvého“ kódu, tedy je u tohoto typu optimistický.

### 2026-10-04 — Sandbox: `Low` label má jen kořen workspace (past-nástroje)
**Co se stalo:** znovu naměřeno, tentokrát poprvé v této session: podprocesy
běží na `Low Mandatory Level`, ale `Mandatory Label\Low` je jen na kořeni
`E:\Workspaces\game-clone`. Zápis do kořene projde, do `.cache`, `data`, `sim`,
`tools` ne. Důsledek: `run-all.py` končí `PermissionError` na `summary.json` a
**G3, G7, G11 nemohou zapsat do `user://`** (`gate_common.py:219` má adresář Godot
natvrdo v `.cache/godot-appdata`).
**Doklad:** `Set-Content` do kořene OK / do `.cache` „Access denied“;
`icacls … | findstr Mandatory` — label jen na kořeni; `run-all.py` v tomto stavu
→ `měřeno 6, čeká 3, chyb 2`, exit 1.
**Ponaučení:** pro **Godot testy** stačí nasměrovat `APPDATA` do adresáře
**přímo pod kořenem** (kořen label dědí, takže se do něj dá psát) — pak testy
běží (`238 kontrol, 0 selhani`). Na **brány** to nepomůže, ty si cestu píšou samy.
Oprava je session na plný přístup. Nové adresáře vytvořené přes `write` label
**dědí**, takže do nich podproces psát může.

---

### 2026-10-04 — Recepty: jména nejsou v `research/04`, jsou v `Cliloc.enu` (postup)
**Co se stalo:** `research/04-craft-data.json` (11 řemesel, 1053 receptů) jména
výsledku ani materiálu **neobsahuje** — je to C# typ (`GoldRing`) a číslo kliloku
(`["expr", "1044176 + offset"]`). Řešení je dvojí: text z `Cliloc.enu` (klíč
`cliloc.py`, už existoval) a teprve pak `tile` z `items.json`; druhý pokus je
rozdělení C# typu (`GoldRing` → `gold ring`).
**Doklad:** `gen-content.py --only recipes --check` → **exit 0**, sha256
`8759e697cefc0d0e…`; dva běhy za sebou dávají shodné bajty.
**Ponaučení:** když zdroj dat jména neobsahuje, je to **vlastnost zdroje**, ne
vada generátoru — text ber z kliloků a do záznamu piš i `type` i číslo kliloku,
aby se dal odkaz zpátky dohledat.

### 2026-10-04 — V této instalaci chybí dvě třetiny obsahu receptů (namereno)
**Co se stalo:** z 1053 receptů má výsledek `tile` jen **354** a materiál 1035
z 1696. Nefektnost není chyba párování: ty předměty v `tiles.json` opravdu nejsou
(„platemail (tunic)“, „turquoise“, „blank scroll“, „star sapphire ring“ — obsah
pozdějších eras, ne T2A).
**Doklad:** `.cache/analysis/probe-recipes.py` (gitignore) — po normalizaci
pluralu/`%s` **nesedí 0 z 1389** vyřešených referencí, takže mapování není
náhodná shoda; `check-content.py` na `recipes.json`: `recipes.json_odkazu`
měřeno, chyba 0.
**Ponaučení:** nerozřešené reference **nepozoruj jako fiktivní `tile`** — bez
`tile` je to „neměřeno“ (G5 odkaz přeskočí), s vymyšleným tile by to byla tichá
zelena. Výsledek patří do `assets/uo/content-report.json`.

### 2026-10-04 — Výpis nevyřešených po jedné řádku schoval vlastní výsledek (chyba)
**Co se stalo:** generátor vypisoval každou nevyřešenou referenci na vlastní řádek
— **1360 řádků** (895 různých jmen). Výstup se uložil do spill souboru, z původního
běhu nebylo vidět `receptu 1053; vysledek ma tile 354`, návratový kód ani OK řádky.
**Doklad:** první běh `--only recipes` měl 1360 řádků `NENALEZENO`; po souhrnu
(top 25) má výstup ~40 řádků a na konci jsou obě metriky i `sha256`.
**Ponaučení:** vedlejší výpis musí mít **svůj strop** a říkat, kolik položek
zanechalo (`… celkem 1360, zde top 25`), jinak se hlučina čte jako výsledek.

### 2026-10-04 — Vedlejší výpis se opírá o cizí klíče a padne na `KeyError` (chyba)
**Co se stalo:** tisk nevyřešených položek je sdílený mezi `items` a `recipes`, ale
ty dva zdroje mají **jiný tvar záznamu** (`kategorie`/`role` proti
`soubor`/`skill`/`kind`/`nazev`). Po zápisu `recipes.json` spadl běh na
`KeyError: 'kategorie'` — **exit 1 a žádný `sha256`**, přestože data byla správně
zapsaná. Podobně `rec["file"]` patří na úroveň řemesla, ne receptu.
**Doklad:** dvě tracebacky z `gen-content.py` (řádky 404 a 458); po opravě
`--only recipes` → exit 0 a `zapsano … sha256 8759e697cefc0d0e…`.
**Ponaučení:** sdílený výpis si musí sjednotit tvar (`.get()` na alternativu),
ne předpokládat jeden. A **výstup, který něco vypíše, patří do testu**: bez
výpisu by chyba přešla do commitnutého kodu a selftesty by ji nechaly projít.

### 2026-10-04 — `res_amount: null` není nula (postup)
**Co se stalo:** `int(rec["amount"])` spadl na `TypeError` — u **4 receptů** z
1053 je `res_amount` v `research/04` `null`.
**Ponaučení:** `null` při převodu na číslo není „0 kusů“ a není to ani „jeden“ bez
změření; tady jde o 1 kus a je to rozhodnutí zaznamenané v kódu i datech
(`amount: 1`).

### 2026-10-04 — Generátor musí reprodukovat data, ne „vylepšit" je (chyba)
**Co se stalo:** při přenosu `.cache/analysis/gen-items.py` do repa jsem při
čtení narazil na `SUROVINY_VYLOUCENE = {"sand"}` — sada, která nikde nebyla
použitá, a `sand` (váha 255 = statika) přitom **byl** v `items.json`. V nové verzi
jsem ho „opravil“ ven ze seznamu a `--check` hned hlásil `VADA` — **a měl pravdu**.
Chyba by nebyla v generátoru, ale v tom, že bych přepsal data, která jsou v gitu a
která nikdo neposoudil.
**Doklad:** porovnání obou generátorů na `tiles.json`: 8748 vs 8747 záznamů,
jediný rozdíl = `tile 9310 'sand'`; po vrácení `sand` → `--check` OK,
`items.json` sha256 `f6c9a6122fcb17127…` identická s dávno commitnutou.
**Ponaučení:** migrace nástroje, který **vyrábí data v gitu**, se nedělá
„přepisem, jak to vypadá správně“. Buď reprodukuj bajty a vadu zapiš jako
otevřenou věc, nebo ji oprav ve zvláštním kroku, kde je vidět diff dat.

### 2026-10-04 — `--only` tiše přepsal celý `content-report.json` (chyba)
**Co se stalo:** `gen-content.py --only items` zapsal svůj (užší) report do
`assets/uo/content-report.json` a **smazal z něj 14 položek „generator chybí“**.
`--only` jsem přitom považoval za „jen něco vygeneruj“, ne „přepiš stav všeho“.
**Doklad:** po `--only items` měl report `bez_generatoru: 0`; po plném běhu znovu
14 (a `unresolved: 2` — `clean bandage`, `blank scroll`, které v tiledata nejsou).
**Ponaučení:** u přepisovaných stavových souborů odděl **plný běh** od
**dílčího** — dílčí výsledek jde vedle (`.cache/gen-content/`), a to se musí
vypsat, ne jen udělat. Stejně jako u `save_game`: „částečný zápis“ není totéž co
„hotový stav“.

### 2026-10-04 — Vedlejší výpis ukončil běh tracebackem (chyba)
**Co se stalo:** vypisování ukázek kategorií na konci `gen-content.py` čte
`data/items.json` z disku. Když `--check` běžel nad **poškozeným** souborem,
padl `JSONDecodeError` a běh skončil tracebackem místo `VADA`. Tedy: kontrola
shody se sice provedla a správně našla rozpor, ale navratovy kod ani hlaska
o rozporu se už neprosly.
**Doklad:** `--check` nad souborem s jedním změněným bajtem → dřív
`JSONDecodeError` na řádku 327, po opravě `VADA items.json: na disku je jiná
verze…` + `ukazky nelze vypisat (…) - výsledek běhu výše platí` + **exit 1**.
**Ponaučení:** vše, co je **vedlejší produkt** (ukázky, souhrny, náhledy), patří do
`try/except` a nesmí to změnit navratovy kod měření. Jinak se vada převede na
stack trace, ktery neumi rict, zda kontrola zmerila nebo ne.

### 2026-10-04 — `data.items` nemá test v `tests/cases/` (postup)
**Co se stalo:** `data/items.json` (8748 záznamů) vznikl během session a nikdo
nemá v `tests/` nic, co by ho četlo. G5 ho sice počítá, ale jen jako „kolik
záznamů“, ne jako „je správný“.
**Doklad:** `data/` vlastní jen granule z roadmapy, `tests/cases/` žádný případ
neobsahuje; `check-content.py` měří `items.json_zaznamu` a `items_tiles`.
**Ponaučení:** „generator existuje a je idempotentní“ je jiné tvrzení než
„data jsou správná“. První teď platí (`gen-content.py --check` + mutace),
druhé je pořád nezakryté — viz HANDOFF.

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

### 2026-10-06 — Self-test na 6 spritech prošel nad atlasem se 117 překryvy (chyba)
**Co se stalo:** `tools/uoextract/atlas.py` má v `self_test()` kontrolu překryvů
políček — a přesto vygeneroval atlas, ve kterém je **117 překryvů** (sprity se
překrývají až o **27 px ze 44**) a **17 spritů je plně průhledných** (např. item
4410), protože je pozdější sprite přepsal. Důvod: self-test pouštěl `rozloz()`
na **6 syntetických spritech** na stránce **256 px**, zatímco reálný běh sází
**17 436 spritů** na **2 048 px**. Malý vstup se chová jinak — police se v něm
nikdy nezaplní.
**Doklad:** `python tools/uoextract/atlas.py --self-test` → „30 kontrol, 0 chyb",
exit 0; `--verify` a `.cache/analysis/atlas-build.log` → „17 chyb: prazdny sprite
item 4410 …"; vlastní měření manifestu: `STEJNA POZICE` 0, ale **překryvů ve
stejném pruhu 117**; `neprůhledných pixelů v rectu itemu 4410: 0`.
**Ponaučení:** self-test, který má prokázat vlastnost **rozložení**, se musí
pustit na **počtu stránek a spritech v měřítku reálného běhu** — jinak je to
kontrola, která nemá jak selhat. A pozor na druhý důsledek: `--verify` sice vadu
našel, ale build přesto **doběhl do konce** — nástroj, který vadu ohlásí a přesto
vydá artefakt, vypadá jako hotový.

### 2026-10-06 — Dvanáct commitů, které nikdo neviděl, není práce v bezpečí (past-nástroje)
**Co se stalo:** `origin/main` byl **12 commitů zpátky** za `HEAD` — veškerá práce
M1 a M2 (tiledata, art, gump, mapa, recepty, `render.sort`) existovala **jen na
tomto disku**. Předchozí předání stav gitu nezmiňovalo.
**Doklad:** `git rev-list --count origin/main..HEAD` → `12`; `git log origin/main`
končil commitem `819c9a3` (2026-10-03 14:44), zatímco `HEAD` byl `3e7864c`
(2026-10-04 22:52); `git status` → `?? tools/uoextract/atlas.py`.
**Doplnění téhož dne (po pushi):** domněnka „CI se nikdy nespustilo" **byla
nesprávná** — spustilo se, ale **dvakrát selhalo s 0 jobů a bez logů**
(`#1` nad `819c9a3`, `#2` nad `7a4f3e7`, `created_at == updated_at`).
**Nezelené CI se tedy četlo jako „CI neběželo"** — a to je jiná věta.
**Ponaučení:** „práce je hotová" a „práce je v bezpečí" jsou dvě tvrzení.
Předání musí nést **stav gitu živě** (`rev-list --count origin/main..HEAD`),
ne jen seznam hotových granulí. A **stav CI se měří v API** (`/actions/runs` →
`conclusion`, `/jobs` → `total_count`), ne odhadem z toho, že workflow soubor
v repu je — repo mělo `total_count: 2` běhů, o kterých dokumentace nevěděla.

### 2026-10-06 — Běh CI s nulou jobů není chyba kódu (past-nástroje)
**Co se stalo:** **všechny tři** běhy workflow skončily `failure`, ale pokaždé
s **0 jobů, 0 check-runs a žádnými logy** — ani jeden krok se nespustil, takže
se neprojevil žádný kód projektu. `Actions` v repu jsou přitom `enabled: true`,
`allowed_actions: all`, workflow je `active` a token má na repo `admin: true`
i scope `repo, workflow`. Podpis odpovídá **vyčerpané kvótě minut u privátního
repa** (`visibility: private`).
**Doklad:** `/repos/.../actions/runs` → 3 běhy (`#1` `819c9a3`, `#2` `7a4f3e7`,
`#3` `036150b`), všechny `failure`; `/actions/runs/<id>/jobs` → `total_count: 0`
(u všech); `created_at == updated_at` (běh netrval ani sekundu);
`/actions/permissions` → `enabled: true`; `/repos/...` → `permissions.admin: true`;
`/users/<login>/settings/billing/actions` → **404** (token billing nevidí).
**Ponaučení:** u červeného CI se **nejdřív ptej, jestli běželo** — počet jobů
a existence logu to řeknou dřív než čtení workflow souboru. „Workflow je
v repu a má `on: push`" nedokazuje, že někdy proběhlo. A **privátní repo má
minuty omezené, veřejné ne** — u hry, jejíž assety jsou gitignore, je
zveřejnění repa levná varianta, ale je to **rozhodnutí uživatele**.

### 2026-10-06 — Zveřejnění repa kvótu vyloučilo, YAML taky: zbývá hláška v UI (postup)
**Co se stalo:** repo jsem zveřejnil (`visibility: public`, ověřeno dotazem
**bez tokenu**) a **běh `#4` selhal úplně stejně** — okamžitě, 0 jobů. Tím padla
hypotéza o vyčerpané kvótě minut, kterou jsem předtím vyslovil. Další měření ji
potvrdilo nezávisle: `/actions/runs/<id>/timing` → **`billable: {}`**, tedy
**nespotřebovala se ani minuta** (což je i logické — běh netrval ani sekundu).
Pak jsem ověřil **syntaxi YAML** vlastním parserem, **kalibrovaným** na dvou
vratných vadách (chybějící dvojtečka u `on:`, tabulátor v odsazení) — soubor je
čistý. Třetí „mutace" (odebraný krok) **kalibraci neprošla a byla to moje chyba
v očekávání**: odebraný krok není syntaktická vada.
**Doklad:** `PATCH /repos/...` → `visibility: public`; `/actions/runs` → `#4`
`8172b75` `failure`, `/jobs` → `total_count: 0`; `timing` → `billable: {}`;
vlastní parser na `.github/workflows/ci.yml` → 0 chyb (a 2/2 vratné vady odhalil).
**Ponaučení:** když hypotéza padne, **řekni to nahlas a zapiš** — jinak zůstane
v předání jako fakt (přesně to se stalo s „kvótou minut" i předtím s „CI nikdy
neběželo"). A **kalibrace parseru je součást měření**: bez vratných vad se
„0 chyb" nedá odlišit od parseru, který nic neměří. Co API neumí, se musí
**přečíst v UI** — a to patří do zadání jako konkrétní krok pro člověka,
ne jako „vyřešit CI".

### 2026-10-06 — Auditem zmizelo 5 granul z fronty: stav se nesmí opisovat (postup)
**Co se stalo:** předání tvrdilo „M0 5" hotových granul a `run-all` fronta stavěla
na tom, že `app.main`, `app.loop`, `app.input`, `sim.commands` a `sim.world_loop`
nejsou hotové. **Všechny mají soubor v gitu i testovací případ** — jen nebyly
v seznamu. Po jejich uznání je **M0 hotové celé (17/17)** a počet granul ve frontě
se změní z 14 na 22.
**Doklad:** `git ls-files` + `tests/cases/` (`commands.gd`, `sim_world.gd`,
`loop.gd`, `input.gd`); `sim/commands.gd` 137 řádků, `sim/sim_world.gd` 232.
**Ponaučení:** stav hotových granulí se **měří** (soubor v gitu **a** jeho funkce
jde zavolat), nikdy se neopisuje z předchozího předání. Ručně udržovaný seznam
hotových věcí **tiše zaostává** — a čím déle, tím víc práce vypadá neudělaná.

### 2026-10-06 — Hotový soubor bez volajícího je mrtvý kód (past-nástroje)
**Co se stalo:** `render/sort.gd` je hotový a změřený sondou (21 kontrol) — a má
**0 volajících z produkce**. Totéž `world.doors`, `world.stairs`, `world.time`:
otestované funkce, které nikdo nevolá. Navíc tři **vady zapojení**, které nejsou
vidět z existence souborů: `app/main.gd:30` přidává jako dítě jen `loop`, takže
`input_map.poll()` se **nikdy nezavolá**; `sim.systems` plní **jen testy**
(`tests/cases/sim_world.gd:85-87`), takže 15 systémů ze `SYSTEM_ORDER` je seznam
jmen; `time.gd:23` má vlastní `world_time_ms`, které **nikdo nezapíše**, takže
`hour()` vrací vždy 0.
**Doklad:** grep `sort_key|draw_order|_draw|queue_redraw|Sprite2D` v celém stromě
→ **3 nálezy, všechny uvnitř `render/sort.gd`**; `check-wiring.json` sám hlásí
„render.sort.sort_key: zatím nevolané z produkce" (25 neintegrovaných,
27 jen-z-testů); `systems[` jen na dvou místech (1 čtení, 1 zápis v testu).
**Ponaučení:** u hotové granule se neptej „existuje soubor?", ale **„kdo to
volá?"** — a to ověř greppem na **jméno funkce v produkčních složkách**. Jinak
se stav „hotovo" počítá z mrtvého kódu a na obrazovce není nic, i když jsou
všechny brány zelené.

### 2026-10-06 — Dva nálezy z rešerše neobstály; vada byla v dokumentaci (postup)
**Co se stalo:** nezávislé rešerše (tři subagenti nad týmž stromem) vrátily dva
nálezy, které **nebyly vady kódu**: (a) „`assets/uo/manifest.json` neexistuje" —
soubor existuje a má 3 565 629 B i klíč `sprites`, rešerše četla jen starší
kandidátní cestu z `check-assets.py`; (b) „`world.time` vrací noc = den, je to
vada" — v `time.gd:12-21` je to **dokumentované rozhodnutí** (noc se neměří,
dokud se nezměří `light.mul`) a soubor to přiznává i v testu.
**Doklad:** `assets/uo/manifest.json` (3 565 629 B, `generator: tools/uoextract/atlas.py`);
`sim/world/time.gd:12-21`; `check-assets.py:28` (`MANIFEST_CANDIDATES`).
**Ponaučení:** cizí měření se ověřuje **otevřením téhož souboru**, ne
důvěrou — a to i když je měřil nástroj, který jsem si sám zadal. Když nález
vypadá jako vada, ale v souboru je **napsaný důvod**, je to nález o dokumentaci
(chybějící zmínka, rozpor sekcí), ne o kódu. Zapsat se má **obojí**.

---

## Vytvořené nástroje (co, kde a čím ověřené)

| Nástroj | K čemu | Ověření |
|---|---|---|
| `tools/uoextract/tiledata.py --extract` | **nově**: zapíše `assets/uo/tiles.json` (land+item, 81 920 záznamů) | `--self-test` **15 kontrol** (7 nových offline); živý běh 2 405 685 B |
| `data/items.json` (granule `data.items`) | katalog 8 748 předmětů s `source`, `value_source`, `category_rule` | G5 `check-content` OK (`items.json_zaznamu: 8748`) |
| `sim/world/tiledata.gd` (granule `world.tiledata`) | vlastnosti dlaždic/předmětů z JSONu, dvě id prostranství (0x4000) | sonda `probe-tiledata.gd` **18 kontrol, 0 selhání** |
| `.cache/analysis/bootstrap-verify.py` | měří bootstrap granule zavoláním (28 hodnot) | `bootstrap-vysledek.json`, 0 vad, 1 NEMĚŘENO |
| `tools/gates/gen-content.py` (granule `data.gen_content`) | **nově**: generátor `data/*.json` z `tiles.json`; `--check` = idempotence bez zápisu, `--only`, nevyřešené do `content-report.json` | `--only items --check` **exit 0** (sha256 `f6c9a612…`); plný `--check` **exit 2** = 14 generátorů chybí; **mutace** (1 bajt / prázdné `{}`) → **exit 1**; neznámé `--only` → exit 1 |
| `tools/uoextract/anim.py` | zdroj animací (`anim.mul` vs `AnimationFrame*.uop`), tabulky framů | `--self-test` 22 kontrol, `--verify` 22 kontrol proti instalaci |
| `research/probe/anim_pokryti.py` | reprodukovatelné měření pokrytí těl | dává 270 / 318 těl, prunik 2 — zapsáno v `research/anim-mereni.md` |
| `tools/gates/check-assets.py` (G6) | nově měří i manifest animací | `--self-test` 4 případy; běh nad repem `OK` |
| `tools/gates/run-all.py --self-test` | nově pouští i `anim.py` | 19 self-testů (10 bran + 9 extrakčních nástrojů), 0 chyb |
| `tools/uoextract/atlas.py` (granule `assets.atlas`) | shelf-pack do 2048² + `manifest.json` (17 436 spritů, 198 stran) s `ox`/`oy` z ClassicUO | `--self-test` **30 kontrol** — ale na 6 spritech, tedy **slepý na překryvy** (záznam 2026-10-06); živý běh `assets/uo/manifest.json` 3 565 629 B; `--verify` hlásí **17 prázdných spritů** = **neopravená vada**; **NENÍ v gitu** |
| `_analyza/sonda-zapisu.py` (gitignore) | zapíše a smaže soubor v 19 cestách stromu — rozliší „nejde zapsat nic" od „nejde zapsat do podsložek" | před opravou 1/19, po přepnutí na plný přístup 19/19 |
| `_analyza/acl/` (gitignore) | zálohy ACL + protokol `acl-report-*.jsonl` (14 grantů, všechny ověřené) | `RECAP` v protokolu: `GRANTED=14 REFUSED=0 RESTORED=0` |
