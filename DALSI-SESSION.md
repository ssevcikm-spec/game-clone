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
| **1× sada SE SVĚTLEM** (`assets/own-lit/`, 46 spritů, kontaktní stín + AO + jedno slunce) | `pack_atlas_lit.py --check` **893/0**, determinismus hlášen ve dvou úrovních, `MERENI.md` §9, `ZADANI-25` §11 |
| Brána `G14` (float ve stavu) | `tools/gates/check-state-float.py`, self-test 6/0 |
| Pravidlo „UO duchovně, ne tělesně" | `docs/01` §1.2.1 |

**Nic neběží** — všechny koleje jsou dotažené do stavu, kdy se dá zadat session A.

**Automatizace je vypnutá, ale zapnout se dá** (`M10`): `HRA.cmd` předává
argumenty dál (`%*`), takže stačí

```bat
HRA.cmd -- --policy              :: vezme user://policy.json
HRA.cmd -- --policy=C:\cesta\moje-pravidla.json
```

Bez přepínače se politika **nenačte ani když soubor existuje** a do žurnálu
neteče nic. Spam je navíc opraven u zdroje (throttle podle pravidla), takže
i se zapnutou politikou jdou do žurnálu jen **změny**.

**Běží:** nic. Vlastní art má tři hotové sady: `assets/own/` (1× bez světla),
`assets/own2x/` (2×, jen pro srovnání) a **`assets/own-lit/` (1× se světlem —
základ pro integraci)**. U `own-lit` platí změřeno: **terén a postava jsou
připravené**, **placaté předměty (dýka, ingot) ještě ne** — jejich stín je
1px lem a kontrast klesl (dýka 25,7 → 15,2), což řeší session B.

---

## A) Vlastní art do hry (integrace) — **největší viditelný krok**

> **✅ HOTOVO 2026-10-11** (session „A“): seam je v `render/own_art.gd` +
> `assets/own-art.json`, brány `G6` a `G10` po vědomé re-base line, nová brána `G15`,
> testy **2629 / 0** (sloučený strom s M5), snímky v `.cache/render/dukaz/` (ne v gitu —
> obsahují UO mapu). **Zadání níž zůstává jako záznam**, needituje se.
> ⚠ **Zjištění, které se týká plánování:** tvrzení „A a C jsou disjunktní“ v §„Paralelně,
> nebo sériově?“ **neplatí** — souběžná session M5 psala do `render/anim_player.gd`,
> `app/main.gd` a `app/world_view.gd`.

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

## F) Úklid: mrtvé kotvy v mutačním harnessu (malá, ale měřitelná)

**Co se stalo 2026-10-10:** při práci se našly **tři mrtvé kotvy** v
`tools/gates/mutace-tests.py` — vzory, které se ve zdroji už nenajdou, takže se
mutace **tiše neprovede** a harness ji počítá jako nechycenu (nebo ji přeskočí
s hláškou `PATRANA VETA SE VE ZDROJI NENASLA`). Dvě vznikly dřívější prací
(model `never` u staminy), jednu jsem způsobil sám (throttle podle pravidla).

**Úkol:** spustit `python tools/gates/mutace-tests.py` (celý, ~200 vzorů, trvá
desítky minut) a **vypsat všechny `PATRANA VETA`** + přepsat kotvy na dnešní
kód. **Nemaže se nic** — vzor, který už nemá co měřit, se buď opraví, nebo se
odstraní s odůvodněním v komentáři.

**Hotovo, když:** běh nehlásí ani jednu `PATRANA VETA` a souhrn je
`N z N chyceno; smlouva vstupu: OK`.

---

## Jak to zadat (zkopíruj do nové session)

**Postup, který funguje (ověřeno z druhé strany — z session vidím jen workspace):**

1. Otevři **novou session** v tomtéž okně, ve kterém mluvíš se mnou
   (`http://127.0.0.1:19387`) — nebo z terminálu zkus `dsh --help` (na stanici
   je zkratka `dsh` v `%LOCALAPPDATA%\Programs\nodejs\dsh.cmd`; **její přepínače
   jsem zevnitř session nedokázal ověřit**, instalace DSH je mimo workspace).
2. **Dej jí plný přístup k souborům.** V režimu `workspace-write` nejde zapsat
   do `.cache` a brány/testy kvůli tomu hlásí **falešné vady** (naměřeno dřív:
   24 selhání v `workspace-write`, 12 po přesměrování `APPDATA`, **0 s plným
   přístupem**). Než začneš řešit „něco je rozbité", zkontroluj tenhle režim.
3. Vlož **jeden blok** níž (A–F) jako první zprávu. Blok je samostatný — nová
   session nemá žádný kontext z téhle.
4. Nech ji dojít k „hotovo, commitnuto"; na konci se zeptej, co zůstalo
   otevřené (má to být v `HANDOFF.md`).

### Blok A — vlastní art do hry (integrace)

```text
Pracovní složka: E:\Workspaces\game-clone

Než začneš: přečti DALSI-SESSION.md (sekce A), HANDOFF.md (stav) a
ROZHODNUTI-2026-10-10-MODERNI-UO.md (M1–M10, směr). Pak tools/artgen/SEAM.md
(návrh napojení), docs/02 §2.4, docs/04 §4.2 (render.textures) a docs/08 (G6, G10).

Úkol: zapoj vlastní art do hry tak, aby se přepínal PO KUSECH — pro (kind, id),
které vlastní sada obsahuje, se použije vlastní sprite, jinak zůstane UO art.
Základ je assets/own-lit/ (1× SE SVĚTLEM): terén a postava jsou připravené,
placaté předměty (dýka, ingot) ber zatím z assets/own/ nebo je vynech — jejich
stín a kontrast řeší session B. Kontrakt manifestu je stejný jako assets/uo/.

Hotovo, když: 1) ve hře je vidět vlastní dýka/krumpáč/ruda/ingot, postava
a 2 dlaždice; 2) id bez vlastního artu se beze změny použije z UO; 3) brány G6
a G10 projdou PO VĚDOMÉ re-baseline s dokladem (snímek + číslo, ne "někdo to
spravil"); 4) testy a replaye beze změny hashů; 5) přiložíš snímek a napíšeš,
co je na něm vidět špatně.

Pravidla: geometrii (44×44, Z_SCALE 4) ani bránu G1 neměň; assets/uo/ zůstává
jako fallback; UO je vzor POCITEM, ne tělesně (docs/01 §1.2.1) — "neshoduje se
s UO" není vada. Na konci přidej záznamy do LESSONS.md, přepiš HANDOFF.md
a commitni + pushni.
```

### Blok B — kvalita artu (obrys, kontrast, čitelnost)

```text
Pracovní složka: E:\Workspaces\game-clone

Než začneš: přečti DALSI-SESSION.md (sekce B), tools/artgen/MERENI.md
(co je změřeno a co jsou pasti), ZADANI-25 §10 (co dalo 2× a co vzalo)
a LESSONS.md – záznamy z 2026-10-10 o artu.

Úkol: vlastní art přestane být "3D hladký" proti UO pixel artu. Dvě konkrétní
věci jsou UŽ ZMĚŘENÉ (ZADANI-25 §11), začni jimi:
(i) STÍN PRO PLACATÉ PŘEDMĚTY — dýka má viditelný jen 1px lem (7 px), ingot
11 px, kdežto ruda 235 px; (ii) VRÁTIT KONTRAST — jedno směrové slunce bez
výplně vzalo kovům odlesky (rozptyl jasu dýky 25,7 → 15,2, postavy 50,8 → 45,2)
a sada je tmavší o 8–13 %. Pak teprve řeš obrys/čitelnost obecně.

Hotovo, když: existuje srovnávací list UO | náš starý | náš nový pro dýku,
terén a postavu; read_image potvrdí, že se to zlepšilo JAKO ČITELNOST; je
změřený čas navíc; a co se nezlepšilo, je pojmenované.

Pravidla: zapisuj jen do tools/artgen/ a nového jmenného prostoru artu;
rozlišení neměň (měřeno: ve stejném měřítku je 2× měkčí, ne ostřejší);
nehonit pixel art 1:1 (nejsme kopie, docs/01 §1.2.1). Na konci LESSONS.md +
HANDOFF.md + commit a push.
```

### Blok C — M5: souboj, monstra, smrt

```text
Pracovní složka: E:\Workspaces\game-clone

Než začneš: přečti DALSI-SESSION.md (sekce C), HANDOFF.md, docs/05 §5.5
(vzorce AoS + rozhodnutí M2: let projektilu je VIZUÁLNÍ, zásah se počítá při
akci), docs/04 §4.6.4 (smlouva souboje + přijímací kritérium), ZADANI-20
a .forge/roadmap.json (milník M5 = 11 granulí, 0 hotových).

Úkol: udělej M5 — souboj, monstra, smrt, loot. Dnes příkaz `attack` routuje do
neregistrovaného systému, takže hráč dostane "Not available yet".

Hotovo, když: hráč zabije monstrum (a monstrum hráče), loot jde sebrat
a prodat, replaye zůstanou zelené (nebo se přepnou S DOKLADEM), a je to vidět
na snímku.

Pravidla: hotové moduly neměň bez zápisu ve docs/; `attack` do slovníku
politiky (ACTION_KINDS) patří SEM, ne dřív — jinak vznikne mrtvá slovní
zásoba, kterou hlásí G4. tests/run_tests.gd se needituje (nové case soubory
jsou v pořádku). Na konci LESSONS.md + HANDOFF.md + commit a push.
```

### Blok D — obsah a čitelnost pro hráče

```text
Pracovní složka: E:\Workspaces\game-clone

Než začneš: přečti DALSI-SESSION.md (sekce D), HANDOFF.md, docs/07 (milníky M7)
a ROZHODNUTI-2026-10-10-MODERNI-UO.md (M4: hra je pro lidi).

Úkol: vyber a udělej to, co potřebuje člověk, který hru nezná — kandidáti:
tvorba postavy + profese, světlo (render.light), zvuk (assets.sounds,
audio.playback), makra/hotkeys, tooltipy. Ne všechny: vyber podle ceny
a napiš, proč.

Hotovo, když: člověk, který hru nezná, projde krátkou smyčku BEZ RADY a umí
říct, co dělal a proč (k tomu snímek + pár vět od tebe jako pozorovatele).

Pravidla: co jde ladit za běhu (čísla, vzhled), patří do dat, ne do kódu;
na konci LESSONS.md + HANDOFF.md + commit a push.
```

### Blok E — modding (až po A–C)

```text
Pracovní složka: E:\Workspaces\game-clone

Než začneš: přečti DALSI-SESSION.md (sekce E), HANDOFF.md a
ROZHODNUTI-2026-10-09-SMER.md §3 (modifikovatelnost dnes CHYBÍ).

Úkol: navrhni a udělej první krok k "modifikovatelné a rozšiřitelné" hře:
švy, stabilní ID, pořadí načítání, verzované ukládání, sandbox skriptů.
Nejdřív NÁVRH (co je potřeba a v jakém pořadí), pak jeden konkrétní krok.

Hotovo, když: existuje dokument s návrhem A jeden funkční krok s testem
(např. verzované ukládání nebo stabilní ID), ne jen plán.

Pravidla: neměň hotové smlouvy bez zápisu v docs/; na konci LESSONS.md +
HANDOFF.md + commit a push.
```

### Blok F — úklid mrtvých kotev v mutačním harnessu

```text
Pracovní složka: E:\Workspaces\game-clone

Než začneš: přečti DALSI-SESSION.md (sekce F) a tools/gates/mutace-tests.py
(hlavička s pravidly pro ten soubor).

Úkol: spusť `python tools/gates/mutace-tests.py` (celý, trvá desítky minut)
a najdi všechny vzory, které hlásí "PATRANA VETA SE VE ZDROJI NENASLA" —
to jsou mrtvé kotvy: mutace se tiše neprovede a harness ji počítá jako
nechycenou. Dnes se takhle našly tři (dvě z dřívější práce, jedna z mé).

Hotovo, když: běh nehlásí ani jednu "PATRANA VETA" a souhrn je
"N z N chyceno; smlouva vstupu: OK". Každou opravenou kotvu ověř tím, že
mutace je skutečně "PROVEDENA" a "CHYCENA".

Pravidla: nic nemaž bez odůvodnění v komentáři; vzor, který už nemá co měřit,
se odstraní s vysvětlením. Na konci LESSONS.md + HANDOFF.md + commit a push.
```

### Blok „nevím co dál" (když chceš jen pokračovat)

```text
Pracovní složka: E:\Workspaces\game-clone
Přečti HANDOFF.md (stav), DALSI-SESSION.md (co je hotové a co dál) a
ROZHODNUTI-2026-10-10-MODERNI-UO.md (M1–M10). Pak mi řekni, co je podle tebe
nejbližší krok, proč, a co to bude stát — a teprve pak to dělej.
```

---

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
