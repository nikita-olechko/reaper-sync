@echo off
setlocal enabledelayedexpansion

:: Define the target subpath
set "subpath=\REAPER\UserPlugins\reaper-plugins"
set "foundDrive="

:: Loop through drive letters C, D, E, F
for %%D in (C D E F) do (
    if exist "%%D:!subpath!\" (
        set "foundDrive=%%D:"
        goto :found
    )
)

:notfound
echo [ERROR] REAPER folder not found on drives C, D, E, or F.
pause
exit /b

:found
echo Found REAPER on %foundDrive%
cd /d "%foundDrive%%subpath%"

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
