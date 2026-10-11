# ZADÁNÍ 26 — varianta dlaždice podle souřadnic buňky (`render.land_variants`)

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalo) — nepřepisuje se.
> Vzniklo **2026-10-11** z měření session, která nasazovala dlažbu z Nano Banana
> a PBR sad (doklady v `_analyza/p53-nabor/`). **Stav projektu:** `HANDOFF.md`.
> **Cíl zadání:** odstranit opakování dlaždic a závislost na počtu id.

## 1. Cíl

**Jedno `land` id → N dlaždic, vybíraných deterministicky podle souřadnic buňky.**
Dnes platí „jedno id = jedna dlaždice", takže se dlažba na velké ploše opakuje
a musíme kvůli rozmanitosti zabírat další a další id.

## 2. Naměřená fakta (vstup, neopakovat měření)

* **Dnes:** `(kind, id) → jeden sprite` (`render/own_art.gd`, `render/texture_cache.gd`).
* **Pravidelné cyklování variant je vidět:** 4 varianty v rytmu `(cx*3+cy)%4` vyrobí
  čitelné **svislé pruhy** (velké skvrny textury se poskládají do mřížky);
  24 variant s výběrem **hashem buňky** pruhy odstraní.
  Doklad: `_analyza/p53-nabor/test-plocha2.png` (vlevo PŘED, vpravo PO),
  skript `_analyza/p53-nabor/s30-vzor.py`.
* **Mapa v Britainu má dlažbu na 4 id** (1001–1004, měřeno z `assets/uo/world/map0.land`
  skriptem `_analyza/p53-nabor/s18-mapa-id.py`); naše vrstva drží 2 → dlažba tvoří
  **diagonální mřížku** proloženou UO (`.cache/render/terakota-on.png`).
* **Výkon, který se nesmí zhoršit:** `texture()` se volá **5 767× za frame**;
  `AtlasTexture.new()` stál **0,118 ms** → hotová okna (`_wrapped`) srazila frame
  z 655 ms na **22,3 ms (45 FPS)** (hlavička `render/texture_cache.gd`).
* **Vada, která s tím souvisí:** `tools/gates/own_art_probe.gd` má id **natvrdo**
  (`VLASTNI = [3, 1001, …]`), ale `tools/gates/check-own-art.py` bere id
  z konfigurace → přidání vrstvy shodí `G15` falešnými hláškami
  „art 1002 se nenacetl (None)". Naměřeno 2026-10-11.

## 3. Required výstup

1. **Konfigurace (data, ne kód):** v `assets/own-art.json` nový nepovinný klíč
   vrstvy, např. `"groups": {"land": [[1002, 1003, 1005, 1006]]}` =
   „tato id jsou jeden materiál; pro kterékoli z nich lze kreslit kterékoli".
   Když klíč chybí, chování je **přesně dnešní**.
2. **API** `render/texture_cache.gd`:
   `texture_variant(art_id: int, x: int, y: int) -> Texture2D`
   a `offset_variant(art_id: int, x: int, y: int) -> Vector2i`.
   **`offset` musí jít ze STEJNÉHO záznamu jako textura** (pravidlo z hlavičky
   `texture_cache.gd` — vlastní dlaždice mají jinou kotvu než UO).
3. **Výběr varianty = čistá funkce souřadnic** (např.
   `abs(x * 73856093 ^ y * 19349663) % N`). **Žádná náhoda za běhu** — rozbila by
   determinismus, replaye a snímky v CI (`docs/09`).
4. **Obě kreslicí cesty** musí používat totéž: `render/chunk_renderer.gd`
   (seznam) i `render/chunk_mesh.gd` (GPU cesta), jinak se rozejdou.
5. **`stats()`** přidá `variants` (počet skupin a členů); `missing` zůstává.
6. **Sonda `tools/gates/own_art_probe.gd`** musí id brát **z konfigurace**, ne
   z konstanty (odstraní vadu z §2 poslední odrážky).

## 4. Jak ověřit (brány, které UMÍ selhat)

| # | Co se měří | Jak | Kdy je to vada |
|---|---|---|---|
| **A** | **zmizelo opakování** | vykreslit plochu 20×20 buněk jednoho id a měřit **podíl dlaždic shodných se sousedem** (lag 1) | na dnešním kódu (N=1) musí vyjít **100 %** — když ne, brána neměří; s N≥16 musí být **< 20 %** |
| **B** | **determinismus** | dva běhy téhož snímku → **shodný sha256** | liší se = vada |
| **C** | **výkon** | frame time ve scéně Britain (baseline: chůze median **34,6 ms**) | zhoršení > 10 % = vada |
| **D** | **nic se nerozbilo** | stávající sada testů + `--no-own-art` + id bez skupiny | cokoli červené = vada |

**Hotovo je, když:** A–D projdou, vada z §2 (sonda vs. brána) je opravená
a `check-own-art.py` je zelený **i s vrstvou, která má skupiny**.

## 5. Co NEDĚLAT

* **Nezavádět náhodu za běhu** (ani `randi()` seedované časem) — determinismus je
  kontrakt.
* **Nerozbít formát manifestu UO** — `assets/uo/manifest.json` skupiny nemá
  a musí zůstat platný.
* **Nesahat na `assets/uo/`** ani na `assets/own-lit/` (pracuje na nich paralelní
  session).
* **Nezapisovat do `render/` bez domluvy** — ten adresář vlastní jiná session;
  tahle granule se musí zapsat do `.forge/roadmap.json` (patří uživateli).
