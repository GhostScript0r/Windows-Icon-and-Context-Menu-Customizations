# Get admin privilege
param(
	[switch]$SkipWinGet,
	[switch]$WingetUpdateOnly,
	[switch]$GitHubCheckOnly
)
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
RunAsAdmin "$($PSCommandPath)"
if($UpdateOnly) {
	winget.exe upgrade --all --disable-interactivity --accept-package-agreements --accept-source-agreements
	exit
}
# ______________________________
# Import necessary functions
. "$($PSScriptRoot)\Functions\GitHubReleaseDownload.ps1"
[version]$CurrentBuildVer=[System.Environment]::OSVersion.Version
# ______________________________
# Install WSL2
if((Get-WindowsOptionalFeature -online -featurename "Microsoft-Windows-Subsystem-Linux").State -like "enabled") {
	if(($CurrentBuildVer.Build -ge 19041)) {
		if(-not (Test-Path "C:\Program Files\WSL\wsl.exe")) {
			GitHubReleaseDownload "microsoft/WSL" -OtherStringsInFileName ".x64.msi" -InstallationName "Windows Subsystem for Linux"
		}
	} # Older releases does not support WSL2 kernel on GitHub, needs to use update from Microsoft Update Catalog instead
	elseif(($CurrentBuildVer.Build -ge 18000) -and ($CurrentBuildVer.Build -lt 19041)) { # WSL2 support starts from Windows 10 1903. Older versions like 2019 LTSC (1809) does not support WSL2 and can only run WSL1
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
	if((-not $(GetDefaultWSL)) -and ($CurrentBuildVer.Build -ge 18000)) { # WSL2 supported, yet no WSL distro installed.
		# Will Install a Linux distro. Ubuntu or Kali Linux
		# Write-Host "Download and install a Linux Distro first"
		# Invoke-WebRequest "https://aka.ms/wsl-kali-linux-new" -outfile "$($env:TEMP)\Kali-Linux.zip"
		# Expand-Archive -Path "$($env:TEMP)\Kali-Linux.zip" -Destination "$($env:TEMP)\Kali\" -Force
		# [string]$X64Package=(Get-Item "$($env:TEMP)\Kali\DistroLauncher-Appx_*_x64.appx").FullName
		# Rename-Item -Path "$($X64Package)" -NewName "Kali_x64.zip"
		# Expand-Archive -Path "$($env:TEMP)\Kali\Kali_x64.zip" -Destination "$($env:LOCALAPPDATA)\Kali"
		# Start-Process "$($env:LOCALAPPDATA)\kali\kali.exe"
	}
}
# __________________________
# Install GitHub desktop - it's not working very well. So it's commented out and has to be installed manually.
# Invoke-WebRequest "https://central.github.com/deployments/desktop/desktop/latest/win32?format=msi" -OutFile "$($env:TEMP)\GitHub.msi"
# msiexec.exe /i "$($env:TEMP)\GitHub.msi" /quiet 
# __________________________
# Install programs from GitHub
# if($CurrentBuildVer.Build -lt 20000) { # System is Windows 10 - Windows 11 also needs acrylic menu for legacy context menu so this "if" statement is disabled.
	# GitHubReleaseDownload "namazso/SecureUxTheme" -Extension ".exe" -Arch "Tool" -OtherStringsInFileName "ThemeTool" -DownloadOnly
	# GitHubReleaseDownload "Maplespe/DWMBlurGlass" -IsZIP -InstallPath "C:\Program Files\BlurGlass"
	if(!(Test-Path "C:\Program Files\AcrylicMenus\AcrylicMenusLoader.exe")) {
		GitHubReleaseDownload "krlvm/AcrylicMenus" -IsZIP -Arch "Menus"
		[string]$AcrylicMenuInstallScript="$($env:LOCALAPPDATA)\Programs\AcrylicMenus\Installer\InstallAllUsers.cmd"
		$ScriptContent=Get-Content "$($AcrylicMenuInstallScript)" | Where-Object {$_ -notlike "pause"}
		$ScriptContent | Set-Content "$($AcrylicMenuInstallScript)"
		Invoke-Item "$($AcrylicMenuInstallScript)"
	}
	if(Test-Path "C:\Program Files\AcrylicMenus\AcrylicMenusLoader.exe") {
		Remove-Item -Path "$($env:LOCALAPPDATA)\Programs\AcrylicMenus" -Force -Recurse -ea 0
	}
	# GitHubReleaseDownload "ChrisAnd1998/TaskbarX" -IsZIP # It didn't work very well so I disabled it.
# }
# __________________________
# Install Acrylic Explorer (Disabled as it hampers the readibility of explorer)
# [string]$AcrylicExplorerDLL="C:\Program Files\AcrylicMenus\ExplorerBlurMica.dll"
# if((!(Test-Path $AcrylicExplorerDLL))) {
# 	GitHubReleaseDownload "Maplespe/ExplorerBlurMica" -IsZIP -InstallPath "$(Split-Path $AcrylicExplorerDLL)"
# 	foreach($DownloadFile in $(Get-ChildItem "$(Split-Path $AcrylicExplorerDLL)\Release\*.*")) {
# 		Move-Item -Path "$($DownloadFile.FullName)" -Destination "$(Split-Path $AcrylicExplorerDLL)"
# 	}
# 	Remove-Item "$(Split-Path $AcrylicExplorerDLL)\Release"
# 	$AcrylicExplorerConfig=(Get-Content "$(Split-Path $AcrylicExplorerDLL)\config.ini")
# 	$AcrylicExplorerConfig -replace 'a=\d+','a=25' | Set-Content "$(Split-Path $AcrylicExplorerDLL)\config.ini" # Reduce the transparency to make the explorer texts more readable.
# 	regsvr32.exe "$($AcrylicExplorerDLL)" /s
# }
# GitHub check separated from winget update and will be run in a less frequent pace (daily) because otherwise the API rate limit can be exhausted quickly.
GitHubReleaseDownload "kovidgoyal/calibre" -Arch "64bit" -Extension ".msi" -OtherStringsInFileName ".msi" -InstallPath "C:\Program Files" -InstallationName "calibre 64bit"
GitHubReleaseDownload "jonaskohl/CapsLockIndicator" -Arch "CLI" -Extension ".exe" -DownloadOnly
GitHubReleaseDownload "benbuck/rbtray" -OtherStringsInFileName ".zip" -IsZIP
GitHubReleaseDownload "NationalSecurityAgency/ghidra" -Arch "PUBLIC" -OtherStringsInFileName ".zip" -IsZIP
GitHubReleaseDownload "rclone/rclone" -Arch "amd64" -OtherStringsInFileName "windows" -IsZIP
GitHubReleaseDownload "syncthing/syncthing" -Arch "amd64" -OtherStringsInFileName "windows" -IsZIP -NoUpdate
GitHubReleaseDownload "Genymobile/scrcpy" -Arch "win64" -IsZIP -InstallPath "$($env:LOCALAPPDATA)\Microsoft\WindowsApps"
GitHubReleaseDownload "yt-dlp/yt-dlp" -Arch ".exe" -Extension ".exe" -InstallPath "$($env:LOCALAPPDATA)\Microsoft\WindowsApps" -DownloadOnly
GitHubReleaseDownload "replydev/cotp" -Arch "x86_64-win" -IsZIP -InstallPath "$($env:LOCALAPPDATA)\Microsoft\WindowsApps" -DownloadOnly
if($GitHubCheckOnly) {
	exit
}
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
	Expand-Archive -Path "$($env:TEMP)\$($ZipName).zip" -DestinationPath "$($env:TEMP)" -Force
    New-Item -Path "$($env:LOCALAPPDATA)\Programs\NirSoft\$($ProgramName)" -ItemType Directory -ea 0
	Move-Item -Path "$($env:TEMP)\$($ProgramName)" -Destination "$($env:LOCALAPPDATA)\Programs\NirSoft\$($ProgramName)"
}
# ____________________________
# Download Coherent PDF
[string]$CPDF="$($env:LOCALAPPDATA)\Microsoft\WindowsApps\cpdf.exe"
if(-not (Test-Path "$($CPDF)")) {
	Invoke-WebRequest "https://github.com/coherentgraphics/cpdf-binaries/blob/master/Windows64bit/cpdf.exe?raw=true" -Outfile "$($CPDF)"
}
# ____________________________
# Download the cute Oneko
# [string]$OnekoProgram="$($env:LOCALAPPDATA)\Programs\Oneko.exe"
# if(-not (Test-Path "$($OnekoProgram)")) {
# 	Invoke-WebRequest "https://github.com/tajas20006/neko2020/blob/master/neko2020.exe?raw=true" -OutFile "$($OnekoProgram)"
# }
# [string]$OnekoConfig="$($env:USERPROFILE)\.config\neko2020\config.yml"
# if(-not (Test-Path "$($OnekoConfig)")) {
# 	New-Item -ItemType Directory -Path "$(Split-Path $OnekoConfig)" -ea 0
# 	Invoke-WebRequest "https://github.com/tajas20006/neko2020/blob/master/config/default_config.yml?raw=true" -OutFile "$($OnekoConfig)"
# }
# ___________________________
# If no WinGet update needed - script ends here
if($SkipWinGet) {
	exit
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
	winget.exe --help | Out-Null # See if WinGet can be run after installation
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
	$listofprograms= $listofprograms + @("Microsoft.DotNet.DesktopRuntime.$($i)") # + @("Microsoft.DotNet.AspNetCore.$($i)")
}

$listofprograms=$listofprograms+@(`

# Cloud Drive Programs
"Box.Box" #,"Google.Drive","pCloudAG.pCloudDrive","Dropbox.Dropbox",` #"Microsoft.OneDrive",
"WinFsp.WinFsp" # WinFSP needed for Rclone mount "Rclone.Rclone",

# MSSQL
"Microsoft.SQLServerManagementStudio"

# Dev kit
# "Docker.DockerDesktop",`
# "Git.Git"
# "OpenJS.NodeJS"

# Everyday tools
"7zip.7zip" #"PeaZip",
"OBSProject.OBSStudio"
"Datronicsoft.SpacedeskDriver.Server"
"Google.ChromeRemoteDesktopHost" #"TeamViewer.TeamViewer",` "Google.Chrome",
"Governikus.Ausweisapp"

# Gaming renderer
"Nvidia.PhysX","Microsoft.DirectX"

# GPU Tool
# "Nvidia.CUDA"

# Java Runtimes
"Oracle.JavaRuntimeEnvironment", "Oracle.JDK.21","Oracle.JDK.22","Oracle.JDK.17"

# Network
"PrivateInternetAccess.PrivateInternetAccess"
"qBittorrent.qBittorrent"
"SpeedCrunch.SpeedCrunch"

# Image processing
# "ImageMagick.ImageMagick","ArtifexSoftware.GhostScript",`
"GIMP.GIMP"
"VideoLAN.VLC","GyanD.FFMPEG" # "KDE.Kdenlive",`
# "Workrave.Workrave",`
"BotProductions.IconViewer"

# Penetration testing and digital forensics tools
"WiresharkFoundation.Wireshark","Insecure.Npcap"

# Games launcher
"EpicGames.EpicGamesLauncher"

# Lenovo Legion toolkit
"BartoszCichecki.LenovoLegionToolkit"

# CMD Tools
# "GNU.MidnightCommander"

#To Run WSL in graphics mode (not needed with WSLg)
# "marha.VcXsrv"

# Dev languages for android development:
# "GoLang.Go"
"Python.Python.3.12"
)
if([System.Environment]::OSVersion.Version.Build -ge 19041) {
	$listofprograms=$listofprograms+@("Microsoft.PowerToys") # PowerToys requires Build 19041 or higher
}

if([System.Environment]::OSVersion.Version.Build -lt 26100) {
	$listofprograms=$listofprograms+@("Rainmeter.Rainmeter") # Rainmeter no longer works properly since Windows 11 24H2 update
}
foreach ($program in $listofprograms)
{
	Write-Host "Checking if $($program) is installed..."
	[string]$installstatus=$(winget list $program) # Check exact match. So that things like Google Chrome remote desktop won't be having a problem.
	if($installstatus -NotLike "*$($program)*")
	{
		Write-Host "Program $($program) is not yet installed. Installing...."
		winget install $program --source winget --accept-package-agreements --accept-source-agreements --scope machine # Scope machine installs stuff system wide
	}
	else {
		Write-Host "Program $($program) is already installed." -ForegroundColor Green
	}
}
# Update programs, if available.
$ProgramsWithUpgrade=$(winget upgrade).ID
foreach ($ProgramUpgrade in $ProgramsWithUpgrade) {
	Write-Host "There's a newer version for $($ProgramUpgrade). Updating..." 
	winget upgrade $ProgramUpgrade --accept-package-agreements --accept-source-agreements
}
# ___________________________
# Install radio-browser.info addon for VLC Media Player
[bool]$VLCInstalled=(Test-Path "C:\Program Files\VideoLAN\VLC\vlc.exe")#([string]((winget list VideoLAN.VLC) -like "*VideoLAN.VLC*")).length -gt 0
if($VLCInstalled) {
	[string]$VLCLuaPath="C:\Program Files\VideoLAN\VLC\lua"
	[string[]]$FilesLocal=@("extensions","sd","playlist")
	[string[]]$FilesLink=@("ex_Radio_Browser_info.lua","sd_Radio_Browser_info.lua","pl_Radio_Browser_info.lua")
	for($i=0;$i -lt $FilesLocal.count; $i++) {
		[string]$FilePath="$($VLCLuaPath)\$($FilesLocal[$i])\$($FilesLink[$i])"
		if(-not (Test-Path "$($FilePath)")) {
			Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ceever/Radio-Browser.info.lua/main/$($FilesLink[$i])" -OutFile "$($FilePath)"
		}
	}
}
#_____________________________
# Install Firefox sidebar
# [string]$FirefoxPath="C:\Program Files\Mozilla Firefox"
# [bool]$FireFoxInstalled=(Test-Path "$($FirefoxPath)\firefox.exe")
# [bool]$GitInstalled=($(where.exe git.exe) -like "*git.exe")
# if($FireFoxInstalled) {
	
# }