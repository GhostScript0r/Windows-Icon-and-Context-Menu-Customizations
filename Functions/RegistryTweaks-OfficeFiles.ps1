. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function OfficeFileAssoc {
    [Outputtype([hashtable])]
    param(
        [switch]$OnlyCheckONLYOFFICE
    )
    # Check which Office program is installed
    [string]$MSOfficeLoc="C:\Program Files\Microsoft Office\root\Office16"
    [bool]$MSOfficeInstalled=(Test-Path "$($MSOfficeLoc)\WINWORD.exe")
    [bool]$LibreOfficeInstalled=(Test-Path "C:\Program Files\LibreOffice\program\soffice.exe")
    [bool]$OnlyOfficeInstalled=(Test-Path "C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe")
    [hashtable]$InstalledOffice=@{
        Office=""
        DOC=""
        PPT=""
        XLS=""
    }
    if($OnlyCheckONLYOFFICE -and (-not $OnlyOfficeInstalled)) {
        return $InstalledOffice
    }
    # File Associations when Microsoft Office is installed
    if($MSOfficeInstalled) {
        $InstalledOffice=@{
            Office="Microsoft Office"
            DOC="Word"
            PPT="PowerPoint"
            XLS="Excel"
        }
        # PPT
        [string[]]$PPTHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {(($_ -like "PowerPoint.Show*") -or ($_ -like "PowerPoint.Slide*")) -and (Test-Path "Registry::HKCR\$_\shell\edit")})
        foreach($Key in $PPTHKCR) {
            CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","Open","OpenAsReadOnly","Print","PrintTo","Show","ViewProtected") -Icon @("","shell32.dll,-133","`"$($MSOfficeLoc)\POWERPNT.EXE`",-1300","`"$($MSOfficeLoc)\POWERPNT.EXE`",-1300","ddores.dll,-2414","ddores.dll,-2413","imageres.dll,-103","") -LegacyDisable @(1,0,0,0,0,0,0,1) -Extended @(1,0,0,0,0,0,0,1) -Command ("","","","","","`"$($MSOfficeLoc)\POWERPNT.EXE`" /pt `"%2`" `"%3`" `"%4`" `"%1`"","","")
        }
        # WORD
        [string[]]$DOCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Word.*Document*.*") -and (Test-Path "Registry::HKCR\$_\shell\edit")})
        foreach($Key in $DOCHKCR) {
            CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","OnenotePrintto","Open","OpenAsReadOnly","Print","PrintTo","ViewProtected") -Icon @("","shell32.dll,-133","","`"$($MSOfficeLoc)\WINWORD.EXE`",-1","`"$($MSOfficeLoc)\WINWORD.EXE`",-1","ddores.dll,-2414","ddores.dll,-2413","") -LegacyDisable @(1,0,1,0,0,0,0,1) 
        }
        # EXCEL
        [string[]]$XLSHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Excel.*") -and (Test-Path "Registry::HKCR\$_\shell\print")})
        foreach($Key in $XLSHKCR) {
            CreateFileAssociation "$($Key)" -ShellOperations @("Open","print") -Icon @("$($MSOfficeLoc)\EXCEL.EXE,-257","ddores.dll,-2414")
            foreach($OtherShellOp in @("Edit","New","OpenAsReadOnly","Printto","ViewProtected")) {
                if(Test-Path "Registry::HKCR\$($Key)\shell\$($OtherShellOp)") {
                    [bool]$ExcelHidden=$false
                    if($OtherShellOp -like "New") {
                        [string]$ExcelIcon="shell32.dll,-133"
                    }
                    elseif($OtherShellOp -like "PrintTo") {
                        [string]$ExcelIcon="ddores.dll,-2413"
                    }
                    else {
                        [string]$ExcelIcon="$($MSOfficeLoc)\EXCEL.EXE,-257"
                        if(@("Edit","ViewProtected") -contains $OtherShellOp) {
                            [bool]$ExcelHidden=$true
                        }
                    }
                    CreateFileAssociation "$($Key)" -ShellOperations "$($OtherShellOp)" -Icon "$($ExcelIcon)" -LegacyDisable $ExcelHidden
                }
            }
        }
        # Outlook ICS Calender
        CreateFileAssociation "Outlook.File.ics.15" -DefaultIcon "dfrgui.exe,-137" -ShellOperations "open" -Icon "$($MSOfficeLoc)\OUTLOOK.exe,-3"
    }
    # File associations when LibreOffice is installed
    elseif($LibreOfficeInstalled) {
        $InstalledOffice=@{
            Office="LibreOffice"
            DOC="Write"
            PPT="Impress"
            XLS="Calc"
        }
        [string[]]$LibreOfficeHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "LibreOffice.*"})
        foreach($Key in $LibreofficeHKCR) {
            $OfficeIcon=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\DefaultIcon").'(default)'
            CreateFileAssociation "$($Key)" -ShellOperations "Open" -Icon "$($OfficeIcon)"
            if(Test-Path "Registry::HKCR\$($Key)\shell\New") {
                CreateFileAssociation "$($Key)" -ShellOperations "New" -Icon "shell32.dll,-133"
            }
            if(Test-Path "Registry::HKCR\$($Key)\shell\Print") {
                CreateFileAssociation "$($Key)" -ShellOperations "Print" -Icon "DDORes.dll,-2414"
            }
            if(Test-Path "Registry::HKCR\$($Key)\shell\PrintTo") {
                CreateFileAssociation "$($Key)" -ShellOperations "PrintTo" -Icon "DDORes.dll,-2413"
            }
        }
    }
    # File Associations when OnlyOffice is installed
    elseif($OnlyOfficeInstalled) {
        $InstalledOffice=@{
            Office="ONLYOFFICE"
            DOC="Word Editor"
            PPT="PPT Editor"
            XLS="Table Editor"
            PDF="PDF Editor"
        }
        if($OnlyCheckONLYOFFICE) {
            return $InstalledOffice
        }
        [string[]]$OnlyOfficeHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "ASC.*"})
        foreach($Key in $OnlyofficeHKCR) {
            $OfficeIcon=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\DefaultIcon" -ErrorAction SilentlyContinue).'(default)'
            if(($OfficeIcon -like "C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe,*")) { 
                [int]$OfficeFileIconType=($OfficeIcon -replace "[^0-9]" , '') # Get the numbers only
                [string]$OpenIcon=""
                Switch($OfficeFileIconType) {
                    {$_ -in 11,7,18,19,30} { # Word
                        $OpenIcon="C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe,-115"
                        # [string[]]$OfficeExtList=@(".doc",".docx","dot","odt") # -DefaultIcon "imageres.dll,-8302" 
                    }
                    {$_ -in 24,22,10,23} { # Excel, CSV files etc.
                        $OpenIcon="C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe,-116"
                        # [string[]]$OfficeExtList=@(".xls",".xlsx","xlsm","ods") # -DefaultIcon "imageres.dll,-8320" 
                    }
                    {$_ -in 1,9,3,2,8} { # PPT
                        $OpenIcon="C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe,-117"
                        # [string[]]$OfficeExtList=@(".ppt",".pptx") # -DefaultIcon "imageres.dll,-8312" 
                    }
                    {$_ -in 4,5,28} { # PDF, Epub, DjVu
                        $OpenIcon="C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe,-118"
                        # [string[]]$OfficeExtList=@(".ppt",".pptx") 
                    }
                    default {
                        $OpenIcon="C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe,-101"
                    }
                }
                CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "$($OpenIcon)"
            }
        }
        CreateFileAssociation "ASC.Csv" -DefaultIcon "imageres.dll,-8301" -FileAssoList @(".csv")
    }
    # When no office program installed: Use browser to open
    else {
        . "$($PSScriptRoot)\CheckDefaultBrowser.ps1"
        [hashtable]$DefaultBrowser=(CheckDefaultBrowser)
        $InstalledOffice=@{
            Office="$($DefaultBrowser.OpenInBrowserText)"
            DOC="Word"
            PPT="PowerPoint"
            XLS="Excel"
        }
        CreateFileAssociation @("PPTFile"."DOCFile","XLSFile") -ShellOperations "open" -ShellOpDisplayName "$($DefaultBrowser.OpenInBrowserText)" -Icon "$($DefaultBrowser.Icon)" -command "$($DefaultBrowser.OpenAction)"
        # WORD
        CreateFileAssociation "DOCFile" -FileAssoList @(".doc",".docx","odt") -DefaultIcon "imageres.dll,-8302" -TypeName "@explorerframe.dll,-50293"
        # EXCEL
        CreateFileAssociation "XLSFile" -FileAssoList @(".xls",".xlsx","xlsm") -DefaultIcon "imageres.dll,-8320" -TypeName "@explorerframe.dll,-50294"
        # PPT
        CreateFileAssociation "PPTFile" -FileAssoList @(".ppt",".pptx") -DefaultIcon "imageres.dll,-8312" -TypeName "@explorerframe.dll,-50295"
    }
    return $InstalledOffice
}