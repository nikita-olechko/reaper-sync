@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem find-reaper.bat - Utility to find REAPER installation path
rem Usage: call find-reaper.bat [drives]
rem Returns: Sets REAPER_ROOT environment variable if found, empty if not found
rem         Sets REAPER_FOUND=1 if found, 0 if not found

set "reaperSubpath=\REAPER"
set "drives=%~1"
if "%drives%"=="" set "drives=C D E F"
set "drivesDisplay=%drives: =:, %:"

set "REAPER_ROOT="
set "REAPER_FOUND=0"

rem First check at root level of each drive
for %%D in (%drives%) do (
    if exist "%%D:%reaperSubpath%\" (
        set "REAPER_ROOT=%%D:%reaperSubpath%"
        set "REAPER_FOUND=1"
        goto :found
    )
)

rem If not found at root, check one level down in each drive's root folders
for %%D in (%drives%) do (
    if exist "%%D:\" (
        for /f "delims=" %%F in ('dir /b /ad "%%D:\" 2^>nul') do (
            if exist "%%D:\%%F%reaperSubpath%\" (
                set "REAPER_ROOT=%%D:\%%F%reaperSubpath%"
                set "REAPER_FOUND=1"
                goto :found
            )
        )
    )
)

goto :end

:found
rem Return the values to the calling script
endlocal & set "REAPER_ROOT=%REAPER_ROOT%" & set "REAPER_FOUND=%REAPER_FOUND%"
exit /b 0

:end
rem Return failure state to the calling script  
endlocal & set "REAPER_ROOT=" & set "REAPER_FOUND=0"
exit /b 1