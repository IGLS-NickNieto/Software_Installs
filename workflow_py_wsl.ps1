# PowerShell Setup Script for Development Environment
# Requirements: Run as Administrator

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
            
            if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
                throw "Chocolatey installation failed!"
            }
        }
        catch {
            Write-Host "Error installing Chocolatey: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "Chocolatey already installed." -ForegroundColor Green
    }
}

# Function to Check if Package is Installed
function Test-PackageInstalled {
    param ($packageName)
    $chocoList = (choco list --local-only) -join " "
    return $chocoList -match $packageName
}

# Function to Install a Package
function Install-Package {
    param ($packageName, $commandName = $packageName)
    
    if (!(Test-PackageInstalled $packageName)) {
        Write-Host "Installing $packageName..." -ForegroundColor Yellow
        $result = choco install $packageName -y
        
        # Verify installation
        if (!(Test-PackageInstalled $packageName)) {
            Write-Host "Failed to install $packageName. Exiting." -ForegroundColor Red
            exit 1
        }
        Write-Host "$packageName installed successfully." -ForegroundColor Green
    } else {
        Write-Host "$packageName is already installed." -ForegroundColor Green
    }
}

# Install Chocolatey
Install-Choco

# Install Required Packages
Install-Package "git"
Install-Package "make"
Install-Package "miniconda3"
Install-Package "docker-desktop"
# Check if repomix is a valid package before installing
$repomixExists = choco find repomix
if ($repomixExists -match "repomix") {
    Install-Package "repomix"
} else {
    Write-Host "Package 'repomix' not found in Chocolatey repository. Skipping." -ForegroundColor Yellow
}

# Ensure Miniconda is in PATH
$condaPath = "C:\ProgramData\Miniconda3\Scripts"
if (!(Test-Path $condaPath)) {
    Write-Host "Miniconda installation not found at expected location!" -ForegroundColor Red
    Write-Host "Please check the installation path manually." -ForegroundColor Yellow
} else {
    $currentPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    if (!($currentPath -like "*$condaPath*")) {
        [System.Environment]::SetEnvironmentVariable("Path", $currentPath + ";" + $condaPath, [System.EnvironmentVariableTarget]::Machine)
        Write-Host "Miniconda added to system PATH." -ForegroundColor Green
    } else {
        Write-Host "Miniconda already in system PATH." -ForegroundColor Green
    }
}

# Enable WSL
Write-Host "Checking Windows Subsystem for Linux (WSL)..." -ForegroundColor Cyan
try {
    $wslInstalled = $false
    $wslOutput = wsl --list 2>&1
    if ($wslOutput -notmatch "Windows Subsystem for Linux has no installed distributions") {
        $wslInstalled = $true
    }
} catch {
    $wslInstalled = $false
}

if (!$wslInstalled) {
    Write-Host "Enabling WSL..." -ForegroundColor Yellow
    try {
        wsl --install
        Write-Host "WSL installation initiated. A system restart may be required to complete." -ForegroundColor Yellow
    } catch {
        Write-Host "Error enabling WSL: $_" -ForegroundColor Red
    }
} else {
    Write-Host "WSL is already installed." -ForegroundColor Green
}

# Final Message
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Setup Complete! Please restart your PC."
Write-Host "=============================================" -ForegroundColor Cyan
