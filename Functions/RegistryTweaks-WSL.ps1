function WriteWSLRegistry {
    [bool]$WSLEnabled=((Get-WindowsOptionalFeature -online -featurename "Microsoft-Windows-Subsystem-Linux").State -eq "Enabled")
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    if(-not $WSLEnabled) {
        Write-Host "WSL is NOT enabled." -ForegroundColor Red -BackgroundColor Green
        for($i=0; $i -le 6; $i++) {
            MkDirCLSID "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}" -RemoveCLSID
        }
        return # Following things not needed
    }
    . "$($PSScriptRoot)\GetDefaultWSL.ps1"
    . "$($PSScriptRoot)\CheckTerminal.ps1"
    . "$($PSScriptRoot)\GetIcons.ps1"
    . "$($PSScriptRoot)\RegistryTweaks-ReadStorage.ps1"
    # _________________________________
    # Remove "Linux" Entry from desktop
    Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -force -ea 0
    # _________________________________ 
    # Find WSL location
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
    # ________ WSL icon ______
    [string]$WSLIcon="`"$($WSLLocation)`",0"
    if([System.Environment]::OSVersion.Version.Build -lt 18000) { # WSL.exe gets an icon since WSL2 (1903)
        GetDistroIcon -Iconforlnk
        $WSLIcon="$($env:USERPROFILE)\Links\Tux.ico"
    }
    # ________ Create WSL distro icons in Windows Explorer ________
    # Check what is the default WSL distro
    [string[]]$WSLFolderCLSIDs=@("{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}")
    [string[]]$DistroNames=@($(GetDefaultWSL))
    if($DistroNames[0].length -eq 0) {
        Write-Host "WSL is enabled but no distro is installed."
        MkDirCLSID $WSLFolderCLSIDs[0] -RemoveCLSID
        return
    }
    [string[]]$MoreDistroName=(GetExtraWSL)
    $DistroNames=$DistroNames+$MoreDistroName
    [string[]]$WSLDistroIcons=@($(GetDistroIcon "$($DistroNames[0])")[1])
    for($i=0; $i -le 5; $i++) {
        MkDirCLSID "{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}" -RemoveCLSID
        if($i -ge $MoreDistroName.count) { # Not so many WSL distros
            CreateFileAssociation @("Directory\Background","Directory","LibraryFolder\background") -ShellOperations "WSL$($i+1)" -LegacyDisable 1
        }
        else {
            reg.exe copy "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}" "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" /s /f
            Copy-Item -Path "Registry::HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -Destination "Registry::HKCU\SOFTWARE\Classes\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}" -Force -Recurse -ea 0
            # Somehow Copy-Item will fail to create properties uder \Instance\InitPropertyBag. These properties need to be created separately
            SetValue "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}\Instance\InitPropertyBag" -Name "DisplayType" -Type "4" -Value 2
            $StringProperties=@{"EnumObjectsTelemetryValue"="WSL";"Provider"="Plan 9 Network Provider";"ResName"="\\wsl.localhost";"TargetFolderPath"="\\wsl.localhost\$($MoreDistroName[$i].replace(' ','-'))"}
            foreach($Key in $StringProperties.keys) {
                SetValue "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}\Instance\InitPropertyBag" -Name $Key -Value $StringProperties.$Key
            }
            $WSLFolderCLSIDs=$WSLFolderCLSIDs+@("{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC$($i)}")
            [string]$ExtraDistroIcon=(GetDistroIcon "$($MoreDistroName[$i])")[1] # ICO file is the 2nd element, first element is PNG
            $WSLDistroIcons=$WSLDistroIcons+@($ExtraDistroIcon)
            CreateFileAssociation @("Directory\Background","Directory","LibraryFolder\background") -ShellOperations "WSL$($i+1)" -LegacyDisable 0
        }
    }
    [string[]]$DistroLocs=@($(GetDefaultWSL -GetWSLPath))+$(GetExtraWSL -GetWSLPath)
    # [int[]]$DistroVers=@(GetDefaultWSL -GetWSLver)+$(GetExtraWSL -GetWSLVer)
    [bool]$WTInstalled=(CheckTerminal)
    for($i=0;$i -lt $DistroNames.count;$i++) { # Do it reversely in order to do default WSL first
        [string]$WSLCtxtMenuIcon=$WSLDistroIcons[$i].replace('VHD','')
        [string]$WSLCtxtMuiVerb="REMOVE"
        if(($i -eq 0) -and ($WSLFolderCLSIDs.count -eq 1)) {
            Write-Host "There is only one default WSL distro installed: $($DefaultDistroName)"
            $WSLCtxtMenuIcon="$($WSLIcon)" # Use default WSL penguin icon instead of distribution icon if there's only one distro installed
            $WSLCtxtMuiVerb="@wsl.exe,-2"
        }
        if($WTInstalled) {
            [string]$WSLMenuCommand="wt.exe -p `"$($DistroNames[$i])`" -d `"%V`""
        }
        else {
            [string]$WSLMenuCommand="wsl.exe -d $($DistroNames[$i]) --cd `"%V`""
        }
        MkDirCLSID $WSLFolderCLSIDs[$i] -FolderType 6 -Name "$($DistroNames[$i])" -Pinned 1 -TargetPath "$($DistroLocs[$i])" -Icon "$($WSLDistroIcons[$i])"    
        wsl.exe -d $($DistroNames[$i].replace(' ','-')) sleep 2 # Need to run WSL first to make sure the next "Test-Path" works.    
        [bool]$XRDPInstalled=$true # (Test-Path "Microsoft.PowerShell.Core\FileSystem::\\wsl.localhost\$($DistroName)\etc\xrdp\xrdp.ini")
        [string]$XRDPCommand=""
        if($XRDPInstalled -eq $true) {
            [string]$PortMentionedInXRDP=((Get-Content "Microsoft.PowerShell.Core\FileSystem::\\wsl.localhost\$($DistroNames[$i])\etc\xrdp\xrdp.ini" | Where-Object {$_ -like "port=*"})[0] -replace "[^0-9]",'')
            [string]$XRDPStartCommand="mstsc.exe /v:localhost:$($PortMentionedInXRDP) /f"
            if($PortMentionedInXRDP.length -gt 0) {
                if(Test-Path "C:\Program Files\WSL\msrdc.exe") {
                    [string]$XRDPIcon="`"C:\Program Files\WSL\msrdc.exe`",-101"
                }
                else {
                    [string]$XRDPIcon="mstscax.dll,-13417"
                }
                [string]$XRDPCommand="cmd /c wsl -d $($DistroNames[$i].replace(' ','-')) bash -c `"sudo systemctl start xrdp | cat`" && start `"`" $($XRDPStartCommand) && exit"
            }
        }
        SetValue "HKCR\CLSID\$($WSLFolderCLSIDs[$i])\shell\Shutdown" -Name "Position" -Value "Bottom"
        CreateFileAssociation "CLSID\$($WSLFolderCLSIDs[$i])" -ShellOperations @("WSL","XRDPConnect","Shutdown") -Icon @("$($WSLCtxtMenuIcon)",$XRDPIcon,"shell32.dll,-28") -Command @("$($WSLMenuCommand)","$($XRDPCommand)","cmd /c wsl -d $($DistroNames[$i].replace(' ','-')) --shutdown") -MUIVerb @("@wsl.exe,-2","","") -ShellOpDisplayName @("","$($DistroNames[$i])-Desktop starten (XRDP)","$($DistroNames[$i]) herunterfahren") # -LegacyDisable @($false,!($XRDPInstalled),$false)
        # __________ Create context menu entry _____________
        [string]$WSLCtxtMenuEntry="WSL$($i)"
        if($i -eq 0) {
            $WSLCtxtMenuEntry="WSL"
        }
        CreateFileAssociation @("Directory\Background","Directory","LibraryFolder\background") -ShellOperations $WSLCtxtMenuEntry -Icon "$($WSLCtxtMenuIcon)" -ShellOpDisplayName "Hier $($DistroNames[$i])-Shell $([char]0x00F6)ffnen" -Command "$($WSLMenuCommand)" -Extended $false -MUIVerb "$($WSLCtxtMuiVerb)"
        CreateFileAssociation "Directory" -ShellOperations $WSLCtxtMenuEntry -LegacyDisable $true   
    }
    UpdateStorageInfo -WSLOnly
}