# 8. Brány a ověřování

> **Hlavní pravidlo celého projektu:** u každé brány se ptej
> **„proběhla skutečně?"**, ne jen **„neprotestovala?"**.
> Naměřeno vícekrát: brána, která se na nic nezeptala, hlásila zelenou
> (a někdy i `exit 0`) — a to je horší než brána, která spadne.

## 8.1 Co musí každá brána splňovat

1. **Umí selhat.** Napiš **mutační test**: vlož vadu a podívej se, že brána
   spadne. Bez toho brána není brána, jen dekorace.
2. **Vypíše, co změřila** (`kontrol: 57, selhání: 0`), a když je měřených
   objektů **nula**, **selže** (nebo výslovně napíše `NEMĚŘENO`).
3. **Čte kód, ne komentáře** (`radek.split("#", 1)[0]`), jinak komentář
   popisující vadu vypadá jako vada.
4. **Nepřeskočí tiše.** Když nemá vstupy (např. v CI nejsou assety), musí to
   být **vidět v logu** i v souhrnu.
5. **Má offline test** se známým správným **i** známým vadným vstupem.

## 8.2 Seznam bran

| # | Brána | Co měří | Kdy | Selže, když… |
|---|---|---|---|---|
| G1 | `check-schema.py` | **rozpor v zadání**: `docs/` + `data/*.json` + kód + atlas musí říkat totéž (tile 44, ISO_STEP 22, Z_SCALE 4, rozsahy id) | každý PR | některý zdroj tvrdí jiné číslo, nebo se číslo **nedá přečíst** |
| G2 | `check-layers.py` | **směry závislostí**: `sim/**` nesmí odkazovat `ui/`, `render/`, `app/`; nesmí obsahovat `Input.`, `Time.`, `OS.`, `randf(`, `randi(` | každý PR | jediný zakázaný odkaz (tvrdá brána) |
| G3 | `tests/run_tests.gd` | **chování simulace** (bez assetů, bez scény) | každý PR | kterákoli nepodmíněná kontrola spadne |
| G4 | `check-wiring.py` | **mrtvý kód**: každé deklarované `provides` je volané z **produkčního** kódu; každý `_on_*` je připojený k signálu | každý PR | funkce není volaná nebo handler není připojený |
| G5 | `check-content.py` | **obsah**: schémata `data/*.json`, existence art ID v manifestu, křížové odkazy (recept → materiál → předmět), počty C1–C10 | každý PR | chybí art, neplatný odkaz, nesplněný minimální počet |
| G6 | `check-assets.py` | **assety**: manifest vs. stránky atlasu, nulové/průhledné sprity, offsety zarovnání, shoda siluet framů animace | každý PR s assety | nekonzistence manifestu nebo prázdný sprite |
| G7 | `check-save.py` | **round-trip**: `save → load → state_hash` shodný | každý PR | hashe se liší nebo load selže |
| G8 | `check-determinism.py` | **determinismus**: dva běhy stejného skriptu příkazů (20 000 ticků) dají stejný hash | každý PR | hash se liší (float, neuspořádaná iterace, čas) |
| G9 | `check-replay.py` | **replaye**: `tests/replays/*.json` dají očekávaný hash | každý PR | odchylka (regrese mechaniky) |
| G10 | `check-render.py` | **vizuální korektnost měřená**: hra vykreslí mapu podle dat — správný počet dlaždic pro kameru, postava **není překrytá** (viditelné pixely v očekávané oblasti), jméno/HUD přítomny | každý PR | snímek neodpovídá datům (např. postava zmizí za zdí) |
| G11 | `smoke` | **běh**: hra se spustí headless na 300 framů bez `SCRIPT ERROR` | každý PR | jakákoli runtime chyba (Godot 3 API, `null`, chybějící uzel) |
| G12 | `bench_sim.gd` | **výkon**: tick ≤ 2 ms při 200 mobilech / 3000 předmětech | nightly | překročení limitu |
| G13 | `vision` (poradní) | **obsah vidí**: je na snímku město? je vidět postava se zbraní? | každý PR se snímkem | **neblokuje** — jen komentuje (falešný poplach je dražší) |

**Pořadí v CI je závazné:** G1 → G3 → G5 → G2 → G4 → G6 → G7 → G8 → G9 →
G11 → G10 → G13. Schéma je první, protože je nejlevnější a rozpor v zadání
zneplatňuje všechno ostatní.

## 8.3 Tři brány, které mají největší cenu

### G1 `check-schema.py` — rozpor v zadání je objektivní fakt

Měří, že **čtyři zdroje** říkají totéž:
`docs/02` (konstanty) ↔ `data/balance.json` ↔ `core/const.gd` ↔
`render/chunk_renderer.gd` (skutečné kreslení).

```python
# příklad kontroly (kostra)
TILE = read_const("core/const.gd", "TILE_W")          # 44
ISO  = read_const("core/const.gd", "ISO_STEP")        # 22
assert TILE == 44 * 2 // 2, "TILE_W nesedí s artem"
assert ISO == TILE // 2, "ISO_STEP musí být TILE_W/2"
# a hlavně: když se konstanta NEDÁ přečíst, je to VADA, ne prázdný seznam
if TILE is None:
    fail("TILE_W se nepodařilo přečíst — kontrola NEPROBĚHLA")
```

### G4 `check-wiring.py` — „funguje to, ale nic to nedělá"

Hledá volání **v produkčním kódu** (`sim/`, `ui/`, `render/`, `app/`),
ne v `tests/`. Naměřeno na jiném projektu: kontrola hledala použití v celém
repu **včetně testů**, takže funkce zmíněná jen v testu se počítala za
použitou, i když ji hra nikdy nezavolala.

### G10 `check-render.py` — vizuální změna se neověřuje testy

Naměřeno: hráč **nebyl na obrazovce** (dlaždice měly `z_index` 0 a vyšší,
hráč +5, takže ho překryly), a přitom byly testy, schéma i assety zelené.
Chybu našel až **pohled na snímek**. Proto G10 měří „je postava vidět"
přímo v pixelech a G13 se na snímek **dívá** (vision / `read_image`).

## 8.4 CI vs. lokálně (a co v CI není)

| Věc | Lokálně | V CI |
|---|---|---|
| Instalace UO | **je** | **není** → G6 a extraktor se **přeskočí s viditelnou poznámkou** |
| Godot | `--headless --script` | totéž, ale s přesměrovaným `APPDATA` (§2.1) |
| `.godot/` import cache | je | **není** → před testy spustit import, jinak „regresují" assety (P8) |
| Snímek hry | `read_image` | `vision.mjs` (Gemini klíč v secrets), `exit 1` běh nezhodí |
| Blender | je | není → render spritů se dělá lokálně a commituje |

**Pravidlo:** „v CI to nejde" není důvod k tichému přeskočení. Brána vypíše
`SKIP: assety nejsou v CI, kontrola NEPROBĚHLA` a v souhrnu to je vidět.

## 8.5 Lidská kontrola (a proč ji nejde nahradit)

| Co | Jak |
|---|---|
| Je to ta postava? Je vidět zbraň? Nevypadá krajina jako šum? | `read_image` (v session) / `vision` (v CI) |
| Sedí styl? Není sprite useknutý? | totéž; brána to nepozná |
| Je město na svém místě (Britain 1495,1630)? | snímek porovnaný s očekáváním |

**Cache schválených snímků** (baseline) je užitečná, ale má dvě pasti
(naměřeno): percepční hash je **slepý na barvu** a **degeneruje u jednolitého
obrázku** → ukládej i barevný podpis a při degeneraci porovnávej `sha256`.
A pozor: cache platí jen pro obrázky **uvnitř repa** — v CI se modelu posílá
vždy (což je správně).

## 8.6 Zakázané podoby brány (katalog, každá naměřená)

| Podoba | Příklad | Čím to nahradit |
|---|---|---|
| Ptá se na **přítomnost** | `_check(n.has_method("gather"), …)` | zavolej a měř výsledek |
| **Tiše přeskočí** | `if load(path) != null:` | nepodmíněná kontrola, nebo viditelný „čeká se" stav |
| **Zelená nad prázdnem** | regexy nenašly nic → cyklus nad `[]` | „NEMĚŘENO" = vada |
| **Čte komentáře** | našel zakázaný vzor v komentáři, který ho popisuje | odstranit komentáře před hledáním |
| **Statická metrika místo běhu** | počet testů spočítaný ze zdrojáku (42) vs. skutečný běh (36) | čti výsledek běhu |
| **Měří jinou otázku** | „soubor existuje" místo „funkce funguje" | formuluj kontrolu jako tvrzení o chování |
| **Zelená nad nulou souborů** | `check-wiring` bez `scripts/*.gd` → „vše v pořádku", `exit 0` | když je měřených objektů 0, selž |

## 8.7 Formát výstupu brány

Každá brána vypíše **lidský souhrn** a zapíše **strojový JSON**:

```
[G5 check-content] PŘEDMĚTŮ: 312, RECEPTŮ: 1150 (dostupných 640), MONSTER: 88
[G5 check-content] CHYBY: 3
   - recipes.json: recept 412 odkazuje na materiál 0x1BEF, který není v items.json
   - items.json: předmět "katana" nemá art v manifestu (tile 0x13FE)
   - C4 NESPLNĚNO: dostupných receptů 118 < 600
EXIT 1
```
```json
{"gate": "check-content", "measured": {"items": 312, "recipes": 1150,
 "recipes_available": 640, "monsters": 88}, "errors": [ ... ], "skipped": []}
```

## 8.8 Mutační testy bran (povinné)

Postup: **vrať vadu** do kopie projektu, spusť bránu, ověř, že **spadne**.
Když nespadne, brána je slabá — oprav bránu, ne test.

| Brána | Záměrná vada | Musí nastat |
|---|---|---|
| G1 | změň `ISO_STEP` na 23 v `const.gd` | chyba „nesedí s TILE_W/2" |
| G2 | přidej `Input.` do `sim/systems/movement.gd` | chyba „sim nesmí používat Input" |
| G3 | rozbij `swing_delay_ms` (vrať 0) | selhání testu boje |
| G4 | odpoj `_on_use_pressed` od signálu | chyba „handler není připojen" |
| G5 | smaž položku z `items.json`, na kterou odkazuje recept | chyba „neplatný odkaz" |
| G6 | v manifestu uveď neexistující stránku atlasu | chyba „stránka chybí" |
| G7 | po načtení neobnov `rng_state` | rozdílný hash |
| G8 | použij `randf()` v `sim/craft.gd` | rozdílný hash mezi běhy |
| G10 | nastav všem dlaždicím `z_index` nad postavou | chyba „postava není vidět" |
| G11 | zavolej Godot 3 API (`margin_left`) | `SCRIPT ERROR` |
| každá | **odeber vstup** (smaž soubor, vyprázdni seznam) | `NEMĚŘENO` + nenulový exit |

## 8.9 Co znamená „zelená"

Zelená je **jen** tehdy, když platí všechny tři věci:

1. brána **proběhla** (má nenulový počet měřených objektů),
2. **neselhala**,
3. její **mutační test** prokazatelně spadne (tj. brána má zuby).

Když chybí kterýkoli bod, výsledek se hlásí jako **NEMĚŘENO** — a to není
úspěch, to je otevřená práce.
