extends RefCounted
# Herni konstanty na jednom miste - jediny zdroj pravdy pro cisla sveta.
#
# Odkud hodnoty jsou (nevymyslene):
#   docs/04 §4.2 ... tabulka komponenty `core.const`
#   docs/02 §2.4 ... TILE_W/TILE_H/ISO_STEP/Z_SCALE/Z_MIN/Z_MAX
#   docs/05 §5.11 .. DAY_LENGTH_MS (den = 7200 s = 2 h realneho casu)
#
# Pravidla:
#   * zadna hodnota se nesmi objevit dvakrat v projektu - kdo ji pouziva,
#     preloaduje tento soubor (G1 to hlida),
#   * cas v ms (int), skilly v desetinach (int), pozice v dlazdicich (int).
#     Float ve stavu je drift (docs/01 §1.5.3), proto jsou vsechny int.

# -- izometrie a svet (docs/02 §2.4) ---------------------------------------
const TILE_W: int = 44          # sirka artu dlazdice
const TILE_H: int = 44          # vyska artu dlazdice
const ISO_STEP: int = 22        # posun po jedne ose dlazdice v px (TILE_W/2)
const Z_SCALE: int = 4          # pixelu na jednotku svetove vysky z
const Z_MIN: int = -128         # rozsah z jako v datech UO
const Z_MAX: int = 127
const BLOCK_SIZE: int = 8       # svet se nacita i kresli po blocich 8x8 dlazdic
const MAP_WIDTH: int = 7168     # faceta 0 (Felucca), docs/01 §1.4
const MAP_HEIGHT: int = 4096

# -- cas (docs/02 §2.3) ----------------------------------------------------
const TICK_MS: int = 50         # pevny tick simulace (20 Hz)
const DAY_LENGTH_MS: int = 7200000  # herni den = 7200 s (SecondsPerUOMinute = 5.0)

# -- pohyb (docs/05 §5.1) --------------------------------------------------
const WALK_MS: int = 400        # chuze pesky
const RUN_MS: int = 200         # beh pesky
const MOUNT_WALK_MS: int = 200  # chuze na mountu
const MOUNT_RUN_MS: int = 100   # beh na mountu
const TURN_MS: int = 80         # otoceni na miste (a frame animace)

# -- postava a predmety ----------------------------------------------------
const PERSON_HEIGHT: int = 16   # vyska postavy ve svetovych jednotkach
const STEP_HEIGHT: int = 2      # max. schod, ktery se da vyjit
const LIFT_RANGE: int = 2       # dosah zvednuti a položení (dlazdice)
const MAX_STACK: int = 60000    # max. mnozstvi v jednom stacku
const CONTAINER_MAX_ITEMS: int = 125
const CONTAINER_MAX_WEIGHT: int = 400  # stones

# -- skilly a staty (desetiny) --------------------------------------------
const SKILL_CAP: int = 7000     # 700.0 v desetinach
const STAT_CAP: int = 225
const SKILL_STEP: int = 1       # +0.1 za uspesne pouziti
