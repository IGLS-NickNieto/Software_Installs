@echo off
setlocal EnableDelayedExpansion

REM Define constants
set "MINICONDA_URL=https://repo.anaconda.com/miniconda/Miniconda3-latest-Windows-x86_64.exe"
set "MINICONDA_FILE=miniconda.exe"
set "CONDA_DIR=%USERPROFILE%\Miniconda3"
set "ENV_NAME=new_env"
set "LOG_FILE=%TEMP%\miniconda_setup.log"
set "EXPECTED_SHA256=fb936987b769759fc852af1b2a0e359ac14620c2b7bea8a90c6d920f2b754c4a"

REM Initialize log file
echo Miniconda Setup Log - %DATE% %TIME% > "%LOG_FILE%"
echo Expected SHA256: %EXPECTED_SHA256% >> "%LOG_FILE%"

REM Step 1: Check if file exists and verify SHA256
echo Checking local Miniconda installer...
if exist "%MINICONDA_FILE%" (
    echo Computing SHA256 for existing file... >> "%LOG_FILE%"
    for /f "tokens=*" %%i in ('powershell -Command "(Get-FileHash -Path '%MINICONDA_FILE%' -Algorithm SHA256).Hash.ToLower()"') do set "LOCAL_SHA256=%%i"
    if not defined LOCAL_SHA256 (
        echo Warning: Failed to compute local SHA256. Assuming mismatch. >> "%LOG_FILE%"
        set "LOCAL_SHA256=unknown"
    ) else (
        set "LOCAL_SHA256=!LOCAL_SHA256: =!"
    )
    echo Local SHA256: !LOCAL_SHA256! >> "%LOG_FILE%"
    if "!LOCAL_SHA256!"=="%EXPECTED_SHA256%" (
        echo Local file is up-to-date. SHA256 matches: !LOCAL_SHA256!
    ) else (
        echo SHA256 mismatch. Local: !LOCAL_SHA256!, Expected: %EXPECTED_SHA256%
        echo Deleting mismatched file... >> "%LOG_FILE%"
        del "%MINICONDA_FILE%" 2>>"%LOG_FILE%"
        call :DownloadInstaller
    )
) else (
    echo No local installer found. Downloading...
    call :DownloadInstaller
)

REM Step 2: Verify installer exists before proceeding
if not exist "%MINICONDA_FILE%" (
    echo Error: Installer not found after download attempt.
    goto :ErrorExit
)

REM Step 3: Install Miniconda for current user only
echo Installing Miniconda to %CONDA_DIR% for current user only...
start /wait "" "%MINICONDA_FILE%" /S /InstallationType=JustMe /RegisterPython=0 /D="%CONDA_DIR%" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Installation failed. Check "%LOG_FILE%".
    goto :ErrorExit
)
if not exist "%CONDA_DIR%\Scripts\conda.exe" (
    echo Error: Conda not found at "%CONDA_DIR%\Scripts\conda.exe".
    goto :ErrorExit
)

REM Step 4: Initialize Conda
echo Initializing Conda...
call "%CONDA_DIR%\Scripts\conda.bat" init cmd.exe >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Conda initialization failed.
    goto :ErrorExit
)

REM Step 5: Remove existing environment if it exists
echo Checking for environment %ENV_NAME%...
call "%CONDA_DIR%\Scripts\conda.bat" env list | findstr /C:"%ENV_NAME%" >nul
if %ERRORLEVEL% equ 0 (
    echo Removing existing environment %ENV_NAME%...
    call "%CONDA_DIR%\Scripts\conda.bat" env remove --yes -n "%ENV_NAME%" >> "%LOG_FILE%" 2>&1
    if %ERRORLEVEL% neq 0 (
        echo Error: Failed to remove environment.
        goto :ErrorExit
    )
)

REM Step 6: Create new environment
echo Creating environment %ENV_NAME%...
call "%CONDA_DIR%\Scripts\conda.bat" create --yes -n "%ENV_NAME%" python=3.9 jupyter pandas numpy matplotlib -c conda-forge >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Failed to create environment.
    goto :ErrorExit
)
if not exist "%CONDA_DIR%\envs\%ENV_NAME%\python.exe" (
    echo Error: Environment creation incomplete.
    goto :ErrorExit
)

REM Step 7: Final instructions
echo.
echo Setup complete!
echo Activate with: conda activate %ENV_NAME%
echo Start Jupyter with: jupyter notebook
echo Location: %CONDA_DIR%\envs\%ENV_NAME%
echo Log: "%LOG_FILE%"
del "%MINICONDA_FILE%" 2>>"%LOG_FILE%"
pause
exit /b 0

REM Subroutine to download installer
:DownloadInstaller
echo Downloading from %MINICONDA_URL%...
powershell -Command "Invoke-WebRequest -Uri '%MINICONDA_URL%' -OutFile '%MINICONDA_FILE%'" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo Error: Download failed.
    goto :ErrorExit
)
echo Verifying downloaded file... >> "%LOG_FILE%"
for /f "tokens=*" %%i in ('powershell -Command "(Get-FileHash -Path '%MINICONDA_FILE%' -Algorithm SHA256).Hash.ToLower()"') do set "NEW_SHA256=%%i"
if not defined NEW_SHA256 (
    echo Error: Failed to compute SHA256 of downloaded file.
    goto :ErrorExit
)
set "NEW_SHA256=!NEW_SHA256: =!"
echo Downloaded SHA256: !NEW_SHA256! >> "%LOG_FILE%"
if not "!NEW_SHA256!"=="%EXPECTED_SHA256%" (
    echo Error: Downloaded file SHA256 mismatch. Expected: %EXPECTED_SHA256%, Got: !NEW_SHA256!
    goto :ErrorExit
)
goto :EOF

REM Error exit handler
:ErrorExit
echo Setup failed. See "%LOG_FILE%" for details.
pause
exit /b 1
