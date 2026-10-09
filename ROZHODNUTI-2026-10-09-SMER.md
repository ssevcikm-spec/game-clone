# Rozhodnutí o směru — 2026-10-09 (produkt, „feel" místo kopie, hranice automatizace, nejmenší hratelná smyčka, nový projekt klienta)

> **Co je tenhle soubor:** **záznam o rozhodnutích** — ne stav, ne zadání.
> Vznikl v session, kterou uživatel 2026-10-09 otevřel revizí cíle („přesná
> kopie hry nedává smysl… jediné, co může zůstat, je feel… musí to být
> modifikovatelné a rozšiřitelné… mohlo by mě bavit hrát UO like jako idle
> sandbox"). **Rozhodnutí níž jsou uživatelova** — odpovědi cituju doslova.
> Odhady jsou označené `[O]` a nejsou měření.
>
> **Současný stav projektu** je v `HANDOFF.md` (ten se přepisuje celý).
> **Cíl a rozsah** se berou z `docs/01-cil-a-scope.md` — ten se tímhle
> rozhodnutím **změnil**; změny jsou v něm i v `docs/09` označené datem.
> **Co je z tohohle souboru provedené**, je v §5; co zůstává otevřené, v §6.

---

## 1. Naměřená východiska

### 1.1 Čísla (a čím vznikla)

| Co | Hodnota | Jak změřeno 2026-10-09 |
|---|---|---|
| Trvání a velikost práce | 2026-10-02 → 2026-10-09; **127 commitů před touhle session** (HEAD `39ee290`); tahle session k tomu přidala 4 commity (**131** k `6f3802a`) — počet je čítač, ne konstanta, proto je u něj sha | `git rev-list --count <sha>`; data z `git log --format=%ad --date=short \| Sort-Object -Unique` |
| Herní kód | **10 617 řádků** (sim 4 198, app 3 169, render 2 399, ui 575, core 276) | `Measure-Object -Line` (neprázdné řádky) přes `sim/ app/ render/ ui/ core/`, přípony `.gd` a `.tscn` — **není to „jen `.gd`"**: `app/main.tscn` přidává 27 řádků (čistě `.gd` = 10 590) |
| Testy | **12 170 řádků** (jen `.gd` = 11 468) | totéž nad `tests/`, přípony `.gd .json .py .md` |
| Nástroje | **12 662 řádků** (extrakce UO 5 771, brány 5 068) | totéž nad `tools/`, přípony `.py` a `.gd` — **není to jen Python**: `tools/gates/sim_probe.gd` přidává 100 řádků (čistě Python = 12 562) |
| Data z UO | `items.json` **8 748** záznamů, `recipes.json` **1 053**, `skills.json` **58** | `ConvertFrom-Json` a počet top-level záznamů |
| Extrahované assety | 77 atlasových stran, **40** PNG animací (těla 400 a 401; v `anim-sheets.json` je **30** z nich), 12 náhledů artu, `world/map0.land` + `statics.bin/.idx` | `Get-ChildItem assets\uo -Recurse`; sondy `.tmp\sonda-anim.py` a `sonda-3-presna.py` |
| Rozhraní klon ↔ klient | `manifest.json` 10 271 078 B (77 stran, **49 705** spritů), `tiles.json` (item 65 536 × 9 polí, land 16 384 × 3), `hues.json` (375 skupin × **8** záznamů = 3 000 sad), `anim-manifest.json` (**586** těl), `content-report.json` (13 souborů bez generátoru, 1 362 nerozřešených jmen) | sondy v `.tmp/` (čtou jen, nic nezapisují) |
| Granule | **118** v `.forge/roadmap.json` (naměřeno po vložení milníku `MK` téhož dne; **před** ním 112); **stav se v roadmapě nevede** | `ConvertFrom-Json` + `Group-Object status` (prázdné) |
| Stav granulí | **61 měřeně hotových**, 4 „soubor je, test není", 53 chybí | `python tools/plan-status.py` (hotovo = soubor v gitu **A** existuje test); po milnících: M0 16/17, M1 16/23, M2 20/34, **MK 0/9, M3 1/5, M4 5/6, M5 0/11, M6 0/3, M7 0/4, M8 0/3**, M9 3/3 |
| `uo-shadows` (sousední projekt) | GDD **35 439 B**, ADD 26 125 B, TDD 48 864 B; roadmapa **21** granulí; „113 kontrol" je tvrzení z jeho `HANDOFF.md` | velikosti a počet granulí naměřeny nezávislým ověřením 2026-10-09; **jeho Godot sadu jsem nespouštěl** |

> **Přeměřeno nezávislým ověřovatelem (2026-10-09, read-only):** všechna čísla
> výš se reprodukují **jedním postupem** uvedeným v tabulce. Ověřovatel zároveň
> našel **čtyři vady popisků** („jen `.gd`", „řádků Pythonu", „jen `.gd`" u testů,
> 34 kB u GDD), které jsou **opravené tady**, a **pět vad smlouvy klienta**
> (`godot-uo-client/docs/01-data-uo.md`), které jsou opravené tamtéž. Dvě z nich
> vznikly vadou měřidla: sonda tiskla u dictu jen první dvě položky a nejvýš
> 12 klíčů, takže se do schématu dopsalo, co se nevytisklo. **Poučení: měřidlo,
> které tiše zkrátí výstup, vyrobí falešné schéma.**

### 1.2 Rozdíl, na kterém rozhodnutí stojí

Projekt dnes drží tři různé věci a každá má jinou cenu přenosu:

| Vrstva | Co to je | Přežije změnu cíle? |
|---|---|---|
| **A. Kostra** | deterministický tik, `Command` → `Event`, autorita v `sim/`, vrstvené brány, replay a hash testy, extrakční pipeline, metoda granulí | **~100 %** — a je to to, co by nový projekt musel zaplatit znovu |
| **B. Obsah a data** | 8 748 předmětů, 1 053 receptů, 58 skillů, mapa, atlas, animace | zůstává, dokud zůstává UO zdrojem obsahu |
| **C. Věrnostní pravidla** | Z-pásma ±14/16, fade střech, near-Z flood fill, hue matematika, světelný cyklus, kadence 400/200 ms | **skoro nic** — a je to přesně to, co uživatel nechce jako cíl |

**Z toho plyne hlavní věta tohohle rozhodnutí:** přechod není fork ani přepis.
Je to **přestat platit za C jako cíl** a nechat C v platnosti jako **nástroj**
(naměřené pravidlo z reference je levnější než vymyšlené).

---

## 2. Rozhodnutí

### D1 — Produkt je `game-clone`

**Rozhodnutí uživatele:** na dotaz „který z těch dvou má být produkt"
(`game-clone` vs. `uo-shadows`) — **`game-clone`**.

**Důvod:** má svět, data i nejlepší ověření (**1 466 kontrol / 0 selhání**
naměřeno na této revizi; `HANDOFF.md` z 20. session uváděl 1 422 — čítač roste
s přibývajícími testy; **11 bran** pouští `tools/gates/run-all.py` — naměřeno
**11 OK / 0 chyb**, `docs/08` jich popisuje **13** — dva čítače téhož slova),
a hlavně **kostru, na které stojí i to, co uživatel chce** (autorita v `sim/`,
vstup jen přes `Command`, běh headless). `uo-shadows` zůstává **držená opce** (D6).

**Cena:** projekt nese dokumenty psané pro věrnost — ty se musí přeoznačit
(D2), jinak budou agenti dál stavět kopii. To je práce s dokumenty, ne s kódem.

### D2 — Cílem je „feel", ne kopie

**Rozhodnutí uživatele:** „přesná kopie hry nedává smysl… zbavit se
technologických omezení a nedostatků — ty nemá smysl kopírovat… jediné, co může
zůstat, je feel."

**Co to znamená konkrétně:**

1. **Cíl** je: hratelná offline hra s feelingem UO, **bez** technologických
   omezení staré hry (trhavý pohyb, nejistota kde jsem a co vidím, brutální
   závislost na ručním klikání), **modifikovatelná a rozšiřitelná**.
2. **Reference zůstává**, ale jako **orákulum**: kde originál něco dělá dobře
   a je to naměřené, opisujeme ho (levnější a spolehlivější než vymýšlet).
3. **V1–V12 v `docs/01` §1.2 platí dál** — ale jako popis **chování, které
   bereme z reference**, ne jako cíl a ne jako požadavek doslovné shody
   (pixel, hash, kadence na milisekundu).
4. **Brány se nemění.** Paritní test obrazu dál měří **regresi**, ne cíl:
   když se obrázek rozbije, je to vada, i když „věrnost není cíl".

**Cena:** „feel" není měřitelný sám o sobě. Aby se z něj nestal cíl bez bran,
musí se rozepsat na **poznatky hráče** („poznám, kde jsem", „vidím, co mám
před sebou", „nemusím odklikat rutinu") — to je **otevřené téma §6.4**, ne
provedená práce.

### D3 — Hranice automatizace: hra smí provést, nesmí rozhodnout

**Rozhodnutí uživatele:** „**Přeformulovat N9**, ale zajímalo by mě, jestli jde
prohloubit koncept třeba podmínkami, takže nejen ‚udělej tunu mečů', ale
‚udělej toto a pokud nastane toto nebo tamto, udělej tamto'. Dokonce bych někdy
rád viděl, jak by si hra mohla hrát sama, abych viděl do uvažování té postavy.
… Primárně tedy ano — **já zadám co chci a hra/postava to umí provést.**"

**Nové znění pravidla (`docs/01` §1.5 bod 8):**

> Hra **smí provést, co hráč rozhodl** — i když u hry není (offline doběh),
> a včetně pravidel s podmínkami. Hra **nesmí rozhodnout za hráče**: co se má
> dělat, určuje hráč. QoL smí zkracovat klikání a zlepšovat čitelnost; výsledek
> pravidel se nemění (žádný loot navíc, žádné zkrácení časovačů).

**Tři vrstvy, které z toho vyplývají** (návrh do diskuse, ne hotová smlouva):

| Vrstva | Kdo rozhoduje | Příklad |
|---|---|---|
| **Úmysl** | hráč | „chci 500 ingotů", „chci mít u sebe 20 obvazů" |
| **Politika** | hráč (pravidla s podmínkami a prioritami) | „nejdřív těž; když dojde krumpáč, jdi ke kováři a kup nový; když je plný batoh, jdi k prodejci" |
| **Provedení** | hra (deterministicky) | kroky, časovače, řemeslo, cesta |

**Otázka, kterou musí zodpovědět design, ne kód:** *„Co je tvoje dovednost,
když nemusíš klikat?"* Odpověď téhle hranice je: **plánování a rozhodnutí**
(co, kdy, za kolik, s jakou zásobou). Ne klikací zručnost. Kdo tuhle otázku
neodpoví, dostane automat, který hraje místo hráče — a hráč u toho usne.

**Souběh s `uo-shadows`:** tamní non-goal `N9` zakazoval „automatickou
asistenci (pravidla hrají za hráče)" s odůvodněním, že to jde proti pilíři `P2`
(„požitek z vlastní dovednosti"). **Přeformulováno tamtéž 2026-10-09** stejnou
hranicí — oba projekty tak říkají totéž (viz §5).

### D4 — Nejmenší hratelná smyčka je KRÁTKÁ SMYČKA

**Rozhodnutí uživatele:** na dotaz „co je v nejmenší podobě hratelné" —
**„krátká smyčka + svět bez hráče"**.

`docs/01` §1.3 má osm vět a v nich souboj, magii, smrt i ukládání — to je celý
`M3`–`M8`. **Nejbližší cíl je menší a nic z něj na souboji nezávisí:**

| # | Věta krátké smyčky | Stav (2026-10-09) |
|---|---|---|
| K1 | Dojdu k prodejci a koupím krumpáč | **chybí** — vendor je v plánu až v `M7` |
| K2 | Vytěžím rudu | hotové (16. session, měřeno na reálné mapě) |
| K3 | U forge vytavím ingoty a vykovu předmět | hotové (měřeno: 624 rudy → 624 ingotů → dýka) |
| K4 | Prodám výrobek prodejci | **chybí** — totéž jako K1 |
| K5 | Zavřu hru, vrátím se a svět se posunul beze mě | **chybí** — žádný offline doběh, žádný scheduler |
| K6 | Zadám, co má postava dělat, a ona to provede (pravidla s podmínkami) | **chybí** — nová práce podle D3 |

**Odhadem `[O]` 6–10 granulí** do stavu, kdy je celá K1–K6 vidět na obrazovce.
Není to měření: vychází z toho, že K2/K3 jsou hotové a že K5 je „pár řádků"
podle `REVIZE-SMER-2026-10-07.md` §2.5 jen tehdy, když se offline doběh
**nepočítá jako simulace agentů** (past: aktivace podle sektorů kolem hráče bez
hráče nefunguje, takže mimo obrazovku musí být svět **funkcí času**, ne AI).
**Měřený kontext k tomu** (`tools/plan-status.py`, 2026-10-09): plná osmička vět
je `M3`–`M8`, což je **32 granulí, z nichž 26 chybí celých** (M5 0/11, M6 0/3,
M7 0/4, M8 0/3, M3 1/5, M4 5/6). Krátká smyčka (`MK`) má **9 granulí** — je tedy
**menší než třetina** toho, co ještě zbývá do „plné" hry, a nepotřebuje z toho
ani souboj, ani magii, ani smrt.

**Co to NEMAŽE:** `M3`–`M8` zůstávají v plánu i v roadmapě. Jen přestávají být
„to, co je nejblíž" — souboj a magie se dodělají, až bude smyčka hratelná.

### D5 — Moderní klient je NOVÝ PROJEKT

**Rozhodnutí uživatele:** „ještě se nechci vzdát možnosti vybudovat domácího
moderního klienta — můžeme to vytvořit jako nový projekt? Pokud ano, založil
jsem ve workspaces novou složku `godot-uo-client`."

**Ano — a jako nový projekt, ne jako fork.** Důvod je naměřený
(`REVIZE-SMER-2026-10-07.md` §1.3): na cizím shardu je **autorita server**,
takže klient nepotřebuje `sim/` (a fork by si ho přitáhl jako druhé místo
pravdy o poloze hráče). Klient potřebuje **druhou polovinu** projektu:
extrakci dat a vykreslování.

**Rozhraní mezi projekty (měřeno, §1.1):** klon generuje `assets/uo/`
(`manifest.json`, `tiles.json`, `hues.json`, `anim-manifest.json`,
`world/map0.*`) a klient **čte tentýž výstup** — jeden generátor, jedna
smlouva, dva konzumanti. Klient **nesmí** číst `.mul`/`.uop` (stejný non-goal
jako v klonu) a **nesmí** vlastnit stav světa.

**První milník klienta:** *vykresli svět UO a choď myší — **bez sítě***.
Síť (protokol) je druhá věc: u cizích shardů je to **17 238 řádků protokolu
a ~141 000 řádků zbytku klienta** (gumpy 50 978), plus čtyři osy, které se
násobí (26 opkódů mění délku podle verze klienta, 12 hodnot expanzí, vendor
rozšíření, vlastní obsah shardu) — citace v `REVIZE-SMER-2026-10-07.md` §1.3.
Proto: **nejdřív vlastní server (nebo lokální svět), cizí shardy až potom.**

**Právně:** assety z instalace UO jsou autorská díla EA/Broadsword — nesmí se
distribuovat (`docs/03` §3.1); hudba a zvuky pro veřejné vydání se nahrazují.

### D6 — `uo-shadows` zůstává držená opce (nezavírat)

**Co v něm je a má cenu:** hotový **design** (GDD/ADD/TDD: pilíře, prvních
5 minut, `V1`–`V8`, non-goals), malý jasný rozsah a v kódu `offline.gd`
a `assist.gd` — tedy přesně ta dvě témata, která uživatel dnes zvolil.
Drží ho cloudová orchestra `forge-orchestra`, která je **momentálně červená**
(20 selhání v řadě, prázdná roadmapa — stav z jeho `HANDOFF.md`, ne měření).

**Co to znamená pro tuhle session:** nic se tam nepřepisuje; jen se srovnalo
`N9` (D3), aby oba projekty neříkaly opak. Rozhodnutí, jestli se v něm
pokračuje, je **odložené** — není potřeba k produktu (`game-clone`).

### D7 — „Feel" je definovaný a potvrzený (s výjimkou: zobrazení zdraví)

**Rozhodnutí uživatele:** syntéza pocitu („se vším v podstatě souhlasím")
**s jednou výhradou** — nesouhlasí s tím, aby **neviditelnost životů** byla
pravidlem: chce být připraven dělat ústupky a tohle je ten případ; **rozhodne,
až si to zahraje**, pokud je to vratné.

**Co je tím rozhodnuté:** definice pocitu je zapsaná v `docs/01` §1.8 jako pět
poznatků hráče (`F1`–`F5`) **s tím, jak se ověří** — tím je zavřené otevřené
téma „feel jako měřitelná definice" (§6.4).

**Co je odložené a vratné:** zobrazení zdraví. Naměřeno v referenci: health bar
je **klientská volba, ne vlastnost simulace** —
`_src/classicuo/src/ClassicUO.Client/Game/UI/Gumps/HealthBarGump.cs:21,302`
(`BaseHealthBarGump`, `HealthBarGumpCustom`), `Game/Managers/HealthLinesManager.cs:11-23`
(health lines nad mobily), `Game/Scenes/GameSceneInputHandler.cs:204-217`
(otevře se i na cizí mobil), `Configuration/Profile.cs:174`
(`CloseHealthBarType`), `OptionsGump.cs:4319-4341` (přepínač vlastních barů).
Zapnutí/vypnutí je tedy přepínač v konfiguraci klienta a rozhodnutí může padnout
později **bez zásahu do pravidel**.

**Co platí tvrdě i tak (architektura, ne vkus):** zobrazení **nesmí měnit
pravidla** (simulace nesmí číst UI ani se ptát, co je vidět; žádné pravidlo
nesmí záviset na tom, jestli je bar zapnutý) a přepínač musí být **na jednom
místě**. Až se rozhodne, patří k tomu **sonda** (kolik rozhodnutí hráč udělá
s health barem a bez něj), ne dojem.

**Cesta zpět:** není potřeba — nic se nezakazuje, `docs/01` §1.8 vede zobrazení
zdraví jako **odložené**.

### D8 — Brány z pocitu `F1` a `F4` jsou schválené

**Rozhodnutí uživatele:** „Schvaluji jako **F1** a **F4**." Obě brány jsou
zapsané v `docs/08` §8.2 (tabulka bran) i s poznámkou, že **do milníku `MK`
vrací `2` (NEMĚŘENO)** — `sim.offline` a obchod ještě neexistují a `2` se
nesmí tvářit jako zelená. Kontroly a mutace, které brány musí mít, jsou
v `NAVRH-BRAN-FEEL-2026-10-09.md` §2–§3.

**Co to znamená pro práci:** brány se implementují **spolu s `MK`** (jsou na něm
závislé) a do `run-all.py` se zapíšou, až soubory bran existovat budou.

**Cesta zpět:** smazat dva řádky v `docs/08` a dvě zmínky v `docs/01` §1.8.

### D9 — Multiplayer: obojí, `always-on` odložený; hodiny světa patří do simulace

**Rozhodnutí uživatele:** „Volitelně bych rád povolil **obojí** s tím, že
**always-on bude odložené**, až na to přijde relevance."

**Co je tím rozhodnuté:**

1. **Session u hostitele** je první multiplayer — cena nula, žádná údržba,
   svět běží, dokud běží hostitel.
2. **Always-on svět** zůstává v plánu jako **odložený**, ne zamítnutý.
3. **Závazné pravidlo pro `sim.offline` (platí od teď):** hodiny světa bydlí
   **v simulaci** a „offline" znamená **„bez připojeného klienta"**, ne „bez
   hráče". Tím zůstanou singleplayer, session u hostitele i always-on server
   **týmž kódem**; kdyby to bylo naopak, MP by musel `sim.offline` přepisovat.
4. **Kolik hráčů:** zatím neurčeno („zatím nevím") — architektura to unese,
   číslo se doladí podle provozu.

**Hosting (analýza, ne rozhodnutí):** `oracle-frankfurt` je Oracle Cloud **ARM**
a **může být i herní server**, ale platí se za čtyři věci, které kapacitou
koupit nelze: **latence z vytížení** (uzel dělá těžké CI úlohy), **bezpečnostní
dosah** (veřejný port na stroji, kde běží self-hosted runner s tokeny),
**sdílený osud** (OOM/restart shodí svět) a **provoz** (zálohy, restarty,
monitoring). Naměřená oprava předpokladu: **conductor na Oracle neběží** — je to
Cloudflare Worker; Oracle uzel je **výpočetní uzel** orchestra. Detaily a návrh
řešení: `NAVRH-BRAN-FEEL-2026-10-09.md` §6.1b.
**Co k tomu chybí:** (a) reálná kapacita uzlu a (b) tik při běžícím buildu.

---

## 3. Proč to není „začít znovu" (a co by naopak drahé bylo)

| Kdyby se šlo na novou kolej od nuly | Cena |
|---|---|
| Kostra (10 617 řádků kódu, 12 170 testů, 12 662 nástrojů) | znovu zaplatit |
| Art a mapa | **nejdražší jednotková položka**: 8 748 předmětů, mapa 7168 × 4096 dlaždic, animace — dnes „zdarma" z vlastní instalace; náhrada = generování nebo zakázka a **jiný feel** |
| Znalost (recepty, vzorce, 23 naměřených pastí, extrakční pipeline) | znovu naměřit |

**A co v projektu naopak chybí, ať se rozhodne jakkoli:** **modifikovatelnost**.
Dnešní design jsou pevné smlouvy a brány (`docs/04`, 100 modulů) — výborné pro
věrnost a měření, ale **není to návrh pro moddery** (švy, stabilní ID, pořadí
načítání, verzované ukládání, sandbox skriptů). „Modifikovatelné a rozšiřitelné"
je **nová práce**, ne vlastnost, kterou projekt má.

---

## 4. Odpověď na uživatelovu otázku „není přechod už moc komplikovaný?"

**Není — protože se nepřechází kódem, ale cílem.** Co by se při změně směru
zahodilo, je vrstva **C** (§1.2) — a to je přesně ta, kterou uživatel nechce.
Co by se naopak muselo zaplatit znovu (kostra, obsah, znalost), zůstává.

Rozhodující je proto něco jiného než „fork ano/ne": **přestat platit za C jako
cíl** a přesunout session do práce, kterou uživatel chce (D4, D5, D3).

---

## 5. Co se tímhle rozhodnutím PROVEDLO (a kde)

| # | Změna | Kde |
|---|---|---|
| 1 | Cíl přeformulován: „feel" místo kopie; V1–V12 přeoznačeny na „co bereme z reference" | `docs/01-cil-a-scope.md` §1.1, §1.2 (hlavička + úvod) |
| 2 | Nejmenší hratelná smyčka `K1`–`K6` zapsána jako nejbližší cíl | `docs/01-cil-a-scope.md` §1.3 |
| 3 | Hranice automatizace (přeformulované `N9`) místo zákazu vylepšení | `docs/01-cil-a-scope.md` §1.5 bod 8 |
| 4 | Pravidla pro agenty: „něco je lepší než UO → neimplementuj" nahrazeno hranicí D3 | `docs/09-pravidla-pro-agenta.md` §9.5 tabulka + bod 10 |
| 5 | Návod pro člověka: „nepřidávat vylepšení, která UO nemá" nahrazeno hranicí D3 | `START-TADY.md` §4 bod 4 |
| 6 | Staré zadání `ZADANI-DALSI-VYVOJ.md` označeno jako překonané v tom bodě (nemaže se) | `ZADANI-DALSI-VYVOJ.md` hlavička |
| 7 | `N9` v `uo-shadows` přeformulováno stejnou hranicí | `E:\Workspaces\uo-shadows\docs\GDD.md` §11 |
| 8 | Nový projekt klienta založen (kostra, smlouvy, zadání prvního milníku) | `E:\Workspaces\godot-uo-client\` |
| 9 | Hlavní zadání označeno jako v cíli překonané (nemaže se, jen doplňuje) | `ZADANI-UO-KLON.md` hlavička |
| 10 | Rozcestník balíčku popisuje nový cíl místo „měřitelné věrnosti" | `README.md` řádek o `docs/01` |
| 11 | V `docs/01` přejmenovány popisky, které by tvrdily opak („věrnostní bod" → „co bereme z reference", „pravidlo věrnosti" → „pravidlo odchylky", „věrnostní audit" → „audit") | `docs/01-cil-a-scope.md` §1.2, §1.7 |
| 12 | Do plánu vložen milník **`MK` (krátká smyčka)** s 9 granulemi, obchod přesunut z M7, přidány vlny W13/W14 — roadmapa přegenerovaná | `tools/roadmap-gen.py`, `tools/plan-status.py`, `docs/07` §7.2/§7.3, `.forge/roadmap.json` |
| 13 | Rozbité markdown tabulky opraveny (3×) a zapsána třída vady | `docs/01`, `HANDOFF.md`, §6.7 |
| 14 | Definice „feel" zapsána jako `F1`–`F5` s tím, jak se ověří; **zobrazení zdraví** vedeno jako **odložené a vratné** | `docs/01` §1.8, §2 D7 |
| 15 | Brány z pocitu **`F1` a `F4` schváleny** a zapsány do smlouvy (do `MK` vrací `2` = neměřeno) | `docs/08` §8.2, `docs/01` §1.8, `NAVRH-BRAN-FEEL-2026-10-09.md` |
| 16 | **Multiplayer:** rozhodnut tvar (session první, `always-on` odložený) + závazné pravidlo „hodiny světa v simulaci, offline = bez klienta" | §2 D9, `HANDOFF.md`, `NAVRH-BRAN-FEEL-2026-10-09.md` §5–§6 |
| 17 | **`MK` zahájen:** hotové granule `sim.scheduler` a `sim.save` (mechanika persistence + stavové zdroje) | `sim/scheduler.gd`, `sim/save.gd`, `tests/cases/scheduler.gd`, `tests/cases/save.gd` |
| 18 | **Jedna dokumentovaná změna specu** (schválena uživatelem): `state_hash()` zahrnuje stavové zdroje; očekávané hashe replayů přepnuty **s dokladem, že chování je stejné** | `sim/sim_world.gd`, `tests/replays/*.json`, `tests/replays/README.md`, `_analyza/p30-replay-legacy-hash.gd` |

**Co zůstalo beze změny a je to tak správně:** `docs/02`–`docs/08`, `docs/10`,
`docs/11`, brány, `project.godot`, `.forge/roadmap.json` — **plán se tímhle
rozhodnutím neškrtá** (§6.1).

---

## 6. Otevřená témata (pojmenovaná, ne provedená)

### 6.1 Roadmapa pro krátkou smyčku — ✅ PROVEDENO 2026-10-09

Vznikl **nový milník `MK` (krátká smyčka)**, vložený **mezi M4 a M5** — krátká
smyčka nepotřebuje souboj ani magii, takže by na ně čekala zbytečně. Nese
**9 granulí**:

| Granule | Co řeší |
|---|---|
| `sim.scheduler` | **typovaná vrstva řídkých událostí NAD `core.clock`** — ne druhý timer (naměřeno: `core.clock` timery má, ale nikdo je nevolal) |
| `sim.save` | uložení a načtení **světa** (dnes obálka s prázdnými `mobiles`/`items`) + migrace |
| `sim.offline` | svět jde dál i bez hráče — **funkce času, ne simulace agentů** |
| `sim.policy` | politika: pravidla s podmínkami a prioritami (data, ne kód) |
| `sim.executor` | vykonavatel: mění rozhodnutí na `Command`, nikdy nesahá na stav |
| `sim.decision_log` | „vidět do uvažování postavy" — které pravidlo se vyhodnotilo a proč |
| `data.vendors`, `sim.vendor`, `ui.vendor_gump` | **přesunuté z M7** — bez obchodu nejde „prodám výrobek prodejci" |

**Stav granul (2026-10-09):** hotové **2 z 9** — `sim.scheduler` (typovaná
vrstva řídkých událostí nad `core.clock`; ne druhý timer) a `sim.save`
(mechanika persistence: IO, verze 2 s migrací 1→2, stavové zdroje; **fronta
plánovače přežije save/load**). První stavový zdroj je plánovač. **Entity
(mobily, předměty) zdrojem ještě nejsou** — `entity.mobile` a
`sim.entity_registry` nemají `state()`/`restore()`, což je další krok.

**Měřeno po změně** (`tools/plan-status.py`): granul **118** (bylo 112),
`MK` 0/0/**9**, M7 spadlo na 4 granule, pokrytí vlnami **80 z 118** (přidány
vlny W13 a W14), DAG konzistentní, žádná kolize `owns`. Rozšíření milníku je na
**třech místech** (`MILNIKY_PORADI`, `MILNIKY`, `docs/07` §7.2) — stejný postup,
jaký projekt už má pro trať zvuku („vlastní milník `A`").
**Nic se přitom nemazalo:** `M5`–`M8` zůstávají v platnosti, jen přestaly být
tím, co je nejblíž.

### 6.2 Podmínky v politice (uživatelův námět) — ✅ v plánu jako `sim.policy`

„Udělej tunu mečů" je cíl; „když nastane toto, udělej tamto" je politika.
Návrh tvaru: **pravidla s prioritou a fallbackem**, data (JSON), ne kód —
aby se dala ladit a testovat bez zásahu do simulace. **Past:** politika musí
být **deterministická** (jinak padá replay a hash testy, což je nejsilnější
zbraň projektu).
**Stav:** tvarem se zabývá granule `sim.policy` (§6.1); **otevřené zůstává, jak
hluboké podmínky mají být** — jestli stačí data (podmínka + priorita), nebo má
vzniknout malý jazyk pravidel. To je rozhodnutí uživatele, ne agenta.

### 6.3 „Vidět do uvažování postavy" (uživatelův námět) — ✅ v plánu jako `sim.decision_log`

Aby se dalo dívat, jak si hra hraje sama, musí být vidět **důvod**, ne jen
akce: které pravidlo se vyhodnotilo, které ne a proč („nemám materiál",
„cesta je blokovaná", „priorita níž"). Kostra je na to ideální — simulace je
deterministická a událostní, takže se dá **logovat rozhodnutí**, ne jen
následek. A je to **testovatelné**: pravidlo + stav světa → očekávané
rozhodnutí je brána. Návrh: `ui/journal` je přirozené místo („co se stalo,
když jsi nebyl") a `ui/debug_overlay` místo pro živý pohled.
**Stav:** zapsáno jako granule `sim.decision_log` (§6.1) — zapisuje důvod jako
události, zobrazuje `ui.journal` (ta se needituje, patří své granuli).

### 6.4 „Feel" jako měřitelná definice — ✅ PROVEDENO 2026-10-09

Zapsáno do `docs/01` **§1.8** jako pět poznatků hráče `F1`–`F5`, každý s tím,
**jak se ověří** (sonda nad simulací, datová brána, zákazový sken, sonda
ulož/načti) — a s výslovným pravidlem, že **pocit se neměří snímkem**.
Přidána i hranice pro informace („čitelnost ano, jistota ne") **s výjimkou
zobrazení zdraví, která je odložená a vratná** (D7).
**Zbývá na uživateli:** jestli z `F1` (svět má vlastní čas) a `F4` (nic není
odpad) mají být **brány** v `docs/08` — brány jsou smlouva, ne úklid.

### 6.5 AI interakce a „komplexní robot" (uživatelův námět — k rozhodnutí)

Uživatel výslovně řekl: „Můžeme jako poznámku pro zvážení zadat AI interakci?
Nebo aspoň nějakého komplexního robota?" **Zapsáno jako námět k rozhodnutí —
ne jako schválená práce.** Dvě různé věci se nesmí slít do jedné:

| Varianta | Co to je | Riziko |
|---|---|---|
| **LLM jako autor politiky** (offline) | uživatel napíše česky, co chce; LLM z toho vyrobí pravidla (data), která hra vykonává | **nízké** — hra zůstává deterministická, model neběží při hraní, výsledek je verze dat |
| **LLM v běhu hry** (rozhoduje za postavu) | postava se ptá modelu, co má dělat | **vysoké** — nedeterminismus (padá replay a hash), latence, cena, neověřitelnost; non-goal #5 (`docs/01`) zakazuje nové závislosti bez zápisu v `docs/` |

**Doporučení k rozhodnutí:** začít první variantou a druhou **držet jako
oddělený experiment**, který umí jen vybírat **cíl** z nabídky a do stavu světa
nesahá. Rozhodnutí patří uživateli.

### 6.6 Modifikovatelnost

Viz §3 — dnes v projektu **není** navržená. Až se rozhodne, co to znamená
(data? skripty? pluginy? vlastní mapy?), je to samostatné zadání, protože mění
smlouvy (`docs/04`).

### 6.7 Brána na rozbité tabulky v dokumentaci (návrh z ověření)

Ověření dnes našlo **třídu vad, kterou žádná brána neměří**: poznámka vložená
doprostřed markdown tabulky ji rozbije (řádky za ní ztratí hlavičku a nevykreslí
se). Naměřeno třikrát — jednou v téhle session, dvakrát už dřív. Sonda, která to
hledá, existuje (`.tmp/sonda-tabulky.py`, self-test 4/4) a po opravách hlásí
**0 vad** ve všech třech projektech.
**Rozhodnutí k provedení:** má z ní být brána (`G14`)? Brány jsou specifikované
v `docs/08` a jejich počet je součást smlouvy — přidání brány je změna
smlouvy, ne úklid, takže patří uživateli.

---

### 6.8 Brány z pocitu (`F1`, `F4`) — ✅ ROZHODNUTO (D8)

Uživatel schválil brány **pod označením `F1` a `F4`**; jsou zapsané v `docs/08`
§8.2 a **čekají na implementaci spolu s `MK`** (do té doby vrací `2` = neměřeno).
Návrh s kontrolami a mutacemi: `NAVRH-BRAN-FEEL-2026-10-09.md`.

### 6.9 Multiplayer a hosting — ✅ ROZHODNUTO (D9); hosting MÁ ČÍSLA (doplněno 2026-10-09)

Tvar je rozhodnutý: **session u hostitele první, `always-on` odložený**, a platí
pravidlo „**hodiny světa v simulaci, offline = bez připojeného klienta**".
Počet hráčů zatím neurčen. **Hosting je analýza, ne rozhodnutí** — Oracle ARM
uzel to umí, ale platí se za latenci z vytížení, bezpečnostní dosah, sdílený osud
a provoz; chybí k tomu dvě měření (kapacita uzlu, tik při buildu).
Detaily: `NAVRH-BRAN-FEEL-2026-10-09.md` §5–§6.1b.

**DOPLNĚNO 2026-10-09 (třetí session téhož dne, zadání `ZADANI-22`): telefon je
změřený, a tím se ruší jen poslední věta předchozího odstavce („hosting zůstává
analýzou"). Čísla a příkazy: [`MERENI-TELEFON-2026-10-09.md`](MERENI-TELEFON-2026-10-09.md).**

* **Engine fit je prokázaný:** Godot 4.7.2 ARM64 na telefonu běží
  (`--headless --version` → `4.7.2.stable.official.ed1daf0bf`, exit 0) a **naše
  testovací sada na něm projde: 61/61 case souborů, 1466 kontrol, 0 selhání, 28 s**
  (bez `assets/uo`, jako v CI). Cesta: **`chroot` pod rootem** — `proot-distro`
  na tomhle telefonu **nefunguje** (Ubuntu 24.04 = glibc 2.43 s `clone3()`,
  Termux proot 5.1.107.96 z 2021 → zacyklení na prvním externím příkazu).
* **Rozhodnutí role telefonu:** **hostitel LAN session pro 2–4 hráče
  (podmíněně); `always-on` i veřejný server = NE.** Pro: prokázaný engine fit,
  LAN 189 Mbit/s, 103 GB volných, stabilní adresa. Proti `always-on`: 1,3–1,5 GB
  volné RAM, 60–64 °C při krátké zátěži, jádra pro app doménu jen 4–6 (a mění se
  v čase), start serveru vyžaduje chroot pod rootem, domácí upload 24 Mbit/s za NAT.
* **D9 se nemění.** `always-on` zůstává odložený; **NEMĚŘENO** zůstávají: tik
  ≤ 2 ms (chybí sonda nad `sim`), soak 24 h a upload/NAT zvenčí.
* Riziko, které k telefonu patří dál: statická `192.168.109.104` **leží v rozsahu,
  který router rozdává** (stav paralelní session, `redmi-server/STAV.md` §2).

---

## 7. Cesta zpět (co je vratné a jak)

| Rozhodnutí | Cesta zpět |
|---|---|
| D1 produkt | `uo-shadows` je nedotčený a má vlastní orchestraci; návrat = jedna session |
| D2 cíl | `docs/01` §1.1/§1.2 mají původní znění zachované jako citaci |
| D3 hranice | bod 8 v `docs/01` §1.5 má původní znění v citaci; `N9` v `uo-shadows` je přeformulovaný, ne smazaný |
| D4 krátká smyčka | `M3`–`M8` nebyly smazány ani přesunuty; návrat = změna pořadí v plánu |
| D5 klient | nový projekt je oddělený repozitář; nic v `game-clone` na něm nezávisí |
| D6 uo-shadows | nedotčeno kromě `N9`; jeho dokumenty zůstávají |

---

**Kdo to má použít:** kdo v `game-clone` zadává práci, bere odsud **cíl**
(D2), **hranici** (D3) a **nejbližší smyčku** (D4); kdo staví klienta, bere
**rozhraní** (D5). Kdo hledá **stav**, čte `HANDOFF.md` — tenhle soubor je
záznam o rozhodnutích a **nepřepisuje se** (doplňuje se).
