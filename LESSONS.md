# Ponaučení, nástroje a zkušenosti

> **Co sem patří:** co tahle práce naučila — chyby a jejich příčiny, postupy,
> které se osvědčily, vytvořené nástroje a čím jsou ověřené.
> **Co sem nepatří:** stav projektu (ten je v `HANDOFF.md`), zadání (`docs/`)
> a naměřená data (`research/`) — na ty se odkazuje, nekopírují se sem.
>
> **Pravidlo:** každá session, která udělá práci, sem přidá záznam **hned**
> (ne až na konci), a to i když nic nevyšlo — *hlavně* když nic nevyšlo.
> Zápis bez měření je dohad; patří k němu soubor, číslo a datum.

## Jak psát záznam

```markdown
### RRRR-MM-DD — krátký název (typ)
**Co se stalo:** jedna až tři věty, konkrétně.
**Doklad:** soubor/commit/číslo, které to dokazuje.
**Ponaučení:** co z toho plyne pro příští práci (ne „dávat pozor", ale co udělat).
```

Typy: `chyba` (moje vada) · `past-nástroje` (prostředí/nástroj, ne logika) ·
`postup` (co se osvědčilo) · `nástroj` (nový nástroj a čím je ověřený) ·
`vada-zadani` (co je potřeba opravit ve `docs/`).

---

### 2026-10-03 — Sedmnáct sond na formát animací místo přečtení repu (chyba)
**Co se stalo:** `anim.mul` jsem se snažil rozluštit vlastními sondami, jednu po
druhé; pokaždé jsem uvěřil číslům, která vypadala rozumně, a stavěl na nich další
sondu. Formát ve skutečnosti popisují **dva referenční zdroje, které v repu už
byly** (`research/refs/UOFiddler/Ultima/Animations.cs`, `_src/classicuo/.../AnimationsLoader.cs`).
**Doklad:** commity `f9d143e`, `b271373`; sondy `.cache/probe-anim*.py` (1–37);
konečné zjištění („prvních 512 B bloku je ve všech blocích stejných") vzniklo
POROVNÁNÍM bloků, ne další sondou.
**Ponaučení:** než začnu luštit binární formát, **projdu `research/refs/` a `_src/`**
(`grep` na název souboru nebo klíčové slovo). Teprve když tam nic není, píšu sondu —
a první sonda má být **rozdíl dvou vzorků**, ne další hypotéza o jediném vzorku.

### 2026-10-03 — `git checkout -- <soubor>` smazal i rozdělané opravy (chyba)
**Co se stalo:** po mutačním testu jsem chtěl vrátit vloženou vadu a použil
`git checkout -- tools/uoextract/anim.py`. Vrátil se ale **celý soubor z posledního
commitu** — tedy i tři opravy, které jsem měl rozdělané a netestované.
**Doklad:** `b271373` (opravy se musely psát znovu); `git status` před tím byl čistý,
takže „vrátit vadu" znamenalo vrátit i všechno ostatní.
**Ponaučení:** mutaci **nedělej editorem a `checkout`em**, ale vlož ji a vrať
**ze zálohy proměnné** v jednom běhu (`$orig = Get-Content …; …; WriteAllText $orig`)
— nebo ji dělej až po commitu, kdy je `checkout` bezpečný.

### 2026-10-03 — Mutační test odhalil, že ověření netestuje pravidlo (chyba)
**Co se stalo:** obrátil jsem pořadí zdrojů animací (UOP před MUL) a `--verify`
zůstalo **zelené**. Pravidlo `zdroj()` se testovalo jen na živých datech, a ta
jsou pomalá, takže kontrola mohla snadno minout.
**Doklad:** `b271373`; po přidání čtyř offline kontrol (`mul_f`/`uop_f` slovník)
mutace padá na `exit 1`, po vrácení je zelená.
**Ponaučení:** u každého pravidla, které není jen „soubor existuje", napiš
**offline test s umělými daty** — jinak se ověření dá minout a nikdo to nepozná.
Mutaci dělej u každé nové kontroly, ne jen u bran.

### 2026-10-03 — Výsledek je „co je ve všech vzorcích stejné" (postup)
**Co se stalo:** rozhodující průlom v animacích nebyl v dekódování, ale v tom, že
jsem **porovnal první 512 B u tří různých těl a akcí** — byly bit po bitu shodné,
takže pixely nemají vlastní paletu. Tím padly tři hypotézy naráz.
**Doklad:** `research/anim-mereni.md`, `research/anim_pokryti.json`.
**Ponaučení:** když nerozumím formátu, **vezmi dva až tři vzorky a udělej rozdíl**
(stejné / různé). „Co je stejné" řekne o formátu víc než další rozbor jednoho vzorku.

### 2026-10-03 — Sandbox zablokoval pracovní složku, vypadalo to jako mrtvý nástroj (past-nástroje)
**Co se stalo:** první příkaz v session spadl na
`SetNamedSecurityInfoW failed (Win32 5): grantWrite(E:\Workspaces\game-clone)`.
Nebyla to vada projektu ani příkazu — sandbox nemohl složce přidělit práva.
**Doklad:** opraveno skriptem ze skillu `diagnose-windows-sandbox-acl`; poté
`git log` i brány běžely bez změny čehokoli v repu.
**Ponaučení:** když selže **každý** příkaz stejnou hláškou, není to kód —
načti `dsh-prostredi` a `diagnose-windows-sandbox-acl` **dřív**, než začnu hledat
chybu v datech. A `powershell.exe -ExecutionPolicy Bypass -File` je potřeba,
protože `& skript.ps1` na této stanici neprojde.

### 2026-10-03 — Brána odhalila vadu dřív než člověk (postup)
**Co se stalo:** do G6 (`check-assets.py`) jsem přidal měření manifestu animací;
hned první běh ohlásil `anim-manifest.json nemá žádné tělo` — protože `--out`
zapisoval starý formát. Vada vznikla při psaní nástroje a **našla ji brána**.
**Doklad:** `f9d143e`; po opravě G6 `OK`, souhrn `9 měřeno / 2 čekají / 0 chyb`.
**Ponaučení:** nová kontrola se vyplatí okamžitě — piš ji **zároveň** s nástrojem,
ne až po něm. A když brána hlásí vadu hned po přidání, je to důkaz, že měří.

### 2026-10-03 — `git ls-files`, ne `Test-Path` (past-nástroje)
**Co se stalo:** ověřoval jsem, že nové soubory jsou v gitu, a `.gitignore`
s vzorem `*.idx`/`*.mul` je case-insensitive — tedy i `*.py` nástroj se stejným
jménem může tiše vypadnout.
**Doklad:** `git check-ignore -v tools/uoextract/anim.py` → nenalezeno (exit 1);
`git ls-files tools/uoextract/` → `anim.py` tam je.
**Ponaučení:** „soubor existuje" neznamená „je v commitu". Po každém novém souboru
pustit `git ls-files <cesta>`; `check-ignore` je rychlá předzvěst.

---

## Vytvořené nástroje (co, kde a čím ověřené)

| Nástroj | K čemu | Ověření |
|---|---|---|
| `tools/uoextract/anim.py` | zdroj animací (`anim.mul` vs `AnimationFrame*.uop`), tabulky framů | `--self-test` 22 kontrol, `--verify` 22 kontrol proti instalaci |
| `research/probe/anim_pokryti.py` | reprodukovatelné měření pokrytí těl | dává 270 / 318 těl, prunik 2 — zapsáno v `research/anim-mereni.md` |
| `tools/gates/check-assets.py` (G6) | nově měří i manifest animací | `--self-test` 4 případy; běh nad repem `OK` |
| `tools/gates/run-all.py --self-test` | nově pouští i `anim.py` | 19 self-testů (10 bran + 9 extrakčních nástrojů), 0 chyb |
