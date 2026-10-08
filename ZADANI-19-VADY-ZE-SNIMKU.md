# ZADÁNÍ pro session 19 (UO-klon, 2026-10-08) — VADY ZE SNÍMKŮ A Z HRY (17 bodů)

> **Co je tenhle soubor:** **zadání** — doslovný přepis toho, co uživatel zadal
> v session 19 (2026-10-08), s naměřenými fakty, která k tomu patří.
> **Nepřepisuje se** — co se z něj provede, patří do `HANDOFF.md` (stav)
> a `LESSONS.md` (ponaučení). Nová měření patří do `_analyza/p22-*.txt`.
> **Současný stav projektu je v `HANDOFF.md`** (ten se přepisuje celý).
> **Datum vzniku:** 2026-10-08. **Datum spotřeby:** průběžně v této session.
> **Zdroj:** uživatel, jeden text + 10 snímků (attachmenty session, v repu nejsou).

---

## 0. Kontext, ve kterém zadání vzniklo

Bazový stav před prvním zápisem (naměřeno 2026-10-08 v této session):

| Co | Postup | Výsledek |
|---|---|---|
| Testy | `Godot --headless --path . --script res://tests/run_tests.gd` (plný přístup) | **1 201 kontrol / 0 selhání**, 44/44 case souborů |
| Testy v sandboxu `workspace-write` | týž příkaz | **1 200 / 13 selhání** — **falešné**: zápis do `.cache` (`globalize_path` → prázdná cesta) → `app.config: data se nectou: ` a `render.textures: manifest dal 4 sprity (namEReno 0)` |
| Git | `git status --short` | čistý strom, HEAD `d6a1188` |
| Hra běží | `p21-snimky.gd` → `_analyza/p21-*.png` | ano (assets `assets/uo/` jsou na disku) |

**Ponaučení hned na začátku:** 13 „selhání“ nebyly vady kódu, ale následek
**chybějícího plného přístupu** (přesně to píše `ZADANI-DALSI-VYVOJ-2.md §0`).
Kdo vidí tahle selhání, ať **nejdřív zkontroluje přístup**, ne kód.

---

## 1. Doslovné zadání uživatele (17 bodů)

| # | Co uživatel napsal (doslova / v překladu) | Druh |
|---|---|---|
| V1 | „Při pohybu doprava dolů (západ?) se propadám do textury mostu (vizuálně)“ | vada |
| V2 | „Západní břeh nemá břeh“ | vada |
| V3 | „Postava běží jen asi 3 políčka. Prvně jsem myslel, že je to rozbité, ale ve skutečnosti se zdá, že došla stamina a neregeneruje se. Prozatím bych to vypnul nebo byl nastavil výchozí staty na 130, aby se to zatím nedělo.“ | vada + **rozhodnutí** |
| V4 | „Rád bych zapl auto-run. Nějakou zkratkou nebo tlačíkem aby postava běžela za myší. V UO to bylo současné stisknutí obou tlačítek myši.“ | nová funkce |
| V5 | „Při pohybu celá obrazovka jakoby zrní. Ne obrazovka samotná, ale veškeré textury — nějaká vada překreslování?“ | vada |
| V6 | „Pri delsi chuzi se hra pravidelne, asi tak po 10 polich, zasekne tak na půl sekundy“ | vada (výkon) |
| V7 | „Na třetím obrázku se divně zobrazuje most, břeh a voda“ | vada |
| V8 | „Na čtvrtém voda a břeh“ | vada |
| V9 | „Celá obrazovka je jakoby trochu pixelatá. Tipuju, že je všechno moc přiblížené — chtělo by to možná oddálit obrazovku, zvětšit rozhled“ | vada + **požadavek** |
| V10 | „Můžeme to uhladit nějak hezky? Nebo zlepšit kvalitu všech assetů?“ | otázka/nápad |
| V11 | „Hra mi neumožní jít na most na obrázku 6. Nevím jestli je to blokace světa nebo chyba nastavení?“ | vada |
| V12 | „Obrázek 7 — ve vysoké budově se zobrazuje i vnější zeď z podkroví, což zavazí“ | vada |
| V13 | „Velmi těžko zjistitelné, ale občas, velmi vzácně mi při pohybu problikne obrazovka a nestihnu ani zaregistrovat co vidím“ | vada (vzácná) |
| V14 | „Zdá se mi, že občas nebo stále hra nedobře detekuje kam mířím myší. Zvláště okolo postavy, kousek pod ní a kousek vlevo mě hra občas směruje jakože jdu nahoru, ačkoliv mám myš vlevo nebo vlevo dole“ | vada |
| V15 | „Postava se neumí otáčet, automaticky popojde směrem, který jí určím. To je blbé, pokud se chci jen otočit (krátkým klikem) nebo když narazím do zdi. Pokud opravím směr přesně, tak se postava odmítá hýbat, ale měla by podle směru (třeba šikmo k překážce) umět jít podél. Jediný bod zastavení by měl být pokud jdu přímo do překážky“ | vada + **požadavek** |
| V16 | „Fotka 8 — zobrazuje se patro nademnou, i když jsem v přízemí a tím pádem nevidím na své patro“ | vada |
| V17 | „Na fotce 9 ani nevím jak navigovat schodiště. Zobrazuje se zábradlí z patra a nedaří se mi vystoupat vzhůru“ + „Je možné, že určování směru chůze podle pozice myši není sladěné s osou Z?“ + „I na předposlední fotce, přestože jsem v přízemí, se zobrazuje zdivo z patra a stejně tak zábradlí a stůl a postele na poslední fotce“ | vada (vícenásobná) |

**Dotaz mimo seznam (V0):** „Než budeš pracovat na všech změnách, řekni mi jestli
můžu pustit paralelně session na něco jiného a vy byste se pak sloučili.“
→ odpověď je v `HANDOFF.md` a v odpovědi v chatu; **není to kód**.

---

## 2. Naměřená fakta k zadání (odkud se vychází)

| # | Fakt | Čím je doložený |
|---|---|---|
| F1 | `sim.movement` má **jen `request_step`** — příkaz `turn` smlouva zná (`sim/commands.gd:21`), ale dispatch ho nemá kam poslat (`:110-112` „Not available yet“) | `sim/commands.gd`, `sim/systems/movement.gd` |
| F2 | Krok se neblokuje jen „přímo do překážky“: `can_step` blokuje i **diagonálu**, když není průchodná **obě** ortogonální (hráč, `walk.gd:118-124`) — což JE věrné referenci, ale uživatel to vidí jako „odmítá se hýbat“ | `sim/world/walk.gd` |
| F3 | `always_run` je od 18. session **true** (výchozí běh) a `Shift` ho přepíná; `stam <= 1` běh zakáže (`movement.gd:126-130`) | `app/input_map.gd:54`, `movement.gd` |
| F4 | Staty hráče jsou **výchozí 10/10/10** → `max_stam = DEX = 10`; `app/main.gd` staty nikde nenastavuje | `sim/entity/stats.gd`, `app/main.gd:216` |
| F5 | `sim.regen` **neexistuje** (v `SYSTEM_ORDER` je, ale `main.gd` ho neregistruje) → stamina se nikdy nedoplní | `sim/sim_world.gd:36`, `app/main.gd` |
| F6 | Svět se kreslí **bez zoomu**: kamera nemá `zoom`, okno 1280×720, viditelná plocha světa ~960×600 px po odečtení černého pásu GUI | `project.godot`, `app/main.gd:49-50`, `app/main.tscn` |
| F7 | Střechy/stropy se skrývají, jen když je hráč **pod** nimi (`z > hrac_z + 16` a `je_strop`) — zdivo patra nad hráčem se neskrývá nijak | `render/chunk_renderer.gd:96-120`, `:201-205` |
| F8 | Rozdělování dávky na „před hráčem / za hráčem“ je binární hledání v klíči (`split_for_player`) — střecha patra není „před/za“, je **nad** | `render/chunk_mesh.gd` |
| F9 | Chůze má naměřeno: 2 037 z 2 319 framů ≤ 1 ms, **> 16 ms 25 framů (1,1 %)**, max 133 ms — a ty 2 framy padají na **překreslení runtime atlasu na GPU** (`hold`) | `HANDOFF.md` (18. session), `_analyza/p21-chuze.gd` |
| F10 | `RECENTER_TILES = 8` → přestavba seznamu objektů se dělá po 8 dlaždicích chůze; cena jedné přestavby je **desítky ms** (rozložená do 8ms kroků) | `app/world_view.gd:51`, `render/chunk_mesh.gd` |

---

## 3. Rozdělení práce (write-scope, aby se session nepobily)

| Trať | Soubory (výhradní zápis) | Body zadání |
|---|---|---|
| **A — pohyb a míření** | `sim/systems/movement.gd`, `sim/world/walk.gd`, `app/input_map.gd`, `app/player_controller.gd`, `tests/cases/{movement,walk,input,player_controller}.gd` | V4, V14, V15, V17 (část „směr vs. osa Z“), V11 (blokace) |
| **B — terén, voda, břeh, zoom** | `app/world_view.gd`, `app/main.gd` (jen pas/zoom), `render/chunk_mesh.gd`, `render/texture_cache.gd`, `tests/cases/world_view.gd` | V1, V2, V5, V7, V8, V9, V10, V13 |
| **C — patra, střechy, schody** | `render/chunk_renderer.gd`, `render/sort.gd`, `sim/world/stairs.gd`, `tests/cases/{chunk_renderer,render_sort}.gd` | V12, V16, V17 (patra, zábradlí) |
| **D — výkon a záseky** | `_analyza/p22-*.gd`, měření; zásah do `render/` jen po dohodě s B/C | V5, V6, V13 |
| **S — stamina** | `app/main.gd` (staty hráče), `sim/systems/movement.gd` (jen po dohodě s A) | V3 |
| **Sdílené (bere si je vždy JEDEN)** | `tools/gates/mutace-tests.py`, `HANDOFF.md`, `LESSONS.md`, `docs/*` | brány a předání |

**Pravidlo pro všechny tratě:** každá oprava má **naměřenou příčinu** a **doklad**
(test, který by spadl, kdyby se vada vrátila; u vizuální změny **snímek** přes
`read_image`). Co se naměřit nepodařilo, patří do „Co se NEOPRAVILO“ — ne do ticha.

---

## 4. Rozhodnutí, která zadání potřebuje (a kdo je dělá)

1. **Staty hráče (V3):** uživatel navrhl „vypnout staminu nebo dát 130“.
   → **rozhodnuto v této session:** staty hráče `STR/DEX/INT = 75/130/20`
   (`max_stam = DEX = 130`, `max_hp = 50 + 75/2 = 87`, `max_mana = 20`),
   zdroj a důvod zapsaný u kódu. Trvalé: `sim.regen` (doplnění staminy)
   zůstává **nehotové** a je to zapsáno jako otevřená věc.
2. **Zoom obrazovky (V9):** je to **vstup**, ne konstanta (uživatel chce
   „oddálit“) → klávesy pro zoom ven/dovnitř + výchozí hodnota, která ukáže
   větší rozhled než dnes. Číslo musí být **měřené** (kolik dlaždic je vidět).
3. **„Zlepšit kvalitu assetů“ (V10):** **není** oprava kódu — patří do
   `docs/`/roadmapy jako návrh (jiné assety = jiný zdroj dat). Do této session
   se dělá jen to, co lze měřit (zoom, filtr, řazení, břeh).

---

## 5. Co NEDĚLAT

- Neměnit `docs/` bez svolení (výjimka se hlásí) — smlouvy se mění jen tam,
  kde to zadání výslovně žádá.
- Nemazat `_src/` klony ani `research/` (jsou to pinované reference).
- Nepřepisovat `_analyza/p20-*` a `p21-*` (jsou to naměřené záznamy).
- Nepřidávat `done: true` do roadmapy ručně.
- Netvrdit „opraveno“ bez měření nebo snímku.
