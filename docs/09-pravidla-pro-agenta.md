# 9. Pravidla pro agenta

> Tenhle oddíl je psaný jako **přímé zadání pro AI agenta**, který na projektu
> pracuje. Každé pravidlo vzniklo z konkrétní naměřené vady (odkazy v závorkách);
> žádné není „dobrá praxe" bez důvodu.

## 9.1 Zlaté pravidlo rozpadu

```
Cíl (§1) → Požadavky → Architektura (§4) → Smlouvy (§4) → Granule (§7)
        → DAG (§7) → Brány (§8) → Ověření proti cíli (§1.7)
```

Pracuje se **shora dolů** a **nikdy se nepřeskakuje úroveň**. Když v granulové
práci narazíš na něco, co nemá předka o úroveň výš (v cíli nebo ve smlouvě),
**zastav a nahlas to** — je to drift, ne úkol.

## 9.2 Jedna granule = jeden soubor

- Piš **jen do souborů uvedených v `owns`** své granule. Nic jiného.
- **Zakázané soubory** (mění je jen člověk nebo integrační granule):
  `tests/**`, `tools/gates/**`, `project.godot`, `.forge/**`, `docs/**`,
  `assets/uo/**`.
- Dvě granule ve stejné vlně nesmí mít společný soubor (`owns` je výlučné).
- Když potřebuješ změnit cizí soubor, **není to tvoje granule** — zapiš
  požadavek do `docs/` a skonči.

## 9.3 Smlouva je zdroj pravdy, ne kód

- Používej **jen názvy z `provides`** své a cizích komponent. Vymyšlené jméno
  = nefunkční integrace.
- **Tvar dat** je součást smlouvy: vlastnosti, typy a **kdo je volá**
  (naměřeno: kontrakt „hráč → `move()`, inventář" bez typů skončil tak, že
  granule dodala jen `project.godot`, zatímco sousední komponenty už
  `player.add_item()` volaly — a nebylo to nikde deklarované).
- Když implementace odhalí díru ve smlouvě: **oprav nejdřív smlouvu v `docs/`
  a test, teprve pak kód.** Nikdy ne „tiše".
- Nikdy **nemaž** existující API, na kterém stojí jiná granule nebo testy.
  Změna je **aditivní**, dokud nedoběhne integrační granule; do zadání se to
  píše výslovně („ZACHOVEJ `_step()`…").

## 9.4 Definice „hotovo" (a co hotové není)

| Hotové JE | Hotové NENÍ |
|---|---|
| Soubor je v `main` **a** brána jeho funkci **skutečně zavolala** | „PR je sloučené" |
| Přijímací kritérium proběhlo s konkrétní hodnotou (`gather(ore, diff=5) == 6`) | „testy jsou zelené" |
| Funkci volá **produkční kód** (ne jen test) | „funkce existuje" |
| V roadmapě je `done_note` s datem a číslem PR | `done: true` bez poznámky |

Naměřeno na `uo-shadows`: dvě granule byly `done` v roadmapě i v databázi
orchestru, ale jejich práce v repu **nebyla** (jedna přesunuta do `_retired/`,
druhá dodala jen `project.godot`). Proto platí: **do DAGu se staví jen na
granuli, jejíž soubor v `main` je a jejíž API jde zavolat.**

## 9.5 Testy jsou spec

- Testy se píšou **před** implementací, z kontraktu.
- Agent **nemění `tests/`** — ani „aby to prošlo".
- **Podmíněný test je časovaná bomba.** `if load(...) != null:` nebo
  `if node.has_method("x"):` znamená, že kontrola mlčí, dokud funkce
  neexistuje — a nikdo se to nedozví. Místo ticha patří **viditelný stav**:
  ```gdscript
  _check(true, "craft.smelt: ještě není implementováno (granule není hotová)")
  ```
  Jakmile soubor existovat **má**, test musí být **nepodmíněný** a musí
  **spadnout**, když funkce chybí.
- Podmíněný test musí mít u sebe napsané, **co udělá, až se zapne**. Když to
  neumíš říct, je to bomba: test, který zakazuje řetězec v cizím souboru, spadne
  na správném kódu (naměřeno: `player.gd` měl zakázaný vzor „odjakživa"
  a kontrola na něm měřila přítomnost textu, ne izometrii).
- **Netestuj přítomnost, testuj chování.** „Má metodu `move()`" neznamená nic;
  „po `move(2)` se `x` zvýší o 1" znamená všechno.

## 9.6 Důkazní pravidla (co je „změřeno")

1. **Nula a prázdno nejsou úspěch.** Když kontrola nic nezměřila (prázdný
   seznam, `0` souborů, `[]` v logu), musí to **říct nahlas**. Brána, která
   projde nad prázdnem, je slepá (naměřeno: `check-schema.py` hledal vzor,
   který po migraci neexistoval → cyklus nad prázdným seznamem → zelená).
2. **Statická kontrola musí číst KÓD, ne komentáře.** Komentář popisující vadu
   jinak vypadá jako vada (naměřeno: „BOM se nezměnil" i po opravě, protože
   kontrola našla vzor ve vlastním komentáři). Před hledáním vzorů odstraň
   komentáře.
3. **Každý test musí umět selhat.** Napiš **mutační test**: vlož vadu a podívej
   se, že kontrola spadne. Bez toho nevíš, že měří.
4. **Čísla se čtou z výstupu, ne ze zdrojáku.** Počet testů a výsledek se bere
   z běhu (`N kontrol, M selhání`), ne z počtu vzorů v souboru.
5. **U každého čísla si napiš, odkud je** (soubor:řádek, datum, příkaz).
   Dvě různá čísla téhož jména (např. „běh #355" vs `run_number` 241) nejsou
   spor, dokud nevíš, který čítač to je.
6. **Když výpis vypadá jako vada dat, přečti data jinudy** (bajty, jiný
   nástroj). Rozbité kódování konzole není rozbitý soubor.

## 9.7 Práce v paralelních vlnách

- Granule může běžet současně s jinou, právě když: obě mají hotové `depends_on`
  **a** jejich `owns` jsou disjunktní **a** nesdílejí soubor, kam obě zapisují
  (typicky registrace v `app/`).
- Když dvě granule potřebují zápis do stejného místa, **vyčleň registraci**
  do samostatné granule a ostatní ať jen deklarují `provides`.
- **Závislost nikdy do prózy** — vždy `depends_on`. (Kaskáda chyb vzniká tím,
  že závislost je schovaná ve větě.)
- **Dvě SESSION v jednom workspace (doplněno 2026-10-06, naměřeno):** když
  v jednom klonu běží dvě agentní session současně, platí:
  1. **Před psaním si projdi `git status` a `LastWriteTime`** souborů, které
     nejsou tvoje — jinak zapíšeš do cizí rozdělané práce.
  2. **Commituj jen své cesty** (`git add <svoje soubory>`), nikdy `git add -A`,
     dokud je v stromě cizí necommitnutá práce.
  3. **Stavové dokumenty (`HANDOFF.md`, `LESSONS.md`) přebírá ten, kdo končí
     později** — a při přepisu nesmí zmizet body, které tam dal ten první
     (zkontroluj hledáním, ne pamětí).
  4. Když se práce sejde ve stejném souboru, **vyhrává ten, kdo má změnu
     doloženou měřením**; druhý ji převezme nebo zapíše konflikt jako nález.

## 9.8 Protokol dokončení granule (co napsat do PR)

1. **Co poskytuji** (přesné názvy a signatury z `provides`).
2. **Co spotřebovávám** (a že to v `main` existuje — ověřeno voláním).
3. **Jak jsem to ověřil**: příkaz, který jsem spustil, a jeho výstup
   (`N kontrol, M selhání`), plus přijímací kritérium s konkrétní hodnotou.
4. **Co jsem NEDĚLAL** (non-goals, které se týkají mého souboru).
5. **Co jsem zjistil a neopravil** (nález, který patří do jiné granule).

## 9.9 Když si nejsi jistý

| Situace | Co udělat |
|---|---|
| Nevím, jak to UO dělalo | zapiš `UNVERIFIED` + **co je potřeba změřit**; nehádej číslo |
| Smlouva je nejasná | zastav, oprav smlouvu v `docs/`, pokračuj |
| Potřebuji cizí soubor | není to tvoje granule, zapiš požadavek |
| Vychází jiná hodnota než v datech | **data vyhrávají** nad dojmem; ověř měřením |
| Dvě možnosti, obě shodné s referencí | vyber tu, která je v `docs/` zdůvodněná; když tam není, zapiš rozhodnutí |
| Něco je rychlejší/„lepší" než UO | QoL (méně klikání, lepší čitelnost) **smí**; **výsledek** pravidel ne — viz `§9.10` bod 10 |

## 9.10 Zakázané zkratky (tvrdý seznam)

1. Nezavádět nové závislosti, pluginy ani generátory bez zápisu v `docs/`.
2. Nečíst `.mul`/`.uop` z herního kódu (jen `tools/uoextract/`).
3. Nepoužívat `float` ve stavu simulace (skilly v desetinách, čas v ms, pozice v dlaždicích).
4. Nevolat z `sim/` nic z `ui/`, `render/`, `app/`, ani `Input`, `Time`, `OS`, `randf()`.
5. Necommitovat assety z instalace UO ani cizí kód z instalace.
6. Nemazat API, na kterém stojí testy ostatních.
7. Neupravovat `tests/`, `tools/gates/`, `project.godot`, `.forge/`, `docs/`.
8. Neoznačit granuli `done`, dokud soubor není v `main` a brána nezavolala jeho funkci.
9. Nezapisovat „prošlo" u kontroly, která se přeskočila.
10. Nepřidávat **výsledky** pravidel, které UO nemělo (loot navíc, rychlejší
    časovače, rychlé cestování). **Provést, co hráč rozhodl, hra smí** — i beze
    hráče (offline doběh) a podle pravidel s podmínkami. Hranice: *hra smí
    provést, nesmí rozhodnout za hráče* (`01-cil-a-scope.md` §1.5 bod 8;
    `ROZHODNUTI-2026-10-09-SMER.md` §2 D3).
    *Do 2026-10-09 platilo: „Nepřidávat ‚vylepšení', která UO nemá (auto-loot,
    rychlé cestování, moderní inventář)." — ve svém čase správné; auto-loot
    a rychlé cestování zůstávají zakázané, protože mění **výsledek**.*
