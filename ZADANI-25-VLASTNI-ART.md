# ZADÁNÍ 25 — vlastní art: pilot druhé koleje (`tools/artgen/`, `assets/own/`)

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalo) — nepřepisuje
> se. Vzniklo **2026-10-10** z rozhodnutí `M6`–`M8` v
> [`ROZHODNUTI-2026-10-10-MODERNI-UO.md`](ROZHODNUTI-2026-10-10-MODERNI-UO.md)
> (odpovědi uživatele: modelovat v 3D → renderovat do spritů, zdroje držet;
> první sada = nejmenší hratelný vzorek; jede **hned paralelně**).
> **Stav projektu** je v [`HANDOFF.md`](HANDOFF.md), plán v `docs/07`.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

## 1. Cíl — prokázat pipeline a ZMĚŘIT, nevyrobit sadu

**Pilot má odpovědět na tři otázky číslem:**

1. **Jde to?** Vyrobí náš vlastní sprite, který **sedí do stávajícího kontraktu**
   atlasu (stejná geometrie, stejné kotvy, stejný tvar manifestu)?
2. **Kolik to stojí?** Minuty na **model**, na **render**, na **postprocess**
   a na **kontrolu pohledem** — a kolik spritů vyjde z jednoho modelu.
3. **Kde je úzké hrdlo?** (Předpoklad z auditu: **kontrola pohledem** — brána
   pozná „mince je 0,67× truhly", ale ne „tohle není truhla", `docs/08`.)

**Co pilot NENÍ:** není to výroba sady pro hru. Je to **jeden kus od každé
třídy** + změřený čas, ze kterého se dá spočítat, co je reálné (`M7`).

## 2. Naměřená fakta (neopakuj měření, ber je jako vstup)

**Kontrakt atlasu** (`assets/uo/manifest.json`, změřeno 2026-10-10):

| Věc | Hodnota |
|---|---|
| Klíče spritu | `id`, `kind`, `page`, `x`, `y`, `w`, `h`, `ox`, `oy`, `rect` |
| Druhy a počty | `gump` 2 019 · `item` 39 326 · `land` 4 244 · `texmap` 4 116 |
| Stránky | 77 × 2048², `pad` 1, cesta `atlas/<kind>_<n>.png` |
| `land` | **vždy 44 × 44**, `ox` = 0, `oy` = 0 |
| `item` | medián **45 × 74**, `ox` medián 0, `oy` medián **30** (kotva „stojí na dlaždici") |
| `texmap` | 64 × 64 (max 128) |
| Chybí v archivu UO | 34 gumpů, 26 020 item artů, 12 140 land artů (`report`) |

**Nástroje na stanici (ověřeno):** Blender **5.2.1 LTS**
(`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`), hotová pipeline
v `E:\Workspaces\uo-shadows\tools\blender\` (`build_character.py` 13 kB,
`postprocess.py` 4,6 kB, **260 spritů** = tělo/nohy/trup/zbraň × 4 směry
× 8 framů, izo kamera, alfa), Python s Pillow/numpy, `read_image` na kontrolu
pohledem.

**Past, na kterou se platí:** Blender **vrací exit 0 i při chybě ve skriptu**
(traceback jde na stderr). **Ticho není úspěch** — kontroluj stderr **a** to,
že vznikl očekávaný PNG.

**Čím se hra řídí při kreslení (kontrakt, který se NEMĚNÍ):** tři id prostory
(`land` = id, `item` = id + `0x4000`, `texmap` = id + `0x10000`,
`docs/04` §…), `assets/uo/hues.json`, `assets/uo/anim-manifest.json`
(animace: akce 0/1 = chůze, 2 = běh; 8 směrů → 5 + zrcadlení; frame 80 ms).

## 3. Rozsah pilotu (nejmenší hratelný vzorek)

Vyrobit **vlastní** verzi těchto věcí — nic víc:

| # | Co | Kolik spritů | Poznámka |
|---|---|---|---|
| 1 | **terénní dlaždice** | 2 (tráva, cesta) | 44 × 44, `ox/oy = 0/0`, kosočtverec 2 : 1 |
| 2 | **postava — chůze** | 5 směrů × 8 framů = 40 | stejná konvence jako UO (5 směrů + zrcadlení); běh může být tatáž sada |
| 3 | **předměty** | krumpáč, ruda, ingot, dýka = 4 | kotva jako UO `item` (`oy ≈ 30` u předmětu „na zemi") |
| 4 | **kontaktní list** | 1 PNG | vlastní sprity **vedle** původních UO, aby byl rozdíl vidět |

**Geometrie se nemění:** 44 × 44 dlaždice, 5 směrů, kotvy UO. Důvod: změna by
shodila bránu `G1` (relace `ISO_STEP == TILE_W/2`) a celý renderer; nejdřív se
prokazuje pipeline **uvnitř** stávajícího kontraktu.

## 4. Required výstup

1. `tools/artgen/` — skripty, které se dají **pustit znovu** (ne ruční klikání):
   `build_model_*.py` (Blender: model + kamera + světlo), `render_sprites.py`
   (Blender: render směrů/framů s alfou), `pack_atlas.py` (Pillow: složí stránky
   + `manifest.json` ve stejném tvaru jako `assets/uo/manifest.json`),
   `contact_sheet.py` (vlastní vedle původních).
2. `assets/own/` — `manifest.json` + `atlas/*.png` **ve stejném tvaru** jako
   `assets/uo/` (klíče spritu výše). `assets/own/` je **nový jmenný prostor**:
   hra ho dnes nečte, čte se až po integrační granuli.
3. `tools/artgen/MERENI.md` — **naměřené časy** (minuty: model / render /
   postprocess / kontrola pohledem), počet spritů z jednoho modelu, co bylo
   potřeba ručně sáhnout, a **co je úzké hrdlo**. Čísla s postupem (co se
   spustilo), ne odhad.
4. `tools/artgen/SEAM.md` — **návrh**, jak se `assets/own/` napojí do hry
   (text, ne kód): kde je jediné místo, které rozhoduje `(kind, id) → sprite`
   (`render/texture_cache.gd`), a co musí platit, aby šlo přepínat **po kusech**
   (vlastní art vyhrává, kde je; jinak původní).
5. **Snímek** kontaktního listu ověřený `read_image` + **jedna věta**, co na něm
   je vidět špatně (povinné — „nic" je taky odpověď, ale musí být po podívání).

## 5. Co NEDĚLAT (write scope — tohle je podmínka paralelního běhu)

* **Nezapisovat** do `app/`, `render/`, `sim/`, `ui/`, `tests/`, `tools/gates/`,
  `data/`, `docs/`, `.forge/`, `project.godot` ani `assets/uo/` — v témže stromu
  **běží jiná session** (demo, `D10`) a tyhle soubory vlastní ona nebo plán.
* **Neintegrovat** vlastní art do rendereru — to je samostatná granule.
* **Nezakládat** nové granule v `.forge/roadmap.json` (patří uživateli).
* **Nepřepisovat** `assets/uo/` ani nic z instalace UO.
* **Necommitovat** — v pracovním stromě je necommitnutá práce jiné session.
* **Neměnit** `tests/` a brány; vlastní mini-kontrolu manifestu si napiš
  v `tools/artgen/`.

## 6. Jak ověřit

```powershell
# 1) Blender existuje a je to ta verze
& 'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe' --version

# 2) pilot se dá pustit znovu (idempotentně) a nic nerozbije
python tools\artgen\pack_atlas.py --check

# 3) kontaktní list a PODÍVAT SE (povinné)
#    read_image na tools/artgen/_kontaktni-list.png

# 4) kolik spritů vzniklo vs. očekáváno (2 + 40 + 4 = 46)
python -c "import json;d=json.load(open('assets/own/manifest.json',encoding='utf-8'));print(len(d['sprites']))"
```

**Hotovo je, když:** skripty jdou pustit znovu, `assets/own/manifest.json` má
stejné klíče jako `assets/uo/manifest.json`, na kontaktním listu jsou **vlastní
i původní** sprity a v `MERENI.md` jsou **čísla s postupem**.

## 7. Pick up here

**Začni kontaktním listem z JEDNOHO předmětu** (dýka): model → render 1 směru →
postprocess → zapsat do manifestu → porovnat s původním artem ve stejném měřítku
a **podívat se na to**. Teprve pak postava (40 spritů) a zbytek — kdyby se
konvence kotev nebo měřítko rozjely, je to vidět na jednom kuse za minuty, ne
na čtyřiceti.
