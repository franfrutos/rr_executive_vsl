@echo off
rem ===========================================================================
rem Launcher of the task (Windows). Double-click to run the task.
rem   run_task.bat test   short automatic session to check the setup (no participant)
rem
rem 1. If PsychoPy 2026.1.1 (Standalone) is installed, the task runs with it.
rem 2. Otherwise, uv (https://docs.astral.sh/uv/) is installed if needed, and the
rem    task runs in an isolated Python 3.10 environment with the versions in
rem    requirements.txt. The first time, this needs internet and takes a few
rem    minutes; later runs start at once. No administrator rights are needed.
rem ===========================================================================
setlocal
cd /d "%~dp0"
set "PSYCHOPY_VERSION=2026.1.1"
if /i "%~1"=="test" set "AST_AUTO=1"

rem ---- 1. PsychoPy Standalone ------------------------------------------------
if defined AST_FORCE_UV goto :uv
for %%P in ("%ProgramFiles%\PsychoPy\python.exe" "%LOCALAPPDATA%\Programs\PsychoPy\python.exe" "%ProgramFiles%\PsychoPy3\python.exe") do (
    if exist "%%~P" call :try_standalone "%%~P"
)
goto :uv

:try_standalone
set "FOUND="
"%~1" -c "import psychopy; print(psychopy.__version__)" > "%TEMP%\ast_psychopy_version.txt" 2>nul
set /p FOUND=<"%TEMP%\ast_psychopy_version.txt"
del "%TEMP%\ast_psychopy_version.txt" >nul 2>nul
if not "%FOUND%"=="%PSYCHOPY_VERSION%" (
    if defined FOUND echo PsychoPy %FOUND% found at %~1, but the task needs %PSYCHOPY_VERSION%.
    exit /b 0
)
echo Running the task with PsychoPy %FOUND% at %~1
"%~1" main.py
if errorlevel 1 pause
exit 0

rem ---- 2. Isolated environment with uv ---------------------------------------
:uv
where uv >nul 2>nul
if errorlevel 1 if exist "%USERPROFILE%\.local\bin\uv.exe" set "PATH=%USERPROFILE%\.local\bin;%PATH%"
where uv >nul 2>nul
if errorlevel 1 (
    echo PsychoPy %PSYCHOPY_VERSION% was not found. Installing uv to set up the Python environment...
    powershell -NoProfile -ExecutionPolicy ByPass -Command "irm https://astral.sh/uv/install.ps1 | iex"
    set "PATH=%USERPROFILE%\.local\bin;%PATH%"
)
where uv >nul 2>nul
if errorlevel 1 (
    echo uv could not be installed. Install PsychoPy %PSYCHOPY_VERSION% from https://www.psychopy.org/download.html and run this file again.
    pause
    exit /b 1
)
echo Preparing the Python environment (the first time, this downloads Python 3.10 and PsychoPy %PSYCHOPY_VERSION%)...
uv run --no-project --python 3.10 --with-requirements requirements.txt main.py
if errorlevel 1 pause
