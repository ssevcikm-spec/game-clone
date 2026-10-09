# ZADÁNÍ 21 — stav entit → `sim.offline` → brána `F1` (dotáhnout milník `MK`)

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalO) — nepřepisuje
> se. Vzniklo 2026-10-09 z rozhodnutí uživatele (`ROZHODNUTI-2026-10-09-SMER.md`
> §2 D4, D8, D9). **Současný stav projektu je v `HANDOFF.md`**, cíl a pocit
> v `docs/01-cil-a-scope.md`, smlouva o branách v `docs/08-brany-a-overovani.md`.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

## 1. Cíl (tři kroky, v tomto pořadí)

1. **Entity se stanou stavovým zdrojem.** `sim/entity/mobile.gd` a
   `sim/entity/registry.gd` dostanou `state()`/`restore(d)` a `SimWorld` je
   zaregistruje přes `register_state_source(...)`. Tím se **mobily a předměty
   poprvé opravdu ukládají** a jsou v `state_hash()`.
2. **`sim/offline`** — svět jde dál i bez hráče: `advance_to(now_unix)`,
   `elapsed_report()`. **Mimo obrazovku je svět FUNKCE ČASU, ne simulace
   agentů** (rozvrhy, doplnění spawnu, ceny), se stropy (`maxCount`, denní strop).
3. **Brána `F1`** (`tools/gates/check-world-clock.py`) podle
   `NAVRH-BRAN-FEEL-2026-10-09.md` §2: **5 kontrol** (svět se hýbe bez hráče;
   dvakrát totéž dá totéž; netiká celý svět; doběh je idempotentní; rychlost
   nezávisí na dávkování) + **5 mutací** + zápis do `tools/gates/run-all.py`.

## 2. Naměřená fakta (neopakuj měření, navazuj)

* `tools/plan-status.py` → **MK 2/0/7** (hotové `sim.scheduler`, `sim.save`),
  celkem **63** hotových z **118** granulí; `run-all.py` → **11 bran OK / 0 chyb**;
  testy **1 507 kontrol / 0 selhání**; HEAD `5959f3b`, `origin/main` = HEAD.
* `sim/save.gd` **už existuje** (IO, verze 2, migrace 1→2, `collect`/`apply`);
  `SimWorld.register_state_source(name, source)` funguje a **plánovač je první
  zdroj**. Save proto nese `sources`, ale `mobiles`/`items` jsou v obálce
  **stále prázdné** — to je přesně to, co má krok 1 změnit.
* `entity.mobile` a `entity.registry` **nemají `state()`/`restore()`** (ověř
  sám; jsou to soubory `sim/entity/mobile.gd`, `sim/entity/registry.gd`).
* **Změna hashe je citlivá:** `state_hash()` od 2026-10-09 zahrnuje stavové
  zdroje a **očekávané hashe replayů byly přepnuty s dokladem**. Postup, jak
  to dělat příště, je v `tests/replays/README.md` (sekce „Historie hashů"):
  **bez dokladu („starý hash sedí") se replaye nepřepínají.**
* `sim/offline` **nesmí číst hodiny sám** — čas dostane argumentem
  (`now_unix`), protože `sim/` nesmí sahat na `Time`/`OS`/`Input`/`randf()`
  (brána G2 to vynucuje).
* Past, která je v zadání i v `REVIZE-SMER-2026-10-07.md` §2.5: **aktivace
  podle sektorů kolem hráče bez hráče nefunguje** — proto doběh jako funkce času.
* `docs/01` §1.6 žádá **simulaci ≤ 2 ms/tick**; UO mělo v aktivním okně
  řádově 37 tikajících NPC (naměřeno v `REVIZE-SMER` §2.1b).

## 3. Required výstup

1. Kód: `sim/entity/mobile.gd`, `sim/entity/registry.gd`, `sim/sim_world.gd`
   (registrace zdrojů), `sim/offline.gd`.
2. Testy v `tests/cases/` (nové case soubory pro entitní round-trip a pro
   `sim.offline`; **existující testy se nemění** — `docs/09` §9.5).
3. Brána `tools/gates/check-world-clock.py` **se všemi 5 kontrolami a 5
   mutacemi**; zápis do `run-all.py`; do té doby vrací **`2` (NEMĚŘENO)**, což
   se nesmí tvářit jako zelená. **Brána musí běžet bez `assets/uo`** (fixture
   mapa `tests/fixtures/world/`), jinak by v CI hlásila NEMĚŘENO.
4. Zelené: `run-all.py` (11 + `F1`), `plan-status.py` (**MK 3–5/9**), testy,
   dokumentové brány; a **aktualizovaný `HANDOFF.md`** + commit + push.

## 4. Co NEDĚLAT

* **Nezavádět timer wheel** z ModernUO — `sim.scheduler` je hotový a wheel
  nemá co měřit (řádově stovky událostí). Kdyby to někdy bylo potřeba, patří to
  do samostatného zadání s měřením.
* **Neměnit `state_hash()` bez dokladu** (viz §2) a nepřepínat replaye jen tak.
* **Neukládat částečný svět** — save je celek (`research/08-multiplayer-poucky.md`
  bod 13: částečný save rozbije vazby).
* **Nesahat na `godot-uo-client`** ani na `uo-shadows` (jiné projekty, jiná zadání).
* **Nepřidávat AI ani spawn** — to patří do `M5` (`sim.ai`, `world.spawn`),
  ne do tohohle zadání. (Ale `sim.offline` smí *počítat* s tím, že je jednou
  bude volat.)
* **Nepředstírat hotovo zelenými testy:** „hotovo" = soubor v gitu **A** brána
  zavolala jeho funkci **A** přijímací kritérium proběhlo s konkrétní hodnotou.

## 5. Jak to ověřit

```powershell
cd E:\Workspaces\game-clone
$py = 'C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
$env:PYTHONIOENCODING = 'utf-8'; $env:APPDATA = "$PWD\.cache\godot-appdata"

& $py tools\gates\run-all.py            # 11 + F1, 0 chyb
& $py tools\plan-status.py              # MK 3+/9, celkem 64+
& $py tools\gates\check-world-clock.py  # 0 = měřeno OK, 2 = NEMĚŘENO (viditelně)
& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . `
    --script res://tests/run_tests.gd   # N kontrol, 0 selhání (exit 1 = úklid)
```

## 6. Pick up here

**Začni registrací entit jako stavového zdroje** (`state()`/`restore()` na
`entity.mobile` + `sim.entity_registry`, registrace v `SimWorld`) — je to
nejmenší krok, hned měřitelný round-tripem přes `sim.save` (G7) a hashem.
Teprve pak `sim.offline` a brána `F1`.
