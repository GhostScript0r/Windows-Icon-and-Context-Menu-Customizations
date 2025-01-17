. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
RunAsAdmin "$($PSCommandPath)"
if((Test-NetConnection box.com).pingsucceeded) { # Need to ping box.com to make sure ipv4 works
    [string[]]$rCloneDrives=(((Get-Content "$($env:Appdata)\rclone\rclone.conf") -match '\[.*\]') -replace '\[','' -replace '\]','') | Where-Object {$_ -NotIn @("Box")}
    foreach($rCloneEntry in $rCloneDrives) {
        [string]$rCloneLocalFolder="$($env:USERPROFILE)\$($rCloneEntry)"
        [string]$ExtraArg=""
        if($rCloneEntry -eq "Google_Photos") {
            $rCloneLocalFolder="$($env:USERPROFILE)\Pictures\$($rCloneEntry)"
            $ExtraArg="--gphotos-read-size"
        } 
        [string]$RunningInstances=(Get-WmiObject Win32_Process -Filter "name = 'rclone.exe'").CommandLine
        if($RunningInstances -notlike "*: $($rCloneLocalFolder) --vfs-cache-mode full*") {
            Write-Host "Starting rclone instance: $($rCloneEntry)" 
            Remove-Item "$($rCloneLocalFolder)" -Force -Recurse -ErrorAction SilentlyContinue 
            Start-Sleep -s 1 
            Start-Process "$($env:LOCALAPPDATA)\Programs\rclone\rclone.exe" -ArgumentList "mount $($rCloneEntry): $rCloneLocalFolder --vfs-cache-mode full $($ExtraArg)" -NoNewWindow
        } 
    } 
} 
else { 
    Get-Process rclone | Stop-Process # End all rClone instances when internet connection is not available.
}