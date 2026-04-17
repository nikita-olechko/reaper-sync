@echo off
setlocal enabledelayedexpansion

:: Define the target subpath
set "subpath=\REAPER\UserPlugins\reaper-plugins"
set "drives=C D E F"
set "drivesDisplay=C:, D:, E:, F:"
set "foundDrive="

:: Loop through drive letters C, D, E, F
for %%D in (%drives%) do (
    if exist "%%D:%subpath%\" (
        set "foundDrive=%%D"
        goto :found
    )
)

:notfound
echo [ERROR] REAPER folder not found on configured drives: %drivesDisplay%
pause
exit /b 1

:found
echo Found REAPER on %foundDrive%:
cd /d "%foundDrive%:%subpath%"
if errorlevel 1 (
    echo [ERROR] Failed to change directory to %foundDrive%:%subpath%
    pause
    exit /b 1
)

echo Starting git pull in: %CD%
git pull
if errorlevel 1 (
    echo.
    echo [ERROR] git pull failed.
    pause
    exit /b 1
)

echo.
echo Sync complete.
pause
