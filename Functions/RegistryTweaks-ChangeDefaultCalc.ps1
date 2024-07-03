function ChangeDefaultCalc {
    param()
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    [string]$SpeedCrunchPath="C:\Program Files (x86)\SpeedCrunch\speedcrunch.exe"
    if(Test-Path "$($SpeedCrunchPath)") {
        CreateFileAssociation "ms-calculator" -ShellOperations "open" -Icon "`"$($SpeedCrunchPath)`"" -Command "`"$($SpeedCrunchPath)`""
    }
    # Remove win32 calculator
    Dism.exe /Online /NoRestart /Disable-Feature /FeatureName:Microsoft-Windows-win32calc /PackageName:@Package
}