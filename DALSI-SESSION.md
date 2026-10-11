# Další session — co zadat a v jakém pořadí (2026-10-10)

> **Co je tenhle soubor:** **rozcestník zadání** (ne stav a ne plán granulí).
> Stav projektu je v [`HANDOFF.md`](HANDOFF.md), plán v `docs/07` +
> `.forge/roadmap.json`, rozhodnutí o směru v
> [`ROZHODNUTI-2026-10-10-MODERNI-UO.md`](ROZHODNUTI-2026-10-10-MODERNI-UO.md)
> (M1–M10). Tenhle soubor říká, **kterou session spustit dál a co jí zadat**.
> **Zapisuje se přepisem** (je to rozcestník), ale hotové session se z něj
> **neodstraňují** — jen se označí.

## 0. Co je hotové (odkud se startuje)

| Hotovo | Důkaz |
|---|---|
| Krátká smyčka je hratelná: těžba → výroba → **prodej** | commit `d8e2a14`, HANDOFF 2026-10-10/2 |
| Automatizace **vypnutá** (opt-in `--policy`), spam opraven u zdroje | `app/main.gd`, `sim/decision_log.gd`, testy **1852/0**, mutace chycena |
| Vlastní art: pipeline + 1× sada (46 spritů) + 2× srovnání | `tools/artgen/`, `assets/own/`, `assets/own2x/`, `pack_atlas.py --check` 476/0 |
| Brána `G14` (float ve stavu) | `tools/gates/check-state-float.py`, self-test 6/0 |
| Pravidlo „UO duchovně, ne tělesně" | `docs/01` §1.2.1 |

**Automatizace je vypnutá, ale zapnout se dá** (`M10`): `HRA.cmd` předává
argumenty dál (`%*`), takže stačí

```bat
HRA.cmd -- --policy              :: vezme user://policy.json
HRA.cmd -- --policy=C:\cesta\moje-pravidla.json
```

Bez přepínače se politika **nenačte ani když soubor existuje** a do žurnálu
neteče nic. Spam je navíc opraven u zdroje (throttle podle pravidla), takže
i se zapnutou politikou jdou do žurnálu jen **změny**.

**Běží:** session, která na 1× sadu aplikuje **světlo** (kontaktní stín + AO +
jedno slunce) → `assets/own-lit/` + srovnávací list. Až doběhne, je to základ
pro session **A**.

---

## A) Vlastní art do hry (integrace) — **největší viditelný krok**

**Cíl:** hra kreslí vlastní art pro id, která vlastní sada obsahuje; zbytek
zůstává z UO. Přepíná se **po kusech**, nic se nerozbíjí.

**Co přečíst:** `tools/artgen/SEAM.md` (návrh: jedno místo
`render/texture_cache.gd` `_index`, `offset()` musí jít ze **stejného záznamu**
jako textura), `docs/02` §2.4, `docs/04` §4.2 (`render.textures`), `docs/08`
(`G6`, `G10`).

**Rozsah zápisu:** `render/`, `app/`, `tools/gates/` (nová brána), `docs/`
(smlouva + odchylka), `data/` (jen když je potřeba), nové granule v
`tools/roadmap-gen.py`.

**Hotovo, když:** (1) ve hře je vidět vlastní dýka/krumpáč/ruda/ingot, postava
a 2 dlaždice, (2) pro id bez vlastního artu se beze změny použije UO art,
(3) `G10` (vzhled) i `G6` (assety) projdou **po vědomé re-baseline s dokladem**
(foto/číslo), (4) testy a replaye beze změny hashů, (5) snímek obrazovky
s vlastním artem **a popis, co je na něm vidět špatně**.

**Co nedělat:** neměnit geometrii (44×44, `Z_SCALE` 4) ani bránu `G1`;
nenahrazovat `assets/uo/` (zůstává jako fallback a pro id, která vlastní sada
nemá); necommituovat nic odvozeného z UO artu.

---

## B) Kvalita artu: obrys, kontrast, čitelnost

**Cíl:** vlastní art přestane být „3D hladký" proti UO pixel artu. Naměřeno
v pilotu: předměty mají **menší kontrast a chybí tmavý obrys**, ingot čte jako
kostka, krumpáč jako tyč, chůze se při zoomu skoro nerozezná.

**Co přečíst:** `tools/artgen/MERENI.md` (co je změřeno a co je past),
`ZADANI-25` §10 (co 2× dalo a vzalo), `LESSONS.md` 2026-10-10 (tři lekce).

**Rozsah zápisu:** jen `tools/artgen/` a nový jmenný prostor artu.

**Hotovo, když:** existuje srovnávací list **UO | náš starý | náš nový** pro
dýku, terén a postavu, `read_image` potvrdí, že se to zlepšilo **jako čitelnost**
(ne „vypadá to jinak"), a je změřený čas navíc.

**Co nedělat:** nehonit pixel art 1 : 1 (nejsme kopie — `docs/01` §1.2.1);
neměnit rozlišení (měřeno: ve stejném měřítku je 2× měkčí).

---

## C) M5 — souboj, monstra, smrt (11 granulí, 0 hotových)

**Cíl:** hra dostane protivníky a riziko. Dnes `attack` routuje do
**neregistrovaného** systému → hráč dostane „Not available yet".

**Co přečíst:** `docs/05` §5.5 (vzorce AoS + `M2`: let projektilu je vizuální),
`docs/04` §4.6.4 (smlouva souboje + přijímací kritérium 20 swingů ≥ 5 zásahů),
`ZADANI-20` (NPC a souboj), `.forge/roadmap.json` (M5).

**Rozsah zápisu:** `sim/systems/`, `sim/entity/`, `data/` (weapons/armor/
monsters), `ui/` (health bar je odložené a vratné rozhodnutí), nové case
soubory; **`tests/run_tests.gd` se needituje**.

**Hotovo, když:** hráč zabije monstrum (a monstrum hráče), loot jde sebrat
a prodat, replaye zůstanou zelené (nebo se přepnou **s dokladem**), a je to
vidět na snímku.

**Poznámka k automatizaci:** `attack` do `ACTION_KINDS` politiky patří **sem**
(ne dřív) — jinak vznikne mrtvá slovní zásoba, kterou hlásí `G4`.

---

## D) Obsah a čitelnost pro „hráč z ulice"

**Cíl:** demo, které dá člověku, ne jen autorovi. Kandidáti (vybrat, ne všechny):
tvorba postavy + profese (`M7`), skill list a tooltip (existují), světlo
(`render.light`), zvuk (`assets.sounds`, `audio.playback`), makra/hotkeys.

**Hotovo, když:** člověk, který hru nezná, projde krátkou smyčku **bez rady**
a je schopen říct, co dělal a proč.

---

## E) Modding (nová práce, `SMER` §3)

**Cíl:** „modifikovatelná a rozšiřitelná" je dnes **chybějící vlastnost**:
pevné smlouvy a brány jsou dobré pro měření, ne pro moddery. Znamená to švy,
stabilní ID, pořadí načítání, verzované ukládání, sandbox skriptů.

**Až po A–C** — je to architektonická práce, ne obsah.

---

## Jak to zadat (zkopíruj do nové session)

```text
Pracovní složka: E:\Workspaces\game-clone
NEJDŘÍV si přečti DALSI-SESSION.md (co dělat), HANDOFF.md (stav) a
ROZHODNUTI-2026-10-10-MODERNI-UO.md (M1–M10, směr).
Tvoje session je [A/B/C/D/E]. Přečti sekci, kterou jsi dostal, a drž její
"Co přečíst" a "Rozsah zápisu".
Pravidla: piš jen do souborů z "owns" své granule; tests/, tools/gates/,
project.godot, docs/ a .forge/ se needitují (mění je člověk nebo integrační
session). "Hotovo" = soubor v main A brána zavolala jeho funkci A přijímací
kritérium proběhlo s konkrétní hodnotou. Neověřenou věc napiš jako UNVERIFIED.
UO je vzor POCITEM, ne tělesně (docs/01 §1.2.1) - "neshoduje se s UO" není vada,
vada je jen rozbitý kontrakt (kotva, id prostor, geometrie bez koordinované
změny) nebo něco, co se nedá přečíst.
Na konci: přidej záznamy do LESSONS.md a přepiš HANDOFF.md, pak commitni.
```

## Paralelně, nebo sériově?

**Paralelně jde A s C** (art vs. simulace — disjunktní soubory) a **B s C**.
**A a B paralelně nejdou** (obojí píše do `tools/artgen/` a do artu).
**D a E** mají smysl až po A (jinak se ladí čitelnost něčeho, co se ještě
bude předělávat).

## Co tenhle soubor NEDĚLÁ

* **Nezapisuje nové granule** do `.forge/roadmap.json` — to patří uživateli /
  integrační session (`docs/07` §7.1 bod 5).
* **Nerozhoduje o prioritách za uživatele** — pořadí A → B → C je doporučení
  podle měřené ceny a viditelnosti, ne verdikt.
