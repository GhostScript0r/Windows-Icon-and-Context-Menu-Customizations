. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function OfficeFileAssoc {
    param()
    # Check which Office program is installed
    [bool]$MSOfficeInstalled=(Test-Path "C:\Program Files*\Microsoft Office\root\Office16\Word.exe")
    [bool]$LibreOfficeInstalled=(Test-Path "C:\Program Files\LibreOffice\program\soffice.exe")
    [bool]$OnlyOfficeInstalled=(Test-Path "C:\Program Files\ONLYOFFICE\DesktopEditors\DesktopEditors.exe")
    # File Associations when Microsoft Office is installed
    if($MSOfficeInstalled) {
        # PPT
        [string[]]$PPTHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {(($_ -like "PowerPoint.Show*") -or ($_ -like "PowerPoint.Slide*")) -and (Test-Path "Registry::HKCR\$_\shell\edit")})
        foreach($Key in $PPTHKCR) {
            CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","Open","OpenAsReadOnly","Print","PrintTo","Show","ViewProtected") -Icon @("","shell32.dll,-133","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`",-1300","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`",-1300","ddores.dll,-2414","ddores.dll,-2413","imageres.dll,-103","") -LegacyDisable @(1,0,0,0,0,0,0,1) -Extended @(1,0,0,0,0,0,0,1) -Command ("","","","","","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`" /pt `"%2`" `"%3`" `"%4`" `"%1`"","","")
        }
        # WORD
        [string[]]$DOCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Word.*Document*.*") -and (Test-Path "Registry::HKCR\$_\shell\edit")})
        foreach($Key in $DOCHKCR) {
            CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","OnenotePrintto","Open","OpenAsReadOnly","Print","PrintTo","ViewProtected") -Icon @("","shell32.dll,-133","","`"$($MSOfficeLoc)\Office16\WINWORD.EXE`",-1","`"$($MSOfficeLoc)\Office16\WINWORD.EXE`",-1","ddores.dll,-2414","ddores.dll,-2413","") -LegacyDisable @(1,0,1,0,0,0,0,1) 
        }
        # EXCEL
        [string[]]$XLSHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Excel.*") -and (Test-Path "Registry::HKCR\$_\shell\print")})
        foreach($Key in $XLSHKCR) {
            CreateFileAssociation "$($Key)" -ShellOperations @("Open","print") -Icon @("$($MSOfficeLoc)\Office16\EXCEL.EXE,-257","ddores.dll,-2414")
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
                        [string]$ExcelIcon="$($MSOfficeLoc)\Office16\EXCEL.EXE,-257"
                        if(@("Edit","ViewProtected") -contains $OtherShellOp) {
                            [bool]$ExcelHidden=$true
                        }
                    }
                    CreateFileAssociation "$($Key)" -ShellOperations "$($OtherShellOp)" -Icon "$($ExcelIcon)" -LegacyDisable $ExcelHidden
                }
            }
        }
        # Outlook ICS Calender
        CreateFileAssociation "Outlook.File.ics.15" -DefaultIcon "dfrgui.exe,-137" -ShellOperations "open" -Icon "$($MSOfficeLoc)\Office16\OUTLOOK.exe,-3"
    }
    # File associations when LibreOffice is installed
    elseif($LibreOfficeInstalled) {
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
        [string[]]$OnlyOfficeHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "ASC.*"})
        foreach($Key in $OnlyofficeHKCR) {
            $OfficeIcon=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\DefaultIcon").'(default)'
            CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "C:\Program Files\ONLYOFFICE\DesktopEditors\app.ico"
            if(($OfficeIcon -like "*ONLYOFFICE*") -and ([System.Environment]::OSVersion.Version.Build -ge 22000)) { 
                # ONLYOFFICE icon is sorta ugly. Wanna change them to the MS Office file icons (only included in imageres.dll after Windows 11)
                [int]$OfficeFileIconType=($OfficeIcon -replace "[^0-9]" , '') # Get the numbers only
                Switch($OfficeFileIconType) {
                    {$_ -in 24,22,10,23} { # Excel, CSV files etc.
                        CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-8320" -FileAssoList @(".xls",".xlsx","xlsm","ods")
                    }
                    {$_ -in 1,9,3,2,8} { # PPT
                        CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-8312" -FileAssoList @(".ppt",".pptx")
                    }
                    {$_ -in 11,7,18,19} { # Word
                        CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-8302" -FileAssoList @(".doc",".docx","dot","odt")
                    }
                }
            }
        }
        CreateFileAssociation "ASC.Csv" -DefaultIcon "imageres.dll,-8301" -FileAssoList @(".csv")
    }
    # When no office program installed: Use browser to open
    else {
        # PPT
        CreateFileAssociation "PPTFile" -FileAssoList @(".ppt",".pptx") -DefaultIcon "imageres.dll,-8312" -TypeName "@explorerframe.dll,-50295" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
        # WORD
        CreateFileAssociation "DOCFile" -FileAssoList @(".doc",".docx","odt") -DefaultIcon "imageres.dll,-8302" -TypeName "@explorerframe.dll,-50293" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
        # EXCEL
        CreateFileAssociation "XLSFile" -FileAssoList @(".xls",".xlsx","xlsm") -DefaultIcon "imageres.dll,-8320" -TypeName "@explorerframe.dll,-50294" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    }
}