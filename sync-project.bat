@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Bring console window to foreground
title REAPER Project Sync
echo Set objShell = CreateObject("WScript.Shell") > "%temp%\activate.vbs"
echo objShell.AppActivate "REAPER Project Sync" >> "%temp%\activate.vbs"
cscript //nologo "%temp%\activate.vbs" >nul 2>&1
del "%temp%\activate.vbs" >nul 2>&1

set "scriptDir=%~dp0"
set "mappingFile=%scriptDir%project-mappings.txt"
set "lastProjectFile=%scriptDir%last-project.txt"
set "projectsSubpath=Projects"
set "drives=C D E F"
set "drivesDisplay=C:, D:, E:, F:"
set "lastProject="

if not exist "%mappingFile%" (
    echo [ERROR] Project mapping file not found: %mappingFile%
    pause
    exit /b 1
)

if exist "%lastProjectFile%" (
    set /p lastProject=<"%lastProjectFile%"
    call :Trim lastProject
)

rem Find REAPER installation
call "%scriptDir%find-reaper.bat" "%drives%"
if %REAPER_FOUND% EQU 0 (
    echo [ERROR] REAPER folder not found on configured drives: %drivesDisplay%
    echo [ERROR] Also checked one level down in root folders of each drive
    pause
    exit /b 1
)

set "reaperRoot=%REAPER_ROOT%"
set "projectsRoot=%reaperRoot%\%projectsSubpath%"

if not exist "%projectsRoot%\" (
    echo Creating Projects folder: %projectsRoot%
    mkdir "%projectsRoot%"
    if errorlevel 1 (
        echo [ERROR] Failed to create Projects folder: %projectsRoot%
        pause
        exit /b 1
    )
)

set /a count=0

if defined lastProject (
    for /f "usebackq eol=# tokens=1* delims=:" %%A in ("%mappingFile%") do (
        set "projectName=%%~A"
        set "repoUrl=%%~B"
        call :Trim projectName
        call :Trim repoUrl

        if defined projectName if defined repoUrl (
            if /I "!projectName!"=="!lastProject!" (
                call :AddProject "!projectName!" "!repoUrl!"
            )
        )
    )
)

for /f "usebackq eol=# tokens=1* delims=:" %%A in ("%mappingFile%") do (
    set "projectName=%%~A"
    set "repoUrl=%%~B"
    call :Trim projectName
    call :Trim repoUrl

    if defined projectName if defined repoUrl (
        if not defined lastProject (
            call :AddProject "!projectName!" "!repoUrl!"
        ) else (
            if /I not "!projectName!"=="!lastProject!" (
                call :AddProject "!projectName!" "!repoUrl!"
            )
        )
    )
)

if %count% EQU 0 (
    echo [ERROR] No projects found in %mappingFile%
    pause
    exit /b 1
)

echo Found REAPER at: %reaperRoot%
echo.
echo Select a project to sync:
for /L %%I in (1,1,%count%) do (
    if defined lastProject if /I "!project[%%I]!"=="!lastProject!" (
        echo   %%I. !project[%%I]! ^(last used^)
    ) else (
        echo   %%I. !project[%%I]!
    )
)
echo.
set /p choice=Enter number [1]: 
if not defined choice set "choice=1"

set "selectedProject=!project[%choice%]!"
set "selectedRepo=!repo[%choice%]!"

if not defined selectedProject (
    echo [ERROR] Invalid selection.
    pause
    exit /b 1
)

echo.
call :SyncProject "!selectedProject!" "!selectedRepo!"
if errorlevel 1 (
    echo.
    echo [ERROR] Sync failed for !selectedProject!
    pause
    exit /b 1
)

> "%lastProjectFile%" echo !selectedProject!

echo.
echo Sync complete for !selectedProject!.
pause
exit /b 0

:AddProject
set /a count+=1
set "project[%count%]=%~1"
set "repo[%count%]=%~2"
exit /b 0

:SyncProject
set "projectName=%~1"
set "repoUrl=%~2"
set "targetPath=%projectsRoot%\%projectName%"

echo [SYNC] %projectName%

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
    set "commitMessage=Sync %projectName% files %date% %time%"
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
