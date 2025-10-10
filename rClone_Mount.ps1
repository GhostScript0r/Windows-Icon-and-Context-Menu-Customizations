[OutputType([string])]
param(
    [string]$DriveToMount="",
    [switch]$AutoMountAll,
    [switch]$ManualMountMode
)
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
. "$($PSScriptRoot)\Functions\TestNetConnection.ps1"
. "$($PSScriptRoot)\Functions\Hashtables.ps1"
# Use $PSBoundParameters to get all passed parameters and their values.
RunAsAdmin "$($PSCommandPath)" -Arguments $PSBoundParameters
[string]$rCloneCloudFolder="$($env:LocalAppdata)\rclone\CloudFolders"
[hashtable]$CloudDriveWebsites=(GetHashTables "CloudWebsites") # Get the hashtable with cloud drive websites
New-Item -ItemType Directory -Path "$($rCloneCloudFolder)" -ea 0 | Out-Null
[string[]]$rCloneConfText=(Get-Content "$($env:Appdata)\rclone\rclone.conf") # Entire rClone config file in text
[string[]]$rCloneDrives=(($rCloneConfText -match '\[.*\]') -replace '\[','' -replace '\]','')
[string[]]$rCloneDrivesCLSIDs=(Get-Item "Registry::HKCR\CLSID\{6587a16a-ce27-424b-bc3a-8f044d36fd??}").Name

if($(where.exe cotp.exe) -like "*cotp.exe") { #2FA CLI utility (CLI based authenticator) installed
    [string[]]$rCloneEntries2FA=($rCloneConfText -match "2fa = \d{6}") # Find all entries including 2FA codes
    if($rCloneEntries2FA.count -eq 0) {
        Write-Host "No 2FA codes found in rClone config file."
        $ThereIs2FACode=$false
    }
    else {
        [bool]$ThereIs2FACode=$true
        [string[]]$rCloneEntries2FA_New=[System.Array]::CreateInstance([string],$rCloneEntries2FA.Count)
        Write-Host "Found following 2FA Codes: $($rCloneEntries2FA -join ', ' -replace '2fa = ','')" -ForegroundColor White -BackgroundColor DarkGreen
    }
    
}
[int]$i=0
Write-Host "In total there are $($rclonedrivesclsids.count) rClone drive entries in Windows Explorer and $($rclonedrives.count) rClone drives in the config file."
if($rCloneDrivesCLSIDs.Count -ne $rCloneDrives.count) {
    . "$($PSScriptRoot)\Functions\RegistryTweaks-CustomNamespaces.ps1"
    GenerateCustomNamespace "rClone"
}
[string[]]$IgnoreDrives=@()
if((-not $AutoMountAll) -and (Test-Path "$($env:Appdata)\rclone\NoAutoMount.txt") -and (-not $ManualMountMode)) {
    $IgnoreDrives=(Get-Content "$($env:Appdata)\rclone\NoAutoMount.txt") # Read the list of drives to ignore from a file
}
foreach($rCloneEntry in $rCloneDrives) {
    if($ManualMountMode -and ($DriveToMount -ne $rCloneEntry)) { # If manual mount mode is on, skip all drives except the one specified
        Write-Host "Skipping rclone instance: $($rCloneEntry) as it is not the one specified for manual mount." -ForegroundColor Yellow
        continue
    }
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
        $rCloneConfText = (Get-Content "$($env:Appdata)\rclone\rclone.conf") # Run this again to get the full proper text of the config file. There had been bugs where unrelated parts were changed and removed.
        $rCloneConfText_New2FA = $rCloneConfText -replace "$($rCloneEntries2FA[$i])","$($rCloneEntries2FA_New[$i])"
        if($rCloneConfText.length -eq $rCloneConfText_New2FA.length) {
            Write-Host "Length of original and new rClone config text match. Proceeding to update the config file." -ForegroundColor Green
        }
        else {
            Write-Host "Length of original and new rClone config text do NOT match. Something went wrong. Skipping update of the config file to prevent damaging or overwriting the original rclone.conf." -ForegroundColor Red
            continue
        }
        $rCloneConfText_New2FA| Set-Content "$($env:Temp)\rclone.conf_NEW"
        if((Get-Content "$($env:Temp)\rclone.conf_NEW").length -lt (Get-Content "$($env:Appdata)\rclone\rclone.conf").length - 2) {
            Write-Host "New rClone config file is significantly smaller than the original. Something went wrong. Skipping update of the config file to prevent damaging or overwriting the original rclone.conf." -ForegroundColor Red
            Remove-Item "$($env:Temp)\rclone.conf_NEW" -Force -ErrorAction SilentlyContinue 
        }
        else {
            Move-Item "$($env:Temp)\rclone.conf_NEW" "$($env:Appdata)\rclone\rclone.conf" -Force
            Write-Host "Successfully updated the rClone config file with new 2FA code." -ForegroundColor Green
        }
        $i=$i+1
    }
    Write-Host "Check if internet connection is working for $($rCloneEntry)..." -ForegroundColor White -BackgroundColor Blue
    [string]$rCloneCloudType=($rCloneEntry -split '-')[0]
    Write-Host "$rCloneCloudType" -ForegroundColor Cyan
    if($CloudDriveWebsites.ContainsKey($rCloneCloudType)) {
        [string]$WebsiteToCheck=$CloudDriveWebsites.$rCloneCloudType
    }
    else {
        [string]$WebsiteToCheck="www.box.com" # Default value if the website is not found in the hashtable
    }
    [bool]$ConnectionAvailable=$(TestNetConnection $WebsiteToCheck)
    [bool]$rCloneAlreadyRunning=$($RunningInstances -like "*: $($rCloneLocalFolder) --vfs-cache-mode full*")
    if($ConnectionAvailable -eq $rCloneAlreadyRunning) {
        Write-Host "No need to take any action. Either (internet is okay and rclone is already running) or (internet is not available and rclone is not running)." 
    }
    elseif($ConnectionAvailable -and (-not $rCloneAlreadyRunning)) {
        if(($rclonecloudtype -in $IgnoreDrives) -and (-not $ManualMountMode)) { # If the drive is in the ignore list and not manually chosen to be mounted, skip it
            Write-Host "Skipping mounting of rclone instance: $($rCloneEntry) as it is in the ignore list." -ForegroundColor Yellow
        }
        else {
            Write-Host "Starting rclone instance: $($rCloneEntry)" 
            Remove-Item "$($rCloneLocalFolder)" -Force -Recurse -ErrorAction SilentlyContinue 
            Start-Sleep -s 1 
            Start-Process "$($env:LOCALAPPDATA)\Programs\rclone\rclone.exe" -ArgumentList "mount $($rCloneEntry): $rCloneLocalFolder --vfs-cache-mode full --no-console $($ExtraArg)" -NoNewWindow
            Write-Host "Starting of process ended with code $?"
        }
    } 
    elseif($rCloneAlreadyRunning -and (-not $ConnectionAvailable)) {
        Write-Host "Stopping rclone instance: $($rCloneEntry) as connection is down to that website"
        Get-CimInstance -ClassName Win32_Process -Filter "Name = 'rclone.exe'" | Where-Object {$_.CommandLine -like "* mount $($rCloneEntry): *"} | Stop-Process -Force
    }
}
Write-Host "Script finished with arguments: $($ArgumentsToPass)" -ForegroundColor Green
return "$($rCloneCloudFolder)"