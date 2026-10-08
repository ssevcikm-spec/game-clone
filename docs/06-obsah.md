# 6. Obsah — předměty, nástroje, výzbroj, výstroj, monstra, obchody

> **Pravidlo:** obsah se **negeneruje ručně z hlavy** a neopisuje z wikipedie.
> Vzniká **generátorem** z dat, která už existují (výzkum + instalace), a do
> `data/*.json` se zapisuje strojově. Ručně se píše jen to, co v datech není
> (AI, ceny, spawny, profese) — a **vždy s označením zdroje**.

## 6.1 Jak obsah vzniká (tok dat)

```
research/04-craft-data.json  ─┐
research/06-world-content.md ─┼─► tools/gates/gen-content.py ─► data/*.json ─► hra
research/03-combat-magic.md  ─┤        (generátor, idempotentní)      │
instalace UO (tiledata)      ─┘                                        ▼
                                                        brána check-content
                                                     (schémata + art ID + odkazy)
```

| Soubor `data/` | Zdroj | Velikost |
|---|---|---|
| `items.json` | tiledata (jméno, váha, hodnota, vrstva, flagy) + ruční doplňky | ~3 000 záznamů |
| `recipes.json` | `research/04-craft-data.json` (**naměřeno 1053**, viz §6.3) | 1053 |
| `weapons.json` | `research/03` (parse `weapons3.json`) | ~120 |
| `armor.json` | `research/03` (`armor_raw.json`) | ~90 |
| `spells.json` | `research/03` (`spells_raw.json`) | 64 |
| `item_properties.json` | `research/03` (`itemprops_table.tsv`, 159 záznamů) | 159 |
| `monsters.json` | `research/06` (88 tabulek) | 88 |
| `spawns.json` | `research/06` (regionální tabulky) | 12 tabulek |
| `vendors.json` | `research/06` (120 tříd, 88 shopů) | ~25 použitých |
| `regions.json`, `moongates.json`, `dungeons.json` | `research/06` | 19 / 9 / 3 |
| `professions.json` | `Prof.txt` (3 klasické) + rozhodnutí pro zbytek | 8 |
| `skills.json` | `skills.mul` (58 jmen) + `research/02` (mechaniky) | 58 |
| `balance.json` | **rozhodnutí** (éry, stropy, prodlevy, model staminy) | 1 |

> **Pozor na jména:** tato instalace **nemá klasická jména předmětů**
> (`leather gloves`, `gold`, `bandage` v `tiledata.mul` nejsou) — je to
> moderní/přejmenovaná sada. Obsah se proto **vybírá podle vlastností**
> (vrstva, `Wearable` flag, weight, animID), ne podle klasického seznamu;
> postup je v `docs/03` §3.3.1b.

## 6.2 Předměty a nástroje (minimální sada)

**Každý záznam v `items.json` má:** `tile` (art id), `name`, `category`,
`weight`, `value`, `layer` (0 = nenasazitelný), `flags` (stackable, blessed,
newbie, …), `source` (`tiledata`|`decision`), `era`.

| Kategorie | Minimum | Příklady |
|---|---|---|
| **Nástroje** | 24 | pickaxe, shovel, hatchet/axe, smith hammer, tongs, sewing kit, scissors, saw, draw knife, tinker tools, mortar & pestle, scribe pen, fishing pole, butcher knife, skillet, rolling pin, flour sifter, flour mill, spinning wheel, loom, oven, anvil, forge, bellows |
| **Suroviny** | 40+ | 9 rud + 9 ingotů, log, boards, 4 kůže, 4 useň, cloth, bolt of cloth, thread, wool, flax, cotton, feathers, arrow shafts, arrows, bolts, bottles, 8 reagentů, flour, dough, water, sand, glass, gems, gold |
| **Zbraně** | ~60 | dagger, kryss, katana, longsword, broadsword, scimitar, viking sword, axe, battle axe, war axe, double axe, executioner's axe, mace, war mace, maul, war hammer, hammer pick, club, quarter staff, black staff, gnarled staff, war fork, spear, short spear, pitchfork, halberd, bardiche, bow, crossbow, heavy crossbow, throwing… |
| **Zbroje** | ~45 | leather/studded/ring/bone/chain/plate v 7 dílech (cap, gorget, chest, arms, gloves, legs, boots) + 6 štítů + dragon scale |
| **Oblečení** | ~30 | shirt, fancy shirt, pants, short pants, skirt, kilt, robe, plain dress, fancy dress, cloak, half apron, full apron, bandana, cap, wide-brim hat, wizard hat, bonnet, boots, shoes, sandals, thigh boots |
| **Lektvary** | ~20 | heal, cure, refresh, agility, strength, nightsight, greater heal/cure/agility/strength/explosion/poison, deadly poison, invisibility, mana, total refresh, bless, confusion… |
| **Svitky** | 64 | 8 kruhů (Inscription) |
| **Jídlo** | ~30 | bread, cake, cookie, cheese, apple, grapes, fish steak, cooked fish, raw ribs, cooked ribs, chicken leg, ham, pizza, stew, fruit |
| **Ostatní** | ~40 | bandage, spellbook, rune, recall rune, key, keyring, lockpick, torch, lantern, candle, sextant, clock, bag, pouch, backpack, chest, crate, barrel, keg, dye tub, dye, potion keg, book, scroll |
| **Speciální** | ~15 | moongate, sign, ankh, healer, bank box, bulletin board, training dummy, archery butt, pickpocket dip, bedroll, campfire |

**Přijímací kritérium obsahu:** každý `tile` v `data/*.json` **existuje
v manifestu artu** — když ne, generátor to zapíše do `content-report.json`
a brána `check-content` **selže** (obsah, který nemá obrázek, je neviditelný
a hráč to pozná jako vadu).

## 6.3 Recepty (1053, strojově)

| Skill | Receptů | Poznámka |
|---|---|---|
| Carpentry | 223 | včetně nábytku a zbraní ze dřeva |
| Tailoring | 198 | oblečení, zbroje z kůže, pytle |
| Blacksmithy | 196 | zbraně, zbroje, nástroje |
| Tinkering | 165 | nástroje, hodiny, pasti, klíče |
| Cooking | 88 | jídlo (včetně receptů s víc kroky) |
| Masonry | 59 | kamenické práce (mimo základ, ale data jsou) |
| Alchemy | 51 | lektvary (přesné kombinace reagentů) |
| Bowcraft/Fletching | 27 | luky, šípy, bolt |
| Glassblowing | 22 | sklo (mimo základ) |
| Inscription | 16 | **+ 97 svitků kouzel chybí**: `research/04-gathering-crafting.md` §5.5 je má jako markdown tabulky (64 Magery + 17 Necromancy + 16 Mysticism), ale `research/04-craft-data.json` je neobsahuje, takže je generátor nevyrobí. Naměřeno 2026-10-08: `data/recipes.json` = **1053** (dřív tu stálo 1150 včetně svitků) |
| Cartography | 8 | mapy |

**⚠ Slepé místo, které je potřeba znát (naměřeno 2026-10-08):** `check-content`
i `tests/cases/recipes.gd` kontrolují jen odkazy, které `tile` **mají** — proto
projde zeleně i 699 receptů, jejichž výsledek v `tiledata` této instalace
**není** (jen 354 má `result.tile`, 267 má `tile` u výsledku i materiálů).
`sim.craft.recipes_for` je proto označuje `craftable: false` a `craft` na ně
vrací `{ok:false, reason:"no_result"}`. Zelená brána tu tedy netvrdí
„recept je vyrobitelný“ — to tvrdí až tohle pole.

**Pravidla generátoru:**
1. Recept bez `min_skill` nebo bez materiálu se **nevypustí tiše** — jde do
   `content-report.json` jako `unresolved`.
2. Každý recept se ověří, že všechny materiály i výsledek existují
   v `items.json` (a tedy mají art).
3. Kategorie (strom v gumpu) se mapuje na číselník kliloků; dokud není
   `Cliloc.enu` přečtený (O2), použije se **anglické jméno kategorie**
   a v datech je `category_source: "decision"`.
4. Recepty z pozdějších ér (runic, reforging, imbuing) se **nezahrnou** (§5.16).

## 6.4 Zbraně a zbroje — co musí tabulka obsahovat

Sloupce (povinné): `name`, `tile`, `skill_used`, `hands`, `min_damage`,
`max_damage`, `speed`, `strength_req`, `weight`, `durability`, `layer`,
`special_move`, `material`, `era`.

**Známá mezera, kterou je potřeba dořešit:** `layer` **není** v serverových
zdrojích (ServUO ho bere z tiledata: `Layer = (Layer)ItemData.Quality`).
→ Vrstvy se doplní **až z vyřešeného `tiledata.mul`** (O1) a do té doby je
`layer: null` + `layer_source: "pending-tiledata"`. **Nikdy nehádat.**

Materiály (kovy): iron, copper, bronze, gold, agapite, verite, valorite
(+ jejich bonusy k damage/trvanlivosti v `research/03`).
Kůže: regular, spined, horned, barbed.

## 6.5 Monstra (88 tabulek, použijeme ~45)

| Skupina | Počet | Příklady |
|---|---|---|
| Začátečníci (divočina) | 10 | rat, giant rat, slime, bat, mongbat, bird, rabbit, cat, dog, cow |
| Nemrtví | 12 | skeleton, zombie, ghoul, headless one, bone magician, lich, wraith, spectre, shade, mummy, skeletal knight, bone knight |
| Humanoidé | 10 | orc, orc lord, orc mage, ettin, troll, ogre, ogre lord, lizardman, ratman, harpy |
| Elementálové a magie | 8 | earth/air/fire/water elemental, gazer, wisp, reaper, vortex |
| Zvířata a hmyz | 10 | snake, giant spider, dread spider, scorpion, giant serpent, alligator, bear, wolf, cougar, panther |
| Draci a bossové | 8 | dragon, drake, wyvern, nightmare, daemon, balron, ancient wyrm, titan |
| Mořské | 4 | dolphin, sea serpent, kraken, water elemental |
| Mounty a tažná zvířata | 6 | horse, pack horse, llama, pack llama, ostard (forest/desert) |

**Každé monstrum má:** staty, skilly, damage, resisty, `VirtualArmor`,
fame/karma, loot (gold dice + items + magic chance), AI typ, flagy
(undead, poisonous, tamable), `taming_difficulty`, slayer typ.
**Přijímací kritérium:** monstrum z `data/monsters.json` jde spawnout,
zaútočí, dá se zabít, nechá tělo s lootem a po ~5–10 min se obnoví.

## 6.6 NPC, vendory a obchody

| Věc | Minimum | Zdroj |
|---|---|---|
| Vendor profesí | **25** | blacksmith, weaponsmith, armorer, tailor, tinker, carpenter, bowyer/fletcher, alchemist, mage, scribe, healer, banker, innkeeper, barkeep, provisioner, butcher, baker, cook, farmer, fisher, miner, lumberjack, jeweler, stablemaster, shipwright |
| Ostatní NPC | 10 | guard, town crier, beggar, thief, gypsy, escort, animal, healer (wandering), merchant, noble |
| Obchody | 25 seznamů zboží | z `research/06` (88 shop definic) |
| Města s kompletní obsluhou | **Britain** (start) + Trinsic, Minoc, Vesper, Moonglow, Yew | `research/06` (19 měst, matice služeb) |
| Guard zóny | města | chování guarda `UNVERIFIED` → konfigurovatelné |

**Přijímací kritérium:** v Britainu najde hráč kováře, krejčího, alchymistu,
magera, léčitele, bankéře a hostinského; každý prodává a kupuje aspoň
5 položek; po 60 min se zboží obnoví.

## 6.7 Svět

| Prvek | Minimum |
|---|---|
| Faceta | Felucca (map0), celá geometrie |
| Města s obsahem | **6** (Britain + Trinsic, Minoc, Vesper, Moonglow, Yew) |
| Moongates | **9** s přesnými souřadnicemi (teleport funkční) |
| Dungeony | **3** (Deceit, Despise, Shame) — vstupy + 2–4 patra, spawn tabulky |
| Významná místa | hřbitov, loupežnické tábory, jeskyně v okolí Britainu |
| Spawn tabulky | 12 prostředí (town fringe, forest, desert, swamp, snow, graveyard, cave L1/L2/L3+, 3× dungeon) |

## 6.8 Definice „obsahově hotovo" (měřitelné)

Hra je obsahově hotová, když platí **všechno**:

| # | Podmínka | Jak se ověří |
|---|---|---|
| C1 | ≥ 250 předmětů má art v manifestu a je vidět ve hře | brána `check-content` |
| C2 | ≥ 20 nástrojů je použitelných (každý má větev v `sim.interaction`) | test po každém nástroji |
| C3 | ≥ 40 zbraní a ≥ 30 kusů zbroje je nasaditelných a viditelných na postavě | snímek + test equipu |
| C4 | ≥ 600 receptů je dostupných (zbytek je nad strop implementovaných skillů) | `check-content` |
| C5 | 64 kouzel je sesílatelných (mana + reagenty) | test per kouzlo |
| C6 | ≥ 40 monster se spawnuje, útočí a umírá | test spawn + boj |
| C7 | ≥ 25 vendorů prodává a kupuje | test obchodu |
| C8 | 8 profesí jde zvolit při tvorbě postavy | test tvorby |
| C9 | 3 dungeony mají spawn a loot | test regionu |
| C10 | Každý záznam v `data/` má `source` a `era` | schéma |

**Pozor na past:** „máme 1150 receptů v JSON" **není** obsahová hotovost, když
je dostupných 50. Počítá se **dostupné** (C4), ne **přítomné**.
