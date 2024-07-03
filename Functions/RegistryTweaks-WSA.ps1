function WSARegistry {
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    # > Find file location of WSA
    [string]$WSAAppDataDir="$($env:Localappdata)\Packages\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe"
    if((Test-Path $WSAAppDataDir) -and ([System.Environment]::OSVersion.Version.Build -ge 19044)) { # WSA Installed
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
}