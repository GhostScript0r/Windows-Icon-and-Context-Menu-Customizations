. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\GetIcons.ps1"
. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function GenerateCustomNamespace {
    param(
        [parameter(ParameterSetName='Namespace', Mandatory=$true, Position=0)]
        [string[]]$Namespace
    )
    foreach($Name in $Namespace) {
        Write-Host "Creating CLSID entry for folder / path $($Name) if it exists."
        switch ($Name) {
            'rClone' {
                Write-Host "Check if rClone is already installed"
                [string]$rClonePath="$($env:Localappdata)\Programs\rclone\rclone.exe"
                if(Test-Path $rClonePath) { # rClone installed # $lastexitcode -eq 0
                    [string[]]$rCloneDrives=(((Get-Content "$($env:Appdata)\rclone\rclone.conf") -match "\[.*\]") -replace '\[','' -replace '\]','') | Where-Object {$_ -NotIn @('Box','Google_Drive','Google_Photos')} # RClone Drive Names is stored with [] in rclone.conf
                    for($i=0;$i -lt 9; $i++) { # This script can display max. 10 CLSID entries.
                        [string]$RcloneCLSID="{6587a16a-ce27-424b-bc3a-8f044d36fd9$($i)}"
                        if(($i -lt $rCloneDrives.count)) {
                            [int]$StringLength=$rCloneDrives[$i].IndexOf('_')
                            if($StringLength -eq -1) { # No underline in name
                                $StringLength=$rCloneDrives[$i].length
                            }
                            [string[]]$DriveIcons=(GetDistroIcon $rCloneDrives[$i].SubString(0,$StringLength) -CloudDrive)
                            [string]$DriveIcon=$DriveIcons[1]
                            if($DriveIcon.length -eq 0) {
                                $DriveIcon="`"$($rClonePath)`",0"
                            }
                            MkDirCLSID "$($RcloneCLSID)" -Name "$($rCloneDrives[$i] -replace '_',' ')" -TargetPath "$($env:Userprofile)\$($rCloneDrives[$i])" -Icon "$($DriveIcon)" -FolderType 9 -Pinned 0
                        }
                        else {
                            Remove-Item "Registry::HKCR\CLSID\$($RcloneCLSID)" -Force -Recurse -ea 0
                            Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($RcloneCLSID)" -Force -Recurse -ea 0
                        }
                    }
                }
            }
            'Games' {
                Write-Host "Check if Games path in start menu exists"
                [string]$GamesPath="$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Spiele"
                [string]$GamesCLSID="{a235a4f4-3349-42e1-b81d-a476cd7e33c0}"
                if ((Test-Path "$($GamesPath)") -and !(Test-Path "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($GamesCLSID)")) {
                    MkDirCLSID $GamesCLSID -Name "@shell32.dll,-30579" -InfoTip "@searchfolder.dll,-9031" -Pinned 0 -TargetPath "$($GamesPath)" -FolderType 3 -Icon "imageres.dll,-186"
                    SetValue -RegPath "HKCU\Software\Classes\CLSID\$($GamesCLSID)\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "$($env:Appdata)\Microsoft\Windows\Start Menu\Programs\Spiele"
                    foreach($SubKey in @("","WOW6432Node\")) {
                        CreateKey "HKCU\SOFTWARE\$($SubKey)Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($GamesCLSID)"
                    }
                }
            }
            'Google Drive' {
                [string]$GoogleDriveCLSID="{9499128F-5BF8-4F88-989C-B5FE5F058E79}"
                if((Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico") -and !(Test-Path "Registry::HKCR\CLSID\$($GoogleDriveCLSID)")) {
                    MkDirCLSID $GoogleDriveCLSID -Name "Google Drive" -TargetPath "A:\" -FolderType 9 -Icon "C:\Program Files\Google\Drive File Stream\drive_fs.ico"
                    $GoogleDriveReg=@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\SOFTWARE\Google\DriveFS]
"PerAccountPreferences"="{\"per_account_preferences\":[{\"key\":\"111142118877551513951\",\"value\":{\"mount_point_path\":\"A\"}}]}"
"DoNotShowDialogs"="{\"mount_point_changed\":true,\"preferences_dialog_tour\":true,\"spork_tour_notification\":true}"
"PromptToBackupDevices"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Google\DriveFS\Share]
"SyncTargets"=hex:0a,1d,0a,17,0a,15,31,31,31,31,34,32,31,31,38,38,37,37,35,35,\
  31,35,31,33,39,35,31,12,02,41,3a
"ShellIpcEnabled"=dword:00000001
'@
                    ImportReg $GoogleDriveReg
                    SetValue -RegPath "HKEY_CURRENT_USER\Software\Google\DriveFS\Share" -Name "BasePath" -Value "$($env:LOCALAPPDATA)\Google\DriveFS"
                    SetValue -RegPath "HKEY_CURRENT_USER\Software\Google\DriveFS\Share" -Name "ShellIpcPath" -Value "\\.\Pipe\GoogleDriveFSPipe_$($env:UserName)_shell"
                }
                else {
                    remove-item "Registry::HKCR\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -Force -Recurse -ErrorAction SilentlyContinue
                    remove-item "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -Force `
                    -ErrorAction SilentlyContinue
                }
            }
            'Dropbox' {
                [string]$DropBoxInstallLoc="C:\Program Files (x86)\Dropbox\Client\Dropbox.exe"
                if(Test-Path "$($DropBoxInstallLoc)") { # DropBox CLSID changes each time, for safety use pre-defined CLSID instead
                    [string]$DropBoxIcon="`"$($DropBoxInstallLoc)`",-13001"
                    MkDirCLSID "{3ac72dca-9dda-4055-9cdb-695154218963}" -Name "Dropbox" -Icon "$($Dropboxicon)" -TargetPath "$($env:Userprofile)\Dropbox" -FolderType 9
                }
                else {
                    Remove-Item "Registry::HKCU\Software\Classes\CLSID\{3ac72dca-9dda-4055-9cdb-695154218963}" -Force -Recurse -ErrorAction SilentlyContinue
                    Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ac72dca-9dda-4055-9cdb-695154218963}" -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}