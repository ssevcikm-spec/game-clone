# Pohyb, klient a „UO aparát" — měřená revize (2026-10-07, 13. session)

> **Co je tenhle soubor:** **analytický záznam (revize)** k dotazu uživatele
> „jsou ty vady z kopírování starého UO do moderního Godotu, a nebylo by levnější
> použít moderní metody a nechat si jen UO parametry?". Není to zadání ani stav
> projektu — **stav je `HANDOFF.md`**, zadání `ZADANI-DALSI-VYVOJ-2.md`.
> **Datum vzniku:** 2026-10-07 (13. session).
> **Datum spotřeby:** **2026-10-07, částečně** — provedlo se z ní **A, D a E**
> (viz §7 níže: co, čím je to doložené a co zůstalo). **V1 a V3 a V6 jsou
> opravené a měřené; V2, V4, V5 a M9 (`render.chunk_mesh`) zůstávají otevřené.**
> **Stav:** co je hotové, je v §7; co zbývá, je v §5.
> **Stav:** **neopravovat, dokud uživatel nerozhodne** o §5 (mění se tím `docs/05`,
> tedy zadání).
>
> **Čím je každé tvrzení doloženo** — v textu je vždy značka:
> **[K]** = kód tohoto repa (`soubor:řádek`), **[R]** = referenční klient/server
> (`_src/classicuo`, `_src/servuo`, `_src/sphere`, `soubor:řádek`),
> **[M]** = měření v této session (sonda + její výstup), **[D]** = dokument
> projektu (`docs/…`). Co není ani jedno, je označené jako hypotéza.

---

## 0. Zadání od uživatele (doslova) a šest vad, které hlásí

> „chození je sekané a hra prvně posune postavu a až potom zobrazí animaci chůze,
> hra hůře určuje směr kam mířím myší (jestli jít v rovině nebo úhlopříčce),
> hra mě nepustí do kopce (sem nemůžeš jít) ani přes most (nad vodou), jižní
> zábradlí mostu se zobrazuje pod dlaždicemi mostu."

| # | Vada | Vrstva, kde vzniká | Stav v této revizi |
|---|---|---|---|
| V1 | chůze je sekaná (nepravidelná kadence kroků) | `app/` + `sim.movement` (časování) | **naměřeno**: 718 ms a 530 ms na krok místo 400 (dva běhy: 7 a 9 kroků za 5 s) [M] |
| V2 | postava se posune dřív, než se objeví animace chůze | `app/player_controller` + `render.anim` | příčina naměřená **[K]** |
| V3 | směr z myši (rovina vs. úhlopříčka) | `app/input_map` | příčina naměřená **[K]** + přesné pravidlo **[R]** |
| V4 | „do kopce se nedá jít" | `sim/world/walk` (pravidlo výšky) | **naměřeno**: 2,4 % kroků blokujeme, UO je povolí [M] |
| V5 | „přes most se nedá jít" | `sim/world/walk` (pořadí kontrol) | příčina v kódu [K] + naměřené příklady nad vodou [M] |
| V6 | jižní zábradlí mostu je pod dlaždicemi mostu | `render/sort` (klíč řazení) | **naměřeno**: 6 401 dlaždic s vadou, z toho 71 nad vodou [M] |

---

## 1. Kde vady vznikají — a kde NE

**Tohle je odpověď na otázku „je to kopírováním UO?" — a je to měřitelná odpověď,
ne dojem.** Vady V1–V3 a V6 vznikají v **ručně psaném klientu** (`app/`, `render/`,
`ui/`), V4 a V5 v **pravidlech chůze**, a **ani jedna nevzniká z UO parametrů**
(skilly, řemesla, předměty, ekonomika) ani z požadavku na věrnost jako takového.

Velikost vrstev (řádky GDScriptu, bez testů) **[K]**:

| Vrstva | Co to je | Velikost | Vady z ní |
|---|---|---|---|
| `sim/` + `core/` + `data/` | **UO aparát**: pravidla, tabulky, data | **3 246** řádků GDScriptu + **2,75 MB** JSON [M] | V4, V5 (nedokončená pravidla) |
| `app/` + `render/` + `ui/` | **ručně psaný klient**: kreslení, vstup, časování | **1 939** řádků GDScriptu [M] | V1, V2, V3, V6 |

**Dvě věty, které z toho plynou:**

1. **UO aparát je ta levná a zdravá část projektu.** Je to data a čisté funkce,
   běží bez scény (headless testy), je deterministický a má 954 kontrol [D].
   Zahodit ho kvůli těmto šesti vadám by znamenalo zaplatit znovu přesně to,
   co už funguje — a to je i to, co uživatel nazývá „UO parametry" (vlastnosti
   předmětů, řemeslnictví).
2. **Drahá a vadná je ta ručně psaná polovina klienta.** Ta se dá nahradit
   metodami Godotu, aniž by se UO aparátu kdokoli dotkl — protože smlouva
   `sim`/`klient` je odděluje (a hlídá ji brána `check-layers`).

**A ještě jeden důsledek, který je proti intuici:** ani V4 ani V5 nevznikly tím,
že bychom UO kopírovali *příliš věrně*. Vznikly tím, že jsme ho **neopsali
úplně** — pravidla chůze jsou v našem kódu *přísnější* než v UO (viz §2.4 a §2.5).

---

## 2. Šest vad: naměřená příčina

### 2.1 V1 — „chození je sekané"

**Naměřené složky (tři různé, nesmí se slít do jedné):**

**(a) NAMĚŘENO: při držení klávesy jde krok za ~530–720 ms, ne za 400 ms,
a pokaždé jinak.** Sonda `_analyza/vada-kadence-kroku.gd` (nová, tato session)
drží 5 s klávesu a měří časy změn pozice **celou reálnou cestou**
(`Input.action_press` → `app/loop` → `input_map.poll` →
`sim.movement.request_step` → `apply_step`). Dva běhy (druhý bez cizí zátěže):

| Běh | drženo | kroků (čekáno 13) | prodlevy v ms | průměr | median |
|---|---|---|---|---|---|
| 1 (se zátěží) | 5024 ms | **7** | 502, 793, 804, 765, 505, 808, 847 | 718 ms | 793 ms |
| 2 (čistý) | 5017 ms | **9** | 432, 487, 451, 792, 479, 791, 465, 437, 439 | 530 ms | 465 ms |

Tři věci, které z toho plynou (a každá je vada sama o sobě):

1. **Krok je pomalejší, než má být** — 530–718 ms místo 400 ms, tedy 72–56 %
   zamýšlené rychlosti.
2. **Je nepravidelný** — v jednom běhu se střídají ~440 ms a ~790 ms prodlevy.
   To je to „sekané": postava jde, pak dvakrát déle stojí.
3. **Není reprodukovatelný** — dva běhy téhož kódu dají 7 a 9 kroků. Projekts
   přitom determinismus vyžaduje (`docs/02 §2.3`), i když ten se týká `sim/`;
   tady se rozchází **časování vstupu proti tikům**, ne stav.

**Mechanismus (z kódu, sedí na naměřený vzorec):** vstup si drží vlastní časovač
opakování (`app/input_map.gd:189-195` `_smi_krokovat` — při úspěchu si **zapíše
čas**), ale sim umí krok odmítnout jako `busy`, když ještě běží předchozí
(`sim/systems/movement.gd:95-97`; krok se aplikuje až za 400 ms,
`movement.gd:105-106,149-159`). Odmítnutý krok ale **časovač vstupu už
spotřeboval** → další pokus přijde až za dalších 400 ms a teprve ten se provede
→ **~800 ms**. Když tik s příkazem vznikne až po aplikaci kroku (což závisí na
fázi dvou hodin — vstup jede na `Time.get_ticks_msec()`, sim na `SimClock`),
vyjde ~440 ms. Naměřeno: **obojí v jednom běhu**.

**A ještě dokumentovaný rozpor:** `docs/05 §5.1.3` žádá **frontu 4 povolených
kroků** (fastwalk stack), takže „busy" pro vlastního hráče je proti zadání;
kód to ví a pojmenovává to (`movement.gd:96` „fronta 4 kroku z docs/05 §5.1.3
je na klientu"). Klient ji ale nemá — `request_step` se volá přímo ze vstupu.

*Doklad, že to nikdo neměřil:* sonda 12. session `_analyza/vlna7-drzeni.gd`
měří jen **počet** kroků za 2,5 s a její verdikt zní „OK (očekáváno >= 4)".
Naměřeno 4 kroky za 2,5 s = **625 ms na krok** — což je stejná vada, jen se
na ni verdikt neptal. Druhá sonda téže session (`_analyza/vlna5-chuze.gd:51-56`)
si kroky posílá **sama přímo** `movement.request_step` každých 400 ms — tedy
**obchází vstup**, kde je ta druhá polovina časování.

**(b) Vykreslování je nad rozpočtem projektu.** Zadání žádá **60 FPS / ≤ 16 ms**
(`docs/01-cil-a-scope.md:120`, §1.6) [D]. Naměřeno v 12. session: **1 516 draw
callů a 11 534 primitiv na frame, 22,3 ms = 45 FPS s vypnutým vsyncem**
(`render/texture_cache.gd:29-36`) [K+M]. V této session **při chůzi 137 framů
za 5 s = 27 FPS (37 ms/frame)** [M]. To je 1,4–2,3× nad rozpočtem a příčina je
známá: každý objekt je vlastní `draw_texture` v `_draw()` (`app/world_view.gd:212-241`).
Plán na to existuje — granule **`render.chunk_mesh`** (M9, „Dávkové kreslení
bloků", `depends_on: render.chunk, render.textures`) [D] — je ale **za** M3–M8,
tedy za obsahem.

**(c) Chůze je prezentovaná jako skok, ne jako pohyb.** Zadání to dokonce
**zakazuje opravit**: „**Zákaz:** »pohyb je plynulý« (lerp mezi dlaždicemi jako
moderní hry)" (`docs/05-mechaniky.md:72-73`) [D]. Referenční klient to ale dělá
(viz §2.2) — ten zákaz je tedy **věcně nesprávné tvrzení o UO**, ne ochrana věrnosti.

### 2.2 V2 — „prvně posune postavu a až potom zobrazí animaci chůze"

**Přesná příčina (celý řetěz, všechny kroky doložené v kódu):**

1. Stisk → `app/input_map.poll` → `Command{t:"move"}` (`app/input_map.gd:150-186`).
2. `sim.movement.request_step` **nic neposune** — založí `_pending` s `due_ms = now + 400`
   (`sim/systems/movement.gd:105-106`).
3. Po 400 ms `apply_step` **skočí** na sousední dlaždici (`movement.gd:120`) a pošle
   událost `mobile_moved` + `mobile_anim` (`movement.gd:107-108, 125-126`).
4. Klient ale události **neodebírá** — `mobile_anim` ani `mobile_moved` nečte
   nikdo (grep přes celý strom: jen `sim/` a jeden test) [K]. Klient místo toho
   **polluje stav** a animaci si zapíná sám, až když si všimne, že se změnila
   dlaždice: `app/player_controller.gd:138-145` (`_action = ACTION_WALK` **až po**
   změně dlaždice, `_walk_until_ms = now + WALK_MS`).
5. `render.anim.play()` pouští frame 0 ve chvíli změny klíče `tělo/akce/směr`
   (`render/anim_player.gd:102-107`).

**Výsledek:** postava 400 ms stojí (idle), pak skočí o dlaždici a **teprve tehdy**
se rozeběhne animace chůze — kterou hraje dalších 400 ms, kdy už postava stojí.
Animace a pohyb jsou tedy **v protifázi**, ne „opožděné".

**Čísla k tomu [M]:** animace chůze těla 400 má **10 framů na směr**
(`assets/uo/anim/anim-sheets.json`), `frame_ms = 80` (`core/const.gd:35` `TURN_MS`,
`render/anim_player.gd:64`) → **jeden cyklus nohou = 800 ms**, tedy dva kroky.
To **odpovídá** referenci (i tam je 80 ms na frame a 400 ms na krok) — chyba
tedy **není** v délce framu.

**Co dělá referenční klient (`_src/classicuo`) [R]:**

* dlaždici **commituje až na konci kroku**, ale do té doby kreslí postavu
  **posunutou v pixelech** o `Offset`, který roste s časem kroku:
  `Mobile.cs:776-782` (`steps = maxDelay / 80`, `x = delay / 80`, `Offset.X/Y`),
  `MovementSpeed.GetPixelOffset` (`MovementSpeed.cs:27-131`; 22 px na osu za
  5 framů, tj. přesně jedna dlaždice za krok), aplikuje se v `MobileView.cs:43-48`;
* `X,Y,Z` se přepíšou teprve když `delay >= maxDelay` (`Mobile.cs:791-845`);
* animace se resetuje na frame 0 **jen při rozjezdu z klidu**
  (`PlayerMobile.cs:631-639`), jinak jde nepřerušeně 80 ms na frame
  (`Mobile.cs:571-606`);
* **jeden časovač řídí obojí** — proto jsou nohy s pohybem ve fázi.

**Z toho plyne oprava, která nemění ani jedno UO pravidlo:** sim zůstane
celočíselný a diskrétní (`apply_step` na konci kroku), ale **klient kreslí
postavu mezi původní a novou dlaždicí** podle téhož 80ms clocku jako framy
animace. To je „moderní metoda, UO parametry" v jedné změně.

### 2.3 V3 — „hůře určuje směr, jestli jít v rovině nebo úhlopříčce"

**Naše pravidlo** (`app/input_map.gd:87-96`) je `signi()` na rozdílu dlaždic:

```gdscript
var dx: int = signi(to.x - from.x)
var dy: int = signi(to.y - from.y)
```

Tím je **každý** klik, který není přesně na ose nebo přesně na 45°, vyhodnocen
jako **úhlopříčka** — a hlavně se to počítá v **prostoru dlaždic**, ne na
obrazovce, takže hranice „rovina vs. úhlopříčka" vychází jinam, než ji má UO.

**Referenční pravidlo** (`_src/classicuo`, `GameCursor.GetMouseDirection`,
`GameCursor.cs:670-754`) [R] je **obrazovkové**:

```
shiftX = mouse.x - střed obrazovky;  shiftY = mouse.y - střed obrazovky
|dy| <= 0,4·|dx|   -> rovný vodorovný směr
|dy| >= 2,5·|dx|   -> rovný svislý směr
jinak              -> úhlopříčka
```
(střed je střed **viewportu**, `GameSceneInputHandler.cs:48-52`;
`run` = vzdálenost ≥ 190 px od středu, `:66` — to už děláme stejně,
`app/input_map.gd:64-70`.)

Po přepočtu na naše číslování směrů (`core/const.gd:45-46`, 0 = východ)
dává totéž pravidlo tuhle **úplnou tabulku** (odvozenou ze všech 8 větví
`hashf` + 4 osových případů; sedí na geometrii projekce `core/iso.gd`):

| kurzor na obrazovce | náš směr |
|---|---|
| vpravo / vlevo (rovina) | 1 = NE / 5 = SW |
| nahoru / dolů (rovina) | 3 = NW / 7 = SE |
| vpravo nahoru (úhlopříčka) | 2 = N |
| vpravo dolů (úhlopříčka) | 0 = E |
| vlevo nahoru (úhlopříčka) | 4 = W |
| vlevo dolů (úhlopříčka) | 6 = S |

Pozor na past, která v referenci je a musí se okopírovat i s ní: návratová
hodnota `GetMouseDirection` **není** světový směr, ale oktant v obraze; do světa
se převádí `facing - 1` s výjimkou `North → 8` (`GameSceneInputHandler.cs:59-81`).
Kdo to neví, dostane směr posunutý o jednu osminu.

### 2.4 V4 — „do kopce mě nepustí"

**Naše pravidlo** (`sim/world/walk.gd:99-101, 210-218`): cílový `z` je **jedno
číslo z mapy** (`map.z_at`) a krok se povolí, jen když `dz <= STEP_HEIGHT = 2`
(výjimka: dlaždice se schodem, kde se použije **plná výška schodu**).

**Referenční server** (`_src/servuo`, `Scripts/Services/Pathing/Movement.cs`) [R]
neporovnává `dz`, ale **horní hranu**:

```
stepTop = startTop + StepHeight (2)          # Movement.cs:170-171
land:   povoleno, když stepTop >= landZ      # :319-321  (landZ = NEJNIŽŠÍ roh cíle)
        stojná výška = landCenter (průměr 4 rohů)   # Map.cs:552-607 GetAverageZ
statik: povoleno, když stepTop >= itemTop    # :216-236
        itemTop = z + Height  (u Bridge jen Height/2)   # TileData.cs:112-125
```

Tři rozdíly, každý z nich je **vada naší věrnosti**:

1. **Dolů nemá UO žádný limit** — podmínka má jen horní mez. My blokujeme
   `dz < -PERSON_HEIGHT` (`walk.gd:216-217`), takže **UO by seskočení povolilo
   a my ne**.
2. **U landu se nahoru nepočítá `z` dlaždice, ale nejnižší roh cíle**, a stojí se
   na průměru 4 rohů. Ve svahu je tedy povolený vzestup `2 + (průměr − nejnižší
   roh)` — **víc než 2**. My máme jediné `z` z mapy, takže svah, který klient
   *kreslí* jako rampu (`z_corners`, `render/chunk_renderer.gd:105-109`),
   simulace **nevidí** a blokuje ho. Dvě různé modely téhož terénu.
3. **Most půlí výšku** (`TileFlag.Bridge`, `TileData.cs:112-125`) — náš `walk.gd`
   o flagu `0x400` neví vůbec.

Platí i to, co už máme správně: `PERSON_HEIGHT = 16`, `STEP_HEIGHT = 2`
(`docs/05-mechaniky.md:41`) a asymetrická diagonála [R] `Movement.cs:550-554`.

**Naměřeno na reálné mapě** (sonda `_analyza/vada-svah.py`, okno
x1400..1620 / y1540..1760, model obou pravidel z `Movement.cs` + `Map.GetAverageZ`):

| | UO povolí | UO blokuje |
|---|---|---|
| **my povolíme** | 161 972 | **0** |
| **my blokujeme** | **4 013 (2,4 %)** | 0 |

Tedy: **žádný krok, který UO zakazuje, u nás neprojde** (jsme striktně
podmnožina) — a **2,4 % kroků, které UO povoluje, u nás neprojde**. Příklady
z výstupu: `(1406,1540)→(1407,1540)` má `dz = +7` (blok), ale UO: `startTop + 2
= 31 ≥ low cíle 29` → povolí. To je přesně „do kopce mě to nepustí".

**Druhé, nezávislé měření (Godot, okno x1440..1560 y1580..1700) [M]** — tentokrát
ne „UO vs. my", ale **jaké jsou naše odmítnutí**: z 58 080 kroků povoleno
**38 424**, odmítnuto **19 656**; rozhodující podmínka: neprůchodný land 7 501,
blokující statik 5 922, **`_fits` (výška) 1 380**, voda **0** (v tom okně žádná
voda není). A jeden doložený svah na pevnině:
`(1460,1580) dirt z=20 → (1461,1580) cobblestones z=24`, `dz = +4`, cíl **bez
statiků** → `_fits` 4 > 2 → odmítnuto, i když UO by povolilo.

|dz| mezi sousedy: 0 → 52 418, 1 → 1 502, 2 → 1 328, **3–5 → 1 510**,
6–10 → 720, 11–20 → 134, >20 → 468. Tedy **nejen hrany: běžných svahů o 3–5
jednotek je v jednom okně 1 510** — a naše pravidlo je odmítá.

*Poznámka k metodě (poučení z obou měření):* kdyby se výška brala z **landu**
místo z `surface_z`, vyjde „svah na pevnině" **1 130** — což je **artefakt
měření**, ne nález (statiky výšku mění). Proto jsou v této sekci dvě čísla:
**2,4 %** z porovnání pravidel a **1 380** z rozpadu našich odmítnutí; každé
měří jinou věc a nesmí se zaměnit.

### 2.5 V5 — „přes most mě nepustí (nad vodou)"

**Příčina v kódu je jednoznačná [K]:** `can_step` se na vodu ptá **dřív, než se
podívá na statiky**:

```gdscript
if _tiledata.flags(land) & F_WET != 0:
    return _no("blocked")           # sim/world/walk.gd:90-91
...
if _blokuje_statik(...)             # :97  <- až tady
var z: int = _surface_z(to.x, to.y) # :99
```

**V UO je to naopak:** kandidátem na povrch je i statik se `Surface` flagem
**bez** `Impassable`, a vyhrává ten, jehož povrch je hráči **výškově nejblíž**
(`_src/servuo` `Movement.cs:211` a `:222-228`) [R]. Voda (`Wet`) blokuje jen
tomu, kdo neumí plavat (`Movement.cs:211` — `canSwim && Wet`). Most tedy **není
entita**, je to obyčejná statika s `TileFlag.Bridge` nad vodou
(`TileData.cs:138-142`: `Surface = 0x200`, `Bridge = 0x400`).

*Co naměřily sondy (dvě nezávislé cesty — Python nad daty a Godot nad kódem):*

**Kde to je [M]:** plošný sken mapy našel **15 063 491 vodních dlaždic** a
**2 973 statik se `Surface`/`Bridge` stojících na vodě** (arty `wooden bridge`
`0x07CA`/`0x07CB`, 1 140 dlaždic `wooden plank`). **Molo u Britannie je na
`x 1522..1525`, `y 1470..1500`** (68 dlaždic splňuje definici „voda + povrch
nad ní"), tedy **24 dlaždic severně od okna, které jsem původně zadal** —
a dvě osamocená prkna `(1480,1766)`/`(1480,1767)`. Naměřený profil dlaždice
`(1522,1478)`: land `water` `z = −5` (flagy `0x000000C0`), statik
`wooden plank` (art 18380) **`z = 10`, výška 1** → **paluba je 16 jednotek
nad vodou** (voda je v datech dvakrát: jako land 168–171 a ještě jako statik
`art 22422 'water'`).

**Co s tím udělá `can_step` [M]:** z 544 zkoušených kroků z okolní pevniny na
molo je **povoleno 0** — a všechny končí na `walk.gd:90` (`F_WET`), tedy
**dřív, než se kód stihne zeptat na povrch ze statiku**. To potvrzuje příčinu
V5 číslem.

**Ale pozor — dvě věci to mění:**

1. **Samotné přesunutí kontroly před statiky nestačí.** I kdyby `F_WET`
   neblokoval, `_fits` by krok odmítl: `dz` by byl **16** (paluba 11 vs voda −5)
   proti povolenému kroku 2 (`walk.gd:210-218`). Oprava musí vzít **stojnou
   výšku z povrchu statiku** (v UO vyhrává povrch výškově nejbližší hráči,
   `Movement.cs:222-228`) — tedy `_surface_z` se musí uplatnit *místo* `z` landu,
   ne vedle něj.
2. **Molo je nedosažitelné i samo se sebou [M].** BFS přes `can_step` z prkna
   dosáhne **1 dlaždice** (jen tu výchozí), BFS z pevniny v okně
   `x1505..1545 y1460..1530` dosáhne 2 dlaždice a k molu **0** (nejbližší
   dosažitelná dlaždice je 21 daleko). Široký BFS z Britannie prošel 300 000
   dlaždic a molo nenašel. **To je nejlepší vysvětlení uživatelova „nepustí mě
   přes most": most je vidět, ale vstoupit na něj nelze vůbec** — a to je
   zároveň důkaz, že vada je v pravidle, ne v datech.

**Poznámka k hlášce:** „You cannot move there." je naše hláška
(`sim/systems/movement.gd:103`). UO samo **žádný text neposílá** — odmítnutí je
binární packet `MovementRej` (0x21) bez důvodu (`_src/servuo`
`Network/Packets.cs:4498-4508`) [R]. Naše hláška je tedy *rozhodnutí projektu*
(„nikdy ticho", `docs/05` §5.2.2), ne opis UO — a je v pořádku; jen se nesmí
zaměnit za „UO to tak má".

### 2.6 V6 — „jižní zábradlí mostu je pod dlaždicemi mostu"

**Naše řazení** (`render/sort.gd:28-36`): klíč = `(x+y) → vrstva (land < static <
mobile) → z vzestupně → pořadí vstupu`. Uvnitř jedné dlaždice tedy rozhoduje
**holé `z` statiky** a při shodě **pořadí v souboru mapy**.

**Referenční klient** (`_src/classicuo`) [R] řadí uvnitř dlaždice podle
`PriorityZ`, což **není** `z`:

```
PriorityZ = z
  land:                    z - 1 (a ještě -1)      Chunk.cs:169-196
  mobile:                  z + 1
  static:                  -1 když IsBackground
                           +1 když Height != 0
                           +1 když IsMultiMovable
depth = (x + y) + (127 + PriorityZ) * 0.01         View.cs:35-84
```

**Rozhoduje `PriorityZ`, a to dvěma složkami — obě musí být v opravě [R]:**

```
PriorityZ(static) = z  − 1 když IsBackground   + 1 když Height != 0   + 1 když IsMultiMovable
```

* **`IsBackground` je ta rozhodující pro most.** Paluba je z **podlahových**
  dlaždic (`wooden plank` art 18380, flagy **`0x00006201`** = Background +
  Surface + NoShoot + ArticleA) → `z − 1 + 1 = z`. Zábradlí a zídky
  (`stone rail` `0x4050`, `stone wall` `0x6050`) background **nejsou** a výšku
  mají → `z + 1`. Tedy **zábradlí se kreslí až po dlaždici mostu**, i když má
  stejné nebo nižší `z`.
* My obě složky ignorujeme, takže při shodě `z` rozhoduje **pořadí v souboru
  mapy** — a dlaždice mostu ho překryje. `TileFlag.Bridge` se v klíči
  referenčního klienta **nevyskytuje** (není to mostová specialita, ale obecné
  pravidlo statiků).
* **Co oprava nezmění (dobře):** zábradlí na **sousední diagonále** se před
  dlaždici mostu nedostane ani dnes — `sort.gd:36` násobí `(diagonal*3 + vrstva)`
  rozsahem 256, takže rozdíl diagonály je **879 > 255** a `z` ho nepřebije.
  A prkno se „nepotopí" pod land: statik má vrstvu 1, land 0 (klíč vyšší o 271).

*Naměřeno na reálné mapě* (sonda `_analyza/vada-zabradli.py`):

| Co | Počet |
|---|---|
| dlaždic, kde mají „plocha" (`Surface`, výška ≤ 1) a „vysoký statik" (výška > 10) **stejné `z`** | **11 271** |
| z toho **vysoký statik je v souboru PRVNÍ** → naše kreslení ho překryje (VADA) | **6 401** |
| z toho plocha v souboru druhá (pořadí náhodou správné) | 4 870 |
| **z VAD leží nad vodou** (land má `WET`, tedy most/molo) | **71** |
| v okně Britannie x1350..1750 y1450..1900: shod / vad | 976 / 416 |

Příklad vady nad vodou: `(1249,869)` až `(1249,876)` (souvislý pruh 8 dlaždic) —
v souboru je **první** `stone wall` (`z = 16`, výška 20, `IMPASSABLE`) a **druhý**
`stone pavers Dark` (`z = 16`, výška 0, `Surface` + `background`) → náš klíč je
u obou stejný, takže se dlažba kreslí **po** zídce a překryje ji. Přesně to je
„jižní zábradlí mostu se zobrazuje pod dlaždicemi mostu".

Oprava podle reference: do klíče dát **`PriorityZ`** místo holého `z`
(statik: `−1` za `IsBackground`, `+1` za `Height != 0`). Tím dlažba dostane
`z − 1` (nebo `z`) a zídka `z + 1` → **shoda zmizí** a pořadí je dané, ne náhodné.

**A naměřený případ přímo na molu u Britannie [M]** — dlaždice `(1525,1474)`,
pořadí podle dnešního klíče:

| index | objekt | `z` | klíč |
|---:|---|---:|---:|
| 1616 | land | −15 | 2303345 |
| 1683 | statik `stone rail` (art 18680) | 1 | — |
| **1685** | **statik `stone wall` (art 16490)** | **6** | **2303622** |
| 1686 | statik `stone rail` (art 18682) | 10 | — |
| **1687** | **`wooden plank` (art 18380) = dlaždice mostu** | **10** | **2303626** |

Dlaždice mostu (1687) jde **po** zídce (1685) → překreslí ji = „zábradlí je pod
dlaždicemi". Stejný vzorec je na `(1525,1471)`–`(1525,1476)`: **30 dlaždic,
kde je na téže dlaždici prkno i zábradlí**. S `PriorityZ` vyjde zábradlí
`10 + 1 = 11` proti prknu `10 − 1 + 1 = 10` → **pořadí se obrátí správně**.

---

## 3. Odpověď na otázku „moderní metody vs. UO aparát"

**Ano — a to rozdělení je správné. Ale pozor na to, co je na které straně čáry.**

| Zůstává UO (a je to ta levná část) | Nahrazuje se metodami Godotu (a je to ta drahá část) |
|---|---|
| **Data a parametry**: 400/200 ms na krok, `StepHeight = 2`, `PersonHeight = 16`, flagy dlaždic, skilly v desetinách, recepty, vlastnosti předmětů, cliloc názvy — `data/*.json` (**2,75 MB**, naměřeno) a `sim/` | **Vykreslování**: místo ~1 500 `draw_texture` na frame dávkové kreslení (`render.chunk_mesh` už je v plánu jako M9) |
| **Pravidla a jejich výsledek**: `sim/` jako autorita (celá čísla, determinismus, `state_hash`, replaye) | **Prezentace pohybu**: kreslit postavu mezi dlaždicemi plynule (jako `Offset` v ClassicUO), sim přitom zůstane diskrétní |
| **Rozhraní Command/Event** mezi sim a klientem (`docs/02` §2.2) — to je to, co dělá UO UO | **Vstup**: směr z myši podle obrazovkového pravidla (§2.3), ne `signi()` |
| **Ovládání a interakce** jako UO (klik, dvojklik, drag & drop, target kurzor) | **Řazení**: klíč podle reference (§2.6) místo holého `z` |
| **Hláška místo ticha** (rozhodnutí projektu) | **Časování animace**: jeden clock pro framy i posun (§2.2) |

**Kde je hranice:** *pravidla, data a jejich důsledky* = UO; *pixely, vstup,
časování vykreslení a engine plumbing* = Godot. Věty, které to porušují, jsou
v zadání dvě:

* `docs/05-mechaniky.md:72-73` — zákaz plynulého pohybu. **Věcně nesprávný**
  (referenční klient pohyb plynule vykresluje, §2.2). Doporučuji přepsat na:
  *„krok je diskrétní a trvá 400 ms (běh 200 ms) — to je pravidlo; klient
  **smí** vykreslit posun mezi dlaždicemi plynule (ClassicUO `Mobile.cs:776-782`),
  protože tím se nemění ani jedno pravidlo ani determinismus simulace."*
* `docs/01-cil-a-scope.md:86-87` (§1.5 bod 2) — „žádná fyzika enginu pro pohyb".
  **Tohle je správně a nemá se měnit**: `CharacterBody2D` do krokového pohybu
  nepatří. Moderní metoda tady znamená **kreslení**, ne fyziku.

**Co by to ušetřilo (měřená část):** 4 z 6 vad sedí v 81 KB ručně psaného klienta;
cíl 60 FPS/≤16 ms je dnes nedodržený (22,3 ms, 1 516 draw callů) a řešení už je
v plánu (`render.chunk_mesh`). Nejdražší není „být věrný UO", ale „mít vlastní
engine uvnitř hry".

---

## 4. Proč to nezachytily brány

Zadání má 13 bran a 954 kontrol [D] — a šest vad je vidět na první pohled.
Naměřené důvody (každý je druhá strana téhož pravidla „brána musí mít jak selhat"):

| Brána / test | Co měří | Co z toho plyne |
|---|---|---|
| `tools/gates/check-render.py` (G10) | **jeden snímek**: je postava v pixelech, sedí barva kůže | **pohyb, časování, řazení ani kadence** se v jednom snímku nepoznají |
| `tests/cases/walk.gd` | pravidla chůze na **vymyšlených fixtures** | most ani svah v datech nikdy neviděl — `can_step` na reálné mapě netestuje nikdo |
| `_analyza/vlna7-drzeni.gd` | **počet** kroků za 2,5 s | 4 kroky za 2,5 s = 625 ms/krok prošlo jako „OK (očekáváno >= 4)" — chybí kontrola **rozestupu** |
| `_analyza/vlna5-chuze.gd` | frame casy, ale kroky posílá **přímo do sim** | měří něco jiného, než si myslí (obchází vstup) |
| žádná brána | **FPS / ms na frame** | kritérium `docs/01` §1.6 (≤16 ms) nemá jak selhat — nikdo ho neměří |

**Obecné ponaučení (patří do `LESSONS`):** *brána, která měří „je to tam?", je
slepá na „je to správně načasované?".* Šest vad tohoto typu prošlo sadou 954
kontrol, protože **všechny** kontrolují přítomnost a stavbu, ne průběh v čase.

---

## 5. Co z toho plyne pro plán (návrh, nerozhodnuto)

Pořadí je podle poměru „viditelný efekt / cena". Body A–C nemění ani jedno UO
pravidlo; bod D je příprava na cíl 60 FPS.

| # | Co | Kde | Proč první |
|---|---|---|---|
| **A** | **Kadence kroku**: (a) vstup nesmí spotřebovat časovač odmítnutým krokem, a/nebo (b) dodělat **frontu 4 kroků**, kterou už žádá `docs/05 §5.1.3` (fastwalk stack) | `app/input_map.gd`, `sim/systems/movement.gd` | V1; naměřeno 718 ms místo 400 a je to ~10 řádků. **Přijímací kritérium: 5 s držení = 12–13 kroků s rozestupem 400 ± 60 ms** (dnes 7 kroků, 718 ms) |
| **B** | **Animace a pohyb v jedné fázi**: klient kreslí postavu mezi dlaždicemi (offset podle `delay / 80 ms`), animace startuje **v okamžiku záměru**, ne po skoku; zapojit `mobile_anim` (dnes ho nikdo nečte) a rozlišit animaci chůze/běhu | `app/player_controller.gd`, `app/world_view.gd`, `render/anim_player.gd` | V2 (+ část V1); sim zůstane nedotčená |
| **C** | **Pravidla chůze**: (1) statik se `Surface` rozhoduje i nad vodou, (2) dolů žádný limit, (3) `TileFlag.Bridge` půlí výšku, (4) výška svahu z rohů dlaždice, ne z jednoho `z` | `sim/world/walk.gd` (+ `world.tiledata`) | V4, V5; každý bod má citaci z reference |
| **D** | **Směr z myši**: obrazovkové pravidlo 0,4 / 2,5 + tabulka z §2.3 | `app/input_map.gd` | V3; dá se testovat tabulkou 8 směrů |
| **E** | **Řazení statiků**: `PriorityZ` = `z` (+1 za výšku, −1 za background) | `render/sort.gd`, `render/chunk_renderer.gd` | V6; ověřit **pohledem** na most |
| **F** | **`render.chunk_mesh`** (už v plánu jako M9) **předsunout** před další obsah | `render/` | 1 516 draw callů → dávky; jinak zůstane 45 FPS a každá další práce na klientu se dělá nad provizoriem |

**Co je potřeba rozhodnout (patří uživateli, ne agentovi):**

1. **Smím přepsat `docs/05 §5.1.4`** (zákaz plynulého pohybu) tak, jak je
   navrženo v §3? Mění se tím zadání — a bez toho zůstane V2 „správně" nerozbitá.
   Věcné odůvodnění je naměřené (`Mobile.cs:776-782`).
2. **Předsunout `render.chunk_mesh` (M9) před obsah M3+?** Dnes platí: 45 FPS,
   1 516 draw callů, kritérium ≤16 ms z `docs/01` §1.6 nedodržené.

**Co k tomu patří jako důkaz (a dnes chybí):**

* brána na **kadenci a rozestup** kroků (ne jen na počet),
* brána na **FPS / ms na frame** proti číslu z `docs/01` §1.6,
* test `can_step` na **reálné mapě** (most, svah) — dnes jen na fixtures,
* **vizuální kontrola pohybu** (dva po sobě jdoucí framy → posun postavy mezi nimi).

---

## 6. Měření, na kterých tahle revize stojí

| Sonda / zdroj | Co měří | Výsledek |
|---|---|---|
| `_analyza/vada-kadence-kroku.gd` (nová) | prodlevy mezi kroky při **držení klávesy** celou reálnou cestou (Input → loop → input_map → sim) | **7 kroků (718 ms) a 9 kroků (530 ms) za 5 s místo 13** — dva běhy téhož kódu (§2.1) |
| `_analyza/vada-svah.py` (nová) | obě pravidla výšky kroku na reálné mapě (`Movement.cs` + `Map.GetAverageZ`) | **4 013 z 165 985 kroků (2,4 %) blokujeme, UO je povolí; opačně 0** (§2.4) |
| `_analyza/vada-most-mapa.py` (nová) | plošný sken mapy: voda, statiky s `BRIDGE`, plochy nad vodou | 15 063 491 vodních dlaždic; 2 973 ploch nad vodou; arty `wooden bridge 0x07CA/0x07CB`; u Britannie `(1480,1766)` a `(1480,1767)` (§2.5) |
| `_analyza/vada-zabradli.py` (nová) | shody `z` mezi plochou a vysokým statikem + pořadí v souboru | **11 271 shod, 6 401 vad, z toho 71 nad vodou**; příklad `(1249,869)…(1249,876)` (§2.6) |
| `_analyza/vada-most*.gd` (nové, Godot) | molo u Britannie: statiky, `can_step`, dosažitelnost BFS, řazení | molo `x1522..1525 y1470..1500`; paluba `z=10..11` nad vodou `z=−5`; **544 zkoušených kroků, povoleno 0**; BFS z prkna = 1 dlaždice; rozhodující dvojice `(1525,1474)` (§2.5, §2.6) |
| `_analyza/vada-svahy.gd` (nová, Godot) | naše odmítnutí podle rozhodující podmínky | 38 424 povoleno / **19 656 odmítnuto**; `_fits` 1 380; voda 0 (§2.4) |
| `_analyza/vada-cena.gd` (nová, Godot) | přestavba seznamu, 7 pokusů | `visible()` studený **51,8 ms** (z toho `_z_grid` 6,7 + `draw_order` 13,0 + zbytek 32,1), teplý **0,262 ms**; 6 095 objektů (§1) |
| `assets/uo/anim/anim-sheets.json` | framy animace těla 400 | **10 framů na směr** (akce 0 = walk i 1 = run), akce 4 = 1 frame; `frame_ms = 80` → cyklus 800 ms [M] |
| `render/texture_cache.gd:29-36` | draw cally a ms na frame (12. session) | 1 516 draw callů, 11 534 primitiv, 22,3 ms / 45 FPS s vypnutým vsyncem [K] |
| `_src/classicuo`, `_src/servuo`, `_src/sphere` | pravidla a časování reference | citace v §2 [R] |

**Jak se to měřilo (aby se to dalo zopakovat):**

```powershell
$env:PYTHONIOENCODING='utf-8'
python _analyza\vada-svah.py           # ~2 s, jen čte assets/uo/world
python _analyza\vada-most-mapa.py      # ~16 s, plošný sken celé facety
python _analyza\vada-zabradli.py       # ~16 s
$env:APPDATA='E:\Workspaces\game-clone\.cache\godot-appdata'
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --path . `
    --rendering-driver opengl3 --resolution 1280x720 `
    --script res://_analyza/vada-kadence-kroku.gd
```

**Co v této revizi NENÍ naměřeno (a nesmí se z ní číst jako fakt):**

* **kadence byla měřena dvakrát** (jednou se zátěží cizího procesu, jednou bez)
  a **pokud jde o FPS, použij jen čistý běh**: oba běhy daly ~27 FPS, takže
  zátěž se na framech neprojevila, ale jisté to není. Simulace tiká správně
  (5000 ms sim na 5017 ms wall) —**prodlevy kroků nejsou zaseknutá simulace**;

---

## 7. Co se z této revize PROVEDLO (2026-10-07, 13. session)

| # | Co | Doklad (naměřeno) |
|---|---|---|
| **A** | **Kadence kroku.** Dvě změny: `sim/sim_world.gd:tick` teď tickuje **systémy před dispatchem příkazů** (krok, který je v tomto ticku na řadě, se aplikuje dřív, než sim odmítne nový jako `busy`) a `app/loop.gd` posílá vstupu **čas simulace** místo nástěnných hodin (`poll(..., sim.world_time())`) | Před: **7–9 kroků za 5 s, 530–718 ms, prodlevy 432…847 ms.** Po: **12 kroků za 5 s, průměr 405 ms, median 404 ms, 11 z 12 prodlev u 400 ms, 0 dvojnásobných** (`_analyza/vada-kadence-po-A2.txt`). Test `sim.world_loop` v `tests/cases/movement.gd` (4 kontroly) + mutace `world_loop` 1/1 |
| **D** | **Směr z myši je obrazovkový.** `app/input_map.gd`: `direction_from_screen(center, mouse)` (prahy 2/5 z `GameCursor.cs:670-754`), `player_screen_position()` jako protějšek `click_at`; kurzor na hráči = `-1` a **nespotřebuje prodlevu** | Testy: 16 větví tabulky ClassicUO + obě hranice (`|dy| = 0,4|dx|` a `2,5|dx|`) + střed = hráč + prodleva se nespálí. Mutace `input`: **10 z 10 chyceno** |
| **E** | **`PriorityZ` v řazení.** `render/sort.gd:priority_z()` (a `sort_key` podle ní), `render/chunk_renderer.gd:_priorita()` = `z − 1` za `IsBackground`, `+ 1` za `Height != 0` | Testy: `render.sort` priority_z rozhoduje na dlaždici, bez něj platí `z`, mimo rozsah se sveruje; `render.chunk` podlaha před zábradlím + bez tiledata = `z`. Mutace `sort`+`chunk_renderer`: **19 z 19 chyceno**. **Vizuálně**: `_analyza/snimky/mol-{pred,po}.png` — v „před" jsou sloupky i dřevěné zábradlí pod prkny, v „po" nad nimi (rozdíl 1 736 px přesně na zábradlí); **stejný stav dává bajtově stejný snímek** (determinismus obou běhů ověřen hashem) |

**Dokumenty, které se kvůli tomu přepsaly:** `docs/04 §4.2` (smlouvy
`render.sort`, `render.chunk`, `app.input`, `app.loop`, `sim.world_loop`),
`docs/02 §2.4` (klíč řazení je `priority_z`, ne `z`), `docs/05 §5.1.4`
(**zákaz plynulého pohybu zrušen** — naměřeno jako věcně nesprávný; krok
zůstává diskrétní, klient smí vykreslit posun plynule).

**Brány po opravách:** testy **969 kontrol / 0 selhání**, `run-all.py`
**11 měřeno / 0 vad**, `check-docs-refs` / `check-zadani` / `roadmap-gen --check`
**exit 0**, replaye **beze změny hashů**.

**Co z revize ZŮSTÁVÁ otevřené:** **V2** (interpolace + animace v jedné fázi),
**V4** (svahy: `_fits` z jednoho `z` místo rohů), **V5** (most: `F_WET` před
statiky + `_fits` proti vodě místo paluby), **M9/F** (`render.chunk_mesh` —
1 516 draw callů, 27 FPS) a **brány na chování v čase** (§4 této revize).
* **kolik z 22,3 ms na frame je CPU a kolik GPU** — měřeno `TIME_PROCESS`
  s vypnutým vsyncem v 12. session; je potřeba zopakovat stejným postupem;
* **jak přesně vypadá chůze na snímcích** — vizuální kontrola nebyla provedena
  (a u V2/V6 je to přitom jediný důkaz, který platí: „vizuální změnu ověř
  pohledem");
* **kolik kroků z V1 způsobí právě `busy`** — vzorec (5× ~800 ms, 2× ~500 ms)
  na to sedí, ale nebylo to měřeno s čítačem odmítnutí; ten je potřeba do
  opravy přidat jako měřitelnou veličinu;
* **most, který viděl uživatel** — naměřené příklady jsou jinde na mapě
  (Britannie má v dosahu jen dvě prkna `(1480,1766)`/`(1480,1767)`), takže
  „který most to byl" zůstává otevřené; mechanika je ale stejná všude.
