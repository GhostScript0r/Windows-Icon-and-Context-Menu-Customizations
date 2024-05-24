# Get admin privilege
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
RunAsAdmin "$($PSCommandPath)"

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

[string[]]$listofprograms=@(`

# Cloud Drive Programs
"Box.Box" #,"Google.Drive","pCloudAG.pCloudDrive","Dropbox.Dropbox",` #"Microsoft.OneDrive",
"Rclone.Rclone","WinFsp.WinFsp",` # WinFSP needed for Rclone mount

# MSSQL
"Microsoft.SQLServerManagementStudio",`

# Dev kit
# "Docker.DockerDesktop",`
"Git.Git","OpenJS.NodeJS",`

"Microsoft.PowerToys",`
"PeaZip",` # "7zip.7zip",`
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
"EpicGames.EpicGamesLauncher",

# Office app
"ONLYOFFICE.DesktopEditors"` # "OneNote"

)

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

foreach ($program in $listofprograms)
{
	Write-Host "Checking if $($program) is installed..."
	[string]$installstatus=$(winget list $program -e) # Check exact match
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

# Install programs from GitHub
. "$($PSScriptRoot)\Functions\GitHubReleaseDownload.ps1"
GitHubReleaseDownload "microsoft/WSL" -OtherStringsInFileName ".x64.msi" -InstallationName "Windows Subsystem for Linux"