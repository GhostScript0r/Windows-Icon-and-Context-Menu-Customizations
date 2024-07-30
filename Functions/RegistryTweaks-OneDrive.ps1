function OneDriveRegistry {
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\CheckInstallPath.ps1"
        . "$($PSScriptRoot)\RegistryTweaks-AccessControl.ps1"
    [string]$OneDriveInstallLoc=(CheckInstallPath "Microsoft\OneDrive\OneDrive.exe")
    if($OneDriveInstallLoc.length -eq 0) {
        $OneDriveInstallLoc=(CheckInstallPath "Microsoft OneDrive\OneDrive.exe")
    }
    if($OneDriveInstallLoc.length -eq 0) {
        Write-Host "OneDrive app not installed!" -ForegroundColor Red -BackgroundColor White
    }
    if(Test-Path "$($OneDriveInstallLoc)") {
        [string]$WorkFolderIcon="`"$($OneDriveInstallLoc)`",-589"
    }
    else {
        [string]$WorkFolderIcon="WorkFoldersRes.dll,-1"
    }
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
        if([System.Environment]::OSVersion.Version.Build -ge 22000) { # Latest version of OneDrive supported. Otherweise let OneDrive app manage the CLSID entry
             MkDirCLSID $OneDriveCLSID -Name "OneDrive" -Icon "$($OneDriveIcon)" -FolderType 9 -TargetPath "$($OneDriveFolderLoc)" -FolderValueFlags 0x30 # 0x30
        }
        else {
            Mkdirclsid $Onedriveclsid -RemoveCLSID
            MkDirCLSID $Onedriveclsid -Name "OneDrive" -Icon "$($OnedriveIcon)" -FolderType 9 -IsShortcut -FolderValueFlags 0x30
            CreateFileAssociation "CLSID\$($OneDriveCLSID)" -defaulticon "imageres.dll,-1040" -shelloperations "Open" -icon "$($OneDriveIcon)" -Command "explorer.exe `"$($OneDriveFolderLoc)`"" -MUIVerb "@SettingsHandlers_OneDriveBackup.dll,-108"
            CreateKey "HKLM\Software\Classes\CLSID\$($OneDriveCLSID)" -StandardValue "OneDrive"
            . "$($PSScriptRoot)\RegistryTweaks-ReadStorage.ps1"
            UpdateStorageInfo -NetDriveOnly
        }
        if($OneDriveEntry.Name -like "*Personal*") {
            CreateFileAssociation "CLSID\$($OneDriveCLSID)" -shelloperations "browse" -ShellOpDisplayName "onedrive.com besuchen" -Icon "ieframe.dll,-190" -Command "rundll32 url.dll,FileProtocolHandler https://onedrive.live.com"
            # MakeReadOnly "HKCU\Software\Classes\CLSID\$($OneDriveCLSID)" # -InclAdmin
            # CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSID)"
            # MakeReadOnly "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSID)"
        }
    }
}