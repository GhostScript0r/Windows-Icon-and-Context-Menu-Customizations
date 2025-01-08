. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function FolderContextMenu {
    CreateFileAssociation "Folder" -ShellOperations @("open","opennewwindow","opennewtab","opennewprocess","pintohome") -Icon @("main.cpl,-606","imageres.dll,-5322","imageres.dll,-116","","shell32.dll,-322") -LegacyDisable @(0,0,0,1,0) -MUIVerb @("@shell32.dll,-32960","","","","") -TypeName "@shell32.dll,-9338"
    if([System.Environment]::OSVersion.Version.Build -ge 22621) {
        Write-Host "Windows 11 with Explorer Tab integrated. QTTabBar not needed."
        return
    }
    [string]$QTTabBarPath="C:\Program Files\QTTabBar\Tools\QTPopup.exe"
    [string[]]$QTTabBarContextMenuEntries=(Split-Path (Get-ChildItem "Registry::HKCR\Folder\shell").Name -Leaf | Where-Object {$_ -like "QTTabBar.*"})
    if(!(Test-Path "$QTTabBarPath")) {
        Write-Host "QTTabBar not installed." -ForegroundColor Red -BackgroundColor White
        foreach($Entry in $QTTabBarContextMenuEntries) {
            Remove-Item "Registry::HKCR\Folder\shell\$($Entry)" -Force -Recurse -ea 0
        }
        return
    }
    [string]$FolderDefaultOps="open"
    foreach($Entry in $QTTabBarContextMenuEntries) {
        Write-Host "$Entry" -ForegroundColor Cyan
        switch($Entry) {
            {$_ -in "QTTabBar.openInTab","QTTabBar.separator","QTTabBar.OpenNewWindow"} {
                CreateFileAssociation "Folder" -ShellOperations $Entry -LegacyDisable 1
                continue
            }
            "QTTabBar.OpenInView" {
                CreateFileAssociation "Folder" -Shelloperations $Entry -Icon "imageres.dll,-5359"
            }
            "QTTabBar.openNewTab" {
                CreateFileAssociation "Folder" -Shelloperations $Entry -Icon "imageres.dll,-116" # -MUIVerb "@windows.storage.dll,-8519"
            }
        }
        $FolderDefaultOps=$FolderDefaultOps+","+$Entry
    }
    CreateKey "HKCR\Folder\shell" -StandardValue $FolderDefaultOps
    return
}
function DirectoryContextMenu { # Includes command to run powershell script
    . "$($PSScriptRoot)\RegistryTweaks-AccessControl.ps1"
    . "$($PSScriptRoot)\CheckTerminal.ps1"
    . "$($PSScriptRoot)\CheckInstallPath.ps1"
    # [string[]]$PowerShellDef=@("","powershell.exe,0") # [0]: Display Name; [1]: Icon file
    # Hide "Open in terminal" entry to unify how the menu looks.
    SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
        -Name "{9F156763-7844-4DC4-B2B1-901F640F5155}" -EmptyValue $true # Terminal
    SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
        -Name "{02DB545A-3E20-46DE-83A5-1329B1E88B6B}" -EmptyValue $true # Terminal preview
    [bool]$WTInstalled=(CheckTerminal)
    [hashtable]$VSCodeInfo=$(FindVSCodeInstallPath)
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
    [string]$PSRunCmd="powershell.exe  `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`"" # Command to run powershell PS1 script, NOT run in folder
    [string]$PSRunCmdAdmin="$($PSRunCmd) -Verb RunAs" # Command to run powershell PS1 script, NOT run in folder
    [string]$PwsIcon="powershell.exe,0" # Older icon from Windows 7/Vista time: scrptadm.dll,-7 for running as normal user, powershell.exe,1 for running as admin
    [bool]$PwsUAC_UseLUAShield=$true
    [string]$VSCodeUACCommand="PowerShell -windowstyle hidden -Command `"Start-Process '$($VSCodeInfo.Path)' -ArgumentList '-d `"`"%V`"`"`"' -Verb RunAs`""
    if(Test-Path "C:\Windows\System32\sudo.exe") {
        $PwsUACCommand="sudo.exe $($PwsMenuCommand)"
        $PSRunCmdAdmin="sudo.exe $($PSRunCmd)"
        $PwsUACIcon="sudo.exe"
        $PwsUAC_UseLUAShield=$false
        $VSCodeUACCommand="sudo.exe `"$($VSCodeInfo.Path)`" -d `"%V`""
    }
    CreateFileAssociation @("Directory\Background","Directory","LibraryFolder\background") `
        -ShellOperations @("cmd","VSCode","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin") `
        -ShellOpDisplayName @("","Hier VS Code $([char]0x00F6)ffnen","Hier VS Code als Admin $([char]0x00F6)ffnen","","","","PowerShell hier als Admin $([char]0x00F6)ffnen") `
        -Icon @("cmd.exe,0","`"$($VSCodeInfo.Path)`",0","`"$($VSCodeInfo.Path)`",0","`"C:\Program Files\Git\git-bash.exe`",0",`
            "`"C:\Program Files\Git\git-bash.exe`",0","powershell.exe,0",$PwsUACIcon) `
        -Extended @(0,0,0,1,1,0,0) `
        -LegacyDisable @(1,0,0,0,0,0,0) `
        -HasLUAShield @(0,0,1,0,0,0,$PwsUAC_UseLUAShield) `
        -MUIVerb @("","","","","","@shell32.dll,-8508","@twinui.pcshell.dll,-10929") `
        -Command @("$($CmdMenuCommand)","`"$($VSCodeInfo.Path)`" `"%v `"",`
            "$($VSCodeUACCommand)",`
            "wt.exe new-tab --title Git-Bash --tabColor #300a16 --suppressApplicationTitle `"C:\Program Files\Git\bin\bash.exe`"",`
            "",` # git-gui no need to define
            "$($PwsMenuCommand)",`
            "$($PwsUACCommand)") # No WSL entry because WSL entry was spinned off into another PS1 script
    # ------- PS1 Script ------
    CreateFileAssociation @("Microsoft.PowerShellScript.1") -FileAssoList @("ps1") `
        -DefaultIcon "$($VSCodeInfo.Icon)\powershell.ico" -ShellOperations @("open","edit","runas") `
        -Icon @("powershell.exe,0","`"$($VSCodeInfo.Path)`",0",$PwsUACIcon) `
        -MUIVerb @("@powershell.exe,-108","","") `
        -Command @("$($PSRunCmd)","`"$($VSCodeInfo.Path)`" `"%1`"","$($PSRunCmdAdmin)")
    CreateFileAssociation "SystemFileAssociations\.ps1" -ShellOperations @("0","Windows.PowerShell.Run") -LegacyDisable @(1,1)
    Remove-Item "Registry::HKCR\Microsoft.PowerShellScript.1\shell\0" -ea 0
    # ------- In case visual studio is installed ---------
    if(Test-Path "C:\Program Files (x86)\Common Files\Microsoft Shared\MSEnv\VSLauncher.exe") {
        CreateFileAssociation "Directory" -ShellOperations "Anycode" -LegacyDisable 1
    }
    Remove-Item -Path "Registry::HKCR\Directory\Background\DefaultIcon" -ea 0 # Not needed
    # Admin commands don't work in Library Folders, so disable them in Libraries
    CreateFileAssociation "LibraryFolder\background" -ShellOperations @("VSCodeWithAdmin","PowerShellWithAdmin") -LegacyDisable @(1,1) 
    foreach($GitContextMenu in @("git_shell","git_bash"))
    {
        if(Test-Path "Registry::HKCR\Directory\Background\shell\$($GitContextMenu)") {
            MakeReadOnly "HKCR\Directory\Background\shell\$($GitContextMenu)" -InclAdmin
        }
    }
    # Show above mentioned entries only on directory background, NOT when clicking a folder
    CreateFileAssociation "Directory" -ShellOperations @("cmd","VSCode","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") -Extended @(1,1,1,1,1,1,1,1) -LegacyDisable @(1,1,1,1,1,1,1,1)
    CreateFileAssociation "DesktopBackground" -ShellOperations @("Display","Personalize") -Icon @("ddores.dll,-2109","shell32.dll,-270") # Desktop functionality
    SetValue "HKCR\Folder\shell\pintohome" -Name "SeparatorAfter" -Value "" # Add a separator line below "pin to home"
}