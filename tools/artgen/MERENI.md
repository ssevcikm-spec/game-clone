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
