function PDFFileAsso {
    param()
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\CheckDefaultBrowser.ps1"
    . "$($PSScriptRoot)\CheckInstallPath.ps1"
    . "$($PSScriptRoot)\RegistryTweaks-OfficeFiles.ps1"
    # Check which browsers are installed, which PDF viewers are installed, and which Office programs are installed
    [hashtable]$EdgeBrowser=(CheckDefaultBrowser -ForceEdgeIfAvailable)
    [hashtable]$DefaultBrowser=(CheckDefaultBrowser)
    [bool]$EdgeInstalled=($EdgeBrowser.Path -like "*msedge.exe")
    [hashtable]$InstalledOffice=(OfficeFileAssoc -OnlyCheckONLYOFFICE)
    [bool]$OnlyOfficeInstalled=$InstalledOffice.Office -like "ONLYOFFICE"
    [string]$SumatraPDFLoc=$(CheckInstallPath "SumatraPDF\sumatrapdf.exe")
    [string]$AdobeAcrobatLoc="C:\Program Files\Adobe\Acrobat DC\Acrobat\Acrobat.exe"
    [bool]$SumatraPDFInstalled=$(Test-Path "$($SumatraPDFLoc)")
    [bool]$AdobeAcrobatInstalled=$(Test-Path "$($AdobeAcrobatLoc)")
    # First: Browsers
    [string[]]$BrowserPDFs=@()
    if($EdgeInstalled) {
        $BrowserPDFs=$BrowserPDFs+@("MSEdgePDF")
        CreateFileAssociation "MSEdgePDF" -ShellOperations "open" -Icon "$($EdgeBrowser.Icon)" -MUIVerb "@ieframe.dll,-21819" -Command "$($EdgeBrowser.OpenAction)" -DefaultIcon "$($EdgeBrowser.Path.replace('msedge.exe','msedge.dll,-130'))"
    }
    if($DefaultBrowser.Path -like "*chrome.exe*") {
        $BrowserPDFs = $BrowserPDFs + @("ChromePDF")
        CreateFileAssociation "ChromePDF" -FileAssoList ".pdf" -DefaultIcon "$($env:Userprofile)\Links\Adobe Acrobat.ico" -ShellOperations "open" -MUIVerb "@SearchFolder.dll,-10496" -Icon "$($DefaultBrowser.Icon)" -Command "$($DefaultBrowser.OpenAction)" # If Adobe Acrobat is not working: Add  before %1
        CreateKey "HKCR\.pdf" -StandardValue "ChromePDF"
    }
    if($DefaultBrowser.Path -like "*firefox.exe*") {
        $BrowserPDFs = $BrowserPDFs + @("FirefoxPDF-308046B0AF4A39CB")
        CreateFileAssociation "FirefoxPDF-308046B0AF4A39CB" -FileAssoList ".pdf" -ShellOperations "open" -MUIVerb "@SearchFolder.dll,-10496" -Icon "$($DefaultBrowser.Icon)" -Command "$($DefaultBrowser.OpenAction)" # If Adobe Acrobat is not working: Add  before %1
        CreateKey "HKCR\.pdf" -StandardValue "FirefoxPDF-308046B0AF4A39CB"
    }
    [string[]]$NonBrowserPDFs=@()
    # Check if Adobe Acrobat is installed
    if($AdobeAcrobatInstalled) {
        CreateFileAssociation "Acrobat.Document.DC" -Shelloperations @("open","print") -Icon @("$($AdobeAcrobatLoc)","ddores.dll,-2414")
        $NonBrowserPDFs = $NonBrowserPDFs + @("Acrobat.Document.DC")
    }
    # Check office apps that can open PDFs (ONLYOFFICE)
    if($OnlyOfficeInstalled) {
        [string[]]$OnlyOfficePDFs=@("ASC.PDF","ASC.DjVu","ASC.Epub")
        $NonBrowserPDFs=$NonBrowserPDFs+$OnlyOfficePDFs
    }
    [string[]]$NonSumatraPDFs=$BrowserPDFs+$NonBrowserPDFs
    # Finally: Check if SumatraPDF is installed. This viewer can open the most types of documents. If it is installed it will be added as "open2" context menu entry to the most document files.
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
                # [string]$KeyWithPrint="$($Key)"
            }
        }
        CreateFileAssociation "Applications\SumatraPDF.exe" -shelloperations "open" -Icon "`"$($SumatraPDFLoc)`",0" -ShellOpDisplayName "Mit SumatraPDF $([char]0x00F6)ffnen" -Command "`"$($SumatraPDFLoc)`" `"%1`""
        CreateFileAssociation $NonSumatraPDFs -ShellOperations "open2" -Icon "`"$($SumatraPDFLoc)`",0" -ShellOpDisplayName "Mit SumatraPDF $([char]0x00F6)ffnen" -Command "`"$($SumatraPDFLoc)`" `"%1`"" #"ddores.dll,-2414"
        # if($EdgeInstalled) {
        #     Copy-Item -Path "Registry::HKCR\$($Key)\shell\open\command" -Destination "Registry::HKCR\MSEdgePDF\shell\open2" -Force
        #     foreach($PrintAction in @("print","printto")) {
        #         Copy-Item -Path "Registry::HKCR\$($KeyWithPrint)\shell\$($PrintAction)" -Destination "Registry::HKCR\MSEdgePDF\shell" -Force -Recurse -ea 0
        #     }
        # }
        $NonBrowserPDFs=$NonBrowserPDFs+$SumatraPDFHKCR
    }
    else { # SumatraPDF not installed
        foreach($PDFkey in $BrowserPDFs) {
            Remove-Item "Registry::HKCR\$($PDFKey)\shell\open2" -Force -Recurse -ea 0
        }
    }
    # Add "OpenInBrowser" context menu entry to all non-browser PDF entries
    CreateFileAssociation $NonBrowserPDFs -ShellOperations "openinbrowser" -Icon "$($DefaultBrowser.Icon)" -MUIVerb "$($DefaultBrowser.Text)" -Command "$($DefaultBrowser.OpenAction)"
}