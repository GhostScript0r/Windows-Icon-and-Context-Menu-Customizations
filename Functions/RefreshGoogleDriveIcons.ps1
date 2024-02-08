. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function RefreshGoogleDriveIcons {
    [object[]]$GoogleDriveApps=(Get-ChildItem "C:\Program Files\Google\Drive File Stream\*\GoogleDriveFS.exe" -recurse)
    if($GoogleDriveApps.count -eq 0) {
        Write-Host "Google Drive FS not yet installed." -ForegroundColor Red
        Remove-Item "Registry::HKCR\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}"
    }
    else {
        [string]$GDriveLoc=$GoogleDriveApps[$GoogleDriveApps.count-1].FullName
        CreateFileAssociation "CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -DefaultIcon "`"$($GDriveLoc)`",-61"
        foreach($GDocExt in @(".gdoc",".gsheet",".gslides")) {
            Remove-Item "Registry::HKCR\$($GDocExt)\ShellNew" -ErrorAction SilentlyContinue
        }
        foreach($GDoc in (Get-ChildItem "Registry::HKCR\GoogleDriveFS.*").Name) {
            [string]$GDocIcon=(Get-ItemProperty -LiteralPath "Registry::$($GDoc)\DefaultIcon").'(default)'
            CreateFileAssociation "$($GDoc)" -ShellOperations "open" -Icon "$($GDocIcon)"
        }
    }
}