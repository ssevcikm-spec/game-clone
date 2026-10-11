# MĚŘENÍ — pilot vlastního artu (`tools/artgen/`, `assets/own/`)

> **Co je tenhle soubor:** **záznam o měření** (co se naměřilo, jak a s jakým
> výsledkem) k zadání [`ZADANI-25-VLASTNI-ART.md`](../../ZADANI-25-VLASTNI-ART.md).
> Není to plán ani zadání a **nepřepisuje se** — čísla se do něj jen doplňují
> s datem. **Současný stav pilotu** je `assets/own/manifest.json` (a jeho
> `report`); tenhle soubor říká, co ta čísla znamenají a odkud jsou.
>
> **Datum měření:** 2026-10-10. **Kde:** stanice s Windows, Blender **5.2.1 LTS**
> (`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`), Python 3.12
> (Pillow 12.3, numpy 2.5, scipy 1.18). **Jakákoli čísla odsud platí pro tuhle
> stanici** — na jiném stroji se musí přeměřit (`python tools/artgen/run_all.py`).

## 1. Co se vyrobilo

| Druh | Spritů | Modelů | Stránek atlasu | Poznámka |
|---|---|---|---|---|
| `land` (tráva id 3, cesta id 1001) | 2 | 2 | 1 | 44 × 44, `ox/oy = 0/0` |
| `item` (dýka 3921, krumpáč 3717, ruda 6583, ingot 7151) | 4 | 4 | 1 | kotva vzorcem UO |
| `anim` (tělo 400, akce walk, 5 směrů × 8 framů) | 40 | 1 | 1 | 40 spritů z JEDNOHO modelu |
| **celkem** | **46** | **7** | **3** | `min(d['sprites'])` = 46 (ZADANI-25 §6) |

K tomu `assets/own/anim/anim-sheets.json` + 5 pruhů PNG ve **tvaru UO anim
exportu** (postava se ve hře bere odtud, ne z manifestu — `render/anim_player.gd:32`).

## 2. Naměřené časy (sekundy → minuty)

Postup: `python tools/artgen/run_all.py` — spustí každou fázi znovu a **změří ji**;
výsledek zapíše do `tools/artgen/_casy.json`. Čísla níž jsou **jeden běh
z 2026-10-10** (naměřeno, ne odhad):

| Fáze | Co se spustilo | Sekund | Podíl |
|---|---|---|---|
| kontrola projekce | `probe_projection.py` (Blender) | 5,8 | 11 % |
| **model** — předměty (4) | `build_model_items.py --item all` | 3,3 | 7 % |
| **model** — dlaždice (2) | `build_model_tiles.py --tile all` | 4,1 | 8 % |
| **model** — postava (1) | `build_model_character.py` | 4,2 | 8 % |
| **render** — předměty (4 sprity) | `render_sprites.py --plan items` | 5,4 | 11 % |
| **render** — dlaždice (2 sprity) | `render_sprites.py --plan tiles` | 5,1 | 10 % |
| **render** — postava (40 spritů) | `render_sprites.py --plan character` | 12,5 | 25 % |
| **postprocess + atlas** (46 spritů) | `pack_atlas.py` | 6,4 | 13 % |
| kontaktní list | `contact_sheet.py` | 2,2 | 4 % |
| vzorky UO (měření barev) | `vzorky_uo.py` | 1,4 | 3 % |
| **celkem (stroj)** | | **50,4 s = 0,84 min** | 100 % |

**Přepočet na kus** (děleno počet spritů; od Blenderu se odečítá ~1,5 s
startu na jedno spuštění, jinak by číslo bylo o startu, ne o práci):

| Co | Naměřeno | Po odečtení startu Blenderu |
|---|---|---|
| 1 sprite: render | 23,0 s / 46 = **0,50 s** | **~0,34 s** |
| 1 sprite: postprocess + zabalení | 6,4 s / 46 = **0,14 s** | 0,14 s |
| 1 nový model (primitiva + kamera + světla) | 11,6 s / 7 = **1,66 s** | ~0,5 s (postava ~2 s, 25 meshů + kostra) |
| **1 sprite od hotového modelu** | | **~0,5 s stroje** |

**Kolik spritů z jednoho modelu:** postava **40** (5 směrů × 8 framů),
dlaždice a předměty **1**. Průměr 46/7 = **6,6 spritu na model** — a to je
důvod, proč se vyplatí modelovat věci, které se opakují (postavy, zbroje),
a ne jednotlivé statiky.

**Ruční lidská práce (co stroj nezměřil):** kontroly pohledem. Během pilotu
jich bylo **11** (viz §3) a **každá našla něco**, co strojové kontroly
neodhalily. Jedna iterace = model + render + postprocess + list + pohled
(strojová část ~20–30 s podle druhu, lidská část je to, co se měřit nedá).

## 3. Co se muselo ručně sáhnout (a kolik iterací to stálo)

| # | Vada | Kdo ji našel | Iterací |
|---|---|---|---|
| 1 | **Orientace ingotu**: tyč mířila ke kameře (obsah 8 × 16 px místo 15 × 15) — model byl omylem otočený o −45° | měření + list | 1 |
| 2 | **Krumpáč mimo střed**: obsah byl o 2 px vpravo od kotvy (model nebyl vystředěný na počátku) | měření (`--tabulka-raw`) | 1 |
| 3 | **Postava jako hůl**: 9 px široká (ruce schované v tunice) — UO má 24–25 px | **pohled** | 2 |
| 4 | **Černé linky na stycích dlaždic** (maska + barva) | **pohled** | 2 |
| 5 | **Barvy 2–3× světlejší než UO** (tráva 121,144,82 vs 42,64,13) | měření barev | 3 |
| 6 | **Záměna obrázku a pozice v atlasu** (dýka vložená na místo rudy) | brána `--check` | 1 |
| 7 | **Ruda slepená v balvan** (5 velkých hrud), UO má rozsypaný shluk | pohled | 1 |
| 8 | **Chybějící klíč `chyby`** v anim listech proti UO | brána `--check` | 1 |
| 9 | **Sekce SCENA se vykreslila BEZ postavy** (překlep v klíči `(směr, frame)` vs `("anim", id)`) — sekce nespadla, jen tiše vynechala vstup | **pohled** | 1 |

**Poučení, které stojí za zapsání:** #3, #4, #7 a #9 prošly **všemi** strojovými
kontrolami (maska dlaždice se rovnala UO na pixel, 476 kontrol zelených) —
vidět je bylo jen na kontaktním listu. Naopak #1, #2, #5, #6 a #8 pohledem
vidět nejsou (nebo až po přeměření) a našly je metriky. **#9 je přesně ta past
ze skillu `overovani`: „brána, která čeká na vstup, jenž nikdy nepřijde"** —
sekce se vyrobila, jen bez toho, co měla kontrolovat.

## 4. Naměřená shoda s UO (kontrakt a vzhled)

**Kontrakt atlasu** (`python tools/artgen/pack_atlas.py --check` → 476 kontrol, 0 chyb):

| Co se kontroluje | Výsledek |
|---|---|
| klíče manifestu proti `assets/uo/manifest.json` | **shodné** (9 klíčů, rozdíl ∅) |
| klíče spritu | **shodné** (`id`,`kind`,`page`,`x`,`y`,`w`,`h`,`ox`,`oy`,`rect`) |
| každá kotva = vzorec UO `ox=(w>>1)-22, oy=h-44` | 46/46 |
| dlaždice: maska kosočtverce proti **reálné masce UO** | **rozdíl 0 px** (1012 px, 44 × 44) |
| střed obsahu proti kotvě | ≤ 1 px u všech 46 |
| přesah obsahu pod kontakt | ≤ 22 px (naměřeno max 21,9 u dlaždice) |
| mezery a překryvy na policích | 0 chyb (pad 1) |
| každé naše `land`/`item` id existuje v UO manifestu (seam = náhrada) | 6/6 (+ anim klíče 5/5) |
| **determinismus** | dva běhy → shodný SHA-256 manifestu `59b2c046…` |

**Vzhled (naměřené průměrné barvy obsahu, sRGB):**

| Prvek | vlastní | UO | rozdíl |
|---|---|---|---|
| tráva (land 3) | (57, 70, 51) | (42, 64, 13) | jas −0,8×, **modrá +38** (modrý ambient) |
| cesta (land 1001) | (60, 56, 54) | (50, 44, 41) | +10…+13 (o 20–30 % světlejší) |
| dýka (3921) | (79, 72, 63) | (62, 52, 68) | teplejší (UO je do modra) |
| krumpáč (3717) | (73, 64, 54) | (74, 53, 35) | jas shodný, menší sytost |
| ruda (6583) | (72, 61, 58) | (94, 60, 57) | −22 v červené |
| ingot (7151) | (72, 75, 79) | (70, 81, 89) | −6…−10 |

**Velikosti obsahu** (cíl = naměřený obsah UO, takže se porovnává stejně velká věc):

| Prvek | vlastní obsah | UO obsah |
|---|---|---|
| dýka | 11 × 11 | 11 × 11 |
| krumpáč | 24 × 26 | 26 × 26 |
| ruda | 32 × 35 | 30 × 35 |
| ingot | 12 × 15 | 15 × 15 |
| postava (frame) | 16 × 60 | 18–40 × 56–64 (medián 25 × 60) |

**Projekce** (`probe_projection.py`, měřeno težišti značek v renderu):
naše kamera po korekci (zrcadlení + svislé roztazení) dává osy **+X → (0,500;
0,500)**, **+Y → (−0,500; 0,500)**, **+Z → (0; −1,004)** šířky artu — UO
(`core/iso.gd`: 22 px na osu, 44 px na jednotku výšky) dává (0,5; 0,5),
(−0,5; 0,5), (0; −1,0). **Shoda** (tolerance 0,02).

## 5. Kde je úzké hrdlo

**Není to stroj.** Stroj vyrobí 46 spritů ze 7 modelů za **50 sekund**; na
jeden sprite od hotového modelu padne **0,5 s**. Kdyby šlo jen o čas CPU,
byla by celá faceta (1 496 land artů + 6 023 statiků = 7 519 spritů) za
7 519 × 0,5 s ≈ **63 minut** stroje (a modely k tomu — u statiků je to
3 000 × 1,7 s ≈ 85 minut, tedy ~2,5 h celkem).

**Úzké hrdlo je kontrola pohledem — a je to naměřené, ne dohad:**

1. **Strojové kontroly jsou slepé k tomu, co je vidět.** Stav, ve kterém
   dlaždice měly černé linky na stycích (#4) a postava byla 9 px široká (#3),
   prošel **470 kontrolami s 0 chybami** — maska dlaždice se přitom rovnala
   UO na pixel. Brána umí „sedí to na pixel", neumí „vypadá to jako tráva".
2. **Každý pohled něco našel** (10 iterací, 8 vad, z toho 3 jen pohledem).
3. **Cena jednoho pohledu neroste s počtem spritů, ale s počtem MODELŮ** —
   proto je výhodné mít modelů málo a spritů z nich mnoho (postava: 1 model =
   40 spritů = 1 pohled na sadu; 40 statiků = 40 modelů = 40 pohledů).

**Co z toho plyne pro cenu celé sady:** celá faceta **není drahá strojem**
(2,5 h) a **není drahá postprocessem** (0,14 s/sprite). Je drahá **autorstvím
modelů a jejich kontrolou pohledem**: 3 000 předmětů = 3 000 modelů, a i kdyby
každý model stál jen jednu iteraci (což je optimistické — u prvních sedmi to
byly 1–3), je to 3 000 lidských zastavení. **Reálná cesta k celé sadě tedy
nevede přes „vyrobit víc spritů", ale přes „mít míň modelů"**: generovat
varianty z jednoho modelu (barvy, velikosti, poškození), sdílet modely mezi
předměty a kontrolovat po SADÁCH (kontaktní list po druzích), ne po kusech.
Pilot to podporuje číslem: postava dala 40 spritů na jeden model a jednu
kontrolu.

## 6. Co se NEMĚŘILO (aby se to nepletlo s naměřeným)

* **Vzhled ve hře** — integrace do `render/` neproběhla (je to samostatná
  granule, ZADANI-25 §5). Umístění na dlaždici je ověřené jen **vzorcem**
  (`core/iso.gd`) a skládáním v kontaktním listu, ne během hry.
* **Čas lidské kontroly v sekundách** — měřitelný není (je to pohled), proto
  je v §5 uvedený jako *počet iterací a nálezů*, ne jako minuty.
* **Jiný stroj než tento** — čísla platí pro tuhle stanici; Blender i GPU
  (EEVEE) jsou součástí měření.
* **Běh v CI** — Blender v CI runneru není (skill `game-assets`), takže se
  sprity musí buď commitovat hotové, nebo renderovat na stanici.
* **Chování při `assets/uo/` chybějícím** — `pack_atlas.py --check` ho
  potřebuje (porovnává masku a barvy); bez něj se změří jen vlastní půlka.

## 7. Jak to pustit znovu

```powershell
$env:PYTHONIOENCODING='utf-8'                  # konzole je cp1252
cd E:\Workspaces\game-clone
python tools\artgen\run_all.py                 # celý pilot + časy do _casy.json
python tools\artgen\pack_atlas.py --check      # brána: 470 kontrol (nic nezapisuje)
python tools\artgen\pack_atlas.py --tabulka-raw  # naměřené hodnoty z renderů (nic nezapisuje)
python tools\artgen\contact_sheet.py           # kontaktní list na POHLED
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\probe_projection.py
```

**Pozor na past, která platí i tady:** Blender vrací **exit 0 i při chybě ve
skriptu** (traceback na stderr). Proto každý krok kontroluje i *výstup*
(`BUILD_OK`, `RENDER_OK`, existence PNG) a `run_all.py` na tom má bránu —
„nespadlo to" není důkaz.

---

## 8. DOPLNĚNO 2026-10-10 (druhý krok koleje) — 2× varianta: co vzniklo a co stálo

> **Co je tenhle oddíl:** **doplněk k měření** (nic výše se nepřepisuje), vznikl
> z `ZADANI-25` §9 — „vyrobit 2× variantu téhož artu a srovnávací list, ze
> kterého se dá rozhodnout". **Odkud brát současný stav:** `assets/own2x/manifest.json`
> (`report`), `tools/artgen/_casy-2x.json`, `tools/artgen/_srovnani-1x-2x.png`.
> **1× sada se neměnila** — `assets/own/` je pořád tentýž (brána `pack_atlas.py
> --check` po celou dobu **476 kontrol / 0 chyb**).

### 8.1 Co se vyrobilo (a kam to leží)

| Co | 1× (`assets/own/`) | 2× (`assets/own2x/`) |
|---|---|---|
| dlaždice | 2 (44 × 44, krok 22, `ox=oy=0`) | **nedělá se** — §9 ji nechce (a „diamant 88×44" je rozpor, viz 8.5) |
| dýka (item 3921) | obsah **11 × 12** px v boxu 14 × 28 | obsah **21 × 23** px v boxu 50 × 69 |
| postava (tělo 400, směr 0) | 8 framů, obsah **60** px, box 18 × 76 | 8 framů, obsah **121** px, box 46 × 152 |
| kotva | `ox=(w>>1)−22`, `oy=h−44` | `ox=(w>>1)−44`, `oy=h−88` |
| render | 512 px, 352 px/jednotka, 3 slunce | 1024 px, 704 px/jednotka, **1 směrové slunce + Fast-GI AO + kontaktní stín** |
| spritů celkem | **46** (2 land + 4 item + 40 anim) | **9** (1 item + 8 anim) |
| skripty | `artgen_common.py`, `build_model_*.py`, `render_sprites.py`, `postprocess.py`, `pack_atlas.py` | `artgen_common_2x.py`, `artgen_blender_2x.py`, `build_model_2x.py`, `render_2x.py`, `postprocess_2x.py`, `pack_atlas_2x.py` |
| zdroje | `blend/*.blend` | `blend/2x_*.blend` (předpona, aby `.blend1` chytil existující `.gitignore`) |
| obrázky | `raw/` (ignorováno) | `_raw2x/` (ignorováno vzorem `tools/artgen/_*`) |

**Kontaktní stín je renderovaný, ne dokreslovaný:** `render_2x.py` vyrenderuje
kontaktní rovinu (přesně 1 × 1 jednotky = půdorys dlaždice, ověřeno sondou
`probe_rovina.py`) dvakrát — **s objektem** a **bez objektu** — a
`postprocess_2x.py` z poměru jasu počítá faktor zastínění
(`1 − jas_stín/jas_ref`, naměřeno **0,163** v nejsilnějším místě). Vrstva se
pak ztlumí radiálním úbytkem (0,14 → 0,34 jednotky), aby to byl **kontaktní**
stín a ne dlouhý vrh přes celou dlaždici. Blender 5.2 na téhle stanici má
v enumu engine **jen `BLENDER_EEVEE`** (Cycles není), takže shadow catcher
(`object.is_shadow_catcher`) je nedostupný — měřeno sondou
`probe_blender_capabilities.py`, ne odhadnuto.

### 8.2 Naměřené časy (jeden běh, `python tools/artgen/mereni_2x.py`)

**Postup:** skript měří **obě varianty teď a tady** na **téže práci** (dýka =
1 sprite, postava = 8 framů směru 0, postprocess = týchž 9 spritů). Render se
měří jako `subprocess` + `perf_counter` (celý běh Blenderu), postprocess
**in-process** (bez startu Pythonu a bez zápisu), aby se porovnávalo totéž.
Čísla jsou **jeden běh** — na téhle stanici kolísají o ±15 %.

| Fáze | 1× | 2× | 2× / 1× |
|---|---|---|---|
| **render** dýka (1 sprite), celý proces | **5,88 s** | **6,79 s** | 1,15× |
| — z toho práce v Blenderu | 1,30 s | 2,24 s | 1,7× |
| **render** postava (8 framů), celý proces | **7,29 s** | **11,26 s** | 1,54× |
| — z toho práce v Blenderu | 2,72 s | 6,70 s | 2,5× |
| **postprocess** 9 spritů (příprava + sesazení) | **1,32 s** | **6,99 s** | **5,3×** |
| — z toho 1 předmět | 0,10 s | 0,78 s | 7,6× |
| — z toho 8 framů postavy | 0,77 s | 6,21 s | 8,1× |
| **na 1 sprite** (render + postprocess) | **~0,34 s** | **~0,91 s** | **2,7×** |

**Kde je čas uvnitř 2× renderu** (z `CAS pass=…`, součty za běh):

| Průchod | dýka | postava (8 framů) |
|---|---|---|
| `beauty` (objekt s alfou) | 1,60 s (1. frame = kompilace shaderů) | 2,28 s = **0,29 s/frame** |
| `stin` (rovina + objekt) | 0,31 s | 2,73 s = **0,34 s/frame** |
| `ref` (rovina bez objektu) | 0,33 s | 1,67 s (jednou za dávku) |
| start Blenderu + načtení .blend | ~4,5 s | ~4,5 s |

**Překvapení, které stojí za zapsání:** `beauty` průchod je na frame u **2×
LEVNĚJŠÍ** (0,29 s) než u 1× (0,34 s) — 2× má **jedno slunce místo tří**
(míň shadow map) a shadery se zkompilují už při `ref` průchodu. Rozlišení
1024² proti 512² je u takhle malé scény skoro zdarma; drahé je **světlo
a druhé kolo renderu**, ne pixely.

**Cena celé sady (přepočet, ne měření):** při ~0,91 s/sprite by 7 519 spritů
facety vyšlo na **~1,9 h stroje** místo ~0,7 h u 1× (pilot §5: 63 min). Stroj
tedy ani ve 2× není úzké hrdlo — tím zůstává **kontrola pohledem a autorství
modelů** (pilot §5).

**Plocha v atlase (měřená cena, která se snadno přehlédne):**

| Prvek | 1× box | 2× box | plocha |
|---|---|---|---|
| dýka | 14 × 28 = 392 px² | 50 × 69 = 3 450 px² | **8,8×** |
| postava | 18 × 76 = 1 368 px² | 46 × 152 = 6 992 px² | **5,1×** |

Z rozlišení by vyšlo 4×; zbytek (u dýky víc než dvojnásobek) dělá **box
nafouknutý kontaktním stínem** — sprite musí mít místo na stín kolem kontaktu.
Stránka 2048² je 16 MB ve VRAM bez ohledu na PNG, takže 2× sada spotřebuje
~5–9× víc stránek na tentýž obsah.

### 8.3 Co je na 2× vidět lépe a co ne (měřeno na `_srovnani-1x-2x.png`)

Čísla v tomhle oddílu měří `probe_2x.py` (barvy, ostrost hrany, krytí stínu)
a `srovnani_1x_2x.py` (poměr obsahu, kotvy, stín) — nic z toho není od oka.

**Lépe (a je to vidět na první pohled):**

1. **Předmět STOJÍ na dlaždici.** Kontaktní stín pod dýkou i pod nohama
   postavy je to, co v 1× (a v UO) chybí — bez něj je art „nalepený na
   podklad". Naměřeno: stín má u dýky **56 viditelných poloprůhledných pixelů**
   (ze 182 v celé vrstvě — zbytek je pod objektem), u postavy **418** (ze 723),
   průměrné krytí 87/255 resp. 73/255.
2. **Hrany jsou hladké (antialias), ne schodovité.** 2× sprite má na hranici
   obsahu víc pixelů, takže přechod je plynulejší — měřeno průměrem |Laplace|
   alfy na hraně obsahu: UO **1,54** · 1× **0,79** · 2× **0,53** (dýka).
3. **Je na čem stavět detaily** — při pohledu 1 : 1 (řada B2/A2 listu) je
   vidět, že 2× art unese tvar, který se do 44px dlaždice nevejde.

**Hůř (a je to taky měřené):**

1. **Ve stejném měřítku je 2× MĚKČÍ, ne ostřejší.** Po zmenšení na polovinu
   (`postprocess.zmensi`) spadne ostrost hrany z 0,79 (1×) na **0,34**
   (2×/2) — tedy *méně* než polovina. Kdo čeká, že „2× = ostřejší", dostane
   opak: rozlišení se při zobrazení ve 44px měřítku **zahodí**.
2. **2× není pixel art.** Je to antialiasovaný render — do sady UO stylu se
   nehodí vedle ručně kreslených spritů (vypadá „vyhlazeně").
3. **Barvy jsou o ~8 % tmavší** (jedno slunce + AO místo tří sluncí): dýka
   (71, 67, 61) proti 1× (79, 72, 63); postava (109, 103, 101) proti
   (117, 109, 106).
4. **Box spritu se nafoukne** (8,8× u dýky, 5,1× u postavy) → víc stránek
   atlasu a víc VRAM (viz 8.2).
5. **Postprocess je 5–8× dražší** — a to je z celé 2× větve **nejdražší
   položka** (6,99 s proti 1,32 s na 9 spritů).

### 8.4 Co se muselo ručně sáhnout (a co to bylo za pasti)

| # | Vada | Kdo ji našel | Poznámka |
|---|---|---|---|
| 1 | `fast_gi_method = "AMBIENT_OCCLUSION"` **neexistuje** (je `AMBIENT_OCCLUSION_ONLY`) | běh + `BUILD_OK` v výstupu | Blender přitom vrátil **exit 0** a traceback šel na stderr — přesně past ze ZADANI-25 §2. Skript teď hodnotu **vybírá z reálného enumu** a když ji nenajde, **spadne** (AO se nesmí tiše vynechat) |
| 2 | **Postava oříznutá o hlavu** — 2× kamera mířila na kontakt (0,0,0), 1× míří na `(0, 0, world_h/2)` | **pohled** na náhled | obsah renderu začínal na `y=0`; spadlo by to jen na listu |
| 3 | **1× větev hledala kontaktní rovinu**, kterou 1× scéna nemá | `RENDER_OK` ve výstupu | 1× .blend se nemění, takže `prepna_rovina` musí být podmíněná |
| 4 | **1× měření otevíralo `2x_*.blend`** (natvrdo zapsané jméno) | `mereni_2x.py` (porovnával 1024 px s 512 px) | proto má `MERITKA` klíč `prefix` |
| 5 | **Srovnávací list tiše zkrátil skupinu z 8 framů na 3** a u 2× zmenšil jen třetí frame | **pohled** na list | `g[:2] + [g[2].zmenseny(0.5)]` — vypadalo to jako „chybí framy" |
| 6 | **Bunky listu ořezávaly spritu hlavu** (kotva se počítala jako `výška − 34`) | **pohled** na list | kotva se teď počítá z `ax`/`ay` všech framů skupiny |
| 7 | **Brána „1 jednotka = 88 px" hlásila chybu u správného artu** | běh brány | měřeno: 1 jednotka je ve spritu **68,4 px** (dýka) a **63,7 px** (postava) — sprite se normalizuje na **naměřený obsah UO**, ne na pevné měřítko. Brána byla předělaná na to, co platit MÁ (poloměr stínu se musí vejít nad kontakt), a čísla se **hlásí**, nehlídají |
| 8 | **Dvě zmínky o „diamant 88×44"** v zadání §9 proti měřené opravě §3 (1 : 1) | čtení zadání | vyřešeno jako **88 × 88** (kosočtverec 1 : 1); `88 × 44` by rozbilo relaci `ISO_STEP == TILE_W/2` a bránu `G1` |

**Dvě měření, která vypadají jako vada a nejsou:**

* **Dva běhy Blenderu dají RŮZNÉ bajty PNG** (`d324e127828a` vs `f2d92a536d63`),
  a přitom **pixely jsou shodné na 0** (ověřeno u 9 snímků: `max|Δ| = 0`).
  Hash souboru tedy **není důkaz obsahu** — proto `mereni_2x.py` porovnává
  pixely, ne hashe. (Determinismus manifestu z pilotu §4 tím není dotčen:
  hlídá se hash **manifestu**, ne PNG.)
* **1× měřicí větev dala pixel za pixel totéž co pilot** (`raw/` vs
  `_raw2x/_timing1x/`, 9/9 snímků, `max|Δ| = 0`) — takže časy „1×" v 8.2 jsou
  časy **téhož**, co dělá `render_sprites.py`, ne něčeho podobného.

### 8.5 Stav bran po zásahu

| Brána | Výsledek |
|---|---|
| `pack_atlas.py --check` (1× sada, **nedotčená**) | **476 kontrol, 0 chyb** |
| `pack_atlas_2x.py --check` (2× sada) | **123 kontrol, 0 chyb** |
| — kotva `ox=(w>>1)−44, oy=h−88` | 9/9 spritů |
| — obsah 2× proti 1× (měřeno z **pixelů obou atlasů**) | průměr **2,02×** (tolerance 25 %) |
| — kontaktní stín **skutečně ve spritu** | 9/9 (jinak by „2× má stín" bylo tvrzení bez krytí) |
| — poloměr stínu se vejde nad kontakt | 9/9 |

### 8.6 Jak to pustit znovu

```powershell
$env:PYTHONIOENCODING='utf-8'
cd E:\Workspaces\game-clone
python tools\artgen\mereni_2x.py                 # celá 2× větev + ČASY do _casy-2x.json
python tools\artgen\pack_atlas_2x.py             # 2× atlas + manifest (zapisuje do assets/own2x/)
python tools\artgen\pack_atlas_2x.py --check     # brána 2× (nic nezapisuje)
python tools\artgen\srovnani_1x_2x.py            # srovnávací list na POHLED
python tools\artgen\probe_2x.py                  # barvy, ostrost hrany, krytí stínu (nic nezapisuje)
python tools\artgen\pack_atlas.py --check        # brána 1× — musí zůstat 476/0
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\build_model_2x.py -- --plan all
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\render_2x.py -- --meritko 2x --plan dagger
```

### 8.7 Co se u 2× NEMĚŘILO

* **Vzhled ve hře** — 2× sada se do `render/` nezapojuje (ZADANI-25 §9: je to
  varianta pro rozhodnutí). Geometrie hry (`core/const.gd`: 44 px, `Z_SCALE 4`)
  zůstala **nedotčená**; přepnutí je samostatná koordinovaná změna.
* **Dlaždice ve 2×** — zadání je nechce (a kdyby ano, je to 88 × 88
  kosočtverec 1 : 1, ne 88 × 44).
* **Ostatní směry postavy a běh** — 2× větev kreslí jen směr 0 (8 framů).
* **Kontaktní stín u dlaždic a u ostatních předmětů** — ověřeno na 9 spritech,
  ne na celé sadě.

---

## 9. DOPLNĚNO 2026-10-11 — 1× SADA SE SVĚTLEM (`assets/own-lit/`): co vzniklo, co stálo a co je vidět

> **Co je tenhle oddíl:** **doplněk k měření** (nic výše se nepřepisuje), vznikl
> z doporučení `ZADANI-25` §10 — „zůstat u 1× a vzít si z 2× **jen světlo**“.
> **Odkud brát současný stav:** `assets/own-lit/manifest.json` (`report`),
> `tools/artgen/_casy-svetlo.json`, `tools/artgen/_determinismus-lit.json`,
> `tools/artgen/_srovnani-svetlo.png`. **Staré sady se neměnily** —
> `pack_atlas.py --check` (1× `assets/own/`) je po celou dobu **476 kontrol /
> 0 chyb** a `assets/own2x/` se vůbec nedotklo.

### 9.1 Co se vyrobilo

| Co | Hodnota |
|---|---|
| dlaždice (`land` 3 tráva, 1001 cesta) | **2** sprity, 44 × 44, `ox=oy=0` |
| předměty (`item` dýka 3921, krumpáč 3717, ruda 6583, ingot 7151) | **4** sprity, kotva `ox=(w>>1)−22, oy=h−44` |
| postava (tělo 400, walk, 5 směrů × 8 framů) | **40** spritů |
| **celkem** | **46 spritů**, 3 stránky 2048² (122,6 kB celkem) |
| nový jmenný prostor | **`assets/own-lit/`** (`manifest.json`, `atlas/*.png`, `anim/anim-sheets.json`) |
| skripty | `artgen_common_lit.py`, `artgen_blender_lit.py`, `build_model_lit.py`, `render_lit.py`, `postprocess_lit.py`, `pack_atlas_lit.py` + `srovnani_svetlo.py`, `mereni_svetlo.py`, `probe_stin_lit.py`, `probe_determinismus_lit.py`, `probe_mutace_lit.py` |
| zdroje | `blend/lit_*.blend` (předpona `lit_`, aby zálohy `.blend1` chytil existující `.gitignore`) |
| renderovné snímky | `_rawlit/` (ignorováno vzorem `tools/artgen/_*`) |

**Rozlišení se NEMĚNILO:** dlaždice 44 px, krok 22, kotva `ox=(w>>1)−22, oy=h−44`,
render 512 px, 352 px na jednotku. Převzato z 2× větve je **jen světlo**:
1 směrové slunce (energie 4,0, úhel 12°, směr `(−0,7; 0; −2,6)`), Fast-GI AO
(`AMBIENT_OCCLUSION_ONLY`, dosah 0,20 jednotky) a kontaktní stín z kontaktní
roviny. Recept není „opsaný text“ — **21 konstant** se z 2× větve **bere** a
`artgen_blender_lit.py` na startu **skončí chybou**, kdyby se rozešly
(`RECEPT_OK 15 konstant` uvnitř Blenderu + 6 z `artgen_common_2x` v bráně).

**Dlaždice kontaktní stín nemá a mít nemá:** dlaždice JE podlaha, takže stín pod
ní je celý schovaný pod ní (v ortografii kryjí oba přesně stejný kosočtverec) —
renderovat ho by znamenalo měřit čas nečeho, co není vidět. AO na dlaždici
zůstává. Kontrola to ověřuje i z pixelů: dlaždice nemá **žádný** poloprůhledný
pixel (`0 px`, jinak by to byla vada masky).

### 9.2 Naměřené časy (jeden běh, `python tools/artgen/mereni_svetlo.py`)

**Postup:** skript měří **obě varianty teď a tady** na **téže práci** (dýka =
1 sprite, postava = 8 framů směru 0, postprocess = týchž 9 spritů). „1× bez
světla“ se renderuje větví, která už existuje (`render_2x.py --meritko 1x`,
výstup do `_raw2x/_timing1x/`) — do `raw/` ani do `assets/own/` se nesahá.
Čísla jsou **jeden běh**; na téhle stanici kolísají o ±15 %.

| Fáze | 1× bez světla | 1× se světlem | poměr |
|---|---|---|---|
| **render** dýka (1 sprite), celý proces | **5,67 s** | **7,95 s** | 1,40× |
| — z toho práce v Blenderu (`beauty`) | 1,47 s | 1,71 s | |
| — navíc `ref` + `stín` (dva průchody) | — | 0,22 + 0,19 s | |
| **render** postava (8 framů), celý proces | **9,37 s** | **9,91 s** | 1,06× |
| — z toho `beauty` na frame | 0,385 s | **0,197 s** | **0,51×** |
| — z toho `stín` na frame | — | 0,212 s | |
| **postprocess** 9 spritů | **1,69 s** | **1,73 s** | 1,02× |
| **postprocess celé sady** (46 spritů) | **4,27 s** | **9,66 s** | **2,26×** |
| **render celé lit sady** (46 spritů, 3 plány) | — | **37,7 s** | |
| **zabaleni lit atlasu** (46 spritů, zápis) | — | **12,1 s** | |
| start Blenderu bez práce | 4,55 s | | |
| **na 1 sprite** (render + postprocess, 9 spritů) | **1,86 s** | **2,18 s** | **1,17×** |

**Překvapení, které stojí za zapsání (a je to podruhé):** `beauty` průchod je se
světlem na frame **skoro dvakrát LEVNĚJŠÍ** (0,197 s proti 0,385 s) — jedno
slunce místo tří znamená méně shadow map a shadery se zkompilují už při `ref`
průchodu. Přesně to naměřila i 2× větev (§8.2). Dražší je **druhé a třetí kolo
renderu** (ref + stín) a **postprocess se stínovou vrstvou**.

**Cena celé facety (přepočet, ne měření):** 46 spritů = render 37,7 s + zabalení
12,1 s ≈ **1,08 s/sprite** → 7 519 spritů ≈ **2,3 h stroje** (pilot §5: ~0,7 h).
Stroj tedy zůstává levný; úzké hrdlo je pořád **autorství modelů a kontrola
pohledem** (pilot §5).

### 9.3 Co je na listu `_srovnani-svetlo.png` vidět LÉPE a co HŮŘ (měřeno)

Sloupce: **původní UO | náš 1× bez světla | náš 1× se světlem**, řady „STEJNÉ
MĚŘÍTKO“ a „VÝŘEZ 1 : 1“, sekce dýka / terén (tráva + cesta) / postava (8 framů).

**Lépe:**

1. **Objekty stojí NA dlaždici.** Kontaktní stín je skutečně ve spritu — počet
   pixelů barvy stínu v hotovém spritu: **ruda 235, postava 60, krumpáč 20,
   ingot 11, dýka 7**; krytí až **126/255** (předměty) a **81/255** (postava).
2. **Barvy jsou blíž UO** (průměr jádra, sRGB): tráva `(57,70,51) → (48,61,44)`
   proti UO `(42,64,13)`; cesta `(60,56,54) → (52,49,48)` proti UO `(50,44,41)`;
   dýka `(79,72,63) → (71,67,62)`; postava `(117,109,106) → (108,103,101)`.
3. **Jeden směr světla v celé sadě.** 1× bez světla má tři slunce
   (klíč/výplň/obrys), takže postava má světlý lem z protisvětla a přes
   dlaždice jde plošné světlo z více směrů — se světlem je sada „jeden model,
   jedno světlo“.

**Hůř (a je to taky měřené):**

1. **Rozptyl jasu (kontrast) se SNÍŽIL u všech vzorků:** tráva `6,1 → 5,7`,
   cesta `10,3 → 8,7`, dýka **`25,7 → 15,2`**, postava `50,8 → 45,2`.
   Jedno slunce místo trojice bere **odlesky a obrysový lem** — u kovových
   předmětů je to vidět nejvíc (na listu má dýka bez světla světlou hranu po
   čepeli, se světlem je plošší).
2. **Je to tmavší** o ~8–13 % (stejný směr posunu, jaký naměřila 2× větev: −8 %).
3. **Předměty ležící na zemi svůj stín SKRÝVAJÍ.** U dýky je vidět **7 px**
   a u ingotu **11 px** — je to 1px tmavý lem u obrysu, protože louže stínu je
   menší než půdorys předmětu. „Stojí na dlaždici“ je proto přesvědčivé
   u postavy, rudy a krumpáče, ale u placatých předmětů jen naznačené.
4. **Box spritu roste** (o místo na stín): dýka `14×28 → 26×35` (plocha 2,3×),
   postava `18×76 → 24×76`, ruda `52×48`. Obsah objektu se přitom nemění
   (kontrola: `|rozdíl| ≤ 2 px` u 44 spritů proti 1× sadě).
5. **Není to pixel art** — je to antialiasovaný render (světlo to nemění).

### 9.4 Co se muselo ručně sáhnout (a co to bylo za pasti)

| # | Vada | Kdo ji našel | Poznámka |
|---|---|---|---|
| 1 | **Brána hledala stín jako „poloprůhledné pixely mimo siluetu rozšířenou o 2 px“** → u dýky hlásila **0 px stínu**, přitom stín ve spritu JE (7 px, 1px tmavý lem u obrysu) | běh brány | Kontaktní stín placatého předmětu je **1 px u obrysu**; dilatace ho smazala. Nově se hledá **podle barvy vrstvy stínu** — a aby to nebylo měření kruhem, hlídá se i opak: **žádný plný pixel nemá barvu stínu** (`0 px`) |
| 2 | **45 falešných chyb „barva stinu neni (0,0,0)“** | běh brány | První verze počítala jako stín **všechny** poloprůhledné pixely — a to je i antialias objektu, který má barvu objektu |
| 3 | **Brána spadla na `KeyError`** místo hlášky, když chybí stránka atlasu | **mutacni test** (`probe_mutace_lit.py`) | Náhled teď chybějící stránky přeskočí a řekne to; „vada v artu“ se nesmí projevit jako „vada v bráně“ |
| 4 | **Šablona listu nechala popisky přetéct do sousední buňky** (u řady 1 : 1 je obsah 44 px, popisek ~100 px) | **pohled** na list | Šířka buňky se teď počítá i z šířky textu; texty se přestaly překrývat |
| 5 | **2× pravidlo „poloměr stínu se musí vejít nad kontakt“ (≤ 22 px) při 1× NEPLATÍ** (ruda 24,7 px) | běh brány | A ani platit nemá: sprite se pro stín **zvětšuje**, takže se nic neukrojí. Nahrazeno tím, co platit MÁ: box je aspoň tak velký jako místo na stín a **žádný pixel stínu se nedotýká okraje** (0 px) |

**Tři měření, která vypadají jako vada a nejsou:**

* **Převzatý vzorec `px_na_jednotku = šířka roviny / √2`** dává u dýky 26,17 px
  (měřená šířka roviny je 37,01 px). Vzorec je **převzatý z 2× záměrně** (aby
  stín vznikal týmž výpočtem), takže stín je v jednotkách ~1,41× menší, než
  říkají konstanty R0/R1. Hlásí se **obě čísla** vedle sebe
  (`px_na_jednotku` i `px_na_jednotku_merene`), ne jen to hezčí.
* **Dva běhy nedají bajtově stejné pixely stránky postavy:** manifest SHA je
  **shodný** (`5ee4e8f2a375…`), stránky `land_0` a `item_0` **bajtově shodné**,
  ale `anim_0` se liší u **80 pixelů o ±1 úroveň v RGB** (alfa shodná). EEVEE
  tedy u postavy není bit-exaktní; brána proto rozlišuje **dvě úrovně**
  (manifest = determinismus z pilotu §4; pixely s tolerancí 1) a čísla hlásí.
* **Kontrast se snížil, i když AO „přidalo hloubku“** — oko to na dlaždicích
  vidí jako plastičnost, ale číslo (`std` jasu jádra) kleslo, protože zmizel
  obrysový lem. Zapsáno je číslo, ne dojem.

### 9.5 Stav bran po zásahu

| Brána | Výsledek |
|---|---|
| `pack_atlas_lit.py --check` (nová sada) | **893 kontrol, 0 chyb** |
| — kotva `ox=(w>>1)−22, oy=h−44` | 46/46 spritů |
| — kontaktní stín **viditelný ve spritu** (barva vrstvy stínu) | 44/44 spritů (item+anim); dlaždice 0 px záměrně |
| — stín v kontaktním okruhu kolem kotvy | 44/44 |
| — stín se nedotýká okraje spritu (neukrojený) | 44/44 (0 px na okraji) |
| — geometrie proti 1× sadě (světlo nemění tvar) | 44 spritů, max `|rozdíl| = 2 px` |
| — recept světla shodný s 2× | 21/21 konstant (15 ověří Blender na startu, 6 brána) + text v manifestu |
| — determinismus (dva běhy) | manifest SHA **shodný**, pixely ±1 u 80 px (`anim_0`) |
| **mutace (`probe_mutace_lit.py`)** | **5/5 odhaleno** (smazaný stín, ztloustlý stín, posunutá kotva, změněný manifest, chybějící stránka) a po vrácení závad brana zelená |
| `pack_atlas.py --check` (1× sada, **nedotčená**) | **476 kontrol, 0 chyb** |

### 9.6 Jak to pustit znovu

```powershell
$env:PYTHONIOENCODING='utf-8'
cd E:\Workspaces\game-clone
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\build_model_lit.py -- --plan all
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\render_lit.py -- --plan tiles
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\render_lit.py -- --plan items
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' -b -P tools\artgen\render_lit.py -- --plan character
python tools\artgen\pack_atlas_lit.py                  # atlas + manifest do assets/own-lit/
python tools\artgen\pack_atlas_lit.py --check           # brána: 893 kontrol
python tools\artgen\probe_stin_lit.py                   # měření stínu (nic nezapisuje)
python tools\artgen\probe_stin_lit.py --ascii --ids 3921  # stín po pixelech
python tools\artgen\probe_determinismus_lit.py          # dva běhy → _determinismus-lit.json
python tools\artgen\probe_mutace_lit.py                 # mutační test brány (5 vad)
python tools\artgen\mereni_svetlo.py                    # časy → _casy-svetlo.json
python tools\artgen\srovnani_svetlo.py                  # srovnávací list na POHLED
python tools\artgen\pack_atlas.py --check               # 1× sada musí zůstat 476/0
```

### 9.7 Co se u lit sady NEMĚŘILO

* **Vzhled ve hře** — sada se do `render/` nezapojuje (integrace je samostatná
  granule). Umístění na dlaždici je ověřené vzorcem a skládáním v listu.
* **Překalibrované barvy** — materiály se ZÁMĚRNĚ neměnily (měřilo se světlo,
  ne dvě věci najednou); naměřený posun barev je v 9.3.
* **Doladění stínu pro placaté předměty** — změřeno, že u dýky a ingotu je stín
  vidět jen jako 1px lem; recept z 2× se needitoval (to je další krok, ne
  měření).
* **Chování ostatních směrů postavy zvlášť** — všech 40 framů (5 směrů × 8) se
  vyrobilo a prošlo branou, ale na listu je vidět jen směr 0 (8 framů).
* **Běh v CI** — Blender v CI runneru není (skill `game-assets`).

---

## 10. DODATEK 2026-10-11 — PIXEL-ART STYL (co z čísel výš PŘESTALO PLATIT)

> **Co je tenhle dodatek:** doplnění k **záznamu měření** (historické oddíly se
> needitují). Čísla výš byla správná **ve svém čase** (před stylem). Kdo je čte
> dnes, musí vědět, co je nahradilo.

Do pipeline přibyl **stylový krok** (`styl.py`: tvrdá alfa + paleta na model;
doostření vypnuté) a obě sady se přegenerovaly. Co to mění:

| Místo výš | Bylo (před stylem) | Je (po stylu) |
|---|---|---|
| §9.5 `pack_atlas_lit.py --check` | 893 kontrol / 0 chyb | **900 kontrol / 0 chyb** |
| §9.5 `pack_atlas.py --check` | 476 / 0 | **476 / 0** (beze změny počtu) |
| §9.2 „není to pixel art“ (antialias) | antialiasovaný render | **silueta 0/255**; antialias zůstal jen v kontaktním stínu (záměr) |
| §9.3 bod 5 „není to pixel art“ | totéž | **neplatí** — je to pixel art s paletou |
| §9.3 bod 1 „kontrast se snížil“ | měřeno na antialiasovaném spritu | **přeměřeno**: postava 472 → **39 barev**, 148 → **0** poloprůhledných, ostrost 26,3 → **31,5** |
| §8.3 „2× je měkčí“ | platí dál | platí dál — **rozlišení není cesta** (proto styl, ne 2×) |

**Dvě věci, které se změnily a nejsou v tabulkách výš:**

1. **`px_na_jednotku` se nezměnilo** (kotvy a boxy zůstaly), ale **sada stránek
   se přepsala** — manifest má jiný SHA (`a745b968…`, dřív `5ee4e8f2…`).
2. **Tolerance determinismu pixelů je 6, ne 1.** Kvantizace zesiluje šum EEVEE
   (±1 úroveň v renderu → až ±5 v atlasu); **manifest SHA zůstává přesně
   shodný**. Důvod je v `probe_determinismus_lit.py` u `PIXEL_TOLERANCE`.

**Brána stylu:** `python tools/gates/check-style.py` (G16) — silueta 0/255 mimo
kontaktní stín, paleta pod 80 barvami, měřeno na spritech i na animacích
z anim listu. Ostrost se **hlásí, ale nehlídá** (ruda má po stylu 19,4 a je
čitelnější; metrika, která trestá žádoucí vlastnost, není brána).

