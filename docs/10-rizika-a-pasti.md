# 10. Rizika a pasti (naměřené, ne teoretické)

> Každá past v tomhle oddílu **skutečně nastala** — buď na této stanici
> v projektu `uo-shadows`/`orchestra`, nebo při průzkumu dat pro tenhle projekt.
> U každé je: **jak vypadá**, **proč to mate**, **co dělat**.
>
> Pravidlo nad všemi: **„Nula a prázdno nejsou úspěch."** Když měření nic
> nezměřilo, musí to být vidět.

## P1 — Podmíněný test je tiše zelený

**Jak vypadá:**
```gdscript
if load("res://scripts/save.gd") != null:
    _check(save.has_method("save"), "...")
```
**Proč to mate:** dokud soubor neexistuje, kontrola se **přeskočí** a běh je
zelený. Když soubor vznikne vadný, test ho zkontroluje jen povrchně
(`has_method`) — a zelená znamená „existuje", ne „funguje".
**Co dělat:** pro soubory, které existovat **mají**, je kontrola
**nepodmíněná** a **musí spadnout**, když funkce chybí. Pro ty, které teprve
vzniknou, veď **viditelný stav**: `_check(true, "craft.smelt: zatím není
(granule není hotová)")` — nikdy ticho.

## P2 — Brána měří přítomnost, ne chování

**Jak vypadá:** `_check(node.has_method("gather"), "gather existuje")`.
**Proč to mate:** projde i nad funkcí, která vždy vrátí `null` nebo spadne.
Naměřeno: `hud.gd` se v `_ready()` rozbil na Godot 3 API (`margin_left`)
a label se nikdy nepřidal — test se ptal jen `has_method("update")`.
**Co dělat:** volej funkci a **měř výsledek**: `gather(ore, 5) == 6`.

## P3 — Zelená nad prázdným seznamem

**Jak vypadá:** kontrola hledá v kódu vzor; po refaktoru vzor zmizí, cyklus
proběhne nad `[]` a vypíše „vše v pořádku".
**Naměřeno:** `check-schema.py` hledal `var cell := 16`, po migraci na
izometrii je v kódu `const CELL_W_DEFAULT := 96` → `výchozí cell=[]` a zelená.
**Co dělat:** když kontrola nemá co měřit, **řekni to** (vada nebo aspoň
poznámka), a nikdy netištěte `[]` jako výsledek měření.

## P4 — Statická kontrola čte komentáře

**Jak vypadá:** kontrola hledá zakázaný řetězec a **najde ho v komentáři**,
který vadu popisuje jako historii.
**Proč to mate:** hlásí vadu i po opravě → nutí „opravovat" správný kód.
**Co dělat:** před hledáním vzorů **odstraň komentáře**
(`radek.split("#", 1)[0]`, u JS `//` a `/* */`).

## P5 — Fáze mřížky (past, na které jsem spálil tři sondy při průzkumu UO dat)

**Jak vypadá:** hledáš `(stride, name_off)` v binárním souboru a vzorkuješ
od pevného offsetu. Správný stride vyjde jako **náhoda**, protože mřížka leží
na **jiné fázi** (`offset mod stride`), než na kterou vzorkuješ.
**Naměřeno u `tiledata.mul`:** jména předmětů mají krok 41 B (`anvil` na
658 708 a 658 749), ale fáze se mezi shluky liší; mřížka bez fáze dala
stride 20/22/30 s ~15 % „čistých jmen" a **správnou** variantu zahodila.
**Co dělat:** vždy hledej **stride i fázi** (`pro p in range(stride)`) a
výsledek ověř **druhým nezávislým kritériem** (velikost souboru, rozumné
hodnoty polí, jméno které musí odpovídat číslu — jako u `hues.mul`, kde text
`Hue (6->1080)` sedí s poli `start=6, end=1080`).

## P6 — Dvě jména téhož klíče = tichá ztráta dat

**Naměřeno:** šablona psala do konfigurace `popis_stylu`, ale kód četl
**pouze** `styl_popis` → celá vizuální kontrola běžela bez stylu a nikdo
o tom nevěděl.
**Co dělat:** při přejmenování klíče čte kód **obě** jména a pro každé
existuje test. Než z konfigurace něco smažeš, najdi **všechna** místa, kde se
to čte.

## P7 — Hash není důkaz, že se nic nezměnilo

**Naměřeno:** percepční hash (`phash`) je **slepý na barvu** (červená a modrá
se stejnými bloky → stejný hash) a **degeneruje u jednolitého obrázku**.
Přebarvený asset by prošel jako „nezměněný".
**Co dělat:** pro cache a schvalování ukládej **barevný podpis** i hash;
u degenerovaných případů porovnávej přesný `sha256`; a když se hash nedá
spočítat, vrať `None` — nikdy nulu.

## P8 — `.godot/` není v gitu → testy v čerstvém stromu „regresují"

**Naměřeno:** v `git worktree` testy hlásily 3 selhání (assety se nenačtou),
protože `.godot/` je ignorovaný a Godot v režimu `--script` assety
**neimportuje**. V hlavním klonu bylo 59 kontrol / 0 selhání.
**Co dělat:** než označíš výsledek za regresi, **zeptej se, které soubory
v tom stromu jsou**. Do worktree zkopíruj `.godot/` (nebo spusť import).

## P9 — Godot `user://` je mimo workspace (a nástroj to neřekne)

**Naměřeno:** `--user-data-dir` tento build **ignoruje**; `user://` jde do
`%APPDATA%\Godot\app_userdata\<projekt>`. V sandboxu zápis selže a
`ConfigFile.save()` vrátí chybu 7 — vypadá to jako vada ukládání.
**Co dělat:** v testech a CI přesměruj `APPDATA` do workspace a **ověř**, kam
se ukládá: `print(ProjectSettings.globalize_path("user://"))`.

## P10 — Exit kód a výstup si odporují

**Naměřeno:** `--headless` testy vypsaly „N kontrol, 0 selhání" a přesto
skončily nenulovým kódem (úklidové volání na stderr). A naopak: skript bez
`assert` a bez `sys.exit` vypsal „CHYBA" a skončil `exit 0`.
**Co dělat:** čti **oba** údaje a v CI vyžaduj **shodu** (výsledek testů
i exit kód). Každý test musí mít assert **i** nenulový exit při selhání.

## P11 — Brána je slepá na soubory, které neleží tam, kam čeká

**Naměřeno:** `check-assets.py` hledá `assets/sprites/walk_*.png`, ale chůze
je rozložená po vrstvách jinde → kontrola shody siluet se **nikdy
neuplatní**, i když ji spec deklaruje.
**Co dělat:** brána musí **ohlásit, že kontrola neproběhla** (a proč), místo
aby tiše přeskočila. A když soubor, který součástí hry být má, chybí, je to
**selhání**.

## P12 — Různé čítače nesou stejné jméno

**Naměřeno:** dokument tvrdil „běhy #355–#362", API hlásilo `run_number`
#235–#241; „20 běhů celkem" proti `total_count` 241. Nikdo nelhal — sečetly
se různé čítače téhož jména.
**V tomhle projektu už jeden takový případ je:** výzkumný dokument má
v souhrnné tabulce `Full in-game day = 120 real seconds`, ale kód
(ServUO `Scripts/Items/Tools/Clocks.cs:28`, ModernUO `…/Tinkering/Clocks.cs:22`,
ověřeno na této stanici) říká `SecondsPerUOMinute = 5.0` → 1440 herních minut
× 5 s = **7200 s = 2 reálné hodiny**. Tabulka je špatně, kód je správně.
**Co dělat:** u každého čísla si napiš **odkud je** (soubor:řádek, datum,
příkaz) a při rozporu **změř znovu**, neopravuj dokument podle dokumentu.

**A ještě jeden případ téhož druhu, naměřený při psaní tohoto zadání:**
skript na opravu odkazů hlásil `změněných znaků 0` — a přitom **opravil pět
odkazů**. Metrika měřila **délku**, a `§8.10` → `§5.10` má stejnou délku.
Kdybych věřil jí, „oprava neproběhla" a šel bych hledat vadu, která není.
Skutečný důkaz byl jiný: „zbylé odkazy `§8.x`: žádné" + validátor.
**Obecně: metrika, která má vyjít nulová i při provedené práci, není metrika.**

**A třetí případ, zákeřnější:** validátor odkazů prošel u `§8.1`–`§8.9`, protože
ty sekce v dokumentu o branách **skutečně existují** — odkaz se „rozřešil" na
**jinou** sekci, než autor myslel. Sada odkazů může být syntakticky v pořádku
a věcně vedle. Proto se odkazy kontrolují **i podle významu** (patří odkaz
k tématu?), ne jen podle existence cíle.

## P13 — Float ve stavu = tichý drift

**Proč to mate:** `0.1` nejde v binárním floatu přesně; skilly po 10 000
cvicích nesedí na desetinu, porovnání `skill == 100.0` selže a save/load
round-trip přestane vycházet.
**Co dělat:** skilly **v desetinách** (`int`, 1000 = 100.0), čas v ms (int),
pozice v dlaždicích (int), `z` v jednotkách světa (int). Float jen pro
vykreslování a kosmetiku.

## P14 — Godot 3 API v Godot 4 projektu

**Naměřeno:** `margin_left`, `node.has()`, `/root/Skills`, `yield`.
**Co dělat:** kompilace to nechytí (runtime chyba), takže: `has_method()`,
`add_theme_constant_override()`, `await`, a **vždy** spustit hru headless
jako součást brány (smoke), která runtime chyby odhalí.

## P15 — Nedeterministické pořadí iterace

**Proč to mate:** `Dictionary.keys()` a množinové operace nemusí mít stabilní
pořadí; stačí jedno místo a `state_hash` se mezi běhy liší → testy
determinismu blikají a replaye nesedí.
**Co dělat:** iteruj přes **seřazené** klíče, entity podle `serial`, recepty
podle `id`. `state_hash` počítej z kanonické serializace.

## P16 — Instalace UO se pod projektem změní

**Proč to mate:** patch klienta přepíše `tiledata.mul` → art ID a vrstvy
přestanou odpovídat uloženým hrám a manifestu; hra „náhle" kreslí jiné věci.
**Co dělat:** manifest obsahuje **SHA-256 vstupních souborů**; extraktor při
neshodě **skončí s hláškou**, ne tiše přegeneruje.

## P17 — Načíst všechen art = konec paměti

**Proč to mate:** 65 536 item artů + animace těl jsou stovky MB; Godot se
pokusí importovat vše a start hry trvá minuty.
**Co dělat:** extrahuj a načítej **jen referencované** art ID (obsah z `data/`)
a zbytek on-demand; `TextureCache` s LRU a stropem (§2.7).

## P18 — Licence referenčních zdrojů

**Naměřeno na této stanici** (klony v `_src/`, kontrola licenčních souborů):

| Projekt | Licence | Smí se portovat kód? |
|---|---|---|
| **ClassicUO** | BSD 2-Clause | **ANO** (s uvedením autora) — čtení art/uop/gump formátů |
| **SphereServer Source-X** | Apache 2.0 | **ANO** (s uvedením) |
| ServUO | GPL v2 | **NE** — jen jako **dokumentace chování** (čísla, vzorce, tabulky) |
| ModernUO | GPL v3 | **NE** — totéž |

**Co dělat:** portuj **algoritmy** z BSD/Apache zdrojů; z GPL zdrojů ber
**fakta** (konstanty, tabulky, vzorce) a **napiš vlastní kód**. Do `CREDITS.md`
patří, které repo bylo zdrojem čeho. **Nikdy nekopíruj kód z GPL projektu** —
jinak se celá hra dostane pod GPL.

## P19 — Vrstvy a váhy předmětů nejsou v serverovém kódu

**Naměřeno:** ServUO přiřazuje vrstvu z **klientských dat**:
`Layer = (Layer)ItemData.Quality;` — tedy z `tiledata.mul`. Totéž váhy.
**Důsledek:** dokud není `tiledata.mul` přečtený (§3.3.1), **nesmí** se
vrstvy ani váhy hardcodovat do `data/items.json` „od oka".
**Co dělat:** vrstvy/váhy brát z tiledata; do `data/` psát jen to, co
v tiledata není (recepty, AI, ceny, spawny), a označit to zdrojem.

## P20 — Nápověda v klientu je skvělý zdroj, ale musí se ověřit

**Co je naměřeno:** `Tilehelp.enu` obsahuje originální věty typu
„Double-clicking ore will bring up a targeting cursor… target a forge…
smelt the ore into ingots using your mining skill." Je to **nejlepší popis
interakčního modelu, jaký v datech je** — ale je to **text**, ne kód.
**Co dělat:** použij ho jako **kontrolní seznam interakcí** (§5.2) a každou
větu ověř proti chování v simulaci. Text, který vadu jen popisuje, není důkaz
(viz P4).

## P21 — `TileMapLayer` neumí UO řazení

**Proč to mate:** Godotí `TileMapLayer` s `y_sort` vypadá „skoro správně",
ale UO řadí **v rámci dlaždice podle `z`** (statiky pod sebou, mobilové mezi
nimi) a používá `Surface` pro povrch. Výsledek: postava mizí za zdí, střecha
překrývá hlavu, schody kreslí špatně.
**Co dělat:** vlastní renderer s **jednou** funkcí řazení
(`render/sort.gd`, §2.4) a testem, který na dvou objektech stejné dlaždice
s různým `z` ověří pořadí.

## P22 — „Kontrola proběhla?" je důležitější než „neprotestovala?"

**Naměřeno vícekrát:** `check-wiring.py` na projektu bez `scripts/*.gd`
vrátí **zelenou nad nulou souborů** („Vše v pořádku: každá funkce je odněkud
volaná") s `exit 0`. Je to nejnebezpečnější druh brány: nespadne, neohlásí
se, jen přestane měřit.
**Co dělat:** každá brána na konci vypíše **počet změřených objektů** a když
je nula, **selže** (nebo aspoň výslovně řekne „NEMĚŘENO"). A každá brána má
**offline test se známým správným i známým vadným vstupem** (mutační test).

**A pozor: i mutační test se dá udělat špatně.** Naměřeno při psaní tohoto
zadání: do dokumentu jsem vložil vadu „Chuze je 500 ms" a kontrola
`check-zadani.py` **prošla** — protože hledá vzor `WALK_MS = 500`, ne českou
větu. Test tedy „nepotvrdil díru v kontrole", ale **netestoval to, co kontrola
tvrdí, že umí**. Po vložení vady, kterou kontrola **slibuje** chytit, spadla
správně.
**Pravidlo:** mutační test musí vložit **takovou** vadu, kterou brána deklaruje,
že chytí — a brána musí mít **napsané, co nechytá** (u `check-zadani.py`:
„hlídá známé vadné literály, ne libovolný rozpor v próze").

## P23 — Souběh: dva agenti v jednom souboru

**Naměřeno:** 12 úloh sahajících do jednoho `game.gd` → konflikty a ztracená
práce.
**Co dělat:** `owns` je výlučné, 1 granule = 1 soubor, registrace se vyčleňuje
zvlášť (§9.7).

## P24 — Model, který sedí na velikost souboru a projde na vzorku, není důkaz

**Naměřeno na mě samém při psaní tohoto zadání (a je to nejcennější past
v celém seznamu).** U `hues.mul` jsem „ověřil" layout:

> 4B hlavička + **3017** záznamů × 88 B = 265 500 B přesně, a sebekontrola
> „text `Hue (6->1080)` sedí s poli `start`/`end`" dala **47/47**.

Jenže správný layout je **375 skupin × (4 B + 8 × 88 B) = 3000 sad**. Oba
modely dávají přesně 265 500 B a **oba projdou na části záznamů** — protože
plochá mřížka se posune o 4 bajty až po osmi záznamech, takže **první skupina
sedí úplně** a zbytek se rozjede. Můj test vzorkoval prvních 400 záznamů
a narazil na 47 shod uvnitř první skupiny; „0 nesouhlasů" byla pravda
o vzorku, ne o souboru.

**Rozhodl až test na celém souboru:** 1000/1000 shod pro skupinový model,
47 pro plochý. A druhý, na modelu nezávislý důkaz: v `tiledata.mul` tvoří
mezery mezi jmény z 97 % 41 B, ale **3,24 % je 45 B** (= 41 + 4) — což je
přesně jedna 4bajtová hlavička na 32 záznamů. Model bez hlaviček předpovídá
0 %.

**Co z toho plyne (obecně):**
1. **Součet na bajt je nutná, ne postačující podmínka.** Dvě různé mřížky
   klidně vyjdou „přesně".
2. **Testuj na CELÉM souboru**, ne na vzorku — částečné shody vypadají jako
   úspěch.
3. **Přidej nulový model** (stejný počet náhodných offsetů). Když tvoje
   metrika nevyjde výrazně nad ním, neměřila nic. Naměřeno u item bloku
   `tiledata.mul`: skupinový model **13 113** čistých jmen, plochý **694**,
   náhoda **786**.
4. **Hledej důkaz nezávislý na modelu** (tady: histogram mezer mezi jmény
   a text v záznamu, který musí odpovídat číslům).
