param(
    [switch]$RemoveCommonStartFolder,
    [switch]$StorageRefreshOnly,
    [switch]$Win32GoogleRefreshOnly,
    [switch]$VSCodeRefreshOnly
)
# Write-Host ((Get-Variable -scope private).Name + @(" ") + (Get-Variable -scope local).Name)
Write-Host "This script is inteneded to write in the usual registry stuff after Windows OOBE or in-place upgrade" -BackgroundColor White -ForegroundColor Blue
# Call functions
# Check Admin Privilege
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
foreach($Argum in (GetThisScriptVariable $(Get-Variable))) {
    if((Get-Variable "$($Argum)").value -eq $true) {
        $ArgumentToPass = $ArgumentToPass + @($Argum)    
    }
}
foreach($Argum in (GetThisScriptVariable $(Get-Variable))) {
    if((Get-Variable "$($Argum)").value -eq $true) {
        $ArgumentToPass = $ArgumentToPass + @($Argum)    
    }
}
RunAsAdmin "$($PSCommandPath)" -Arguments $ArgumentToPass
$PSFunctions=(Get-ChildItem "$($PSScriptRoot)\Functions\*.ps1")
foreach($Function in $PSFunctions) {
    . "$($Function.FullName)"
}
# Refresh Box Drive if updated
BoxDriveRefresh
if($StorageRefreshOnly) {
    UpdateStorageInfo
    exit # The 5-minute storage refresh script ends at the place above.
}
# Here starts the script that will only be run manually or when a system version update is done.
GenerateCustomNamespace @("Dropbox","Google Drive","rClone","Games","AllApps") #Generate namespaces for cloud drives and custom folders
SetValue "HKLM\SYSTEM\ControlSet001\Control\TimeZoneInformation" -Name "RealTimeIsUniversal" -Type 4 -Value 1 # Use BIOS time as UTC
HideMouseShadowPlay # NVidia Shadow Play - hide mouse button
# -------Get privileges to take ownership-------
Write-Host "Preparing to take ownership of keys owned by SYSTEM or TrustedInstaller" # Python equivalent: print("...")
#Take ownership of keys owned by SYSTEM or TrustedInstaller
[string[]]$LockedHKCRMain=@(`
    "HKCR\Launcher.AllAppsDesktopApplication\shell",`
    "HKCR\Launcher.Computer\shell",`
    "HKCR\Launcher.DesktopPackagedApplication\shell",`
    "HKCR\Launcher.ImmersiveApplication\shell",`
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
WriteWSLRegistry # Add WSL stuff to registry
WSARegistry # Add WSA to registry
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
ZipFileAssoc # zip relevant, compressed archives
PDFFileAsso # PDF Document
# ________________ VS Code related __________________
# Check if VS Code is installed systemwide or for current user only
[hashtable]$VSCodeInfo=$(FindVSCodeInstallPath)
# ------- Python script -------
# > Find file location of Python
[string]$PythonEXELocation=(where.exe python.exe)
if($lastexitcode -eq 1) { 
    Write-Host "Python not installed."
    Remove-Item "Registry::HKCR\py_auto_file" -Force -Recurse -ea 0
}
else {
    if($PythonEXELocation -like "$($env:LOCALAPPDATA)\Microsoft\WindowsApps\python.exe") { # Python installed as UWP app
        $PythonApp=(Get-AppxPackage PythonSoftwareFoundation.Python*)[0]
        [string]$PythonInstallLoc="$($PythonApp.InstallLocation)\python.exe"
        [string]$PythonScriptsLoc=(Get-Item "$($env:LocalAppdata)\Packages\$($PythonApp.PackageFamilyName)\LocalCache\local-packages\Python*\Scripts").FullName
        [string]$PythonIconPath=(GetDistroIcon "$($PythonApp.Name)" -CopyAppIconPNG -PNGSubLoc "_resources\pythonx150.png")
        # [string]$PythonDefaultIconPath=""
        try {
            [string]$PythonFileHKCR=((Get-ItemProperty "Registry::HKCR\.py\OpenWithProgids\") | get-member | Where-Object {$_.Name -like "AppX*"})[0].Name # Does not include HKCR itself
            # $PythonDefaultIconPath=(Get-ItemProperty "Registry::HKCR\$($PythonFileHKCR)\DefaultIcon").'(default)'
            # if($PythonDefaultIconPath -like "*/_resources/py.png}") {
            #     $PythonDefaultIconPath=$PythonDefaultIconPath.replace('py.png}','idlex150.png}') # The icon is too low-res, so better not use it.
            # }
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
    CreateFileAssociation "$($PythonFileHKCR)" -shelloperations @("open","edit") -Icon @("$($PythonIconPath)","`"$($VSCodeInfo.Path)`",0") -Command ("","`"$($VSCodeInfo.Path)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","") # -DefaultIcon "$($PythonDefaultIconPath)"
}
# -----------Text files, VS Code related--------------
# ------- All VSCode files ------
[string]$VSCodeVerHKCR=(FindVSCodeInstallPath).Registry
[string[]]$VSCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "$($VSCodeVerHKCR).*"})
foreach($Key in $VSCHKCR) {
    if(Test-Path "Registry::HKCR\$($Key)\shell\open\command" -ea 0) { # Use this if argument to skip VS Code files without "command" subkey
        CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "`"$($VSCodeInfo.Path)`",0" -MUIVerb "@shell32.dll,-37398" -Extended 0 -command "`"$($VSCodeInfo.Path)`" `"%1`""
    }  # Else: Do nothing for VS Code files without "command" subkey. Those are probably defined somewhere else.
}
CreateKey "HKCR\$($VSCodeVerHKCR).txt\DefaultIcon" -StandardValue "imageres.dll,-19"
[string]$VSCodeInfo.Registry=$(Split-Path "$($VSCodeInfo.Path)" -leaf)
CreateFileAssociation "Applications\$($VSCodeInfo.Registry)" -ShellOperations "open" -Icon "`"$($VSCodeInfo.Path)`",0" -MUIVerb "@certmgr.dll,-291" -Command "`"$($VSCodeInfo.Path)`" `"%1`"" -DefaultIcon "imageres.dll,-19"
# Give "Text" property to all VS Code related files
foreach($FileExt in (Get-ChildItem "Registry::HKCR\.*").Name) {
    [string]$ProgID=(Get-ItemProperty -LiteralPath "Registry::$($FileExt)\OpenWithProgIds" -ea 0) 
    if(($ProgID -like "*$($VSCodeVerHKCR).*") -and (-not (Test-Path "Registry::$($FileExt)\PersistentHandler"))) {
        # Change item type to text in order to let Windows index the values
        CreateKey "$($FileExt)\PersistentHandler" -StandardValue "{5e941d80-bf96-11cd-b579-08002b30bfeb}"
    }
}
CreateFileAssociation "Microsoft.System.Update.1" -ShellOperations "open" -Icon "wusa.exe,-101" -MUIVerb "@ActionCenter.dll,-2107" # Windows Update package (MSU)
FolderContextMenu # Folders
ChangeBitLockerIcon
DirectoryContextMenu # --------Directories--------
RemoveAMDContextMenu # Remove AMD Radeon context menu entries
ImageFileAssoc # Image files
MediaPlayerFileAssoc # Media files
CreateFileAssociation @("exefile","Launcher.DesktopPackagedApplication","Launcher.AllAppsDesktopApplication","Launcher.DesktopPackagedApplication","Windows.PackagedApplicationCommand") -ShellOperations @("open","runas") -Icon @("imageres.dll,-100","imageres.dll,-100") -MUIVerb @("@shell32.dll,-12710","") -HasLUAShield @(0,1) # EXE files
CreateFileAssociation "Launcher.AllAppsDesktopApplication" -ShellOperations @("Feature.Uninstall","OpenFileLocation","OpenNewWindow","Uninstall") -Icon @("DevicePairingFolder.dll,-151","main.cpl,-606","imageres.dll,-5322","DevicePairingFolder.dll,-151") -MUIVerb @("@pcsvdevice.dll,-584","","","@shell32.dll,-24722")
CreateFileAssociation "Launcher.ImmersiveApplication" -ShellOperations "open" -Icon "imageres.dll,-100" -MUIVerb "@shell32.dll,-12710"
CreateFileAssociation "scrfile" -FileAssoList ".scr" -DefaultIcon "%1" -ShellOperations @("config","install","open") -Icon @("mmcndmgr.dll,-30572","setupugc.exe,-133","webcheck.dll,-407") # Screensavers
# ---------TXT File---------
CreateFileAssociation @("txtfile","textfile","SystemFileAssociations\text") -DefaultIcon "imageres.dll,-19" -ShellOperations @("open","edit") -ShellDefault "open" -LegacyDisable @(0,1) -Icon @("`"$($VSCodeInfo.Path)`",0","`"$($VSCodeInfo.Path)`",0") -Command @("`"$($VSCodeInfo.Path)`" `"%1`"","`"$($VSCodeInfo.Path)`" `"%1`"") `
    -MUIVerb @("@mshtml.dll,-2210","")
if(Test-Path "Registry::HKCR\txtfile\shell\print\command") {
    CreateFileAssociation @("txtfile","textfile") -ShellOperations @("print","printto") `
        -Icon @("ddores.dll,-2413","ddores.dll,-2414") `
        -Extended @(1,1) -LegacyDisable @(1,1)
}
# ------- Cheat Engine Cheat Table-------
if(Test-Path "Registry::HKCR\CheatEngine\DefaultIcon") {
    [string]$CheatEnginePath=(Get-ItemProperty -LiteralPath "Registry::HKCR\CheatEngine\DefaultIcon").'(default)' -replace ',0',''
    CreateFileAssociation "CheatEngine" -shelloperations @("open","edit") -Icon @("$($CheatEnginePath)","`"$($VSCodeInfo.Path)`",0") -Command @("","`"$($VSCodeInfo.Path)`" `"%1`"")
}
# --------BAT, CMD, COM script-------
CreateFileAssociation @("batfile","cmdfile","comfile") -ShellOperations @("open","print","edit","runas") -Icon @("cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeInfo.Path)`",0","cmd.exe,0") -MUIVerb @("@shell32.dll,-12710","","","") -Command @("","","`"$($VSCodeInfo.Path)`" `"%1`"","") -Extended @(0,1,0,0) -LegacyDisable @(0,1,0,0) -DefaultIcon "cmd.exe,0" ` # "$($VSCodeInfo.Icon)\shell.ico"
# --------VBE, VBS and JSE (JavaScript) Script--------
if(Test-Path "C:\Windows\System32\wscript.exe") { # If VBS as a legacy component is not disabled yet.
    CreateFileAssociation @("VBSFile","VBEFile","JSEFile") ` # "$($VSCodeVerHKCR).vb",
    -ShellOperations @("open","open2","print","edit") `
    -Icon @("wscript.exe,-1","cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeInfo.Path)`",0") `
    -MUIVerb @("@shell32.dll,-12710","@wshext.dll,-4511","","") `
    -Command @("WScript.exe `"%1`" %*","CScript.exe `"%1`" %*","","`"$($VSCodeInfo.Path)`" `"%1`"") `
    -FileAssoList @("vb","vbs","vbe","jse") `
    -Extended @(0,0,1,0) -LegacyDisable @(0,0,1,0)
}
# --------Registry file--------
CreateFileAssociation "regfile" -ShellOperations @("open","edit","print") -Icon @("regedit.exe,0","`"$($VSCodeInfo.Path)`",0","DDORes.dll,-2413") -Extended @(0,0,1) -command @("","`"$($VSCodeInfo.Path)`" `"%1`"","")
PowerToysFileAsso -RegFile
# ------- Check default browser ---------
[hashtable]$DefaultBrowser=(CheckDefaultBrowser)
[hashtable]$EdgeBrowser=(CheckDefaultBrowser -ForceEdgeIfAvailable)
# -------XML Document-------
Remove-ItemProperty -Path "Registry::HKCR\.xml" -Name "PreceivedType" -ea 0 -Force
foreach($ML_Ext in @("xml","htm","html")) {    
    Remove-ItemProperty -Path "Registry::HKCR\.$($ML_Ext)\OpenWithProgids" -Name "MSEdgeHTM" -ea 0 
}
CreateFileAssociation @("xmlfile","$($VSCodeVerHKCR).xml","xml_auto_file") -FileAssoList ".xml" -DefaultIcon "msxml3.dll,-128" -ShellOperations @("open","edit") -ShellDefault "edit" -Icon @("$($DefaultBrowser.Icon)","`"$($VSCodeInfo.Path)`",0") -MUIVerb @("$($DefaultBrowser.Text)","")-Command @("$($DefaultBrowser.OpenAction)","`"$($VSCodeInfo.Path)`" `"%1`"") -CommandId @("IE.File","") -DelegateExecute @("{17FE9752-0B5A-4665-84CD-569794602F5C}","")
Remove-Item "Registry::HKCR\xmlfile\ShellEx\IconHandler" -ea 0
# ------- PS1 Script ------
CreateFileAssociation @("Microsoft.PowerShellScript.1") -FileAssoList @("ps1")  -DefaultIcon "$($VSCodeInfo.Icon)\powershell.ico" -ShellOperations @("open","edit","runas") -Icon @("scrptadm.dll,-7","`"$($VSCodeInfo.Path)`",0","C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,1") -MUIVerb @("@`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`",-108","","") -Command @("`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`"  `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`"","`"$($VSCodeInfo.Path)`" `"%1`"","`"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`" `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`" -Verb RunAs")
CreateFileAssociation "SystemFileAssociations\.ps1" -ShellOperations @("0","Windows.PowerShell.Run") -LegacyDisable @(1,1)
Remove-Item "Registry::HKCR\Microsoft.PowerShellScript.1\shell\0" -ea 0
# ------- LOG File ------
SetValue "HKCR\.log" -Name "Content Type" -Value "text/plain"
SetValue "HKCR\.log" -Name "PerceivedType" -Value "text"
# ------- Linux BASH -------
CreateFileAssociation @("bashfile") -FileAssoList @("sh","bash") -ShellOperations @("open","edit") -Icon @("$($WSLLocation)","$($VSCodeInfo.Path)") -Command @("wsl.exe bash `$(wslpath `"%1`")","`"$($VSCodeInfo.Path)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","") -DefaultIcon "$($VSCodeInfo.Icon)\shell.ico" -LegacyDisable @(!($WSLEnabled),0)
# --------HTML file--------
[string]$OpenHTMLVerb="@ieframe.dll,-14756" # Open in new tab
if($DefaultBrowser.Path -like "*msedge.exe") {
    $OpenHTMLVerb="@ieframe.dll,-21819" # Open with Edge
}
if([System.Environment]::OSVersion.Version.Build -ge 22000) {
    [string]$HTMLIcon="shell32.dll,-14"
}
else {
    [string]$HTMLIcon="ieframe.dll,-110"
}
CreateFileAssociation @("htmlfile","$($VSCodeVerHKCR).htm","$($VSCodeVerHKCR).html","MSEdgeHTM","Applications\MSEdge.exe") -DefaultIcon "ieframe.dll,-210" -ShellOperations @("open","edit","print","printto") -Icon @("$($DefaultBrowser.Icon)","`"$($VSCodeInfo.Path)`",0","DDORes.dll,-2414","DDORes.dll,-2413") -Command @("$($DefaultBrowser.OpenAction)","`"$($VSCodeInfo.Path)`" `"%1`"","","") -MUIVerb @("$($OpenHTMLVerb)","","","") -LegacyDisable @(0,0,1,1)
CreateFileAssociation @("MSEdgeHTM","Applications\MSEdge.exe") -Shelloperations "open" -Icon $EdgeBrowser.Icon -Command $EdgeBrowser.OpenAction
MakeReadOnly "HKCR\MSEdgeHTM\DefaultIcon" -InclAdmin
MakeReadOnly "HKCR\htmlfile\DefaultIcon" -InclAdmin
# ------- URL Internet Shortcut -------
foreach($PropertyToBeRemoved in @("NeverShowExt")) { #,"IsShortcut"
    Remove-ItemProperty -Path "Registry::HKCR\InternetShortcut" -Name $PropertyToBeRemoved -Force -ea 0
}
Remove-Item -Path "Registry::HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}" -Force -ea 0
if([System.Environment]::OSVersion.Version.Build -ge 22000) {
    [string]$URLIcon="url.dll,-5"
}
else {
    [string]$URLIcon="urlmon.dll,-106"
}
CreateFileAssociation "InternetShortcut" -DefaultIcon $URLIcon -ShellOperations @("open","edit","print","printto") -Icon @("$($DefaultBrowser.Icon)","`"$($VSCodeInfo.Path)`",0","ddores.dll,-2414","ddores.dll,-2413") -MUIVerb @("@synccenter.dll,-6102",,"","","") -LegacyDisable @(0,0,1,1) -Command @("powershell.exe -Command `"`$URL= ((Get-Content '%1') -like 'URL=*') -replace 'URL=',' '; Start-Process `"$($DefaultBrowser.Path)`" `$URL'","`"$($VSCodeInfo.Path)`" `"%1`"","","")
# --------Google Chrome HTML (if Chrome installed)--------
if($DefaultBrowser.Path -like "*chrome.exe*") {
    CreateFileAssociation "ChromeHTML" -DefaultIcon "$($HTMLIcon)" `
    -ShellOperations @("open","edit") -MUIVerb @("@SearchFolder.dll,-10496","") `
    -Icon @("`"$($DefaultBrowser.Path)`",0","`"$($VSCodeInfo.Path)`",0") `
    -Command @("`"$($DefaultBrowser.Path)`" `"%1`"","`"$($VSCodeInfo.Path)`" `"%1`"")
}
# ---------TTF Schriftart----------
CreateFileAssociation "ttffile" -ShellOperations @("preview","print") -Icon @("imageres.dll,-77","imageres.dll,-51")
# ---------MS Office files---------
OfficeFileAssoc
# ---------RDP file (config for remote connection) ------
CreateFileAssociation "RDP.File" -ShellOperations @("Connect","Edit","Open") -Extended @(0,0,0) -Icon @("mstscax.dll,-13417","mstsc.exe,-101","`"$($VSCodeInfo.Path)`",0")  -ShellOpDisplayName @("","Mit MSTSC bearbeiten","Mit Visual Studio Code bearbeiten") -Command @("","","`"$($VSCodeInfo.Path)`" `"%1`"")
# ---------PFX Certificate------
CreateFileAssociation "pfxfile" -ShellOperations @("add","open") -Extended @(0,1) -LegacyDisable @(0,1) -Icon @("certmgr.dll,-6169","certmgr.dll,-6169") -MUIVerb @("@cryptext.dll,-6126","") -ShellDefault "add"
# ---------INI /INF Config file------
CreateFileAssociation @("inifile","inffile") `
    -FileAssoList @("forger2","conf","ini","inf") `
    -ShellOperations @("open","print") `
    -Command @("`"$($VSCodeInfo.Path)`" `"%1`"","") `
    -MUIVerb @("@mshtml.dll,-2210","") `
    -Icon @("`"$($VSCodeInfo.Path)`",0","DDORes.dll,-2413") `
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
        -Icon @("`"$($SEditLoc)`",0","`"$($VSCodeInfo.Path)`",0") `
        -Command @("`"$($SEditLoc)`" `"%1`"","`"$($VSCodeInfo.Path)`" `"%1`"")
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
CreateFileAssociation "CLSID\{645FF040-5081-101B-9F08-00AA002F954E}" -shelloperations "empty" -Icon "imageres.dll,-5305"
# Add recycle bin to this PC
SetValue -RegPath "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}" -Name "DescriptionID" -Type "dword" -Value 0x16
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{645FF040-5081-101B-9F08-00AA002F954E}"
# Change "Manage" icon
CreateFileAssociation @("CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}","Launcher.Computer") -shelloperations "Manage" -Icon "mycomput.dll,-204" -HasLUAShield 0 
CreateFileAssociation "Launcher.Computer" -shelloperations @("connectNetworkDrive","disconnectNetworkDrive") -Icon @("shell32.dll,-10","shell32.dll,-11")
# ------ CONTROL PANEL ------
# Change control panel icons
CreateFileAssociation @("CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}","CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}") -DefaultIcon "Control.exe,0" -Icon @("Control.exe,0","shell32.dll,-16826") -ShellOperations @("open","open2") -MUIVerb @("@shell32.dll,-10018","@shell32.dll,-31312") -command @("control.exe","explorer.exe shell:AppsFolder\windows.immersivecontrolpanel_cw5n1h2txyewy!microsoft.windows.immersivecontrolpanel")
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
GenerateCustomNamespace "StandardFolders"
# __________________ Library ____________________________
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
# Change Quick Access icon
CreateFileAssociation @("CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}","CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}") -DefaultIcon "shell32.dll,-51380" -ShellOperations "pintohome" -Icon "shell32.dll,-322" -TypeName "@propsys.dll,-42249"
# Change desktop icon
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon" -StandardValue "DDORes.dll,-2068" # My PC to a laptop icon
if([System.Environment]::OSVersion.Version.Build -ge 22000) { # Windows 11
    [string]$UserFolderIcon="Shell32.dll,-279" # User profile
}
else {
    [string]$UserFolderIcon="imageres.dll,-123"
}
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon" -StandardValue $UserFolderIcon
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon" -StandardValue "imageres.dll,-120" # Network places
OneDriveRegistry # OneDrive stuff
HideDriveLetters # Hide unwanted drive letters
ModifyMusicLibraryNamespace
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
ChangeDefaultCalc # Use SpeedCrunch as calculator, if installed
UseBrowserForCertainURLs
# Use QWERTZ German keyboard layout for Chinese IME
[string]$CurrentKeyboardLayout=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804")."Layout File"
if($CurrentKeyboardLayout -notlike "KBDGR.DLL") {
    SetValue "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804" -Name "Layout File" -Value "KBDGR.DLL"
    BallonNotif "Computer needs to be restarted to let keyboard layout change (EN->DE) take effect"
}
# ------ System PATH Environment -----
[string]$SysEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").Path
[string]$UsrEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_CURRENT_USER\Environment").Path
[string[]]$PathsToBeAdded=@()
if(Test-Path $PythonScriptsLoc) {
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
DAToolSetFileAssoc
# Use dark mode
SetValue "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -Type "4" -Value 0
SetValue "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppUsesLightTheme" -Type "4" -Value 0