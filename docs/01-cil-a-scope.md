# 1. Cíl a rozsah

> Tento oddíl odpovídá na otázku **„co má vzniknout"**. Všechno ostatní v zadání
> je odvozené odsud. Když se nějaký požadavek v jiném oddílu nedá dovést sem,
> je to drift a patří smazat (viz `09-pravidla-pro-agenta.md`).

## 1.1 Cíl jednou větou

**Vytvoř jednu hratelnou, offline, single-player hru, která se principielně
chová jako Ultima Online (éra T2A/Renaissance + AoS prvky): izometrický svět
z dlaždic 44×44, pohyb po krocích, předměty které se berou, nosí, používají
a vyrábějí, NPC se kterými se obchoduje, souboj se skilly které rostou
používáním — a to všechno nad **originálními datovými soubory UO Classic**,
které leží na této stanici.**

Hra **není** MMO, nemá server, nemá síťový protokol a nepočítá s jiným hráčem.
Vše, co v UO dělal server, dělá v klonu simulace v jednom procesu — ale
**rozhraní mezi simulací a klientem zůstává** (viz `04-architektura-a-smlouvy.md`),
protože právě ono dělá UO tím, čím je (zpožděné akce, target cursor, gumpy,
krokové timery).

## 1.2 Co je „věrná kopie" — měřitelná definice

„Věrnost" není dojem. Následujících **12 bodů je zadání a zároveň kontrolní
seznam**; každý bod musí být dohledatelný v hotové hře a ověřitelný bez
spuštění originálního klienta. Tabulka je zároveň mapováním na oddíly zadání.

| # | Věrnostní bod | Co to konkrétně znamená | Kde je spec |
|---|---|---|---|
| V1 | **Ovládání jako UO** | levá myš = výběr/cíl, dvojklik = použij, pravý klik = kontext, drag & drop předmětů, kurzor pro target, makra na klávesách, chůze po kliknutí (klik-to-move) i šipkami | §5.3 |
| V2 | **Pohyb po krocích** | 8 směrů, diskrétní krok za 400 ms (běh 200 ms), spotřeba staminy, blokování terénem, výšky a schody, doors/teleporty jako v datech klienta | §5.1 |
| V3 | **Interakce mezi objekty** | dvojklik otevře/použije, použití nástroje na cíl, předmět na předmět, předmět na tile, kontejnery, řetězení (ore → forge → ingot), hlášky místo tichého selhání | §5.2 |
| V4 | **Manipulace** | zvednout/položit/přesunout, stackování, váha a nosnost, equip/unequip na vrstvy, reach (dosah), decay na zemi, zamčené kontejnery | §5.4 |
| V5 | **Souboj** | war/peace, útočný cíl, swing timer dle DEX a zbraně, hit chance, damage, parry, luk a munice, healing obvazy, smrt a tělo | §5.5 |
| V6 | **Magie** | 8 kruhů × 8 kouzel, many, reagenty, přerušení sesílání, spellbook a svitky, meditace | §5.6 |
| V7 | **Obchod** | vendor buy/sell gump, ceny z dat, zlato jako předmět s vahou, banka, restock, krádež/flag | §5.9 |
| V8 | **Sběr surovin** | těžba rudy (podle skilu druhy rud), dřevo, rybolov, kůže z těl, vlna — s vyčerpáním zdroje a nástroji s trvanlivostí | §5.7 |
| V9 | **Výroba** | kovářství, krejčovství, truhlařina, tinkering, alchymie, léčitelství/psaní svitků, vaření, lukovství — s recepty, minimálním skillem, spotřebou materiálu a gump menu | §5.8 |
| V10 | **Vývoj skillů** | 58 skillů v desetinách (0.0–100.0/120.0), růst používáním dle obtížnosti, skill cap 700, stat gain, stat cap | §5.10 |
| V11 | **Obsah předmětů** | data-driven katalog: nástroje, zbraně, zbroje, oblečení, suroviny, lektvary, svitky, jídlo — každý s art ID z originálních dat, vahou, vrstvou, hodnotou | §6 |
| V12 | **Svět a čas** | Britannia z originální mapy (faceta 0), statics, den/noc, světlo, spawn příšer, NPC ve městech | §5.11, §5.12 |

**Pravidlo věrnosti:** tam, kde se klon od UO odchýlí, musí to být
**rozhodnutí zapsané v `docs/`** s důvodem — ne tichý rozdíl v kódu. „Nevím,
jak to UO dělalo" je přípustný stav, ale musí být vidět: `UNVERIFIED` +
co je potřeba změřit.

## 1.3 Hlavní herní smyčka, která musí fungovat celá

Tohle je **jediná smyčka, která definuje hotovou hru**. Musí projít od začátku
do konce bez ručního zásahu do souborů:

1. Hráč začne ve městě (Britain) s postavou dle profese a základní výbavou.
2. Dojde k NPC kováři, **koupí** si pickaxe a pár ingotů (obchod V7).
3. Dojde k hoře, **vytěží rudu** (V8), u forge ji **vytaví na ingoty** (V3, V9).
4. U anvil a forge **vyková** z ingotů zbraň nebo zbroj (V9); skill kovářství
   přitom **stoupne** (V10).
5. Vyzkouší zbraň v **souboji** s potvorem, dostane damage a zranění (V5),
   použije obvazy (V5) a lektvar (V6/V9).
6. Z potvora **vezme kořist** (V4), prodá ji obchodníkovi (V7).
7. Zapíše hru, ukončí ji, spustí znovu a **stav je přesně tam, kde byl** (V4).
8. Umře a vrátí se jako duch k léčitelce, nechá se vzkřísit (V5).

Když kterákoliv z těch osmi vět nefunguje, hra **není hotová**, i kdyby
všechny testy svítily zeleně (viz `08-brany-a-overovani.md`).

## 1.4 Rozsah světa — rozhodnutí

| Rozhodnutí | Hodnota | Důvod |
|---|---|---|
| Faceta | **0 (Felucca)** z `map0LegacyMUL.uop` | klasická Britannia, nejvíc obsahu, T2A éra |
| Rozsah dlaždic | **celá faceta** 7168 × 4096 dlaždic | mapa se streamuje po blocích; ořezávat svět nemá důvod |
| Startovní město | **Britain** (okolí 1495 × 1630) | největší město, všechny služby |
| Ostatní facety | **mimo rozsah** (door pro později: načtení jiné facety je jen jiný `map_id`) | jeden svět stačí na věrný zážitek |
| Dungeony | **3 ručně vybrané** (Deceit, Despise, Shame) jako ověření spawn a AI | víc dungeonů = jen data, ale musí být nejdřív funkční jeden vzor |
| Budovy/housing | **jen statické budovy z mapy**, stavění domů mimo rozsah | housing je samostatný systém (multi komponenty), nepatří do základu |
| Lodě | **mimo rozsah** (voda je neprůchodná) | vyžaduje multi + pohyb na vodě |

## 1.5 Non-goals (co agent NESMÍ dělat, ani když to vypadá snadné)

Tohle je **explicitní seznam zákazů**. Každý bod, který by agent „domyslel",
vyrábí druhý zdroj pravdy a rozbíjí plán:

1. **Žádná síť, žádný server, žádný protokol.** Žádné `ENet`, žádné
   `MultiplayerSpawner`, žádná serializace paketů.
2. **Žádná fyzika enginu pro pohyb.** Pozice jsou celá čísla dlaždic; pohyb
   řeší simulace, ne `CharacterBody2D`/`move_and_slide`.
3. **Žádné plovoucí desetinné číslo ve stavu simulace** (skilly, hp, čas,
   pozice). Skilly v desetinách (int), čas v ms (int), pozice v dlaždicích
   (int), z v jednotkách světa (int). Float jen pro vykreslování.
4. **Žádné čtení `.mul`/`.uop` z herního kódu.** Data se čtou jen nástrojem
   v `tools/uoextract/` a do hry jdou hotové assety + manifest. Hra nesmí
   záviset na instalaci UO v runtime.
5. **Žádné nové závislosti** (pluginy, addony, externí knihovny) bez zápisu
   v `docs/`. Cílem je hra, kterou spustí `godot --path .`.
6. **Žádné stahování assetů z internetu za běhu** a žádné commity souborů
   z instalace UO (licence, §3.1).
7. **Žádné překladání názvů předmětů.** Názvy se berou z dat UO (tiledata /
   cliloc). Lokalizace UI je jedna vrstva navíc, ne přepis dat.
8. **Žádné „vylepšování" mechanik.** Když je v UO něco nepohodlné (např. váha
   zlata, pomalý běh), zůstává to — věrnost je cíl, ne pohodlí.
9. **Žádné čtení cizí vrstvy.** UI nikdy nemění stav simulace přímo; posílá
   příkazy. Simulace nikdy nesahá na uzly scény.
10. **Žádné mazání existujícího API** při úpravě souboru — změna je aditivní,
    dokud nedoběhne integrační granule (`09-pravidla-pro-agenta.md` §4).

## 1.6 Cílová platforma

| Věc | Hodnota |
|---|---|
| Engine | **Godot 4.7.2 stable**, GDScript (typovaný), bez C# |
| OS | Windows 10/11 (vývoj i cíl), bez konzolí |
| Vstup | myš + klávesnice; žádný gamepad v první verzi |
| Okno | výchozí 1280×720, zoom 1× a 2× (celočíselný), okno i fullscreen |
| Uložení | `user://saves/<slot>.sav` (JSON + gzip); POZOR: v sandboxu je
  `user://` mimo workspace → v testech přesměruj `APPDATA` (§10, past P9) |
| Jazyk hry | **anglické názvy předmětů a hlášek** (jsou v datech UO), UI texty
  anglicky; `locale/*.json` jako jediné místo pro překlad, česká varianta
  volitelná. Důvod: překlad 60 000 názvů by byl druhý zdroj pravdy. |
| Výkon | 60 FPS při 1280×720 v Britainu, ≤ 16 ms/frame; simulace ≤ 2 ms/tick |

## 1.7 Jak se celek vyhodnocuje (nezávisle na agentovi)

1. **Hratelnostní test podle §1.3** — člověk projde osm vět smyčky a dá
   známku 1–5. Tohle je jediné kritérium, které rozhoduje o „hotovo".
2. **Věrnostní audit V1–V12** — u každého bodu se najde místo v datech
   a v kódu, které ho implementuje, a ověří se spuštěním.
3. **Snímek hry** — `read_image` (nebo `vision` v CI) se podívá na frame:
   je tam vidět dlaždicová krajina, postava, zbraň, jméno, HUD.
4. **Determinismus** — dva běhy téhož skriptu příkazů dají stejný hash stavu.
5. **Uložení/načtení** — hash stavu před uložením == hash po načtení.
6. **Brány** (§8) — všechny musí projít **a** musí být prokazatelně schopné
   selhat (mutační test).
