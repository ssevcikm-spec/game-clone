# ROZHODNUTÍ 2026-10-09 (večer) — SMĚR SE MĚNÍ NA „HERNÍ ZÁKLADY A DEMO"

> **Co je tenhle soubor:** **zadání / rozhodnutí o směru** (záznam, co se
> rozhodlo a proč). Vzniklo **2026-10-09** večer, navazuje na
> [`ROZHODNUTI-2026-10-09-SMER.md`](ROZHODNUTI-2026-10-09-SMER.md) (D1–D9)
> a **v jedné věci ho mění**.
> **Stav projektu je v [`HANDOFF.md`](HANDOFF.md)** — ten se bere jako dnešní
> stav, tenhle soubor je rozhodnutí.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

## 1. Co uživatel řekl (2026-10-09, večer)

Po dodělání `D3` (pravidla politiky jen jako HUD) uživatel řekl:

> „Prosím tě změň prioritizaci. **Automatizace má smysl až když existuje nějaká
> herní náplň.** Teď je cílem **získat co nejvíce za co nejméně času** —
> jinými slovy **rozchodit herní základy, aby se dalo pouštět demo**.“

A na dotaz, co musí být v demu vidět, zvolil:

* **celou krátkou smyčku včetně obchodu** (`K1`–`K6`: koupím krumpáč →
  vytěžím → vykovu → **prodám** → svět jde dál beze mě → postava provede,
  co jsem jí zadal),
* a pořadí prací: **nejdřív všechny otevřené vady, pak náplň**.

## 2. Rozhodnutí (D10) — automatizace je NAD hrou, ne místo ní

**`D4` z 2026-10-09 („nejbližší cíl je krátká smyčka“) platí dál.** Mění se ale
**poměr**: `sim.policy` / `sim.executor` / `sim.decision_log` (session D,
`ZADANI-24`) je **vrstva nad hrou** — umí „míň klikání u toho, co už jde“.
Bez hry pod ní **není co zautomatizovat**, takže:

1. **Politika a automatizace se ODKLÁDÁ** na dobu po demu. Moduly zůstávají
   v repu i v plánu (jsou hotové, měřené a v `MK`), ale **nejsou cíl**.
   `K6` („zadám, co má postava dělat“) je tím **splněná po mechanické stránce**
   a zůstává jako ukázka — ne jako priorita.
2. **Prioritou je „hratelný základ“**: to, co si člověk může zahrát a u čeho
   vydrží — pohyb a dojem, sběr, výroba, **obchod** (koupit/prodat), viditelný
   růst (skilly) a **žádná vada, která to kazí**.
3. **Vady jdou před náplní** (rozhodnutí uživatele). Vady se dělí na dvě
   skupiny a to je důležité:
   * **vady, které kazí dojem při hraní** (záseky, hráč za zdí, zrnění obrazu,
     nedoplňující se stamina) — ty se opravují hned,
   * **vady, které hraní nekazí** (první frame 2 s při startu, mesh neorezává
     podle kamery, černé `nodraw` dlaždice) — zůstávají **pojmenované** a jdou
     po demu, aby se demo neposunulo.

## 3. Co to konkrétně znamená (řazeno podle ceny)

| # | Věc | Proč patří do dema | Cena |
|---|---|---|---|
| 1 | `sim.regen` (doplnění staminy) | dnes po ~26 s běhu už jen chodíš (`data/balance.json` to obchází `DEX = 130`) | 1 modul + test + mutace |
| 2 | Hráč za zdí (CoT — fade statiků, které ho překrývají) | naměřeno: `_analyza/p21-uvnitr.png`, hráč za zdí není vidět | nová vrstva v `render/` |
| 3 | Obchod: `data.vendors`, `sim.vendor`, `ui.vendor_gump` | `K1`/`K4` krátké smyčky; bez něj se nedá koupit krumpáč ani prodat výrobek | 3 granule (schváleno) |
| 4 | `ui.skill_list` | bez něj není vidět, že těžba a výroba něco rostou | 1 modul |
| 5 | `world.regions`, `entity.equipment` | základy, na kterých stojí `M2`/`M5` | 2 moduly |
| 6 | Záseky při přestavbě seznamu (`R6`: max 147 ms) a zrnění obrazu (`V5b`) | kazí dojem při hraní | měření + zásah do `render/`, respektive `project.godot` |

**Co se NEDĚLÁ teď** (a je to pojmenované, ne ztracené): souboj a monstra
(`M5`), magie (`M6`), tvorba postavy a menu (`M7`), zvuk (`assets.sounds`,
`audio.playback`), multiplayer (`MP`). Nejsou zrušené — jsou **za demem**.

## 4. Měřený kontext, ze kterého to vychází (2026-10-09)

* `tools/plan-status.py`: **67** měřeně hotových granul, **4** soubor bez testu,
  **51** chybí. `MK` **6/0/3** — chybí právě obchod (`data.vendors`,
  `sim.vendor`, `ui.vendor_gump`).
* Hra dnes **jde**: chodit, dveře, batoh, žurnál, okno výroby, vytavit rudu
  a vykovat předmět — ale **rudu dostaneš jen debug funkcí** `app/main._give_tools()`
  a **prodat se nedá nic**. To je rozdíl mezi „technickým demem“ a „hratelným“.
* Že je automatizace nad hrou, plyne i z kódu: kdyby dnes postava dostala
  pravidlo „kup krumpáč“, **nepošle se** (`invalid command (range:action)` —
  `vendor` v `data/` neexistuje). Automatizace bez obchodu je prázdná.

## 5. Jak se to pozná (přijímací kritérium dema)

Demo je hotové, když **člověk** ve hře projde tuhle cestu a nemusí u toho
nic zadávat z konzole:

1. přijdu k prodejci a **koupím krumpáč**,
2. **vytěžím rudu** (nástroj mám z obchodu, ne z debugu),
3. u výhně **vytavím ingoty a vykovu předmět**,
4. **prodám výrobek** a mám víc zlata, než jsem měl,
5. **zavřu hru, vrátím se** a svět se posunul, i když jsem tam nebyl,
6. a **vidím u toho, co se děje** (skilly, ceny, žurnál s důvody).

Zelené testy k tomu **nestačí** — u každého bodu je snímek nebo konkrétní číslo
(`docs/09` §9.4, `START-TADY.md` §5).

## 6. Co tenhle soubor NEMAŽE

`D1`–`D9` z `ROZHODNUTI-2026-10-09-SMER.md` platí dál (produkt je `game-clone`,
„feel“ místo kopie, hranice `D3`, krátká smyčka jako nejbližší cíl, klient jako
nový projekt, `uo-shadows` držená opce, brány `F1`/`F4`, MP u hostitele).
Stejně tak platí `docs/01` §1.5 bod 8 (hra smí provést, co hráč rozhodl) —
`D3` se tímhle rozhodnutím **nemění**, jen se přestává být prioritou.
