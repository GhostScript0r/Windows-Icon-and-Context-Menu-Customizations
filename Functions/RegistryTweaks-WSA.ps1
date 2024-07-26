function WSARegistry {
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\FindDefaultZipApp.ps1"
    . "$($PSScriptRoot)\GetIcons.ps1"
    # > Find file location of WSA
    [string]$WSAAppDataDir="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe"
    [string]$WSAInstallLoc="$((Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForAndroid).InstallLocation)"
    if((Test-Path $WSAAppDataDir) -and ([System.Environment]::OSVersion.Version.Build -ge 19044)) { # WSA Installed
        [string[]]$WSAIcons=@("$($WSAAppDataDir)\LatteLogo.png","$($WSAAppDataDir)\app.ico")
        foreach($Icon in $WSAIcons) {
            [string]$WSALocation="$($WSAInstallLoc)\Assets\$(Split-Path $Icon -Leaf)"
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
        . "$($PSScriptRoot)\RegistryTweaks-ReadStorage.ps1"
        UpdateStorageInfo -WSAOnly
        [string]$StartWSAAppCommandPrefix="$($env:Localappdata)\Microsoft\WindowsApps\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe\WsaClient.exe /launch wsa://"
        [string]$WSAUserVHDX=(Get-Item "$($WSAAppDataDir)\LocalCache\userdata*.vhdx")[0].FullName
        [string[]]$WSAContextMenu=@("open","cmd","zipopen","WSAsettings")
        [string[]]$WSAContextMenuIcon=@("imageres.dll,-190","`"$($WSAIconsDistro[1] -replace 'VHD','')`"","$(FindDefaultZipApp -GetIcon)","$($WSAIcons[1])")
        [string[]]$WSAContextMenuName=@("Mit Android-Dateibrowser ansehen","WSA ADB-Shell starten","VHD mit $(FindDefaultZipApp -GetName) browsen","WSA-Einstellungen abrufen")
        [string[]]$WSAContextMenuCommand=@("$($StartWSAAppCommandPrefix)com.android.documentsui","wt.exe -p `"WSA ADB Shell`"","`"$(FindDefaultZipApp -GetFM)`" `"$($WSAUserVHDX)`"","explorer.exe shell:AppsFolder\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!SettingsApp")
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
        SetValue "HKCR\CLSID\$($WSACLSID)\shell\WSAsettings" -Name "Position" -Value "Bottom"
    }
    else { # WSA not installed
        MkDirCLSID $WSACLSID -RemoveCLSID -ea 0
    }
}