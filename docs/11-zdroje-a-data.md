# 11. Zdroje, ověřená data a otevřené otázky

## 11.1 Co je o této instalaci OVĚŘENO (měřeno, ne převzato)

Měřeno sondami `research/probe_uo*.py` a `research/profese_parse.py`, jejichž
výstupy jsou v `research/probe-uo*.json` a `research/profese.json`.

| Zjištění | Hodnota | Jak ověřeno |
|---|---|---|
| Verze klienta | `1.25.35` | `Version.txt` |
| `hues.mul` | **375 skupin × (4 B hlavička + 8 × 88 B)** = 3000 barevných sad, 265 500 B přesně; záznam = 32 barev (u16) + `start` (u16) + `end` (u16) + 20B jméno | **OVĚŘENO semanticky** (1000/1000 souhlasů textu `Hue (X->Y)` s poli; plochý model dá jen 47) |
| `anim.idx` | 148 810 slotů × 12 B (první záznamy `-1,-1,-1` = prázdné) | dělení beze zbytku + obsah |
| `multi.idx` | 8 480 slotů × 12 B | totéž |
| `radarcol.mul` | 81 884 × uint16 | dělení beze zbytku |
| `texidx.mul` | 16 384 × 12 B | totéž |
| `skills.mul` | **58 jmen skillů** v pořadí klienta (viz tabulka níže) | přímé čtení řetězců |
| `skillgrp.mul` | 6 skupin: Combat, Trade Skills, Magic, Wilderness, Thieving, Bard | přímé čtení |
| `SKILNAME.ENU` | jména skillů v klientu, včetně pozdějších (Necromancy, Chivalry, Focus, Disarm) | přímé čtení |
| `map0` | 7168 × 4096 dlaždic = 896 × 512 bloků = 458 752 bloků × 196 B ≈ 85,8 MB | **sedí na velikost souboru** `map0LegacyMUL.uop` |
| `staidx0.mul` | 5 242 880 B / 12 = 436 906 bloků | dělení beze zbytku |
| UOP kontejnery | magic `MYP\0`, verze 4 (gump/sound/anim/multi/tileart) a 5 (art/map) | přečtené hlavičky |
| `tiledata.mul` | 3 188 736 B; **VYŘEŠENO**: land = 512 skupin × (4B hlavička + 32 × 30 B) od offsetu 4; item = 2048 skupin × (4B + 32 × 41 B) od 493 568; součet = přesná velikost, rezerva 0 B; 65 536 předmětů | **OVĚŘENO** (vrstvy sedí na jména u 1268 Wearable předmětů; `research/07`) |
| `Cliloc.enu` | 5 110 078 B; **BWT-komprimovaný** (3. bajt `0x8E` = diskriminátor, ověřeno mým měřením i zdrojem ClassicUO); pak `u32,u16` a záznamy `i32 číslo, u8 flag, i16 délka v bajtech, UTF-8 text` | **VYŘEŠENO** (`research/05` §7.1 + shoda diskriminátoru) |
| `Prof.txt` | **7 profesí**: Samurai, Ninja, Paladin, Necromancer, **Warrior, Mage, Blacksmith** (každá 4 skilly po 30, staty v součtu 90) | parsováno do `research/profese.json` |
| `doors.txt` | 37 kategorií × 8 art ID + FeatureMask + jméno | přečteno |
| `stairs.txt` | 19 kategorií (Block, N/E/S/W, Squared1/2, Rounded1/2, MultiN/E/S/W) | přečteno |
| `teleprts.txt` | kategorie teleportovacích dlaždic (např. „Alchemical Tiles" 6173–6184) | přečteno |
| `misc.txt` | kategorie × 8 dílů + TID + jméno (archways, walls) | přečteno |
| `body.def` / `Corpse.def` | formát `ORIG {NEW} HUE` (např. `11 {28} 1401`) | přečteno z komentáře i dat |
| `Bodyconv.def` | `<Object> <LBR> <AoS> <AoW> <Mondain>`; monstra 0–199, zvířata 200–399, lidé 400+, max 2048 | přečteno |
| `Equipconv.def` | `bodyType equipmentID convertToID gumpID hue` (gumpID 0 = +50000) | přečteno |
| `mobtypes.txt` | `ID TYPE FLAGS` (MONSTER/ANIMAL/HUMAN) | přečteno |
| `Tilehelp.enu` | originální nápověda k použití předmětů (dvojklik + cíl) | přečteno |
| Hudba | 93 MP3 + `Music/Digital/Config.txt` | spočítáno |
| `soundLegacyMUL.uop` | 160,6 MB + `sound.def` (mapování id → soubor) | velikost/obsah |
| Fonty | `fonts.mul` + `unifont*.mul` **bez české diakripiky** → přibalit OFL font | obsah |

**Pořadí skillů z `skills.mul` (id 0–57), jak je vede tento klient:**

```
0 Alchemy            8 Bowcraft/Fletching  16 Evaluating Intelligence  24 Lockpicking      32 Spirit Speak    40 Swordsmanship  48 Remove Trap    56 Imbuing
1 Anatomy            9 Peacemaking         17 Healing                 25 Magery           33 Stealing        41 Mace Fighting  49 Necromancy     57 Mysticism
2 Animal Lore       10 Camping             18 Fishing                 26 Resisting Spells 34 Tailoring       42 Fencing        50 Focus
3 Item Identification 11 Carpentry          19 Forensic Evaluation     27 Tactics          35 Animal Taming   43 Wrestling      51 Chivalry
4 Arms Lore         12 Cartography         20 Herding                 28 Snooping         36 Taste Identification 44 Lumberjacking 52 Bushido
5 Parrying          13 Cooking             21 Hiding                  29 Musicianship     37 Tinkering      45 Mining         53 Ninjitsu
6 Begging           14 Detecting Hidden    22 Provocation             30 Poisoning        38 Tracking       46 Meditation     54 Spellweaving
7 Blacksmithy       15 Discordance         23 Inscription             31 Archery          39 Veterinary     47 Stealth        55 Throwing
```

**Pozor — id 48–57 jsou pozdější skilly (AoS+).** Klasická éra T2A jich měla
54 (0–53) plus přejmenování (`Detecting Hidden` vs. `Detect Hidden`,
`Evaluate/Evaluating Intelligence`, `Blacksmith` vs. `Blacksmithy`). Klon
používá **všech 58 id** (drží kompatibilitu s daty), ale **mechanicky
implementuje** jen ty, které jsou v rozsahu (§5.10), a u zbytku má
`implemented: false` + viditelnou hlášku v UI. Nikdy „prázdný skill, který
tvrdí, že funguje".

## 11.2 Referenční zdroje na stanici (klony zdrojáků)

V `_src/` jsou klony čtyř open-source projektů (gitignored, read-only
reference). **Licence rozhoduje, co se smí:**

| Repo | Licence | K čemu se smí použít |
|---|---|---|
| `_src/classicuo` (BSD 2-Clause) | **portovat smí** | čtení `art/gump/uop/tiledata/map` formátů, konstanty vykreslování, řazení |
| **`DatMoshu/GodotUO`** (BSD 2-Clause) | **portovat smí** | **ClassicUO portovaný do Godot 4 (.NET)** — nejbližší referenční implementace pro integraci s enginem; pozor, používá C#, takže se z něj bere **postup**, ne kód |
| `_src/sphere` (Apache 2.0) | **portovat smí** | alternativní pohled na mechaniky, skriptovací model |
| `_src/servuo` (GPL v2) | **jen fakta** | čísla, vzorce, tabulky (recepty, monstra, ceny) — **kód nekopírovat** |
| `_src/modernuo` (GPL v3) | **jen fakta** | totéž; místy novější a přesnější |

Do `CREDITS.md`: které repo dalo které číslo. Do kódu: **žádná kopie GPL kódu**
(P18 v `10-rizika-a-pasti.md`).

## 11.3 Výzkumné dokumenty (jsou součástí zadání)

| Soubor | Obsah | Jak ho použít |
|---|---|---|
| `research/01-core-mechanics.md` (1921 řádků) | pohyb, interakce, postava, čas, ekonomika; 40 čísel „která klon nesmí splést"; 487 citací `soubor:řádek` | **normativní** pro §5.1–5.4, §5.9, §5.11 |
| `research/02-skills.md` | 58 skillů, gain, gump menu, bard/hide/steal | normativní pro §5.10 |
| `research/03-combat-magic-items.md` (2678 řádků) | 4 éry swing timingu, 2 vzorce damage, 64 kouzel, 159 vlastností předmětů, loot | normativní pro §5.5, §5.6, §6.4 |
| `research/04-gathering-crafting.md` (2332 řádků) + `04-craft-data.json` | **1150 receptů** strojově extrahovaných + engine výroby, tavení, oprava | normativní pro §5.7, §5.8, §6.3 |
| `research/05-data-formats.md` | binární formáty `.mul`/`.uop` (art, gump, tiledata, anim, mapa) | normativní pro §3.4, §3.5 |
| `research/06-world-content-npcs.md` (5164 řádků) | facety, 19 měst, 9 moongate, 15 dungeonů, 88 monster, spawnery, obchod, profese | normativní pro §5.9, §5.12, §6.5, §6.6 |
| `research/07-extractor-verification.md` | co z extraktoru **skutečně funguje** (art ověřen a viděn, statics ověřeny, tiledata předměty ověřeny; 4 rozpory s `research/05`) + funkční kód v `tools/uoextract/` a vzorky PNG | normativní pro granuli `assets.*`, ale **rozpory R1–R4 se rozhodují testem** (§3.5.4) |

**Pravidlo použití:** výzkumný dokument je **normativní tam, kde cituje kód**,
a **poradní tam, kde je označený `UNVERIFIED`/`UNCERTAIN`**. Když je v rozporu
s měřením na této stanici, **vyhrává měření** (P12). Přesně to se stalo
u `tiledata.mul`: model z `research/05` §4 jsem **změřil a vyvrátil**
(4,4 % a 6,5 % čistých jmen), takže zadání obsahuje **měření**, ne model.

## 11.4 Volné assety (když originální nestačí)

Pořadí podle poměru kvalita/čas (skill `game-assets`):

1. **Free zdroj** — [Kenney](https://kenney.nl) (CC0), [OpenGameArt](https://opengameart.org) (filtruj CC0), [Freesound](https://freesound.org) (CC0/CC-BY) pro zvuky, [Incompetech](https://incompetech.com) (CC-BY) pro hudbu, [Google Fonts](https://fonts.google.com) (OFL) pro fonty s diakritikou.
2. **Lokální generátor** — ComfyUI + SDXL (skill `imagegen-local`), reprodukovatelné seedem.
3. **Cloud generátor** — Gemini (skill `imagegen`), pixel-art a rychlé sprity.
4. **Blender 5.2.1 headless** — 3D → 2D sada (nejkonzistentnější perspektiva).

**Pravidla:** jedna sada = jeden nástroj (nemíchat styly); preferuj CC0;
u CC-BY zapiš autora do `CREDITS.md`; **CC-BY-SA se vyhni** (share-alike).
Každý asset musí projít lidskou kontrolou (`read_image`) — brána pozná
„mince je 0,67× truhly", ne „tohle není truhla".

**Hudba a zvuk:** originální MP3 ze instalace **jen pro lokální build**;
pro veřejné vydání použij CC0/CC-BY alternativy (§3.1).

## 11.5 Nástroje na stanici

| Nástroj | Cesta / jak | K čemu |
|---|---|---|
| Godot 4.7.2 | `C:\Users\Ssevc\Local-Deepseek\orchestra\tools\godot\Godot_v4.7.2-stable_win64_console.exe` | engine, `--headless` testy, snímky |
| Python 3.12 + Pillow/numpy | `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe` | extraktor, brány |
| Node.js | `…\dependencies\node\bin\node.exe` | nástroje orchestru, `fetch` (TLS z PowerShellu nefunguje) |
| `read_image` | vestavěný nástroj | **podívat se na výsledek** (v CI není — tam `vision.mjs`) |
| Blender 5.2.1 | `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` | 3D → 2D sprity (pozor: exit kód 0 i při chybě) |

## 11.6 Otevřené otázky (registr — nic z toho se nesmí „domyslet")

| # | Otázka | Stav | Jak to uzavřít |
|---|---|---|---|
| O1 | Layout `tiledata.mul` v této instalaci | **VYŘEŠENO**: land 512 skupin × 30 B od offsetu 4, item 2048 skupin × 41 B od 493 568, rezerva 0 B | hotovo; zbývá jen port do extraktoru a ověření vah/hodnot (`docs/03` §3.3.1) |
| O2 | Layout `Cliloc.enu` | **VYŘEŠENO**: BWT komprese (3. bajt `0x8E`), pak `u32,u16`, záznamy `i32,u8,i16,UTF-8` | port `BwtDecompress` + `ReadCliloc` z ClassicUO; kritérium: 5 čitelných záznamů a nalezený anglický text (§3.3.2) |
| O3 | Který formát animací použít (anim*.mul vs AnimationFrame*.uop) | nerozhodnuto | změřit pokrytí těl v obou; rozhodnout podle obsahu |
| O4 | Spotřeba staminy při běhu v originále | UNVERIFIED | měřit v originálním klientu (v emulatech se to liší) |
| O5 | Ztráta skillů při smrti vraha (stat loss) | UNVERIFIED (20 % vs 33 %) | zdroj mimo tyto repa; do té doby config flag, default vypnuto |
| O6 | OSI vs RunUO světelný cyklus | **ROZHODNUTO 2026-10-06 (uživatel): V1 = RunUO/ServUO rampy**; zbytková část (chování originálního OSI klienta) zůstává NEMĚŘENO | serverová část je vyřešená a v kódu (`sim/world/time.gd`, `docs/05 §5.11`); kdo chce OSI binární variantu, mění jen `_day_night_level` |
| O7 | Význam 9 čísel kontextového menu | UNVERIFIED | dohledat v `Cliloc.enu` (až bude O2) |
| O8 | Klasické profesní šablony (8+) | částečně | v instalaci jsou 3 klasické (Warrior/Mage/Blacksmith); zbytek **rozhodnout a zapsat** do `data/professions.json` |
| O9 | Ceny domů (tabulky se rozcházejí o ~19 %) | UNVERIFIED | mimo rozsah (housing je non-goal) |
| O10 | Přesné časy harvestu (OSI vs ServUO) | UNVERIFIED | měřit; do té doby použít ServUO hodnoty a označit |
| O11 | `TileFlag` bit 25 (HoverOver vs NoDiagonal) | rozpor zdrojů | **nepřiřazovat žádný herní význam** |
| O12 | Váhy předmětů | závisí na O1 | z tiledata; do té doby jen explicitně doložené hodnoty (ingot 0.1, ore 1.0, log 2.0, hide 5.0…) |

## 11.7 Slovník (aby si agent nerozjely termíny)

| Termín | Význam v tomto projektu |
|---|---|
| **mobile** | cokoli živé: hráč, NPC, monstrum, zvíře (má `serial`, `body`, `pos`, staty) |
| **serial** | identifikátor entity (int); `>= 0x40000000` = mobile, jinak item |
| **item / tile / art id** | `tile` = id předmětu v datech (0x4000+), zároveň id artu; land dlaždice 0–0x3FFF |
| **hue** | index barvy v `hues.mul` (0 = bez tónování) |
| **layer** | vrstva výbavy (1 one-handed, 2 two-handed, 3 shoes, 4 pants, 5 shirt, 6 helm, 7 gloves, 8 ring, 10 necklace, 11 hair, 12 waist, 13 inner torso, 14 bracelet, 16 facial hair, 17 middle torso, 18 earrings, 19 arms, 20 cloak, 21 backpack, 22 outer torso, 23 outer legs, 24 inner legs) |
| **static** | nehybný objekt v mapě (nábytek, zdi, stromy) uložený ve `statics*.mul` |
| **gump** | okno UI z `gumpart` (batoh, paperdoll, vendor, craft) |
| **notoriety** | barva/jméno podle chování (1 innocent … 6 murderer, 7 invulnerable) |
| **facet** | mapa/svět (0 Felucca, 1 Trammel, 2 Ilshenar, 3 Malas, 4 Tokuno, 5 Ter Mur) |
| **cliloc** | číslovaný lokalizovaný text (`Cliloc.enu`) |
| **tiledata** | tabulka vlastností dlaždic/předmětů (flagy, výška, vrstva, váha, hodnota, jméno) |
| **dist** | dosah akce (zvednutí 2 dlaždice, mluvení 12, použití předmětu 2) |
| **war/peace** | bojový/klidový režim hráče |
| **swing** | jeden útočný cyklus zbraně |
| **GGS** | garantovaný růst skillu (po dlouhé době bez zisku) |
| **exceptional** | mistrovský výrobek (lepší vlastnosti, značka výrobce) |
