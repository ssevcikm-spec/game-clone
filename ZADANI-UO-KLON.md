# ZADÁNÍ: Věrný klon Ultima Online (single-player, offline)

> **Tohle je hlavní zadání.** Je psané tak, aby se dalo předat AI agentovi
> (nebo týmu agentů) jako jediný vstupní dokument. Všechno podstatné je v něm;
> detaily jsou v `docs/`, na které se odkazuje.
>
> **Rozsah:** hratelná offline hra, která se principielně chová jako Ultima
> Online (T2A/Renaissance + AoS prvky) — pohyb, interakce, souboj, obchod,
> sběr, výroba, skilly a obsah — nad **originálními datovými soubory UO
> Classic**, které jsou na této stanici.
>
> **Není to MMO.** Žádný server, žádná síť, žádný druhý hráč.

---

## 0. Jak máš pracovat (přečti první)

1. **Přečti zadání celé**, než začneš psát kód. Pořadí: tento soubor → `docs/01`
   (cíl) → `docs/04` (architektura a smlouvy) → `docs/07` (granule a milníky)
   → `docs/08` (brány) → `docs/09` (pravidla pro agenta).
2. **Pracuj po granulích.** Granule = jeden soubor, jednoznačné zadání,
   ověřitelný výsledek. Strojově čitelný seznam je `.forge/roadmap.json`
   (klíč `grains`, 100 granul, DAG).
3. **Nikdy nepřeskakuj úroveň.** Cíl → požadavky → architektura → smlouvy →
   granule. Když narazíš na něco, co nemá předka v zadání, **zastav a nahlas
   to** — je to drift, ne úkol.
4. **Smlouvy jsou zdroj pravdy.** Tvary dat, jména funkcí a přijímací
   kritéria bereš z `docs/04`; nevymýšlej vlastní jména API.
5. **„Hotovo" = soubor je v `main` A brána jeho funkci zavolala A přijímací
   kritérium proběhlo s konkrétní hodnotou.** „PR je sloučené" ani „testy jsou
   zelené" nestačí.
6. **Když si nejsi jistý, řekni to.** `UNVERIFIED` + co je potřeba změřit je
   správná odpověď. Vymyšlené číslo je vada.
7. **Nic z toho, co je v `docs/09` §9.10 zakázané**, neimplementuj ani
   „dočasně".

---

## 1. Co má vzniknout (cíl a měřitelná věrnost)

**Cíl jednou větou:** jedna hratelná offline hra s izometrickým světem
z dlaždic 44×44, pohybem po krocích, předměty které se berou/nosí/používají/
vyrábějí, NPC se kterými se obchoduje a soubojem se skilly, které rostou
používáním — nad originálními daty UO Classic.

**Dvanáct věrnostních bodů** (každý musí být ve hře dohledatelný a ověřitelný):

| # | Bod | Detail |
|---|---|---|
| V1 | Ovládání jako UO | `docs/05` §5.3 |
| V2 | Pohyb po krocích | `docs/05` §5.1 |
| V3 | Interakce mezi objekty | `docs/05` §5.2 |
| V4 | Manipulace (zvedni/polož/nasaď) | `docs/05` §5.4 |
| V5 | Souboj | `docs/05` §5.5 |
| V6 | Magie | `docs/05` §5.6 |
| V7 | Obchod | `docs/05` §5.9 |
| V8 | Sběr surovin | `docs/05` §5.7 |
| V9 | Výroba | `docs/05` §5.8 |
| V10 | Vývoj skillů | `docs/05` §5.10 |
| V11 | Obsah předmětů, nástrojů, výzbroje, výstroje | `docs/06` |
| V12 | Svět a čas | `docs/05` §5.11, §5.12 |

**Hlavní smyčka, která definuje hotovou hru** (`docs/01` §1.3): koupit nástroj
u kováře → vytěžit rudu → vytavit ingoty → vykovat zbraň (skill stoupne) →
bojovat s potvorem → vzít loot a prodat → uložit a načíst bez ztráty →
umřít a nechat se vzkřísit. Když kterákoli věta nefunguje, hra **není hotová**.

---

## 2. Nezpochybnitelná technická rozhodnutí

| Věc | Hodnota |
|---|---|
| Engine | **Godot 4.7.2**, GDScript (typovaný), headless testy |
| Architektura | **klient/server v jednom procesu**: `sim/` = autorita, `ui/` + `render/` = tenký klient, spojení přes `Command` a `Event` (`docs/04` §4.1–4.4) |
| Simulace | pevný tick **50 ms**, čas v ms (int), **žádné floaty ve stavu**, deterministický RNG (PCG32) |
| Svět | dlaždice **44×44**, krok izometrie **22 px**, `z` scale **4 px**, faceta 0 (Felucca) 7168×4096, start Britain (1495,1630) |
| Pohyb | chůze **400 ms**, běh **200 ms**, mount 200/100 ms, otáčení 80 ms |
| Skilly | **58 id, hodnoty v desetinách** (int 0–1000/1200), strop **700.0**, krok **+0.1**, GGS zapnutý |
| Postava | `hits_max = 50 + STR/2`, `stam_max = DEX`, `mana_max = INT`, stat cap 225 |
| Obchod | `buy_price = 1.90 × sell_price`, restock 60 min, zlato váží 0.02 |
| Uložení | JSON + gzip, `state_hash` round-trip musí sedět |
| Jazyk hry | anglické názvy (jsou v datech UO), UI texty anglicky, `locale/*.json` pro překlad |

Úplný seznam včetně odůvodnění: `docs/02-technicka-rozhodnuti.md`.
**Co je zakázané** (nové závislosti, fyzika enginu, floaty ve stavu, čtení
`.mul` z herního kódu, mazání cizího API, „vylepšení"): `docs/01` §1.5
a `docs/09` §9.10.

---

## 3. Data a assety (kde je vzít)

**Zdroj:** `D:\Games\Electronic Arts\Ultima Online Classic` (verze `1.25.35`) —
**read-only**. Extrahuje se nástrojem `tools/uoextract/` (Python 3.12),
výstup jde do `assets/uo/` (**gitignore**, necommitovat!).

| Co | Soubor v instalaci | Stav znalosti |
|---|---|---|
| Art dlaždic a předmětů | `artLegacyMUL.uop` (149 MB) | UOP/MYP0, portovat z ClassicUO (BSD-2) |
| Gumpy (UI) | `gumpartLegacyMUL.uop` (78 MB) | totéž |
| Vlastnosti dlaždic a předmětů | `tiledata.mul` (3,19 MB) | **VYŘEŠENO**: land 512 skupin × (4B+32×30 B) od offsetu 4, item 2048 skupin × (4B+32×41 B) od 493 568, rezerva **0 B**, 65 536 předmětů; vrstvy ověřeny na 1268 Wearable předmětech (`docs/03` §3.3.1) |
| Barvy | `hues.mul` | **OVĚŘENO semanticky**: 375 skupin × (4 B + 8 × 88 B) = 3000 sad; text `Hue (X->Y)` sedí s poli 1000/1000 |
| Animace | `anim*.mul` (149–212 MB) + `AnimationFrame*.uop` | rozhodnout zdroj podle pokrytí těl |
| Mapa a statiky | `map0LegacyMUL.uop`, `statics0.mul`, `staidx0.mul` | blok 196 B = **u32 + 64 × 3 B** (`u16 tile_id`, `i8 z`); statics 7 B, index 12 B |
| UOP kontejner | `artLegacyMUL.uop`, `gumpartLegacyMUL.uop` | **art se extrahovat PODAŘILO** (a je vidět: meč je meč). Dva rozpory k rozhodnutí testem: (a) hash jména záznamu — `hashlittle2` vs `CreateHash` (jedna větev 100 %, druhá 1 636/2 000), (b) komprese gumpart — BWT vs zlib. Rozhoduje test, ne zdroj (`docs/03` §3.5.4, R1/R2) |
| Statický art | — | index statického artu = **`tiledata_id + 0x4000`** |
| Skilly | `skills.mul` (58 jmen), `skillgrp.mul` (6 skupin) | **OVĚŘENO** |
| Chování | `doors.txt` (37 kategorií), `stairs.txt` (19), `teleprts.txt`, `misc.txt` | **PŘEČTENO** — použij jako data |
| Nápověda k interakcím | `Tilehelp.enu` | **kontrolní seznam interakcí** (`docs/05` §5.2.3) |
| Hudba/zvuky | `Music/Digital/*.mp3` (93), `soundLegacyMUL.uop` | pro lokální build; pro veřejné vydání CC0/CC-BY |

**Licence:** portovat kód smíš z **ClassicUO (BSD-2)** a **SphereServer
(Apache-2.0)**; ze **ServUO a ModernUO (GPL) smíš brát jen fakta** (čísla,
vzorce, tabulky), **nikdy jejich kód**. Zapiš do `CREDITS.md`.

**Ověřeno o instalaci** (rozměry, počty, layouty): `docs/11` §11.1.
**Nevyřešené otázky** (nic z toho se nesmí domyslet): `docs/11` §11.6.

---

## 4. Architektura a smlouvy (zkratka)

```
app/   scéna, vstup → Command, smyčka, menu
  │
ui/ + render/   tenký klient: gumpy, kurzory, drag&drop, chunkový renderer
  │  ▲  čte jen snapshot + události, píše jen Command
  ▼  │
sim/   autorita: world (mapa, průchodnost, dveře, čas, spawn)
       ├ entity (mobile, item, container, equipment, stats, skills, notoriety)
       └ systems (movement, interaction, combat, magic, skill_gain, harvest,
                  craft, ai, vendor, loot, death, poison, regen, hunger, decay)
core/  iso projekce, RNG, hodiny, serialy, události, hash stavu, konstanty
```

**Pravidla, která hlídá brána:** `sim/` nesmí volat `ui/render/app` ani
`Input`, `Time`, `OS`, `randf()`; `ui/` a `render/` nesmí měnit stav `sim/`.
Plné tabulky komponent, příkazů, událostí a **smluv s tvary dat a přijímacími
kritérii** jsou v `docs/04` §4.2–4.6.

**Příklad smlouvy (takto vypadá každá):**
```
sim.movement.request_step(m, dir, run) -> {ok:bool, delay_ms:int, reason:String}
volá: sim.commands.dispatch
kritérium: volná dlaždice + chůze → {ok:true, delay_ms:400};
           voda (Wet) → {ok:false, reason:"blocked"};
           diagonála u zdi → hráč {ok:false, reason:"diagonal"}, NPC {ok:true}
```

---

## 5. Rozpad práce: milníky a granule

| # | Milník | Na konci je vidět |
|---|---|---|
| M0 | Kostra a pravidla | testy a brány běží, simulace tickuje |
| M1 | **Data a svět** | mapa Britainu na obrazovce, postava stojí nohama na dlaždici |
| M2 | Pohyb a interakce | chůze, dveře, teleporty, jména, kurzor, použití předmětů |
| M3 | Předměty a manipulace | zvedni/polož/nasaď/kontejnery, váha a stacky |
| M4 | Skilly, sběr, výroba | ruda → ingot → dagger, skill roste, gump výroby |
| M5 | Souboj a smrt | kostlivec, loot, smrt, duch, vzkříšení |
| M6 | Magie | 64 kouzel s many a reagenty, spellbook a svitky |
| M7 | Ekonomika a svět | vendor, banka, spawny, 3 dungeony, den/noc |
| M8 | Trvanlivost | uložení, determinismus, replaye, výkon, vydání |

**Granule:** `.forge/roadmap.json` (100 granul, DAG ověřen lintem).
Každá má `owns` (jeden soubor), `depends_on`, `provides`, `consumes`,
`acceptance`, `size_lines`, `model` a `prompt`.

**První vlna (W0), může běžet paralelně:**
`core.const`, `core.iso`, `core.rng`, `core.clock`, `core.serial`,
`core.events`, `core.hash`, `data.balance` — pak `sim.commands`,
`sim.world_loop`, `app.main`, `app.loop`, `app.input`.

**Nejtěžší část je M1** (extrakce dat) — layout `tiledata.mul` je už vyřešený,
ale port a ověření zbývá. **Vrstvy, váhy a ceny se nikdy nehardcodují** —
berou se z dat; co v datech není, se vybírá podle vlastností a označí
`source` (`docs/10` P19, `docs/03` §3.3.1b).

---

## 6. Brány: co musí projít a co znamená zelená

| Brána | Co hlídá |
|---|---|
| G1 schéma | rozpor v zadání (konstanty vs. data vs. kód vs. kreslení) |
| G2 vrstvy | `sim/` nesahá do `ui/render/app`, žádné `Input`/`Time`/`rand` v sim |
| G3 testy | chování simulace (bez scény a assetů) |
| G4 zapojení | každé `provides` je volané z produkčního kódu, `_on_*` připojené |
| G5 obsah | schémata `data/`, existence art ID, křížové odkazy, počty C1–C10 |
| G6 assety | manifest vs. stránky atlasu, prázdné sprity, offsety |
| G7 uložení | round-trip `state_hash` |
| G8 determinismus | dva běhy → stejný hash |
| G9 replaye | skriptované sekvence dají očekávaný hash |
| G10 render | hra kreslí podle dat; postava **není překrytá** |
| G11 smoke | běh bez `SCRIPT ERROR` |
| G12 výkon | tick ≤ 2 ms, frame ≤ 16 ms |
| G13 vision | **poradní**: je na snímku to, co má být (neblokuje) |

**Zelená znamená jen tohle:** brána **proběhla** (změřila nenulový počet
objektů), **neselhala** a její **mutační test** prokazatelně spadne.
Když kontrola nic nezměřila, hlásí se **NEMĚŘENO** — a to není úspěch.
Zakázané podoby bran (podmíněný test, zelená nad prázdnem, čtení komentářů,
„soubor existuje"): `docs/08` §8.6.

---

## 7. Pasti, které už někoho stály čas (nešlapej do nich)

1. **Podmíněný test je tiše zelený** — `if load(...) != null:` přeskočí práci
   a nikdo to nepozná. Pro soubory, které mají existovat, test **musí spadnout**.
2. **Nula a prázdno nejsou úspěch** — brána nad prázdným seznamem je slepá.
3. **Statická kontrola nesmí číst komentáře** — komentář popisující vadu
   vypadá jako vada.
4. **Fáze mřížky** — při hledání layoutu v binárním souboru hledej **stride
   i fázi**, jinak správná varianta vyjde jako náhoda (naměřeno na `tiledata.mul`).
5. **Float ve stavu = drift** — skilly v desetinách, čas v ms.
6. **Nedeterministické pořadí iterace** rozbíjí `state_hash`.
7. **`.godot/` není v gitu** → v čerstvém stromu „regresují" assety.
8. **Godot `user://` je mimo workspace** → v testech přesměruj `APPDATA`.
9. **Exit kód a výstup si mohou odporovat** → čti oba.
10. **`TileMapLayer` neumí UO řazení** → vlastní renderer s jednou funkcí řazení.
11. **Různé čítače mají stejné jméno** → u každého čísla si napiš, odkud je.
12. **GPL zdroje jen na fakta** → nekopíruj kód ze ServUO/ModernUO.

Celý registr (23 položek, každá naměřená): `docs/10-rizika-a-pasti.md`.

---

## 8. Když narazíš na nevyřešenou věc

| Situace | Co udělat |
|---|---|
| `tiledata.mul` (postup) | layout je **vyřešený** (`docs/03` §3.3.1); jde jen o port a ověření vah/hodnot. **Když by port neseděl, nehádej vrstvy/váhy/ceny** — zapiš měření |
| `Cliloc.enu` (postup) | je **BWT-komprimovaný** (`docs/03` §3.3.2); použij anglická jména z tiledata a kliloky jen tam, kde jsou nutné |
| **Jména předmětů nejsou klasická** | tato instalace má moderní/přejmenovanou sadu (`gargoyle_leather_arm`, `leather cap`, …) — **nikdy nehardcoduj klasická jména ani tile id z hlavy**, vybírej podle vlastností (`docs/03` §3.3.1b) |
| Číslo není nikde ověřené (stamina při běhu, stat loss, světelný cyklus) | `UNVERIFIED` + konfigurační flag + zapsat do `docs/11` §11.6 |
| Smlouva je nejasná | zastav, oprav **nejdřív smlouvu v `docs/`**, pak kód |
| Potřebuješ cizí soubor | není to tvoje granule — zapiš požadavek a skonči |
| Dvě možnosti, obě věrné | vyber podle `docs/`, a když tam rozhodnutí není, zapiš ho tam |

---

## 9. Přijímací kritéria celku (jak se hodnotí výsledek)

1. **Smyčka `docs/01` §1.3 projde celá** — člověk, bez ručního zásahu do souborů.
2. **V1–V12** dohledatelné a ověřené spuštěním.
3. **Snímek hry** ukazuje dlaždicovou krajinu, postavu se zbraní, jméno a HUD.
4. **Determinismus:** dva běhy téhož skriptu dají stejný `state_hash`.
5. **Uložení/načtení:** hash před == hash po.
6. **Všechny brány projdou a každá má mutační test.**
7. **Lidská známka 1–5** za to, jak moc to „je UO".

---

## 10. Rychlý přehled čísel, která nesmíš splést

| # | Věc | Hodnota |
|---|---|---|
| 1 | Chůze / běh pěšky | 400 / 200 ms |
| 2 | Chůze / běh na mountu | 200 / 100 ms |
| 3 | Otočení / frame animace | 80 / 80 ms |
| 4 | `PERSON_HEIGHT` / `STEP_HEIGHT` | 16 / 2 |
| 5 | Dosah zvednutí a položení | 2 dlaždice |
| 6 | Max. stack | 60 000 |
| 7 | Kontejner / batoh | 125 předmětů, 400 stones / 400 (550 ML+) |
| 8 | `hits_max` / `stam_max` / `mana_max` | `50 + STR/2` / DEX / INT |
| 9 | Stat cap / skill cap | 225 / 700.0 (720) |
| 10 | Krok skillu | +0.1 |
| 11 | Kriminální flag / vrah | 2 min / 5 vražd |
| 12 | Vzkříšení | hp = 10 |
| 13 | Rozpad těla / předmětu na zemi | 7 min / 60 min |
| 14 | Restock vendora | 60 min |
| 15 | Ceny | buy = 1.90 × sell |
| 16 | Zlato | 0.02 stones |
| 17 | Spawn | 5–10 min, refill 1/3 |
| 18 | Faceta 0 | 7168 × 4096 |
| 19 | Herní den | 7200 s (2 h reálné) — `SecondsPerUOMinute = 5.0` |
| 20 | Světlo: den / dungeon | 12 / 26 |
| 21 | Mana kouzel 1.–8. kruhu | 4, 6, 9, 11, 14, 20, 40, 50 |
| 22 | Swing delay (AoS) | `floor(40000/swiftness) × 0.5 s`, min 1.25 s |
| 23 | Hit chance (AoS) | `((atk+20)×(100+HCI)) / (2×(def+20)×(100+DCI))`, strop 45 |
| 24 | Prodleva sesílání (AoS) | `(4+kruh)×0.25 − FC×0.25`, min 0.25 s |
| 25 | Tavení | ore → ingot 1:1, skill gate 50–99 |
| 26 | Zpětné tavení | `floor(66 %)` ceny předmětu |

(Plná tabulka 40 čísel s citacemi `soubor:řádek`: `research/01` §6.)

---

## 11. První tři kroky, kterými začneš

1. **Ověř, že prostředí žije:** spusť `godot --headless --path . --script
   res://tests/run_tests.gd` (po bootstrapu) a `python tools/check-docs-refs.py`.
   Když něco neexistuje, je to bootstrap — ne tvoje granule.
2. **Vezmi vlnu W0** z `docs/07` §7.3 a udělej `core.const` + `core.iso` +
   `core.rng` (tři nezávislé soubory, dají se dělat paralelně).
3. **Než začneš M1**, přečti `docs/03` §3.3.1 a `docs/10` P5 — ušetří ti to
   tři mrtvé sondy, které jsem na `tiledata.mul` spálil já (a vysvětlí, proč
   „číslo, které nějak vychází", není důkaz).
