# Nálezy z pohledu na hru — dvě vady, které testy nevidí (2026-10-07)

> **Co je tenhle soubor:** **analytický záznam** (revize) — co je na hře vidět
> špatně, čím je to naměřené a co z toho plyne pro plán. **Není to zadání ani
> stav** (stav je `HANDOFF.md`, zadání `ZADANI-DALSI-VYVOJ-2.md`).
> **Nepřepisuje se** — co se z něj provede, patří do `HANDOFF.md`.
> **Datum vzniku:** 2026-10-07 (5. session), **na základě snímků od uživatele**.
> **Datum spotřeby:** zatím žádné — nic z toho se ještě neprovádělo.
> **Stav:** **NEMÁ SE OPRAVOVAT TEĎ** (rozhodnutí uživatele: „je to jen poznámka
> až na to bude čas a až to bude relevantní").

---

## 0. Proč to není v bránách

Brány jsou zelené (**G1–G11, 11/0/0**), testy **520/0** — a přesto je na snímku
vidět, že hra kreslí špatně. Je to stejná past jako u „postava je 40 px nad
středem" (2. session): **měřené kontroly se ptaly na jinou věc, než co je vidět**.
Proto se obojí zapisuje sem a doplňuje se **vizuální kontrola** jako budoucí brána
(G10 dnes měří barvu postavy, ne úplnost land artu).

**Snímky, ze kterých to je** (od uživatele, 2026-10-07):
- `sha256 a715b5b0…` — postava a **stopa animačních framů** na ulici (vada A),
- `sha256 fb866716…` — **šedá plocha** v místě změny výšky, plochý břeh (vada B).

*(Snímky nejsou v repu — jsou to attachmenty session. Kdo je bude potřebovat,
ať si je vyžádá; reprodukce je popsaná měřením níže.)*

---

## Vada A — při pohybu je krátce vidět „stopa" animačních framů

**Co je vidět:** na ulici stojí postava a za ní (i před ní) je **vidět několik
postav v různých fázích animace chůze** — jako by se vykreslily všechny framy
najednou. Po chvíli zmizí.

**Co NENÍ příčina (naměřeno, ať se to nehledá znovu):**
- **Animace v čase se mění správně** — sonda `sonda-vady2.gd`:
  `0->f0 40->f0 80->f1 120->f1 160->f2 240->f3 320->f4 400->f5 480->f6`,
  a při změně klíče se stav resetuje (`0->f0 80->f1 160->f2`).
  Pozor na past, která mě u toho chytila: `play(1, …)` **není** tělo 1 —
  serial 1 není v registru, takže `body_of(1)` vrátí `-1` a `play` vrátí
  `{ok:false}`. Měřit se musí se serialem, který je v registru (nebo s tělem).
- Chůze má **10 framů** na směr (0–7) a `frame_ms = 80` (`Const.TURN_MS`);
  `chunk.visible(...)` vrací seznam jen jednou za krok, ne za frame.

**Kde hledat dál (hypotézy k ověření, ne závěry):**
1. `app/world_view.gd:_draw_player()` — kreslí se postava **uvnitř smyčky** přes
   objekty a při `mirror` se mění transformace (`draw_set_transform`). Ověřit,
   že se transformace vždy vrátí zpět i při `continue`/`return` (test na to není).
2. `app/player_controller.gd` — kolik `queue_redraw()` na krok a zda se
   `set_action()` nepřepíná walk/idle tak, že vznikne mezistav.
3. Zda není na vině **animace jako taková** (10 framů na jeden krok 400 ms =
   frame každých 80 ms): krok je 400 ms, takže animace **proběhne celá** — což je
   správně, ale znamená to, že „stopa" může být jen **nedokreslený předchozí
   frame** (double buffer / čistění plátna).

**Jak to ověřit příště (měřitelně):** vykreslit **dva po sobě jdoucí framy** do
PNG (`--write-movie`) a porovnat je: kolik pixelů mimo pozadí se změnilo a zda
je mezi nimi postava **jednou**, nebo víckrát. Dnes to změřené není.

---

## Vada B — šedá plocha v místě změny výšky a plochý břeh (PŘÍČINA NALEZENA)

**Co je vidět:** na přechodu výšky je místo dlažby/trávy **šedé pozadí** (díra)
a břeh u vody je **plochý**.

**Naměřená příčina (tvrdé číslo, ne dohad):** `world.map` vydává **land tile id
z mapy** (`map0.land`), ale atlas i `render.textures` pracují s **art id z pole
`texture` v tiledata**. U dlaždic, kde se ta dvě čísla liší, se hledá art, který
v atlase není → `texture()` vrátí `null` → `_draw()` udělá `continue` → **díra**
(místo ní je vidět šedé pozadí).

Naměřeno sondou `.cache/analysis/sonda-vady.gd` v okolí `(1519, 1657)`:

| Co | Hodnota |
|---|---|
| největší skok `z` na sousedy v okolí | **40** (`(1519,1657)`: `z 25` → `z -15`) |
| histogram `z` v okolí skoku | `{20: 80, -15: 81, 16: 2, 18: 2, 17: 1, 19: 1, 25: 1, 23: 1}` |
| land arty v atlase **CHYBÍ** | `{83: 12, 95: 12, 100: 53, 84: 1, 88: 1, 96: 1}` |
| řádek přes přechod | `x1518:land6/z19/OK x1519:land35/z25/OK x1520:land83/z-15/CHYBI x1521:land95/z-15/CHYBI x1522:land100/z-15/CHYBI` |

A v datech (`assets/uo/tiles.json`, `layout.land_fields = ["flags","texture","name"]`):

| land id | jméno | `texture` |
|---|---|---|
| 83 | NoName | **76** |
| 95 | NoName | **76** |
| 100 | NoName | **76** |
| 1003 | cobblestones | 1003 |
| 1022 | dirt | 1022 |
| 6 | grass | 6 |

**Atlas má 3 732 land artů z 16 384**, chybí **12 652** — a chybí právě ty, které
potřebují překlad (`texture != id`). `tools/uoextract/atlas.py:rozsah()` staví
seznam z pole `texture`, takže **atlas je konzistentní s tiledata**; chyba je na
straně kreslení (`render/chunk` bere land id jako art id).

**Druhá část vady (plochý břeh) má stejného viníka:** `world.walk` a kreslení
používají `z` z mapy, ale sousední dlaždice se liší o **40 jednotek** — krajina
je schodovitá a **mezi výškami se nekreslí nic** (žádná stěna svahu). To je vidět
jako plochý přechod. Patří to k `render.chunk` (budoucí `render.chunk_mesh`, M9).

**Co z toho plyne pro plán (návrh, nerozhodnuto):**
1. **Překlad land tile id → art id** musí být na jednom místě (tiledata), ne
   v kreslení. Dnes `sim/world/tiledata.gd` umí `flags/height/layer/weight/name`,
   ale **ne `texture`** — to je ta chybějící znalost.
2. **Chybějící art nesmí být ticho.** `texture()` vrací `null` a kreslení udělá
   `continue`; místo toho má být vidět **magenta/šrafovaná dlaždice** (jako
   v jiných enginech), aby vada byla vidět při prvním pohledu.
3. **Vizuální brána na úplnost mapy**: pro N dlaždic v okně hry ověřit, že
   `texture(land_art_id)` není `null` (dnes to neměří nikdo).

---

## Co je potřeba ověřit, než se to začne opravovat

1. **Vada A** — není dořešená (viz „Jak to ověřit příště"): dvěma framy dokázat,
   zda jde o stopu, nebo o nedokreslení.
2. **Vada B** — příčina je nalezená, ale **není ověřený důsledek opravy**:
   kolik dlaždic v Británii je „CHYBI" (odhad z okna: 6 různých artů na 80
   dlaždicích). Až se to opraví, musí to být vidět **na snímku**, ne jen v testu.
3. **Zda `texture` v tiledata stačí** — u některých land id může být `texture`
   taky mimo atlas (pak je to díra v atlase, ne v překladu). To se musí změřit
   přes celou mapu, ne na jednom okně.
