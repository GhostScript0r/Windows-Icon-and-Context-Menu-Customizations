function CreateShortCut {
    param(
        [parameter(Mandatory=$true, Position=0)]
        [string]$ShortcutName,
        [parameter(Mandatory=$true, Position=1)]
        [string]$Target,
        [string]$Argument="",
        [string]$Icon="",
        [switch]$TargetIsWSL,
        [switch]$TargetNeedsWSLsudo
    )
    if(($ShortCutName -notlike "?:\*") -and ($ShortcutName -notlike "\\*")) {
        Write-Host "Shortcut name is just a file name without full path. Use default path - start menu."
        if($TargetIsWSL) {
            . "$($PSScriptRoot)\GetDefaultWSL.ps1"
            [string]$DefaultWSLName=(GetDefaultWSL)
            New-Item -Path "$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\WSL $($DefaultWSLName)" -ItemType Directory -ErrorAction SilentlyContinue
            $ShortCutName="$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\WSL $($DefaultWSLName)\$($ShortCutName)"
        }
        else {
            $ShortCutName="$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\$($ShortCutName)"
        }
        if($ShortCutName -notlike "*.lnk") {
            Write-Host "Shortcut name does not contain extension (LNK), adding it..."
            $ShortCutName="$($ShortCutName).lnk"
        }
    }
    if($TargetIsWSL) {
        if($TargetNeedsWSLsudo) {
            [string]$SudoCommand="sudo "
        }
        else {
            [string]$SudoCommand=""
        }
        [string]$TargetWSL=$Target
        $Target="C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" 
        $Argument="-Command `"wsl.exe $($SudoCommand)bash -c 'xrandr --auto && export GTK_THEME=Yaru-dark && export GTK_ICON_THEME=Flat-Remix-Blue-Dark && export XCURSOR_THEME=DMZ-White && export QT_ICON_THEME=Flat-Remix-Blue-Dark && $($TargetWSL) & sleep 1 && pgrep -l $($TargetWSL) || $($TargetWSL)'"
    }
    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("$($ShortCutName)")
    $Shortcut.TargetPath = "$($Target)"
    if($Argument.Length -gt 0) {
        $Shortcut.Arguments=$Argument
    }
    if($Icon.length -gt 0) {
        if(($Icon -notlike "?:\*") -and ($Icon -notlike "\\*") -and ($Icon -like "*.???,*")) {
            Write-Host "Shortcut icon name is just a file name without full path. Use default path: C:\Windows\System32"
            $Icon="C:\Windows\System32\$($Icon)"
        }
        $Shortcut.IconLocation="$($Icon)"
    }
    elseif($TargetIsWSL) {
        # Four levels of icon fallback: First search for ICO file downloaded, then search from WSL icon folder for the icon, then search for the low-res ico WSl generates. Finally fallback to plain WSL icon.
        $Icon="$($env:USERPROFILE)\Links\$($TargetWSL).ico"
        if(!(Test-Path "$($Icon)")) {
            [string]$WSLIconsPath=$(wsl.exe wslpath -w /usr/share/icons)
            [string]$IconPNGs=(Get-Childitem "$($WSLIconsPath)\*\*$($TargetWSL)*.png" -Recurse | Sort-Object -Property Length -Descending)
            if($IconPNGs.count -gt 0) {
                $IconPNG=($IconPNGs | Select-Object -First 1).FullName
                . "$($PSScriptRoot)\GetIcons.ps1"
                $Icon=(GetDistroIcon "$($IconPNG))" -IconForWSLApp)
            }
            else {
                $Icon=""
            }
        }
        if(!(Test-Path "$($Icon)")) {
            $Icon="$($env:LOCALAPPDATA)\Temp\WSLDVCPlugin\$($DefaultWSLName)\$($TargetWSL).ico"
        }
        # Fallback to Windows-generated icon (low res, bad quality, not recommended).
        if(!(Test-Path "$($Icon)")) {
            $Icon="C:\Program Files\WSL\wsl.exe,0" # Fallback to default icon
        }
        $Shortcut.IconLocation="$($Icon)"
    }
    Write-Host "Creating shortcut $($ShortcutName)..."
    $Shortcut.Save()
}