# PowerShell script to manage uninstalled Windows Subsystem for Android (WSA) apps
# This version uses dynamic package information and explicit variable types.

# Add a Force switch parameter to override the exit on no changes
[CmdletBinding()]
param(
    [switch]$Force
)

# Step 0: Confirm WSA is installed and get its package information
Write-Host "Step 0: Confirm WSA is installed and get its package information" -ForegroundColor Black -BackgroundColor White
# Declare package name variable for cleaner code
[string]$WsaPackageName = "MicrosoftCorporationII.WindowsSubsystemForAndroid"

try {
    [Microsoft.Windows.Appx.PackageManager.Commands.AppxPackage]$WsaPackage = Get-AppxPackage -Name $($WsaPackageName) -ErrorAction Stop
    [string]$WsaPackageFamilyName = $($WsaPackage.PackageFamilyName)
    [string]$WsaAppdataFolder = Join-Path $env:LOCALAPPDATA "Packages\$($WsaPackageFamilyName)"
}
catch {
    Write-Error "Windows Subsystem for Android (WSA) is not installed. Aborting script."
    exit 1
}

# Step 1: Create WSAappStatus folder
Write-Host "Step 1: Create WSAappStatus folder" -ForegroundColor Black -BackgroundColor White
[string]$WsaAppStatusFolder = Join-Path $($WsaAppdataFolder) "WSAappStatus"
if (-not (Test-Path $($WsaAppStatusFolder))) {
    New-Item -ItemType Directory -Path $($WsaAppStatusFolder) -Force | Out-Null
    Write-Host "Created WSAappStatus folder: $($WsaAppStatusFolder)"
} else {
    Write-Host "WSAappStatus folder already exists: $($WsaAppStatusFolder)"
}

# Step 2: Create JSON files if they don't exist
Write-Host "Step 2: Create JSON files if they don't exist" -ForegroundColor Black -BackgroundColor White
[string]$WsaUserAppsJson = Join-Path $($WsaAppStatusFolder) "WSAuserApps.json"
[string]$WsaStartMenuAppsJson = Join-Path $($WsaAppStatusFolder) "WSAstartMenuApps.json"
[string]$WsaUninstallInfoAppsJson = Join-Path $($WsaAppStatusFolder) "WSAuninstallInformationApps.json"

[string[]]$jsonFiles = @($WsaUserAppsJson, $WsaStartMenuAppsJson, $WsaUninstallInfoAppsJson)
foreach ($file in $jsonFiles) {
    if (-not (Test-Path $($file))) {
        Set-Content -Path $($file) -Value "[]" # Initialize as empty JSON array
        Write-Host "Created empty JSON file: $($file)"
    } else {
        Write-Host "JSON file already exists: $($file)"
    }
}

# Step 3: Get all installed apps from WSA using ADB
Write-Host "Step 3: Get all installed apps from WSA using ADB" -ForegroundColor Black -BackgroundColor White
Write-Host "Checking ADB availability and WSA connection..."
[string]$adbPath = (where.exe adb.exe)
if (-not $($adbPath)) {
    Write-Error "adb.exe not found in PATH. Aborting script."
    exit 1
}

# Check if WSA is connected
[string]$adbDevicesOutput = & $($adbPath) devices
if ($adbDevicesOutput -notlike "*127.0.0.1:58526*") {
    Write-Host "WSA not connected. Attempting to connect..."
    try {
        & $($adbPath) connect "127.0.0.1:58526" | Out-Null
        # Give it a moment to connect
        Start-Sleep -Seconds 5
        $adbDevicesOutput = & $($adbPath) devices
        if ($adbDevicesOutput -notlike "*127.0.0.1:58526*") {
            Write-Error "Failed to connect to WSA via ADB. Aborting script."
            exit 1
        }
        Write-Host "Successfully connected to WSA."
    }
    catch {
        Write-Error "An error occurred while trying to connect to WSA: $($_.Exception.Message). Aborting script."
        exit 1
    }
} else {
    Write-Host "WSA is already connected."
}

# Get list of all installed apps (including system apps) to avoid false positives
# The `-3` filter has been removed to get all packages
[string[]]$adbAppsOutput = $(. adb "-s 127.0.0.1:58526 shell pm list packages") | ForEach-Object {
    $_ -replace 'package:', ''
} | Sort-Object
if($adbAppsOutput -notlike "*package:com.microsoft.windows.documentsui*") {
    Write-Error "Error reading WSA apps. Aborting script."
    exit 1
}

# Read existing WSAuserApps.json if it exists
[System.Collections.ArrayList]$existingWsaUserApps = New-Object System.Collections.ArrayList
if (Test-Path $($WsaUserAppsJson)) {
    try {
        [string[]]$appsFromJson = Get-Content -Path $($WsaUserAppsJson) | ConvertFrom-Json
        $existingWsaUserApps.AddRange($appsFromJson)
        $existingWsaUserApps.Sort()
    }
    catch {
        Write-Warning "Could not read existing WSAuserApps.json. It might be malformed. Proceeding with fresh data."
    }
}

# Compare current ADB output with existing JSON and exit if no changes unless -Force is used
if (($adbAppsOutput | Compare-Object $existingWsaUserApps -PassThru | Measure-Object).Count -eq 0) {
    if (-not $Force) {
        Write-Host "WSA installed apps list has not changed. Aborting further steps. To force cleanup, run with -Force."
        exit 0 # Exit successfully as nothing needs to be done
    } else {
        Write-Host "WSA installed apps list has not changed, but continuing due to -Force parameter."
    }
} else {
    Write-Host "WSA installed apps list has changed. Updating WSAuserApps.json."
    # Write current app list to JSON
    $adbAppsOutput | ConvertTo-Json -Depth 100 | Set-Content -Path $($WsaUserAppsJson)
}

# Step 4: Get WSA app shortcuts from Start Menu
Write-Host "Step 4: Get WSA app shortcuts from Start Menu" -ForegroundColor Black -BackgroundColor White
Write-Host "Scanning Start Menu for WSA app shortcuts..."
[string]$startMenuProgramsPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
[System.Collections.ArrayList]$wsaStartMenuApps = New-Object System.Collections.ArrayList

$shell = New-Object -ComObject WScript.Shell

# Define the prefix we're looking for and will remove
[string]$WSAargPrefix = "/launch wsa://"

foreach ($item in (Get-ChildItem -Path $($startMenuProgramsPath) -Filter "*.lnk" -Recurse)) {
    try {
        $shortcut = $($shell.CreateShortcut($item.FullName))
        $targetPath = $($shortcut.TargetPath)
        $shortcutArguments = $($shortcut.Arguments) # Get the arguments

        # Condition to check for a WSA shortcut
        if ($targetPath -like "*WsaClient.exe" -and $shortcutArguments -like "$($WSAargPrefix)*") {
            # Use -replace to get the package name, making the script more robust
            $packageName = $shortcutArguments -replace "^$([RegEx]::Escape($WSAargPrefix))"
            $wsaStartMenuApps.Add([PSCustomObject]@{
                Name        = $($item.BaseName)
                Path        = $($item.FullName)
                TargetPath  = $($targetPath)
                PackageName = $($packageName)
            }) | Out-Null
        }
    }
    catch {
        Write-Warning "Could not process shortcut '$($item.FullName)': $($_.Exception.Message)"
    }
}

$wsaStartMenuApps | ConvertTo-Json -Depth 100 | Set-Content -Path $($WsaStartMenuAppsJson)
Write-Host "Updated WSAstartMenuApps.json with $($wsaStartMenuApps.Count) entries."

# Step 5: Get WSA app uninstall information from Registry (HKCU)
Write-Host "Step 5: Get WSA app uninstall information from Registry (HKCU)" -ForegroundColor Black -BackgroundColor White
Write-Host "Scanning Registry for WSA app uninstall information..."
[System.Collections.ArrayList]$wsaUninstallInfoApps = New-Object System.Collections.ArrayList
[string]$uninstallPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"

foreach ($item in (Get-ChildItem -Path $($uninstallPath))) {
    # Get the AndroidPackageName property. If it doesn't exist, this variable will be $null
    $androidPackageName = (Get-ItemProperty -Path $($item.PSPath) -Name "AndroidPackageName" -ErrorAction SilentlyContinue)."AndroidPackageName"
    
    # Only process this registry key if it has an AndroidPackageName property
    if ($androidPackageName) {
        Set-ItemProperty -Path $($item.PSPath) -Name "NoRemove" -Value 1 -Type DWORD -Force -ErrorAction SilentlyContinue
        $wsaUninstallInfoApps.Add([PSCustomObject]@{
            KeyPath     = $($item.PSPath)
            PackageName = $($androidPackageName)
        }) | Out-Null
    }
}

$wsaUninstallInfoApps | ConvertTo-Json -Depth 100 | Set-Content -Path $($WsaUninstallInfoAppsJson)
Write-Host "Updated WSAuninstallInformationApps.json with $($wsaUninstallInfoApps.Count) entries."

# Step 6: Compare JSONs and clean up
Write-Host "Step 6: Compare JSONs and clean up" -ForegroundColor Black -BackgroundColor White
Write-Host "Comparing app lists and performing cleanup..."

[string[]]$currentWsaUserApps = Get-Content -Path $($WsaUserAppsJson) | ConvertFrom-Json
[array]$currentWsaStartMenuApps = Get-Content -Path $($WsaStartMenuAppsJson) | ConvertFrom-Json
[array]$currentWsaUninstallInfoApps = Get-Content -Path $($WsaUninstallInfoAppsJson) | ConvertFrom-Json

[hashtable]$removedAppsCandidates = @{}

foreach ($startMenuApp in $currentWsaStartMenuApps) {
    if ($startMenuApp.PackageName -and ($currentWsaUserApps -notcontains $($startMenuApp.PackageName))) {
        $removedAppsCandidates[$($startMenuApp.PackageName)] = $true
    }
}

foreach ($uninstallApp in $currentWsaUninstallInfoApps) {
    if ($uninstallApp.PackageName -and ($currentWsaUserApps -notcontains $($uninstallApp.PackageName))) {
        $removedAppsCandidates[$($uninstallApp.PackageName)] = $true
    }
}

[string[]]$appsToClean = $($removedAppsCandidates.Keys)

if ($appsToClean.Count -eq 0) {
    Write-Host "No uninstalled WSA apps found requiring cleanup."
} else {
    Write-Host "Found $($appsToClean.Count) uninstalled WSA apps to clean up: $($appsToClean -join ', ')"

    # Clean up Start Menu shortcuts
    foreach ($packageName in $appsToClean) {
        $shortcutsToDelete = $currentWsaStartMenuApps | Where-Object { $_.PackageName -eq $($packageName) }
        foreach ($shortcut in $shortcutsToDelete) {
            Write-Host "Deleting Start Menu shortcut: $($shortcut.Path)"
            Remove-Item -Path $($shortcut.Path) -Force -ErrorAction SilentlyContinue
        }
    }

    # Clean up Uninstall information in Registry
    foreach ($packageName in $appsToClean) {
        $uninstallEntriesToDelete = $currentWsaUninstallInfoApps | Where-Object { $_.PackageName -eq $($packageName) }
        foreach ($entry in $uninstallEntriesToDelete) {
            Write-Host "Deleting Registry uninstall entry: $($entry.KeyPath)"
            Remove-Item -Path $($entry.KeyPath) -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Script execution completed."
