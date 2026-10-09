# ZADÁNÍ 23 — nezávislé ověření toho, co vzniklo po 2. kole (read-only)

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalO) — nepřepisuje
> se. Vzniklo 2026-10-09 proto, že **autor není nezávislý reviewer**: dvě kola
> nezávislého ověření v ten den našla **10 + 3 vady**, které autor neviděl
> (4 popisky měření, 5 vad smlouvy klienta, 3 rozbité tabulky).
> **Pracovní složka: `E:\Workspaces\game-clone`.**
> **⚠ TOHLE ZADÁNÍ JE READ-ONLY: nic neopravuj, nic necommituj, nic nezapisuj
> (ani do `_analyza/`). Výstupem je zpráva.**

## 1. Cíl

Ověřit **měřením** (ne čtením prózy), že to, co session 2026-10-09 tvrdí
o granulích `sim.scheduler` a `sim.save`, je pravda — a najít, co ne.

## 2. Co přesně ověřit (každý bod = změřit a uvést příkaz)

| # | Tvrzení k ověření | Jak to změřit | Jak vypadá vada |
|---|---|---|---|
| 1 | „`hash_legacy` replayů se přesně rovná **původním** očekávaným hashům" (doklad, že se změnil jen tvar hashe) | spusť `_analyza/p30-replay-legacy-hash.gd` na obou replayích a porovnej s tabulkou v `tests/replays/README.md` | čísla nesedí, nebo sonda nejde spustit |
| 2 | „Fronta plánovače přežije save/load" | `tests/cases/save.gd` projde; navíc **sám** zkus: z payloadu save odstranit `sources` (v KOPII souboru!) a ověřit, že round-trip spadne, jak má | save/load projde i bez zdrojů → zdroje se neukládají |
| 3 | „`sim.scheduler` je deterministický (pořadí `(at, id)`)" | spusť `tests/cases/scheduler.gd`; přečti `sim/scheduler.gd` a najdi, čím je pořadí dané | pořadí závisí na pořadí klíčů `Dictionary` |
| 4 | „Nikdo do plánovače zatím neplánuje a je to pojmenované" | hledej `schedule(`/`schedule_in(` v `sim/`, `app/` (mimo `scheduler.gd` a testů) | něco plánuje a není to zdokumentované |
| 5 | „`run-all.py` = 11 bran OK, testy 1 507/0" | spusť obojí (viz §4) | jiná čísla, nebo brána tiše neměří |
| 6 | „MK 2/0/7, celkem 63 hotových" | `python tools\plan-status.py` | jiná čísla (a hlavně: ověř, že „hotovo" znamená **soubor v gitu + test**) |
| 7 | „Brány `F1` a `F4` jsou v `docs/08` §8.2 se stejnými kontrolami jako v návrhu" | porovnej `NAVRH-BRAN-FEEL-2026-10-09.md` §2/§3 s `docs/08` §8.2 | v dokumentu chybí kontroly, mutace, nebo tři stavy |
| 8 | „V dokumentech nezůstalo tvrzení o opaku (věrnost je cíl apod.)" | hledej v `docs/`, rootových `*.md`, `ZADANI-*.md`; rozliš **neoznačené tvrzení o dnešku** (vada) od označeného záznamu („překonáno", „původní znění", „dřív") a od popisu chování („je to věrné referenci") | neoznačené tvrzení, že cílem je kopie/věrnost |
| 9 | „Markdown tabulky nejsou rozbité" | `python .tmp\sonda-tabulky.py . docs .forge` (sonda je dočasná; když chybí, napiš to) | sonda hlásí vady, nebo chybí a nikdo to neví |
| 10 | „`state_hash()` zahrnuje stavové zdroje a load je vrací ve správném pořadí" | přečti `sim/sim_world.gd` (`save`, `load`, `state_hash`) a ověř, že `apply()` je **před** kontrolou hashe | pořadí je opačné → round-trip by musel hlásit rozchod (a nehlásí) |

## 3. Required výstup (přesně tato struktura)

1. **Co SEDÍ** — seznam s naměřenými hodnotami a příkazy.
2. **Co NESEDÍ** — u každého: soubor:řádek, citace, naměřená hodnota proti tvrzené.
3. **Co zůstalo NEMĚŘENO** — a proč (co ti chybělo).
4. **Nálezy mimo zadání** — cokoli, co vypadá jako vada (i v cizích dokumentech).
5. **Verdikt jednou větou:** dá se na tvrzení session 2026-10-09 spolehnout?

## 4. Jak měřit (prostředí)

```powershell
cd E:\Workspaces\game-clone
$py = 'C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe'
$env:PYTHONIOENCODING = 'utf-8'; $env:APPDATA = "$PWD\.cache\godot-appdata"
$godot = '.cache\godot\Godot_v4.7.2-stable_win64_console.exe'

& $godot --headless --path . --script res://tests/run_tests.gd   # N kontrol, M selhání
& $py tools\gates\run-all.py        # 11 bran
& $py tools\plan-status.py          # MK x/y/z
& $py tools\check-docs-refs.py ; & $py tools\check-zadani.py
# doklad o hashích:
& $godot --headless --path . --script res://_analyza/p30-replay-legacy-hash.gd `
    -- "--replay=res://tests/replays/tic_200.json"
```

**Dvě pasti prostředí, které vypadají jako vada kódu:**
`--headless` testy končí `exit 1` kvůli úklidu (leaked RID) — **čti „N kontrol,
M selhání"**, ne exit kód. A `Measure-Object -Line` nad `git show` nedopočítá
poslední řádek — autorita je `git diff` a velikost blobu.

## 5. Co NEDĚLAT

* **Nic neopravovat** — ani „očividnou" vadu, ani dokument, ani test. Nález se
  hlásí, neopravuje (`docs/09` §9.5: testy jsou spec).
* **Nezapisovat nikam** (ani do `_analyza/`, ani do `.tmp/`) — když potřebuješ
  kopii souboru pro mutaci, dělej ji v systémovém tempu a **řekni to**.
* **Nevěřit mým tvrzením** — každý bod měř; co nejde změřit, patří do NEMĚŘENO.
* **Nepoužívat `Select-String`** na hledání v souborech (tichý falešný negativ) —
  použij `grep` tool, a když hledáš plošně, Python walk.

## 6. Pick up here

Začni **bodem 1** (doklad o hashích) — je to nejcitlivější místo celé session:
kdyby ten doklad neseděl, je zelená brána G9 nad posunutou pravdou a všechno
ostatní je vedlejší.
