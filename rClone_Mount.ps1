[OutputType([string])]
param()
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
. "$($PSScriptRoot)\Functions\TestNetConnection.ps1"
RunAsAdmin "$($PSCommandPath)"
[string]$rCloneCloudFolder="$($env:LocalAppdata)\rclone\CloudFolders"
New-Item -ItemType Directory -Path "$($rCloneCloudFolder)" -ea 0 | Out-Null
if($(TestNetConnection)) { # Need to ping box.com to make sure ipv4 works
    [string[]]$rCloneConfText=(Get-Content "$($env:Appdata)\rclone\rclone.conf") # Entire rClone config file in text
    [string[]]$rCloneDrives=(($rCloneConfText -match '\[.*\]') -replace '\[','' -replace '\]','')
    [string[]]$rCloneDrivesCLSIDs=(Get-Item "Registry::HKCR\CLSID\{6587a16a-ce27-424b-bc3a-8f044d36fd??}").Name
    if($(where.exe cotp.exe) -like "*cotp.exe") { #2FA CLI utility installed
        [string[]]$rCloneEntries2FA=($rCloneConfText -match "2fa = \d{6}") # Find all 2fa entries
        [string[]]$rCloneEntries2FA_New=[System.Array]::CreateInstance([string],$rCloneEntries2FA.Count)
        [int]$i=0
    }
    Write-Host "In total there are $($rclonedrivesclsids.count) rClone drive entries in Windows Explorer and $($rclonedrives.count) rClone drives in the config file."
    if($rCloneDrivesCLSIDs.Count -ne $rCloneDrives.count) {
        . "$($PSScriptRoot)\Functions\RegistryTweaks-CustomNamespaces.ps1"
        GenerateCustomNamespace "rClone"
    }
    foreach($rCloneEntry in $rCloneDrives) {
        [string]$rCloneLocalFolder="$($rCloneCloudFolder)\$($rCloneEntry)"
        [string]$ExtraArg=""
        if($rCloneEntry -eq "Google_Photos") {
            $rCloneLocalFolder="$($env:USERPROFILE)\Pictures\$($rCloneEntry)"
            $ExtraArg="--gphotos-read-size" # This will force rclone to cache all photos in Google Photos folder instead of showing files with 0 byte size.
        }       
        [string]$RunningInstances=(Get-WmiObject Win32_Process -Filter "name = 'rclone.exe'").CommandLine
        [string]$_2FACode=$(Get-Content "$($env:APPDATA)\cotp\p.cotp" | cotp.exe --password-stdin extract --label "$($rCloneEntry)")
        if($_2FACode -match '^\d{6}$') { # There is 2FA code
            Write-Host "Refreshing the 2FA code of $($rCloneEntry).  Old code = $($rCloneEntries2FA[$i] -replace '2fa = ',''), New code = $($_2FACode)" -ForegroundColor White -BackgroundColor Blue
            $rCloneEntries2FA_New[$i]="2fa = $($_2FACode)"
            $rCloneConfText -replace "$($rCloneEntries2FA[$i])","$($rCloneEntries2FA_New[$i])" | Set-Content "$($env:Appdata)\rclone\rclone.conf"
            $i=$i+1
        }
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
return "$($rCloneCloudFolder)"