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
# Remove unwanted MS Office components
# For the following scripts to work Office Deployment Tool need to be downloaded https://www.microsoft.com/en-us/download/details.aspx?id=49117 and put to location %localappdata%\Programs\Office Deployment Tool
# Check if MS Office is installed
[bool]$MSOfficeInstalled=$false
foreach($ProgramFilesLoc in @("Program Files","Programe Files (x86)")) {
    [string]$MSOfficeLoc="C:\$($ProgramFilesLoc)\Microsoft Office\root\Office16\Word.exe" # As OneNote can be installed separately without license, it's better to test if Office (license needed) is installed via word.exe
    if(Test-Path "$($MSOfficeLoc)") {
        $MSOfficeInstalled=$true
        break
    }
}
if($MSOfficeInstalled) {
	[string]$CurrentOfficeVer=(Get-WmiObject win32_product | Where-Object {$_.Name -like "Office 16 Click-to-Run Licensing Component"}).Version
	[string]$LastCheckedVer=(Get-Content "$($env:LOCALAPPDATA)\Programs\Office Deployment Tool\CurrentOfficeVer.json" | ConvertFrom-Json)
	if($CurrentOfficeVer -like $LastCheckedVer) {
		Write-Host "Office was not updated since last time the program was running"
	}
	elseif((Test-Path "$($MSOfficeLoc)\Office16\ACCESS.EXE") -or (Test-Path "$($MSOfficeLoc)\Office16\MSPUB.EXE")) { 
		# Access and Publisher are things I definitely dont't need. If they are present, it means a cleanup is needed
		$MSCleanupConfig=@'
		<Configuration>
		<Add OfficeClientEdition="64" Channel="Current">
		  <Product ID="O365ProPlusRetail">
			<Language ID="de-de" />
			<ExcludeApp ID="Access" />
			<ExcludeApp ID="Publisher" />
			<ExcludeApp ID="OneDrive" />
			<ExcludeApp ID="Groove" />
			<ExcludeApp ID="Lynk" />
			<ExcludeApp ID="OneNote" />
			<!-- If not using Outlook UWP App comment out the next line to avoid removing Outlook -->
			<ExcludeApp ID="Outlook" />
		  </Product>
		</Add>
		<Updates Enabled="TRUE" Channel="Broad" />
		<Display Level="None" AcceptEULA="TRUE" />
	  </Configuration>
'@
		$MSCleanupConfig | Out-File "$($env:TEMP)\OfficeCleanupCfg.xml"
		Start-Process -FilePath "$($env:LOCALAPPDATA)\Programs\Office Deployment Tool\setup.exe" -ArgumentList "/configure ""$($env:TEMP)\OfficeCleanupCfg.xml"""
		ConvertTo-Json -InputObject $CurrentOfficeVer | Out-File "$($env:LOCALAPPDATA)\Programs\Office Deployment Tool\CurrentOfficeVer.json"
	}
}
else {
	Write-Host "MS Office is not installed at all."
}
if($OfficeCleanupOnly -or ((Get-AppxPackage "Microfost.WindowsStore").count -eq 0)) {
	exit
}
#Define apps that has file association used
# [string[]]$AppsWithFileAsso=@("Microsoft.Paint", "Microsoft.WindowsTerminal", "Microsoft.WindowsTerminalPreview", "PythonSoftwareFoundation.Python.3.10")
# Define apps that need to be removed
[string[]]$uselessapps=@("Microsoft.WindowsAlarms",`
	"Microsoft.Windows.Photos", "Microsoft.549981C3F5F10", "Microsoft.WindowsMaps","Microsoft.YourPhone",`
	"Microsoft.GetHelp","Microsoft.BingNews","Microsoft.WindowsNotepad",`
	"Microsoft.People", "Microsoft.MicrosoftStickyNotes", "Microsoft.MicrosoftOfficeHub",` #"Microsoft.Office.OneNote", 
	"Microsoft.Microsoft3DViewer","Microsoft.MicrosoftSolitaireCollection",`
	"Microsoft.MixedReality.Portal", "Microsoft.XboxApp", "Microsoft.WindowsCalculator", "Microsoft.SkypeApp",`
	"Microsoft.MSPaint", "Microsoft.BingWeather", "Microsoft.Getstarted", "Microsoft.WindowsSoundRecorder", "Microsoft.Todos",`
	"Microsoft.PowerAutomateDesktop", "Microsoft.GamingApp", "Microsoft.XboxIdentityProvider", "Microsoft.WindowsFeedbackHub",`
	"AdvancedMicroDevicesInc-2.AMDLink","Microsoft.XboxGamingOverlay",`
	"Clipchamp.Clipchamp", "MicrosoftCorporationII.MicrosoftFamily", "MicrosoftCorporationII.QuickAssist", "MicrosoftTeams",`
	"AdvancedMicroDevicesInc-2.AMDRadeonSoftware", "microsoft.windowscommunicationsapps", "microsoft.outlookforwindows") #"Microsoft.ScreenSketch",
if(((Get-AppxPackage "*WindowsTerminalPreview*") -like "*WindowsTerminalPreview*")) {
	$uselessapps = $uselessapps + @("Microsoft.WindowsTerminal")
}
if(Test-Path "C:\Program Files\NVIDIA Corporation\NVIDIA app\CEF\NVIDIA App.exe") {
	$uselessapps = $uselessapps + @("NVIDIACorp.NVIDIAControlPanel")
}
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
# Start-Sleep -Seconds 5
# $AllApps = Get-AppxPackage -allusers *
# [bool]$FileAssoRegRefreshNeeded=$false
# foreach($UWPapp in $AllApps)
# {
# 	if(-Not $uselessapps.Contains($UWPapp.Name))	{
# 		if($UWPapp.PackageUserInformation -like "*Staged*") {
# 			Write-Output "refreshing $($UWPapp.PackageFullName)"
# 			try {
# 				Add-AppxPackage -DisableDevelopmentMode -Register "$($UWPapp.InstallLocation)\AppXManifest.xml" -Erroraction 'silentlycontinue'
# 			}
# 			catch {
# 				if(($Error[0] -like "*0x80073D06*") -and ()) {
# 					Write-Output "This package is outdated, removing ..."
# 					ForceUninstall $UWPapp
# 					# if($AppsWithFileAsso.contains($UWPapp.Name)) {
# 					# 	Write-Host "need to refresh file associations context menu of file $($UWPapp.name)" -ForegroundColor Cyan
# 					# 	$FileAssoRegRefreshNeeded=$true
# 					# }
# 					if($UWPapp.Name -like "Microsoft.WindowsTerminal*") {
# 						powershell.exe -File "$($PSScriptRoot)\Symlink_AppData.ps1" -TerminalOnly
# 					}
# 					Write-Host "`n"
# 			}
# 		}
# 		}
# 	}
# }
# if($FileAssoRegRefreshNeeded) {
# 	powershell.exe -File "$($PSScriptRoot)\WriteRegistry.ps1" -ArgumentList "-UWPRefreshOnly"
# }