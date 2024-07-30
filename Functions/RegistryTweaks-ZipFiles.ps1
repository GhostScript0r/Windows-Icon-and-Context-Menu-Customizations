. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function ZipFileAssoc {
    param()
    CreateFileAssociation "CompressedFolder" -ShellOperations "open" -Icon "zipfldr.dll,0"
    # Other ZIP folders
    [string[]]$ZipFileAssoExt=@("7z","apk","zip","cbz","cbr","rar","vdi","001","gz")
    [string]$ZipAppInstalled=(Get-Childitem "C:\Program files\*zip").name
    if($ZipAppInstalled -like "PeaZip") {
        Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2browseasarchive; PeaZip.add2separate; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
        Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name 'Icon' -Value "C:\Program files\Peazip\peazip.exe"
        <# PeaZip Commands include:
        PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2smart; PeaZip.ext2folder; PeaZip.ext2test; PeaZip.ext2browseasarchive; PeaZip.ext2browsepath; PeaZip.add2separate; PeaZip.add2separatesingle; PeaZip.add2separatesfx; PeaZip.add2separate7z; PeaZip.add2separate7zfastest; PeaZip.add2separate7zultra; PeaZip.add2separatezip; PeaZip.add2separatezipfastest; PeaZip.add2separate7zencrypt; PeaZip.add2separatezipmail; PeaZip.add2split; PeaZip.add2convert; PeaZip.analyze; PeaZip.add2wipe #>
        [string[]]$PeaZipHKCR=(Get-ChildItem Registry::HKCR\PeaZip.*).Name # Include HKCR\ prefix
        CreateFileAssociation $($PeaZipHKCR+@("Applications\PEAZIP.exe")) -DefaultIcon "imageres.dll,-174" -ShellOperations "open" -ShellOpDisplayName "Mit PeaZip browsen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
        CreateFileAssociation "CompressedFolder" -DefaultIcon "imageres.dll,-174" -ShellOperations "open2" -ShellOpDisplayName "Mit PeaZip browsen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
        CreateFileAssociation @("Directory\Background","LibraryFolder\background") -ShellOperations @("Browse path with PeaZip","ZPeaZip") -ShellOpDisplayName @("","Hier PeaZip starten") -Icon @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`",0") -Command @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"-ext2browsepath`" `"%V`"") -LegacyDisable @(1,0)
        foreach($Key in $PeaZipHKCR) {
            Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::$($Key)\shell" -Force
            CreateFileAssociation "$($Key)" -ShellOperations "PeaZip" -Icon "zipfldr.dll,-101" -MUIVerb "@zipfldr.dll,-10148"
            SetValue "$($Key)\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2folder; PeaZip.add2split; PeaZip.add2convert; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
            Remove-Item -Path "Registry::$($Key)\shell\PeaZipCompressedFolder" -Force -Recurse -ea 0
        }
        Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::HKCR\AllFilesystemObjects\shell" -Force
        [string[]]$PeaZipCommandHKCR=(Get-ChildItem Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\PeaZip.*).Name # Include HKLM\..... whole path
        foreach($SubCommand in $PeaZipCommandHKCR) {
            if($SubCommand -like "*PeaZip.ext2browseasarchive") {
                [string]$ZipIcon="zipfldr.dll,-101" # Open as archive
            }
            elseif($SubCommand -like "*PeaZip.add2separate*") {
                [string]$ZipIcon="imageres.dll,-175" # Compress/Add2archive
                if($SubCommand -like "*PeaZip.add2separatezipmail") {
                    [string]$ZipIcon="mssvp.dll,-500" # Send via E-Mail
                }
                if($SubCommand -like "*PeaZip.*encrypt") {
                    [string]$ZipIcon="imageres.dll,-5360" # Encrypt archive
                }
            }
            elseif(($SubCommand -like "*Peazip.ext2*") -and ($SubCommand -notlike "*Peazip.ext2browsepath")) {
                [string]$ZipIcon="shell32.dll,-46" # Extract
            }
            elseif($SubCommand -like "*PeaZip.add2wipe") {
                [string]$ZipIcon="shell32.dll,-16777" #Erase
            }
            else {
                [string]$ZipIcon=""
            }
            if($ZipIcon.length -gt 1) {
                Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "$($ZipIcon)"
            }
        }
        # Remove PeaZip "SendTo" entries
        $SendToItems=(Get-ChildItem "$($env:APPDATA)\Microsoft\Windows\SendTo") | Where-Object {$_.Name -like "*.lnk"}
        $sh=New-Object -ComObject WScript.Shell
        foreach($SendToItem in $SendToItems) {
            $LNKTarget=$sh.CreateShortcut("$($SendToItem.FullName)").TargetPath
            if($LNKTarget -like "*PeaZip*") {
                Remove-Item "$($SendToItem.FullName)"
            }
        } 
    }
    elseif($ZipAppInstalled -like "7-Zip") {
        CreateFileAssociation @("CompressedArchive","Applications\7zFM.exe","dllfile") -FileAssoList $ZipFileAssoExt -DefaultIcon "imageres.dll,-174" -ShellOperations "open" -ShellOpDisplayName "Mit 7-Zip browsen" -Icon "`"C:\Program Files\7-Zip\7zFM.exe`",0" -Command "`"C:\Program Files\7-Zip\7zFM.exe`" `"%1`""
        CreateFileAssociation "dllfile" -DefaultIcon "imageres.dll,-67"
    }
}