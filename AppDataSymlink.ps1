param(
    [switch]$TerminalOnly
)
# Initialization
. "$($PSScriptRoot)\Functions\AppDataSymlink_Functions.ps1"
$AppdataPath="$($PSScriptRoot)\..\AppData"
if(!(Test-Path "$($AppDataPath)")) {
    Write-Error -Message "No `"AppData`" Folder found at $($AppDataPath). Please edit the script to correct the path."
    exit
}
# Create Symlink for Windows Terminal Settings. The Script will create symlink in all possible places that Windows Terminal and Windows Terminal Preview will look to
if([System.Environment]::OSVersion.Version.Build -ge 19041) { # Minimum requirement to install Windows Terminal
    [string[]]$WTFileLocations=@("Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe","Microsoft.WindowsTerminal_8wekyb3d8bbwe","Windows Terminal")
    foreach($WTFileDir in $WTFileLocations) {
        if($WTFileDir -like "*8wekyb3d8bbwe") {
            MkLKFile -LkPath "$($env:LOCALAPPDATA)\Packages\$($WTFileDir)" -LkFileName "settings.json" -TargetFilePath "$($AppdataPath)\Terminal_Settings.json" -HasLocalState
        }
        else { # Not in package folder
            MkLKFile -LkPath "$($env:LOCALAPPDATA)\Microsoft\$($WTFileDir)" -LkFileName "settings.json" -TargetFilePath "$($AppdataPath)\Terminal_Settings.json"
        }
    }
    if($TerminalOnly) {
        exit
    }
}
# Read subfolders for folders in %LocalAppData% %AppData% and "Saved Games" and "Public Documents" and "Start Menu"
$LocalFolders=(Get-ChildItem "$($AppdataPath)\Local\" -Directory)
$RoamingFolders=(Get-ChildItem "$($AppdataPath)\Roaming\" -Directory)
$SavedGameFolders=(Get-ChildItem "$($AppdataPath)\Saved Games\" -Directory)
$StartFolder=(Get-Item "$($AppdataPath)\Start Menu\")
$PublicDocuFolders=(Get-ChildItem "$($AppdataPath)\Public Documents\" -Directory)
# ________________________________________________________
# Create Symlink for %Localappdata% and %Appdata% subfolders and "Saved Games" and "Public Documents"
foreach($LocalFolder in $LocalFolders) {
    MkLKFolders "$($env:LOCALAPPDATA)\$($LocalFolder.Name)" "$($LocalFolder.FullName)"
}
foreach($RoamFolder in $RoamingFolders) {
    MkLKFolders "$($env:APPDATA)\$($RoamFolder.Name)" "$($RoamFolder.FullName)"
}
foreach($SGFolder in $SavedGameFolders) {
    MkLKFolders "$($env:USERPROFILE)\Saved Games\$($SGFolder.Name)" "$($SGFolder.FullName)"
}
foreach($PDFolder in $PublicDocuFolders) {
    MkLKFolders "$($env:PUBLIC)\Documents\$($PDFolder.Name)" "$($PDFolder.FullName)"
}
# ________________________________________________________
# Create Symlink for files
# PIA VPN Settings
MkLKFile -LkPath "$($env:LOCALAPPDATA)\Private Internet Access" -LkFileName "clientsettings.json" -TargetFilePath "$($AppdataPath)\PIA_clientsettings.json"
# SumatraPDF Settings
MkLKFile -LkPath "$($env:LOCALAPPDATA)\SumatraPDF" -LkFileName "SumatraPDF-settings.txt" -TargetFilePath "$($AppdataPath)\SumatraPDF-settings.txt"
# WSL global settings
MkLKFile -LkPath "$($env:USERPROFILE)" -LkFileName ".wslconfig" -TargetFilePath "$($AppdataPath)\.wslconfig"
# _____________________________________
# Create Start menu entry
# STEP 1: Remove existing start menu entry. If it's a symlink, only delete folder link. If it's NOT a symlink, delete the entire content
$StartFolderInAppData=(Get-Item "$($env:appdata)\Microsoft\Windows\Start Menu\Programs\")
if($StartFolderInAppData.Mode -like "d????l") { # Start menu folder is already symlink
    cmd /c rmdir "$($StartFolderInAppData)"
}
elseif($StartFolderInAppData.Mode -like "d????-") { # Start menu folder is an actual folder
    Remove-Item "$($StartFolderInAppData)" -Recurse -Force -Confirm:$false
}
MkLKFile -LkPath "$($env:appdata)\microsoft\windows\start menu" -LkFilename "Programs" -TargetFilePath "$($StartFolder)"