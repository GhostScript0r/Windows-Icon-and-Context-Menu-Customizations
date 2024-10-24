. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\GetFileSizeOnDisk.ps1"
. "$($PSScriptRoot)\GetDefaultWSL.ps1"
. "$($PSScriptRoot)\ReadableFileSize.ps1"
function UpdateStorageInfo {
    param(
        [switch]$WSLOnly,
        [switch]$WSAOnly,
        [switch]$NetDriveOnly
    )
    [string[]]$CustomDrives=(Split-Path ((Get-ChildItem "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace").Name) -leaf)
    [bool]$PingSucceeded=(Test-NetConnection box.com).pingsucceeded
    foreach($Drive in $CustomDrives) {
        if(!(Test-Path "Registry::HKCR\CLSID\$($Drive)")) { # the drive's definition is no longer present, possibly drive uninstalled, leaving a blank icon in explorer. Time to remove this entry
            Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($Drive)"
        }
        else {
            [string]$DriveName=(Get-ItemProperty -Path "Registry::HKCR\CLSID\$($Drive)").'(default)'
            [int]$DriveNameKlammer=$DriveName.IndexOf('(') # Will be -1 if the drive name does not contain size info
            if($DriveNameKlammer -gt 0) { # Cloud drive name already
                [string]$DriveName=$DriveName.Substring(0,$DriveNameKlammer-1)
            }
            [int]$StorageType=(Get-ItemProperty "Registry::HKCR\CLSID\$($Drive)").DescriptionID
            if($StorageType -eq 3) {
                continue
            }
            Write-Host "Recalculating drive size of $($DriveName)"
            if($StorageType -eq 6) { # this is WSL or WSA drive
                if(Test-Path "Registry::HKCR\CLSID\$($Drive)\InProcServer32") { # this is WSL drive
                    if($WSAOnly -or $NetDriveOnly) {
                        Write-Host "Skipped" -BackgroundColor White -ForegroundColor Black
                        continue
                    }
                    if($Drive -eq "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}") { # Default WSL
                        [string]$DistroVHDPath=$(GetDefaultWSL -GetVHDPath)
                    }
                    else {
                        [string[]]$ExtraDistroLocs=(GetExtraWSL -GetVHDPath)
                        for($i=0;$i -lt $ExtraDistroLocs.count; $i++) {
                            if($Drive -like "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}") {
                                [string]$DistroVHDPath=$ExtraDistroLocs[$i]
                                break
                            }
                        }
                    }
                    [int]$WSLVer=$(GetDefaultWSL -GetWSLver)
                    switch($WSLVer) {
                        1 {
                            $DistroVHDPath="$($DistroVHDPath)\rootfs"
                        }
                        2 {
                            $DistroVHDPath ="$($DistroVHDPath)\ext4.vhdx"
                        }
                    }
                }
                else { # This is WSA drive
                    if($WSLOnly -or $NetDriveOnly) {
                        Write-Host "Skipped" -BackgroundColor White -ForegroundColor Black
                        continue
                    }
                    [string]$DistroVHDPath="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalCache\userdata.*vhdx"
                }
                if((Get-Item "$($DistroVHDPath)").mode -like "d?----") { # WSL1 folder
                    $VHDXSize=Readablefilesize((Get-ChildItem "$($DistroVHDPath)" -Force -Recurse | Measure-Object -Sum Length).Sum)
                }
                else {
                    $VHDXSize=ReadableFileSize(GetFileSizeOnDisk "$($DistroVHDPath)") # WSA VHDX is some new sort. File size ≠ occupied disk size
                }
                CreateKey "Registry::HKCR\CLSID\$($Drive)" -StandardValue "$($DriveName) ($($VHDXSize))"
            }
            elseif($StorageType -eq 9) { # this is a network drive
                if($WSLOnly -or $WSAOnly) {
                    Write-Host "Skipped" -BackgroundColor White -ForegroundColor Black
                    continue
                }
                if($PingSucceeded) { # Only calculate disk size if there's internet connection.
                    if((($DriveName -like "Google*" -and (Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico")) -or ($DriveName -like "pCloud*" -and (Test-Path "C:\Program Files\pCloud Drive\pcloud.exe"))) -and ($DriveName -NotLike "*Yahoo*")) { # Virtual drives created by Google Drive and pCloud app
                        if($DriveName -like "Google*") {$DriveLetter="A"}
                        elseif($DriveName -like "pCloud*") {$DriveLetter="P"}
                        $DriveInfo=(Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "$($DriveLetter):"})
                        [string]$UsedSpace=ReadableFileSize($DriveInfo.Size-$DriveInfo.FreeSpace)
                        [string]$TotalSpace="$($DriveInfo.Size/1GB) GB"
                        if($TotalSpace -eq "0 GB") { # Drive offline
                            $UsedSpace="OFFLINE"
                        }
                        . "$($PSScriptRoot)\RegistryTweaks-Drives.ps1"
                        HideDriveLetters
                    }
                    elseif(Test-Path "$($env:Userprofile)\$($DriveName -creplace ' ','_')") { # Rclone drive
                        $OneNoteSize=0GB
                        if($DriveName -like "pCloud*") {
                            $TotalSpace="9 GB"
                            if($DriveName -like "pCloud Yahoo*") {
                                $TotalSpace="10 GB"
                            }
                        }
                        elseif($DriveName -like "OneDrive*") {
                            $TotalSpace = "5 GB"
                            if(($DriveName -like "OneDrive Yahoo*") -and !(Test-Path "$($env:Userprofile)\$($DriveName -creplace ' ','_')\*\*.one")) {
                                $OneNoteSize=2GB
                            }
                            else {
                                SetValue "HKCR\CLSID\$($Drive)\ShellFolder" -Name "FolderValueFlags" -Type 4 -Value 0x30
                                if($DriveName -like "OneDrive - Personal") {
                                    $DriveName="OneDrive"
                                }
                            }
                        }
                        elseif($DriveName -like "DropBox*") {
                            $TotalSpace = "2 GB"
                        }
                        elseif(($DriveName -like "Box*") -or ($DriveName -like "Koofr*")) {
                            $TotalSpace = "10 GB"
                        }
                        elseif($DriveName -like "Google Drive*") {
                            $TotalSpace = "15 GB"
                        }
                        elseif($DriveName -like "MEGA*") {
                            $TotalSpace= "20 GB"
                        }
                        $UsedSpace=Readablefilesize((Get-ChildItem "$($env:Userprofile)\$($DriveName -creplace ' ','_')" -Force -Recurse | Measure-Object -Sum Length).Sum + $OneNoteSize)   
                    }
                    else { # Drive cannot be sorted
                        $UsedSpace="OFFLINE"
                    }
                    if($UsedSpace.length -eq 0) {
                        $UsedSpace="0 B"
                    }
                    if($TotalSpace.length -eq 0) {
                        $TotalSpace="0 GB"
                    }
                    [string]$StorageInformation="$($UsedSpace)"
                    if(($UsedSpace -notlike "OFFLINE") -and ($TotalSpace -ne "0 GB")) {
                       $StorageInformation=$StorageInformation + " $([char]0x2215) $($TotalSpace)" 
                    }
                }
                else {
                    [string]$StorageInformation="OFFLINE"
                    # Kill all rclone.exe commands to prevent Windows Explorer from freezing.
                }
                CreateKey "HKCR\CLSID\$($Drive)" -StandardValue "$($DriveName) ($($StorageInformation))"
            }
        }
    }
}