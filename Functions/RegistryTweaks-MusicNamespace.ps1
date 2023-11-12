. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\RegistryTweaks-AccessControl.ps1"
function ModifyMusicLibraryNamespace {
    [string[]]$LibraryCLSID=@("{A0C69A99-21C8-4671-8703-7934162FCF1D}","My Music") #",{35286A68-3C57-41A1-BBB1-0EAE73D76C95}","{374DE290-123F-4565-9164-39C4925E467B}","My Video"
[string[]]$LibraryLoc=@("%USERPROFILE%\Box\Music","%USERPROFILE%\Box\Music") #,"D:\Videos","D:\Downloads","D:\Videos"
for($i=0; $i -lt $LibraryCLSID.length ; $i++) {
    SetValue "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "$($LibraryCLSID[$i])" -Value "$($LibraryLoc[$i])"
    }
    MakeReadOnly "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
}