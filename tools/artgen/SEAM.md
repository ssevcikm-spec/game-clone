# SEAM — jak napojit `assets/own/` do hry (návrh, ne kód)

> **Co je tenhle soubor:** **návrh** (text) k zadání
> [`ZADANI-25-VLASTNI-ART.md`](../../ZADANI-25-VLASTNI-ART.md) §4.4. Odpovídá na
> jednu otázku: **kde je jediné místo, které rozhoduje `(kind, id) → sprite`,
> a co musí platit, aby šlo přepínat PO KUSECH** (vlastní art vyhrává, kde je;
> jinak původní). **Není to hotová integrace** — ta je samostatná granule
> (rozhodnutí `M8`), tenhle soubor říká, co v ní musí platit.
>
> **Datum:** 2026-10-10. **Odkud brát současný stav:** `assets/own/manifest.json`
> (`report`), `tools/artgen/MERENI.md`, `render/texture_cache.gd`.

## 1. Kde se dnes rozhoduje `(kind, id) → sprite`

**Jedno místo, a je to tak správně:**

| Co | Kde | Co dělá |
|---|---|---|
| `(kind, id) → art_id` | `render/texture_cache.gd:147-160` (`_index`) | `land = id`, `item = id + 0x4000`, `texmap = id + 0x10000`; neznámý druh → `-1` (zahodí se) |
| `art_id → (page, rect, offset)` | tamtéž (zápis do `_sprites`) | `page` = `_prefix + page`, `rect` z `x,y,w,h`, `offset` z `ox,oy` |
| odkud se to čte | `render/texture_cache.gd:51-52` (`MANIFEST_PATH`, `ATLAS_PREFIX`) | jeden manifest, jeden prefix |
| kdo to používá | `render/chunk_renderer.gd:620` (`offset` pro statiky), `:599-603` (land, `offset` = nula), `:451-457` (`screen_position`) | odečtení offsetu od dlaždice |

**Postava jde jinudy** (`render/anim_player.gd:32`): čte
`assets/uo/anim/anim-sheets.json` + PNG pruhy, klíč `tělo/skupina/směr`
(`_key`, `:135-138`), zrcadlení 8 → 5 je v `DIR_MAP` (`:35-36`) a **nemění se**.

## 2. Návrh: „vlastní vyhrává, kde je" = jedna řádka v `_index`

Mechanismus **už v kódu je** — `_index` zahazuje druhou položku se stejným
`art_id` (`texture_cache.gd:154`: `... or _sprites.has(art_id): return`).
Stačí tedy indexovat **vlastní manifest PRVNÍ** a UO **druhý**: co je ve
vlastním, vyhraje; co tam není, zůstane z UO. Žádná nová logika kreslení.

**Co k tomu musí přibýt (a proč):**

1. **Rozlišený prefix na SPRITE, ne na cache.** Dnes je `_prefix` jedna
   konstanta pro celý manifest. Dva manifesty = dva prefixy
   (`res://assets/uo/`, `res://assets/own/`), takže se cesta ke stránce musí
   složit **v `_index`** (`"page": prefix + page`) nebo nést v manifestu.
   Kdyby zůstal jeden prefix, načte se stránka z druhého jména prostoru
   a vyskočí `chybi <cesta>`.
2. **`offset()` musí jít ze STEJNÉHO záznamu jako textura.** To je kritické:
   vlastní art má **jiné `ox/oy`** než UO pro totéž id (naměřeno: naše dýka
   `ox=-15, oy=-16` v boxu 14×28; UO dýka `ox=-11, oy=-18` v boxu 22×26 —
   jiný box, jiná kotva, stejné id).
   Kdyby se textura vzala z vlastního a offset z UO, sprite sedí o pár pixelů
   vedle. `offset()` to dnes čte ze stejného `_sprites` (`:122-124`) — proto
   musí „vlastní vyhrává" platit **v indexu**, ne až při kreslení.
3. **Počítadlo původu ve `stats()`.** Bez něj se „vlastní art je zapnutý" nedá
   ve hře ověřit. Návrh: `stats()["own"]` a `stats()["uo"]` (kolik indexovaných
   spritů přišlo odkud). Dnešní `stats()` už hlásí `sprites` a `missing` — jen
   by se rozdělilo.
4. **Stejný trik pro animace.** `assets/own/anim/anim-sheets.json` je **ve
   stejném tvaru** jako UO export (klíče `version, decoder, anchor, actions,
   sprites, chyby`, klíč spritu `400/0/<směr>`, framy s `cx, cy, w, h, rect`)
   a `--check` to porovnává. Indexovat vlastní první, UO druhá; `file` v listu
   je potřeba resolvovat stejným prefixem (bod 1). **`DIR_MAP` a zrcadlení se
   nemění** — vyrenderovali jsme stejných 5 kanonických směrů jako UO.

## 3. Co musí platit, aby přepínání po kusech bylo bezpečné

| # | Invariant | Jak je doložený |
|---|---|---|
| 1 | **Je to NAHRAZENÍ, ne přidání**: každý náš `(kind, id)` existuje i v UO | `pack_atlas.py --check`: „seam: land+item **6/6** id je v UO manifestu; anim **5/5** klíčů je v UO anim listech" |
| 2 | **Geometrie se nemění**: 44 × 44 dlaždice, `ISO_STEP = 22`, kotva `ox=(w>>1)-22, oy=h-44` | `--check`: kotva u 46/46 spritů; maska dlaždice proti reálné masce UO = **rozdíl 0 px** |
| 3 | **Kontakt sedí na dlaždici**: obsah je 22 px nad spodní hranou spritu | naměřeno max **21,9 px** (`report.land_obsah_pod_kontaktem_max_px`, `item_…`) |
| 4 | **`assets/uo/` zůstává jen ke čtení** — vlastní art ho nepřepisuje | celý pilot zapisuje do `tools/artgen/` a `assets/own/` (ZADANI-25 §5) |
| 5 | **`vymena` (výměna za běhu) má dál přednost** před obojím | `chunk_mesh.gd:634` kontroluje `vymena` první — vlastní art se řadí POD ni |
| 6 | **Sazení a řazení se nemění** (priorita, klíče, `z_corners`) | seam mění jen pixely a `offset`, ne geometrii — brána `G1` (`ISO_STEP == TILE_W/2`) platí dál |
| 7 | **Chybějící id se nesmí tvářit jako „načítá se"** | `page_pending()` vs `missing` v `stats()` zůstává rozdělené i pro dva manifesty |

## 4. Přepínač: data, ne nová větev kódu

Tři úrovně, od nejmenšího zásahu:

* **Vypnuto/zapnuto jako celek** — `TextureCache.new(own_manifest_path)`:
  předáš `null`/prázdno → jede jen UO; předáš `res://assets/own/manifest.json`
  → vlastní vyhrává. **Žádný nový `if` v kreslení**, přepínač je argument
  (stejný princip, jaký už má `_init` kvůli testům: `page_prefix`).
* **Po kusech (druh)** — dva manifesty místo jednoho (land/item/anim zvlášť,
  `assets/own/manifest.json` je dnes jeden, ale `sprites` se dá filtrovat).
* **Po kusech (id)** — seznam id, která se mají přepnout (např. jen tráva
  a dýka pro první srovnávací snímek). Návrh: `assets/own/pieces.json`
  (seznam `[[kind, id], …]`), který si integrační granule přečte a zahodí
  ostatní záznamy **před** indexací. Výhoda: A/B snímek „před/po" na jedné
  scéně bez přepínání kódu.

## 5. Jak seam ověřit (a čím se to nesmí dokazovat)

**Už hotové (pilot):**
`python tools/artgen/pack_atlas.py --check` → **476 kontrol, 0 chyb**: shoda
klíčů manifestu i spritů s UO, kotva vzorcem UO, maska dlaždice proti UO na
pixel, střed obsahu proti kotvě ≤ 1 px, mezery a překryvy, determinismus
(dva běhy → stejný SHA-256 manifestu).

**Co musí přidat integrační granule (návrh bran):**

1. **Chování, ne přítomnost.** Test musí *zavolat* `texture(id)` a `offset(id)`
   pro každé vlastní id a ověřit, že **textura přišla z vlastní stránky**
   (`AtlasTexture.atlas.resource_path` obsahuje `assets/own/`) a že `offset`
   je **náš** (ne UO). Test, který jen zkontroluje, že soubor existuje, je slepý
   (skill `overovani`).
2. **Přepínač opravdu přepíná.** Tentýž test dvakrát: s vlastním manifestem
   a bez něj. Když vyjdou stejná data, seam nic nepřepnul — a to je nález
   o bráně, ne o artu.
3. **Snímek před/po.** Vykreslit tutéž scénu s vlastním artem vypnutým
   a zapnutým a **porovnat pixely**: rozdíl musí být nenulový **jen** na
   dlaždicích s vlastním artem (počet odlišných pixelů ≈ plocha přepnutých
   dlaždic; jinde 0).
4. **Paměť.** Stránka 2048² je **16 MB ve VRAM** bez ohledu na to, jak malý
   je PNG (naměřeno: 46 spritů = 3 stránky, ale 71 kB na disku). Vlastní art
   tedy přidává stránky do pracovní sady; `stats()` a `MAX_BYTES` se musí
   vyhodnotit znovu na reálné scéně — dnes je referenční číslo „Britain
   27 stránek / 432 MB při stropu 384 MB" (`texture_cache.gd:20-27`).

## 6. Co tenhle pilot ZÁMĚRNĚ neudělal (a proč to není opomenutí)

* **Nezapisoval do `render/`** — integrace je samostatná granule (`M8`), druhá
  kolej vlastní jen `tools/artgen/` a `assets/own/`.
* **Nezměnil kotvu na „předmět na zemi" variantu.** UO art má dva výklady
  (`atlas.py:55-57`: „statik na mapě" vs „předmět na zemi o 22 px výš").
  Pilot jede tu první (stejný vzorec jako UO atlas), a proto má každý sprite
  **22 px průhledné rezervy pod kontaktním bodem**. Kdyby se hra rozhodla pro
  druhou variantu, je to **jedna konstanta** (`GROUND_PX` v `artgen_common.py`)
  a přegenerování — a zmizí i ta rezerva (dnes u malých předmětů tvoří víc než
  polovinu boxu, tedy i víc než polovinu plochy atlasu).
* **Nezakládal nové id prostory.** Vlastní art nahrazuje známá UO id; nový
  obsah (co v UO není) by potřeboval dohodu o id, a to je rozhodnutí uživatele,
  ne pilotu.
