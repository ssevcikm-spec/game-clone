# Zdroje, licence a poděkování

> **Co je tenhle soubor:** záznam o tom, **odkud pochází každý netriviální
> vstup** ve hře (art, zvuk, data) a **za jakých podmínek se smí šířit**.
> Patří k distribučnímu balíčku: kdo hru někam dá, musí umět doložit, že na to
> má právo. **Aktuální stav projektu:** `HANDOFF.md`.

## 1. Co je NAŠE (a smí se šířit)

| Co | Kde | Jak vzniklo | Licence |
|---|---|---|---|
| **Vlastní art** (`own`, `own-lit`, `own-v3`, `stone-path`, `own2x`) | `assets/own*`, `assets/stone-path/` | 3D model → 1× render v Blenderu (`tools/artgen/`), deterministicky zapečeno do atlasu | naše dílo — šíření bez omezení |
| **Zvuky** (`hit`, `hurt`, `mine`, `smith`, `death`) | `assets/sounds/` | generátor `tools/audio/gen-sfx.py` (syntéza, žádný cizí vzorek) | **CC0-1.0** (viz `assets/sounds/manifest.json`) |
| **Kód, data, dokumentace** | celý repozitář | práce projektu | viz `README.md` |

**Proč jsou zvuky generované:** `ZADANI-27-POCIT.md` §5 dovoluje jen volné
zvuky (CC0/CC-BY) a **zakazuje** zvuk z instalace UO. Generátor je
reprodukovatelný (`tools/audio/gen-sfx.py --check` dá stejné bajty), takže
u žádného souboru není potřeba dohledávat původ. Kdo chce lepší (nahraný)
zvuk, vymění soubor a v `assets/sounds/manifest.json` upraví `license`
a `source` — formát (44,1 kHz stereo) zůstává.

## 2. Co je z UO — a NEDISTRIBUUJE SE

| Co | Kde | Stav |
|---|---|---|
| Art, mapy, animace, hue, tiledata z instalace **Ultima Online Classic** | `assets/uo/` | **lokálně**, v `.gitignore` — **do distribučního balíčku nepatří** |
| Zvuky a hudba z UO | — | **nepoužívají se vůbec** (rozhodnutí uživatele, `ZADANI-27-POCIT.md` §5) |

Hra běží bez `assets/uo/` tak, že si chybějící art **řekne** (brána G6/G10 to
hlásí jako NEMĚŘENO, ne jako vadu kódu) — kdo hru šíří, musí si vlastní data
UO dodat sám, stejně jako to dělá vývoj.

**Vlastní art v UO rozměrech** (`44×44`, kotva jako UO) je naše dílo; shoda
**geometrie** s UO je záměr (`docs/01 §1.2.1` — UO je vzor **duchovní**, ne
tělesný), nikoli odvozenina z jeho spritů.

## 3. Nástroje, na kterých práce stojí

| Nástroj | K čemu | Licence |
|---|---|---|
| Godot 4.7.2 | engine | MIT |
| Python 3 + Pillow + numpy | měřidla, brány, generátor zvuku | PSF / MIT / BSD |
| Blender 5.2.1 (headless) | render vlastního artu | GPL (používá se jako nástroj, výstup je náš) |
| Referenční zdroje v `_src/` (ServUO, ModernUO, ClassicUO, SphereServer) | **jen čtení faktů** (čísla, vzorce) | GPL/Apache/BSD — kód se nekopíruje, viz `README.md` |

## 4. Co tenhle soubor NEDĚLÁ

* **Není právní posudek** — je to evidence pro toho, kdo balíček vydává.
* **Nezapisuje data z UO** (ta jsou v `.gitignore` a v repu být nemají).
* **Nezmíňuje každý soubor jednotlivě** — u vlastního artu stačí jmenný
  prostor, protože vzniká jedním nástrojem a jeden nástroj ho i kontroluje.

_Stav: 2026-10-12._
