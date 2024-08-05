function RegFolderContextMenu {
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    CreateFileAssociation "Folder" -ShellOperations @("open","opennewwindow","opennewtab","opennewprocess","pintohome") -Icon @("main.cpl,-606","imageres.dll,-5322","imageres.dll,-116","","shell32.dll,-322") -LegacyDisable @(0,0,0,1,0) -MUIVerb @("@shell32.dll,-32960","","","","") -TypeName "@shell32.dll,-9338"

    if([System.Environment]::OSVersion.Version.Build -ge 22621) {
        Write-Host "Windows 11 with Explorer Tab integrated. QTTabBar not needed."
        return
    }
    [string]$QTTabBarPath="C:\Program Files\QTTabBar\Tools\QTPopup.exe"
    if(!(Test-Path "$QTTabBarPath")) {
        Write-Host "QTTabBar not installed." -ForegroundColor Red -BackgroundColor White
        return
    }
    [string[]]$QTTabBarContextMenuEntries=(Split-Path (Get-ChildItem "Registry::HKCR\Folder\shell").Name -Leaf | Where-Object {$_ -like "QTTabBar.*"})
    [string]$FolderDefaultOps="open"
    foreach($Entry in $QTTabBarContextMenuEntries) {
        Write-Host "$Entry" -ForegroundColor Cyan
        switch($Entry) {
            {$_ -in "QTTabBar.openInTab","QTTabBar.separator","QTTabBar.OpenNewWindow"} {
                CreateFileAssociation "Folder" -ShellOperations $Entry -LegacyDisable 1
                continue
            }
            "QTTabBar.OpenInView" {
                CreateFileAssociation "Folder" -Shelloperations $Entry -Icon "imageres.dll,-5359"
            }
            "QTTabBar.openNewTab" {
                CreateFileAssociation "Folder" -Shelloperations $Entry -Icon "imageres.dll,-116" # -MUIVerb "@windows.storage.dll,-8519"
            }
        }
        $FolderDefaultOps=$FolderDefaultOps+","+$Entry
    }
    CreateKey "HKCR\Folder\shell" -StandardValue $FolderDefaultOps
}