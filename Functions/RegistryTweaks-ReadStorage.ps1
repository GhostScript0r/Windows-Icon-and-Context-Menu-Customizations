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
            [int]$DriveNameBracket=$DriveName.IndexOf('(') # Will be -1 if the drive name does not contain size info - no brackets
            if($DriveNameBracket -gt 0) { # Cloud drive name already has size info (brackets)
                [string]$DriveName=$DriveName.Substring(0,$DriveNameBracket-1) # remove brackets
            }
            [int]$StorageType=(Get-ItemProperty "Registry::HKCR\CLSID\$($Drive)").DescriptionID
            if($StorageType -eq 3) { # This is the system folders, not drives.
                continue
            }
            [string]$DriveFolderPath="$($env:Userprofile)\$($DriveName -creplace ' ','_')" # Default value: in the user folder
            [string]$DriveFolderPathAccordingToReg="" # Need to reset after each loop. Otherwise if the next command fails no new value will be assigned to this variable.
            $DriveFolderPathAccordingToReg=(Get-ItemProperty -Path "Registry::HKCR\CLSID\$($Drive)\Instance\InitPropertyBag" -Name "TargetFolderPath" -ea 0).TargetFolderPath
            if(($DriveFolderPathAccordingToReg -notlike "@*") -and ($DriveFolderPathAccordingToReg -like "*\*")) { # Registry already contains the folder path and it's not @ a dll
                $DriveFolderPath=$DriveFolderPathAccordingToReg
            }
            Write-Host "Path of the folder $($Drive) is `"$($DriveFolderPath)`""
            Write-Host "Recalculating drive size of $($DriveName)"
            if($StorageType -eq 6) { # this is WSL or WSA drive
                if(Test-Path "Registry::HKCR\CLSID\$($Drive)\InProcServer32") { # this is WSL drive
                    if($WSAOnly -or $NetDriveOnly) {
                        Write-Host "Skipped, WSL drive not recalculated." -BackgroundColor White -ForegroundColor Black
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
                        Write-Host "Skipped, WSA drive not recalculated." -BackgroundColor White -ForegroundColor Black
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
                    Write-Host "Skipped, network drive not recalculated" -BackgroundColor White -ForegroundColor Black
                    continue
                }
                if($PingSucceeded) { # Only calculate disk size if there's internet connection.
                    if((($DriveName -like "Google*" -and (Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico")) -or ($DriveName -like "pCloud*" -and (Test-Path "C:\Program Files\pCloud Drive\pcloud.exe"))) -and ($DriveName -NotLike "*_*")) { # Virtual drives created by Google Drive and pCloud app
                        if($DriveName -like "Google*") {
                            $DriveLetter="A"
                        }
                        elseif($DriveName -like "pCloud*") {
                            $DriveLetter="P"
                        }
                        $DriveInfo=(Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "$($DriveLetter):"})
                        [string]$UsedSpace=ReadableFileSize($DriveInfo.Size-$DriveInfo.FreeSpace) # Get Used space
                        [string]$TotalSpace="$($DriveInfo.Size/1GB) GB" # Get Total Space
                        if($TotalSpace -eq "0 GB") { # Drive offline
                            $UsedSpace="OFFLINE"
                        }
                        . "$($PSScriptRoot)\RegistryTweaks-Drives.ps1"
                        HideDriveLetters # Hide A and P drive letters if it was shown
                    }
                    elseif(Test-Path "$($DriveFolderPath)") { # Is either rClone drives or folders of installed drive
                        [string]$DriveFolderType=(Get-Item "$($DriveFolderPath)").Mode
                        Write-Host "$DriveFolderPath $DriveFolderType"
                        if($DriveFolderType -like "d----l") { # Folder is rClone folder
                            [string]$rCloneInstanceName=$($DriveName -creplace ' ','_')
                            [string[]]$rCloneStorageInfo=$(. "$($env:Localappdata)\Programs\rclone\rclone.exe" about "$($rCloneInstanceName):")
                            # 1st line: total space, 2nd line: used space, 3rd line: free space
                            [hashtable]$rCloneStorageTable=(ConvertRCloneFileSizeInfo $rCloneStorageInfo)
                            $TotalSpace=$rCloneStorageTable.'Total Space'
                            $UsedSpace=$rCloneStorageTable.'Used Space'
                        }
                        elseif($DriveFolderType -match "d[a|-]r--l") { # Folder is OneDrive folder (dar--l) or Box Drive folder (d-r--l)
                            $UsedSpace=Readablefilesize(Get-ChildItem "$($DriveFolderPath)\" -Force -Recurse | Measure-Object -Sum Length).Sum
                            if($DriveFolderType -like "dar--l") {# is Onedrive
                                $TotalSpace="5 GB"
                            }
                            elseif($DriveFolderType -like "d-r--l") { # is Box
                                $TotalSpace="10 GB"
                            }
                        }
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
                else { # Ping failed - device not online
                    [string]$StorageInformation="OFFLINE"
                    # rClone_mount.ps1 will kill all the rclone processes when device is offline
                }
                CreateKey "HKCR\CLSID\$($Drive)" -StandardValue "$($DriveName) ($($StorageInformation))"
            }
        }
    }
}