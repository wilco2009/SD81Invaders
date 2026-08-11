@echo off
rem =============================================================
rem  Space Invaders - ZX81 + SD81 Booster
rem  Ensambla src\invaders.asm y deja INVADERS.BIN en la raiz,
rem  listo para copiar a la microSD.
rem =============================================================
setlocal

if "%ZMAC%"=="" set ZMAC=C:\zmac\zmac.exe

if not exist "%ZMAC%" (
    echo No se encuentra zmac en "%ZMAC%".
    echo Define la variable ZMAC con la ruta al ejecutable.
    exit /b 1
)

pushd "%~dp0src"
"%ZMAC%" invaders.asm
if errorlevel 1 (
    popd
    echo.
    echo *** Error de ensamblado ***
    exit /b 1
)
popd

copy /y "%~dp0src\zout\invaders.cim" "%~dp0INVADERS.BIN" >nul
echo.
echo INVADERS.BIN generado.
for %%F in ("%~dp0INVADERS.BIN") do echo Tamano: %%~zF bytes

rem --- copia a la SD virtual del emulador, si existe ---
if "%SD81DIR%"=="" set SD81DIR=C:\ClaudeCode\Eightyone2\EightyOne\SD81\INVADERS
if exist "%SD81DIR%\" (
    copy /y "%~dp0INVADERS.BIN" "%SD81DIR%\INVADERS.BIN" >nul
    echo Copiado a %SD81DIR%
) else (
    echo SD virtual no encontrada en %SD81DIR% - copia omitida.
)
