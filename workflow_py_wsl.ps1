# PowerShell Setup Script for Development Environment
#@echo off && powershell -Command "& {Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/IGLS-NickNieto/Software_Installs/main/workflow_py_wsl.ps1' -OutFile 'workflow_py_wsl.ps1'}" && powershell -ExecutionPolicy Bypass -File workflow_py_wsl.ps1
# Auto-elevates to administrator if needed

# Self-elevate if not already running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Relaunching as administrator..." -ForegroundColor Yellow
    $arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    Exit
}

# Enable ANSI Colors
$Host.UI.RawUI.ForegroundColor = "Cyan"
Write-Host "============================================="
Write-Host "  Development Environment Setup"
Write-Host "=============================================" -ForegroundColor Cyan

# Function to Install Chocolatey (if not installed)
function Install-Choco {
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        try {
            Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            # Refresh environment variables to make choco available in current session
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
            
            if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
                Write-Host "Chocolatey installation may have succeeded, but command not available in current session." -ForegroundColor Yellow
                Write-Host "Will attempt to continue using full path..." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Error installing Chocolatey: $_" -ForegroundColor Red
            Write-Host "Please try to install Chocolatey manually and then re-run this script." -ForegroundColor Red
            Pause
            return $false
        }
    } else {
        Write-Host "Chocolatey already installed." -ForegroundColor Green
    }
    return $true
}

# Function to Check if Package is Installed via Chocolatey
function Test-ChocoPackageInstalled {
    param ($packageName)
    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (!(Test-Path $chocoPath)) {
        $chocoPath = "choco"
    }
    $output = & $chocoPath list --local-only $packageName 2>$null
    return $output -match "$packageName\s+\d+"
}

# Function to Install a Package
function Install-ChocoPackage {
    param (
        $packageName,
        $checkCommand = $null
    )
    
    # First check via command if provided
    $commandExists = $false
    if ($checkCommand) {
        $commandExists = Get-Command $checkCommand -ErrorAction SilentlyContinue
    }
    
    if ($commandExists) {
        Write-Host "$packageName is already installed (command '$checkCommand' exists)." -ForegroundColor Green
        return $true
    }
    
    # Then check via chocolatey
    if (Test-ChocoPackageInstalled $packageName) {
        Write-Host "$packageName is already installed via Chocolatey." -ForegroundColor Green
        return $true
    }
    
    # If not installed, proceed with installation
    Write-Host "Installing $packageName..." -ForegroundColor Yellow
    $chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
    if (!(Test-Path $chocoPath)) {
        $chocoPath = "choco"
    }
    & $chocoPath install $packageName -y
    
    # Verify installation
    if (Test-ChocoPackageInstalled $packageName) {
        Write-Host "$packageName installed successfully." -ForegroundColor Green
        return $true
    } else {
        Write-Host "Warning: $packageName installation may have failed." -ForegroundColor Yellow
        Write-Host "Continuing with setup..." -ForegroundColor Yellow
        return $false
    }
}

# Function to ensure a directory is in the PATH
function Ensure-PathContains {
    param (
        [string]$Directory
    )
    
    if (!(Test-Path $Directory -ErrorAction SilentlyContinue)) {
        Write-Host "Directory $Directory does not exist." -ForegroundColor Yellow
        return $false
    }
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    
    if ($currentPath -notlike "*$Directory*") {
        try {
            [Environment]::SetEnvironmentVariable("Path", $currentPath + ";" + $Directory, [EnvironmentVariableTarget]::Machine)
            $env:Path = $env:Path + ";" + $Directory
            Write-Host "Added $Directory to system PATH." -ForegroundColor Green
            return $true
        }
        catch {
            Write-Host "Failed to add $Directory to PATH: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "$Directory is already in system PATH." -ForegroundColor Green
        return $true
    }
}

# Function to check and install WSL
function Install-WSL {
    Write-Host "Checking Windows Subsystem for Linux (WSL)..." -ForegroundColor Cyan
    
    # Check if WSL is enabled by examining the list of WSL distros
    $wslEnabled = $false
    try {
        $wslOutput = wsl --list 2>&1
        # If WSL is enabled but no distros are installed, this command succeeds but gives a message
        $wslEnabled = $true
    } catch {
        # An error indicates WSL is not enabled
        $wslEnabled = $false
    }
    
    if (!$wslEnabled) {
        Write-Host "Enabling Windows Subsystem for Linux..." -ForegroundColor Yellow
        try {
            # Enable the WSL Windows feature
            Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
            # Install WSL 2
            wsl --install
            Write-Host "WSL installation initiated. A restart may be required to complete the installation." -ForegroundColor Yellow
            return $false  # Indicate that a restart is recommended
        } catch {
            Write-Host "Error enabling WSL: $_" -ForegroundColor Red
            Write-Host "You may need to enable Windows Subsystem for Linux manually through Windows Features." -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "WSL is already installed." -ForegroundColor Green
        return $true
    }
}

# Main execution flow
$chocoInstalled = Install-Choco
if (!$chocoInstalled) {
    Write-Host "Cannot proceed without Chocolatey. Please install manually and retry." -ForegroundColor Red
    Pause
    Exit 1
}

# Refresh environment to make sure choco is available
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

# Install packages (with command verification if available)
Install-ChocoPackage "git" "git"
Install-ChocoPackage "make" "make"
Install-ChocoPackage "miniconda3"
Install-ChocoPackage "docker-desktop"

# Check if repomix is a valid package before attempting to install
$chocoPath = "C:\ProgramData\chocolatey\bin\choco.exe"
if (!(Test-Path $chocoPath)) { $chocoPath = "choco" }
$repomixExists = & $chocoPath search repomix
if ($repomixExists -match "repomix") {
    Install-ChocoPackage "repomix"
} else {
    Write-Host "Package 'repomix' not found in Chocolatey repository. Skipping." -ForegroundColor Yellow
}

# Ensure Miniconda is in PATH
$condaPath = "C:\ProgramData\Miniconda3\Scripts"
$condaPathAdded = Ensure-PathContains $condaPath

# Install WSL if needed
$wslReady = Install-WSL

# Final Message
Write-Host "=============================================" -ForegroundColor Cyan
if (!$wslReady -or !$condaPathAdded) {
    Write-Host "  Setup Complete! Please restart your PC for"
    Write-Host "  all changes to take effect."
} else {
    Write-Host "  Setup Complete!"
}
Write-Host "=============================================" -ForegroundColor Cyan

Pause
