# Záznam o provedení — světlo a stínování svahů podle normály (task-5, 8. 10. 2026)

> **⚠ CO JE TENHLE SOUBOR:** kopie `_analyza/p22-svetlo-nalez.md`, vložená do
> **gitu pod jiným jménem** — protože `_analyza/` je v `.gitignore`, takže kdo
> pracuje z čistého klonu, původní text by nenašel. Obsah je shodný (jen tahle
> hlavička je navíc). Odkazy na `_analyza/…` níže jsou **měření na stanici**
> (v gitu nejsou; na disku, kde session běžela, dohledatelné).

**Čím je tenhle dokument:** záznam o tom, co se 8. 10. 2026 (20. session, teammate
`svetlo`) **skutečně udělalo** a čím je to doložené. Není to stav ani plán.
**Současný stav kódu se čte z kódu** — `render/chunk_mesh.gd` (funkce
`svah_normal` / `svah_jas` / `svah_barva`) a `app/world_view.gd`
(`_draw_slope`, `slope_barva`); smlouvu má `docs/04-architektura-a-smlouvy.md`
(řádek `render.chunk_mesh`) — **ten se v této session neaktualizoval** (mimo
psací právo, viz „Co zůstalo otevřené").

**Zadání:** sdílená tabule `task-5` (Lead), psací právo
`render/chunk_mesh.gd`, `app/world_view.gd` (jen `_draw_slope`),
`tests/cases/chunk_mesh.gd`, `tests/cases/world_view.gd`, `_analyza/p22-svetlo-*`.

---

## 1. Reference — přesný předpis (soubor:řádek)

| Co | Kde | Hodnota |
|---|---|---|
| směr světla | `_src/classicuo/src/ClassicUO.Renderer/shaders/IsometricWorld.fx:14` | `LIGHT_DIRECTION = (0, 1, 1)` |
| jas z normály | tamtéž `:60-69` | `base = max(dot(normalize(n), normalize(l)), 0) / 2 + 0.5` |
| co se násobí | tamtéž `:143-146` (režim `LAND`) | `color.rgb *= get_light(IN.Normal)` — **jen jas, hue se nemění** |
| který režim | `_src/classicuo/src/ClassicUO.Client/Game/GameObjects/Views/LandView.cs:53` | stretched land = `SHADER_LAND` |
| normála | `_src/classicuo/src/ClassicUO.Client/Game/GameObjects/Land.cs:164-238` | 4 křížové součiny, `Cross(v, u)`, měřítka **22 px** a **`(soused − tile) * 4`** |
| vstupy normály | tamtéž `:113-116,145-155` | `tile` = vlastní, `top` = (x, y−1), `right` = (x+1, y), `bottom` = (x, y+1), `left` = (x−1, y) |
| rovná plocha | `IsometricWorld.fx:66-67` | `1/√2/2 + 0.5` = **0.85355339** |
| `Brightlight` | `IsometricWorld.fx:68` + `GameScene.cs:1002` + `Configuration/Profile.cs:240` | `TerrainShadowsLevel * 0.1`; default 15 → **1.5** |

Naše měřítka jsou tatáž čísla: `Const.ISO_STEP = 22`, `Const.Z_SCALE = 4`.

## 2. Naměřený stav PŘED (sonda `_analyza/p22-svetlo-mereni.gd`)

Postup: `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script
res://_analyza/p22-svetlo-mereni.gd` (s `APPDATA`/`XDG_DATA_HOME` ve workspace).
Výstup: `_analyza/p22-svetlo-mereni.txt`.

- **3914 dlaždic na svahu** v okně Britannie 1430..1580 × 1560..1700; **všechny**
  měly jas **0.85355339** (jedna konstanta, žádný směr světla).
- Kontrola metriky na **známém správném** případě (rovina `z = 5x + 7y`):
  reference i naše čtyřrohová normála dávají **úhel 0.0000°** a stejný jas.
- Kontrola na **známém rozdílném** případě (nerovinný terén `tile 0, top 20,
  right 4, bottom 0, left −6`): **úhel 18.84°**, jas 0.793689 vs 0.761608 —
  metrika rozdíl pozná (na rovině 0°, tady 18.84°).
- 5 dlaždic na skutečném svahu (jas dnešní → jas z normály):
  (1484,1560) +16.48 %, (1485,1560) +3.65 %, (1503,1560) −0.67 %,
  (1504,1560) +12.89 %, (1507,1560) +13.43 %.
- **Rozsah přes 3914 svahů: 0.500000 .. 1.000000** (v <0,1>; 1.0 = dlaždice
  přesně odvrácená ke světlu → textura zůstane neztmavená, ne přesvícená).
- S `Brightlight = 1.5` (profil 15) vychází **0.323223 .. 1.073223**, tedy
  **nad 1.0** → texturu by to přepálilo.

**Odbocka (potvrzená Leadem):** `Brightlight` je v modulu **VSTUP** s výchozí
hodnotou `1.0` (`BRIGHTLIGHT_DEFAULT`), ne konstanta. S výchozí 1.0 se nikdy
nepřesvítí; kreslení (`svah_barva`) navíc ořezává na <0,1>, aby ani explicitní
1.5 nemohlo dát víc než 1.0.

## 3. Co se změnilo

| Soubor | Změna |
|---|---|
| `render/chunk_mesh.gd` | nové `SVETLO_SMER`, `BRIGHTLIGHT_DEFAULT`, `BRIGHTLIGHT_PROFIL_15`; nové statické `svah_normal(obj)`, `svah_jas(obj, brightlight = 1.0)`, `svah_barva(obj, brightlight = 1.0)`; `_kvadr` bere `barva = svah_barva(obj)`; hlavička má naměřená čísla |
| `app/world_view.gd` | `_draw_slope` bere `barva = slope_barva(obj)`; nové statické `slope_barva()` = průchod na `chunk_mesh.svah_barva` (jedna funkce pro obě cesty) |
| `tests/cases/chunk_mesh.gd` | sekce A: barva svahu se srovnává s nezávislým přepisem reference; nová sekce H (identita, opačné sklony, jiná normála, rozsah <0,1>, `Brightlight` jako vstup, vrcholy dávky) |
| `tests/cases/world_view.gd` | sekce 11b: `_draw_slope` na rovné ploše = přesně původní barva, na svahu = jas z normály (nezávislý přepis) |

**Normála = `(pravý − levý) × (dolní − horní)`**, tj. součet normál obou
trojúhelníků kvadru (plošně vážený průměr). První verze používala
`(pravý − horní) × (dolní − horní)` a **levý roh ignorovala** — naměřeno při
psaní této změny; na rovině je obojí totéž, na reálném terénu ne.

**Změřený rozdíl proti referenci na reálném terénu: 0.00° až 53.75°** (příklad
(1507,1560) sedí na 0.00°). Je to tím, že reference bere i **severní a západní**
souseda (a počítá normálu pro každý roh zvlášť a interpoluje), kdežto dlaždicový
objekt nese jen čtyři rohy.

## 4. Testy

| Běh | Výsledek | Doklad |
|---|---|---|
| bazový (před změnou) | **1352 kontrol / 0 selhání** | výstup prvního běhu této session (job; log se neukládal do souboru — číslo je z výstupu, ne z dokumentace) |
| po `chunk_mesh` (sekce H) | **1359 / 0** | `_analyza/p22-svetlo-testy1.txt` |
| po `world_view` | **1361 / 0** | `_analyza/p22-svetlo-testy2.txt` |
| po opravě normály (diagonály) | **1362 / 0** | `_analyza/p22-svetlo-testy4.txt` |
| finální (po všech obnovách souboru) | **1362 / 0** | `_analyza/p22-svetlo-testy-final.txt` |

Příkaz: `& ".cache\godot\Godot_v4.7.2-stable_win64_console.exe" --headless --path .
--script res://tests/run_tests.gd` s `$env:APPDATA` a `$env:XDG_DATA_HOME` =
`E:\Workspaces\game-clone\.cache\godot-appdata`. (Zadání uvádělo bázi 1320 —
naměřeno 1352; rozdíl dělá práce paralelní session 20.)
Poznámka: proces končí `exit 1` kvůli únikům RID na konci — rozhoduje řádek
`N kontrol, M selhání`, ne exit kód (`dsh-prostredi` §6).

## 5. Mutační vzory (připravené; gate se NESPOUŠTĚL)

Vzory i mutanty vyrábí `_analyza/p22-svetlo-mutace.py` (bajtová náhrada, kontroluje
počet výskytů). Ověřeno **ručním** spuštěním sady s `--chunk-mesh-script=<mutant>`
(výsledky `_analyza/p22-svetlo-mutace-vysledky.txt`, logy `p22-svetlo-mut-M*-out.txt`).

| # | Vzorek (starý → nový) | Selhání |
|---|---|---|
| M1 | `var base: float = maxf(n.dot(SVETLO_SMER.normalized()), 0.0) / 2.0 + 0.5` → `var base: float = SVAH_JAS` | 5 |
| M2 | `return (r - l).cross(b - t).normalized()` → `return Vector3(0.0, 0.0, 1.0)` | 5 |
| M3 | `const SVETLO_SMER := Vector3(0.0, 1.0, 1.0)` → `Vector3(0.0, -1.0, 1.0)` | 4 |
| M4 | `var j: float = clampf(svah_jas(obj, brightlight), 0.0, 1.0)` → `svah_jas(obj, brightlight)` | 2 |
| M5 | `return SVAH_JAS` → `return 0.8535534` (identita se ztratí) | 1 |
| M6 | `return base + (brightlight * (base - SVAH_JAS) - (base - SVAH_JAS))` → `return base` | 1 |

⚠ **M5 je důkaz, že identita musí být `==`, ne `is_equal_approx`**: rozdíl
0.85355340 vs 0.85355339 vytištěný jako `Color` vypadá stejně, ale přesné
porovnání ho chytí.

⚠ **`tools/gates/mutace-tests.py:858` má STARÝ vzor** (patřil řádku, který jsem
změnil): `"barva = SVAH_BARVA       # viz \`SVAH_JAS\` v hlavičce"`. Dnes je na
tom místě `barva = svah_barva(obj)  # viz \`svah_jas\` a hlavicka (stinovani dle normaly)`.
Soubor je mimo psací právo — **musí ho upravit Lead**, jinak se mutace tiše
neprovede (a „neprovedená mutace tvrdí totéž co procházející“).

## 6. Snímky (PŘED/PO ze stejného místa)

Místo **1452,1520** vybráno měřením (`_analyza/p22-svetlo-mista.gd`): hledá
pohled s **oběma protilehlými sklony** (`kontrast = min(tmavých, světlých)`)
a zároveň bez řeky v záběru. „PŘED“ se fotilo tak, že se na dobu běhu vypnulo
stínování jednou řádkou v `render/chunk_mesh.gd` a soubor se vrátil z bajtů
(`_analyza/p22-svetlo-pred.py`, návrat v `finally`, SHA-256 shoda ověřena:
`85e0c85c…` před i po — ten hash je stav **před** opravou konců řádků, viz §6b
bod 5).

| Soubor | Co je |
|---|---|
| `_analyza/p22-svetlo-pred.png` | stav před (svah jedna barva) — z `p22-svetlo-ph-5.png`, SHA-256 shodná |
| `_analyza/p22-svetlo-po.png` | stav po (jas podle normály) — z `p22-svetlo-kand2-5.png`, SHA-256 shodná |
| `_analyza/p22-svetlo-pred-po-pred-po.png` | 2× zvětšený výřez PŘED\|PO vedle sebe (hlavní doklad pro oko) |
| `_analyza/p22-svetlo-diff-final.png` | 8× zesílený rozdíl finální dvojice — mění se **jen svahové dlaždice** |
| `_analyza/p22-svetlo-porovnej.txt` | čísla: 20–22 % pixelů změněno, průměr 1.1–1.6 z 255, max 164 |
| `_analyza/p22-svetlo-mista.txt` | výběr místa (kontrast = min(tmavých, světlých) v pohledu) |

**Co je vidět (ověřeno `read_image`):** v PO vede přes levou část trávy
**ztmavený pruh** (svah odvrácený od světla) a skála má tmavší/světlejší stěny;
v PŘED je tráva plošně stejná. Rozdílový snímek je **nulový na rovných
plochách** (dlažba, cesta, střecha, stromy) a nemá tvar posunutého obrazu.

## 6b. Co se nepovedlo / co má cenu vědět

1. **První verze normály ignorovala levý roh** (`(pravý − horní) × (dolní −
   horní)`): změna `z_corners[2]` by jasem nepohnula. Našlo se to při psaní
   mutačního vzoru a opravilo na diagonály (§3).
2. **Sám jsem si vyrobil vadu, kterou pravidla popisují:** `Set-Content
   -Encoding utf8` nad `_analyza/p22-svetlo-vyrez.py` zapsal **UTF-8 s BOM**
   (první bajty `EF BB BF`). Opraveno `write` toolem, ověřeno `ast.parse` nad
   všemi čtyřmi `.py` a kontrolou prvních tří bajtů (`dsh-prostredi` §3).
3. **Jeden běh „PŘED“ se přerušil** (`$ErrorActionPreference='Stop'` udělal
   z Godot warningu na stderr terminující chybu), takže se **nevrátil soubor**.
   Zjištěno hned, soubor obnoven a ověřen hashem (`85e0c85c…`); další běhy už
   dělá `_analyza/p22-svetlo-pred.py` s návratem v `finally`.
4. **Smazání mutovaných kopií:** 6 souborů `p22-svetlo-mut-M*.gd` zůstává jako
   doložení; **jsou to kopie stavu k 8. 10. 2026** a po další změně
   `render/chunk_mesh.gd` je nutné je regenerovat (`p22-svetlo-mutace.py`).
5. **Konce řádků (ne moje vada, ale opravené):** `render/chunk_mesh.gd`
   a `tests/cases/chunk_mesh.gd` měly v pracovním stromě **CRLF**, zatímco
   `.gitattributes` žádá `eol=lf` a ostatních **94 .gd souborů je LF**. Že to
   neudělaly tooly této session, je **kontrolovaný pokus**: `write` i `edit`
   píšou LF (a `app/world_view.gd` po třech editacích zůstal LF). Vzniklo to
   dřív — Python `write_text()` bez `newline=''` (past `dsh-prostredi` §3).
   Opraveno bajtově (`python _analyza/p22-svetlo-eol.py`, CRLF 888 → 0 a
   653 → 0; po opravě má CRLF **0** z 96 .gd). Testy po opravě **1362 / 0**.
   ⚠ Hash souboru se tím změnil (`render/chunk_mesh.gd` dnes
   `FF619060…`, ne `85e0c85c…` z §6) — číslo v §6 je stav **těsně po obnově
   z PRED běhu**, ne „dnešní hash“.

## 7. Co zůstalo otevřené

1. **`tools/gates/mutace-tests.py:858`** — starý vzor, musí se vyměnit (viz §5).
2. **`docs/04-architektura-a-smlouvy.md:128`** — řádek `render.chunk_mesh` uvádí
   `SVAH_BARVA`; dnes jsou tam i `svah_normal`/`svah_jas`/`svah_barva`
   (a `world_view.slope_barva`). Mimo psací právo.
3. **`HANDOFF.md:129,278`** — mluví o `SVAH_BARVA` jako o jediné barvě svahu.
   Vlastní Lead.
4. **`Brightlight` se nikde nečte z dat** — je to jen parametr s výchozí 1.0.
   Až bude `render.light`/profil, stačí hodnotu předat (nic se nepředělává).
5. **Statické mutanty** `_analyza/p22-svetlo-mut-M*.gd` (6 souborů) leží na disku
   jako doklad; když se `render/chunk_mesh.gd` změní, **jsou zastaralé** —
   regenerují se `python _analyza/p22-svetlo-mutace.py`.
