# PROMPTY pro Nano Banana — zemní dlaždice (2026-10-11)

> **Co je tenhle soubor:** pracovní pomůcka — **prompty ke kopírování** + důvod
> každé podmínky. Není to stav projektu ([`HANDOFF.md`](HANDOFF.md)) ani zadání
> ([`ZADANI-25-VLASTNI-ART.md`](ZADANI-25-VLASTNI-ART.md)).
> **Proč to vypadá takhle:** vychází z měření v
> [`RESERSE-ART-PIPELINE-2026-10-11.md`](RESERSE-ART-PIPELINE-2026-10-11.md) §11–12
> (UO je military projekce; čtvercová dlaždice se převádí tuhým otočením 45°).
> **Datum:** 2026-10-11.

---

## 1. Verdikt k otázce „rovnou natočené, nebo normální s předtočeným světlem"

| Varianta | Verdikt | Proč |
|---|---|---|
| **(a) Generovat rovnou natočené kosočtverce** | **NE** | Model **neumí držet geometrii**: když jsme ho o kosočtverce požádali, vrátil **1,17 : 1** a **1,71 : 1** — ani jedno není naše 1:1. Navíc ke kosočtvercům přikresluje **3D lem** (boční stěnu), který u země nechceme. Otočení je naproti tomu **přesné a zdarma**, když ho uděláme sami. |
| **(b) Normální čtvercová dlaždice, ale s předtočeným světlem** | **ANO — to je správná cesta** | Model umí dobře **texturu** (to je jeho síla), ne geometrii. My texturu jen **otočíme −45°** — tuhé otočení, měřená odchylka tvaru 0,987 → 1,000. |
| dodatek | **Předtočit jen SVĚTLO, ne hrany** | Kde je hlína/tráva, se otočí **správně samo** (hrana „sever“ skončí na severu). Předtočit je potřeba jen to, co je v artu orientované „nahoru“: **světlo, vržené stíny, stojící trsy**. |

**Přesné znění triku (patří do promptu):** dlaždici otočíme o **45° po směru
hodinových ručiček**, proto ať světlo přichází **z LEVÉ strany** dlaždice — po
otočení bude **zleva-shora**, což je směr světla, který má v naší hře zem
i objekty (naměřeno na UO artu: jas levá-horní − pravá-dolní = **+4,4**).

---

## 2. Sedm podmínek, které musí mít každý prompt

1. **Čtvercová dlaždice zeshora (top-down), vyplňuje CELÝ rám** — žádné
   kosočtverce, žádné pozadí, žádné okraje.
2. **Bezešvá (seamless / tileable)** — vzor plynule pokračuje přes okraje
   obrázku. Tím zmizí švy, když obrázek rozřežeme na dlaždice.
3. **Jen plochá zem** — žádné stojící objekty, zdi, balvany, kmeny; žádná
   tloušťka/boční stěna (3D lem). Stojící věci patří do samostatné vrstvy.
4. **Světlo z LEVÉ strany**, měkké a jednotné v celém obrázku.
5. **Žádné mřížky, rámečky, popisky, text, vodoznak, šipky.**
6. **Jednotné měřítko kamenů** v celém obrázku (žádné „jiné kameny v rohu“).
7. **Styl:** ručně kreslená 2D medieval dlažba, tlumené barvy (šedomodrá +
   okrová), tmavé spáry — **odpovídat předchozí sadě**, ne fotorealisticky.

---

## 3. Hotové prompty

### A) Kámen — základní cesta (nejdůležitější)

```
Seamless tileable texture of a medieval cobblestone road, viewed straight from
above (pure top-down, orthographic). The stone pattern fills the ENTIRE frame
edge to edge — no background, no margins, no border, no grid lines, no labels.
Irregular hand-laid rounded stones of mixed size, muted grey-blue and warm tan
stones with dark packed-earth joints. Soft even lighting coming FROM THE LEFT
side of the image (shadows fall to the right), low contrast, no harsh highlights.
Hand-painted 2D game texture, slightly weathered, no photorealistic look.
The pattern must continue across the image edges so the image can be cut into
tiles without visible seams. Same stone scale across the whole image.
```

### B) Hlína / ušlapaná zem (set ji neměl — potřebujeme ji jako podklad)

```
Seamless tileable texture of packed dirt ground, viewed straight from above
(pure top-down, orthographic). Fills the ENTIRE frame edge to edge — no
background, no margins, no border. Fine dirt with small pebbles, tiny cracks and
subtle wheel ruts, muted brown tones. Soft even lighting coming FROM THE LEFT
side of the image, low contrast. Hand-painted 2D game texture, slightly
weathered, not photorealistic. Must tile seamlessly in all directions.
```

### C) Kámen zarostlý mechem (varianta pro okraje cest)

```
Seamless tileable texture of old cobblestone overgrown with moss, viewed straight
from above (pure top-down, orthographic). Fills the ENTIRE frame edge to edge, no
background, no border. Flat patches of green moss and thin grass lying ON the
stones (nothing standing upright, no tufts sticking up). Muted grey-blue and tan
stones with dark joints. Soft even lighting FROM THE LEFT side of the image.
Hand-painted 2D game texture, weathered, not photorealistic, tiles seamlessly.
```

### D) Mokrý kámen s kalužemi (pro déšť a večer)

```
Seamless tileable texture of wet cobblestone road after rain, viewed straight
from above (pure top-down, orthographic). Fills the ENTIRE frame edge to edge, no
background, no border. Shallow puddles lying flat between the stones, dark
reflective water with a soft sky reflection, damp dark joints. Soft even lighting
FROM THE LEFT side of the image. Hand-painted 2D game texture, not photorealistic,
tiles seamlessly in all directions.
```

### E) Přechodové dlaždice (volitelně — dekorativní vzhled, ne systematický)

> Systematické přechody umíme **procedurálně** (kámen + hlína přes masku) a je
> to přesné. Tenhle prompt je pro **ručně malovaný, organický** vzhled navíc —
> počítej s tím, že některé orientace budou chybět a doplníme je otočením o 90°.

```
A sheet of 4x4 square tiles for a 2D top-down game, all tiles EXACTLY the same
size, laid out in a strict regular grid, no gaps, no borders, no labels, no
grid lines. Theme: a cobblestone road meeting dirt and grass. Each tile shows
the cobblestones with the dirt or grass intruding from a DIFFERENT side — top,
right, bottom, left, and the four corners — covering every orientation once.
Pure top-down view, flat, no thickness, no 3D sides. Soft even lighting FROM THE
LEFT side of the image, identical in every tile. Hand-painted medieval look,
muted colours, matching stone scale across all tiles.
```

### Negativní prompt (když to jde zadat zvlášť)

```
isometric, diamond, 2:1, three-quarter view, perspective, 3D render, thickness,
side walls, drop shadow outside the tile, border, frame, grid lines, text,
labels, watermark, people, animals, buildings, standing grass tufts, bushes,
rocks standing up, photorealistic, HDR, oversaturated
```

---

## 4. Co s výstupem udělám já (aby se vědělo, co je potřeba dodržet)

1. **Kontrola čísly:** rozměr obrázku, počet dlaždic v mřížce, zda jsou tvarově
   čtvercové (sonda `_analyza/p53-nabor/s1-mrizka.py`).
2. **Řez:** u bezešvé textury rozřezat na mřížku (např. 6×6 dlaždic po ~170 px);
   u listu se držet detekované mřížky.
3. **Převod:** **otočení −45°** + zmenšení na **44×44** (Lanczos), alfa = obsah,
   `ox = oy = 0` → běžný `land` sprite v existujícím kontraktu atlasu.
4. **Kontrola pohledem** (`read_image`) na složenou ulici v naší mřížce —
   měření nepozná „tohle není dlažba“, oči ano.
5. **Zápis** do atlasu a vrstvy `assets/own-art.json` (id k přebití: UO cesta je
   1001–1004; 1001 už drží `own-lit`, tedy 1002–1004).

**Velikost, kterou potřebujeme:** dlaždice **≥ 132 px** (3× cíl). Při výstupu
1024×1024 a mřížce 6×6 vychází ~170 px na dlaždici — to je správně.

---

## 5. Když to nevyjde (iterační žebřík)

| Co je na obrázku špatně | Co změnit v promptu |
|---|---|
| Kosočtverce / izometrie místo čtverců | přidat: *„pure top-down orthographic, square grid, viewed straight down“* a odebrat slovo „isometric“ |
| Viditelné pozadí nebo okraje dlaždic | přidat: *„fills the entire frame, no background, no border“* |
| Dlaždice na sebe nenavazují (švy) | přidat: *„seamless tileable, pattern continues across the edges“* — a použít variantu „jedna velká textura“ místo listu dlaždic |
| 3D lem / boční stěna | přidat: *„flat, zero thickness, no 3D sides, no drop shadow“* |
| Světlo zeshora nebo zleva-shora | zopakovat: *„light FROM THE LEFT side only“* (po otočení potřebujeme zleva-shora) |
| Stojící tráva a balvany | přidat: *„flat moss and grass lying on the ground, nothing standing upright“* |
| Jiné měřítko kamenů v každé dlaždici | *„identical stone scale and identical lighting across all tiles“* |
| Styl utíká mezi sadami | **přiložit předchozí dobrou sadu jako referenční obrázek** — v jedné konverzaci si model drží styl, v nové ne |

**Obecné pravidlo:** model je dobrý na **malbu textury**, špatný na
**geometrii a rozvržení**. Když se nedaří geometrie, neopravuj ji v promptu —
vyřeš ji kódem (řez, maska, otočení) a v promptu chtěj jen texturu.

---

## 6. Proč nestačí zadat „iso dlaždice“ (důkaz, ne názor)

| Sada z tvého profilu | Co model vrátil | Co potřebujeme |
|---|---|---|
| pixel-art iso | kosočtverec **1,71 : 1** | 1 : 1 |
| stone road iso | kosočtverec **1,17 : 1** | 1 : 1 |
| cobblestone road (čtvercová) | **čtverce** 152×155 px, mřížka 4×8 | ✓ čtverce |

Naměřeno sondou `_analyza/p53-nabor/s9-nove-sady.py` (kalibrace: UO dlaždice
vyšla 1,00) a `s13-otoceni.py` (otočení je tuhé: 0,987 → 1,000). Tedy: model
**čtverce umí**, kosočtverce **ne**.
