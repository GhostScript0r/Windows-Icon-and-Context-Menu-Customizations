. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\GetFileSizeOnDisk.ps1"
function UpdateStorageInfo {
    param()
    [string[]]$CustomDrives=(Split-Path ((Get-ChildItem "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace").Name) -leaf)
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
            Write-Host "Recalculating drive size of $($DriveName)"
            if((Get-ItemProperty "Registry::HKCR\CLSID\$($Drive)").DescriptionID -eq 6) { # this is WSL/WSA drive
                if(Test-Path "Registry::HKCR\CLSID\$($Drive)\InProcServer32") { # this is WSL drive
                    [string]$DistroVHDPath=$(GetDefaultWSL -GetWSLPath)
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
                    [string]$DistroVHDPath="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalCache\userdata.*vhdx"
                }
                if((Get-Item "$($DistroVHDPath)").mode -like "d?----") { # WSL1 folder
                    $VHDXSize=Readablefilesize((Get-ChildItem "$($DistroVHDPath)" -Force -Recurse | Measure-Object -Sum Length).Sum)
                }
                else {
                    $VHDXSize=ReadableFileSize(GetFileSizeOnDisk "$($DistroVHDPath)") # WSA VHDX is some new sort. File size ≠ occupied disk size
                }
                CreateKey "Registry::HKCR\CLSID\$($Drive)" -StandardValue "$($DriveName) ($($VHDXSize) belegt)"
            }
            elseif((Get-ItemProperty "Registry::HKCR\CLSID\$($Drive)").DescriptionID -eq 9) { # this is a network drive
                if((Test-NetConnection box.com).pingsucceeded) { # Only calculate disk size if there's internet connection.
                    if((($DriveName -like "Google*" -and (Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico")) -or ($DriveName -like "pCloud*" -and (Test-Path "C:\Program Files\pCloud Drive\pcloud.exe"))) -and ($DriveName -NotLike "*Yahoo*")) { # Virtual drives created by Google Drive and pCloud app
                        if($DriveName -like "Google*") {$DriveLetter="A"}
                        elseif($DriveName -like "pCloud*") {$DriveLetter="P"}
                        $DriveInfo=(Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DeviceID -eq "$($DriveLetter):"})
                        [string]$UsedSpace=ReadableFileSize($DriveInfo.Size-$DriveInfo.FreeSpace)
                        [string]$TotalSpace="$($DriveInfo.Size/1GB) GB"
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
                            if($DriveName -like "OneDrive Yahoo*") {
                                $OneNoteSize=2.01GB
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
                        elseif($DriveName -like "Box*") {
                            $TotalSpace = "10 GB"
                        }
                        elseif($DriveName -like "Google Drive*") {
                            $TotalSpace = "15 GB"
                        }
                        $UsedSpace=Readablefilesize((Get-ChildItem "$($env:Userprofile)\$($DriveName -creplace ' ','_')" -Force -Recurse | Measure-Object -Sum Length).Sum + $OneNoteSize)   
                    }
                    else { # Drive cannot be sorted
                        $UsedSpace="rClone gestoppt"
                    }
                    if($UsedSpace.length -eq 0) {
                        $UsedSpace="0 B"
                    }
                    if($TotalSpace.length -eq 0) {
                        $TotalSpace="0 GB"
                    }
                    [string]$StorageInformation="$($UsedSpace)"
                    if($UsedSpace -notlike "rClone gestoppt") {
                       $StorageInformation=$StorageInformation + " von $($TotalSpace) belegt" 
                    }
                }
                else {
                    [string]$StorageInformation="keine Verbindung"
                    # Kill all rclone.exe commands to prevent Windows Explorer from freezing.
                }
                CreateKey "HKCR\CLSID\$($Drive)" -StandardValue "$($DriveName) ($($StorageInformation))"
            }
        }
    }
}