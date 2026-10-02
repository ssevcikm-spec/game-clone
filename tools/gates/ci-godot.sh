#!/usr/bin/env bash
# CI: Godot s přesměrovaným user:// , importem assetů a testy (docs/02 §2.1, docs/08 §8.4).
#
# Použití:  GODOT=/cesta/godot tools/gates/ci-godot.sh [koren_projektu]
#
# Co skript dělá a proč:
#   1. přesměruje user:// do workspace (APPDATA na Windows, XDG_DATA_HOME na Linuxu) -
#      jinak Godot píše mimo projekt a "nic se neuloží", což vypadá jako vada ukládání,
#   2. spustí import (.godot/ není v gitu, v čerstvém stromu "regresují" assety),
#   3. spustí testy a PŘEDÁ jejich exit kód (0 = prošlo, 1 = selhalo, 2 = 0 kontrol),
#   4. zkusí snímek pro G10/G13; když to prostředí neumí, řekne to nahlas a neselže -
#      snímek je poradní, ale jeho absence musí být VIDĚT (docs/08 §8.4).
set -uo pipefail

GODOT="${GODOT:-godot}"
ROOT="${1:-.}"
USERDATA="${ROOT}/.cache/godot-appdata"
SNAPSHOT_DIR="${ROOT}/.cache/render"

mkdir -p "${USERDATA}/Godot/app_userdata" "${SNAPSHOT_DIR}"
export APPDATA="${USERDATA}"          # Windows
export XDG_DATA_HOME="${USERDATA}"    # Linux (godot/app_userdata/<projekt>)
export HOME="${HOME:-${USERDATA}}"

status=0

echo "== import =="
"${GODOT}" --headless --path "${ROOT}" --import || echo "POZOR: import vrátil nenulový kód (u prázdného projektu to bývá bez chyb)"

echo "== testy (G3) =="
tests_out="$("${GODOT}" --headless --path "${ROOT}" --script res://tests/run_tests.gd 2>&1)"
tests_rc=$?
echo "${tests_out}"
if [ "${tests_rc}" -ne 0 ]; then
  echo "CHYBA: testy skončily s kódem ${tests_rc}"
  status=1
fi
# Výstup a exit kód si mohou odporovat (docs/08 past 9) - čtou se oba.
# Kontrola je schválně jen ze shellu (case), ne přes grep: při prvním běhu
# 2026-10-02 grep v PATH nebyl a kontrola kvůli tomu hlásila falešnou chybu
# ("testy NEPROBĚHLY") i když testy prošly.
case "${tests_out}" in
  *kontrol,*selh*) ;;
  *)
    echo "CHYBA: ve výstupu chybí 'N kontrol, M selhání' - testy NEPROBĚHLY"
    status=1
    ;;
esac

echo "== snímek pro G10/G13 =="
snapshot="${SNAPSHOT_DIR}/snapshot.png"
rm -f "${snapshot}" 2>/dev/null || true
movie_cmd=("${GODOT}" --path "${ROOT}" --rendering-driver opengl3 --resolution 1280x720
           --write-movie "${SNAPSHOT_DIR}/frame.png" --quit-after 5)
if command -v xvfb-run >/dev/null 2>&1; then
  xvfb-run -a "${movie_cmd[@]}" >/dev/null 2>&1 || true
else
  "${movie_cmd[@]}" >/dev/null 2>&1 || true
fi
# Godot pojmenovává framy frame0000000.png apod.; pro G10 potřebujeme jednu cestu.
# Hledá se jen globem - `ls | head` selhalo, když v PATH nebyly coreutils.
first_frame=""
for candidate in "${SNAPSHOT_DIR}"/frame*.png; do
  if [ -e "${candidate}" ]; then
    first_frame="${candidate}"
    break
  fi
done
if [ -n "${first_frame}" ]; then
  cp "${first_frame}" "${snapshot}" 2>/dev/null || cp "${first_frame}" "${snapshot}.tmp" 2>/dev/null || true
  if [ -e "${snapshot}" ]; then
    echo "snímek: ${snapshot}"
  else
    echo "SKIP: snímek vznikl (${first_frame}), ale nešel zkopírovat na ${snapshot}"
  fi
else
  echo "SKIP: snímek nevznikl (chybí display/xvfb nebo --write-movie) - G10 zůstane NEMĚŘENO"
fi

exit "${status}"
