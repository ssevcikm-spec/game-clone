# 1. Cíl a rozsah

> Tento oddíl odpovídá na otázku **„co má vzniknout"**. Všechno ostatní v zadání
> je odvozené odsud. Když se nějaký požadavek v jiném oddílu nedá dovést sem,
> je to drift a patří smazat (viz `09-pravidla-pro-agenta.md`).
>
> **⚠ 2026-10-09 — CÍL SE ZMĚNIL (rozhodnutí uživatele).** **Věrná kopie není
> cíl.** Cílem je **feel** — hratelná hra s pocitem Ultimy Online, ale **bez
> technologických omezení a vad staré hry** (trhavý pohyb, nejistota „kde jsem
> a co vidím", brutální závislost na ručním klikání) a **modifikovatelná
> a rozšiřitelná**. Reference se dál používá — jako **orákulum** (naměřené
> pravidlo je levnější než vymyšlené), ne jako cíl. Rozhodnutí, důvody a ceny:
> `ROZHODNUTI-2026-10-09-SMER.md` (root). **Změněné oddíly níž: §1.1, §1.2
> (úvod), §1.3 (nejbližší cíl), §1.5 bod 8.** Ostatní platí beze změny.

## 1.1 Cíl jednou větou

**Cíl od 2026-10-09:** *vytvoř jednu hratelnou, offline, single-player hru
s **feelingem** Ultimy Online — a to bez omezení, která si stará hra nesla
s sebou: pohyb je plynulý, hráč pozná, kde je a co vidí, rutinu nemusí
odklikat. Hra je **modifikovatelná a rozšiřitelná** a **svět jde dál i beze
hráče**.*

*Původní formulace (2. 10. 2026, ve svém čase správná — zůstává jako popis
chování, které z reference bereme):*

**Vytvoř jednu hratelnou, offline, single-player hru, která se principielně
chová jako Ultima Online (éra T2A/Renaissance + AoS prvky): izometrický svět
z dlaždic 44×44, pohyb po krocích, předměty které se berou, nosí, používají
a vyrábějí, NPC se kterými se obchoduje, souboj se skilly které rostou
používáním — a to všechno nad **originálními datovými soubory UO Classic**,
které leží na této stanici.**

Hra dnes **běží jako singleplayer** (jeden proces: klient + simulace)
a **nepočítá s jiným hráčem**; síť je **odložená, ne zamítnutá** — `D9` rozhodl
session u hostitele první a milník `MP` je za `M9`
(`ROZHODNUTI-2026-10-09-SMER.md`; rozpor s původním zněním je zapsaný
v `ROZHODNUTI-2026-10-10-MODERNI-UO.md`).
Vše, co v UO dělal server, dělá v klonu simulace v jednom procesu — ale
**rozhraní mezi simulací a klientem zůstává** (viz `04-architektura-a-smlouvy.md`),
protože právě ono dělá UO tím, čím je (zpožděné akce, target cursor, gumpy,
krokové timery).

## 1.2 Co bereme z reference — měřitelná definice (dřív „věrná kopie")

**Od 2026-10-09 to není cíl, ale smlouva o chování.** Následujících **12 bodů**
je seznam toho, **co z originálu bereme**; každý bod musí být dohledatelný
v hotové hře a ověřitelný bez spuštění originálního klienta. Tabulka je zároveň
mapováním na oddíly zadání.

**Co se od 2026-10-09 nevyžaduje:** doslovná shoda s originálem (pixel, hash,
kadence na milisekundu) **jako cíl**. Vyžaduje se, aby chování šlo **dohledat
k referenci** a aby ho **hráč poznal**. Brány měřící paritu obrazu zůstávají —
měří **regresi** („něco se rozbilo"), ne cíl.

| # | Co bereme z reference (dřív „věrnostní bod") | Co to konkrétně znamená | Kde je spec |
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

> **„Plynulý pohyb" ≠ volný pohyb.** Nový cíl (§1.1) žádá, aby pohyb **nebyl
> trhavý** — to ale **neznamená zrušit kroky**: krok zůstává diskrétní
> (400 ms / běh 200 ms) a **plynulý je přechod mezi dlaždicemi** (interpolace
> obrazu mezi dvěma polohami). Přesně to dělá i originál v podání ClassicUO
> a v klonu to řeší `REVIZE-POHYB-2026-10-07.md` §5 oprava B. Kdo by „plynulost"
> četl jako volný pohyb, rozbije V2 i brány na kadenci.
>
> **DOPLNĚNO 2026-10-10 (`M1`):** **tempo kroku (400/200 ms) je výchozí
> hodnota v datech**, ne zamrzlé pravidlo — důvod (naměřeno: je to anti-cheat
> throttling) a ceny jsou v `ROZHODNUTI-2026-10-10-MODERNI-UO.md` (M1)
> a v `docs/05` §5.1.4. Pravidlem zůstávají **průchodnost, dosah a spotřeba
> staminy**.
>
> **⚠ Poznámka musí zůstat POD tabulkou, ne uvnitř ní** — vložená mezi řádky
> V2 a V3 tabulku rozbije (řádky za ní ztratí hlavičku a nevykreslí se).
> Naměřeno 2026-10-09 nezávislým ověřením; opraveno.

**Pravidlo odchylky (dřív „pravidlo věrnosti"):** tam, kde se hra od UO
odchýlí, musí to být **rozhodnutí zapsané v `docs/`** s důvodem — ne tichý
rozdíl v kódu. „Nevím, jak to UO dělalo" je přípustný stav, ale musí být
vidět: `UNVERIFIED` + co je potřeba změřit.

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

### Nejbližší cíl: KRÁTKÁ SMYČKA (rozhodnutí 2026-10-09)

Osmička výš je **plná** definice hry. Než se dodělá, musí fungovat tenhle menší
celek — a **nic z něj nezávisí na souboji, magii ani smrti**:

| # | Věta krátké smyčky | Stav (2026-10-09) |
|---|---|---|
| K1 | Dojdu k prodejci a koupím krumpáč | **chybí** — obchod je v plánu až v `M7` |
| K2 | Vytěžím rudu | hotové (naměřeno 16. session) |
| K3 | U forge vytavím ingoty a vykovu předmět | hotové (naměřeno: 624 rudy → 624 ingotů → dýka) |
| K4 | Prodám výrobek prodejci | **chybí** — totéž jako K1 |
| K5 | Zavřu hru, vrátím se a svět se posunul beze mě | **chybí** — offline doběh ani scheduler neexistují |
| K6 | Zadám, co má postava dělat, a ona to provede (pravidla s podmínkami) | **chybí** — nová práce podle §1.5 bodu 8 |

**Past u K5 (patří do zadání, ne do kódu):** mimo obrazovku **nesmí** tiknout
celý svět jako simulace agentů — trik „aktivace podle sektorů kolem hráče" bez
hráče nefunguje. Svět mimo obrazovku je **funkce času** (rozvrhy, doplnění
spawnu, ceny), ne AI. Viz `REVIZE-SMER-2026-10-07.md` §2.5.

`M3`–`M8` (souboj, magie, obchod, spawn) se tím **neruší** — jen přestávají být
tím, co je nejblíž. Odůvodnění a ceny: `ROZHODNUTI-2026-10-09-SMER.md` (root).

## 1.4 Rozsah světa — rozhodnutí

| Rozhodnutí | Hodnota | Důvod |
|---|---|---|
| Faceta | **0 (Felucca)** z `map0LegacyMUL.uop` | klasická Britannia, nejvíc obsahu, T2A éra |
| Rozsah dlaždic | **celá faceta** 7168 × 4096 dlaždic | mapa se streamuje po blocích; ořezávat svět nemá důvod |
| Startovní město | **Britain** (okolí 1495 × 1630) | největší město, všechny služby |
| Ostatní facety | **mimo rozsah** (door pro později: načtení jiné facety je jen jiný `map_id`) | jeden svět stačí na zážitek blízký originálu |
| Dungeony | **3 ručně vybrané** (Deceit, Despise, Shame) jako ověření spawn a AI | víc dungeonů = jen data, ale musí být nejdřív funkční jeden vzor |
| Budovy/housing | **jen statické budovy z mapy**, stavění domů mimo rozsah | housing je samostatný systém (multi komponenty), nepatří do základu |
| Lodě | **mimo rozsah** (voda je neprůchodná) | vyžaduje multi + pohyb na vodě |

## 1.5 Non-goals (co agent NESMÍ dělat, ani když to vypadá snadné)

Tohle je **explicitní seznam zákazů**. Každý bod, který by agent „domyslel",
vyrábí druhý zdroj pravdy a rozbíjí plán:

1. **Žádná vlastní síťová vrstva se nepíše, dokud není hra hratelná**
   (změněno 2026-10-10 — dřív tu stálo „žádná síť, žádný server, žádný
   protokol", což si odporovalo s `D9` a milníkem `MP`). **Hranice
   `Command`/`Event` mezi klientem a simulací je závazná už dnes** (klient
   posílá jen záměr, simulace rozhoduje) — je to zároveň příprava na session
   u hostitele. Konkrétní síť (protokol, replikace, predikce) je **odložená, ne
   zamítnutá**; `ENet` a `MultiplayerSpawner` se nepoužívají, dokud k nim
   nebude smlouva (`mp.contract`) a zápis v `docs/`.
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
8. **Automatizace smí provést, nesmí rozhodnout (změněno 2026-10-09).** Hra
   **smí provést, co hráč rozhodl** — i když u hry není (offline doběh), a to
   i podle pravidel s podmínkami („udělej toto; když nastane tamto, udělej
   tamto"). Hra **nesmí rozhodnout za hráče**: co se má dělat, určuje hráč.
   QoL smí zkracovat klikání a zlepšovat čitelnost; **výsledek pravidel se
   nemění** (žádný loot navíc, žádné zkrácení časovačů, žádná výhoda, kterou
   by hráč neměl v UO s Razorem nebo UO Assist). Odpověď na „co je tvoje
   dovednost, když nemusíš klikat" je **plánování a rozhodnutí**, ne klikací
   zručnost. Podrobnosti a tři vrstvy (úmysl / politika / provedení):
   `ROZHODNUTI-2026-10-09-SMER.md` §2 D3.
   *Původní znění (do 2026-10-09, ve svém čase správné): „Žádné ‚vylepšování'
   mechanik. Když je v UO něco nepohodlné (např. váha zlata, pomalý běh),
   zůstává to — věrnost je cíl, ne pohodlí."*
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
| Jazyk hry | **anglické názvy předmětů a hlášek** (jsou v datech UO), UI texty anglicky; `locale/*.json` jako jediné místo pro překlad, česká varianta volitelná. Důvod: překlad 60 000 názvů by byl druhý zdroj pravdy. |
| Výkon | 60 FPS při 1280×720 v Britainu, ≤ 16 ms/frame; simulace ≤ 2 ms/tick |

## 1.7 Jak se celek vyhodnocuje (nezávisle na agentovi)

1. **Hratelnostní test podle §1.3** — člověk projde osm vět smyčky a dá
   známku 1–5. Tohle je jediné kritérium, které rozhoduje o „hotovo".
2. **Audit V1–V12** (co bereme z reference) — u každého bodu se najde místo
   v datech a v kódu, které ho implementuje, a ověří se spuštěním.
3. **Snímek hry** — `read_image` (nebo `vision` v CI) se podívá na frame:
   je tam vidět dlaždicová krajina, postava, zbraň, jméno, HUD.
4. **Determinismus** — dva běhy téhož skriptu příkazů dají stejný hash stavu.
5. **Uložení/načtení** — hash stavu před uložením == hash po načtení.
6. **Brány** (§8) — všechny musí projít **a** musí být prokazatelně schopné
   selhat (mutační test).

## 1.8 „Feel" — co má hráč zažít (a jak se to ověří)

> **Co je tenhle oddíl:** definice **pocitu**, který je od 2026-10-09 cílem hry
> (§1.1). Vznikl jako syntéza uživatelova popisu a návrhu agenta; **uživatel ho
> 2026-10-09 potvrdil** („se vším v podstatě souhlasím") **s jednou výhradou —
> zobrazení zdraví** — což je níž vedené jako **odložené a vratné** rozhodnutí,
> ne jako zákaz. **Není to stav projektu** (ten je v `HANDOFF.md`) a **není to
> nová smlouva o chování** (to je §1.2). Je to **kritérium**, podle kterého se
> pozná, že hra má pocit, který jsme chtěli.

**Definice jednou větou:** *Svět, který běží, i když se nedívám; hráč do něj
vstupuje bez levelů, takže riziko čte z kontextu a učí se z následků; jeho moc
roste dovednostmi a přípravou, ne úrovněmi; a každý výstup světa je něčí vstup,
takže nic není odpad.*

| # | Poznatek hráče | Co to znamená pro kód a data | Jak se to ověří |
|---|---|---|---|
| F1 | **Svět jde dál, i když se nedívám** | svět má vlastní hodiny a vlastní knihu událostí; mimo obrazovku je **funkce času**, ne simulace agentů | sonda: headless, **nula příkazů**, N světových hodin → hash se změní, dva běhy dají totéž, počet tikajících entit zůstane v rozpočtu |
| F2 | **Riziko čtu z kontextu a učím se z následků** | žádný obsah není zamčený úrovní; nebezpečnost se pozná z toho, co vidím (výbava, místo, chování), ne z čísla | zákazový sken: v datech a kódu není predikát `min_level`; sonda: každý region je dosažitelný od startu |
| F3 | **Moc roste z přípravy, ne z úrovně** | strop je měkký: skilly, staty a **co si vezmu s sebou** (obvazy, lektvar, terén, útěk) | sonda: týž cíl jde splnit s minimem skillu a **s přípravou**; pravidla neobsahují člen „level" |
| F4 | **Nic, co vyrobím, není odpad** | každý výstup dosažitelný ve hře má **konzumenta**: recept, poptávku světa, nebo propad | datová brána: pro každou kategorii dosažitelnou ve hře existuje konzument; mutace: předmět bez konzumenta → spadne |
| F5 | **Co jsem udělal, zůstává** | svět si pamatuje změny, které způsobil hráč, a dají se po dnech přečíst | sonda: udělej X → ulož → načti → svět X pořád ukazuje; mutace: smazat knihu při načtení → spadne |

**Pocit není snímek.** Kritéria odvozená z tohohle oddílu měří **vlastnosti
světa** (čas, dosažitelnost, konzumenty, paměť), ne vzhled obrazovky. Vzhled
zůstává na snímku a lidském oku (§1.7).

**Lhostejnost světa musí být spočítaná, ne napsaná.** F1 a F4 se v singleplayeru
perou: „svět, kterému jsem lhostejný" a „vždycky je komu prodat" dohromady
znamenají svět autorovaný jako lhostejný a zkonstruovaný tak, aby hráče uživil —
tedy nakonec postavený kolem něj. Řešení: ceny a poptávka jsou **funkcí stavu
světa** (zásobenost, infestace), takže prodej 500 kůží cenu srazí a svět se
neomluví.

### Čitelnost ano, jistota ne — s výjimkou, která je odložená

Z F2 plyne hranice pro **informace**, sestra hranice pro akce (§1.5 bod 8):
**čitelnost smíme zlepšovat, jistotu nezavádíme.** „Jistota" je informace, která
hráči **odebere rozhodnutí** (přesné číslo nebezpečnosti, ze kterého se „mám to
zkusit?" stane mechanický přepočet).

**⚠ Zobrazení zdraví je z toho vyňaté — odloženo a vratné** (rozhodnutí
uživatele 2026-10-09: chce mít možnost dělat ústupky a tohle je ten případ;
rozhodne se, **až si to zahraje**). Naměřeno v referenci: health bar je
**klientská věc** — `BaseHealthBarGump` a `HealthBarGumpCustom`
(`_src/classicuo/src/ClassicUO.Client/Game/UI/Gumps/HealthBarGump.cs:21,302`),
health lines nad mobily (`Game/Managers/HealthLinesManager.cs:11-23`), otevře se
i na **cizí** mobil (`Game/Scenes/GameSceneInputHandler.cs:204-217`) a je
ovladatelný nastavením (`Configuration/Profile.cs:174` `CloseHealthBarType`,
`OptionsGump.cs:4319-4341`). **Zobrazení zdraví tedy není proti feelu — je to
volba klienta.**

**Co platí tvrdě i tak (je to architektura, ne vkus):**

1. **Zobrazení nesmí měnit pravidla.** Simulace nesmí číst UI ani se ptát, co je
   vidět; žádné pravidlo nesmí záviset na tom, jestli je health bar zapnutý.
2. **Přepínač je na jednom místě** (konfigurace klienta), aby se dal zapnout
   a vypnout bez zásahu do simulace.
3. **Až se rozhodne, musí to být měřené, ne dojmové** — patří k tomu sonda
   (kolik rozhodnutí hráč udělá s health barem a bez něj), ne jen dojem.

**Co z tohohle oddílu už je v plánu:** F1 a F5 nesou granule `sim.offline`,
`sim.save` a `sim.decision_log` (milník `MK`, `docs/07` §7.2); F4 je kandidát na
datovou bránu a F2/F3 jsou kritéria pro obsah a souboj (`M5`). **Brány `F1`
a `F4` jsou od 2026-10-09 SCHVÁLENÉ** (uživatel) a zapsané v `docs/08` §8.2 —
do milníku `MK` vrací `2` (NEMĚŘENO), protože `sim.offline` a obchod ještě
neexistují. Návrh včetně kontrol a mutací: `NAVRH-BRAN-FEEL-2026-10-09.md`.
