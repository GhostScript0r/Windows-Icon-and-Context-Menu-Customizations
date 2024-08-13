function PDFFileAsso {
    param()
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\CheckDefaultBrowser.ps1"
    . "$($PSScriptRoot)\CheckInstallPath.ps1"
    [string[]]$BrowserPDFs=@()
    [hashtable]$EdgeBrowser=(CheckDefaultBrowser -ForceEdgeIfAvailable)
    if($EdgeBrowser.Path -like "*msedge.exe") {
        $BrowserPDFs=$BrowserPDFs+@("MSEdgePDF")
        CreateFileAssociation "MSEdgePDF" -ShellOperations "open" -Icon "$($EdgeBrowser.Icon)" -MUIVerb "@ieframe.dll,-21819" -Command "$($EdgeBrowser.OpenAction)" -DefaultIcon "$($EdgeBrowser.Path.replace('msedge.exe','msedge.dll,-129'))"
    }
    [hashtable]$DefaultBrowser=(CheckDefaultBrowser)
    if($DefaultBrowser.Path -like "*chrome.exe*") {
        $BrowserPDFs = $BrowserPDFs + @("ChromePDF")
        CreateFileAssociation "ChromePDF" -FileAssoList ".pdf" -DefaultIcon "$($env:Userprofile)\Links\Adobe Acrobat.ico" -ShellOperations "open" -MUIVerb "@SearchFolder.dll,-10496" -Icon "$($DefaultBrowser.Icon)" -Command "$($DefaultBrowser.OpenAction)" # If Adobe Acrobat is not working: Add  before %1
        CreateKey "HKCR\.pdf" -StandardValue "ChromePDF"
    }
    [string]$SumatraPDFLoc=$(CheckInstallPath "SumatraPDF\sumatrapdf.exe")
    [bool]$SumatraPDFInstalled=$(Test-Path "$($SumatraPDFLoc)")
    if($SumatraPDFInstalled) {
        [string[]]$SumatraPDFHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "SumatraPDF.*"})
        $SumatraPDFHKCR = $SumatraPDFHKCR + "Applications\SumatraPDF.exe"
        foreach($Key in $SumatraPDFHKCR) { # $SumatraPDFHKCR do not contain HKCR\ prefix
            if($Key -like "*epub*") {
                [int]$IconNr=3
            }
            elseif($Key -like "*cb?") {
                [int]$IconNr=4
            }
            else {
                [int]$IconNr=2
            }
            [string]$SumatraICO="`"$($SumatraPDFLoc)`",-$($IconNr)"
            CreateFileAssociation "$($Key)" -DefaultIcon "$($SumatraICO)" -ShellOperations "open" -MUIVerb "@appmgr.dll,-652" -Icon "`"$($SumatraPDFLoc)`",0"
            if($Key -like "*chm") { # CHM Help File
                CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-99" -ShellOperations "open2" -MUIVerb "@srh.dll,-1359" -Icon "C:\Windows\hh.exe" -Command "C:\Windows\hh.exe `"$1`""
            }
            if($Key -like "*pdf") {
                . "$($PSScriptRoot)\CheckDefaultBrowser"
                [hashtable]$DefaultBrowser=(CheckDefaultBrowser)
                CreateFileAssociation $Key -shelloperations "open2" -MUIVerb "$($DefaultBrowser.Text)" -Icon "$($DefaultBrowser.Icon)" -Command "$($DefaultBrowser.OpenAction)"
            }
            if(Test-Path "Registry::HKCR\$($Key)\shell\print") {
                CreateFileAssociation "$($Key)" -ShellOperations "print" -LegacyDisable 1 -Icon "ddores.dll,-2414"
            }
            if(Test-Path "Registry::HKCR\$($Key)\shell\printto") {
                CreateFileAssociation "$($Key)" -ShellOperations "printto" -LegacyDisable 1 -Icon "ddores.dll,-2413"
                [string]$KeyWithPrint="$($Key)"
            }
        }
        CreateFileAssociation "Applications\SumatraPDF.exe" -shelloperations "open" -Icon "`"$($SumatraPDFLoc)`",0" -ShellOpDisplayName "Mit SumatraPDF lesen" -Command "`"$($SumatraPDFLoc)`" `"%1`""
        CreateFileAssociation $BrowserPDFs -ShellOperations "open2" -Icon "`"$($SumatraPDFLoc)`",0" -ShellOpDisplayName "Mit SumatraPDF lesen" -Command "`"$($SumatraPDFLoc)`" `"%1`"" #"ddores.dll,-2414"
        Copy-Item -Path "Registry::HKCR\$($Key)\shell\open\command" -Destination "Registry::HKCR\MSEdgePDF\shell\open2" -Force
        foreach($PrintAction in @("print","printto")) {
            Copy-Item -Path "Registry::HKCR\$($KeyWithPrint)\shell\$($PrintAction)" -Destination "Registry::HKCR\MSEdgePDF\shell" -Force -Recurse -ea 0
        }
    }
}