. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function ChangeDefaultCalc {
    [string]$SpeedCrunchPath="C:\Program Files (x86)\SpeedCrunch\speedcrunch.exe"
    if(Test-Path "$($SpeedCrunchPath)") {
        CreateFileAssociation "ms-calculator" -ShellOperations "open" -Icon "`"$($SpeedCrunchPath)`"" -Command "`"$($SpeedCrunchPath)`"" -IsURLProtocol -URL "ms-calculator"
    }
    # Remove win32 calculator
    Dism.exe /Online /NoRestart /Disable-Feature /FeatureName:Microsoft-Windows-win32calc /PackageName:@Package
    return
}

function UseBrowserForCertainURLs {
    CreateFileAssociation "ms-people" -ShellOperations "open" -Command "rundll32 url.dll,FileProtocolHandler https://contacts.google.com" -IsURLProtocol # Replace Microsoft People with Google Contacts
    CreateFileAssociation "bingmaps" -ShellOperations "open" -Command "rundll32 url.dll,FileProtocolHandler https://maps.google.com" -IsURLProtocol
    . "$($PSScriptRoot)\CheckDefaultBrowser.ps1"
    CreateFileAssociation "Protocols\Handler\mailto" -ShellOperations "open" -Command "$($DefaultBrowser.OpenAction)" # Use default browser to open mailto link. Need to set GMail as the default browser to open the file.
}