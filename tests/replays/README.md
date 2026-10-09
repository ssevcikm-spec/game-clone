# Replaye (docs/04 §4.8, brána G9)

Replay je skriptovaná sekvence příkazů, která po odehrání **musí dát stejný
`state_hash()`**. Slouží k odhalení regrese v mechanikách: když se změní pohyb,
souboj nebo výroba, hash se rozejde.

Formát (`*.json`):

```json
{
  "name": "kratky_pohyb",
  "popis": "co replay ověřuje (pro člověka)",
  "ticks": 200,
  "hash": "<očekávaný state_hash() po odehrání>",
  "commands": [
    {"at": 0,  "t": "move", "dir": 0, "run": false, "seq": 1},
    {"at": 40, "t": "move", "dir": 1, "run": true,  "seq": 2}
  ]
}
```

Pravidla:

* `commands` musí být **neprázdný** seznam; `at` je číslo ticku, ve kterém se
  příkaz vloží do fronty (stejné `at` = stejné pořadí vložení),
* `ticks` je počet ticků po 50 ms, po které replay běží,
* `hash` je **povinný** — bez očekávaného hashe replay nic neměří
  (brána `check-replay.py` to hlásí jako vadu),
* tvary příkazů jsou z `docs/04` §4.3 — nic se nevymýšlí.

Replaye vznikají až s `sim.world_loop` (M0/M2). Do té doby je brána G9
**NEMĚŘENO** a je to vidět v souhrnu CI.

## Historie hashů (přepnutí je změna specu, ne údržba)

* **2026-10-09** — `state_hash()` začal zahrnovat **stavové zdroje** světa
  (první je `sim.scheduler` = fronta budoucích událostí; granule `sim.save`).
  Očekávané hashe obou replayů se tím **přepnuly**: `tic_200` z `281e7802…`
  na `451d0a79…`, `tic_1000` z `9e6218ab…` na `d1e0db5c…`.
  **Doklad, že se nezměnilo chování:** sonda `_analyza/p30-replay-legacy-hash.gd`
  odehraje týž replay a spočítá **starým** seznamem vstupů `hash_legacy` —
  a ten se oběma replayům **přesně rovná původním očekávaným hashům**. Změnil
  se tedy tvar vstupu do hashe, ne svět. Přepnutí odsouhlasil uživatel jako
  **jednu dokumentovanou změnu specu** (`ROZHODNUTI-2026-10-09-SMER.md` §5).
  **Co to znamená pro budoucnost:** kdo mění hash nebo replay, musí přinést
  stejný druh dokladu („starý hash sedí"), ne jen přepsané číslo.
