. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
. "$($PSScriptRoot)\CheckInstallPath.ps1"
function ImageFileAssoc {
    param()
    [bool]$NoPaintApp=$false
    [string]$PaintAppName="mspaint.exe"
    # Find file location of paint app and copy it out
    if((Get-AppxPackage Microsoft.Paint).count -gt 0) { # App version of MS Paint installed
        [string]$PaintAppLocation="$($(Get-AppxPackage Microsoft.Paint).InstallLocation)\PaintApp\mspaint.exe"
        [string]$PaintIconLocation="$($env:LocalAppdata)\Packages\Microsoft.Paint_8wekyb3d8bbwe\mspaint.exe"
        if(!(Test-Path "$($PaintIconLocation)")) {
            Copy-Item -Path "$($PaintAppLocation)" -Destination "$(Split-Path $PaintIconLocation)"
        }
        [string]$PaintAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_.Name)\Application" -ea 0).ApplicationName -like "*Microsoft.Paint*"})[0]
    }
    elseif(Test-Path "C:\Windows\System32\mspaint.exe") {
        [string]$PaintAppLocation="C:\Windows\System32\mspaint.exe"
        [string]$PaintIconLocation="C:\Windows\System32\mspaint.exe"
        [string]$PaintAppHKCR="HKCR\Applications\mspaint.exe"
    }
    elseif(Test-Path "C:\Program Files\Pinta\pinta.exe") {
        [string]$PaintAppLocation="C:\Program Files\Pinta\pinta.exe"
        [string]$PaintIconLocation="C:\Program Files\Pinta\pinta.exe"
        [string]$PaintAppHKCR="HKCR\Applications\pinta.exe"
        $PaintAppName="`"C:\Program Files\Pinta\pinta.exe`""
    }
    else {
        $NoPaintApp=$true
    }
    [string]$GIMPLocation=(CheckInstallPath "GIMP *\bin\gimp-?.*.exe")
    [bool]$HideGIMP=$false
    if($GIMPLocation.length -eq 0) {
        # No GIMP installation found
        [bool]$HideGIMP=$true
    }
    [string]$PaintEditIcon="`"$($PaintIconLocation)`",0"
    CreateFileAssociation @("$($PaintAppHKCR)","SystemFileAssociations\image") -ShellOperations @("edit","edit2","print","printto") -Icon @("$($PaintEditIcon)","`"$($GIMPLocation)`",0","ddores.dll,-2414","ddores.dll,-2413") -ShellOpDisplayName @("","Mit GIMP bearbeiten","","") -MUIVerb @("@mshtml.dll,-2210","","@shell32.dll,-31250","@printui.dll,-14935") -Command @("$($PaintAppName) `"%1`"","`"$($GIMPLocation)`" `"%1`"","","") -LegacyDisable @($NoPaintApp,$HideGIMP,$true,$true) 
    [string[]]$ImageFileExts=@("bmp","jpg","jpeg","png","016","256","ico","cur","ani","dds","tif","tiff","rri")
    SetValue "HKCR\.256" -Name "PerceivedType" -Value "image"
    foreach($ImageExt in $ImageFileExts) {
        if($ImageExt[0] -ne ".") {
            $ImageExt=".$($ImageExt)"
        }
        if($ImageExt -eq ".ani") {
            [string]$PhotoViewerCap="anifile"
        }
        elseif($ImageExt -eq ".cur") {
            [string]$PhotoViewerCap="curfile"
        }
        elseif($ImageExt -eq ".ico") {
            [string]$PhotoViewerCap="icofile"
        }
        else {
            [string]$PhotoViewerCap="PhotoViewer.FileAssoc.Tiff"
            SetValue -RegPath "HKCR\$($ImageExt)" -Name "PerceivedType" -Value "image"
        }
        SetValue -RegPath "Registry::HKLM\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" -Type "string" -Name $ImageExt -Value "$($PhotoViewerCap)"
        if($PhotoViewerCap -notlike "PhotoViewer.FileAssoc.Tiff") {
            CreateFileAssociation $PhotoViewerCap -ShellOperations "open" -command "rundll32.exe `"%ProgramFiles%\Windows Photo Viewer\PhotoViewer.dll`", ImageView_Fullscreen %1" -MUIVerb "@%ProgramFiles%\Windows Photo Viewer\photoviewer.dll,-3043" -Icon "`"C:\Program Files\Windows Photo Viewer\PhotoViewer.dll`",0"
            CreateKey "HKCR\$($PhotoViewerCap)\shell\open\DropTarget"
            SetValue "HKCR\$($PhotoViewerCap)\shell\open\DropTarget" -Name "Clsid" -Value "{FFE2A43C-56B9-4bf5-9A79-CC6D4285608A}"
        }
    }
    # Cursor file: show icon directly af file: DefaultIcon="%1"
    foreach($CursorType in @("anifile","curfile")) {
        Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell" -Destination "Registry::HKCR\$($CursorType)" -force
        Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open" -Destination "Registry::HKCR\$($CursorType)\shell" -force
        Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open\command" -Destination "Registry::HKCR\$($CursorType)\shell\open" -force
        Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open\droptarget" -Destination "Registry::HKCR\$($CursorType)\shell\open" -force
    }
    CreateFileAssociation "PhotoViewer.FileAssoc.Tiff" -ShellOperations "open" -Icon "`"C:\Program Files\Windows Photo Viewer\PhotoViewer.dll`",0" -DefaultIcon "imageres.dll,-122" # "`"C:\Program Files\Windows Photo Viewer\PhotoAcq.dll`",-7"
    $SysFileAssoExt=(Get-ChildItem "Registry::HKEY_CLASSES_ROOT\SystemFileAssociations\.*")
    foreach($AssoExt in $SysFileAssoExt) {
        if(Test-Path "Registry::$($AssoExt.name)\shell\setdesktopwallpaper") {
            CreateFileAssociation "$($AssoExt.name)" -ShellOperations "setdesktopwallpaper" -Icon "imageres.dll,-110"
            if([System.Environment]::OSVersion.Version.Build -lt 22000) { # there will be "Edit with Paint 3D in the file association."
                CreateFileAssociation "$($AssoExt.name)" -ShellOperations "3d edit" -LegacyDisable 1
            }
        }
    }
}