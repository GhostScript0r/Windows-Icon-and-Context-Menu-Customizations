﻿param(
    [switch]$RemoveCommonStartFolder,
    [switch]$StorageRefreshOnly,
    [switch]$Win32GoogleRefreshOnly,
    [switch]$VSCodeRefreshOnly
)
# Write-Host ((Get-Variable -scope private).Name + @(" ") + (Get-Variable -scope local).Name)
Write-Host "This script is inteneded to write in the usual registry stuff after Windows OOBE or in-place upgrade" -BackgroundColor White -ForegroundColor Blue
# Call functions
$PSFunctions=(Get-ChildItem "$($PSScriptRoot)\Functions\*.ps1")
foreach($Function in $PSFunctions) {
    . "$($Function.FullName)"
}
# Check Admin Privilege
foreach($Argum in (GetThisScriptVariable $(Get-Variable))) {
    if((Get-Variable "$($Argum)").value -eq $true) {
        $ArgumentToPass = $ArgumentToPass + @($Argum)    
    }
}
RunAsAdmin "$($PSCommandPath)" -Arguments $ArgumentToPass
# ---------------------
# Update the name of other drives shown in Windows Explorer to get drive size infos
# —————————————————————
# Refresh Box Drive if updated
[string]$BoxInstallLoc="C:\Program Files\Box\Box\Box.exe"
if([System.Environment]::OSVersion.Version.Build -ge 22000) {
    [string]$BoxIcon=$BoxInstallLoc
}
else {
    [string]$BoxIcon="C:\Program Files\Box\Box\WindowsFolder.ico"
}
[string[]]$BoxDriveCLSIDs=@("HKCR\CLSID\{345B91D6-935F-4773-9926-210C335241F9}","HKCR\CLSID\{F178C11B-B6C5-4D71-B528-64381D2024FC}") #((Get-ChildItem "Registry::HKCR\CLSID" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)").'(default)' -like "Box*"} ))
if(Test-Path "$($BoxInstallLoc)") {
    foreach($BoxDriveCLSID in $BoxDriveCLSIDs) {
        foreach($RegRoot in @("HKCR","HKLM")) {
            Remove-Item "Registry::$($RegRoot)\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\Namespace\$(Split-Path $BoxDriveCLSID -leaf)" -Force -ea 0
        }
        # CreateKey "$($BoxDriveCLSID)" -StandardValue "Box"
        if((Get-ItemProperty -LiteralPath "Registry::$($BoxDriveCLSID)\DefaultIcon").'default' -like "`"$($Icon)`"") {
            # Box drive not updated, no need to update icon.
            break
        }
        SetValue "$($BoxDriveCLSID)" -Name "DescriptionID" -Type "4" -Value 9
        Set-ItemProperty -Path "Registry::$($BoxDriveCLSID)\DefaultIcon" -Name '(Default)' -Value "`"$($BoxIcon)`""
        if(Test-Path "Registry::$($BoxDriveCLSID)\Instance") { # Box Drive Entry without online status overlay. Looks like traditional folder
            Set-ItemProperty -Path "Registry::$($BoxDriveCLSID)" -Name "System.IsPinnedToNameSpaceTree" -Value 0
        }
        else { # Box Drive Entry with online status overlay - Add to explorer
            CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\$(Split-Path $BoxDriveCLSID -leaf)"
        }
        # Remove Box Drive Entry from desktop
        Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\$(Split-Path $BoxDriveCLSID -leaf)" -Force -ea 0
        # if($?) { # Making Box Drive CLSID read-only will break Box updater, so they are commented out.
        #     MakeReadOnly "$($BoxDriveCLSID)\DefaultIcon" -InclAdmin 
        # }
    }
    # Remove duplicate Box drive entries if more than one Box CLSID entry exist.
    $BoxDriveInExplorer=(Split-Path (Get-ChildItem "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\").Name -leaf | Where-Object {$BoxDriveCLSIDs -match $_})
    if($BoxDriveInExplorer.Count -gt 1) {
        for($i=0;$i -lt $BoxDriveInExplorer.Count-1;$i++) {
            Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\$($BoxDriveInExplorer[$i])"
        }
    }
}
else {
    foreach($BoxDriveCLSID in $BoxDriveCLSIDs) {
        Remove-Item "Registry::$($BoxDriveCLSID)" -Force -Recurse -ea 0
        Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\$(Split-Path $BoxDriveCLSID -leaf)" -Force -Recurse -ea 0
    }
}
# Remove-Item "Registry::HKCR\Directory\Background\shellex\ContextMenuHandlers\ACE" -Force -ea 0 # Remove AMD Radeon
# Remove-Item "Registry::HKCR\Directory\Background\shellex\ContextMenuHandlers\DropboxExt" -Force -ea 0
# Change Box Entry
if((Test-Path "$($env:USERPROFILE)\old_Box") -or ((Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders").'{A0C69A99-21C8-4671-8703-7934162FCF1D}' -notlike "*\Box\Music")) {
    ModifyMusicLibraryNamespace
    Remove-Item "$($env:USERPROFILE)\old_Box" -Force -Recurse -ea 0
}
if($StorageRefreshOnly) {
    UpdateStorageInfo
    exit
}
# The 5-minute storage refresh script ends at the place above. 
# #######################################################
# Here starts the script that will only be run manually or when a system version update is done.
# > Find file location of paint app and copy it out
if((Get-AppxPackage Microsoft.Paint).count -gt 0) {
    [string]$PaintAppLocation="$($(Get-AppxPackage Microsoft.Paint).InstallLocation)\PaintApp\mspaint.exe"
    [string]$PaintIconLocation="$($env:LocalAppdata)\Packages\Microsoft.Paint_8wekyb3d8bbwe\mspaint.exe"
    if(!(Test-Path "$($PaintIconLocation)")) {
        Copy-Item -Path "$($PaintAppLocation)" -Destination "$(Split-Path $PaintIconLocation)"
    }
    [string]$PaintAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_.Name)\Application" -ea 0).ApplicationName -like "*Microsoft.Paint*"})[0]
}
else {
    [string]$PaintAppLocation="C:\Windows\System32\mspaint.exe"
    [string]$PaintIconLocation="C:\Windows\System32\mspaint.exe"
    [string]$PaintAppHKCR="HKCR\Applications\mspaint.exe"
}
# > Find file location of Windows Terminal app and copy the profile icons out
[bool]$WTInstalled=([System.Environment]::OSVersion.Version.Build -ge 19041) -and ((Get-AppxPackage  Microsoft.WindowsTerminal).InstallLocation -gt 0)
if($WTInstalled) {
    [string]$WTLocation="$($(Get-AppxPackage Microsoft.WindowsTerminal).InstallLocation)"
    [string]$PowerShellIconPNG="$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\ProfileIcons\{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.scale-200.png"
    [string]$TerminalIconICO="$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\terminal_contrast-white.ico"
    if(!(Test-Path "$($PowerShellIconPNG)")) {
        Copy-Item -Path "$($WTLocation)\ProfileIcons" -Destination "$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe" -Recurse
    }
    if(!(Test-Path "$($TerminalIconICO)")) {
        Copy-Item -Path "$($WTLocation)\Images\terminal_contrast-white.ico" -Destination "$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"
    }
}
# Find location of WSL
[bool]$WSLEnabled=((Get-WindowsOptionalFeature -online -featurename "Microsoft-Windows-Subsystem-Linux").State -eq "Enabled")
if($WSLEnabled) {
    [string]$WSLLocation="C:\Program Files\WSL\wsl.exe"
    [string]$WSLLocationUWP="$((Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForLinux).InstallLocation)\wsl.exe"
    if (-NOT (Test-Path "$($WSLLocation)")) {
        $WSLLocation=$WSLLocationUWP
    }
    if (-NOT (Test-Path "$($WSLLocationUWP)")) {
        $WSLLocation="C:\Windows\System32\wsl.exe" 
    }
    [string]$WSLIconPNG="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_8wekyb3d8bbwe\Square44x44Logo.altform-lightunplated_targetsize-48.png"
    if(!(Test-Path "$($WSLIconPNG)") -and ($WSLLocation -notlike "C:\Windows\System32\wsl.exe")) {
        Copy-Item -Path "$(Split-Path $WSLLocationUWP)\Images\$(Split-Path $WSLIconPNG -Leaf)" -Destination "$(Split-Path $WSLIconPNG)"
    }
}
# > Find file location of WMP UWP
[bool]$WMPUWPInstalled=((Get-AppxPackage *ZuneMusic*).count -gt 0)
# > Find file location of WSA
[string]$WSAAppDataDir="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe"
if((Test-Path $WSAAppDataDir) -and ([System.Environment]::OSVersion.Version.Build -ge 20000)) { # WSA Installed, system is Windows 11+
    [string[]]$WSAIcons=@("$($WSAAppDataDir)\LatteLogo.png","$($WSAAppDataDir)\app.ico")
    foreach($Icon in $WSAIcons) {
        [string]$WSALocation="$((Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForAndroid).InstallLocation)\Assets\$(Split-Path $Icon -Leaf)"
        if((Test-Path "$($WSALocation)") -and (!(Test-Path "$($Icon)"))) {
            Copy-Item "$($WSALocation)" "$(Split-Path -Path $Icon)"
        }
    }
    [string[]]$WSAIconsDistro=(GetDistroIcon "Android")
    if($WSAIconsDistro.length -eq 0) {
        $WSAIconsDistro=$WSAIcons
    }
    [string]$WSACLSID="{a373e8cc-3516-47ac-bf2c-2ddf8cd06a4c}"
    MkDirCLSID $WSACLSID -Name "Android" -Icon "`"$($WSAIconsDistro[1])`"" -FolderType 6 -IsShortcut
    [string]$StartWSAAppCommandPrefix="$($env:Localappdata)\Microsoft\WindowsApps\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\WsaClient.exe /launch wsa://"
    [string[]]$WSAContextMenu=@("open","cmd")
    [string[]]$WSAContextMenuIcon=@("`"$($WSAIcons[1])`"","$($TerminalIconICO)")
    [string[]]$WSAContextMenuName=@("Mit Android-Dateibrowser ansehen","WSA ADB-Shell starten")
    [string[]]$WSAContextMenuCommand=@("$($StartWSAAppCommandPrefix)com.android.documentsui","wt.exe -p `"WSA ADB Shell`"")
    [string[]]$ExtraApps=@("com.android.settings") # "com.ghisler.android.TotalCommander",
    for($i=0;$i -lt $ExtraApps.count;$i++) {
        [string]$AppIconLoc = "$($env:LOCALAPPDATA)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalState\$(`
        $ExtraApps[$i]).ico"
        if((Test-Path "$($AppIconLoc)") -or ($ExtraApps[$i] -like "com.android.settings")) {
            $WSAContextMenu = $WSAContextMenu + @("open$($i+2)")
            if($ExtraApps[$i] -like "com.android.settings") {
                $AppIconLoc="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\LocalState\com.google.android.googlequicksearchbox.ico"
            }
            $WSAContextMenuIcon = $WSAContextMenuIcon + @("$($AppIconLoc)")
            [string[]]$WSANameToAdd=switch($i) {
                0 {
                    @("Android-Systemeinstellungen")
                }
            }
            $WSAContextMenuName = $WSAContextMenuName + $WSANameToAdd
            $WSAContextMenuCommand = $WSAContextMenuCommand +@("$($StartWSAAppCommandPrefix)$($ExtraApps[$i])")
        }
    }
    CreateFileAssociation "CLSID\$($WSACLSID)" -ShellOperations $WSAContextMenu -ShellOpDisplayName $WSAContextMenuName -Icon $WSAContextMenuIcon -Command $WSAContextMenuCommand
}
else { # WSA not installed
    MkDirCLSID $WSACLSID -RemoveCLSID -ea 0
}

# > Remove PowerRename
# if((Get-AppxPackage Microsoft.PowerToys.PowerRenameContextMenu).count -gt 0) {
#     Remove-Item "Registry::HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\PowerRenameEx" -Force -ea 0
# }
#Generate namespaces for cloud drives and custom folders
GenerateCustomNamespace @("Dropbox","Google Drive","rClone","Games")
# Use BIOS time as UTC
SetValue "HKLM\SYSTEM\ControlSet001\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type 4 -Value 1
# NVidia Shadow Play - hide mouse button
$nVidiaShadowPlayReg=@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS]
"{079461D0-727E-4C86-A84A-CBF9A0D2E5EE}"=hex:01,00,00,00
'@
ImportReg $nVidiaShadowPlayReg
# Check which Office program is installed
[bool]$MSOfficeInstalled=(Test-Path "C:\Program Files*\Microsoft Office\root\Office16\Word.exe")
[bool]$LibreOfficeInstalled=(Test-Path "C:\Program Files\LibreOffice\program\soffice.exe")
[bool]$OnlyOfficeInstalled=(Test-Path "C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe")
# ------- Check default browser ---------
[string[]]$DefaultBrowser=(CheckDefaultBrowser)
[string]$BrowserPath=$DefaultBrowser[0]
[string]$BrowserOpenAction=$DefaultBrowser[1]
[string]$BrowserIcon=$DefaultBrowser[2]
[string]$OpenInBrowserText=$DefaultBrowser[3]
# -------Get privileges to take ownership-------
Write-Host "Preparing to take ownership of keys owned by SYSTEM or TrustedInstaller" # Python equivalent: print("...")
#Take ownership of keys owned by SYSTEM or TrustedInstaller
[string[]]$LockedHKCRMain=@(`
    "HKCR\DesktopBackground\Shell\Display",`
    "HKCR\DesktopBackground\Shell\Personalize",`
    "HKCR\Directory\shell",`
    "HKCR\Directory\Background\shell",`
    "HKCR\PhotoViewer.FileAssoc.Tiff",`
    "HKCR\InternetShortcut",`
    # "HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}",` # Remove IE functionality of URL link
    "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}",` # Trash Bin
    "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage",` # This PC
    "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}",` # Control Panel
    "HKCR\CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}\DefaultIcon",` # Control Panel Category View
    "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}",` # WSL Entry
    "HKCR\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",` # Network places
    "HKCR\CLSID\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}",` # Pictures
    "HKCR\CLSID\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}",` # Videos
    "HKCR\CLSID\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}",` # Music
    "HKCR\CLSID\{088e3905-0323-4b02-9826-5d99428e115f}",` # Downloads
    "HKCR\CLSID\{d3162b92-9365-467a-956b-92703aca08af}",` # Documents
    "HKCR\CLSID\{59031a47-3f72-44a7-89c5-5595fe6b30ee}",` # User profile
    "HKCR\CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}",` # Quick Access
    "HKCR\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}",` # Quick Access
    "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}",` # Recent Folders
    "HKCR\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}",` # Newest Gallery / Catalog
    "HKCR\CLSID\{60632754-c523-4b62-b45c-4172da012619}\DefaultIcon",` # Control panel - user accounts
    "HKCR\CLSID\{6DFD7C5C-2451-11d3-A299-00C04F8EF6AF}\shell",` # Control panel - folder options
    "HKCR\CLSID\{7b81be6a-ce2b-4676-a29e-eb907a5126c5}\DefaultIcon",` # Control panel - Programs and Features
    "HKCR\CLSID\{62D8ED13-C9D0-4CE8-A914-47DD628FB1B0}\DefaultIcon",` # Control panel - Region and Language
    "HKCR\CLSID\{725BE8F7-668E-4C7B-8F90-46BDB0936430}\DefaultIcon",` # Control panel - Keyboard properties
    "HKCR\CLSID\{6C8EEC18-8D75-41B2-A177-8831D59D2D50}\DefaultIcon",` # Control panel - Mouse properties
    "HKCR\CLSID\{D555645E-D4F8-4c29-A827-D93C859C4F2A}\DefaultIcon",` # Control panel - Ease of access center
    "HKCR\CLSID\{ECDB0924-4208-451E-8EE0-373C0956DE16}\DefaultIcon",` # Control panel - Work folders
    "HKCR\CLSID\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}\DefaultIcon",` # Control panel - Power options
    "HKCR\CLSID\{93412589-74D4-4E4E-AD0E-E0CB621440FD}\DefaultIcon",` # Control panel - Font settings
    "HKCR\CLSID\{BD84B380-8CA2-1069-AB1D-08000948F534}\DefaultIcon",` # Control panel - Font folder
    "HKCR\CLSID\{58E3C745-D971-4081-9034-86E34B30836A}\DefaultIcon",` # Control panel - Speech recognition
    "HKCR\CLSID\{BB06C0E4-D293-4f75-8A90-CB05B6477EEE}\DefaultIcon",` # Control panel - System
    "HKCR\CLSID\{9C60DE1E-E5FC-40f4-A487-460851A8D915}\DefaultIcon",` # Control panel - Autoplay
    "HKCR\CLSID\{9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF}\DefaultIcon",` # Control panel - Sync center
    "HKCR\CLSID\{80F3F1D5-FECA-45F3-BC32-752C152E456E}\DefaultIcon",` # Control panel - Tablet PC Settings
    "HKCR\CLSID\{5ea4f148-308c-46d7-98a9-49041b1dd468}\DefaultIcon",` # Control panel - Windows Mobility Center
    "HKCR\CLSID\{F942C606-0914-47AB-BE56-1321B8035096}\DefaultIcon",` # Control panel - Storage spaces
    "HKCR\CLSID\{87D66A43-7B11-4A28-9811-C86EE395ACF7}\DefaultIcon",` # Control panel - Indexing options
    "HKCR\CLSID\{A3DD4F92-658A-410F-84FD-6FBBBEF2FFFE}\DefaultIcon",` # Control panel - Internet options (IE)
    "HKCR\CLSID\{F82DF8F7-8B9F-442E-A48C-818EA735FF9B}\DefaultIcon",` # Control panel - Pen and touch
    "HKCR\CLSID\{A8A91A66-3A7D-4424-8D24-04E180695C7A}\DefaultIcon",` # Control panel - Devices and Printers
    "HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" # Libraries
)
[string[]]$LockedHKCRSub=@()
foreach($LockedKey in $LockedHKCRMain) {
    [string[]]$LockedSubKey=(Get-ChildItem "Registry::$($LockedKey)" -Recurse).Name
    $LockedHKCRSub=$LockedHKCRSub + $LockedSubKey
}
[string[]]$LockedHKCR= $LockedHKCRMain + $LockedHKCRSub
# Windows Media Player (Legacy) file association.
[bool]$WMPLegacyInstalled=((Get-ItemProperty -Path "Registry::HKLM\Software\Microsoft\Active Setup\Installed Components\{22d6f312-b0f6-11d0-94ab-0080c74c7e95}" -ea 0).isinstalled -eq 1)
if($WMPLegacyInstalled) {
    [string[]]$WMPHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "WMP11.AssocFile.*") -and (Test-Path "Registry::HKCR\$($_)\shell\play")})
    $WMPLockedHKCR=[string[]]::new($WMPHKCR.length)
    for($i=1;$i -lt $WMPHKCR.length;$i++) {
        $WMPLockedHKCR[$i]="HKCR\$($WMPHKCR[$i])\shell\play"
    }
}
else {
    [string[]]$WMPLockedHKCR=@()
}
[string[]]$LockedHKLM=@()
foreach($Arch in @("","\WOW6432Node")) {
    $LockedHKLM = $LockedHKLM + `
    @(
        "HKLM\SOFTWARE$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{EDC978D6-4D53-4b2f-A265-5805674BE568}",` # Control Panel on Desktop
        "HKLM\SOFTWARE$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" # WSL on desktop
    )
}
[string[]]$AllLockedKeys= $LockedHKLM + $LockedHKCR + $WMPLockedHKCR
foreach($LockedKey in $AllLockedKeys) {
    if((Test-Path "Registry::$($LockedKey)") -and ((Get-Acl "Registry::$($LockedKey)" -ea 0).Owner -NotLike "$($env:UserDomain)\$($env:Username)")) {
        TakeRegOwnership "$($LockedKey)" | Out-Null
    }
}
# ————————FILE ASSOCIATIONS—————————
# --------Any file---------
try {
    New-ItemProperty -LiteralPath "Registry::HKCR\*\shell\pintohomefile" -Name "Icon" -PropertyType "string" -Value "shell32.dll,-322" -ea 0 # Cannot use SetValue function, as the path contains wildcard character *. Must use -LiteralPath. Add SilentlyContinue to suppress error when it's already written.
}
catch { # If the last run returns an error
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\pintohomefile" -Name "Icon" -Value "shell32.dll,-322" -ea 0
}
# --------Java files--------
[bool]$JREInstalled=((Get-Command javaw -ea 0).name -like "javaw.exe")
if($JREInstalled) {
    CreateFileAssociation "jarfile" -ShellOperations "open" -MUIVerb "@shell32.dll,-12710" -Icon "javaw.exe"
}
# --------- zip relevant, compressed archives ---------
# System Standard ZIP Folder
CreateFileAssociation "CompressedFolder" -ShellOperations "open" -Icon "zipfldr.dll,0"
# Other ZIP folders
[string[]]$ZipFileAssoExt=@("7z","apk","zip","cbz","cbr","rar","vdi","001","gz")
if($DAToolSetInstalled) {
    $ZipFileAssoExt = $ZipFileAssoExt + @("override")
}
[string]$ZipAppInstalled=(Get-Childitem "C:\Program files\*zip").name
if($ZipAppInstalled -like "PeaZip") {
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2browseasarchive; PeaZip.add2separate; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name 'Icon' -Value "C:\Program files\Peazip\peazip.exe"
    <# PeaZip Commands include:
    PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2smart; PeaZip.ext2folder; PeaZip.ext2test; PeaZip.ext2browseasarchive; PeaZip.ext2browsepath; PeaZip.add2separate; PeaZip.add2separatesingle; PeaZip.add2separatesfx; PeaZip.add2separate7z; PeaZip.add2separate7zfastest; PeaZip.add2separate7zultra; PeaZip.add2separatezip; PeaZip.add2separatezipfastest; PeaZip.add2separate7zencrypt; PeaZip.add2separatezipmail; PeaZip.add2split; PeaZip.add2convert; PeaZip.analyze; PeaZip.add2wipe #>
    [string[]]$PeaZipHKCR=(Get-ChildItem Registry::HKCR\PeaZip.*).Name # Include HKCR\ prefix
    CreateFileAssociation $($PeaZipHKCR+@("Applications\PEAZIP.exe")) -DefaultIcon "imageres.dll,-174" -ShellOperations "open" -ShellOpDisplayName "Mit PeaZip browsen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
    CreateFileAssociation "CompressedFolder" -DefaultIcon "imageres.dll,-174" -ShellOperations "open2" -ShellOpDisplayName "Mit PeaZip browsen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
    CreateFileAssociation @("Directory\Background","LibraryFolder\background") -ShellOperations @("Browse path with PeaZip","ZPeaZip") -ShellOpDisplayName @("","Hier PeaZip starten") -Icon @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`",0") -Command @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"-ext2browsepath`" `"%V`"") -LegacyDisable @(1,0)
    foreach($Key in $PeaZipHKCR) {
        Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::$($Key)\shell" -Force
        CreateFileAssociation "$($Key)" -ShellOperations "PeaZip" -Icon "zipfldr.dll,-101" -MUIVerb "@zipfldr.dll,-10148"
        SetValue "$($Key)\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2folder; PeaZip.add2split; PeaZip.add2convert; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
        Remove-Item -Path "Registry::$($Key)\shell\PeaZipCompressedFolder" -Force -Recurse -ea 0
    }
    Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::HKCR\AllFilesystemObjects\shell" -Force
    [string[]]$PeaZipCommandHKCR=(Get-ChildItem Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\PeaZip.*).Name # Include HKLM\..... whole path
    foreach($SubCommand in $PeaZipCommandHKCR) {
        if($SubCommand -like "*PeaZip.ext2browseasarchive") {
            [string]$ZipIcon="zipfldr.dll,-101" # Open as archive
        }
        elseif($SubCommand -like "*PeaZip.add2separate*") {
            [string]$ZipIcon="imageres.dll,-175" # Compress/Add2archive
            if($SubCommand -like "*PeaZip.add2separatezipmail") {
                [string]$ZipIcon="mssvp.dll,-500" # Send via E-Mail
            }
            if($SubCommand -like "*PeaZip.*encrypt") {
                [string]$ZipIcon="imageres.dll,-5360" # Encrypt archive
            }
        }
        elseif(($SubCommand -like "*Peazip.ext2*") -and ($SubCommand -notlike "*Peazip.ext2browsepath")) {
            [string]$ZipIcon="shell32.dll,-46" # Extract
        }
        elseif($SubCommand -like "*PeaZip.add2wipe") {
            [string]$ZipIcon="shell32.dll,-16777" #Erase
        }
        else {
            [string]$ZipIcon=""
        }
        if($ZipIcon.length -gt 1) {
            Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "$($ZipIcon)"
        }
    }
    # Remove PeaZip "SendTo" entries
    $SendToItems=(Get-ChildItem "$($env:APPDATA)\Microsoft\Windows\SendTo") | Where-Object {$_.Name -like "*.lnk"}
    $sh=New-Object -ComObject WScript.Shell
    foreach($SendToItem in $SendToItems) {
        $LNKTarget=$sh.CreateShortcut("$($SendToItem.FullName)").TargetPath
        if($LNKTarget -like "*PeaZip*") {
            Remove-Item "$($SendToItem.FullName)"
        }
    } 
}
elseif($ZipAppInstalled -like "7-Zip") {
    CreateFileAssociation @("CompressedArchive","Applications\7zFM.exe") `
    -FileAssoList $ZipFileAssoExt `
    -DefaultIcon "imageres.dll,-174" `
    -ShellOperations "open" `
    -ShellOpDisplayName "Mit 7-Zip browsen" `
    -Icon "`"C:\Program Files\7-Zip\7zFM.exe`",0" `
    -Command "`"C:\Program Files\7-Zip\7zFM.exe`" `"%1`""
}
# ------- PDF Document -------
[string[]]$BrowserPDFs=@("MSEdgePDF")
CreateFileAssociation $BrowserPDFs -ShellOperations "open" -Icon "ieframe.dll,-31065" -MUIVerb "@ieframe.dll,-21819"
if($BrowserPath -like "*chrome.exe*") {
    $BrowserPDFs = $BrowserPDFs + @("ChromePDF")
    CreateFileAssociation "ChromePDF" -FileAssoList ".pdf" -DefaultIcon "$($env:Userprofile)\Links\Adobe Acrobat.ico" -ShellOperations @("open") -MUIVerb @("@SearchFolder.dll,-10496") -Icon @("`"$($BrowserPath)`",0") -Command @("`"$($BrowserPath)`" `"%1`"") # If Adobe Acrobat is not working: Add  before %1
}
# SumatraPDF related
[string]$SumatraPDFLoc=$(CheckInstallPath "SumatraPDF\sumatrapdf.exe")
[bool]$SumatraPDFInstalled=$(Test-Path "$($SumatraPDFLoc)")
if($SumatraPDFInstalled) {
    [string[]]$SumatraPDFHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "SumatraPDF.*"})
    $SumatraPDFHKCR = $SumatraPDFHKCR + "Applications\SumatraPDF.exe"
    foreach($Key in $SumatraPDFHKCR) { # $SumatraPDFHKCR do not contain HKCR\ prefix
        if($Key -like "*epub*") {
            [int]$IconNr=3
        }
        elseif($Key -like "*cb?") {
            [int]$IconNr=4
        }
        else {
            [int]$IconNr=2
        }
        [string]$SumatraICO="`"$($SumatraPDFLoc)`",-$($IconNr)"
        CreateFileAssociation "$($Key)" -DefaultIcon "$($SumatraICO)" -ShellOperations "open" -MUIVerb "@appmgr.dll,-652" -Icon "`"$($SumatraPDFLoc)`",0"
        if($Key -like "*chm") { # CHM Help File
            CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-99" -ShellOperations @("open","open2") -MUIVerb @("@appmgr.dll,-652","@srh.dll,-1359") -Icon ("","C:\Windows\hh.exe") -Command @("","C:\Windows\hh.exe `"$1`"")
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\print") {
            CreateFileAssociation "$($Key)" -ShellOperations "print" -LegacyDisable 1 -Icon "ddores.dll,-2414"
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\printto") {
            CreateFileAssociation "$($Key)" -ShellOperations "printto" -LegacyDisable 1 -Icon "ddores.dll,-2413"
            [string]$KeyWithPrint="$($Key)"
        }
    }
    CreateFileAssociation $BrowserPDFs -ShellOperations @("open2") -Icon @("`"$($SumatraPDFLoc)`",0") -ShellOpDisplayName @("Mit SumatraPDF lesen") -Command @("`"$($SumatraPDFLoc)`" `"%1`"") #"ddores.dll,-2414"
    Copy-Item -Path "Registry::HKCR\$($Key)\shell\open\command" -Destination "Registry::HKCR\MSEdgePDF\shell\open2" -Force
    foreach($PrintAction in @("print","printto")) {
        Copy-Item -Path "Registry::HKCR\$($KeyWithPrint)\shell\$($PrintAction)" -Destination "Registry::HKCR\MSEdgePDF\shell" -Force -Recurse -ea 0
    }
}
# ________________ VS Code related __________________
# Check if VS Code is installed systemwide or for current user only
[bool]$VSCodeInstalled=$false
[string[]]$VSCodeVersion=@("Microsoft VS Code\Code.exe","Microsoft VS Code Insiders\Code - Insiders.exe")
for ($i=0;$i -lt $VScodeVersion.count;$i++) {
    [string]$VSCodeLocation=(CheckInstallPath "$($VSCodeVersion[$i])")
    if($VSCodeLocation.length -gt 0) {
        $VSCodeInstalled=$true
        [string]$VSCodeIconsLoc="$(Split-Path "$($VSCodeLocation)" -Parent)\resources\app\resources\win32"
        [string]$VSCodeVerHKCR="VSCode"
        if($VSCodeLocation -like "*Insiders*") {
            [string]$VSCodeVerHKCR="VSCodeInsiders"
        }
        break
    }
}
# ------- Python script -------
# > Find file location of Python
[string]$PythonEXELocation=(where.exe python.exe)
if($lastexitcode -eq 1) { 
    Write-Host "Python not installed"
    Remove-Item "Registry::HKCR\py_auto_file" -Force -Recurse -ea 0
}
else {
    if($PythonEXELocation -like "$($env:LOCALAPPDATA)\Microsoft\WindowsApps\python.exe") { # Python installed as UWP app
        $PythonApp=(Get-AppxPackage PythonSoftwareFoundation.Python*)[0]
        [string]$PythonInstallLoc="$($PythonApp.InstallLocation)\python.exe"
        [string]$PythonScriptsLoc=(Get-Item "$($env:LocalAppdata)\Packages\$($PythonApp.PackageFamilyName)\LocalCache\local-packages\Python*\Scripts").FullName
        [string]$PythonIconPath="$($env:LOCALAPPDATA)\Packages\$($PythonApp.PackageFamilyName)\python.exe"
        if(!(Test-Path $PythonIconPath)) {
            Copy-Item "$($PythonInstallLoc)" "$(Split-Path -Path $PythonIconPath)"
        }
        try {
            [string]$PythonFileHKCR=((Get-ItemProperty "Registry::HKCR\.py\OpenWithProgids\") | get-member | Where-Object {$_.Name -like "AppX*"})[0].Name # Does not include HKCR itself
        }
        catch {
            [string]$PythonFileHKCR="py_auto_file"
        }
    }
    else { 
        [string]$PythonInstallLoc=$PythonEXELocation
        [string]$PythonIconPath=$PythonEXELocation
        [string]$PythonScriptsLoc="$(Split-Path $PythonEXELocation)\Scripts"
    }
    CreateFileAssociation "$($PythonFileHKCR)" -shelloperations @("open","edit") -Icon @("$($PythonIconPath)","`"$($VSCodeLocation)`",0") -Command ("","`"$($VSCodeLocation)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","")
}
# -----------Text files, VS Code related--------------
# ------- All VSCode files ------
[string[]]$VSCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "$($VSCodeVerHKCR).*"})
foreach($Key in $VSCHKCR) {
    if(Test-Path "Registry::HKCR\$($Key)\shell\open\command" -ea 0) { # Use this if argument to skip VS Code files without "command" subkey
        CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "`"$($VSCodeLocation)`",0" -MUIVerb "@shell32.dll,-37398" -Extended 0 -command "`"$($VSCodeLocation)`" `"%1`""
    }  # Else: Do nothing for VS Code files without "command" subkey. Those are probably defined somewhere else.
}
CreateKey "HKCR\$($VSCodeVerHKCR).txt\DefaultIcon" -StandardValue "imageres.dll,-19"
[string]$VSCodeAppHKCR=$(Split-Path "$($VSCodeLocation)" -leaf)
CreateFileAssociation "Applications\$($VSCodeAppHKCR)" -ShellOperations "open" -Icon "`"$($VSCodeLocation)`",0" -MUIVerb "@certmgr.dll,-291" -Command "`"$($VSCodeLocation)`" `"%1`"" -DefaultIcon "imageres.dll,-19"
# Give "Text" property to all VS Code related files
foreach($FileExt in (Get-ChildItem "Registry::HKCR\.*").Name) {
    [string]$ProgID=(Get-ItemProperty -LiteralPath "Registry::$($FileExt)\OpenWithProgIds" -ea 0) 
    if(($ProgID -like "*$($VSCodeVerHKCR).*") -and (-not (Test-Path "Registry::$($FileExt)\PersistentHandler"))) {
        # Change item type to text in order to let Windows index the values
        CreateKey "$($FileExt)\PersistentHandler" -StandardValue "{5e941d80-bf96-11cd-b579-08002b30bfeb}"
    }
}
# --------Windows Update package (MSU)--------
CreateFileAssociation "Microsoft.System.Update.1" -ShellOperations "open" -Icon "wusa.exe,-101" -MUIVerb "@ActionCenter.dll,-2107"
# ---------Windows folders--------
CreateFileAssociation "Folder" -ShellOperations @("open","opennewwindow","opennewtab","opennewprocess","pintohome") -Icon @("main.cpl,-606","imageres.dll,-5322","imageres.dll,-116","","shell32.dll,-322") -LegacyDisable @(0,0,0,1,0) -MUIVerb @("@shell32.dll,-32960","","","","") -TypeName "@shell32.dll,-9338"
# ---------Hard drives--------
CreateFileAssociation "Drive" -ShellOperations @("manage-bde","encrypt-bde","encrypt-bde-elev","pintohome") -Icon @("shell32.dll,-194","shell32.dll,-194","shell32.dll,-194","shell32.dll,-322")
# --------Directories--------
# Change "Linux (WSL)" Entry icon and location
if($WSLEnabled) {
    [string]$DistroName=(GetDefaultWSL)
    if(($DistroName.length -eq 0)) {
        MkDirCLSID "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -RemoveCLSID
    }
    [string[]]$WSLIconDistro=(GetDistroIcon "$($DistroName)")
    if($WSLIconDistro.length -eq 0) {
        $WSLIconDistro=@($WSLIconPNG,$WSLLocation)
    }
    if($WTInstalled) {
        [string]$WSLMenuCommand="wt.exe -p `"$($DistroName)`""
    }
    else {
        [string]$WSLMenuCommand="wsl.exe --cd `"%V`""
    }
    [int]$WSLVer=(GetDefaultWSL -GetWSLVer)
    if($WSLVer -eq 2) {
        [string]$WSLDirPath="\\wsl.localhost\$($DistroName.Replace(' ','-'))"
    }
    elseif($WSLVer -eq 1) {
        [string]$WSLDirPath="$(GetDefaultWSL -GetWSLPath)\rootfs"
    }
    MkDirCLSID "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -FolderType 6 -Name "$($DistroName)" -Pinned $WSLVer%2 -TargetPath "$($WSLDirPath)" -Icon "$($WSLIconDistro[1])"
    CreateFileAssociation "CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -ShellOperations "open2" -Icon "`"$($WSLLocation)`",0" -Command "$($WSLMenuCommand)" -MUIVerb "@wsl.exe,-2" 
    # Remove "Linux" Entry from desktop
    Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -ea 0
}
[string[]]$PowerShellDef=@("","powershell.exe,0") # [0]: Display Name; [1]: Icon file
# Hide "Open in terminal" entry to unify how the menu looks.
SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
    -Name "{9F156763-7844-4DC4-B2B1-901F640F5155}" -EmptyValue $true # Terminal
SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
    -Name "{02DB545A-3E20-46DE-83A5-1329B1E88B6B}" -EmptyValue $true # Terminal preview
if($WTInstalled) {
    [string]$CmdMenuCommand="wt.exe -d `"%V `" -p `"Eingabeaufforderung`""
    [string]$PwsMenuCommand="wt.exe -d `"%V `" -p `"PowerShell`""
    [string]$PwsUACCommand="PowerShell -windowstyle hidden -Command `"Start-Process wt.exe -ArgumentList '-d `"`"%V `"`"`"' -Verb RunAs`""
}
else {
    [string]$CmdMenuCommand="cmd.exe -d `"%V `""
    [string]$PwsMenuCommand="powershell.exe -NoExit -Command Set-Location -LiteralPath `"%V`""
    [string]$PwsUACCommand="PowerShell.exe -windowstyle hidden -Command `"Start-Process powershell.exe -ArgumentList '-noexit -command Set-Location -LiteralPath `"`"%V `"`"`"' -Verb RunAs`""
}
if(Test-Path "C:\Windows\System32\twinui.pcshell.dll") {
    $PowerShellWithAdminMUIverb="@twinui.pcshell.dll,-10929"
    $PowerShellWithAdminDisplay=""
}
else {
    $PowerShellWithAdminMUIverb=""
    $PowerShellWithAdminDisplay="PowerShell (Admin) hier starten"
}
[string]$WSLIcon="`"$($WSLLocation)`",0"
if([System.Environment]::OSVersion.Version.Build -lt 18000) { # WSL.exe gets an icon since WSL2 (1903)
    GetDistroIcon -Iconforlnk
    $WSLIcon="$($env:USERPROFILE)\Links\Tux.ico"
}
CreateFileAssociation @("Directory\Background","Directory","LibraryFolder\background") `
    -ShellOperations @("cmd","VSCode","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") `
    -ShellOpDisplayName @("","Hier VS Code starten","Hier VS Code starten (Administrator)","","","","$($PowerShellWithAdminDisplay)","") `
    -Icon @("cmd.exe,0","`"$($VSCodeLocation)`",0","`"$($VSCodeLocation)`",0","`"C:\Program Files\Git\git-bash.exe`",0",`
        "`"C:\Program Files\Git\git-bash.exe`",0","$($PowerShellDef[1])","$($PowerShellDef[1])","$($WSLIcon)") `
    -Extended @(0,0,0,1,1,0,0,0) `
    -LegacyDisable @(1,0,0,0,0,0,0,!($WSLEnabled)) `
    -HasLUAShield @(0,0,1,0,0,0,1,0) `
    -MUIVerb @("","","","","","@shell32.dll,-8508",$PowerShellWithAdminMUIverb,"@wsl.exe,-2") `
    -Command @("$($CmdMenuCommand)","`"$($VSCodeLocation)`" `"%v `"",`
        "PowerShell -windowstyle hidden -Command `"Start-Process '$($VSCodeLocation)' -ArgumentList '-d `"`"%V`"`"`"' -Verb RunAs`"",`
        "wt.exe new-tab --title Git-Bash --tabColor #300a16 --suppressApplicationTitle `"C:\Program Files\Git\bin\bash.exe`"",`
        "",` # git-gui no need to define
        "$($PwsMenuCommand)",`
        "$($PwsUACCommand)","$($WSLMenuCommand)")
Remove-Item -Path "Registry::HKCR\Directory\Background\DefaultIcon" -ea 0 # Not needed
# Admin commands don't work in Library Folders, so disable them in Libraries
CreateFileAssociation "LibraryFolder\background" -ShellOperations @("VSCodeWithAdmin","PowerShellWithAdmin") -LegacyDisable @(1,1) 
foreach($GitContextMenu in @("git_shell","git_bash"))
{
    MakeReadOnly "HKCR\Directory\Background\shell\$($GitContextMenu)" -InclAdmin
}
# Show above mentioned entries only on directory background, NOT when clicking a folder
CreateFileAssociation "Directory" -ShellOperations @("cmd","VSCode","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") -Extended @(1,1,1,1,1,1,1,1) -LegacyDisable @(1,1,1,1,1,1,1,1)
# Desktop functionality
CreateFileAssociation "DesktopBackground" -ShellOperations @("Display","Personalize") -Icon @("ddores.dll,-2109","shell32.dll,-270")
# Remove AMD Radeon context menu entries
RemoveAMDContextMenu
# -------Image files-------
[string]$GIMPLocation=(CheckInstallPath "GIMP 2\bin\gimp-2.10.exe")
[string]$PaintEditIcon="`"$($PaintIconLocation)`",0"
CreateFileAssociation @("$($PaintAppHKCR)","SystemFileAssociations\image") -ShellOperations @("edit","edit2","print","printto") -Icon @("$($PaintEditIcon)","`"$($GIMPLocation)`",0","ddores.dll,-2414","ddores.dll,-2413") -ShellOpDisplayName @("","Mit GIMP bearbeiten","","") -MUIVerb @("@mshtml.dll,-2210","","@shell32.dll,-31250","@printui.dll,-14935") -Command @("mspaint.exe `"%1`"","`"$($GIMPLocation)`" `"%1`"","","")
[string[]]$ImageFileExts=@("bmp","jpg","jpeg","png","016","256","ico","cur","ani","dds","tif","tiff","rri")
SetValue "HKCR\.256" -Name "PerceivedType" -Value "image"
foreach($ImageExt in $ImageFileExts) {
    if($ImageExt[0] -ne ".") {
        $ImageExt=".$($ImageExt)"
    }
    if($ImageExt -eq ".ani") {
        [string]$PhotoViewerCap="anifile"
    }
    elseif($ImageExt -eq ".cur") {
        [string]$PhotoViewerCap="curfile"
    }
    elseif($ImageExt -eq ".ico") {
        [string]$PhotoViewerCap="icofile"
    }
    else {
        [string]$PhotoViewerCap="PhotoViewer.FileAssoc.Tiff"
        SetValue -RegPath "HKCR\$($ImageExt)" -Name "PerceivedType" -Value "image"
    }
    SetValue -RegPath "Registry::HKLM\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" -Type "string" -Name $ImageExt -Value "$($PhotoViewerCap)"
    if($PhotoViewerCap -notlike "PhotoViewer.FileAssoc.Tiff") {
        CreateFileAssociation $PhotoViewerCap -ShellOperations "open" -command "rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -MUIVerb "@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043" -Icon "`"C:\Program Files\Windows Photo Viewer\PhotoViewer.dll`",0"
        CreateKey "HKCR\$($PhotoViewerCap)\shell\open\DropTarget"
        SetValue "HKCR\$($PhotoViewerCap)\shell\open\DropTarget" -Name "Clsid" -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"
    }
}
# Cursor file: show icon directly af file: DefaultIcon="%1"
foreach($CursorType in @("anifile","curfile")) {
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell" -Destination "Registry::HKCR\$($CursorType)" -force
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open" -Destination "Registry::HKCR\$($CursorType)\shell" -force
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open\command" -Destination "Registry::HKCR\$($CursorType)\shell\open" -force
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open\droptarget" -Destination "Registry::HKCR\$($CursorType)\shell\open" -force
}
CreateFileAssociation "PhotoViewer.FileAssoc.Tiff" -ShellOperations "open" -Icon "`"C:\Program Files\Windows Photo Viewer\PhotoViewer.dll`",0" -DefaultIcon "imageres.dll,-122" # "`"C:\Program Files\Windows Photo Viewer\PhotoAcq.dll`",-7"
$SysFileAssoExt=(Get-ChildItem "Registry::HKEY_CLASSES_ROOT\SystemFileAssociations\.*")
foreach($AssoExt in $SysFileAssoExt) {
    if(Test-Path "Registry::$($AssoExt.name)\shell\setdesktopwallpaper") {
        CreateFileAssociation "$($AssoExt.name)" -ShellOperations "setdesktopwallpaper" -Icon "imageres.dll,-110"
        if([System.Environment]::OSVersion.Version.Build -lt 22000) {
            CreateFileAssociation "$($AssoExt.name)" -ShellOperations "3d edit" -LegacyDisable 1
        }
    }
}
# -------Audio and video files-------
# Check which media player is installed
[string[]]$MPlayers=@("VLC","WMP Legacy","WMP UWP")
[bool[]]$MPlayersInstalled=@((Test-Path "C:\Program Files\VideoLAN"),`
$WMPLegacyInstalled,` # Mentioned above to check if needed to take ownership of WMP11* keys
$WMPUWPInstalled)
if($MPlayersInstalled[0]) { # VLC installed
    Write-Host "$($MPlayers[0]) installed"
    CreateFileAssociation "Directory" -ShellOperations @("PlayWithVLC","AddtoPlaylistVLC") -LegacyDisable @(1,1)
    [string[]]$VLCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "VLC.*"})
    $VLCHKCR=$VLCHKCR+@("Applications\vlc.exe")
    [string]$VLCFileName=""
    foreach($VLCKey in $VLCHKCR) {
        if($VLCKey -like "VLC.VLC*") { # Skip VLC.VLC, as the following command will chang "VLC.VLC" to "." and break the file association of files without extension.
            continue
        }
        [string]$VLCExtension=($VLCKey -replace 'VLC','' -Replace '.Document','')
        if(@('.bin','.dat','.','.iso') -contains $VLCExtension) { # Skip VLC.VLC.Document
            continue
        }
        [string]$VLCFileType=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($VLCExtension)" -ea 0).'PerceivedType'
        if($VLCFileType -like "audio") { # VLC Audio File
            [string]$VLCFileIcon="imageres.dll,-1026" # "imageres.dll,-22"
            [string]$VLCFileName="@wiashext.dll,-279"
            if($VLCExtension -like ".mid*") {
                [string]$VLCFileName="@unregmp2.dll,-9993"
            }
        }
        elseif($VLCFileType -like "video" -or (@(".rmvb",".flv") -contains $VLCFileType)) {
            [string]$VLCFileIcon="imageres.dll,-23"
            if($VLCExtension -like ".mp4") {
                [string]$VLCFileName="@unregmp2.dll,-9932"
            }
            elseif($VLCExtension -like ".mkv") {
                [string]$VLCFileName="@unregmp2.dll,-9950"
            }
            elseif($VLCExtension -like ".avi") {
                [string]$VLCFileName="@unregmp2.dll,-9997"
            }
            elseif($VLCExtension -like ".wmv") {
                [string]$VLCFileName="@unregmp2.dll,-10000"
            }
            elseif($VLCExtension -like ".3gp") {
                [string]$VLCFileName="@unregmp2.dll,-9937"
            }
            elseif($VLCExtension -like ".3g*2") {
                [string]$VLCFileName="@unregmp2.dll,-9938"
            }
            else {
                [string]$VLCFileName="@unregmp2.dll,-9905"
            }
        }
        elseif(@(".cda",".CDAudio") -contains $VLCExtension) {
            [string]$VLCFileIcon="imageres.dll,-180"
        }
        else {
            [string]$VLCFileIcon="imageres.dll,-134"
        }
        SetValue "HKCR\$($VLCExtension)\OpenWithProgids" -Name "$($VLCKey)" -EmptyValue $true
        CreateFileAssociation "$($VLCKey)" -DefaultIcon "$($VLCFileIcon)" -ShellOperations "open" -Icon "imageres.dll,-5201" -MUIVerb "@shell32.dll,-22072" -TypeName "$($VLCFileName)"
        [string]$EnqueueEntry=""
        if(Test-Path "Registry::HKCR\$($VLCKey)\shell\enqueue") {
            $EnqueueEntry="enqueue"
        }
        elseif(Test-Path "Registry::HKCR\$($VLCKey)\shell\AddToPlaylistVLC") {
            $EnqueueEntry="AddtoPlaylistVLC"
        }
        CreateFileAssociation "$($VLCKey)" -ShellOperations $enqueueentry -MUIVerb "@shell32.dll,-37427" -Icon "wlidcli.dll,-1008"
        if("Registry::HKCR\$($VLCKey)\shell\PlayWithVLC") {
            CreateFileAssociation "$($VLCKey)" -ShellOperations "PlayWithVLC" -LegacyDisable $true
        }
    }
}
elseif($MPlayersInstalled[1]) { # WMP Legacy installed
    Write-Host "$($MPlayers[1]) installed"
    foreach($Key in $WMPHKCR) { # WMPHKCR includes "HKCR\" at the beginning
        if((Get-ItemProperty -LiteralPath "Registry::$($Key)\shell\play" -ea 0)."Icon" -like "imageres.dll,-5201") {
            break
        }
        CreateFileAssociation $Key -ShellOperations @("Enqueue","play") `
            -Icon @("wlidcli.dll,-1008","imageres.dll,-5201") `
            -MUIVerb @("@shell32.dll,-37427","@shell32.dll,-22072")
    }
}
elseif($MPlayersInstalled[2]) { # WMP UWP installed
    [string]$WMPAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)\Application" -ea 0).ApplicationName -like "*Microsoft.ZuneMusic*"})[0]
    CreateFileAssociation "$($WMPAppHKCR)" -ShellOperations @("open","enqueue","play") -ShellDefault "play" -LegacyDisable @(1,0,0) -Icon @("","shell32.dll,-16752","imageres.dll,-5201") -DefaultIcon "imageres.dll,-134" -MUIVerb @("","@shell32.dll,-37427","")
}
# --------EXE File--------
CreateFileAssociation "exefile" -ShellOperations @("open","runas") `
    -Icon @("imageres.dll,-100","imageres.dll,-100") `
    -MUIVerb @("@shell32.dll,-12710","") -HasLUAShield @(0,1)
# -------Screensaver-------
CreateFileAssociation "scrfile" -FileAssoList ".scr" -DefaultIcon "%1" `
    -ShellOperations @("config","install","open") `
    -Icon @("mmcndmgr.dll,-30572","setupugc.exe,-133","webcheck.dll,-407")
# ---------TXT File---------
CreateFileAssociation @("txtfile","textfile","SystemFileAssociations\text") `
    -DefaultIcon "imageres.dll,-19" `
    -ShellOperations @("open","edit") `
    -ShellDefault "open" `
    -LegacyDisable @(0,1) `
    -Icon @("`"$($VSCodeLocation)`",0","`"$($VSCodeLocation)`",0") `
    -Command @("`"$($VSCodeLocation)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"") `
    -MUIVerb @("@mshtml.dll,-2210","")
if(Test-Path "Registry::HKCR\txtfile\shell\print\command") {
    CreateFileAssociation @("txtfile","textfile") -ShellOperations @("print","printto") `
        -Icon @("ddores.dll,-2413","ddores.dll,-2414") `
        -Extended @(1,1) -LegacyDisable @(1,1)
}
# ------- Cheat Engine Cheat Table-------
if(Test-Path "Registry::HKCR\CheatEngine\DefaultIcon") {
    [string]$CheatEnginePath=(Get-ItemProperty -LiteralPath "Registry::HKCR\CheatEngine\DefaultIcon").'(default)' -replace ',0',''
    CreateFileAssociation "CheatEngine" -shelloperations @("open","edit") -Icon @("$($CheatEnginePath)","`"$($VSCodeLocation)`",0") -Command @("","`"$($VSCodeLocation)`" `"%1`"")
}
# --------BAT, CMD, COM script-------
CreateFileAssociation @("batfile","cmdfile","comfile") -ShellOperations @("open","print","edit","runas") -Icon @("cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeLocation)`",0","cmd.exe,0") -MUIVerb @("@shell32.dll,-12710","","","") -Command @("","","`"$($VSCodeLocation)`" `"%1`"","") -Extended @(0,1,0,0) -LegacyDisable @(0,1,0,0) -DefaultIcon "cmd.exe,0" ` # "$($VSCodeIconsLoc)\shell.ico"
# --------VBE, VBS and JSE (JavaScript) Script--------
if(Test-Path "C:\Windows\System32\wscript.exe") { # If VBS as a legacy component is not disabled yet.
    CreateFileAssociation @("VBSFile","VBEFile","JSEFile") ` # "$($VSCodeVerHKCR).vb",
    -ShellOperations @("open","open2","print","edit") `
    -Icon @("wscript.exe,-1","cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeLocation)`",0") `
    -MUIVerb @("@shell32.dll,-12710","@wshext.dll,-4511","","") `
    -Command @("WScript.exe `"%1`" %*","CScript.exe `"%1`" %*","","`"$($VSCodeLocation)`" `"%1`"") `
    -FileAssoList @("vb","vbs","vbe","jse") `
    -Extended @(0,0,1,0) -LegacyDisable @(0,0,1,0)
}
# --------Registry file--------
CreateFileAssociation "regfile" -ShellOperations @("open","edit","print") `
    -Icon @("regedit.exe,0","`"$($VSCodeLocation)`",0","DDORes.dll,-2413") `
    -Extended @(0,0,1) -ShellDefault "open"`
    -command @("","`"$($VSCodeLocation)`" `"%1`"","")
# -------XML Document-------
Remove-ItemProperty -Path "Registry::HKCR\.xml" -Name "PreceivedType" -ea 0
foreach($ML_Ext in @("xml","htm","html")) {    
    Remove-ItemProperty -Path "Registry::HKCR\.$($ML_Ext)\OpenWithProgids" -Name "MSEdgeHTM" -ea 0 
}
CreateFileAssociation @("xmlfile","$($VSCodeVerHKCR).xml","xml_auto_file") -FileAssoList ".xml" -DefaultIcon "msxml3.dll,-128" -ShellOperations @("open","edit") -ShellDefault "edit" -Icon @("$($BrowserIcon)","`"$($VSCodeLocation)`",0") -MUIVerb @("$($OpenInBrowserText)","")-Command @("$($BrowserOpenAction)","`"$($VSCodeLocation)`" `"%1`"") -CommandId @("IE.File","") -DelegateExecute @("{17FE9752-0B5A-4665-84CD-569794602F5C}","")
Remove-Item "Registry::HKCR\xmlfile\ShellEx\IconHandler" -ea 0
# ------- PS1 Script ------
CreateFileAssociation @("Microsoft.PowerShellScript.1") -FileAssoList @("ps1")  -DefaultIcon "$($VSCodeIconsLoc)\powershell.ico" -ShellOperations @("open","edit","runas") -Icon @("scrptadm.dll,-7","`"$($VSCodeLocation)`",0","C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,1") -MUIVerb @("@`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`",-108","","") -Command @("`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`"  `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`"","`"$($VSCodeLocation)`" `"%1`"","`"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`" `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`" -Verb RunAs")
CreateFileAssociation "SystemFileAssociations\.ps1" -ShellOperations @("0","Windows.PowerShell.Run") -LegacyDisable @(1,1)
Remove-Item "Registry::HKCR\Microsoft.PowerShellScript.1\shell\0" -ea 0
# ------- LOG File ------
SetValue "HKCR\.log" -Name "Content Type" -Value "text/plain"
SetValue "HKCR\.log" -Name "PerceivedType" -Value "text"
# ------- Linux BASH -------
CreateFileAssociation @("bashfile") -FileAssoList @("sh","bash") -ShellOperations @("open","edit") -Icon @("$($WSLLocation)","$($VSCodeLocation)") -Command @("wsl.exe bash `$(wslpath `"%1`")","`"$($VSCodeLocation)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","") -DefaultIcon "$($VSCodeIconsLoc)\shell.ico" -LegacyDisable @(!($WSLEnabled),0)
# --------HTML file--------
[string]$OpenHTMLVerb="@ieframe.dll,-14756" # Open in new tab
if($BrowserIcon -like "ieframe.dll,-31065") {
    $OpenHTMLVerb="@ieframe.dll,-21819" # Open with Edge
}
CreateFileAssociation @("htmlfile","$($VSCodeVerHKCR).htm","$($VSCodeVerHKCR).html","MSEdgeHTM","Applications\MSEdge.exe") -DefaultIcon "ieframe.dll,-210" -ShellOperations @("open","open2","edit","print","printto") -Icon @("$($BrowserIcon)","`"$($SumatraPDFLoc)`",0","`"$($VSCodeLocation)`",0","DDORes.dll,-2414","DDORes.dll,-2413") -Command @("$($BrowserOpenAction)","`"$($SumatraPDFLoc)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"","","") -MUIVerb @("$($OpenHTMLVerb)","","","","") -LegacyDisable @(0,0,0,1,1) -ShellOpDisplayName @("","Mit SumatraPDF lesen","","","")
MakeReadOnly "HKCR\MSEdgeHTM\DefaultIcon" -InclAdmin
MakeReadOnly "HKCR\htmlfile\DefaultIcon" -InclAdmin
# ------- URL Internet Shortcut -------
foreach($PropertyToBeRemoved in @("NeverShowExt")) { #,"IsShortcut"
    Remove-ItemProperty -Path "Registry::HKCR\InternetShortcut" -Name $PropertyToBeRemoved -ea 0
}
Remove-Item -Path "Registry::HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}" -Force
CreateFileAssociation "InternetShortcut" -DefaultIcon "url.dll,-5" -ShellOperations @("open","edit","print","printto") -Icon @("$($BrowserIcon)","`"$($VSCodeLocation)`",0","ddores.dll,-2414","ddores.dll,-2413") -MUIVerb @("@synccenter.dll,-6102",,"","","") -LegacyDisable @(0,0,1,1) -Command @("powershell.exe -Command `"`$URL= ((Get-Content '%1') -like 'URL=*') -replace 'URL=',' '; Start-Process '$($BrowserPath)' -ArgumentList `$URL`"","`"$($VSCodeLocation)`" `"%1`"","","")
# --------Google Chrome HTML (if Chrome installed)--------
if($BrowserPath -like "*chrome.exe*") {
    CreateFileAssociation "ChromeHTML" -DefaultIcon "shell32.dll,-14" `
    -ShellOperations @("open","edit") -MUIVerb @("@SearchFolder.dll,-10496","") `
    -Icon @("`"$($BrowserPath)`",0","`"$($VSCodeLocation)`",0") `
    -Command @("`"$($BrowserPath)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"")
}
# ---------MS Office files---------
# File Associations when Microsoft Office is installed
if($MSOfficeInstalled) {
    # PPT
    [string[]]$PPTHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {(($_ -like "PowerPoint.Show*") -or ($_ -like "PowerPoint.Slide*")) -and (Test-Path "Registry::HKCR\$_\shell\edit")})
    foreach($Key in $PPTHKCR) {
        CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","Open","OpenAsReadOnly","Print","PrintTo","Show","ViewProtected") -Icon @("","shell32.dll,-133","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`",-1300","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`",-1300","ddores.dll,-2414","ddores.dll,-2413","imageres.dll,-103","") -LegacyDisable @(1,0,0,0,0,0,0,1) -Extended @(1,0,0,0,0,0,0,1) -Command ("","","","","","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`" /pt `"%2`" `"%3`" `"%4`" `"%1`"","","")
    }
    # WORD
    [string[]]$DOCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Word.*Document*.*") -and (Test-Path "Registry::HKCR\$_\shell\edit")})
    foreach($Key in $DOCHKCR) {
        CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","OnenotePrintto","Open","OpenAsReadOnly","Print","PrintTo","ViewProtected") -Icon @("","shell32.dll,-133","","`"$($MSOfficeLoc)\Office16\WINWORD.EXE`",-1","`"$($MSOfficeLoc)\Office16\WINWORD.EXE`",-1","ddores.dll,-2414","ddores.dll,-2413","") -LegacyDisable @(1,0,1,0,0,0,0,1) 
    }
    # EXCEL
    [string[]]$XLSHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Excel.*") -and (Test-Path "Registry::HKCR\$_\shell\print")})
    foreach($Key in $XLSHKCR) {
        CreateFileAssociation "$($Key)" -ShellOperations @("Open","print") -Icon @("$($MSOfficeLoc)\Office16\EXCEL.EXE,-257","ddores.dll,-2414")
        foreach($OtherShellOp in @("Edit","New","OpenAsReadOnly","Printto","ViewProtected")) {
            if(Test-Path "Registry::HKCR\$($Key)\shell\$($OtherShellOp)") {
                [bool]$ExcelHidden=$false
                if($OtherShellOp -like "New") {
                    [string]$ExcelIcon="shell32.dll,-133"
                }
                elseif($OtherShellOp -like "PrintTo") {
                    [string]$ExcelIcon="ddores.dll,-2413"
                }
                else {
                    [string]$ExcelIcon="$($MSOfficeLoc)\Office16\EXCEL.EXE,-257"
                    if(@("Edit","ViewProtected") -contains $OtherShellOp) {
                        [bool]$ExcelHidden=$true
                    }
                }
                CreateFileAssociation "$($Key)" -ShellOperations "$($OtherShellOp)" -Icon "$($ExcelIcon)" -LegacyDisable $ExcelHidden
            }
        }
    }
    # Outlook ICS Calender
    CreateFileAssociation "Outlook.File.ics.15" -DefaultIcon "dfrgui.exe,-137" -ShellOperations "open" -Icon "$($MSOfficeLoc)\Office16\OUTLOOK.exe,-3"
}
# File associations when LibreOffice is installed
elseif($LibreOfficeInstalled) {
    [string[]]$LibreOfficeHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "LibreOffice.*"})
    foreach($Key in $LibreofficeHKCR) {
        $OfficeIcon=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\DefaultIcon").'(default)'
        CreateFileAssociation "$($Key)" -ShellOperations "Open" -Icon "$($OfficeIcon)"
        if(Test-Path "Registry::HKCR\$($Key)\shell\New") {
            CreateFileAssociation "$($Key)" -ShellOperations "New" -Icon "shell32.dll,-133"
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\Print") {
            CreateFileAssociation "$($Key)" -ShellOperations "Print" -Icon "DDORes.dll,-2414"
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\PrintTo") {
            CreateFileAssociation "$($Key)" -ShellOperations "PrintTo" -Icon "DDORes.dll,-2413"
        }
    }
}
# File Associations when OnlyOffice is installed
elseif($OnlyOfficeInstalled) {
    [string[]]$OnlyOfficeHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "ASC.*"})
    foreach($Key in $OnlyofficeHKCR) {
        $OfficeIcon=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\DefaultIcon").'(default)'
        CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "C:\Program Files\ONLYOFFICE\DesktopEditors\app.ico"
        if(($OfficeIcon -like "*ONLYOFFICE*") -and ([System.Environment]::OSVersion.Version.Build -ge 22000)) { 
            # ONLYOFFICE icon is sorta ugly. Wanna change them to the MS Office file icons (only included in imageres.dll after Windows 11)
            [int]$OfficeFileIconType=($OfficeIcon -replace "[^0-9]" , '') # Get the numbers only
            Switch($OfficeFileIconType) {
                {$_ -in 24,22,10,23} { # Excel, CSV files etc.
                    CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-8320" -FileAssoList @(".xls",".xlsx","xlsm","ods")
                }
                {$_ -in 1,9,3,2,8} { # PPT
                    CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-8312" -FileAssoList @(".ppt",".pptx")
                }
                {$_ -in 11,7,18,19} { # Word
                    CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-8302" -FileAssoList @(".doc",".docx","dot","odt")
                }
            }
        }
    }
    CreateFileAssociation "ASC.Csv" -DefaultIcon "imageres.dll,-8301" -FileAssoList @(".csv")
}
# When no office program installed: Use browser to open
else {
    # PPT
    CreateFileAssociation "PPTFile" -FileAssoList @(".ppt",".pptx") -DefaultIcon "imageres.dll,-8312" -TypeName "@explorerframe.dll,-50295" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    # WORD
    CreateFileAssociation "DOCFile" -FileAssoList @(".doc",".docx","odt") -DefaultIcon "imageres.dll,-8302" -TypeName "@explorerframe.dll,-50293" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    # EXCEL
    CreateFileAssociation "XLSFile" -FileAssoList @(".xls",".xlsx","xlsm") -DefaultIcon "imageres.dll,-8320" -TypeName "@explorerframe.dll,-50294" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
}
# ----------------
# RDP file (config for remote connection)
if(!([bool](Get-ItemProperty "Registry::HKCR\RDP.File\shell\Connect").Icon)) { # If registry not written already
    CreateFileAssociation "RDP.File" -ShellOperations @("Connect","Edit","Open") -Extended @(0,0,0) -Icon @("mstscax.dll,-13417","mstsc.exe,-101","`"$($VSCodeLocation)`",0")  -ShellOpDisplayName @("","Mit MSTSC bearbeiten","Mit Visual Studio Code bearbeiten") -Command @("","","`"$($VSCodeLocation)`" `"%1`"")
}
# ----------------
# PFX Certificate
CreateFileAssociation "pfxfile" -ShellOperations @("add","open") -Extended @(0,1) -LegacyDisable @(0,1) `
    -Icon @("certmgr.dll,-6169","certmgr.dll,-6169") -MUIVerb @("@cryptext.dll,-6126","") -ShellDefault "add"
# ----------------
# INI /INF Config file
CreateFileAssociation @("inifile","inffile") `
    -FileAssoList @("forger2","conf","ini","inf") `
    -ShellOperations @("open","print") `
    -Command @("`"$($VSCodeLocation)`" `"%1`"","") `
    -MUIVerb @("@mshtml.dll,-2210","") `
    -Icon @("`"$($VSCodeLocation)`",0","DDORes.dll,-2413") `
    -Extended @(0,1) -LegacyDisable @(0,1) `
    -DefaultIcon "imageres.dll,-69"
# INF File Install
CreateFileAssociation "SystemFileAssociations\.inf" -ShellOperations "install" -Icon "msihnd.dll,-10" 
# SRT Subtitles
[string]$SEditLoc="C:\Program Files\Subtitle Edit\SubtitleEdit.exe"
if(Test-Path "$($SEditLoc)") {
    [string[]]$SubtitleTypes=(Get-ChildItem "$($SEditLoc.replace("\SubtitleEdit.exe","\Icons\*"))").BaseName # Only file name without extension
    foreach($SubtitleType in $SubtitleTypes) {
        if($SubtitleType -like "uninstall") {
            continue
        }
    CreateFileAssociation "SubtitleEdit.$($SubtitleType)" `
        -DefaultIcon "`"$($SEditLoc -replace "\SubtitleEdit.exe","\icons\$($SubtitleType).ico")`"" `
        -ShellOperations @("open","edit") -FileAssoList "$($SubtitleType)" `
        -Icon @("`"$($SEditLoc)`",0","`"$($VSCodeLocation)`",0") `
        -Command @("`"$($SEditLoc)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"")
    }
}
# CRDownload and !qB partially downloaded files
CreateFileAssociation "Downloading" -FileAssoList @("crdownload","!qB") -DefaultIcon "shell32.dll,-231"
# ISO File
CreateFileAssociation "Windows.ISOFile" -ShellOperations "burn" -Icon "shell32.dll,-16768"
# _____________________________
# ____Explorer Namespaces_____
# Most must be changed both in 64-bit and 32-bit registry to have effect

# Change recycle bin empty icon
SetValue -RegPath "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\empty" -Name "Icon" -Value "imageres.dll,-5305"
# Add recycle bin to this PC
SetValue -RegPath "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}" -Name "DescriptionID" -Type "dword" -Value 0x16
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{645FF040-5081-101B-9F08-00AA002F954E}"
# Change "Manage" icon
SetValue -RegPath "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "Icon" -Value "mycomput.dll,-204"
Remove-ItemProperty -Path "Registry::HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "HasLUAShield" -ea 0
# ------ CONTROL PANEL ------
# Change control panel icons
CreateFileAssociation @("CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}","CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}") -DefaultIcon "Control.exe,0" -Icon "Control.exe,0" -ShellOperations "open" -MUIVerb "@shell32.dll,-10018" -command "control.exe"
SetValue -RegPath "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -name "DescriptionID" -Type "dword" -Value 0x16
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
CreateFileAssociation "CLSID\{60632754-c523-4b62-b45c-4172da012619}" -DefaultIcon "imageres.dll,-79" # Control panel - user accounts
CreateFileAssociation "CLSID\{7b81be6a-ce2b-4676-a29e-eb907a5126c5}" -DefaultIcon "wusa.exe,-101" # Control panel - Programs and Features
CreateFileAssociation "CLSID\{62D8ED13-C9D0-4CE8-A914-47DD628FB1B0}" -DefaultIcon "imageres.dll,-144" # Control panel - Region and Language
CreateFileAssociation "CLSID\{725BE8F7-668E-4C7B-8F90-46BDB0936430}" -DefaultIcon "ddores.dll,-2210" # Control panel - Keyboard properties
CreateFileAssociation "CLSID\{6C8EEC18-8D75-41B2-A177-8831D59D2D50}" -DefaultIcon "ddores.dll,-2212" # Control panel - Mouse properties
CreateFileAssociation "CLSID\{D555645E-D4F8-4c29-A827-D93C859C4F2A}" -DefaultIcon "shell32.dll,-268" # Control panel - Ease of access center
CreateFileAssociation "CLSID\{9C60DE1E-E5FC-40f4-A487-460851A8D915}" -DefaultIcon "imageres.dll,-5362" # Control panel - AutoPlay
CreateFileAssociation "CLSID\{A8A91A66-3A7D-4424-8D24-04E180695C7A}" -DefaultIcon "imageres.dll,-196" # Control panel - Devices and Printers
[string]$OneDriveInstallLoc=(CheckInstallPath "Microsoft?OneDrive\OneDrive.exe")
if(Test-Path "$($OneDriveInstallLoc)") {
    [string]$WorkFolderIcon="`"$($OneDriveInstallLoc)`",-589"
}
else {
    [string]$WorkFolderIcon="WorkFoldersRes.dll,-1"
}
CreateFileAssociation "CLSID\{ECDB0924-4208-451E-8EE0-373C0956DE16}" -DefaultIcon "$($WorkFolderIcon)" # Control panel - Work folders
CreateFileAssociation "CLSID\{BB06C0E4-D293-4f75-8A90-CB05B6477EEE}" -DefaultIcon "mstsc.exe,-20022" # Control panel - System
CreateFileAssociation "CLSID\{BD84B380-8CA2-1069-AB1D-08000948F534}" -DefaultIcon "imageres.dll,-129" # Control panel - Font folder
CreateFileAssociation "CLSID\{93412589-74D4-4E4E-AD0E-E0CB621440FD}" -DefaultIcon "main.cpl,-106" # Control panel - Font settings
CreateFileAssociation "CLSID\{58E3C745-D971-4081-9034-86E34B30836A}" -DefaultIcon "ddores.dll,-2014" # Control panel - Speech recognition
CreateFileAssociation "CLSID\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}" -DefaultIcon "ddores.dll,-2143" # Power options
CreateFileAssociation "CLSID\{80F3F1D5-FECA-45F3-BC32-752C152E456E}" -DefaultIcon "ddores.dll,-2108" # Tabet PC Settings
CreateFileAssociation "CLSID\{87D66A43-7B11-4A28-9811-C86EE395ACF7}" -DefaultIcon "imageres.dll,-1025" # Indexing options
CreateFileAssociation "CLSID\{9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF}" -DefaultIcon "mobsync.exe,-1" # Sync center
CreateFileAssociation "CLSID\{A3DD4F92-658A-410F-84FD-6FBBBEF2FFFE}" -DefaultIcon "ieframe.dll,-211" # Internet options
# Add "Personalization" to Control Panel
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{ED834ED6-4B5A-4bfe-8F11-A626DCB6A921}"
# ------
# Use legacy context menu
CreateKey "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" -StandardValue " "
# Remove common groups folder
if($RemoveCommonStartFolder) {
    foreach($RegRt in @("HKCU","HKLM")) {
        SetValue "$($RegRt)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoCommonGroups" -Type "dword" -Value "0"
    }
}
# Show "Details" tile in Windows Explorer
# SetValue "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Modules\GlobalSettings\DetailsContainer" -Name "DetailsContainer" -Type 3 -Value "01,00,00,00,02,00,00,00" # Type 3 means binary
# Show library folders in Explorer
foreach($LibraryFolder in ((Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\")+(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\")).Name) {
    Remove-ItemProperty -Path "Registry::$($LibraryFolder)" -Name "HideIfEnabled" -ea 0
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
SetValue -RegPath "HKCR\CLSID\{088e3905-0323-4b02-9826-5d99428e115f}" -Name "Infotip" -Value "@occache.dll,-1070" # Downloads
SetValue -RegPath "HKCR\CLSID\{d3162b92-9365-467a-956b-92703aca08af}" -Name "Infotip" -Value "@shell32.dll,-22914" # MyDocuents
# Context menu icon - revert to standard library
CreateFileAssociation "CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -ShellOperations "restorelibraries" -Icon "shell32.dll,-16803" -Extended 1
Remove-ItemPeoperty -Path "Registry::HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" -Name "SeparatorBefore" -ea 0
Remove-ItemPeoperty -Path "Registry::HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" -Name "SeparatorAfter" -ea 0
# Remove most folders from desktop
foreach($Arch in @("","\WOW6432Node")) { # 32-bit and 64-bit registry
    foreach($DesktopFolderNamespace in (Get-ChildItem "Registry::HKLM\SOFTWARE$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace_*")) {
        Remove-Item $DesktopFolderNamespace -Force
    }
    # Recover some folders to desktop - favorites, quick access, userprofile folder 
    foreach($DesktopFolderNamespaceRec in @("{f874310e-b6b7-47dc-bc84-b9e6b38f5903}","{679f85cb-0220-4080-b29b-5540cc05aab6}","{59031a47-3f72-44a7-89c5-5595fe6b30ee}")) # f874310e...: Start; 679f85cb...: Quick access; 59031a47...: Userprofile
    {
        CreateKey "HKLM\SOFTWARE$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$($DesktopFolderNamespaceRec)"
    }
    # ------ Remove unwanted desktop icons in HKLM ------
    foreach ($DesktopIconsToRemove in @(`
        "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}",` # WSL
        "{645FF040-5081-101B-9F08-00AA002F954E}",` # Recycle bin
        "{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"` # Control Panel
    ))  {
        Remove-Item "Registry::HKLM\Software$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$($DesktopIconsToRemove)" -Force -ea 0
    }
}
SetValue -RegPath "HKCR\CLSID\{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Name "Infotip" -Value "@shell32.dll,-30372"
SetValue -RegPath "HKCR\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" -Name "Infotip" -Value "@propsys.dll,-42249"
# Pin Userprofile to tree
New-ItemProperty -Path "Registry::HKCR\CLSID\{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Name "System.IsPinnedToNameSpaceTree" -Value 1 -PropertyType "4"
# Change Quick Access icon
CreateFileAssociation @("CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}","CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}") -DefaultIcon "shell32.dll,-51380" -ShellOperations "pintohome" -Icon "shell32.dll,-322" -TypeName "@propsys.dll,-42249"
# Change desktop icon
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon" -StandardValue "DDORes.dll,-2068" # My PC
if([System.Environment]::OSVersion.Version.Build -ge 22000) { # Windows 11
    [string]$UserFolderIcon="Shell32.dll,-279" # User profile
}
else {
    [string]$UserFolderIcon="imageres.dll,-123"
}
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon" -StandardValue $UserFolderIcon
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon" -StandardValue "imageres.dll,-120" # Network places
# --------------OneDrive---------------
# Change OneDrive (private) and OneDrive (business) icon and name
[object[]]$OneDriveEntries=(Get-ChildItem "Registry::HKCU\Software\Microsoft\OneDrive\Accounts\" | `
    Where-object { ($_ | Get-ItemProperty).UserEmail -like "*@*" }) # Only entries with proper E-Mail addresses are considered.
foreach($OneDriveEntry in $OneDriveEntries) {
    [string]$OneDriveCLSID=(Get-ItemProperty "Registry::$($OneDriveEntry.Name)").NamespaceRootId
    [string]$OneDriveFolderLoc=(Get-ItemProperty "Registry::$($OneDriveEntry.Name)").UserFolder
    if($OneDriveEntry.Name -like "*Personal") {
        [string]$OneDriveIcon="imageres.dll,-1040" # "imageres.dll,-1040" # 1306 is my suitcase
    }
    elseif($OneDriveEntry.Name -like "*Business*") {
        [string]$OneDriveIcon="`"$($OneDriveInstallLoc)`",-589"
    }
    if([System.Environment]::OSVersion.Version.Build -ge 26100) { # Latest version of OneDrive supported. Otherweise let OneDrive app manage the CLSID entry
        MkDirCLSID $OneDriveCLSID -Name "OneDrive" -Icon "$($OneDriveIcon)" -FolderType 9 -TargetPath "$($OneDriveFolderLoc)" -FolderValueFlags 0x28 # 0x30
    }
    else {
        Mkdirclsid $Onedriveclsid -RemoveCLSID
        MkDirCLSID $Onedriveclsid -Name "OneDrive" -Icon "$($OnedriveIcon)" -FolderType 9 -IsShortcut -FolderValueFlags 0x28
        CreateFileAssociation "CLSID\$($OneDriveCLSID)" -defaulticon "imageres.dll,-1040" -shelloperations "Open" -icon "$($OneDriveIcon)" -Command "explorer.exe `"$($OneDriveFolderLoc)`""
        CreateKey "HKCR\CLSID\$($OneDriveCLSID)" -StandardValue "OneDrive"
    }
    if($OneDriveEntry.Name -like "*Personal*") {
        MakeReadOnly "HKCU\Software\Classes\CLSID\$($OneDriveCLSID)" # -InclAdmin
        CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSID)"
        MakeReadOnly "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSID)"
    }
}
# ________________
# Hide unwanted drive letters
[string[]]$DriveLetters=(Get-PSDrive -PSProvider FileSystem).Name
[int]$HiddenDrives=0
if($DriveLetters -contains "A") { # Google Drive
    $HiddenDrives=$HiddenDrives+1
}
if(($DriveLetters -contains "P") -and ((Get-Volume P).FileSystemLabel -like "pcloud*")) { # Check the drive label extra to see if it's actually pCloud drive
    # PCloud installed
    $HiddenDrives=$HiddenDrives+[math]::pow(2,15) # P is the 16th letter in Latin alphabet. begin with A  2^0=1, P will be 2^15. The equvilant in Python is 2 ** 15
    MkDirCLSID "{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Name "pCloud" -FolderType 9 -TargetPath "P:\" -Icon "`"C:\Program Files\pCloud Drive\pcloud.exe`",0"
}
else {
    Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -Recurse -ea 0
    Remove-Item -Path "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -Recurse -ea 0
}
SetValue "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDrives" -Type 4 -Value $HiddenDrives
ModifyMusicLibraryNamespace # Modify music library namespace
# Remove "3D objects" and "Desktop" from Windows Explorer namespace
foreach($UselessNamespace in @("{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}","{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}")) {
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($UselessNamespace)" -ea 0
}
# Add Recent Items to folders
SetValue "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}" -Name "System.IsPinnedToNameSpaceTree" -Type 4 -Value 0
SetValue "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}" -Name "DescriptionID" -Type 4 -Value 3
CreateKey "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}\DefaultIcon" -StandardValue "shell32.dll,-37219"
CreateKey "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{22877a6d-37a1-461a-91b0-dbda5aaebc99}"
# ----- Folder Options ------
Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\HideFileExt" -Name "DefaultValue" -Value 0 # Show file extensions
Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\ShowCompColor" -Name "DefaultValue" -Value 1 # Show compressed / encrypted files in blue/green
foreach($HiddenOption in @("NOHIDDEN","SHOWALL")) {
    Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\$($HiddenOption)" -Name "DefaultValue" -Value 1 # Show hidden files
}
# ------ Remove all later-added desktop icons in HKCU ------
Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\*" -Force -ea 0
MakeReadOnly "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
# Set Auto Cleanup
[string[]]$VolCaches=(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\").Name
foreach($TempFileCleanup in $VolCaches) {
    if(($TempFileCleanup -like "*Downloads*") -or ($TempFileCleanup -like "*Recycle Bin")) {
        Remove-ItemProperty -LiteralPath "Registry::$($TempFileCleanup)" -Name "StateFlags0001" -ea 0
    }
    else {
        SetValue -RegPath "$($TempFileCleanup)" -Name "StateFlags0001" -Type "dword" -Value 2
    }
}
# ————————KEYBOARD TWEAKS—————————
# Use SpeedCrunch as calculator
[string]$SpeedCrunchPath="C:\Program Files (x86)\SpeedCrunch\speedcrunch.exe"
if(Test-Path "$($SpeedCrunchPath)") {
    CreateFileAssociation "ms-calculator" -ShellOperations "open" -Icon "`"$($SpeedCrunchPath)`"" -Command "`"$($SpeedCrunchPath)`""
}
# Replace Microsoft People with Google Contacts
CreateFileAssociation "ms-people" -ShellOperations "open" -Command "$($BrowserOpenAction.Replace(" %1"," contacts.google.com"))"
# Use Google chrome to open mailto link
CreateFileAssociation "Protocols\Handler\mailto" -ShellOperations "open" -Command "$($BrowserOpenAction)"
# Use QWERTZ German keyboard layout for Chinese IME
[string]$CurrentKeyboardLayout=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804")."Layout File"
if($CurrentKeyboardLayout -notlike "KBDGR.DLL") {
    SetValue "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804" -Name "Layout File" -Value "KBDGR.DLL"
    BallonNotif "Computer needs to be restarted to let keyboard layout change (EN->DE) take effect"
}
# --------Dragon Age Toolset--------
if($DAToolSetInstalled) {
    if(Test-Path $DAToolSetD) {
        [string]$DAToolSetL=$DAToolSetD
    }
    elseif(Test-Path $DAToolSetC) {
        [string]$DAToolSetL=$DAToolSetC
    }
    CreateFileAssociation "DAToolSetFile" `
        -FileAssoList @("arl","cif","das","are","dlb","dlg","erf","gda","rim","uti","cut","cub","mor","mao","mop","mmh","msh") `
        -DefaultIcon "`"$($DAToolSetL)`",0" `
        -shelloperations "open" `
        -ShellOpDisplayName "Mit Dragon Age Toolset ansehen und bearbeiten" `
        -Icon "`"$($DAToolSetL)`",0" `
        -Command "wscript.exe `"$($DAToolSetL.replace(".exe",".vbe"))`" `"%1`""
    if($JREInstalled) {
        CreateFileAssociation "UTCFile" -FileAssoList "utc" -DefaultIcon "javaw.exe,0" -ShellOperations "run" -ShellDefault "run" -Command "javaw.exe -jar `"$($DAToolSetL.replace("\Tools\DragonAgeToolset.exe","\TlkEdit-R13d\tlkedit.jar"))`" `"%1`""
    }
    Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "PerceivedType" -ea 0
    Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "Content Type" -ea 0
}
# ------ System PATH Environment -----
[string]$SysEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").Path
[string]$UsrEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_CURRENT_USER\Environment").Path
[string[]]$PathsToBeAdded=@()
if(Test-Path variable:PythonScriptsLoc) {
    $PathsToBeAdded=$PathsToBeAdded+@($PythonScriptsLoc)
}
foreach($PathAdd in $PathsToBeAdded) {
    if($PathAdd -like "$($env:Userprofile)*") { # PATH in user folder
        if($UsrEnv -Notlike "*$($PathAdd)*") {
            Write-Host "Adding `"$($PathAdd)`" to user PATH"
            $UsrEnv="$($UsrEnv);$($PathAdd)"
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Environment" -Name "Path" -Value "$($UsrEnv)"
        }
    }
    else {
        if($SysEnv -Notlike "*$($PathAdd)*") {
            Write-Host "Adding `"$($PathAdd)`" to system PATH"
            $SysEnv="$($SysEnv);$($PathAdd)"
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "Path" -Value "$($SysEnv)"
        }
    }
}
# Require pressing Ctrl+Alt+Del to login
SetValue "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" -Name "DisableCAD" -Type "4" -Value 0
# On Windows 10 2019 LTSC: disable fast boot, because otherwise Windows will BSOD on new laptops.
if([System.Environment]::OSVersion.Version.Build -lt 19041) {
    SetValue "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "Hiberbootenabled" -Type "4" -Value 0
}
# Show seconds in clock for Windows 10
if([System.Environment]::OSVersion.Version.Build -lt 20000) {
    SetValue "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowSecondsInSystemClock" -Type "4" -Value 1
}
# update storage information
UpdateStorageInfo 
# Use dark mode
SetValue "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Type "4" -Value 0