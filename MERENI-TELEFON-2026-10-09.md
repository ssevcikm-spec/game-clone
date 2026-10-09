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
