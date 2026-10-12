@echo off
rem ============================================================================
rem  DAVKA.cmd - spusti davku prace pro PEAK hodiny DeepSeeku.
rem ----------------------------------------------------------------------------
rem  CO TO JE: obal nad `tools\davka.py`. Davka jen MERI - nemeni zdrojove
rem  soubory. Logy jdou do `.cache\davka\`, souhrn do `.cache\davka\souhrn.json`.
rem
rem  PROC VE SPICCE: cena tokenu je ve spicce dvojnasobna, ale jen za to, co
rem  projde modelem. Stroj muze pracovat dal - viz skill `dsh-peak-uspory`.
rem
rem  ARGUMENTY se predavaji dal: --dry, --rychle, --only <text>.
rem  Pozn.: text zamerne bez diakritiky - .cmd se v ruznych kodovych strankach
rem  rozbiji a chyba pak vypada jako vada skriptu, ne jako kodovani.
rem ============================================================================
setlocal
cd /d "%~dp0"
python tools\davka.py %*
