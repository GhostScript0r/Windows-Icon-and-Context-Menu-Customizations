param(
    [switch]$RemoveCommonStartFolder,
    [switch]$UWPRefreshOnly,
    [switch]$Win32GoogleRefreshOnly
)
# Get admin privilege
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
[bool]$ScriptIsRunningOnAdmin=($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
if(!($ScriptIsRunningOnAdmin)) {
	Write-Host "The script $($PSCommandPath.Name) is NOT running with Admin privilege." -ForegroundColor Red -BackgroundColor White
    [string]$ScriptWithArgs="`"$($PSCommandPath)`""
    foreach($Argument in @("RemoveCommonStartFolder","UWPRefreshOnly","Win32GoogleRefreshOnly")) {
        if((Get-Variable "$($Argument)").value -eq $true) {
            $ScriptWithArgs=$ScriptWithArgs + " -$($Argument) "
        }
    }
    Start-Process powershell.exe -ArgumentList "-File $($ScriptWithArgs)" -verb runas
	exit
}
Write-Host "This script is inteneded to write in the usual registry stuff after Windows OOBE or in-place upgrade" -BackgroundColor White -ForegroundColor Blue
# Call functions
$PSFunctions=(Get-ChildItem "$($PSScriptRoot)\Functions\*.ps1")
foreach($Function in $PSFunctions) {
    . "$($Function.FullName)"
}
function FixUWPCommand {
    [string]$UWPCommand="$($args[0])"
    # if($args[0] -like "*Ubuntu*") {
    #     $UWPCommand="C:\Windows\System32\wsl.exe $($UWPCommand) && sleep 0.8"
    # }
    # elseif($args[0] -like "*mspaint*") {
    #     $UWPCommand="cmd.exe /min /c start $($UWPCommand) && exit"
    # }
    return $UWPCommand
}
function RefreshGoogleDriveIcons {
    [object[]]$GoogleDriveApps=(Get-ChildItem "C:\Program Files\Google\Drive File Stream\*\GoogleDriveFS.exe" -recurse)
    if($GoogleDriveApps.count -eq 0) {
        Write-Host "Google Drive FS not yet installed." -ForegroundColor Red
        Remove-Item "Registry::HKCR\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}"
    }
    else {
        [string]$GDriveLoc=$GoogleDriveApps[$GoogleDriveApps.count-1].FullName
        CreateFileAssociation "CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -DefaultIcon "`"$($GDriveLoc)`",-61"
        foreach($GDocExt in @(".gdoc",".gsheet",".gslides")) {
            Remove-Item "Registry::HKCR\$($GDocExt)\ShellNew" -ErrorAction SilentlyContinue
        }
        foreach($GDoc in (Get-ChildItem "Registry::HKCR\GoogleDriveFS.*").Name) {
            [string]$GDocIcon=(Get-ItemProperty -LiteralPath "Registry::$($GDoc)\DefaultIcon").'(default)'
            CreateFileAssociation "$($GDoc)" -ShellOperations "open" -Icon "$($GDocIcon)"
        }
    }
}
# ————————————————————————
# Main part of the script. At the beginning are the parts needed to be regularly run.
# -----------
# Update the name of other drives shown in Windows Explorer to get drive size infos
# —————————————————————
# Refresh Box Drive if updated
[string]$BoxInstallLoc="C:\Program Files\Box\Box\Box.exe"
[string[]]$BoxDriveCLSIDs=@("HKCR\CLSID\{345B91D6-935F-4773-9926-210C335241F9}","HKCR\CLSID\{F178C11B-B6C5-4D71-B528-64381D2024FC}") #((Get-ChildItem "Registry::HKCR\CLSID" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)").'(default)' -like "Box*"} ))
if(Test-Path "$($BoxInstallLoc)") {
    foreach($BoxDriveCLSID in $BoxDriveCLSIDs) {
        foreach($RegRoot in @("HKCR","HKLM")) {
            Remove-Item "Registry::$($RegRoot)\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\Namespace\$(Split-Path $BoxDriveCLSID -leaf)" -Force -ErrorAction SilentlyContinue
        }
        # CreateKey "$($BoxDriveCLSID)" -StandardValue "Box"
        if((Get-ItemProperty -LiteralPath "Registry::$($BoxDriveCLSID)\DefaultIcon").'default' -like "`"$($BoxInstallLoc)`"") {
            # Box drive not updated, no need to update icon.
            break
        }
        SetValue "$($BoxDriveCLSID)" -Name "DescriptionID" -Type "4" -Value 9
        Set-ItemProperty -Path "Registry::$($BoxDriveCLSID)\DefaultIcon" -Name '(Default)' -Value "`"$($BoxInstallLoc)`""
        if(Test-Path "Registry::$($BoxDriveCLSID)\Instance") { # Box Drive Entry without online status overlay. Looks like traditional folder
            Set-ItemProperty -Path "Registry::$($BoxDriveCLSID)" -Name "System.IsPinnedToNameSpaceTree" -Value 0
        }
        else { # Box Drive Entry with online status overlay - Add to explorer
            CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\$(Split-Path $BoxDriveCLSID -leaf)"
        }
        # Remove Box Drive Entry from desktop
        Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\$(Split-Path $BoxDriveCLSID -leaf)" -Force -ErrorAction SilentlyContinue
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
        Remove-Item "Registry::$($BoxDriveCLSID)" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\$(Split-Path $BoxDriveCLSID -leaf)" -Force -Recurse -ErrorAction SilentlyContinue
    }
}

# Remove-Item "Registry::HKCR\Directory\Background\shellex\ContextMenuHandlers\ACE" -Force -ErrorAction SilentlyContinue
# Remove-Item "Registry::HKCR\Directory\Background\shellex\ContextMenuHandlers\DropboxExt" -Force -ErrorAction SilentlyContinue
# Change Box Entry
if((Test-Path "$($env:USERPROFILE)\old_Box") -or ((Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders").'{A0C69A99-21C8-4671-8703-7934162FCF1D}' -notlike "*\Box\Music")) {
    ModifyMusicLibraryNamespace
    Remove-Item "$($env:USERPROFILE)\old_Box" -Force -Recurse -ErrorAction SilentlyContinue
}
if($UWPRefreshOnly) {
    UpdateStorageInfo
    exit
}

# The 5-minute UWP refresh script ends at the place above. 
# #######################################################
# Here starts the script that will only be run manually or when a system version update is done.
# > Find file location of paint app and copy it out
[string]$PaintAppLocation="$($(Get-AppxPackage Microsoft.Paint).InstallLocation)\PaintApp\mspaint.exe"
[string]$PaintIconLocation="$($env:LocalAppdata)\Packages\Microsoft.Paint_8wekyb3d8bbwe\mspaint.exe"
if(!(Test-Path "$($PaintIconLocation)")) {
    Copy-Item -Path "$($PaintAppLocation)" -Destination "$(Split-Path $PaintIconLocation)"
}
[string]$PaintAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_.Name)\Application" -ErrorAction SilentlyContinue).ApplicationName -like "*Microsoft.Paint*"})[0]
# > Find file location of Windows Terminal app and copy the profile icons out
[string]$WTLocation="$($(Get-AppxPackage Microsoft.WindowsTerminal).InstallLocation)"
[string]$PowerShellIconPNG="$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\ProfileIcons\{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.scale-200.png"
[string]$TerminalIconICO="$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\terminal_contrast-white.ico"
if(!(Test-Path "$($PowerShellIconPNG)")) {
    Copy-Item -Path "$($WTLocation)\ProfileIcons" -Destination "$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe" -Recurse
}
if(!(Test-Path "$($TerminalIconICO)")) {
    Copy-Item -Path "$($WTLocation)\Images\terminal_contrast-white.ico" -Destination "$($env:LocalAppdata)\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe"
}
# > Find file location of WSL app and copy it
[string]$WSLLocation="$((Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForLinux).InstallLocation)\wsl.exe"
[string]$WSLIconLocation="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_8wekyb3d8bbwe\wsl.exe"
[string]$WSLIconPNG="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_8wekyb3d8bbwe\Square44x44Logo.altform-lightunplated_targetsize-48.png"
if(!(Test-Path "$($WSLIconLocation)")) {
    Copy-Item -Path "$($WSLLocation)" -Destination "$(Split-Path $WSLIconLocation)"
}
if(!(Test-Path "$($WSLIconPNG)")) {
    Copy-Item -Path "$(Split-Path $WSLLocation)\Images\$(Split-Path $WSLIconPNG -Leaf)" -Destination "$(Split-Path $WSLIconPNG)"
}
# > Find file location of WMP UWP
[bool]$WMPUWPInstalled=((Get-AppxPackage *ZuneMusic*).count -gt 0)
# > Find file location of Python
[string[]]$PythonVerInstalled=(Get-AppxPackage "*.Python.*").Name
if($PythonVerInstalled.Count -gt 0) { # If Python app is installed
    [string]$PythonInstallLoc="$((Get-AppxPackage "$($PythonVerInstalled)").InstallLocation)\python.exe"
    [string]$PythonFileHKCR="HKCR\py_auto_file" #(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)" -ErrorAction SilentlyContinue).'(default)' -like "Python File*"})[0] # Includes HKCR\ prefix
}
else { # Python app not installed, probably in WSL?
    Remove-Item "Registry::HKCR\py_auto_file" -Force -ErrorAction SilentlyContinue
}
# > Find file location of WSA
foreach($Icon in @("LatteLogo.png","app.ico")) {
    [string]$WSALocation="$((Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForAndroid).InstallLocation)\Assets\$($Icon)"
    [string]$WSAIconLocation="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\$($Icon)"
    if((Test-Path "$($WSALocation)") -and (!(Test-Path "$($WSAIconLocation)"))) {
        Copy-Item "$($WSALocation)" "$(Split-Path -Path $WSAIconLocation)"
    }
}
if(Test-Path "$($WSALocation)") {
    MkDirCLSID "{a373e8cc-3516-47ac-bf2c-2ddf8cd06a4c}" -Name "Android" -Icon "`"$($WSAIconLocation)`"" -FolderType 6 -IsShortcut
    [string]$StartWSAAppCommandPrefix="$($env:Localappdata)\Microsoft\WindowsApps\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\WsaClient.exe /launch wsa://"
    [string[]]$WSAContextMenu=@("open","cmd")
    [string[]]$WSAContextMenuIcon=@("`"$($WSAIconLocation)`"","$($TerminalIconICO)")
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
    CreateFileAssociation "CLSID\{a373e8cc-3516-47ac-bf2c-2ddf8cd06a4c}" -ShellOperations $WSAContextMenu -ShellOpDisplayName $WSAContextMenuName -Icon $WSAContextMenuIcon -Command $WSAContextMenuCommand

}
# > Remove PowerRename
# if((Get-AppxPackage Microsoft.PowerToys.PowerRenameContextMenu).count -gt 0) {
#     Remove-Item "Registry::HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\PowerRenameEx" -Force -ErrorAction SilentlyContinue
# }
# Use system time as UTC
SetValue "HKLM\SYSTEM\ControlSet001\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type 4 -Value 1
# NVidia Shadow Play - hide mouse button
$nVidiaShadowPlayReg=@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS]
"{079461D0-727E-4C86-A84A-CBF9A0D2E5EE}"=hex:01,00,00,00
'@
ImportReg $nVidiaShadowPlayReg
# Check if MS Office is installed
[bool]$MSOfficeInstalled=$false
foreach($ProgramFilesLoc in @("Program Files","Programe Files (x86)")) {
    [string]$MSOfficeLoc="C:\$($ProgramFilesLoc)\Microsoft Office\root\Office16\Word.exe" # Need to check to differentiate from when only Microsoft OneDrive is installed
    if(Test-Path "$($MSOfficeLoc)") {
        $MSOfficeInstalled=$true
        break
    }
}
# Check if LibreOffice is installed
[bool]$LibreOfficeInstalled=$false
if(Test-Path "C:\Program Files\LibreOffice\program\soffice.exe") { 
    $LibreOfficeInstalled=$true
}
# -------Get privileges to take ownership-------
Write-Host "Preparing to take ownership of keys owned by SYSTEM or TrustedInstaller"
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
[bool]$WMPLegacyInstalled=((Get-ItemProperty -Path "Registry::HKLM\Software\Microsoft\Active Setup\Installed Components\{22d6f312-b0f6-11d0-94ab-0080c74c7e95}" -ErrorAction SilentlyContinue).isinstalled -eq 1)
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
    if((Test-Path "Registry::$($LockedKey)") -and ((Get-Acl "Registry::$($LockedKey)" -ErrorAction SilentlyContinue).Owner -NotLike "$($env:UserDomain)\$($env:Username)")) {
        TakeRegOwnership "$($LockedKey)" | Out-Null
    }
}
# ------- Check if Google Chrome is installed ---------
[string]$ChromePath="C:\Program Files\Google\Chrome\Application\chrome.exe"
[bool]$ChromeInstalled=(Test-Path "$($ChromePath)")
if($ChromeInstalled) {
    [string]$BrowserOpenAction="`"$($ChromePath)`" %1"
    [string]$BrowserIcon="`"$($ChromePath)`",0"
}
else { # Microsoft Edge Installed
    [string]$BrowserOpenAction="`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`" --single-argument %1"
    [string]$BrowserIcon="ieframe.dll,-31065"
}
# ————————KEYBOARD TWEAKS—————————
# Use SpeedCrunch as calculator
[string]$SpeedCrunchPath="C:\Program Files (x86)\SpeedCrunch\speedcrunch.exe"
if(Test-Path "$($SpeedCrunchPath)") {
    CreateFileAssociation "ms-calculator" -ShellOperations "open" -Icon "`"$($SpeedCrunchPath)`"" -Command "`"$($SpeedCrunchPath)`""
}
# Replace Microsoft People with Google Contacts
CreateFileAssociation "ms-people" -ShellOperations "open" -Command "$($BrowserOpenAction.Replace(" %1"," contacts.google.com"))"
# Use QWERTZ German keyboard layout for Chinese IME
[string]$CurrentKeyboardLayout=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804")."Layout File"
if($CurrentKeyboardLayout -notlike "KBDGR.DLL") {
    SetValue "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804" -Name "Layout File" -Value "KBDGR.DLL"
    BallonNotif "Computer needs to be restarted to let keyboard layout change (EN->DE) take effect"
}
# ————————FILE ASSOCIATIONS—————————
# --------Any file---------
# ! Cannot use SetValue function, as the path contains wildcard character *. Must use -LiteralPath
New-ItemProperty -LiteralPath "Registry::HKCR\*\shell\pintohomefile" -Name "Icon" -PropertyType "string" -Value "shell32.dll,-322" -ErrorAction SilentlyContinue
if(!($?)) { 
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\pintohomefile" -Name "Icon" -Value "shell32.dll,-322" -ErrorAction SilentlyContinue
}
# --------Java files--------
[bool]$JREInstalled=((Get-Command javaw -ErrorAction SilentlyContinue).name -like "javaw.exe")
if($JREInstalled) {
    CreateFileAssociation "jarfile" -ShellOperations "open" -MUIVerb "@shell32.dll,-12710" -Icon "javaw.exe"
}
# --------Dragon Age Toolset--------
[string]$DAToolSetD="D:\Spiele\Dragon Age Origins\Tools\DragonAgeToolset.exe"
[string]$DAToolSetC="$($env:USERPROFILE)\Spiele\Dragon Age Origins\Tools\DragonAgeToolset.exe"
[bool]$DAToolSetInstalled=((Test-Path $DAToolSetD) -or (Test-Path $DAToolSetC))
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
    Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "PerceivedType" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "Content Type" -ErrorAction SilentlyContinue
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
if($ZipAppInstalled -like "*PeaZip*") {
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2browseasarchive; PeaZip.add2separate; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name 'Icon' -Value "C:\Program files\Peazip\peazip.exe"
    <# PeaZip Commands include:
    PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2smart; PeaZip.ext2folder; PeaZip.ext2test; PeaZip.ext2browseasarchive; PeaZip.ext2browsepath; PeaZip.add2separate; PeaZip.add2separatesingle; PeaZip.add2separatesfx; PeaZip.add2separate7z; PeaZip.add2separate7zfastest; PeaZip.add2separate7zultra; PeaZip.add2separatezip; PeaZip.add2separatezipfastest; PeaZip.add2separate7zencrypt; PeaZip.add2separatezipmail; PeaZip.add2split; PeaZip.add2convert; PeaZip.analyze; PeaZip.add2wipe; 
    #>
    [string[]]$PeaZipHKCR=(Get-ChildItem Registry::HKCR\PeaZip.*).Name # Include HKCR\ prefix
    CreateFileAssociation $($PeaZipHKCR+@("Applications\PEAZIP.exe")) -DefaultIcon "imageres.dll,-174" -ShellOperations "open" -ShellOpDisplayName "Mit PeaZip browsen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
    CreateFileAssociation "CompressedFolder" -DefaultIcon "imageres.dll,-174" -ShellOperations "open2" -ShellOpDisplayName "Mit PeaZip browsen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
    CreateFileAssociation @("Directory\Background","LibraryFolder\background") -ShellOperations @("Browse path with PeaZip","ZPeaZip") -ShellOpDisplayName @("","Hier PeaZip starten") -Icon @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`",0") -Command @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"-ext2browsepath`" `"%V`"") -LegacyDisable @(1,0)
    foreach($Key in $PeaZipHKCR) {
        Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::$($Key)\shell" -Force
        CreateFileAssociation "$($Key)" -ShellOperations "PeaZip" -Icon "zipfldr.dll,-101" -MUIVerb "@zipfldr.dll,-10148"
        SetValue "$($Key)\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2folder; PeaZip.add2split; PeaZip.add2convert; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
        Remove-Item -Path "Registry::$($Key)\shell\PeaZipCompressedFolder" -Force -Recurse -ErrorAction SilentlyContinue
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
elseif($ZipAppInstalled -like "*7-Zip*") {
    CreateFileAssociation @("CompressedArchive","Applications\7zFM.exe") `
    -FileAssoList $ZipFileAssoExt `
    -DefaultIcon "imageres.dll,-174" `
    -ShellOperations "open" `
    -ShellOpDisplayName "Mit 7-Zip browsen" `
    -Icon "`"C:\Program Files\7-Zip\7zFM.exe`",0" `
    -Command "`"C:\Program Files\7-Zip\7zFM.exe`" `"%1`""
}
# --------Windows Update package (MSU)--------
CreateFileAssociation "Microsoft.System.Update.1" `
    -ShellOperations "open" `
    -Icon "wusa.exe,-101" `
    -MUIVerb "@ActionCenter.dll,-2107"
# ---------Windows folders--------
CreateFileAssociation "Folder" `
    -ShellOperations @("open","opennewwindow","opennewtab","opennewprocess","pintohome") `
    -Icon @("main.cpl,-606","imageres.dll,-5322","imageres.dll,-116","","shell32.dll,-322") `
    -LegacyDisable @(0,0,0,1,0) `
    -MUIVerb @("@shell32.dll,-32960","","","","") `
    -TypeName "@shell32.dll,-9338"
# ---------Hard drives--------
CreateFileAssociation "Drive" `
    -ShellOperations @("manage-bde","encrypt-bde","encrypt-bde-elev","pintohome") `
    -Icon @("shell32.dll,-194","shell32.dll,-194","shell32.dll,-194","shell32.dll,-322")
# Check if VS Code is installed systemwide or for current user only
[string[]]$VSCodeVersion=@("Microsoft VS Code\code.exe","Microsoft VS Code Insiders\Code - Insiders.exe")
for ($i=0;$i -lt $VScodeVersion.count;$i++) {
    [string]$VSCodeLocation=(CheckInstallPath "$($VSCodeVersion[$i])")
    if($VSCodeLocation.length -gt 0) {
        break
    }
}
[string]$VSCodeIconsLoc="$(Split-Path "$($VSCodeLocation)" -Parent)\resources\app\resources\win32"
[string]$VSCodeVerHKCR="VSCode"
if($VSCodeLocation -like "*Insiders*") {
    [string]$VSCodeVerHKCR="VSCodeInsiders"
}
# --------Directories--------
[string[]]$PowerShellDef=@("","powershell.exe,0") # [0]: Display Name; [1]: Icon file
# Hide "Open in terminal" entry to unify how the menu looks.
SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
    -Name "{9F156763-7844-4DC4-B2B1-901F640F5155}" -EmptyValue $true # Terminal
SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
    -Name "{02DB545A-3E20-46DE-83A5-1329B1E88B6B}" -EmptyValue $true # Terminal preview
CreateFileAssociation @("Directory\Background","Directory","LibraryFolder\background") `
    -ShellOperations @("cmd","VSCodeNoAdmin","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") `
    -ShellOpDisplayName @("","Hier VS Code starten","Hier VS Code starten (Administrator)","","","","$($PowerShellDef[0])","") `
    -Icon @("cmd.exe,0","`"$($VSCodeLocation)`",0","`"$($VSCodeLocation)`",0","`"C:\Program Files\Git\git-bash.exe`",0",`
        "`"C:\Program Files\Git\git-bash.exe`",0","$($PowerShellDef[1])","$($PowerShellDef[1])","`"$($WSLIconLocation)`",0") `
    -Extended @(0,0,0,1,1,0,0,0) `
    -LegacyDisable @(1,0,0,0,0,0,0,0) `
    -HasLUAShield @(0,0,1,0,0,0,1,0) `
    -MUIVerb @("","","","","","","@twinui.pcshell.dll,-10929","@wsl.exe,-2") `
    -Command @($(FixUWPCommand "wt.exe -d `"%V `" -p `"Eingabeaufforderung`"" 0),`
        "`"$($VSCodeLocation)`" `"%v `"",`
        "PowerShell -windowstyle hidden -Command `"Start-Process '$($VSCodeLocation)' -ArgumentList '-d `"`"%V`"`"`"' -Verb RunAs`"",`
        $(FixUWPCommand "wt.exe new-tab --title Git-Bash --tabColor #300a16 --suppressApplicationTitle `"C:\Program Files\Git\bin\bash.exe`"" 0),`
        "",` # git-gui no need to define
        $(FixUWPCommand "wt.exe  -d `"%V `" -p `"PowerShell`"" 0),`
        "PowerShell -windowstyle hidden -Command `"Start-Process wt.exe -ArgumentList '-d `"`"%V `"`"`"' -Verb RunAs`"",$(FixUWPCommand "wt.exe -d `"%V `" -p `"Ubuntu`"" 0))
Remove-Item -Path "Registry::HKCR\Directory\Background\DefaultIcon" -ErrorAction SilentlyContinue # Not needed
# Admin commands don't work in Library Folders, so disable them in Libraries
CreateFileAssociation "LibraryFolder\background" -ShellOperations @("VSCodeWithAdmin","PowerShellWithAdmin") -LegacyDisable @(1,1) 
foreach($GitContextMenu in @("git_shell","git_bash"))
{
    MakeReadOnly "HKCR\Directory\Background\shell\$($GitContextMenu)" -InclAdmin
}
# Show above mentioned entries only on directory background, NOT when clicking a folder
CreateFileAssociation "Directory" -ShellOperations @("cmd","VSCodeNoAdmin","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") -Extended @(1,1,1,1,1,1,1,1) -LegacyDisable @(1,1,1,1,1,1,1,1)
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
    else {
        [string]$PhotoViewerCap="PhotoViewer.FileAssoc.Tiff"
        SetValue -RegPath "HKCR\$($ImageExt)" -Name "PerceivedType" -Value "image"
    }
    SetValue -RegPath "Registry::HKLM\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" -Type "string" -Name $ImageExt -Value "$($PhotoViewerCap)"
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
        [string]$VLCFileType=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($VLCExtension)" -ErrorAction SilentlyContinue).'PerceivedType'
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
        if((Get-ItemProperty -LiteralPath "Registry::$($Key)\shell\play" -ErrorAction SilentlyContinue)."Icon" -like "imageres.dll,-5201") {
            break
        }
        CreateFileAssociation $Key -ShellOperations @("Enqueue","play") `
            -Icon @("wlidcli.dll,-1008","imageres.dll,-5201") `
            -MUIVerb @("@shell32.dll,-37427","@shell32.dll,-22072")
    }
}
elseif($MPlayersInstalled[2]) { # WMP UWP installed
    [string]$WMPAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)\Application" -ErrorAction SilentlyContinue).ApplicationName -like "*Microsoft.ZuneMusic*"})[0]
    CreateFileAssociation "$($WMPAppHKCR)" -ShellOperations @("open","enqueue","play") -ShellDefault "play" -LegacyDisable @(1,0,0) -Icon @("","shell32.dll,-16752","imageres.dll,-5201") -DefaultIcon "imageres.dll,-134" -MUIVerb @("","@shell32.dll,-37427","")
}
# -----------Text files, VS Code related--------------
# ------- All VSCode files ------
[string[]]$VSCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "$($VSCodeVerHKCR).*"})
foreach($Key in $VSCHKCR) {
    if((Get-ItemProperty "Registry::HKCR\$($Key)\shell\open\command" -ErrorAction SilentlyContinue).'(default)' -like "*$($VSCodeLocation)*") {
        CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "`"$($VSCodeLocation)`",0" -MUIVerb "@shell32.dll,-37398" -Extended 0
    }
    else {
        # Do nothing for VS Code files without "command" subkey. Those are probably defined somewhere else.
    }
}
CreateKey "HKCR\$($VSCodeVerHKCR).txt\DefaultIcon" -StandardValue "imageres.dll,-19"
foreach($VSCodeAppHKCR in @("Code.exe","Code - Insiders.exe")) {
    if(Test-Path "Registry::HKCR\Applications\$($VSCodeAppHKCR)") {
        CreateFileAssociation "Applications\$($VSCodeAppHKCR)" -ShellOperations "open" -Icon "`"$($VSCodeLocation)`",0" -MUIVerb "@certmgr.dll,-291"
    }
}
# Give "Text" property to all VS Code related files
foreach($FileExt in (Get-ChildItem "Registry::HKCR\.*").Name) {
    [string]$ProgID=(Get-ItemProperty -LiteralPath "Registry::$($FileExt)\OpenWithProgIds" -ErrorAction SilentlyContinue) 
    if(($ProgID -like "*$($VSCodeVerHKCR).*") -and (-not (Test-Path "Registry::$($FileExt)\PersistentHandler"))) {
        # Change item type to text. Let Windows Search index the items
        CreateKey "$($FileExt)\PersistentHandler" -StandardValue "{5e941d80-bf96-11cd-b579-08002b30bfeb}"
    }
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
# --------BAT, CMD, COM script-------
CreateFileAssociation @("BATFile","CMDFile","COMFile") -ShellOperations @("open","print","edit","runas") -DefaultIcon "cmd.exe,0" ` # "$($VSCodeIconsLoc)\shell.ico"
-Icon @("cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeLocation)`",0","cmd.exe,0") -MUIVerb @("@shell32.dll,-12710","","","") -Command @("","","`"$($VSCodeLocation)`" `"%1`"","") -Extended @(0,1,0,0) -LegacyDisable @(0,1,0,0)
# --------Registry file--------
CreateFileAssociation "regfile" -ShellOperations @("open","edit","print") `
    -Icon @("regedit.exe,0","`"$($VSCodeLocation)`",0","DDORes.dll,-2413") `
    -Extended @(0,0,1) -ShellDefault "open"`
    -command @("","`"$($VSCodeLocation)`" `"%1`"","")
# ------- Python script -------
if(($PythonVerInstalled.Count -gt 0)) {
    CreateFileAssociation @("$($PythonFileHKCR)") -shelloperations @("open","edit") -Icon @("$($PythonInstallLoc)","`"$($VSCodeLocation)`",0") -Command ("python.exe `"%1`"","`"$($VSCodeLocation)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","")
}
else {
    Remove-Item "Registry::$($PythonFileHKCR)" -Force -Recurse
}
# -------XML Document-------
Remove-ItemProperty -Path "Registry::HKCR\.xml" -Name "PreceivedType" -ErrorAction SilentlyContinue
foreach($ML_Ext in @("xml","htm","html")) {    
    Remove-ItemProperty -Path "Registry::HKCR\.$($ML_Ext)\OpenWithProgids" -Name "MSEdgeHTM" -ErrorAction SilentlyContinue 
}
CreateFileAssociation @("xmlfile","$($VSCodeVerHKCR).xml") -FileAssoList ".xml" -DefaultIcon "msxml3.dll,-128" `
    -ShellOperations @("open","edit") -ShellDefault "edit" `
    -Icon @("ieframe.dll,-31065","`"$($VSCodeLocation)`",0") -MUIVerb @("@ieframe.dll,-21819","")`
    -Command @("`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`" --single-argument %1","`"$($VSCodeLocation)`" `"%1`"") `
    -CommandId @("IE.File","") `
    -DelegateExecute @("{17FE9752-0B5A-4665-84CD-569794602F5C}","")
Remove-Item "Registry::HKCR\xmlfile\ShellEx\IconHandler" -ErrorAction SilentlyContinue
# ------- PS1 Script ------
CreateFileAssociation @("Microsoft.PowerShellScript.1") -FileAssoList @("ps1")  -DefaultIcon "$($VSCodeIconsLoc)\powershell.ico" -ShellOperations @("open","edit","runas") -Icon @("scrptadm.dll,-7","`"$($VSCodeLocation)`",0","C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,1") -MUIVerb @("@`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`",-108","","") -Command @("`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`"  `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`"","`"$($VSCodeLocation)`" `"%1`"","`"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`" `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`" -Verb RunAs")
CreateFileAssociation "SystemFileAssociations\.ps1" -ShellOperations "Windows.PowerShell.Run" -LegacyDisable $true
Remove-Item "Registry::HKCR\Microsoft.PowerShellScript.1\shell\0" -ErrorAction SilentlyContinue
# ------- LOG File ------
SetValue "HKCR\.log" -Name "Content Type" -Value "text/plain"
SetValue "HKCR\.log" -Name "PerceivedType" -Value "text"
# ------- Linux BASH -------
CreateFileAssociation @("bashfile") -FileAssoList @("sh","bash") -ShellOperations @("open","edit") -Icon @("$($WSLIconLocation)","$($VSCodeLocation)") -Command @("wsl.exe bash `$(wslpath `"%1`")","`"$($VSCodeLocation)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","") -DefaultIcon "$($VSCodeIconsLoc)\shell.ico"
# ------- PDF Document -------
CreateFileAssociation "MSEdgePDF" -ShellOperations "open" -Icon "ieframe.dll,-31065" -MUIVerb "@ieframe.dll,-21819"
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
    CreateFileAssociation "MSEdgePDF" -ShellOperations @("open2","print") -Icon @("`"$($SumatraPDFLoc)`",0","ddores.dll,-2414") -ShellOpDisplayName @("Mit SumatraPDF lesen","") -Command @("`"$($SumatraPDFLoc)`" `"%1`"","")
    Copy-Item -Path "Registry::HKCR\$($Key)\shell\open\command" -Destination "Registry::HKCR\MSEdgePDF\shell\open2" -Force
    foreach($PrintAction in @("print","printto")) {
        Copy-Item -Path "Registry::HKCR\$($KeyWithPrint)\shell\$($PrintAction)" -Destination "Registry::HKCR\MSEdgePDF\shell" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
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
    Remove-ItemProperty -Path "Registry::HKCR\InternetShortcut" -Name $PropertyToBeRemoved -ErrorAction SilentlyContinue
}
Remove-Item -Path "Registry::HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}" -Force
CreateFileAssociation "InternetShortcut" -DefaultIcon "url.dll,-5" -ShellOperations @("open","edit","print","printto") -Icon @("$($BrowserIcon)","`"$($VSCodeLocation)`",0","ddores.dll,-2414","ddores.dll,-2413") -MUIVerb @("@synccenter.dll,-6102",,"","","") -LegacyDisable @(0,0,1,1) -Command @("powershell.exe -Command `"`$URL= ((Get-Content '%1') -like 'URL=*') -replace 'URL=',' '; Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -ArgumentList `$URL`"","`"$($VSCodeLocation)`" `"%1`"","","")
# --------Google Chrome HTML (if Chrome installed)--------
if($ChromeInstalled) {
    CreateFileAssociation "ChromeHTML" -DefaultIcon "shell32.dll,-14" `
    -ShellOperations @("open","edit") -MUIVerb @("@ieframe.dll,-10064","") `
    -Icon @("`"$($ChromePath)`",0","`"$($VSCodeLocation)`",0") `
    -Command @("`"$($ChromePath)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"")
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
# When no office program installed: Use microsoft edge.
else {
    # PPT
    CreateFileAssociation "PPTFile" -FileAssoList @(".ppt",".pptx") -DefaultIcon "imageres.dll,-8312" -TypeName "@explorerframe.dll,-50295" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    # WORD
    CreateFileAssociation "DOCFile" -FileAssoList @(".doc",".docx","odt") -DefaultIcon "imageres.dll,-8302" -TypeName "@explorerframe.dll,-50293" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    # EXCEL
    CreateFileAssociation "XLSFile" -FileAssoList @(".xls",".xlsx","xlsm") -DefaultIcon "imageres.dll,-8320" -TypeName "@explorerframe.dll,-50294" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
}
# PFX Certificate
CreateFileAssociation "pfxfile" -ShellOperations @("add","open") -Extended @(0,1) -LegacyDisable @(0,1) `
    -Icon @("certmgr.dll,-6169","certmgr.dll,-6169") -MUIVerb @("@cryptext.dll,-6126","") -ShellDefault "add"
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
Remove-ItemProperty -Path "Registry::HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "HasLUAShield" -ErrorAction SilentlyContinue
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
    Remove-ItemProperty -Path "Registry::$($LibraryFolder)" -Name "HideIfEnabled" -ErrorAction SilentlyContinue
    if(((Get-ItemProperty -LiteralPath "Registry::$($LibraryFolder)").'(default)') -like "CLSID_*RegFolder") {
        Remove-Item -Path "Registry::$($LibraryFolder)" -ErrorAction SilentlyContinue
        New-Item -Path "Registry::$($LibraryFolder)"
    }
}
foreach($LibraryFolder in @("{d3162b92-9365-467a-956b-92703aca08af}","{088e3905-0323-4b02-9826-5d99428e115f}","{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}","{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}","{24ad3ad4-a569-4530-98e1-ab02f9417aa8}")) 
# d3162b...: Dokumente; 088e39...: Downloads; 3dfdf2...: Musik; f86fa3...: Videos; 24ad3a...: Bilder
{
    Rename-ItemProperty -Path "Registry::HKCR\CLSID\$($LibraryFolder)" -Name "System.IsPinnedToNameSpaceTree_Old" -NewName "System.IsPinnedToNameSpaceTree" -ErrorAction SilentlyContinue
    if($LibraryFolder -Notlike "{088e3905-0323-4b02-9826-5d99428e115f}") { 
        # Hide "Music", "Photos", "Videos" and "Documents" because they are also retrievable from library. Keep "Download" only
        SetValue "HKCR\CLSID\$($LibraryFolder)" -Name "System.IsPinnedToNameSpaceTree" -Type "dword" -Value 0 
    }
}
SetValue -RegPath "HKCR\CLSID\{088e3905-0323-4b02-9826-5d99428e115f}" -Name "Infotip" -Value "@occache.dll,-1070"
SetValue -RegPath "HKCR\CLSID\{d3162b92-9365-467a-956b-92703aca08af}" -Name "Infotip" -Value "@shell32.dll,-22914"
# Context menu icon - revert to standard library
CreateFileAssociation "CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -ShellOperations "restorelibraries" -Icon "shell32.dll,-16803" -Extended 1
Remove-ItemPeoperty -Path "Registry::HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" -Name "SeparatorBefore" -ErrorAction SilentlyContinue
Remove-ItemPeoperty -Path "Registry::HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" -Name "SeparatorAfter" -ErrorAction SilentlyContinue
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
        Remove-Item "Registry::HKLM\Software$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$($DesktopIconsToRemove)" -Force -ErrorAction SilentlyContinue
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
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon" -StandardValue "Shell32.dll,-279" # User profile
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon" -StandardValue "imageres.dll,-120" # Network places
# --------------OneDrive---------------
# Change OneDrive (private) and OneDrive (business) icon and name
# if(Test-Path $OneDriveInstallLoc) {
    [object[]]$OneDriveEntries=(Get-ChildItem "Registry::HKCU\Software\Microsoft\OneDrive\Accounts\" | `
        Where-object { ($_ | Get-ItemProperty).UserEmail -like "*@*" }) # Only entries with proper E-Mail addresses are considered.
    foreach($OneDriveEntry in $OneDriveEntries) {
        [string]$OneDriveCLSID=(Get-ItemProperty "Registry::$($OneDriveEntry.Name)").NamespaceRootId
        [string]$OneDriveFolderLoc=(Get-ItemProperty "Registry::$($OneDriveEntry.Name)").UserFolder
        if($OneDriveEntry.Name -like "*Personal") {
            [string]$OneDriveIcon="imageres.dll,-1040"
        }
        elseif($OneDriveEntry.Name -like "*Business*") {
            [string]$OneDriveIcon="imageres.dll,-1306" #"`"$($OneDriveInstallLoc)`",-589"
        }
        MkDirCLSID $OneDriveCLSID -Name "OneDrive" -Icon "$($OneDriveIcon)" -FolderType 9 -TargetPath "$($OneDriveFolderLoc)" -FolderValueFlags 0x30
        if($OneDriveEntry.Name -like "*Personal*") {
            MakeReadOnly "HKCU\Software\Classes\CLSID\$($OneDriveCLSID)" -InclAdmin
            CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSID)"
            MakeReadOnly "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSID)" -InclAdmin
        }
    }
# }
# ——————————————
# DropBox
[string]$DropBoxInstallLoc="C:\Program Files (x86)\Dropbox\Client\Dropbox.exe"
if(Test-Path "$($DropBoxInstallLoc)") { # DropBox CLSID changes each time, for safety use pre-defined CLSID instead
    [string]$DropBoxIcon="`"$($DropBoxInstallLoc)`",-13001"
    MkDirCLSID "{3ac72dca-9dda-4055-9cdb-695154218963}" -Name "Dropbox" -Icon "$($Dropboxicon)" -TargetPath "$($env:Userprofile)\Dropbox" -FolderType 9
}
else {
    Remove-Item "Registry::HKCU\Software\Classes\CLSID\{3ac72dca-9dda-4055-9cdb-695154218963}" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3ac72dca-9dda-4055-9cdb-695154218963}" -Force -ErrorAction SilentlyContinue
}
# ————————————————
# Google Drive
if(Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico") {
    MkDirCLSID "{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -Name "Google Drive" -TargetPath "A:\" -FolderType 9 -Icon "C:\Program Files\Google\Drive File Stream\drive_fs.ico"
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
# ______rClone Drives_______
[string]$rClonePath=(where.exe rclone.exe)
if($rClonePath -like "*rclone.exe") { # rClone installed
    [string[]]$rCloneDrives=(((Get-Content "$($env:Appdata)\rclone\rclone.conf") -match "\[.*\]") -replace '\[','' -replace '\]','')
    for($i=0;$i -lt 9; $i++) {
             $DriveIcon="`"$($rClonePath)`",0" #"imageres.dll,-1040"
        if((((Get-WmiObject Win32_Process -Filter "name='rclone.exe'" | Select-Object CommandLine) -like "* $($rCloneDrives[$i]): *").count) -and ($i -lt $rCloneDrives.count)) {
            MkDirCLSID "{6587a16a-ce27-424b-bc3a-8f044d36fd9$($i)}" -Name "$($rCloneDrives[$i] -replace '_',' ')" -TargetPath "$($env:Userprofile)\$($rCloneDrives[$i])" -Icon "$($DriveIcon)" -FolderType 9 -Pinned 0
        }
        else {
            Remove-Item "Registry::HKCR\CLSID\{6587a16a-ce27-424b-bc3a-8f044d36fd9$($i)}" -Force -Recurse
            Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{6587a16a-ce27-424b-bc3a-8f044d36fd9$($i)}" -Force -Recurse
        }
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
    $HiddenDrives=$HiddenDrives+[math]::pow(2,15)
    MkDirCLSID "{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Name "pCloud" -FolderType 9 -TargetPath "P:\" -Icon "`"C:\Program Files\pCloud Drive\pcloud.exe`",0"
}
else {
    Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -Recurse -ErrorAction SilentlyContinue
    Remove-Item -Path "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -Recurse -ErrorAction SilentlyContinue
}
SetValue "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDrives" -Type 4 -Value $HiddenDrives
# ________________
# Modify library namespaces
ModifyMusicLibraryNamespace
# Remove "3D objects" and "Desktop" from Windows Explorer namespace
foreach($UselessNamespace in @("{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}","{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}")) {
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($UselessNamespace)" -ErrorAction SilentlyContinue
}
# _______________
# Create "Games" folder
[string]$SpielePath="$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Spiele"
if (Test-Path "$($SpielePath)") {
    MkDirCLSID "{a235a4f4-3349-42e1-b81d-a476cd7e33c0}" -Name "@shell32.dll,-30579" -InfoTip "@searchfolder.dll,-9031" -Pinned 0 -TargetPath "$($SpielePath)" -FolderType 3 -Icon "imageres.dll,-186"
    SetValue -RegPath "HKCU\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "$($env:Appdata)\Microsoft\Windows\Start Menu\Programs\Spiele"
    foreach($SubKey in @("","WOW6432Node\")) {
        CreateKey "HKLM\SOFTWARE\$($SubKey)Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}"
    }
}
# Add Recent Items to folders
SetValue "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}" -Name "System.IsPinnedToNameSpaceTree" -Type 4 -Value 0
SetValue "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}" -Name "DescriptionID" -Type 4 -Value 3
CreateKey "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}\DefaultIcon" -StandardValue "shell32.dll,-37219"
CreateKey "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{22877a6d-37a1-461a-91b0-dbda5aaebc99}"
# Change "Linux (WSL)" Entry icon and location
if(Test-Path "Registry::HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}") {
    [string]$DistroName=(GetDefaultWSL)
    MkDirCLSID "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -Name "$($DistroName)" -Pinned 0 -TargetPath "\\wsl.localhost\$($DistroName)" -Icon "$($WSLIconLocation)" -MkInHKLM -FolderType 6
    CreateFileAssociation "CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -ShellOperations "open2" -Icon "$($TerminalIconICO)" -Command "wt.exe -p Ubuntu"
    # Remove "Linux" Entry from desktop
    Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -ErrorAction SilentlyContinue
}
UpdateStorageInfo
# ----- Folder Options ------
Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\HideFileExt" -Name "DefaultValue" -Value 0 # Show file extensions
Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\ShowCompColor" -Name "DefaultValue" -Value 1 # Show compressed / encrypted files in blue/green
foreach($HiddenOption in @("NOHIDDEN","SHOWALL")) {
    Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\$($HiddenOption)" -Name "DefaultValue" -Value 1 # Show hidden files
}
# ------ Remove all later-added desktop icons in HKCU ------
Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\*" -Force -ErrorAction SilentlyContinue
MakeReadOnly "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
# ------ System PATH Environment -----
[string]$SysEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").Path
[string]$UsrEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_CURRENT_USER\Environment").Path
[string[]]$PathsToBeAdded=@("$($env:Localappdata)\Programs\Scrcpy")
foreach($PathToBeAdded in $PathsToBeAdded) {
    if($PathToBeAdded -like "$($env:Userprofile)*") {
        if($UsrEnv -Notlike "*$($PathToBeAdded)*") {
            Write-Host "Adding `"$($PathToBeAdded)`" to user PATH"
            $UsrEnv="$($UsrEnv);$($PathToBeAdded)"
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Environment" -Name "Path" -Value "$($UsrEnv)"
        }
    }
    else {
        if($SysEnv -Notlike "*$($PathToBeAdded)*") {
            Write-Host "Adding `"$($PathToBeAdded)`" to system PATH"
            $SysEnv="$($SysEnv);$($PathToBeAdded)"
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "Path" -Value "$($SysEnv)"
        }
    }
}
# Remove Windows.old folder
[string[]]$VolCaches=(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\").Name
foreach($TempFileCleanup in $VolCaches) {
    if(($TempFileCleanup -like "*Downloads*") -or ($TempFileCleanup -like "*Recycle Bin")) {
        Remove-ItemProperty -LiteralPath "Registry::$($TempFileCleanup)" -Name "StateFlags0001" -ErrorAction SilentlyContinue
    }
    else {
        SetValue -RegPath "$($TempFileCleanup)" -Name "StateFlags0001" -Type "dword" -Value 2
    }
}
# Enable Windows 11 25300+ preview feature
SetValue -RegPath "HKLM\Software\Microsoft\Windows\CurrentVersion\Shell\Update\Packages\MicrosoftWindows.Client.40729001_cw5n1h2txyewy" -Name "Compatible" -Type "dword" -Value 1