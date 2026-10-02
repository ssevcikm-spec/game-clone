"""Vlozi VYRESENY layout tiledata.mul do docs/03 (sekce 3.3.1).

Sekce se nahrazuje celym blokem, aby text nebyl rozbity zbytky puvodni verze.
"""
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

f = Path(r"E:\Workspaces\game-clone\docs\03-assety-a-data.md")
lines = f.read_text(encoding="utf-8").splitlines(keepends=True)

start = next(i for i, l in enumerate(lines) if l.startswith("### 3.3.1"))
end = next(i for i, l in enumerate(lines) if l.startswith("### 3.3.2"))

NEW = """### 3.3.1 `tiledata.mul` — VYŘEŠENO (dvě fáze: nevyřešeno → vyvrácené hypotézy → změřeno)

**Řešení (naměřeno a doloženo, `research/07`):** soubor jsou **dva bloky
s hlavičkami skupin a NULOVOU rezervou** — součet sedí na bajt přesně.

```text
LAND blok:  offset 4,        512 skupin x (u32 hlavička + 32 záznamů x 30 B) =   493 568 B
            záznam = [u64 flags][u16 texId][20 znaků jméno]
ITEM blok:  offset 493 568, 2048 skupin x (u32 hlavička + 32 záznamů x 41 B) = 2 695 168 B
            záznam = [u64 flags][u8 weight][u8 layer][i32 count][u16 animID]
                     [u16 hue][u16 light][u8 height][20 znaků jméno]   (jméno na +21)

493 568 + 2 695 168 = 3 188 736 = přesná velikost souboru (rezerva 0 B)
65 536 záznamů předmětů (2048 skupin, tj. 4x víc než klasických 0x4000)
```

**Důkaz, že to není jen „číslo, které vychází":** ze 1268 předmětů s flagem
`Wearable` (0x00400000) mají **všechny** nenulovou vrstvu a **96,9 %** vrstvu
uvnitř známého číselníku — a vrstvy sedí na jména:

| předmět (id) | vrstva | význam |
|---|---|---|
| `leather cap` (7609) | 6 | Helm |
| `gargoyle_leather_arm` (769) | 19 | Arms (weight 4, animID 585) |
| `gargoyle_leather_che` (771) | 13 | InnerTorso |
| `gargoyle_leather_leg` (773) | 4 | Pants |
| `backpack` (2482) | 21 | Backpack |
| `dagger` / `longsword` / `katana` | 1 | OneHanded (weights 1/7/6) |
| `anvil`, `forge`, `stone stairs` | 0 | nenositelné, weight 255 |

**Dvě hypotézy, které jsem předtím změřil a vyvrátil** (historie je poučná —
ukazuje, proč se má měřit, ne hádat):

| Hypotéza | Naměřeno | Verdikt |
|---|---|---|
| land 26 B + item 37 B, 512 skupin po 32 (klasický `TileDataLoader`) | 0x4000×37×2 = 1 212 416 ≠ 3 188 736 | **neplatí** |
| land 34 B (jméno +9), item 41 B od 557 056 (`research/05` §4) | čistých jmen: land **4,4 %**, item **6,5 %** | **vyvráceno měřením** |

**Proč všechny naivní modely selhaly:** blok předmětů má **2048 skupin (65 536
dlaždic)**, ne 512 — proto je soubor 4× větší, než model s 512 skupinami
předpovídá, a proto vycházely „skoro správné" offsety, které neseděly
o jednotky bajtů. Past s fází mřížky (`docs/10` P5) byla příznakem tohoto:
mezi skupinami je 4bajtová hlavička, takže fáze jmen se po každých 32
záznamech posune.

> **Poučení:** „číslo, které nějak vychází" (0x4000 × 34 = 557 056) **není**
> důkaz. Důkaz je **čistota dekódovaných jmen** a **součet délek bloků** —
> a ten tady sedí na **0 bajtů rezervy**.

### 3.3.1b Pozor: tato instalace NEMÁ klasická jména předmětů

Naměřeno: v `tiledata.mul` této instalace **nejsou** řetězce `leather gloves`,
`leather helm`, `black pearl`, `gold`, `plate chest` ani `bandage`. Je to
**moderní/přejmenovaná sada dlaždic** (místo nich jsou např.
`gargoyle_leather_arm`, `leather cap`, `backpack`).

**Co z toho plyne pro obsah (`docs/06`):**
1. **Nikdy nehardcoduj klasická jména ani tile id z paměti** — ani z wiki,
   ani z vlastní zkušenosti s UO. Jména se **hledají skenováním tiledata**
   (podle jména, vrstvy, flagu `Wearable`, animID) a do `data/items.json` jde
   to, co v datech **skutečně je**.
2. Když pro nějakou roli („těžká zbroj", „lektvar") není v datech jméno,
   vyber ji **podle vlastností** (vrstva + weight + animID + flagy), ne podle
   názvu — a zapiš, jak jsi ji vybral (`source: "tiledata-by-properties"`).
3. Když něco v datech není vůbec, je to **nález do `content-report.json`**,
   ne tichý přeskok.

"""
lines[start:end] = [NEW]
f.write_text("".join(lines), encoding="utf-8")
print(f"sekce 3.3.1 nahrazena ({len(NEW.splitlines())} radku)")
