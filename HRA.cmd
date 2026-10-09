@echo off
rem ============================================================================
rem  HRA.cmd - spusteni herniho okna UO klonu (lokalne, bez Godot editoru)
rem ----------------------------------------------------------------------------
rem  CO TO JE: dvojklikem, nebo z konzole, se otevre herni okno s mapou Britainu
rem  a postavou, ktera chodi po sipkach nebo numpadu 1-9. Dnesni stav dema i
rem  konzolovy postup spusteni je v HANDOFF.md, sekce DEMO JE NA SVETE.
rem
rem  DVE VEci, KTERE SE TU RESI - bez nich to "nejde spustit":
rem   1. Godot binarka je v .cache\godot\ a cela slozka .cache je v .gitignore.
rem      Kdo ji nema, dostane presnou adresu, kam ji dat, a skript ji umi
rem      stahnout z oficialniho GitHub release.
rem   2. user:// - ukladani a logy - smeruje pres APPDATA do workspace. Kdyz se
rem      APPDATA necha systemu, Godot pise do sveho profilu a v sandboxu to
rem      spadne na "Could not open 'user://' directory", past 31 v HANDOFF.md.
rem
rem  POZOR: hra potrebuje assets\uo\ - extrahovana data z instalace UO. Ta jsou
rem  v .gitignore, takze v cerstvem klonu nejsou. Skript to rekne a nabidne
rem  extrakci. Bez nich se okno otevre, ale mapa bude prazdna.
rem
rem  DULEZITE PRI EDITACI: kazdy `echo` uvnitr bloku `if (` nebo `for (` musi
rem  mit escapovane zavorky `^(` a `^)`. Neescapovana zavorka v echo uvnitr
rem  bloku shodi cely skript hlaskou "X was unexpected at this time" - a to
rem  i kdyz je text cesky a v uvozovkach.
rem ============================================================================
setlocal EnableDelayedExpansion
cd /d "%~dp0"

set "HRA=%~dp0"
set "GODOT=%HRA%.cache\godot\Godot_v4.7.2-stable_win64_console.exe"
set "GODOT_VERZE=4.7.2-stable"
set "GODOT_URL=https://github.com/godotengine/godot/releases/download/%GODOT_VERZE%/Godot_v%GODOT_VERZE%_win64.zip"

rem --- 1) Godot: najdi, nebo rekni kam -------------------------------------
if not exist "%GODOT%" if not "%GODOT_BIN%"=="" if exist "%GODOT_BIN%" set "GODOT=%GODOT_BIN%"

if not exist "%GODOT%" (
  echo.
  echo CHYBA: Godot nenalezen.
  echo   Hledal jsem: "%GODOT%"
  echo.
  echo Godot %GODOT_VERZE% patri sem:
  echo   .cache\godot\Godot_v%GODOT_VERZE%_win64_console.exe
  echo Cela slozka .cache je v .gitignore, takze v cerstvem klonu neni.
  echo.
  set /p "ODPOVED=Stahnout ji ted z oficialniho GitHub release? [a/N] "
  if /i "!ODPOVED!"=="a" (
    echo Stahuji %GODOT_URL%
    if not exist "%HRA%.cache\godot" mkdir "%HRA%.cache\godot"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%GODOT_URL%' -OutFile '%HRA%.cache\godot\godot.zip' -UseBasicParsing } catch { Write-Host ('CHYBA stahovani: ' + $_.Exception.Message); exit 1 }"
    if errorlevel 1 goto :stahovani_selhalo
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%HRA%.cache\godot\godot.zip' -DestinationPath '%HRA%.cache\godot' -Force"
    del "%HRA%.cache\godot\godot.zip" >nul 2>nul
    echo Rozbaleno do .cache\godot - kdyby se soubor jmenoval jinak, prejmenuj ho na:
    echo   Godot_v%GODOT_VERZE%_win64_console.exe
  ) else (
    goto :konec_chyba
  )
)

if not exist "%GODOT%" (
  echo.
  echo CHYBA: Godot porad neni na "%GODOT%" - okno nespustim.
  goto :konec_chyba
)

rem --- 2) user:// do workspace - sandbox a reprodukovatelnost ---------------
set "USERDATA=%HRA%.cache\godot-appdata"
if not exist "%USERDATA%\Godot\app_userdata" mkdir "%USERDATA%\Godot\app_userdata"
set "APPDATA=%USERDATA%"
set "XDG_DATA_HOME=%USERDATA%"

rem --- 3) data z instalace UO - bez nich je mapa prazdna --------------------
if not exist "%HRA%assets\uo\world" (
  echo.
  echo POZOR: chybi assets\uo\world, mapa bude prazdna.
  echo   Extrakce z instalace UO:
  echo     python tools\uoextract\worldmap.py --extract assets\uo\world
  echo   Dalsi data: python tools\gates\gen-content.py
  echo.
)

rem --- 4) spusteni ---------------------------------------------------------
echo Spoustim UO klon - Godot %GODOT_VERZE%, okno 1600x900, opengl3
echo   sipky nebo numpad 1-9 = chuze, jedno zmacknuti = jeden krok
echo   F2 = fullsize (svet pres cele okno, bez cerneho pasu GUI)
echo   F3 = debug overlay (lokace, zoom, fps, spicka frame casu)
echo   Esc = zavrit okno
echo   APPDATA ^(user://^) = %USERDATA%
echo.
rem ⚠ 2026-10-09 (bod 5.2): rozliseni je 1600x900 a `project.godot` ma
rem `stretch/mode=disabled`, takze platno = okno a vetsi okno PRIDAVA svet.
rem Kdo si hru zvetsi (maximalizuje), uvidi vic mapy - coz je zadani uzivatele.
"%GODOT%" --path "%HRA%." --rendering-driver opengl3 --resolution 1600x900 %*
set "KOD=%ERRORLEVEL%"
if not "%KOD%"=="0" (
  echo.
  echo Hra skoncila s kodem %KOD%.
  echo Kdyz chybi importovane assety, pomuze:
  echo   "%GODOT%" --headless --path "%HRA%." --import
  goto :konec_chyba
)
endlocal
exit /b 0

:stahovani_selhalo
echo.
echo Stazeni selhalo. Stahni Godot %GODOT_VERZE% rucne z:
echo   https://github.com/godotengine/godot/releases/tag/%GODOT_VERZE%
goto :konec_chyba

:konec_chyba
echo.
pause
endlocal
exit /b 1
