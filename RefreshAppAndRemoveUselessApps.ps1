param(
	[switch]$OfficeCleanupOnly,
	[switch]$EspeciallyAnnoyingOnly
)
# Get Admin privilege
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
[string[]]$ArgumentToPass=@()
foreach($Argum in @("OfficeCleanupOnly","EspeciallyAnnoyingOnly")) {
    if((Get-Variable "$($Argum)").value -eq $true) {
        $ArgumentToPass = $ArgumentToPass + @($Argum)    
    }
}
RunAsAdmin "$($PSCommandPath)" -Arguments $ArgumentToPass
function ForceUninstall {
	if($args[0].GetType().Name -like "string") {
		# This is a useless app that need to be removed
		Get-AppxPackage $args[0] -all | Remove-AppxPackage # First try uninstalling it locally on this account (MS store) - as some apps cannot be uninstalled via admin
		Get-AppxPackage $args[0] -all | Remove-AppxPackage -all
		Get-ChildItem "C:\Program Files\WindowsApps\$($args[0])*" | Remove-Item -Force -Recurse
	}
	elseif($args[0].GetType().Name -like "AppxPackage") {
		# This is an outdated version of an app that is still needed
		Remove-AppxPackage -all -package $args[0].PackageFullName
		Get-ChildItem "C:\Program Files\WindowsApps\$($args[0].Name)_$($args[0].Version)*" | Remove-Item -Force -Recurse
	}
}
if($EspeciallyAnnoyingOnly) {
	[string[]]$annoyingsapps=@("Microsoft.OutlookForWindows")
	foreach($uselessapp in $annoyingsapps) {
		Get-AppxPackage $uselessapp | Remove-AppxPackage
	}
	exit
}
. "$($PSScriptRoot)\Functions\MS-Office-Cleanup.ps1"
MSOfficeCleanup
if($OfficeCleanupOnly -or ((Get-AppxPackage "Microsoft.WindowsStore").count -eq 0)) {
	exit
}
#Define apps that has file association used
# [string[]]$AppsWithFileAsso=@("Microsoft.Paint", "Microsoft.WindowsTerminal", "Microsoft.WindowsTerminalPreview", "PythonSoftwareFoundation.Python.3.10")
# Define apps that need to be removed
[string[]]$uselessapps=@(
	"Microsoft.WindowsAlarms"
	"Microsoft.Windows.Photos"
	"Microsoft.549981C3F5F10" # Cortana
	"Microsoft.WindowsMaps"
	"Microsoft.YourPhone"
	"Microsoft.GetHelp"
	"Microsoft.BingNews"
	"Microsoft.WindowsNotepad"
	"Microsoft.People"
	"Microsoft.MicrosoftStickyNotes"
	"Microsoft.MicrosoftOfficeHub"
	"Microsoft.Office.OneNote" 
	"Microsoft.Microsoft3DViewer"
	"Microsoft.MicrosoftSolitaireCollection"
	"Microsoft.MixedReality.Portal"
	"Microsoft.XboxApp"
	"Microsoft.WindowsCalculator"
	"Microsoft.SkypeApp"
	"Microsoft.MSPaint"
	"Microsoft.BingWeather"
	"Microsoft.Getstarted"
	"Microsoft.WindowsSoundRecorder"
	"Microsoft.Todos"
	"Microsoft.PowerAutomateDesktop"
	"Microsoft.GamingApp"
	"Microsoft.XboxIdentityProvider"
	"Microsoft.WindowsFeedbackHub"
	"AdvancedMicroDevicesInc-2.AMDLink"
	"Microsoft.XboxGamingOverlay"
	"Clipchamp.Clipchamp"
	"MicrosoftCorporationII.MicrosoftFamily"
	"MicrosoftCorporationII.QuickAssist"
	"MicrosoftTeams"
	"AdvancedMicroDevicesInc-2.AMDRadeonSoftware"
	"microsoft.windowscommunicationsapps"
	"microsoft.outlookforwindows"
	"Microsoft.Windows.DevHome"
	"Microsoft.Windows.DevHomeGitHubExtension"
)
if(((Get-AppxPackage "*WindowsTerminalPreview*") -like "*WindowsTerminalPreview*")) {
	$uselessapps = $uselessapps + @("Microsoft.WindowsTerminal")
}
# if(Test-Path "C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA App.exe") {
# 	$uselessapps = $uselessapps + @("NVIDIACorp.NVIDIAControlPanel") # Nvidia control panel still needed by NVIDIA app
# }
[bool[]]$MPlayersInstalled=@((Test-Path "C:\Program Files\VideoLAN\VLC\vlc.exe"),`
((Get-ItemProperty -Path "Registry::HKLM\Software\Microsoft\Active Setup\Installed Components\{22d6f312-b0f6-11d0-94ab-0080c74c7e95}" -ErrorAction SilentlyContinue).isinstalled -eq 1))
if($MPlayersInstalled -contains $true) {
	$uselessapps = $uselessapps + @("Microsoft.ZuneMusic","Microsoft.ZuneVideo")
}
foreach ($uselessapp in $uselessapps)
{
	if($uselessapp.length -eq 0) {
		continue
	}
	$checkifappinstalled = $null
	$checkifappinstalled = Get-AppxPackage $uselessapp -all
	if($checkifappinstalled -like "*$($uselessapp)*")
	{
		Write-Output "Removing unwanted apps $($uselessapp)"
		ForceUninstall $uselessapp
	}
}
# Refresh all MS Store apps. NO LONGER Useful since the 0x80070005 error no longer exists.
Start-Sleep -Seconds 7
$AllApps = Get-AppxPackage -allusers *
# [bool]$FileAssoRegRefreshNeeded=$false
foreach($UWPapp in $AllApps)
{
	if(-Not $uselessapps.Contains($UWPapp.Name))	{
		if($UWPapp.PackageUserInformation -like "*Staged*") {
			Write-Output "refreshing $($UWPapp.PackageFullName)"
			try {
				Add-AppxPackage -DisableDevelopmentMode -Register "$($UWPapp.InstallLocation)\AppXManifest.xml" -Erroraction 'silentlycontinue'
			}
			catch {
				if(($Error[0] -like "*0x80073D06*")) {
					Write-Output "This package is outdated, removing ..."
					ForceUninstall $UWPapp
					# if($AppsWithFileAsso.contains($UWPapp.Name)) {
					# 	Write-Host "need to refresh file associations context menu of file $($UWPapp.name)" -ForegroundColor Cyan
					# 	$FileAssoRegRefreshNeeded=$true
					# }
					if($UWPapp.Name -like "Microsoft.WindowsTerminal*") {
						powershell.exe -File "$($PSScriptRoot)\Symlink_AppData.ps1" -TerminalOnly
					}
					Write-Host "`n"
			}
		}
		}
	}
}
# if($FileAssoRegRefreshNeeded) {
# 	powershell.exe -File "$($PSScriptRoot)\WriteRegistry.ps1" -ArgumentList "-UWPRefreshOnly"
# }