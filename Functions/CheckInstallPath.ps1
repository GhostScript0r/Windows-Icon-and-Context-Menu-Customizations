# Checks if a certain program is installed for all users or current user only
function CheckInstallPath {
    [OutputType([string])]
    param(
        [parameter(ParameterSetName='Program', Mandatory=$true, Position=0)]
        [string]$Program,
        [string[]]$InstallLocation=@("C:\Program Files","$($env:LOCALAPPDATA)\Programs"),
        [switch]$IgnoreInstallInformation
    )
    if(-not ($IgnoreInstallInformation)) {
        [string[]]$RegEntryHKLM=(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object {(Get-Itemproperty "Registry::$_").'DisplayName' -like "$($Program)*"})
        [string[]]$RegEntryHKCU=(Get-ChildItem "Registry::HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | Where-Object {(Get-Itemproperty "Registry::$_").'DisplayName' -like "$($Program)*"})
        [string[]]$RegEntry=$RegEntryHKLM+$RegEntryHKCU
        for($i=0;$i -lt $RegEntry.count;$i++) {
            [string]$InstallLoc=(Get-ItemProperty "Registry::$($RegEntry[$i])")."InstallLocation"
            if(($InstallLoc.length -gt 0) -and (Test-Path "$($InstallLoc)")) {
                if($InstallLoc[-1] -eq "\") {
                    $InstallLoc=$InstallLoc.substring(0,$InstallLoc.length-1) # Remove the ending backslash
                }
                return $InstallLoc
            }
        }
        Write-Host "Did not find installation information in registry. Try to search in folders directly..." -ForegroundColor Red -BackgroundColor Yellow
    }
    if(($Program -like "*OneDrive.exe") -or ($Program -like "*SumatraPDF.exe")) {
        $InstallLocation[1]="$($env:LOCALAPPDATA)"
    }
    for($i=0;$i -lt $InstallLocation.length;$i++) {
        if(Test-Path "$($InstallLocation[$i])\$($Program)") {
            [string]$ProgramLocation="$($InstallLocation[$i])\$($Program)"
            Write-Host "$(Split-Path $Program -leaf) is installed in $($InstallLocation[$i])"
            break
        }
        else {
            [string]$ProgramLocation=""
        }
    }
    try {
        [string]$ProgramLocation=(Get-Item "$($ProgramLocation)").FullName # Use Get-Item in case the input includes wildcard ? or *
        return $ProgramLocation
    }
    catch {
        return ""
    }
}

function FindVSCodeInstallPath {
    [OutputType([string[]])]
    [string[]]$VSCodeVersion=@("Microsoft VS Code\Code.exe","Microsoft VS Code Insiders\Code - Insiders.exe")
    for ($i=0;$i -lt $VScodeVersion.count;$i++) {
        [string]$VSCodeLocation=(CheckInstallPath "$($VSCodeVersion[$i])")
        if($VSCodeLocation.length -gt 0) {
            [string]$VSCodeIconsLoc="$(Split-Path "$($VSCodeLocation)" -Parent)\resources\app\resources\win32"
            [string]$VSCodeVerHKCR="VSCode"
            if($VSCodeLocation -like "*Insiders*") {
                [string]$VSCodeVerHKCR="VSCodeInsiders"
            }
            break
        }
    }
    return @($VSCodeLocation,$VSCodeIconsLoc,$VSCodeVerHKCR)
}