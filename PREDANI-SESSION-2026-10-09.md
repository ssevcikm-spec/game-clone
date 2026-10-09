# Předání session — 2026-10-09: od „přesná kopie nemá smysl" k prvním granulím `MK`

> **Co je tenhle soubor:** **předávací artefakt pro novou session** (handoff).
> Není to stav projektu — ten je v `E:\Workspaces\game-clone\HANDOFF.md`
> (rolling log, přepisuje se každou session) — a není to zadání; zadání jsou
> tři soubory `ZADANI-21`/`22`/`23` níž.
> **Datum: 2026-10-09.** Session: `session-328f5412-529a-4ff3-b828-e36a6b722b43`
> (276 requestů, cache-hit **99,75 %**, 0 kompakcí, context peak **626 396**).
> **Proč se předává:** ne kvůli tokenům (ty byly zelené), ale kvůli **větvení
> témat** a **nezávislosti pohledu** — pravidla stanice
> (`~/.dsh/AGENTS.md` §„Kdy práce patří do nové session").

## Kde to začalo

Uživatel otevřel **revizi cíle**: „přesná kopie hry nedává smysl… zbavit se
technologických omezení… jediné, co může zůstat, je feel… musí to být
modifikovatelné a rozšiřitelné… mohlo by mě bavit hrát UO like jako idle
sandbox." Z toho vzešla série rozhodnutí (D1–D9), pak doplnění plánu
(milník `MK`) a pak první dvě granule `MK`. Ke konci session přišlo **nové
téma: malý multiplayer + hosting** (uživatel: „server už je nastaven" — telefon).

## Rozhodnutí, která platí (a kde jsou)

| # | Rozhodnutí | Kde to je |
|---|---|---|
| D1 | **Produkt je `game-clone`** (`uo-shadows` = držená opce) | `E:\Workspaces\game-clone\ROZHODNUTI-2026-10-09-SMER.md` §2 D1 |
| D2 | **Cílem je „feel", ne kopie**; V1–V12 = co bereme z reference, ne cíl | tamtéž D2 + `docs\01-cil-a-scope.md` §1.1/§1.2 |
| D3 | **Hra smí provést, co hráč rozhodl — nesmí rozhodnout za něj** | D3 + `docs\01` §1.5 bod 8 + `docs\09` |
| D4 | **Nejbližší cíl = KRÁTKÁ SMYČKA** (`K1`–`K6`) | D4 + `docs\01` §1.3 |
| D5 | **Moderní klient = nový projekt** `E:\Workspaces\godot-uo-client` | D5 + `ZADANI-KLIENT.md` tamtéž |
| D6 | `uo-shadows` = držená opce, jen srovnaný `N9` | D6 + `E:\Workspaces\uo-shadows\docs\GDD.md` |
| D7 | **„Feel" definován** (`F1`–`F5` s tím, jak se ověří); **zobrazení zdraví odložené a vratné** | `docs\01` §1.8 + D7 |
| D8 | **Brány `F1` a `F4` schváleny** a zapsány do smlouvy | `docs\08-brany-a-overovani.md` §8.2 + D8 |
| D9 | **MP: session u hostitele první, `always-on` odložený**; hodiny světa v simulaci, „offline" = bez připojeného klienta | D9 + `NAVRH-BRAN-FEEL-2026-10-09.md` §5–§6 |

## Co je hotové a čím doložené

**Plán:** vznikl milník **`MK`** (krátká smyčka) vložený mezi M4 a M5, 9 granulí,
obchod přesunut z M7 → roadmapa má **118 granulí**, pokrytí vlnami 80/118
(vlny W13/W14). Měřeno `python tools\plan-status.py`.

**Implementace (`MK` = 2/9):**

* `sim/scheduler.gd` — **typovaná vrstva řídkých událostí NAD `core.clock`**
  (ne druhý timer: naměřeno, že `core/clock.gd` timery má, ale nikdo je nevolal).
  Zapojeno do `SimWorld.tick()` před systémy i příkazy; vyřízené události jdou
  do fronty jako `world_event`. Test: `tests/cases/scheduler.gd` (+21 kontrol).
* `sim/save.gd` — mechanika persistence: IO, **verze 2**, migrace 1→2, odmítnutí
  novější verze, **stavové zdroje** (`register_state_source`). Test:
  `tests/cases/save.gd` (+20 kontrol). Fronta plánovače **přežije save/load**.
* **Jedna dokumentovaná změna specu** (schválená uživatelem): `state_hash()`
  zahrnuje stavové zdroje → očekávané hashe replayů **přepnuty s dokladem**:
  `tic_200` `281e7802…` → `451d0a79…`, `tic_1000` `9e6218ab…` → `d1e0db5c…`.
  Doklad: `_analyza/p30-replay-legacy-hash.gd` (starý seznam vstupů dá
  **přesně** původní hashe). Postup zapsán v `tests\replays\README.md`
  („Historie hashů") jako pravidlo pro příště.

**Naměřeno na konci session:** testy **1 507 kontrol / 0 selhání**,
`python tools\gates\run-all.py` → **11 bran OK / 0 chyb**, `plan-status`:
**MK 2/0/7**, celkem **63** měřeně hotových granulí.

**Vedlejší projekty:** `godot-uo-client` založen a ověřen (brána M0 + mutační
self-test 2/2, 5 commitů, bez remote); `uo-shadows` má přeformulovaný `N9`.

## Klíčové soubory pro novou session

* `E:\Workspaces\game-clone\HANDOFF.md` — **stav projektu** (bloky „ROZHODNUTÍ
  O SMĚRU", „MK — první/druhá granule hotová"); čti ho první.
* `E:\Workspaces\game-clone\ROZHODNUTI-2026-10-09-SMER.md` — všechna rozhodnutí
  s cenou a cestou zpět (+ §6 otevřená témata).
* `E:\Workspaces\game-clone\NAVRH-BRAN-FEEL-2026-10-09.md` — spec bran `F1`/`F4`
  (kontroly, mutace) + multiplayer/hosting analýza.
* `E:\Workspaces\game-clone\docs\01-cil-a-scope.md` — cíl, §1.8 „feel" (`F1`–`F5`).
* `E:\Workspaces\game-clone\docs\08-brany-a-overovani.md` — smlouva o branách.
* `E:\Workspaces\game-clone\.forge\roadmap.json` — granule (stav se v něm nevede;
  měří ho `tools\plan-status.py`).
* `E:\Workspaces\game-clone\sim\scheduler.gd`, `sim\save.gd`, `sim\sim_world.gd` —
  co je hotové a jak je to zapojené.
* `C:\Users\Ssevc\Local-Deepseek\OTEVRENA-TEMATA.md` — ledger stanice (témata
  `game-clone`, `godot-uo-client` a telefon/hosting; zápis potřebuje oprávnění).

## Prostředí

- Pracovní složka: `E:\Workspaces\game-clone` (git, `origin/main` = `5959f3b`, ahead 0)
- Godot: `E:\Workspaces\game-clone\.cache\godot\Godot_v4.7.2-stable_win64_console.exe`
  (testy: `$env:APPDATA="$PWD\.cache\godot-appdata"` + `--headless --path . --script res://tests/run_tests.gd`)
- Python: `C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe`
  (`$env:PYTHONIOENCODING='utf-8'`)
- Model v této session: `deepseek-flash` (DSH), sandbox `danger-full-access`
- ⚠ `--headless` testy končí `exit 1` kvůli úklidu (leaked RID) — **čti
  „N kontrol, M selhání"**, ne exit kód (past `dsh-prostredi`).

## Objective to re-arm

- Objective: **žádný `goal` v této session nebyl** (`get_goal()` → `null`).
  Práce se vedla rozhodnutími v `ROZHODNUTI-2026-10-09-SMER.md` a zadáními
  `ZADANI-21`/`22`/`23`. Nová session nemá co re-armovat.

## Background procesy

- **Žádné.** Všech 5 background jobů (`pwsh-7146`, `pwsh-7214`, `pwsh-7350`,
  `pwsh-7354`, `pwsh-7423`) doběhlo; žádný proces neběží, žádný port není
  otevřený. Nová session nemá co uklízet.

## Subagenti

- **Dvě kola nezávislého ověření (read-only), obě dokončená a uvolněná** —
  jejich id jsou v nové session nepoužitelná, ale **výsledky jsou v této session
  a v dokumentech**: 1. kolo našlo 10 vad (4 popisky měření, 5 vad smlouvy
  klienta, 1 rozbitá tabulka) → opraveno; 2. kolo potvrdilo opravy a našlo
  3 další vady (rozbitá tabulka u V2, starší zalomená buňka, prázdná tabulka).
  **Zadání `ZADANI-23` je třetí kolo** na to, co vzniklo po nich.

## Running state

- Repozitáře a commity (vše pushnuté, `ahead 0`):
  - `E:\Workspaces\game-clone` — `5959f3b` (`sim.save`), `77745e6` (scheduler),
    `3930088` (brány F1/F4), `ca105d2` (návrh), `4cd1a72` (feel), `44d20e7` (MK),
    `d6e4f2b`, `43f80f7`, `a422990`, `718bb04`
  - `E:\Workspaces\godot-uo-client` — `5e51fd0`, `a818742`, `2a5598a`, `c529ddc`, `d5a5bb2`; **bez remote**
  - `E:\Workspaces\uo-shadows` — `e4dccdb`, `0a5ee2f` (**nepushnuto**; push by spustil jejich CI)
- Worktrees/větve: žádné nové, vše na `main`.

## Ověření — čím se dá stav potvrdit

```powershell
cd E:\Workspaces\game-clone
$py = 'C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
$env:APPDATA = "$PWD\.cache\godot-appdata"; $env:PYTHONIOENCODING = 'utf-8'

& $py tools\plan-status.py                # → MK 2/0/7, 63 hotových, 118 granulí
& $py tools\gates\run-all.py              # → 11 OK / 0 chyb (exit 0)
& $py tools\check-docs-refs.py            # → OK
& $py tools\check-zadani.py               # → OK
& $py tools\roadmap-gen.py --check        # → DAG konzistentní
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . `
    --script res://tests/run_tests.gd      # → 1507 kontrol, 0 selhání (exit 1 = úklid)
git -C E:\Workspaces\game-clone status --short   # → prázdné
```

## Odložené a otevřené

- **Odloženo (rozhodnutí uživatele):** zobrazení zdraví (health bar) — až po
  sehrání krátké smyčky; `always-on` server — „až na to přijde relevance";
  brána `G14` na rozbité tabulky (návrh v `ROZHODNUTI` §6.7).
- **Otevřené otázky pro uživatele:** kolik hráčů je „malé množství"; zda smí
  `oracle-frankfurt` dělat i herní server (analýza v návrhu §6.1b); co s
  modulem „AI interakce / komplexní robot" (`ROZHODNUTI` §6.5); modifikovatelnost
  (§6.6); zda založit remote pro `godot-uo-client`.
- **NEMĚŘENO:** telefon (Redmi Note 8) — v době mé kontroly byl nedostupný
  a `Host cetnik` v `~/.ssh/config` mířil na **192.168.109.101 = tuto stanici**
  (zastaralé); uživatel hlásí „server už je nastaven", čísla ale nemám.

## Pick up here

Vyber si **jedno ze tří zadání** a začni v **nové session**:

| Session | Zadání | Co udělá |
|---|---|---|
| **A** | `E:\Workspaces\game-clone\ZADANI-21-ENTITNI-STAV-A-OFFLINE.md` | stav entit → `sim.offline` → brána `F1` (dotáhne `MK`) |
| **B** | `E:\Workspaces\game-clone\ZADANI-22-TELEFON-A-HOSTING.md` | změří telefon a rozhodne hosting pro malý MP |
| **C** | `E:\Workspaces\game-clone\ZADANI-23-OVERENI-MK.md` | nezávisle (read-only) ověří, co vzniklo po 2. kole ověření |

Když nechceš nic z toho: **pokračovat v této session je bezpečné** (626k z 800k,
cache 99,75 %), jen si krok ponese historii, která se k němu neváže.
