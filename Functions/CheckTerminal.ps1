function CheckTerminal {
    [OutputType([bool])]
    param()
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
    return $WTInstalled
}