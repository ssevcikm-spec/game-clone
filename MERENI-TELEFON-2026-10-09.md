# Měření telefonu a rozhodnutí hostingu — 2026-10-09

> **Co je tenhle soubor:** **záznam o provedení** (měření a rozhodnutí) — je
> datovaný, **nepřepisuje se**; nová měření se přidávají jako další blok s datem.
> **Zadání:** [`ZADANI-22-TELEFON-A-HOSTING.md`](ZADANI-22-TELEFON-A-HOSTING.md).
> **Analýza, ze které se vycházelo:** `NAVRH-BRAN-FEEL-2026-10-09.md` §6.
> **Současný stav projektu je v `HANDOFF.md`** (ten se přepisuje každou session).
> **Datum měření:** 2026-10-09, **18:29–19:05 SELČ**.
> **Nic ve hře se tím nezměnilo** — kvůli tomuhle zadání nebyl upraven žádný
> soubor hry; měnily se jen `~/.ssh/config` (se souhlasem uživatele) a telefon.

**Zařízení:** Redmi Note 8 (ginkgo, Snapdragon 665), LineageOS 23.2 / Android 16,
root (Magisk 30.7), Termux 0.118.3 + OpenSSH, **IP 192.168.109.104** (staticky
v telefonu). Stav flashe/rootu/SSH/limitu nabíjení je v
`C:\Users\Ssevc\Local-Deepseek\redmi-server\STAV.md` — **převzat od paralelní
session, neopakován** (souběh: práce té session se nedotýkala).

**Výchozí past, která se potvrdila:** `Host cetnik` v `~/.ssh/config` mířil na
`192.168.109.101` = **tuhle stanici** (a `User root`, což na telefonu dnes nejde).
Telefon je dosažitelný jako **`redmi`** (`192.168.109.104:8022`, `u0_a155`,
klíč `redmi_server_ed25519`) — výsledek paralelní session. `cetnik` byl
**se souhlasem uživatele smazán** (záloha `~/.ssh/config.bak-2026-10-09-cetnik`).

---

## 1. Tabulka naměřených čísel

| # | Co | Příkaz (kde) | Hodnota | Poznámka |
|---|---|---|---|---|
| 1 | Dosažitelnost | `ssh redmi "uname -a"` | exit 0, `aarch64` | kernel `4.14.357-openela-perf-g77d2912bc00e` |
| 2 | Jádra — **není konstanta** | `nproc`, `nproc --all`, `grep Cpus_allowed_list /proc/self/status` | app **4** (18:29–18:33), **6** (19:05); maska `0-2,5-7`; `--all` 8 | **root (magisk): 8** jader, maska `0-7`, i uvnitř chrootu |
| 3 | Frekvence CPU | `cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_max_freq` | cpu0–3 **1,8048 GHz**, cpu4–7 **2,016 GHz** | 8 jader v `/proc/cpuinfo` |
| 4 | Paměť | `free -m` | total **3627 MB**, used 1887–1933, **available 1345–1453 MB** | swap (zram) **3071 MB**, ~0–284 použito |
| 5 | Disk | `df -h /data` | **107 GB**, použito 4,1 GB, **volných 103 GB (4 %)** | varianta 128 GB |
| 6 | Zátěž | `uptime` | **0,94–1,17** (idle 18:29) → **5,82** (po testech 19:05) | `cat /proc/loadavg` je app doméně zakázán |
| 7 | Teplota | `cat /sys/class/thermal/thermal_zone{26,29}/temp` | CPU **30–34 °C** (idle) → **60–64 °C** (po zátěži) | zóny `cpu-1-*-usr`; jiné zóny mají nesmysly (69, 156, −40000) |
| 8 | Baterie | `dumpsys battery`, `cat /sys/class/power_supply/battery/*` | **69 % → 61 %** za 36 min; `status: Discharging`; **`AC powered: false`** | telefon **nebyl zapojený**; 790 cyklů (paralelní session); teplota 26,2 → 30,5 °C |
| 9 | **Engine fit** | `Godot_v4.7.2-stable_linux.arm64 --headless --version` (chroot) | **`4.7.2.stable.official.ed1daf0bf`, exit 0, <1 s** | SHA256 zipu ověřen: `5dd0d864…` |
| 10 | **Naše testy** | `--import` → `--script res://tests/run_tests.gd` (replikace `tools/gates/ci-godot.sh`) | **61/61 case souborů, 1466 kontrol, 0 selhání, exit 0, 28 s** | import 19 s; **bez `assets/uo`** (art se na server nekopíruje — licence); PC s artem 1507/0 dle `PREDANI-SESSION-2026-10-09.md` |
| 11 | LAN propustnost telefon→PC | `ssh redmi "dd if=/dev/zero bs=1M count=100"` | 100 MB / 4,24 s = **23,6 MB/s = 189 Mbit/s** | směr, kterým server posílá stav |
| 12 | Internet (domácí linka) | `curl` na `speed.cloudflare.com` | download **8,80 MB/s (70 Mbit/s)**, upload **3,02 MB/s (24 Mbit/s)** | |
| 13 | WiFi | `adb shell dumpsys wifi` | SSID **„Sevcikovi"**, RSSI **−39…−48 dBm**, link **433 Mbps**, kanál 15 % | adresa staticky v telefonu (riziko: leží v DHCP rozsahu) |
| 14 | **NEMĚŘENO** | — | **tik ≤ 2 ms**, **soak 24 h**, **upload/NAT zvenčí**, směr PC→telefon | tik nemá sondu; server se neprovozuje; zvenčí se nikdo neptal; pokus o PC→telefon selhal (`dd` není na Windows) a byl **zahozen** |

## 2. Jak se k bodu 9 došlo (a co na cestě nefunguje)

`godot --headless --version` **v Termuxu** → `command not found` (exit 127);
Godot **na zařízení nebyl** (root `find` nad `/data`, `/system`, `/sdcard`, `/apex`).
V repu Termuxu **není** (pozitivní kontrola: `apt-cache search openssh` i `curl`
něco vrátí, `godot` nic). Cesta tedy vede přes kontejner:

1. **`proot-distro` + Ubuntu 24.04 NEFUNGUJE.** Bash v kontejneru naběhne (builtin
   `echo` jde), ale **první externí příkaz se zacyklí**: `/bin/echo` → proces ve
   stavu `t (tracing stop)`, **1 556 172 voluntary ctxt switchů**, 6 min CPU
   a **žádný výstup**. Příčina doložená měřením i zdrojem: Ubuntu 24.04 má
   **glibc 2.43** (procesy vytváří přes `clone3()`), Termux má **proot
   5.1.107.96 (2021)**, který `clone3` neumí — opraveno až v
   [PRoot v5.4.1, 2026-09-09](https://proot-me.github.io/blog/2026-09-09-v5.4.1-release/).
   `PROOT_NO_SECCOMP=1` nepomohlo; čistý `proot` s Termux (bionic) binárkou
   funguje → vada je **proot × glibc**, ne proot × jádro.
2. **Řešení, které funguje: `chroot` pod rootem** (`adb shell su -c`, Magisk):
   mounty `proc`/`dev`/`sys`/`dev/shm` zvenčí + `chroot <rootfs> /bin/bash …`.
   Po měření **odmountováno** (192 → 0 záznamů v `/proc/mounts`) a tempy uklizeny.
3. **Dvě pasti při přenosu** (obě stály kolo): **tar proteklý rourou
   PowerShell→ssh se rozbil** (4 597 503 B místo správných 4 533 760 B) → posílat
   **souborem přes `scp`** a ověřit **sha256 na obou koncích**; a **co rozbalí root
   (mód 0700), Termux už nepřepíše** → projekt rozbalovat **Termuxem**, rootem jen
   uklízet/mazat.
4. **První běh testů dal 1424/13** — všech 13 selhání bylo z **chybějících souborů,
   které jsem nekopíroval** (`docs/05-mechaniky.md`, `research/02-skills.md`,
   `.forge/roadmap.json`), **ne z telefonu**. Po doplnění: **1466 / 0**.

## 3. Rozhodnutí role telefonu

> **Telefon = `hostitel LAN session` pro 2–4 hráče (podmíněně); `always-on`
> i veřejný server = NE.**

**Proč to z čísel vyplývá:** engine fit je **prokázaný** (Godot 4.7.2 ARM64
i celá naše testovací sada: 61/61 case souborů, 0 selhání, 28 s), LAN propustnost
**189 Mbit/s** a stabilní adresa stačí pro session; proti `always-on` mluví
**1,3–1,5 GB volné RAM**, **60–64 °C** při krátké zátěži, jádra jen **4–6** pro app
doménu (a **mění se v čase**), **start serveru vyžaduje chroot pod rootem** (proot
cestou to dnes nejde) a domácí **upload 24 Mbit/s za NAT**.

**Co to nemění:** rozhodnutí `D9` platí dál — první multiplayer je session
u hostitele, `always-on` je odložený. Tenhle záznam mění jen to, že **hosting už
není jen analýza: má čísla**.

## 4. Co zůstalo na telefonu (uživatel to schválil) a cesta zpět

| Co | Velikost | Cesta zpět |
|---|---|---|
| `proot-distro` + Ubuntu 24.04 | 1,6 GB | `proot-distro remove ubuntu` |
| Godot 4.7.2 ARM64 + projekt bez artu | 138 MB + 99 MB | `rm -rf …/containers/ubuntu/rootfs/root/{godot,game-clone}` |
| skripty `run-godot.sh`, `run-tests.sh` v kontejneru | <2 kB | `rm` |

**Co zůstává NEMĚŘENO a co k tomu chybí:** **tik ≤ 2 ms** (chybí sonda nad `sim` —
teď už je na čem měřit), **soak 24 h** (server se neprovozuje), **upload/NAT
zvenčí** (bez dotazu z internetu je to dohad).

---

# DODATEK 2026-10-09 (dokončení zadání: tik, soak a dvě meze telefonu)

> **Dopsáno tentýž den po prvním zápisu.** První verze tvrdila u prootu
> „**příčina doložená**: `clone3`" — **experiment ji vyvrátil** (viz §8).
> Původní text se needituje, oprava je v §8. Body 3 a 4 ze `ZADANI-22`
> už **NEMĚŘENO nejsou**.

## 5. Tik ≤ 2 ms (ZADÁNÍ bod 3) — NAMĚŘENO

Sonda [`_analyza/p32-telefon-tik.gd`](_analyza/p32-telefon-tik.gd) (na telefonu
běžela z `res://.tmp/probe/tick_probe.gd`): 200 tiků po 50 ms na každé N, 30 tiků
zahřátí, fixture mapa, **stub tiledata/doors/stairs**, každý mobil dostane každý
tik příkaz k chůzi, `--headless`. **Stejný soubor na PC i na telefonu.**

| N mobilů | telefon (aarch64, chroot) | PC (Ryzen 5 2600, x86_64) | poměr |
|---|---|---|---|
| 0 | **1,42 ms** (p95 1,52) | 0,46 ms | 3,1× |
| 1 | 1,45 ms | 0,47 ms | 3,1× |
| **37** | **2,27 ms** (p95 2,51) | 0,82 ms (p95 1,43) | 2,8× |
| 200 | 5,90 ms | 2,53 ms | 2,3× |
| 1000 | 22,5 ms | 11,2 ms | 2,0× |

Dva běhy na telefonu se shodují na **0,1 %**. `state_hash()` (cena snapshotu):
1 mobil 1,18 ms · 37 mobilů **39,9 ms** · 200 mobilů 214 ms · 1000 mobilů 1 080 ms
(na PC 0,53 / 17,2 / 92 / 458 ms).

**Co z toho plyne:**
* Rozpočet **tik ≤ 2 ms** telefon plní **jen do ~25 mobilních entit**: i prázdný
  tik stojí **1,42 ms** (71 % rozpočtu) a každý mobil přidá ~**0,023 ms**.
* Při **37 mobilech** („aktivní okno" z analýzy) je tik **2,27 ms = o 14 % nad
  rozpočtem** — ale jen **4,5 % z 50ms slotu**, takže reálný čas to stíhá.
* **`state_hash()` nesmí běžet každý tik** (39,9 ms při 37 mobilech) — patří
  k uložení/replayi, ne do smyčky. Platí na obou strojích.
* **Bonus:** hashe stavu jsou na ARM64 **shodné s x86_64** (`a6ef58dc…`,
  `11ad0714…`, `16e7e971…`, `9d93a854…`, `d3b1685d…` pro N = 0/1/37/200/1000)
  → determinismus simulace **není vázaný na architekturu**.

## 6. Soak (ZADÁNÍ bod 4) — 20 minut, NE 24 h

[`_analyza/p33-telefon-soak.gd`](_analyza/p33-telefon-soak.gd) (na telefonu
běžela z `res://.tmp/probe/soak.gd`): 37 mobilů, 20 Hz, reálné tempo, uložení
každých 5 min, externí vzorkování každou minutu (RSS, MemAvailable, load, teplota,
baterie).

| Co | Naměřeno (20 min, 22:01–22:21 SELČ) |
|---|---|
| Tiky | **23 214** v 1 170 s = **19,84 Hz** (tempo drží) |
| Paměť Godotu | **static 25,3 MB / peak 30,1 MB — PLOCHÉ celých 20 min** |
| RSS procesu | **99 484 kB — ploché** (posledních 9 vzorků) |
| Volná paměť telefonu | 1,48–1,57 GB (během zátěže) |
| Teplota CPU | **58–68 °C** (zóny `cpu-1-*-usr`); idle 28–34 °C |
| Load average | 3,3–5,4 (část okna běžely dva Godoty — viz níže) |
| Uložení světa | 4× `save()`, **78–115 ms**, soubor ~1 970 B |
| Zabití procesu | **žádné** (`dmesg`: žádné „Killed process"/OOM) |
| Baterie | **70 % a `Not charging` celou dobu** — limit nabíjení drží i v zátěži |

**⚠ Dvě vady, které jsem udělal sám (obě měnily měření):**
1. **První běh soak-a měřil moji chybu:** `sim.tick()` plní frontu událostí a já ji
   nevypouštěl → paměť rostla ~1 MB/s (RSS 152 → 337 MB za 4 min). Po přidání
   `sim.drain_events()` je paměť plochá (25,3 MB). **Bez té opravy by soak za ~20 min
   spadl na OOM a vypadalo by to jako vada telefonu.**
2. **`pkill -f proot` zabil i soak** — cesta kontejneru obsahuje `proot-distro`,
   takže vzor „proot" zabral obal `chroot` a **vnitřní Godot zůstal jako sirotek**
   (kill obalu vnitřní proces nezabije). Správně `pkill -x proot` nebo vzor
   s hranatou závorkou (`[s]oak.gd`). **Pro always-on z toho plyne: řízení procesů
   musí zabíjet i vnitřní proces, ne jen obal.**

**24 h NEMĚŘENO** — `always-on` je odložený; 20 minut je **proxy**, ne náhrada.

## 7. Dvě meze telefonu, naměřené mimoděk (obě důležité pro always-on)

* **Build na telefonu zabil Termux.** Pokus postavit proot 5.5.0 ze zdroje
  (`make -j4`, 4× clang) skončil **OOM**: SSH vypadlo, Termux app zmizela
  (`ps -A` → 750 procesů, žádný termux), v `logcat` série „OOM killer
  enabled/disabled". `device_config max_phantom_processes` i
  `settings_enable_monitor_phantom_procs` jsou **nedotčené (`null`)** → byl to
  **lowmemorykiller, ne phantom limit**. Telefon jsem vrátil **rebootem**;
  autostart SSH fungoval sám (uptime 0 min → SSH OK za ~30 s), kontejner, Godot
  i projekt restart **přežily**. → **Telefon není místo pro souběžné těžké úlohy**
  (build/CI), aniž by to shodilo běžící služby.
* **Limit nabíjení drží i v zátěži:** 70 % / `Not charging` po celých 20 minut
  zatížení (nezávislé potvrzení brány paralelní session).

## 8. OPRAVA: proot nejde ani s glibc 2.31 → domněnka o `clone3` je VYVRÁCENA

První verze (§2 bod 1) tvrdila jako **doloženou příčinu**, že Ubuntu 24.04 má
glibc 2.43 s `clone3()`, který starý proot (5.1.107.96, 2021) nezná.
**Test to vyvrátil:**

| Test | Výsledek |
|---|---|
| `proot-distro install ubuntu:20.04 --name ubuntu2004` | OK, glibc **2.31** (`libc-2.31.so`) |
| `proot-distro login ubuntu2004 -- /bin/bash -c "uname -m; ldd --version"` | **visí** → SIGKILL po 150 s |
| `proot-distro login ubuntu2004 -- Godot… --headless --version` | Godot se **začal načítat** (vypsal varování o `libfontconfig`), ale **nedoběhl** → SIGKILL po 200 s |

**Správná formulace je slabší, ale pravdivá:** vada je v **kombinaci proot
5.1.107.96 (2021) × LineageOS 23.2 / Android 16** — ne v glibc a ne v jádře
(čistý proot s Termux bionic binárkou funguje). Upstream vydal 5.4.1 (9. 9. 2026)
a 5.5.0 (6. 10. 2026); **stavět 5.5.0 na telefonu jsem po OOM-killu Termuxu
nezkoušel** → další krok, ne hotová věc. **Ověřená cesta zůstává `chroot` pod
rootem** (proto všechny testy výše běžely tak).

## 9. Upravené rozhodnutí role (po tiku a soaku)

> **Telefon = `hostitel LAN session` pro MALÝ svět (do ~25 mobilních entit);
> `always-on` i veřejný server = NE; není to stroj na buildy.**

Co to mění proti prvnímu zápisu: engine fit a síť zůstávají dobré (Godot běží,
testy 1466/0, LAN 189 Mbit/s), ale **rozpočet `tik ≤ 2 ms` plní telefon jen pro
malý svět** (při 37 entitách je o 14 % nad ním, při 200 už 3×) a přibyla **druhá
mez**: souběžná těžká práce (build) shodí Termux (OOM). Pro `always-on` to není
jen „málo RAM", ale i **teplo 58–68 °C v trvalé zátěži**, nutnost hlídat procesy
(sirotek po zabití obalu) a start serveru přes **chroot pod rootem**. `D9` se
nemění: první multiplayer je session u hostitele, `always-on` odložený.
