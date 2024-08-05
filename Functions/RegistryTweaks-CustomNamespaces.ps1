. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\GetIcons.ps1"
. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
. "$($PSScriptRoot)\RegistryTweaks-ReadStorage.ps1"
. "$($PSScriptRoot)\RegistryTweaks-ContextMenuWebsite.ps1"
function GenerateCustomNamespace {
    param(
        [parameter(ParameterSetName='Namespace', Mandatory=$true, Position=0)]
        [string[]]$Namespace,
        [switch]$Remove
    )
    foreach($Name in $Namespace) {
        Write-Host "Creating CLSID entry for folder / path $($Name) if it exists."
        switch ($Name) {
            'rClone' {
                Write-Host "Check if rClone is already installed"
                [string]$rClonePath="$($env:Localappdata)\Programs\rclone\rclone.exe"
                if(-not (Test-Path $rClonePath)) {
                    Write-Host "rClone not installed."
                    return
                }
                . "$($PSScriptRoot)\Hashtables.ps1"
                [hashtable]$DrivesWebsites=$(GetHashTables "CloudWebsites")
                [string[]]$rCloneDrives=(((Get-Content "$($env:Appdata)\rclone\rclone.conf") -match "\[.*\]") -replace '\[','' -replace '\]','') | Where-Object {$_ -NotIn @('Google_Drive','Google_Photos')} # 'Box' # RClone Drive Names is stored with [] in rclone.conf
                for($i=0;$i -lt 9; $i++) { # This script can display max. 10 CLSID entries.
                    [string]$RcloneCLSID="{6587a16a-ce27-424b-bc3a-8f044d36fd9$($i)}"
                    if(($i -lt $rCloneDrives.count)) {
                        [int]$StringLength=$rCloneDrives[$i].LastIndexOf('_') # put lastindexof instead of indexof for Google_Drive or Google_Photos
                        if($StringLength -eq -1) { # No underline in name
                            $StringLength=$rCloneDrives[$i].length
                        }
                        [string]$CloudDriveName=$rCloneDrives[$i].SubString(0,$StringLength)
                        [string[]]$DriveIcons=(GetDistroIcon "$($CloudDriveName)" -CloudDrive)
                        [string]$DriveIcon=$DriveIcons[1]
                        if(($DriveIcon.length -eq 0) -or (!(Test-Path "$($DriveIcon)") -and ($DriveIcon -like "*.ico"))) { # some cloud drives use DLL entries instead of ICO.
                            $DriveIcon=(GetDistroIcon "rClone" -CloudDrive)[1]
                        }
                        MkDirCLSID "$($RcloneCLSID)" -Name "$($rCloneDrives[$i] -replace '_',' ')" -TargetPath "$($env:Userprofile)\$($rCloneDrives[$i])" -Icon "$($DriveIcon)" -FolderType 9 -Pinned 0
                        [string]$DriveSite=""
                        foreach($DriveName in $DrivesWebsites.keys) {
                            if($rCloneDrives[$i] -like "$($DriveName)*") {
                                $DriveSite=$DrivesWebsites.$DriveName
                                break
                            }
                        }
                        [bool]$WebsiteValid=$($DriveSite.length -gt 0)
                        Write-Host "Writing $($DriveSite)" -ForegroundColor Cyan
                        [string]$WebsiteIcon="ieframe.dll,-190" # "imageres.dll,-1404" #"$($env:Userprofile)\Links\$($DriveName.replace('_',' ')).ico"
                        if($Drivesite -notlike "https://*") {
                            $Drivesite="https://"+$Drivesite
                        }
                        CreateFileAssociation "CLSID\$($RcloneCLSID)" -ShellOperations "Browse" -Icon "$($WebsiteIcon)" -ShellOpDisplayName "$($DriveSite.replace('https://','')) besuchen" -Command "rundll32 url.dll,FileProtocolHandler $($Drivesite)" -LegacyDisable (-Not $WebsiteValid)
                        SetValue "HKCR\CLSID\$($RcloneCLSID)\shell\Browse" -Name "Position" -Value "Top"
                    }
                    else {
                        Remove-Item "Registry::HKCR\CLSID\$($RcloneCLSID)" -Force -Recurse -ea 0
                        Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($RcloneCLSID)" -Force -Recurse -ea 0
                    }
                }
                UpdateStorageInfo -NetDriveOnly
            }
            'Games' {
                Write-Host "Check if Games path in start menu exists"
                [string]$GamesPath="$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Spiele"
                [string]$GamesCLSID="{a235a4f4-3349-42e1-b81d-a476cd7e33c0}"
                if (Test-Path "$($GamesPath)") {
                    MkDirCLSID $GamesCLSID -Name "@shell32.dll,-30579" -InfoTip "@searchfolder.dll,-9031" -Pinned 0 -TargetPath "$($GamesPath)" -FolderType 3 -Icon "imageres.dll,-186"
                    SetValue -RegPath "HKCU\Software\Classes\CLSID\$($GamesCLSID)\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "$($env:Appdata)\Microsoft\Windows\Start Menu\Programs\Spiele"
                    foreach($SubKey in @("","WOW6432Node\")) {
                        CreateKey "HKCU\SOFTWARE\$($SubKey)Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($GamesCLSID)"
                    }
                }
                WebsiteInContextMenu $GamesCLSID -SiteNames @("Epic Games Store")
                [string]$EpicLauncherLoc="C:\Program Files (x86)\Epic Games\Launcher\Portal\Binaries\Win32\EpicGamesLauncher.exe"
                if(Test-Path "$($EpicLauncherLoc)") {
                    CreateFileAssociation "CLSID\$($GamesCLSID)" -ShellOperations "Epic Games Store" -Command "$($EpicLauncherLoc)" -Icon "$($EpicLauncherLoc)"
                }
                $nVidiaContainerFile=(Get-Item "C:\Windows\System32\DriverStore\FileRepository\nvlti.inf_*\Display.NvContainer\NVDisplay.Container.exe")
                [bool]$nVidiaCPAppInstalled=((Get-AppxPackage NVIDIACorp.NVIDIAControlPanel).Count -eq 1)
                if($nVidiaContainerFile.count -gt 0) {
                    # Add nVidia settings to Games menu
                    if($nVidiaCPAppInstalled) {
                        CreateFileAssociation "CLSID\$($GamesCLSID)" -ShellOperations "nVidia Control Panel" -Command "explorer.exe shell:AppsFolder\NVIDIACorp.NVIDIAControlPanel_56jybvy8sckqj!NVIDIACorp.NVIDIAControlPanel" -Icon "$($nVidiaContainerFile)"
                    }
                }
            }
            'AllApps' {
                # CLSID for the device {4234d49b-0245-4df3-b780-3893943456e1}
                [string]$AllAppsCLSID="{0f5ecf41-20c1-49e2-9a4a-db21c3666876}"
                if($Remove) {
                    # Remove-Item "Registry::HKCR\CLSID\$($AllAppsCLSID)" -Force -Recurse -ea 0
                    Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($AllAppsCLSID)" -Force -Recurse -ea 0
                    continue
                }
                CreateKey "HKCR\CLSID\$($AllAppsCLSID)" -StandardValue "@werconcpl.dll,-10100"
                GetDistroIcon "Microsoft.WindowsStore" -CopyAppIconPNG -PNGSubLoc "Assets\Illustrations\LifeLineIcon.png"
                CreateFileAssociation "CLSID\$($AllAppsCLSID)" -DefaultIcon "imageres.dll,-198" -ShellOperations @("open","edit","openinstore") -Command @("explorer.exe shell:::{4234d49b-0245-4df3-b780-3893943456e1}","control.exe appwiz.cpl","explorer.exe shell:AppsFolder\Microsoft.WindowsStore_8wekyb3d8bbwe!App") -TypeName "@appmgr.dll,-667" -Icon @("shell32.dll,-20","appwiz.cpl,-1500","$($env:Userprofile)\Links\Microsoft.WindowsStore_LifeLineIcon.ico") -MUIVerb ("","@sud.dll,-228","@shell32.dll,-5382")
                Remove-ItemProperty -Path "Registry::HKCR\CLSID\$($AllAppsCLSID)\shell\openinstore" -Name "Position" -ea 0
                SetValue "HKCR\CLSID\$($AllAppsCLSID)" -Name "InfoTip" -Value "@appmgr.dll,-667"
                SetValue "HKCR\CLSID\$($AllAppsCLSID)" -Name "SortOrderIndex" -Type "4" -Value 0x42
                SetValue "HKCR\CLSID\$($AllAppsCLSID)" -Name "DescriptionID" -Type "4" -Value 3
                CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($AllAppsCLSID)"
            }
            'Google Drive' {
                [string]$GoogleDriveCLSID="{9499128F-5BF8-4F88-989C-B5FE5F058E79}"
                if((Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico")) { # -and !(Test-Path "Registry::HKCR\CLSID\$($GoogleDriveCLSID)")
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
                    GetDistroIcon "Google Drive" -CloudDrive
                    [string]$GDriveIcon="$($env:Userprofile)\Links\Google DriveFolder.ico"
                    if(!(Test-Path "$Gdriveicon")) {
                        $GDriveIcon="C:\Program Files\Google\Drive File Stream\drive_fs.ico"
                    }
                    MkDirCLSID $GoogleDriveCLSID -Name "Google Drive" -TargetPath "A:\Meine Ablage" -FolderType 9 -Icon "$GDriveIcon"
                    # Hide Drive Letter A
                    . "$($PSScriptRoot)\RegistryTweaks-Drives.ps1"
                    HideDriveLetters
                    UpdateStorageInfo -NetDriveOnly
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
            'StandardFolders' {
                foreach($LibraryFolder in ((Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\")+(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\")).Name) {
                    Remove-ItemProperty -Path "Registry::$($LibraryFolder)" -Name "HideIfEnabled" -ea 0 -Force
                    if(((Get-ItemProperty -LiteralPath "Registry::$($LibraryFolder)").'(default)') -like "CLSID_*RegFolder") {
                        Remove-Item -Path "Registry::$($LibraryFolder)" -ea 0
                        New-Item -Path "Registry::$($LibraryFolder)"
                    }
                }
                [string[]]$LibraryFolders=@("{d3162b92-9365-467a-956b-92703aca08af}","{088e3905-0323-4b02-9826-5d99428e115f}","{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}","{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}","{24ad3ad4-a569-4530-98e1-ab02f9417aa8}")
                # [string[]]$LibraryDescripCLSIDs=@("{7b0db17d-9cd2-4a93-9733-46cc89022e7c}","","{2112AB0A-C86A-4ffe-A368-0DE96E47012E}","{491E922F-5643-4af4-A7EB-4E7A138D8174}","{A990AE9F-A03B-4e80-94BC-9912D7504104}")
                # d3162b...: Dokumente; 088e39...: Downloads; 3dfdf2...: Musik; f86fa3...: Videos; 24ad3a...: Bilder
                [string[]]$LibraryFolderName=@("@shell32.dll,-21770","@shell32.dll,-21798","@shell32.dll,-21790","@shell32.dll,-17452","@shell32.dll,-30486")
                for($i=0;$i -lt $LibraryFolders.count;$i++) {
                    # [string]$LibraryIcon=(Get-ItemProperty -Path "Registry::HKCR\CLSID\$($LibraryFolders[$i])\DefaultIcon" -ea 0).'(default)'
                    # [string]$LibraryDescripCLSID=$LibraryDescripCLSIDs[$i]
                    # [bool]$LibraryIsMSLibrary=$true
                    # if($LibraryDescripCLSID.length -eq 0) {
                        # [string]$LibraryDescripCLSID=(Get-ItemProperty -Path "Registry::HKCR\CLSID\$($LibraryFolders[$i])\Instance\InitPropertyBag" -ea 0).'TargetKnownFolder'
                        # [bool]$LibraryIsMSLibrary=$false
                    # }
                    # [string]$LibraryName=(Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$($LibraryDescripCLSID)").'LocalizedName'
                    # [string]$LibraryInfoTip=(Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$($LibraryDescripCLSID)").'InfoTip'
                    # [string]$LibraryPath=(Get-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\$($LibraryDescripCLSID)").'ParsingName'
                    # $LibraryPath = $LibraryPath -replace 'shell:::','' -replace '::',''
                    Rename-ItemProperty -Path "Registry::HKCR\CLSID\$($LibraryFolders[$i])" -Name "System.IsPinnedToNameSpaceTree_Old" -NewName "System.IsPinnedToNameSpaceTree" -ea 0
                    [int]$Pinned = 0 # Hide 
                    if($LibraryFolders[$i] -like "{088e3905-0323-4b02-9826-5d99428e115f}") { # Downloads
                        $Pinned=1
                    }
                    MkDirCLSID $LibraryFolders[$i] -Pinned $Pinned -Name $LibraryFolderName[$i]
                    # Since  version 22631.3672, the abovementioned function no longer works - Need to create new CLSIDs for the my computer folder
                    # if ($LibraryIsMSLibrary) {
                    #     MkDirCLSID "{77777777-7777-4489-a3ca-2b3aae34421$($i)}" -Icon $LibraryIcon -Name $LibraryName -Infotip $LibraryInfoTip -IsShortcut
                    #     CreateFileAssociation "CLSID\{77777777-7777-4489-a3ca-2b3aae34421$($i)}" -ShellOperations "open" -Icon "imageres.dll,-1001" -Command "shell:::$($LibraryPath)"  -MUIVerb "@comres.dll,-1865"
                    # }
                    # else {
                        # MkDirCLSID "{77777777-7777-4489-a3ca-2b3aae34421$($i)}" -Pinned $Pinned -Icon $LibraryIcon -Name $LibraryName -Infotip $LibraryInfoTip -TargetPath $LibraryDescripCLSID
                    # }
                }
                WebsiteInContextMenu "{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" -SiteNames @("Google_Photos","Flickr")
                WebsiteInContextMenu "{d3162b92-9365-467a-956b-92703aca08af}" -SiteNames @("Google Docs","Adobe Document Cloud","Google Play Books")
                WebsiteInContextMenu "{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" -SiteNames @("YouTube","YouTube Studio","ZDF Mediathek","ARD Mediathek")
                CreateFileAssociation "CLSID\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" -ShellOperations "YouTube Studio" -Extended 1
                WebsiteInContextMenu "{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" -SiteNames @("Spotify","YouTube Music","Radio")
                $AudialsInstalled=(Get-AppxPackage AudialsAG.AudialsPlay)
                if($AudialsInstalled.count -eq 1) { # Audials play installed
                    GetDistroIcon "AudialsAG.AudialsPlay" -CopyAppIconPNG -PNGSubLoc "Assets\StoreLogo.scale-400.png"
                    CreateFileAssociation "CLSID\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" -ShellOperations "Radio" -Icon "$($env:Userprofile)\Links\AudialsAG.AudialsPlay_StoreLogo.scale-400.ico" -ShellOpDisplayName "AudialsPlay starten" -Command "explorer.exe shell:AppsFolder\AudialsAG.AudialsPlay_3eby6px24ctcy!AudialsAG.AudialsPlay"
                }
                SetValue -RegPath "HKCR\CLSID\{088e3905-0323-4b02-9826-5d99428e115f}" -Name "Infotip" -Value "@occache.dll,-1070" # Downloads
                SetValue -RegPath "HKCR\CLSID\{d3162b92-9365-467a-956b-92703aca08af}" -Name "Infotip" -Value "@shell32.dll,-22914" # MyDocuents                
            }
        }
    }
}