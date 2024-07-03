. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
RunAsAdmin "$($PSCommandPath)"
[int]$CurrentBuildVer=[System.Environment]::OSVersion.Version.Build
if($CurrentBuildVer -lt 19045) { # This script can work
    $EdgeFolders=(Get-Item "C:\Program Files (x86)\Microsoft\Edge*")
    [string]$UninsCommand="msedge"
    foreach($F in $EdgeFolders) {
        [string]$InstallerLocation="$($F.FullName)\Application\*.*.*.*\Installer\setup.exe"
        if($F.BaseName -eq "EdgeCore") {
            [string]$InstallerLocation="$($F.FullName)\*.*.*.*\Installer\setup.exe"
        }
        if($F.BaseName -eq "EdgeWebView") {
            $UninsCommand="msedgewebview"
        }
        $Installer=(Get-Item "$($InstallerLocation)" -ea 0)
        if($Installer.count -eq 1) {
            Start-Process "$($Installer.FullName)" -ArgumentList "--uninstall --force-uninstall --$UninsCommand --system-level --verbose-logging"
        }
    }
}