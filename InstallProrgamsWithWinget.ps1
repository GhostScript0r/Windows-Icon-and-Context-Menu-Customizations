# Get admin privilege
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
[bool]$ScriptIsRunningOnAdmin=($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
if(!($ScriptIsRunningOnAdmin)) {
	Write-Host "The script $($PSCommandPath.Name) is NOT running with Admin privilege."
	Start-Process powershell.exe -ArgumentList "-File `"$($PSCommandPath)`"" -verb runas
	exit
}
else {
	Write-Host "Script is running with Admin privilege" -ForegroundColor Green
}
[string[]]$listofprograms=@(`

# Cloud Drive Programs
"Box.Box" #,"Google.Drive","pCloudAG.pCloudDrive","Dropbox.Dropbox",` #"Microsoft.OneDrive",
"Rclone.Rclone","WinFsp.WinFsp",` # WinFSP needed for Rclone mount

# MSSQL
"Microsoft.SQLServerManagementStudio",`
# "OpenJS.NodeJS","Git.Git","Docker.DockerDesktop",`
"PeaZip",` # "7zip.7zip",`
"OBSProject.OBSStudio",`
"Datronicsoft.SpacedeskDriver.Server",`
"Google.ChromeRemoteDesktop",` #"TeamViewer.TeamViewer",`
"Ausweisapp",`
"Nvidia.PhysX","Microsoft.DirectX",`
"Oracle.JavaRuntimeEnvironment",`
"PrivateInternetAccess.PrivateInternetAccess",`
"qBittorrent.qBittorrent",`
"SpeedCrunch.SpeedCrunch",`
"ImageMagick.ImageMagick","ArtifexSoftware.GhostScript","GIMP.GIMP",`
"Rainmeter.Rainmeter",`
"VideoLAN.VLC",` # "KDE.Kdenlive",`
# "Workrave.Workrave",`
"BotProductions.IconViewer",`

# Penetration testing and digital forensics tools
"WiresharkFoundation.Wireshark","Insecure.Npcap"
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