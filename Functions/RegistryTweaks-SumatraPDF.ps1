function PDFFileAsso {
    param()
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\CheckDefaultBrowser.ps1"
    . "$($PSScriptRoot)\CheckInstallPath.ps1"
    [string[]]$BrowserPDFs=@("MSEdgePDF")
    CreateFileAssociation $BrowserPDFs -ShellOperations "open" -Icon "ieframe.dll,-31065" -MUIVerb "@ieframe.dll,-21819"
    [string[]]$DefaultBrowser=(CheckDefaultBrowser)
    if($DefaultBrowser[0] -like "*chrome.exe*") {
        $BrowserPDFs = $BrowserPDFs + @("ChromePDF")
        CreateFileAssociation "ChromePDF" -FileAssoList ".pdf" -DefaultIcon "$($env:Userprofile)\Links\Adobe Acrobat.ico" -ShellOperations @("open") -MUIVerb @("@SearchFolder.dll,-10496") -Icon @("`"$($DefaultBrowser[0])`",0") -Command @("`"$($DefaultBrowser[0])`" `"%1`"") # If Adobe Acrobat is not working: Add  before %1
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
                CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-99" -ShellOperations @("open","open2") -MUIVerb @("@appmgr.dll,-652","@srh.dll,-1359") -Icon ("","C:\Windows\hh.exe") -Command @("","C:\Windows\hh.exe `"$1`"")
            }
            if(Test-Path "Registry::HKCR\$($Key)\shell\print") {
                CreateFileAssociation "$($Key)" -ShellOperations "print" -LegacyDisable 1 -Icon "ddores.dll,-2414"
            }
            if(Test-Path "Registry::HKCR\$($Key)\shell\printto") {
                CreateFileAssociation "$($Key)" -ShellOperations "printto" -LegacyDisable 1 -Icon "ddores.dll,-2413"
                [string]$KeyWithPrint="$($Key)"
            }
        }
        CreateFileAssociation $BrowserPDFs -ShellOperations @("open2") -Icon @("`"$($SumatraPDFLoc)`",0") -ShellOpDisplayName @("Mit SumatraPDF lesen") -Command @("`"$($SumatraPDFLoc)`" `"%1`"") #"ddores.dll,-2414"
        Copy-Item -Path "Registry::HKCR\$($Key)\shell\open\command" -Destination "Registry::HKCR\MSEdgePDF\shell\open2" -Force
        foreach($PrintAction in @("print","printto")) {
            Copy-Item -Path "Registry::HKCR\$($KeyWithPrint)\shell\$($PrintAction)" -Destination "Registry::HKCR\MSEdgePDF\shell" -Force -Recurse -ea 0
        }
    }
}