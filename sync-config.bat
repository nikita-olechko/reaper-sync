@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Bring console window to foreground
title REAPER Config Sync
echo Set objShell = CreateObject("WScript.Shell") > "%temp%\activate.vbs"
echo objShell.AppActivate "REAPER Config Sync" >> "%temp%\activate.vbs"
cscript //nologo "%temp%\activate.vbs" >nul 2>&1
del "%temp%\activate.vbs" >nul 2>&1

set "scriptDir=%~dp0"
set "mappingFile=%scriptDir%sync-mappings.txt"
set "drives=C D E F"
set "drivesDisplay=C:, D:, E:, F:"

rem Find REAPER installation
call "%scriptDir%find-reaper.bat" "%drives%"
if %REAPER_FOUND% EQU 0 (
    echo [ERROR] REAPER folder not found on configured drives: %drivesDisplay%
    echo [ERROR] Also checked one level down in root folders of each drive
    pause
    exit /b 1
)

set "reaperRoot=%REAPER_ROOT%"

if not exist "%mappingFile%" (
    echo [ERROR] Mapping file not found: %mappingFile%
    pause
    exit /b 1
)

echo Found REAPER at: %reaperRoot%
echo Using mappings from: %mappingFile%
echo.

rem Update this script repository first (if it's a git repository)
if exist "%scriptDir%.git\" (
    echo [UPDATE] Pulling latest changes in script directory...
    pushd "%scriptDir%"
    git pull
    if errorlevel 1 (
        echo [WARNING] Failed to update script directory - continuing with sync
    ) else (
        echo [SUCCESS] Script directory updated successfully
    )
    popd
    echo.
) else (
    echo [INFO] Script directory is not a git repository - skipping self-update
    echo.
)

for /f "usebackq eol=# tokens=1* delims=:" %%A in ("%mappingFile%") do (
    set "relativePath=%%~A"
    set "repoUrl=%%~B"

    call :Trim relativePath
    call :Trim repoUrl

    if defined relativePath if defined repoUrl (
        call :SyncRepo "!relativePath!" "!repoUrl!"
        if errorlevel 1 (
            echo.
            echo [ERROR] Sync failed for !relativePath!
            pause
            exit /b 1
        )
        echo.
    )
)

echo Sync complete.
pause
exit /b 0

:SyncRepo
set "relativePath=%~1"
set "repoUrl=%~2"
set "targetPath=%reaperRoot%\%relativePath%"

echo [SYNC] %relativePath%

if not exist "%targetPath%" (
    echo Creating folder: %targetPath%
    mkdir "%targetPath%"
    if errorlevel 1 (
        echo [ERROR] Failed to create folder: %targetPath%
        exit /b 1
    )
)

if not exist "%targetPath%\.git\" (
    echo Cloning %repoUrl% into %targetPath%
    git clone "%repoUrl%" "%targetPath%"
    if errorlevel 1 (
        echo [ERROR] git clone failed for %targetPath%
        exit /b 1
    )
)

echo Pulling latest changes in: %targetPath%
git -C "%targetPath%" pull
if errorlevel 1 (
    echo [ERROR] git pull failed for %targetPath%
    exit /b 1
)

echo Staging changes in: %targetPath%
git -C "%targetPath%" add .
if errorlevel 1 (
    echo [ERROR] git add failed for %targetPath%
    exit /b 1
)

git -C "%targetPath%" diff --cached --quiet
if errorlevel 1 (
    set "commitMessage=Sync %relativePath% files %date% %time%"
    echo Committing changes: !commitMessage!
    git -C "%targetPath%" commit -m "!commitMessage!"
    if errorlevel 1 (
        echo [ERROR] git commit failed for %targetPath%
        exit /b 1
    )
) else (
    echo No local changes to commit in: %targetPath%
)

echo Pushing changes in: %targetPath%
git -C "%targetPath%" push
if errorlevel 1 (
    echo [ERROR] git push failed for %targetPath%
    exit /b 1
)

exit /b 0

:Trim
for /f "tokens=* delims= " %%T in ("!%~1!") do set "%~1=%%T"
:TrimRight
if defined %~1 if "!%~1:~-1!"==" " (
    set "%~1=!%~1:~0,-1!"
    goto :TrimRight
)
exit /b 0
