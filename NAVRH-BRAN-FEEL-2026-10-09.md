# Návrh bran z pocitu (`F1`, `F4`) + co s tím dělá multiplayer a hosting

> **Co je tenhle soubor:** **NÁVRH — SCHVÁLENO 2026-10-09.** Uživatel schválil
> brány `F1` a `F4` **pod označením `F1` a `F4`** (ne `G14`/`G15`); jsou
> **zapsané v `docs/08` §8.2** a **čekají na implementaci** — do milníku `MK`
> vrací `2` (NEMĚŘENO), protože `sim.offline` a obchod ještě neexistují.
> **Datum spotřeby: 2026-10-09** — z §2 a §3 se provedlo **zapsání do smlouvy**;
> samotné brány jsou před námi (spolu s granulemi `MK`). **§5 (multiplayer)
> a §6 (hosting) jsou analýza a doporučení, ne provedená práce.**
> **Co je v něm měřené:** uzly a zdroje v §6 (naměřeno 2026-10-09 na této
> stanici). **Co je odhad:** ceny práce u bran (`[O]`).
> **Současný stav projektu** je v `HANDOFF.md`; **cíl a pocit** v `docs/01`.

---

## 1. Proč právě tyhle dvě brány

Z pěti poznatků (`F1`–`F5`, `docs/01` §1.8) jsou **dva přímo měřitelné na datech
a na simulaci**, bez ohledu na vzhled:

| Poznatek | Proč je bránovatelný |
|---|---|
| **`F1` — svět jde dál, i když se nedívám** | je to **chování v čase**: dá se spustit headless, bez hráče, a změřit, co se změnilo a jestli je to reprodukovatelné |
| **`F4` — nic není odpad** | je to **vlastnost dat**: u každého výstupu se dá spočítat, jestli má konzumenta |

Zbylé tři (`F2` dosažitelnost bez levelů, `F3` moc z přípravy, `F5` paměť světa)
mají taky měřitelné jádro, ale **ne v tuhle chvíli**: `F2` a `F3` potřebují
obsah a souboj (`M5`), `F5` potřebuje `sim.save` (MK). Navrhnout je teď by
znamenalo navrhnout bránu na něco, co ještě neexistuje — a to je přesně
„brána, která čeká na vstup, jenž nikdy nepřijde".

---

## 2. Brána `F1` — „svět má vlastní čas"

**Soubor:** `tools/gates/check-world-clock.py` (`[O]` ~150 řádků).
**Co měří** (vše headless, **nula příkazů od hráče**):

| # | Kontrola | Jak | Co je „v pořádku" |
|---|---|---|---|
| 1 | **Svět se hýbe bez hráče** | spusť simulaci na `N` světových hodin s prázdnou frontou příkazů | hash stavu na konci **≠** hash na začátku |
| 2 | **Je to reprodukovatelné** | tytéž vstupy a týž seed dvakrát | **stejný hash** v obou bězích (jinak padá replay i predikce) |
| 3 | **Není to simulace agentů** | spočítej entity, které za `N` hodin opravdu tikly | zůstanou **v rozpočtu** (řádově stovky, ne desítky tisíc) — jinak svět mimo obrazovku „tiká všechno" a je to drahé i nereprodukovatelné |
| 4 | **Doběh je idempotentní** | `advance_to(T)`, pak `advance_to(T)` znovu | druhý krok **nic nezmění** (jinak se čas počítá dvakrát) |
| 5 | **Rychlost nezáleží na způsobu** | `advance_to(T)` najednou vs. po dávkách (např. po hodinách) | **stejný hash** (jinak je svět závislý na tom, jak často se ukládal) |

**Mutace (každá musí bránu shodit):**
`M1` vypni doběh (udělej z `advance_to` prázdnou funkci) → kontrola 1 spadne ·
`M2` přidej do doběhu `randf()` → kontrola 2 spadne ·
`M3` tikni v doběhu všechny entity světa → kontrola 3 spadne ·
`M4` nech čas přičíst dvakrát → kontrola 4 spadne ·
`M5` počítej doběh po dávkách jinak než najednou → kontrola 5 spadne.

**Tři stavy:** `0` měřeno OK · `1` vada · `2` **NEMĚŘENO** (`sim.offline`
neexistuje) — a `2` se **nesmí** tvářit jako zelená (`run-all.py` to tak už umí).
**Kde běží:** `tools/gates/`, do `run-all.py` mezi G8 (determinismus) a G9
(replay). **Bez assetů:** na fixture mapě (`tests/fixtures/world/`), jinak by
v CI hlásila NEMĚŘENO (přesně ta past, kterou projekt řešil u R11).
**Závislost:** granule `sim.offline`, `sim.scheduler`, `sim.save` (MK).
**Do té doby:** brána existuje a vrací `2`. **Není to zelená.**

---

## 3. Brána `F4` — „nic není odpad"

**Soubor:** `tools/gates/check-no-waste.py` (`[O]` ~180 řádků).
**Co měří:** vezme **množinu věcí dosažitelných ve hře** (uzávěr z startovní
výbavy a profesí přes recepty a obchod — spočítaný, ne vypsaný ručně) a pro
každý **výstup** (co jde vyrobit/těžit) hledá **konzumenta**. Konzument je
kterákoli z těchto tří věcí:

1. **recept** (vstup dalšího výrobku),
2. **poptávka světa** (vendor, jehož zboží/skupina to kupuje),
3. **propad** (decay, spotřeba NPC/časem — tedy i „to se prostě ztratí").

**Co NEMĚŘÍ:** celý katalog 8 748 předmětů. Měří **dosažitelnou množinu** —
jinak by brána chtěla konzumenta pro předměty, které ve hře nikdy nepotkáš.
**Kontroly:**

| # | Kontrola | Co je „v pořádku" |
|---|---|---|
| 1 | **Uzávěr není prázdný** | dosažitelných věcí je **> 0** (jinak by zelená znamenala „neměřil jsem nic") |
| 2 | **Každý výstup má konzumenta** | **0 výstupů bez konzumenta** — a výstup vypíše, které to jsou |
| 3 | **Konzument je doložený** | u každého výstupu je **odkaz na recept/vendorovu skupinu/propad**, ne jen „true" |
| 4 | **Nic nevisí na neexistujícím** | každý odkaz vede na existující záznam (jinak je to falešný konzument) |

**Mutace:** `M1` přidej výrobek bez konzumenta → kontrola 2 spadne ·
`M2` nech uzávěr prázdný → kontrola 1 spadne (a **nesmí** to být zelená) ·
`M3` uveď konzumenta na neexistující id → kontrola 4 spadne.
**Tři stavy:** `2` dokud není `data.vendors` + simulovaná poptávka (MK).
**Kde běží:** `tools/gates/check-content.py` (G5) **nerozšiřovat** — G5 měří
něco jiného (počty a tvary); `F4` je samostatná brána vedle.

---

## 4. Co se změní, když to schválíš

| Co | Změna |
|---|---|
| `docs/08-brany-a-overovani.md` | přibudou dvě brány (`G14`/`G15` nebo `F1`/`F4` — pojmenování je na tobě); tabulka bran 13 → 15 |
| `tools/gates/` | dva nové soubory + zápis do `run-all.py` (pořadí: po determinismu a replayi) |
| `docs/01` §1.8 | u `F1`/`F4` zmizí „kandidát" a bude „brána" |
| **Co se NEZMĚNÍ** | nic v `sim/`, `render/`, roadmapě ani v datech — brány jen měří |

**Pozor na jednu věc, kterou je fér říct předem:** obě brány budou **několik
týdnů vracet `2` (neměřeno)**, protože `sim.offline` a `data.vendors` ještě
neexistují. To je v tomhle projektu povolený stav (`G13` je taky neimplementovaná
a poradní), ale musí být **vidět** — jinak vznikne „zelená nad prázdnem".

---

## 5. Multiplayer — ano, ale je to **jiný režim světa**, ne jiná funkce

**Odpověď na otázku „počítáme s možným multiplayerem?"** — Ano, a projekt to má
naměřené už z 7. 10. (`REVIZE-SMER-2026-10-07.md` §1.4): rozhraní klient/server
je hotové a **vynucené branou** (`tools/gates/check-layers.py`) — `sim/` je jediná
autorita, klient posílá jen `Command` a **nikdy polohu**, tik je pevný
a deterministický. Malý multiplayer je proto **aditivní**, ne přepis:

| Co už je hotové | Co pro MP chybí (`[O]`, `REVIZE-SMER` §1.4) |
|---|---|
| deterministický tik, hash stavu, replaye | serializace `Command`/`Event` na drát |
| autorita v `sim/`, klient posílá záměr | streamování snapshotů + zájem o okolí (interest management) |
| vrstvy a brány (klient nesahá na stav) | predikce klienta + snap-back po odmítnutí |
| ukládání s verzí dat | souběh více postav v jednom světě (a jeho perzistence) |

### 5.1 Co s tím dělá `F1` (a proto to patří do tohohle návrhu)

**`F1` je podmíněná režimem světa:**

| Režim | Jak vypadá „svět má vlastní čas" |
|---|---|
| **Singleplayer** | simulace běží lokálně; „offline" = **hráč není připojený**, ale proces běží dál (nebo se doběhne při startu) |
| **Host-authoritative session** (2–8 hráčů) | svět běží **jen dokud běží hostitel**; „offline" = svět je pozastavený (jako Minecraft/Valheim) |
| **Always-on server** | svět běží 24/7 na serveru; „offline" = hráč se odpojil, svět jede dál |

**Z toho plyne jedno pravidlo, které je potřeba dodržet už teď (je zdarma):**
**hodiny světa bydlí v simulaci, ne v klientovi, a „offline" znamená „bez
připojeného klienta", ne „bez hráče".** Když to takhle postavíme, jsou všechny
tři režimy **tentýž kód** a rozhodnutí o multiplayeru se dá udělat později.
Kdyby `sim.offline` znamenalo „hráč vypnul hru", MP by to muselo přepisovat.

### 5.2 Co MP mění na pocitu (a co ne)

`F1`, `F3`, `F4` platí ve všech režimech. **Mění se `F5` a lhostejnost světa:**
ve sdíleném světě už „co jsem udělal, zůstává" platí pro **všechny**, a ceny
reagují na **všechny** hráče — což je vlastně *silnější* verze téhož pocitu
(svět si žije, i když v něm nejsem sám). Naopak **`F2` (žádné levely) je
v MP důležitější**, protože bez levelů se hráči navzájem posuzují podle toho,
co vidí — ne podle čísla.

---

## 6. Hosting — co reálně máme (naměřeno 2026-10-09)

**Než se vybere hosting, musí padnout rozhodnutí z §5.1** — protože jinak se
hostuje něco, co ještě nemá tvar. Naměřené zdroje:

| Zdroj | Co to je (měřeno) | Hodí se na co | Riziko |
|---|---|---|---|
| **`oracle-frankfurt`** | **Oracle Cloud ARM** (`linux arm64 6.17.0-1020-oracle`), **živý** uzel orchestra; má Godot 4.7.2, Python 3.12.3, Node 18.19.1, git 2.43.0; kinds `test,build` | **always-on server** (veřejná IP, 24/7) | **Už dělá CI orchestra** — build/test špička a herní tik si polezou po CPU (náš rozpočet je ≤ 2 ms/tik). ARM64 znamená ověřit headless Godot export pro ARM. Provoz (systemd, zálohy, restarty) je na nás |
| **`cetnik`** = **Xiaomi Redmi Note 8** (`192.168.109.101:8022`, root, Termux + Ubuntu proot + PM2, běží na něm Telegram bot) | **domácí server na telefonu**, dosažitelný SSH z této stanice | **LAN hraní** a záloha; případně malý svět pro pár lidí přes VPN | Android **zabíjí procesy**, baterie/teplo, domácí upload, dynamická IP za NAT (nutné VPN/průchod). Jako *veřejný* server to nedoporučuju |
| **`pc-domaci`** | domácí PC jako uzel orchestra — **často offline** (naměřeno 57,6 h) | **host-authoritative session** (hostitel stejně hraje) | Jen když je zapnuté — což je pro tenhle režim **vlastnost, ne vada** |

### 6.1 Doporučená posloupnost (a proč)

1. **Teď nic nehostovat.** Není co hostovat; a rozhodnutí, které by se teď
   udělalo, by se dělalo naslepo. Co je potřeba teď: dodržet pravidlo z §5.1.
2. **První multiplayer = host-authoritative session** (hostitel hraje a obsluhuje,
   přátelé se připojí). **Cena: nula** (žádný pronájem, žádná údržba), žádný
   veřejný port (VPN/Tailscale), a svět se chová přesně jako v SP.
3. **Always-on svět až potom** — a tehdy je `oracle-frankfurt` nejlepší kandidát,
   ale **oddělený od CI**: vlastní `systemd` jednotka, CPU kvóta (nebo druhý
   stroj/instance), a **měření**, že tik drží rozpočet i při běžícím buildu.
   Kdyby to nevyšlo: domácí PC (když běží) nebo telefon pro LAN.

### 6.1b „Co to ovlivní?" — co se platí za sdílení uzlu s CI

Uživatel se 2026-10-09 ptal, co vlastně sdílení uzlu ovlivní, a vyslovil
podezření, že Oracle uzel má zdrojů dost. **Podezření je pravděpodobně správné
u kapacity, ale nesdílení není o kapacitě** — platí se za čtyři jiné věci:

| Co | Proč to je problém | Jak se to dá řešit |
|---|---|---|
| **1. Latence z vytížení CPU** | uzel je **CI worker** (kinds `test,build`) — tedy přesně těžké úlohy (Godot import/export, testy). Náš rozpočet je **tik ≤ 2 ms v 50 ms slotu**; když ho build vyhladoví, hráči vidí poskakování | `systemd` jednotka s `CPUQuota`, `Nice`, nebo omezit souběh runneru na 1; **a změřit** tik při běžícím buildu |
| **2. Bezpečnostní dosah** | self-hosted runner **spouští kód z repa a drží tokeny**; veřejně poslouchající herní port je **nová útočná plocha na témže stroji** — kdo ji prolomí, je vedle CI tajemství | vlastní uživatel bez přístupu k pracovnímu stromu runneru, firewall, hardening; **nejlépe druhý stroj/instance** (free tier ARM obvykle dovolí dva) |
| **3. Sdílený osud** | OOM nebo restart kvůli CI shodí svět uprostřed hraní; a naopak | oddělené jednotky + limity; zálohy světa (save) mimo stroj |
| **4. Provoz** | updates, restarty, zálohy, monitoring — **někdo to musí dělat**, i když je to zdarma penězi | až ve chvíli, kdy je always-on opravdu potřeba (§6.1 bod 3) |

**Co to naopak neovlivní:** peníze (free tier malý server unese), síť (veřejná IP
je), paměť (server posílá jen stav, art zůstává na klientech) a výkon herní
smyčky samotné — ta je lehká (naměřeno v UO: v aktivním okně kolem 37 NPC).

**Oprava jednoho předpokladu (naměřeno):** na Oracle uzlu **neběží conductor** —
conductor je Cloudflare Worker (`conductor/wrangler.toml`, `*.workers.dev`).
Oracle uzel je **výpočetní uzel orchestra** (self-hosted runner pro `test`
a `build`). To je pro rozhodnutí důležité: neběží tam „řídicí smyčka", ale
**těžké úlohy**.

**Co k tomu chybí, aby to bylo rozhodnutí a ne dohad:** (a) reálná kapacita uzlu
(`nproc`, RAM, load average, disk) a (b) **tik při běžícím buildu**. První jde
změřit hned (na stanici je `~/.ssh/oracle_node.key`, ale chybí záznam
o hostiteli — viz otázka níž); druhé až s implementovaným `sim.offline`.

### 6.2 Právní poznámka, která se týká právě hostingu

Server **nesmí šířit art** z instalace UO (`docs/03` §3.1) — a nemusí: **art
zůstává na klientech** (každý si ho vygeneruje z vlastní instalace), server
posílá jen **stav světa**. Pro soukromý server pro pár lidí je to stejný model
jako u libovolného UO shardu. Rozdělení je ale potřeba dodržet **v datech**:
`atlas/`, `anim/`, `gump-preview/` = klient; `world/map0.*`, `data/*.json`,
`tiles.json`, `hues.json` = server i klient.

---

## 7. Co tím chci od tebe rozhodnout

1. **Schvaluješ brány `F1` a `F4`** do `docs/08` (a pod jakým označením —
   `G14`/`G15`, nebo `F1`/`F4`)?
2. **Jaký multiplayer chceš** — host-authoritative session (§6.1 bod 2), nebo
   always-on svět na Oracle uzlu (§6.1 bod 3)? (Od toho se odvíjí, jestli se
   hosting řeší teď, nebo až po MK.)
3. **Smí se `oracle-frankfurt` použít i pro hru**, nebo má zůstat jen CI?
   (Já bych ho pro hru **nesdílel** bez měření — viz tabulka.)
4. **Kolik hráčů** je „malé množství" (2–4, nebo 6–8)? Změní to rozpočet na
   snapshoty a zájem o okolí.
