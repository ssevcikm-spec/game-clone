# ZADÁNÍ 24 — automatizace: politika, vykonavatel, log rozhodnutí (`sim.policy`, `sim.executor`, `sim.decision_log`)

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalO) — nepřepisuje
> se. Vzniklo 2026-10-09 navazující na rozhodnutí `D3` (`ROZHODNUTI-2026-10-09-SMER.md`:
> „hra smí provést, co hráč rozhodl — nesmí rozhodnout za něj").
> **Stav projektu je v `HANDOFF.md`**, pocit v `docs/01` §1.8, plán v `docs/07`.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

## 1. Cíl — tři granule, které zavírají `K6` krátké smyčky

Dnes platí: **svět jde dál i bez hráče** (`sim.offline`, brána `F1` zelená).
Cílem je, aby **postava jednala i bez klikání** — a aby bylo vidět **proč**.

| Granule | Soubor | `provides` (ze smlouvy) | Hotovo, když |
|---|---|---|---|
| `sim.policy` | `sim/policy.gd` | `load(json)`, `evaluate(state) -> [rozhodnuti]`, `priority_of(rule)` | pravidla s podmínkami a prioritami jsou **data**, vyhodnocení je deterministické a vrací seřazená rozhodnutí |
| `sim.executor` | `sim/executor.gd` | `step(state) -> [Command]`, `status()` | rozhodnutí se mění na `Command`; vykonavatel **nikdy nesahá na stav** a umí se zastavit s důvodem |
| `sim.decision_log` | `sim/decision_log.gd` | `decision(rule_id, why, state_ref)`, `skipped(rule_id, why)`, `since(tick)` | je vidět **důvod**: které pravidlo se vyhodnotilo, které ne a proč |

**Tři vrstvy podle `D3` (to je jádro, ne detail):** **úmysl** zadává hráč
(např. „500 ingotů"), **politika** jsou pravidla s podmínkami a prioritami
(„když dojde krumpáč, kup nový"), **provedení** dělá simulace. Hra **nesmí
rozhodnout za hráče** (`docs/01` §1.5 bod 8).

## 2. Naměřená fakta (stav před session, neopakuj měření)

* `MK` **3/0/6** — hotové `sim.scheduler`, `sim.save`, `sim.offline`;
  zbývá **tenhle trojlístek + obchod** (`data.vendors`, `sim.vendor`, `ui.vendor_gump`).
* Brány: **12 měřeno / 0 chyb** (`run-all.py`), testy **1 551 kontrol / 0 selhání**,
  celkem **64** měřeně hotových granul z 118. HEAD ověř před prací sám.
* `sim/scheduler.gd` je **hotový**: `schedule(kind, at_ms, payload)`,
  `schedule_in`, `cancel`, `advance_to(now)`, `pending()`, `state()`/`restore()`.
  `SimWorld` ho tickuje **před** systémy a příkazy; vyřízené události jdou do
  fronty jako `world_event`. **Politika s ním smí mluvit** (např. „zkus to za 2 s").
* `sim/save.gd` umí **stavové zdroje**: `SimWorld.register_state_source(name, source)`
  (zdroj musí mít `state()`/`restore()`). Když bude mít politika stav, **patří
  tam** — a **pozor**: `state_hash()` už stavové zdroje zahrnuje, takže přidání
  zdroje **mění hashe replayů**; postup je v `tests/replays/README.md`
  („Historie hashů") a **bez dokladu se replaye nepřepínají**.
* `sim/` nesmí číst `Input`, `Time`, `OS`, `randf()`, `randi()` (brána **G2**).
  Čas i náhoda jdou **argumentem** nebo z `sim.clock()`/`sim.rng()`.
* Vrstvy (brána **G2**): `sim/` nesmí volat `ui/`, `render/`, `app/`.

## 3. Rozhodnutí, které zadání NECHÁVÁ na tobě (a moje doporučení)

**Jak hluboké mají podmínky být?** (`ROZHODNUTI` §6.2 to vede jako otevřené.)
* **Doporučení: začni DATY, ne jazykem.** Podmínka = `{"kind": "...", "args": {...}}`
  s **pevným slovníkem**, priorita = číslo, akce = `{"kind": "...", ...}`.
  Richer forma (vnořené `and`/`or`, výrazy) je **aditivní** rozšíření, které se
  dá přidat, když na to bude konkrétní potřeba — a je to **vratné** rozhodnutí
  (`AGENTS.md`: vratné a levné rozhodni sám a zapiš to).
* **Když narazíš na potřebu jazyka**, neimplementuj ho: přines důkaz (které
  pravidlo se nedá zapsat daty) a zeptej se — je to rozhodnutí uživatele.

## 4. Required výstup

1. Tři moduly podle §1 + **nové case soubory** v `tests/cases/`
   (`policy.gd`, `executor.gd`, `decision_log.gd`; **existující testy se nemění** —
   `docs/09` §9.5).
2. **Zapojení**: vykonavatel musí být **dosažitelný z produkce**, ne mrtvý kód.
   Nejbližší poctivá cesta: `SimWorld` (nebo `app/main.gd`) **tickuje vykonavatele
   jen když je politika načtená** (bez politiky = no-op) a vyrobené `Command`
   vkládá **do stejné fronty** jako hráč — s označením, aby se v žurnálu dalo
   rozlišit, co přišlo od hráče a co od politiky.
3. **Determinismus**: stejný stav + stejná politika = stejná rozhodnutí; žádné
   `randf()`. Replay (G9) musí zůstat zelený — nebo se přepne **s dokladem** (§2).
4. **Log rozhodnutí** zapisuje **důvod**, ne jen akci („nemám materiál",
   „cesta blokovaná", „priorita níž"); zobrazuje ho `ui.journal` (**tu needituj**).
5. Zelené: `run-all.py` (12+ bran), testy, `plan-status.py` (**MK 6/9**),
   dokumentové brány; aktualizovaný `HANDOFF.md`; commit + push.

## 5. Co NEDĚLAT

* **Nevkládat LLM do běhu hry.** „AI interakce / komplexní robot" je **námět
  k rozhodnutí** (`ROZHODNUTI` §6.5, dvě varianty: LLM jako *autor politiky*
  vs. LLM *v běhu*) — tenhle trojlístek je deterministická mechanika bez modelu.
* **Nepřidávat nové závislosti** (`docs/01` §1.5 bod 5).
* **Neměnit `state_hash()` ani replaye bez dokladu** (§2).
* **Neimplementovat obchod** — to je samostatná trojice granulí
  (`data.vendors`, `sim.vendor`, `ui.vendor_gump`), další session.
* **Nesahat na `godot-uo-client`** ani na `uo-shadows`.
* **Nepředstírat hotovo zelenými testy:** hotovo = soubor v gitu **A** brána
  zavolala jeho funkci **A** kritérium proběhlo s konkrétní hodnotou.

## 6. Jak to ověřit

```powershell
cd E:\Workspaces\game-clone
$py = 'C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
$env:PYTHONIOENCODING = 'utf-8'; $env:APPDATA = "$PWD\.cache\godot-appdata"

& $py tools\gates\run-all.py          # 12+ bran, 0 chyb
& $py tools\plan-status.py            # MK 6/9
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . `
    --script res://tests/run_tests.gd # N kontrol, 0 selhání (exit 1 = úklid)
```

## 7. Pick up here

**Začni `sim.policy`** — je to jediná z trojice, která se dá ověřit úplně sama
(vstupy: stav světa + data pravidel → seřazená rozhodnutí; výstup: žádné
`Command`). Testy piš na **pořadí podle priority**, na **nesplněnou podmínku**
a na to, že **stejný vstup dá stejný výstup**. Teprve pak `sim.executor`
(rozhodnutí → `Command`) a `sim.decision_log` (proč).
