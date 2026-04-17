@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "scriptDir=%~dp0"
set "mappingFile=%scriptDir%sync-mappings.txt"
set "reaperSubpath=\REAPER"
set "drives=C D E F"
set "drivesDisplay=C:, D:, E:, F:"
set "reaperRoot="

if not exist "%mappingFile%" (
    echo [ERROR] Mapping file not found: %mappingFile%
    pause
    exit /b 1
)

for %%D in (%drives%) do (
    if exist "%%D:%reaperSubpath%\" (
        set "reaperRoot=%%D:%reaperSubpath%"
        goto :found
    )
)

echo [ERROR] REAPER folder not found on configured drives: %drivesDisplay%
pause
exit /b 1

:found
echo Found REAPER at: %reaperRoot%
echo Using mappings from: %mappingFile%
echo.

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
