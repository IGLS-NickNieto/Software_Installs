# Log function
function Write-Log {
    param (
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $Message"
    Add-Content -Path "C:\drop\QuickAssist_Uninstall.log" -Value $logMessage
}

# Ensure log directory exists
$logDir = "C:\drop"
if (!(Test-Path -Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

# Check if Quick Assist is installed
$quickAssistPackage = Get-AppxPackage -AllUsers *QuickAssist*
$quickAssistCapability = Get-WindowsCapability -Online | Where-Object Name -like "App.Support.QuickAssist*"

if ($quickAssistPackage -or ($quickAssistCapability.State -eq "Installed")) {
    Write-Host "Uninstalling Quick Assist..."
    Write-Log "Quick Assist detected. Proceeding with uninstallation."
    
    # Uninstall Quick Assist capability
    try {
        $capabilityOutput = powershell.exe -command "Remove-WindowsCapability -Online -Name (Get-WindowsCapability -Online | Where-Object Name -like 'App.Support.QuickAssist*').Name" 2>&1
        Write-Log "Remove-WindowsCapability output: $capabilityOutput"
    } catch {
        Write-Log "Error removing Windows Capability: $($_.Exception.Message)"
    }
    
    # Uninstall Quick Assist App Package
    try {
        $packageOutput = Get-AppxPackage -AllUsers *QuickAssist* | Remove-AppxPackage -AllUsers 2>&1
        Write-Log "Remove-AppxPackage output: $packageOutput"
    } catch {
        Write-Log "Error removing Appx Package: $($_.Exception.Message)"
    }
    
    Write-Host "Quick Assist uninstallation completed."
    Write-Log "Quick Assist uninstallation process completed."
    
    # Remove Quick Assist registry entries
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QuickAssist",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\QuickAssist"
    )
    
    foreach ($path in $registryPaths) {
        if (Test-Path $path) {
            Remove-Item -Path $path -Recurse -Force
            Write-Log "Removed registry entry: $path"
        }
    }
    
    # Remove leftover Quick Assist files
    $foldersToRemove = @(
        "C:\Program Files\WindowsApps\MicrosoftCorporationII.QuickAssist*",
        "C:\Windows\SystemApps\MicrosoftCorporationII.QuickAssist*"
    )
    
    foreach ($folder in $foldersToRemove) {
        if (Test-Path $folder) {
            Remove-Item -Path $folder -Recurse -Force
            Write-Log "Removed leftover files: $folder"
        }
    }
    
    # Check if a reboot is required
    $rebootPending = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue)
    if ($rebootPending) {
        Write-Host "A system reboot is required to complete the uninstallation."
        Write-Log "Reboot required after Quick Assist removal."
    }
    
} else {
    Write-Host "Quick Assist is not installed."
    Write-Log "Quick Assist is not installed. No action taken."
}
