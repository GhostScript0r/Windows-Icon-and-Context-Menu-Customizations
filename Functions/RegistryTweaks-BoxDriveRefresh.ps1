function BoxDriveRefresh {
    . "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
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
                    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
                    CreateFileAssociation $BoxDriveCLSID -shelloperations "Browse" -ShellOpDisplayName "box.com besuchen" -Icon "ieframe.dll,-190" -Command "rundll32 url.dll,FileProtocolHandler https://box.com"
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
}