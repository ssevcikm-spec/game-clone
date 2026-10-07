# UO klon — zadávací balíček pro vývoj hry

Tenhle adresář **není hra**. Je to **zadání pro AI**, které má hru postavit:
věrný single-player klon Ultima Online nad originálními datovými soubory
UO Classic, které jsou na této stanici.

> **Stavba už běží — tenhle soubor je zadání, ne stav.** Co je hotové a ověřené,
> se bere z **[`HANDOFF.md`](HANDOFF.md)** (přepisuje se každou session);
> ponaučení a pasti z **[`LESSONS.md`](LESSONS.md)**.

## Co si přečíst

| Když jsi… | Začni tady |
|---|---|
| **Člověk**, který zadání předává AI | [`ZADANI-UO-KLON.md`](ZADANI-UO-KLON.md) — hlavní zadání, dá se vložit celé |
| **AI agent**, který má pracovat | `ZADANI-UO-KLON.md` → `docs/01` → `docs/04` → `docs/07` → `docs/08` → `docs/09` |
| **Orchestrátor** (automatické vydávání práce) | [`.forge/roadmap.json`](.forge/roadmap.json) — 100 granulí s DAG, `owns`, `acceptance` |

## Mapa balíčku

```
ZADANI-UO-KLON.md            hlavní zadání (10 oddílů, dá se předat samostatně)
docs/
  01-cil-a-scope.md          cíl, měřitelná věrnost (V1–V12), non-goals, hlavní smyčka
  02-technicka-rozhodnuti.md engine, architektura běhu, izometrie, konvence, výkon
  03-assety-a-data.md        extrakce z instalace UO: soubory, formáty, nástroj, brány
  04-architektura-a-smlouvy.md vrstvy, 100 komponent, Command/Event, TVARY DAT, kritéria
  05-mechaniky.md            pohyb, interakce, souboj, magie, skilly, sběr, výroba, obchod
  06-obsah.md                předměty, nástroje, zbraně, zbroje, monstra, vendory, svět
  07-granule-a-milniky.md    milníky M0–M8, vlny, pravidla granulí
  08-brany-a-overovani.md    13 bran, mutační testy, co znamená zelená
  09-pravidla-pro-agenta.md  jak pracovat, definice hotovo, zakázané zkratky
  10-rizika-a-pasti.md       23 naměřených pastí (každá se už jednou stala)
  11-zdroje-a-data.md        ověřená data instalace, zdroje, otevřené otázky, slovník
.forge/roadmap.json          DAG granulí (generuje tools/roadmap-gen.py)
tools/
  roadmap-gen.py             generátor a lint roadmapy (kontrola DAG, owns, cyklů)
  check-docs-refs.py         kontrola interních odkazů v dokumentaci
research/
  01-core-mechanics.md       pohyb/interakce/postava/čas/ekonomika (487 citací kódu)
  03-combat-magic-items.md   souboj, magie, 159 vlastností předmětů, loot
  04-gathering-crafting.md   sběr a výroba + 04-craft-data.json (1150 receptů)
  06-world-content-npcs.md   facety, města, moongates, dungeony, 88 monster, vendory
  profese.json               profesní šablony z Prof.txt (7 profesí, z toho 3 klasické)
  probe_uo*.py, probe-uo*.json  sondy, kterými jsem měřil formáty dat
_src/                        klony ClassicUO/ServUO/ModernUO/Sphere (reference, gitignore)
```

Poznámka: `research/02-skills.md` a `research/07-extractor-verification.md`
vznikají v paralelních výzkumných větvích. Kdyby v balíčku chyběly, **není to
vada zadání** — příslušné granule (`sim.skill_gain`, `assets.tiledata`) je mají
vyrobit jako svůj první krok, protože obě mají v zadání přesné přijímací
kritérium (`docs/05` §5.10, `docs/03` §3.3.1).

## Jak to použít

**Zahrát si dnešní stav (hra už existuje):** dvojklik na **`HRA.cmd`** v kořeni
repozitáře. Otevře herní okno s mapou Britainu a postavou; **šipky** nebo
**numpad 1–9** = chůze (jedno zmáčknutí = jeden krok), `Esc` = zavřít.
Skript si sám najde Godot v `.cache\godot\` (když tam není, nabídne stažení),
přesměruje `user://` do workspace přes `APPDATA` a upozorní, když chybí
`assets\uo\` — extrahovaná data z instalace UO, která v gitu nejsou.

**Ruční zadání AI (jeden agent):**
vlož `ZADANI-UO-KLON.md` a nech agenta číst `docs/` v pořadí z §0.

**Automatický orchestr (víc agentů paralelně):**
`roadmap.json` má klíč `grains`; conductor vydává granule, jejichž
`depends_on` jsou hotové a jejichž `owns` jsou disjunktní. Bootstrap granule
(`kind: "bootstrap"`: `project.godot`, `tests/`, `tools/gates/`, CI) **nejsou
pro agenty** — zakládá je člověk.

**Údržba balíčku:**
```powershell
$py = 'C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
& $py tools\roadmap-gen.py          # přegeneruje roadmapu + zkontroluje DAG
& $py tools\roadmap-gen.py --check  # jen kontrola (nic nezapisuje)
& $py tools\check-docs-refs.py      # kontrola odkazů mezi dokumenty
```

## Co je ověřené a co ne (stav zadání)

**Ověřeno měřením na této stanici:**
- instalace UO `1.25.35` a inventura dat (velikosti, počty záznamů),
- `hues.mul`: 375 skupin × (4 B hlavička + 8 × 88 B) = 3000 sad; ověřeno
  **sémanticky** — text `Hue (X->Y)` sedí s číselnými poli 1000/1000
  (plochý model dá jen 47, takže „skoro správný" model je špatný),
- `skills.mul`: 58 jmen v pořadí klienta; `skillgrp.mul`: 6 skupin,
- `Prof.txt`: 7 profesí (Warrior, Mage, Blacksmith + 4 moderní),
- `doors.txt` (37 kategorií), `stairs.txt` (19), `teleprts.txt`, `misc.txt`,
- mapa: 7168 × 4096 = 458 752 bloků × 196 B ≈ 85,8 MB (sedí na velikost souboru),
- licence referenčních zdrojů (ClassicUO BSD-2, Sphere Apache-2.0, ServUO/ModernUO GPL),
- čísla mechanik s citacemi `soubor:řádek` (pohyb 400/200 ms, capy 700/225,
  `hits_max = 50 + STR/2`, den 7200 s, buy = 1.90 × sell, …).

**Vyřešeno v průběhu psaní zadání (měřením, ne odhadem):**
- **`tiledata.mul`** — dva bloky se skupinovými hlavičkami a **nulovou
  rezervou**: land 512 skupin × (4 B + 32 × 30 B) od offsetu 4, item 2048
  skupin × (4 B + 32 × 41 B) od 493 568; součet = přesná velikost souboru,
  65 536 předmětů. Vrstvy ověřeny na 1268 předmětech s flagem `Wearable`
  (`docs/03` §3.3.1).
- **`Cliloc.enu`** — je **BWT-komprimovaný** (3. bajt `0x8E`), záznamy jsou
  `i32 číslo, u8 flag, i16 délka, UTF-8 text` (`docs/03` §3.3.2).
- **Dvě chybné hypotézy vyvráceny měřením** (klasický loader i model
  z `research/05`) — to je taky výsledek: ušetří to práci.

**Nevyřešeno (a nesmí se domýšlet):**
- **Jména předmětů v této instalaci nejsou klasická** (chybí `leather gloves`,
  `gold`, `bandage`) — obsah se vybírá podle vlastností, ne podle klasických
  seznamů (`docs/03` §3.3.1b).
- Která formule je „ta pravá" u staminy při běhu, stat loss a světelného cyklu —
  konfigurační flag + `UNVERIFIED` (registr v `docs/11` §11.6).
- Zdroj animací (`anim*.mul` vs `AnimationFrame*.uop`) — rozhodnout měřením
  pokrytí těl (O3).

## Právní poznámka

Assety z instalace UO (art, gumpy, animace, mapa, hudba) **jsou autorská díla
EA/Broadsword**. Zadání je staví tak, aby se **necommitovaly** (`assets/uo/`
je v `.gitignore`) a aby si je každý vygeneroval lokálně z vlastní instalace.
Hudba a zvuky pro veřejné vydání se nahrazují volnými (CC0/CC-BY).
Kód se portuje jen z permisivních zdrojů (BSD-2/Apache-2.0); z GPL projektů
se berou **jen fakta** (čísla, vzorce, tabulky).
