# ZADÁNÍ 22 — telefon a hosting: změřit a rozhodnout, kde poběží malý multiplayer

> **Co je tenhle soubor:** **zadání** (záznam o tom, co se zadalO) — nepřepisuje
> se. Vzniklo 2026-10-09 z rozhodnutí uživatele (`ROZHODNUTI-2026-10-09-SMER.md`
> §2 D9: „obojí, `always-on` odložené"). **Současný stav projektu je
> v `HANDOFF.md`**, analýza hostingu v `NAVRH-BRAN-FEEL-2026-10-09.md` §6.
> **Pracovní složka: `E:\Workspaces\game-clone`.**

## 1. Cíl

Odpovědět **číslem**, ne dojmem, na jedinou otázku: **může Xiaomi Redmi Note 8
(nebo Oracle uzel) dělat herní server pro malý multiplayer — a pro kterou roli?**
Uživatel 2026-10-09 hlásí „server už je nastaven" (telefon), ale **číslo k tomu
nikdo nepředal**.

## 2. Naměřená fakta (stav k 2026-10-09, neopakuj je — navazuj)

* **Telefon = Redmi Note 8** (ginkgo, SM6125, 3/4/6 GB RAM, eMMC/UFS):
  `Android (flashnutý, root) + Termux + Ubuntu proot + PM2`, běží na něm
  Telegram bot. Dokumenty: `C:\Users\Ssevc\Local-Deepseek\dsh-consolidation\server-harness\server-setup-report.md`
  (stav 15. 9. 2026) a `C:\Users\Ssevc\Local-Deepseek\research\redmi-note8-server-2026.md`
  (tam naměřeno: **postmarketOS na tomhle telefonu nemá WiFi/3D/USB networking** →
  poctivý Linux není cesta, zůstává Android; ve 4GB variantě reálně 1,5–2,5 GB volných).
* **`Host cetnik` v `C:\Users\Ssevc\.ssh\config` je ZASTARALÝ:** míří na
  `192.168.109.101:8022`, a tuhle adresu má **dnes tato stanice sama**
  (`Get-NetIPAddress`). Při kontrole 2026-10-09 byl telefon na té adrese
  nedostupný a na LAN nebyl žádný host s SSH (8022/22) → **NEMĚŘENO**.
  Soubor patří uživateli — opravit ho smí jen on (nebo s jeho souhlasem).
* **`oracle-frankfurt`** = Oracle Cloud **ARM** (`linux arm64 …-oracle`), živý
  uzel orchestra; má Godot 4.7.2, Python 3.12.3, Node 18.19.1; kinds `test,build`.
  **Conductor tam neběží** — je to Cloudflare Worker; Oracle je *výpočetní* uzel.
* Co server potřebuje (změřeno v repu): mapa (29,36 M land dlaždic, statiky
  20,4 MB + 458 752 index entries), data JSON ~6 MB, rozpočet **tik ≤ 2 ms
  v 50ms slotu**, **art zůstává na klientech** (server nesmí šířit EA assety —
  `docs/03` §3.1).
* **Rozhodnutí, které platí:** první multiplayer je **session u hostitele**;
  `always-on` je odložený. Pravidlo: hodiny světa bydlí v simulaci a „offline"
  = bez připojeného klienta. **Nic z toho se tímhle zadáním nemění.**

## 3. Co změřit (a co to rozhodne)

| # | Měření | Jak | Co to rozhodne |
|---|---|---|---|
| 1 | **Dosažitelnost** | aktuální IP telefonu (uživatel), `ssh -o BatchMode=yes -o ConnectTimeout=8 <ip> "uname -m; nproc; free -m; df -h /data"` | jestli se na něj vůbec dá sahat |
| 2 | **Engine fit** | `godot --headless --version` a spuštění **našeho** `tests/run_tests.gd` pod proot Ubuntu | klíčová neznámá: běží headless Godot 4.7 ARM64 v proot? |
| 3 | **Tik** | sonda se simulací, N entit, měření ms/tick | drží rozpočet ≤ 2 ms? |
| 4 | **Soak 24 h** | RSS, load, teplota, `pm2 jlist` (restarty), záznamy o zabití procesu | přežije to jako always-on uzel? |
| 5 | **Síť** | upload, chování po výpadku WiFi, stabilita adresy (NAT?) | veřejný server, nebo jen LAN/VPN |

## 4. Required výstup

1. **Tabulka naměřených čísel** k bodům 1–5 (u každého uveď příkaz a čas měření;
   co nešlo změřit, napiš **NEMĚŘENO** — nula a prázdno nejsou úspěch).
2. **Rozhodnutí role telefonu** jednou větou: *hostitel session* / *always-on
   pro LAN* / *nevhodný* — s odůvodněním z čísel.
3. **Zápis** do `HANDOFF.md` a do `ROZHODNUTI-2026-10-09-SMER.md` §6.9 (hosting
   přestane být „analýza" jen tehdy, když k tomu budou čísla).
4. **Nic ve hře se nemění** — žádný kód `game-clone` se tímhle zadáním neupravuje.

## 5. Co NEDĚLAT

* **Nestavět always-on server** — uživatel ho odložil; tohle zadání jen měří
  a rozhoduje, neprovozuje.
* **Nezasahovat do práce paralelní session** (ta telefon nastavovala) — její
  výsledky **převezmi**, neopakuj. Když nejsou k dispozici, napiš to a zeptej se.
* **Neměnit `~/.ssh/config`** ani nic neinstalovat na telefon bez výslovného
  souhlasu uživatele (jsou to jeho zařízení a jeho konfigurace).
* **Neslibovat veřejný server** — bez čísel o uploadu a NAT je to slib.
* **Nezapisovat do `assets/`** ani nekopírovat art na server (licence).

## 6. Jak to ověřit

```powershell
# 1) ověř, že telefon je na síti (nespoléhej na zastaralý alias)
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' }
Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.*' }
# 2) po připojení: uname -m; nproc; free -m; uptime   → ulož čísla i s časem
# 3) teprve pak engine fit: godot --headless --version  (na telefonu)
```

## 7. Pick up here

**Nejdřív si vyžádej aktuální IP telefonu od uživatele** (dnešní `cetnik`
v `~/.ssh/config` vede na tuto stanici) a teprve pak měř. První měření, které
má cenu: **`godot --headless --version` na telefonu** — když Godot pod proot
nenaběhne, je zbytek měření jedno a odpověď je „telefon na herní server nestačí".
