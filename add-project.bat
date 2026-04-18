@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem Bring console window to foreground
title REAPER Add Project
echo Set objShell = CreateObject("WScript.Shell") > "%temp%\activate.vbs"
echo objShell.AppActivate "REAPER Add Project" >> "%temp%\activate.vbs"
cscript //nologo "%temp%\activate.vbs" >nul 2>&1
del "%temp%\activate.vbs" >nul 2>&1

set "scriptDir=%~dp0"
set "mappingFile=%scriptDir%project-mappings.txt"
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
set "projectsRoot=%reaperRoot%\Projects"

if not exist "%projectsRoot%\" (
    echo Creating Projects folder: %projectsRoot%
    mkdir "%projectsRoot%"
    if errorlevel 1 (
        echo [ERROR] Failed to create Projects folder: %projectsRoot%
        pause
        exit /b 1
    )
)

echo Found REAPER at: %reaperRoot%
echo Projects directory: %projectsRoot%
echo.

rem Prompt for project name
:prompt
set /p projectName="Enter project name: "
call :Trim projectName

if "%projectName%"=="" (
    echo [ERROR] Project name cannot be empty
    goto :prompt
)

rem Validate project name (no special characters)
echo %projectName%| findstr /R /C:"[^a-zA-Z0-9_-]" >nul
if not errorlevel 1 (
    echo [ERROR] Project name can only contain letters, numbers, underscores, and hyphens
    goto :prompt
)

set "fullProjectName=reaper-projects-%projectName%"
set "projectPath=%projectsRoot%\%fullProjectName%"

rem Check if project already exists
if exist "%projectPath%\" (
    echo [ERROR] Project already exists: %fullProjectName%
    echo Path: %projectPath%
    pause
    exit /b 1
)

echo.
echo Creating new project: %fullProjectName%
echo Location: %projectPath%
echo.

rem Create project folder
mkdir "%projectPath%"
if errorlevel 1 (
    echo [ERROR] Failed to create project folder: %projectPath%
    pause
    exit /b 1
)

rem Initialize git repository
echo Initializing git repository...
git init "%projectPath%"
if errorlevel 1 (
    echo [ERROR] Failed to initialize git repository
    rmdir /s /q "%projectPath%" 2>nul
    pause
    exit /b 1
)

rem Set up main branch from the start
echo Setting up main branch...
git -C "%projectPath%" checkout -b main

rem Create initial README.md
echo # %fullProjectName% > "%projectPath%\README.md"
echo. >> "%projectPath%\README.md"
echo REAPER project: %projectName% >> "%projectPath%\README.md"
echo Created: %date% %time% >> "%projectPath%\README.md"

rem Initial commit
echo Making initial commit...
git -C "%projectPath%" add .
git -C "%projectPath%" commit -m "Initial commit for %projectName%"
if errorlevel 1 (
    echo [ERROR] Failed to make initial commit
    rmdir /s /q "%projectPath%" 2>nul
    pause
    exit /b 1
)

rem Check if GitHub CLI is available
echo.
echo Checking GitHub CLI availability...
gh --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] GitHub CLI not found. GitHub CLI is required for this script.
    echo Download from: https://cli.github.com/
    echo Please install GitHub CLI and try again.
    pause
    exit /b 1
)
echo GitHub CLI found. Checking if repository already exists...

rem Check if GitHub repository already exists
    gh repo view "%fullProjectName%" >nul 2>&1
    if not errorlevel 1 (
        echo [INFO] GitHub repository already exists: %fullProjectName%
        
        rem Get the existing repository URL
        for /f "tokens=*" %%i in ('gh repo view "%fullProjectName%" --json url -q .url') do set "repoUrl=%%i"
        echo Repository URL: !repoUrl!
        
        rem Set up remote connection to existing repository
        echo Connecting to existing GitHub repository...
        git -C "%projectPath%" remote add origin "!repoUrl!.git"
        if errorlevel 1 (
            echo [WARNING] Failed to add remote origin
        )
        
        rem Fetch remote to understand its state
        echo Fetching from remote...
        git -C "%projectPath%" fetch origin
        if errorlevel 1 (
            echo [WARNING] Failed to fetch from remote
        )
        
        rem Set up tracking and push
        echo Setting up tracking and pushing...
        git -C "%projectPath%" branch --set-upstream-to=origin/main main
        git -C "%projectPath%" push origin main
        if errorlevel 1 (
            echo [WARNING] Failed to push to existing repository. Attempting force push...
            git -C "%projectPath%" push --force-with-lease origin main
            if errorlevel 1 (
                echo [ERROR] Failed to connect to existing repository
            ) else (
                echo [SUCCESS] Force pushed to existing GitHub repository!
            )
        ) else (
            echo [SUCCESS] Connected and pushed to existing GitHub repository!
        )
    ) else (
        echo Repository does not exist. Creating new remote repository...
        
        rem Create GitHub repository
        gh repo create "%fullProjectName%" --private --description "REAPER project: %projectName%" --confirm
        if errorlevel 1 (
            echo [ERROR] Failed to create GitHub repository.
            echo This may happen if:
            echo - Repository already exists
            echo - Authentication failed
            echo - Network issues
            pause
            exit /b 1
        ) else (
            echo [SUCCESS] GitHub repository created!
            
            rem Get the repository URL and set up remote connection
            for /f "tokens=*" %%i in ('gh repo view "%fullProjectName%" --json url -q .url') do set "repoUrl=%%i"
            echo Repository URL: !repoUrl!
            
            rem Set up remote connection
            echo Setting up remote connection...
            git -C "%projectPath%" remote add origin "!repoUrl!.git"
            if errorlevel 1 (
                echo [ERROR] Failed to add remote origin
            ) else (
                rem Push with upstream tracking
                echo Pushing with upstream tracking...
                git -C "%projectPath%" push -u origin main
                if errorlevel 1 (
                    echo [WARNING] Failed to push to remote repository
                ) else (
                    echo [SUCCESS] Repository connected and initial commit pushed!
                    
                    rem Verify tracking is set up
                    git -C "%projectPath%" branch -vv
                )
            )
        )
    )
)

rem Add to project mappings
echo.
echo Adding to project mappings...
echo %fullProjectName%: %repoUrl% >> "%mappingFile%"
if errorlevel 1 (
    echo [ERROR] Failed to add project to mappings file
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Project created successfully!
echo Project name: %fullProjectName%
echo Location: %projectPath%
echo Repository URL: %repoUrl%
echo Added to: %mappingFile%
echo.
pause
exit /b 0

:Trim
setlocal
set "str=!%~1!"
for /f "tokens=* delims= " %%a in ("!str!") do set "str=%%a"
for /l %%i in (1,1,100) do if "!str:~-1!"==" " set "str=!str:~0,-1!"
endlocal & set "%~1=%str%"
goto :eof