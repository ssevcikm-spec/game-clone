# Jak zadat práci nové session

> Tenhle soubor je návod pro **člověka**, ne pro agenta. Obsahuje hotový text,
> který se dá zkopírovat do nové session, a tři způsoby zadání podle toho,
> kolik agentů chcete zapojit.

---

## 1. Nejkratší cesta: zkopírujte tenhle blok do nové session

```text
Pracovní složka: E:\Workspaces\game-clone

NEJDŘÍV si přečti HANDOFF.md (stav projektu) a ZADANI-DALSI-VYVOJ.md (co dělat
teď — vzniklo auditem 2026-10-06) a prvních pár záznamů z LESSONS.md (co už
někoho stálo čas). Teprve pak zadání v ZADANI-UO-KLON.md — přečti ho celé.
Pak v tomto pořadí:
docs/01 (cíl), docs/04 (architektura a smlouvy), docs/07 (granule a milníky),
docs/08 (brány), docs/09 (pravidla pro agenta). Než je nemáš přečtené,
nepiš kód.

⚠ TATO SESSION POTŘEBUJE PLNÝ PŘÍSTUP. V režimu workspace-write nejde zapsat do
.cache (Low integritní label) → brány G3/G7/G11 hlásí vadu, testy hlásí
save=false, run-all.py spadne na summary.json. Neopravuj kvůli tomu kód.

Stav k 2026-10-06 (naměřeno, ne opsáno): hotových 31 granul z 101 (+5, které
předání neuvádělo: app.main, app.loop, app.input, sim.commands, sim.world_loop
— M0 je tím hotové celé); na obrazovce NENÍ NIC (render/ má 1 soubor ze 7);
atlas.py je v gitu, ale má 117 překryvů spritů; práce JE pushnutá (ahead 0),
ale CI na GitHubu selhalo dvakrát s 0 jobů — viz ZADANI-DALSI-VYVOJ.md úkol 1.

Pak postupně:
1. Spusť kontroly a ověř, že procházejí:
   python tools/check-docs-refs.py ; python tools/check-zadani.py ;
   python tools/roadmap-gen.py --check
2. Udělej ÚKOLY 1–7 ze ZADANI-DALSI-VYVOJ.md v uvedeném pořadí. První tři
   kroky k prvnímu obrázku: opravit atlas.py → render.textures → render.chunk,
   a pak ZAPOJIT do scény (kamera + queue_redraw + main.tscn) — bez zapojení
   zůstane i hotový renderer mrtvý kód.
3. Než začneš psát nový kód, oprav tři vady ZAPOJENÍ z HANDOFF.md:
   input_map se nikdy nepřidá do stromu, sim.systems plní jen testy,
   time.world_time_ms nikdo nezapíše.

Pravidla, která platí bez výjimky:
- Piš jen do souborů z "owns" své granule. tests/, tools/gates/, project.godot,
  .forge/ a docs/ se needitují.
- sim/ nesmí volat ui/, render/, app/ ani Input, Time, OS, randf().
- Žádné floaty ve stavu: skilly v desetinách (int), čas v ms, pozice v dlaždicích.
- Jména API ber ze smluv v docs/04 — nevymýšlej nová.
- Neověřenou věc napiš jako UNVERIFIED + co je potřeba změřit. Nevymýšlej čísla.
- "Hotovo" = soubor v main A brána zavolala jeho funkci A přijímací kritérium
  proběhlo s konkrétní hodnotou. Zelené testy samy nestačí.
- "Nula a prázdno nejsou úspěch": když kontrola nic nezměřila, nahlas to.

Prostředí:
- Godot (binárka ve workspace): .cache\godot\Godot_v4.7.2-stable_win64_console.exe
- Python: C:\Users\Ssevc\.dsh\dsh-runtimes\dsh-primary-runtime\dependencies\python\python.exe
- Klony referenčních zdrojů (_src/, research/refs/) jsou JEN KE ČTENÍ. Z GPL
  projektů (ServUO, ModernUO) se berou fakta (čísla, vzorce), NIKDY kód.
  Portovat se smí z ClassicUO (BSD-2) a SphereServer (Apache-2.0).
- Instalace UO (D:\Games\Electronic Arts\Ultima Online Classic) je read-only.

Než začneš psát, řekni mi: co jsi přečetl, co budeš dělat první a proč.

NA KONCI (povinné, viz HANDOFF.md): přidej do LESSONS.md záznamy za tuhle
session (ponaučení, chyby, nové nástroje) a přepiš HANDOFF.md na stav po své
práci — včetně sekce o povinném předání, kterou zkopíruj dál. Pak commitni.
Push na GitHub jen na vyžádání.
```

**Proč v textu není bootstrap:** bootstrap granule (`boot.project`, `boot.tests`,
`boot.gates`, `boot.ci_env`) byly hotové **2026-10-02** a `boot.*` soubory
(`project.godot`, `tests/`, brány) agenti needitují. Kdyby je orchestra vydala
znovu, přepsala by základy projektu. Jejich stav se **měří** (viz předletová
kontrola), neopakuje.

---

## 2. Tři způsoby zadání

### A) Jeden agent, jedna session (nejjednodušší)
Zkopírujte blok z §1. Agent půjde milníky M0 → M8. Výhoda: nikdo se nepere
o soubory. Nevýhoda: M1 (extrakce dat) je nejdelší část a poběží sériově.

### B) Víc agentů paralelně, po vlnách
Každé session zadejte **jednu vlnu** z `docs/07` §7.3 a platí:
- granule ve vlně mají **disjunktní `owns`** — to je podmínka, ne přání,
- závislosti se **nedomlouvají prózou**, ale čtou z `depends_on`,
- **registrace systémů** (`sim/sim_world.gd`, `app/loop.gd`) patří do
  integrační session, ne do vln — jinak si agenti rozbijí tick.

Text pro takovou session:

```text
Pracovní složka: E:\Workspaces\game-clone
Přečti ZADANI-UO-KLON.md, docs/04 a docs/09.
Tvoje vlna je W1 z docs/07 §7.3. Udělej granule: world.tiledata, world.map,
render.textures, render.hue, render.sort.
Piš jen do jejich "owns". Když potřebuješ jiný soubor, skonči a napiš mi to.
Přijímací kritéria jsou v .forge/roadmap.json u každé granule.
```

### C) Orchestra (automatické vydávání granulí)
Tenhle balíček je na to připravený — `roadmap.json` má klíč `grains`:

1. Repo je na GitHubu (`ssevcikm-spec/game-clone`) a **práce je pushnutá**
   (`ahead 0`, ověřeno 2026-10-06).
2. Zaregistrujte hru: `POST /game {"game_id": "...", "repo": "vlastnik/repo",
   "roadmap_file": ".forge/roadmap.json"}`.
3. Bootstrap granule (`boot.*`) jsou **hotové** (2026-10-02) — neopakovat.
4. Pozor na invariant 15 z orchestra: nová granule se kvůli cooldownu
   `RETRY_HOURS` (3 h) nemusí vydat hned. Když „orchestra nic nedělá",
   zkontroluj nejdřív CI cílového repa, ne conductora.
5. **⚠ CI cílového repa JE ČERVENÉ a neměří nic** (`.github/workflows/ci.yml` má
   v hlavičce `UNVERIFIED`): dva běhy, oba `failure` s **0 jobů** a bez logů
   (`#1` 2026-10-03, `#2` 2026-10-06) — neproběhl ani download Godotu. Podpis
   odpovídá vyčerpané kvótě minut u privátního repa. **Než orchestra zapnete,
   odblokujte CI** (úkol 1 v `ZADANI-DALSI-VYVOJ.md`) — jinak orchestra staví
   na zelené, která neexistuje.
6. **`docs/07 §7.3` (vlny) pokrývá 62 granul z 101** — chybí celá extrakční
   pipeline M1 (14 granul), všechny `data.*` (8) a 4 bootstrap granule. Orchestra
   vydávající podle vln by tuhle práci **nikdy nevydal**; musí se doplnit.

---

## 3. Předletová kontrola (5 minut)

| Co | Jak | Očekáváno (2026-10-06) |
|---|---|---|
| Je co číst | `Test-Path HANDOFF.md, LESSONS.md, ZADANI-DALSI-VYVOJ.md` | `True` (stav, ponaučení i zadání pro další vývoj) |
| Workspace je repo | `git -C E:\Workspaces\game-clone log --oneline -1` | `3e7864c` (render.sort) — nebo novější, pokud session pracovala |
| Nic nevisí na disku | `git status --porcelain -uall` | `?? tools/uoextract/atlas.py` **a nic jiného** |
| Kolik je před GitHubem | `git rev-list --count origin/main..HEAD` | `12` (dokud se nepushne) |
| Testy | `$env:APPDATA="E:\Workspaces\game-clone\.cache\godot-appdata"` + `godot --headless --path . --script res://tests/run_tests.gd` | `238 kontrol, 1 selhání` (to jedno je `user://` = prostředí) |
| Nic velkého v gitu | `git -C ... ls-files \| Measure-Object` | **266 souborů, 7,4 MB** |
| Kontroly procházejí | `python tools/check-docs-refs.py` a `check-zadani.py` | `OK` (obě mají mutační test) |
| DAG je konzistentní | `python tools/roadmap-gen.py --check` | `OK: DAG je konzistentní` |
| Instalace UO na místě | `Test-Path 'D:\Games\Electronic Arts\Ultima Online Classic\tiledata.mul'` | `True` (`map0.mul` tam **není**, mapa je v `map0LegacyMUL.uop`) |
| Godot běží | `& .cache\godot\Godot_v4.7.2-stable_win64_console.exe --headless --version` | `4.7.2.stable.official.ed1daf0bf` |

**Předávací smyčka (platí od 2026-10-03):** každý krok = **nová session** a po
každé implementaci **rovnou předání**. Nová session začíná přečtením
`HANDOFF.md` + `LESSONS.md` a končí jejich aktualizací a commitem. Když
v `HANDOFF.md` chybí sekce „POVINNÉ: na konci každé session", je předání
neúplné — doplň ji podle `LESSONS.md`.

---

## 4. Na co si dát pozor (nejdražší chyby z tohoto projektu)

1. **Nehardcodovat klasická jména předmětů.** Tato instalace je **nemá**
   (`leather gloves`, `gold`, `bandage` v `tiledata.mul` nejsou) — obsah se
   vybírá podle vlastností (`docs/03` §3.3.1b).
2. **Nezapisovat „hotovo" podle zelených testů.** Naměřeno: hráč nebyl na
   obrazovce a všechny brány byly zelené. Proto je v bránách snímek a lidská
   kontrola.
3. **Nevěřit modelu, který „sedí na velikost souboru".** Dvě mřížky klidně
   vyjdou přesně; rozhoduje test na **celém** souboru proti **nulovému modelu**
   (`docs/10` P24 — stálo mě to jednu chybnou „verifikaci").
4. **Hra smí provést, co hráč rozhodl — nesmí rozhodnout za hráče.** Zakázané
   zůstávají **výsledky** pravidel, které UO nemělo (auto-loot, rychlé
   cestování, moderní inventář); dovolené je méně klikání, lepší čitelnost,
   offline doběh a pravidla s podmínkami. **Změna cíle 2026-10-09** —
   podrobnosti `ROZHODNUTI-2026-10-09-SMER.md`, hranice v `docs/01` §1.5 bod 8.
5. **Nedělat `tiledata.mul` znovu.** Je vyřešený: dva bloky se skupinovými
   hlavičkami, rezerva 0 B (`docs/03` §3.3.1). Čtyři sporné body, které
   zbyly, se rozhodují **testem**, ne dojmem (`docs/03` §3.5.4).

---

## 5. Jak poznat, že práce jde správně

| Signál | Význam |
|---|---|
| Milník M0 hotový a `godot --headless --script res://tests/run_tests.gd` projde | kostra žije |
| M1: na snímku je **mapa Britainu a postava stojí nohama na dlaždici** | extrakce dat funguje |
| M2: hráč chodí 400 ms/krok, otevírá dveře, projde moongate | pohyb a interakce sedí |
| M4: ruda → ingot → dagger a **kovářství stouplo** | smyčka §1.3 funguje zčásti |
| M5–M7: souboj, magie, obchod | hra je hratelná |
| Každá brána má **mutační test** (vlož vadu → spadne) | zelená něco znamená |

Když se zaseknete: `docs/11` §11.6 je registr otevřených otázek s postupem,
jak je uzavřít — a `docs/10` je seznam pastí, které už někoho stály čas.
