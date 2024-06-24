# Get admin privilege
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
RunAsAdmin "$($PSCommandPath)"
# ______________________________
[version]$CurrentBuildVer=[System.Environment]::OSVersion.Version
# Install WSL and Kali Linux
. "$($PSScriptRoot)\Functions\GitHubReleaseDownload.ps1"
if($CurrentBuildVer.Build -ge 19041) {
	GitHubReleaseDownload "microsoft/WSL" -OtherStringsInFileName ".x64.msi" -InstallationName "Windows Subsystem for Linux"
} # Older releases does not support WSL2 kernel on GitHub, needs to use update from Microsoft Update Catalog instead
elseif($CurrentBuildVer.Build -ge 18000) { # WSL2 support starts from Windows 10 1903. Older versions like 2019 LTSC (1809) does not support WSL2 and can only run WSL1
	[bool]$WSLKernelInstalled=(Get-ChildItem "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object {(Get-ItemProperty "Registry::$($_.Name)").DisplayName -like "Windows Subsystem for Linux Update" }).count
	if(-not $WSLKernelInstalled) {
		Invoke-WebRequest -Uri "https://catalog.s.download.windowsupdate.com/d/msdownload/update/software/updt/2022/03/wsl_update_x64_8b248da7042adb19e7c5100712ecb5e509b3ab5f.cab" -OutFile "$($env:TEMP)\WSL.cab"
		expand.exe -F:wsl_update_x64.msi "$($env:TEMP)\WSL.cab" "$($env:TEMP)\WSL.msi"
		msiexec.exe /I "$($env:TEMP)\WSL\WSL.msi" /quiet
	}
}
else {
	Write-Host "WSL2 not supported on this build."
}
. "$($PSScriptRoot)\Functions\GetDefaultWSL.ps1"
if((-not $(GetDefaultWSL)) -and $CurrentBuildVer.Build -ge 18000) { # No WSL distro installed. WSL2 supported
	Write-Host "Download and install Kali Linux"
	Invoke-WebRequest "https://aka.ms/wsl-kali-linux-new" -outfile "$($env:TEMP)\Kali-Linux.zip"
	Expand-Archive -Path "$($env:TEMP)\Kali-Linux.zip" -Destination "$($env:TEMP)\Kali\"
	[string]$X64Package=(Get-Item "$($env:TEMP)\Kali\DistroLauncher-Appx_*_x64.appx").FullName
	Rename-Item -Path "$($X64Package)" -NewName "Kali_x64.zip"
	Expand-Archive -Path "$($env:TEMP)\Kali\Kali_x64.zip" -Destination "$($env:LOCALAPPDATA)\Kali"
	Start-Process "$($env:LOCALAPPDATA)\kali\kali.exe"
}
# __________________________
# Install GitHub desktop
Invoke-WebRequest "https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi" -OutFile "$($env:TEMP)\GitHub.msi"
msiexec.exe /i "$($env:TEMP)\GitHub.msi" /quiet 
# __________________________
# Install programs from GitHub
GitHubReleaseDownload "benbuck/rbtray" -OtherStringsInFileName ".zip" -IsZIP
GitHubReleaseDownload "NationalSecurityAgency/ghidra" -Arch "PUBLIC" -OtherStringsInFileName ".zip" -IsZIP
GitHubReleaseDownload "rclone/rclone" -Arch "amd64" -OtherStringsInFileName "windows" -IsZIP
GitHubReleaseDownload "syncthing/syncthing" -Arch "amd64" -OtherStringsInFileName "windows" -IsZIP
GitHubReleaseDownload "Genymobile/scrcpy" -Arch "win64" -IsZIP -InstallPath "$($env:LOCALAPPDATA)\Microsoft\WindowsApps"
# _________________________
# Download NirSoft programs
[string[]]$NirSoftUtilities=@("iconsext","resourcesextract")
[bool[]]$With_x64=@(0,1)
for($i=0;$i -lt $NirSoftUtilities.count;$i++) {
	[string]$ProgramName=$NirSoftUtilities[$i] + ".exe"
	if (Test-Path "$($env:LOCALAPPDATA)\Programs\NirSoft\$($ProgramName)") {
		continue
	}
	[string]$ZipName=$NirSoftUtilities[$i]
	if($With_x64[$i]) {
		$ZipName=$ZipName + "-x64"
	}
	Invoke-WebRequest "https://www.nirsoft.net/utils/$($ZipName).zip" -OutFile "$($env:TEMP)\$($ZipName).zip"
	# [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
	Expand-Archive -Path "$($env:TEMP)\$($ZipName).zip" -DestinationPath "$($env:TEMP)"
	Move-Item -Path "$($env:TEMP)\$($ProgramName)" -Destination "$($env:LOCALAPPDATA)\Programs\NirSoft\$($ProgramName)"
}
# ____________________________
# Download Coherent PDF
[string]$CPDF="$($env:LOCALAPPDATA)\Microsoft\WindowsApps\cpdf.exe"
if(-not (Test-Path "$($CPDF)")) {
	Invoke-WebRequest "https://github.com/coherentgraphics/cpdf-binaries/blob/master/Windows64bit/cpdf.exe" -Outfile "$($CPDF)"
}
# ____________________________
# Install programs with WinGet
# Check in Winget is installed
where.exe winget.exe
if($lastexitcode -eq 1) { # Winget not installed
    Write-Information "Downloading WinGet and its dependencies..."
	Invoke-WebRequest -Uri https://aka.ms/getwinget -OutFile "$($env:TEMP)\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
	Invoke-WebRequest -Uri https://aka.ms/Microsoft.VCLibs.x64.14.00.Desktop.appx -OutFile "$($env:TEMP)\Microsoft.VCLibs.x64.14.00.Desktop.appx"
	Invoke-WebRequest -Uri https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.x64.appx -OutFile "$($env:TEMP)\Microsoft.UI.Xaml.2.8.x64.appx"
	Add-AppxPackage "$($env:TEMP)\Microsoft.VCLibs.x64.14.00.Desktop.appx"
	Add-AppxPackage "$($env:TEMP)\Microsoft.UI.Xaml.2.8.x64.appx"
	Add-AppxPackage "$($env:TEMP)\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
}
try {
	winget.exe --help
}
catch {
	. "$($PSScriptRoot)\Functions\BallonNotif.ps1"
	try {
		. "$($PSScriptRoot)\Functions\RegistryTweaks-BasicOps.ps1"
		# Enable Developer Mode (allow installation of Microsoft Apps without valid license / signature)
		CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
		SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" -Name "AllowDevelopmentWithoutDevLicense" -Value 1 Type "4"
		Invoke-CommandInDesktopPackage -PackageFamilyName Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -AppId winget -command cmd.exe
	}
	catch {
		BallonNotif "Winget.exe cannot start. Turn on development mode in system settings and try again."
		exit
	}
	
}
[string[]]$ListOfPrograms=@()
# VSRedist Runtimes
foreach($VCRedistVersion in @("2005","2008","2010","2012","2013","2015+")) {
	foreach($VCArch in @("x86","x64")) {
		$listofprograms= $listofprograms + @("Microsoft.VCRedist.$($VCRedistVersion).$($VCArch)")
	}
}

# .NET Desktop Runtimes
for($i=5; $i -le 8; $i++)
{
	$listofprograms= $listofprograms + @("Microsoft.DotNet.DesktopRuntime.$($i)")
}

$listofprograms=$listofprograms+@(`

# Cloud Drive Programs
"Box.Box" #,"Google.Drive","pCloudAG.pCloudDrive","Dropbox.Dropbox",` #"Microsoft.OneDrive",
"WinFsp.WinFsp",` # WinFSP needed for Rclone mount "Rclone.Rclone",

# MSSQL
"Microsoft.SQLServerManagementStudio",`

# Dev kit
# "Docker.DockerDesktop",`
"Git.Git","OpenJS.NodeJS",`

 "7zip.7zip",` #"PeaZip",`
"OBSProject.OBSStudio",`
"Datronicsoft.SpacedeskDriver.Server",`
"Google.Chrome","Google.ChromeRemoteDesktop",` #"TeamViewer.TeamViewer",`
"Ausweisapp",`

# Gaming renderer
"Nvidia.PhysX","Microsoft.DirectX",`
"Oracle.JavaRuntimeEnvironment",`

# Network
"PrivateInternetAccess.PrivateInternetAccess",`
"qBittorrent.qBittorrent",`
"SpeedCrunch.SpeedCrunch",`

# Image processing
# "ImageMagick.ImageMagick","ArtifexSoftware.GhostScript",`
"GIMP.GIMP",`
"Rainmeter.Rainmeter",`
"VideoLAN.VLC",` # "KDE.Kdenlive",`
# "Workrave.Workrave",`
"BotProductions.IconViewer",`

# Penetration testing and digital forensics tools
"WiresharkFoundation.Wireshark","Insecure.Npcap",`

# Games launcher
# "EpicGames.EpicGamesLauncher",

# Lenovo Legion toolkit
"BartoszCichecki.LenovoLegionToolkit",`

# Office app
"ONLYOFFICE.DesktopEditors"` # "OneNote"

)
if([System.Environment]::OSVersion.Version.Build -ge 19041) {
	$listofprograms=$listofprograms+@("Microsoft.PowerToys") # PowerToys requires Build 19041 or higher
}
if((Get-AppxPackage "Microsoft.WindowsStore").count -eq 0) { # This is a Windows 10 2019 LTSC without store.
	$listofprograms=@("Python3")
}
foreach ($program in $listofprograms)
{
	Write-Host "Checking if $($program) is installed..."
	[string]$installstatus=$(winget list $program) # Check exact match. So that things like Google Chrome remote desktop won't be having a problem.
	if($installstatus -NotLike "*$($program)*")
	{
		Write-Host "Program $($program) is not yet installed. Installing...."
		winget install $program --source winget --accept-package-agreements --accept-source-agreements
	}
	else {
		Write-Host "Program $($program) is already installed." -ForegroundColor Green
	}
}

$ProgramsWithUpgrade=$(winget upgrade).ID
foreach ($ProgramUpgrade in $ProgramsWithUpgrade) {
	Write-Host "There's a newer version for $($ProgramUpgrade). Updating..." 
	winget upgrade $ProgramUpgrade --accept-package-agreements --accept-source-agreements
}
