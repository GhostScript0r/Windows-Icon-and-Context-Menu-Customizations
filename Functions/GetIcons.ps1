. "$($PSScriptRoot)\FindDefaultZipApp.ps1"
. "$($PSScriptRoot)\HashTables.ps1"
function GetDistroIcon {
    [OutputType([string])]
    param(
        [parameter(ParameterSetName='DistroName', Mandatory=$false, Position=0)]
        [string]$DistroName="",
        [switch]$CloudDrive,
        [switch]$IconForLnk,
        [switch]$IconForMIME,
        [switch]$IconForWSLApp,
        [switch]$Force,
        [switch]$CopyAppIconPNG,
        [string]$PNGSubLoc=""
    )
    # Creating Distro Icon (PNG to ICO) requires ImageMagick
    if(-not ((where.exe magick.exe) -like "*magick.exe")) {
        Write-Host "Image Magick not installed. Icons cannot be created!" -ForegroundColor Red
        return ""
    }
    [string]$AppDataDir = "$($env:USERPROFILE)\Links"
    if($IconForWSLApp) {
        if(!(Test-Path "$($DistroName)")) {
            Write-Host "" -ForegroundColor Red -BackgroundColor White
            return ""
        }
    }
    if($CopyAppIconPNG) {
        if($PNGSubLoc.length -eq 0) {
            Write-Error "File location is mandatory."
            return ""
        }
        [string]$PNGMainLoc=""
        if(($DistroName -like "*\*") -and (Test-Path "$($DistroName)")) 
        { # DistroName is an AppxPackage
            $PNGMainLoc=$DistroName
        }
        else {
            $App=(Get-AppxPackage $DistroName)
            if($App.count -gt 0) {
                $PNGMainLoc=$App[0].InstallLocation
            }
        }
        if($PNGMainLoc.length -eq 0) {
            Write-Host "The app or path $($PNGMainLoc) does not exist!" -ForegroundColor Red -BackgroundColor Black
            return ""
        }
        [string]$TargetFile="$($env:USERPROFILE)\Links\$($DistroName)_$([io.path]::GetFileNameWithoutExtension($PNGSubLoc)).ico"
        if(-not (Test-Path "$($TargetFile)")) {
            [string]$PNGSource=($PNGMainLoc+"\"+$PNGSubLoc).replace("\\","\")
            Copy-Item -Path "$($PNGSource)" -Destination "$($TargetFile.replace('.ico','.png'))" -Force
            magick.exe -background transparent "$($TargetFile.replace('.ico','.png'))" -define icon:auto-resize=16,24,32,48,64,72,96,128,256 "$($TargetFile)"
        }
        return $TargetFile
    }
    if($IconForLnk -or $IconForMIME) {
        if($IconForLnk) {
            $DistroLogoURLs=(GetHashTables "IconForLnk")
            [string]$DisplayText="for shortcuts"
        }
        elseif($IconForMIME) {
            $DistroLogoURLs=(GetHashTables "MIME")
            [string]$DisplayText="for file icons"
        }
        if([System.Environment]::OSVersion.Version.Build -lt 18200) {
            # Old Windows version like 2019 LTSC does not have an icon for WSL.
            $DistroLogoURLs.Add("Tux","https://www.kernel.org/theme/images/logos/favicon.png")
            Write-Host $DistroLogoURLs.'Tux'
        }
        foreach($hash in $DistroLogoURLs.GetEnumerator()) {
            [string]$Extension="png"
            if($hash.value -like "*.ico") {
                $Extension="ico"
            }
            [string]$DownloadTargetFile="$($AppDataDir)\$($hash.Name -replace '.png','').$($Extension)" # Removing and adding the extension to unify the results
            if((!(Test-Path $($DownloadTargetFile.replace('.png','.ico')))) -or ($Force)) {
                Invoke-WebRequest -Uri $hash.value -OutFile "$($DownloadTargetFile)"
                if($DownloadTargetFile -notlike "*.ico") {
                    magick.exe "$($AppDataDir)\$($hash.Name).png" -trim -resize 256x256 -background '#00000000' -gravity center -extent 256x256 "$($AppDataDir)\$($hash.Name).png"
                    magick.exe -background transparent "$($AppDataDir)\$($hash.Name).png" -define icon:auto-resize=16,24,32,48,64,72,96,128,256 "$($AppDataDir)\$($hash.Name).ico"
                }
                Write-Host "$($hash.Name).ico created and can be used $($DisplayText)." -ForegroundColor Green
            }
        }
        return # no need to return anything.
    }
    Write-Host "Downloading $($DistroName) icon" -ForegroundColor Yellow
    if($CloudDrive) {
        if($DistroName -like "OneDrive") {
            return @("","imageres.dll,-1040") # OneDrive default icon
        }
        elseif(($DistroName -like "Box") -and ([System.Environment]::OSVersion.Version.Build -lt 22000)) {
            return @("","C:\Program Files\Box\Box\WindowsFolder.ico")
        }
        # [string]$AppDataDir = "$($env:LOCALAPPDATA)\rclone"
        if( [System.Environment]::OSVersion.Version.Build -ge 22000) {
            [string]$IconComboGravity="Center" # Windows 11
            [int]$DLLIconNr=49
        }
        else {
            [string]$IconComboGravity="SouthEast"
            [int]$DLLIconNr=9
        }
        [string]$DLLIconName="Folder"
        [hashtable]$DistroLogoURLs=(GetHashTables "CloudIcons")
    }
    else {
        if( [System.Environment]::OSVersion.Version.Build -ge 22000) {
            [int]$DLLIconNr=209
        }
        else {
            [int]$DLLIconNr=216
        }
        [string]$DLLIconName="VHD"
        [hashtable]$DistroLogoURLs=(GetHashTables "LinuxDistro")
        [string]$IconComboGravity="NorthWest"
    }
    # Download basic icon for VHD file / folder. Needs 7z.exe to work
    if((!(Test-Path "$($AppDataDir)\$($DLLIconName).png")) -or ($Force)) {
        [string]$IconPNGSource="C:\Windows\SystemResources\imageres.dll.mun"
        if(-not (Test-Path "$($IconPNGSource)")) {
            $IconPNGSource="C:\Windows\System32\imageres.dll"
        }
        [string]$ZipCommand=(FindDefaultZipApp)
        if(!($ZipCommand)) {
            Write-Error "There's no 7z app installed." -Category NotInstalled
            exit
        }
        if(-not (Test-Path "$($AppDataDir)\$($DLLIconName).png")) {
            Write-Host "Extracting hard drive icon from imageres.dll" -ForegroundColor Yellow
            . "$($ZipCommand)" e -y "$($IconPNGSource)" -o"$($AppDataDir)" .rsrc/ICON/$DLLIconNr
            Move-Item "$($AppDataDir)\$($DLLIconNr)" -Destination "$($AppDataDir)\$($DLLIconName).png" -Force # Need to use Move-Item instead of Rename-Item to force overwrite of existing file.
        }
    }
    # $wc = New-Object System.Net.WebClient
    [string]$DistroLogoURL=$DistroLogoURLs."$($DistroName)"
    if($DistroLogoURL.length -ge 1) {
        # Download logo PNG
        if(!(Test-Path "$($AppDataDir)\$($DistroName).png") -or $Force) {
            Write-Host "Downloading $($DistroName)." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $DistroLogoURL -OutFile "$($AppDataDir)\$($DistroName).png" -Verbose
            # $wc.DownloadFile($DistroLogoURL,"$($AppDataDir)\$($DistroName).png")
            if(!($?)) {
                Write-Error "Download of $($DistroName) icon has failed." -Category WriteError
            }
        }
        magick.exe "$($AppDataDir)\$($DistroName).png" -trim -resize 128x128 -background '#00000000' -gravity center -extent 128x128 "$($AppDataDir)\$($DistroName).png"
        magick.exe -background transparent "$($AppDataDir)\$($DistroName).png" -define icon:auto-resize=16,24,32,48,64,72,96,128,256 "$($AppDataDir)\$($DistroName).ico"
        # if($DistroName -like "Android") {
        #     magick.exe "$($AppDataDir)\$($DistroName).png" -gravity south -crop 128x74+0+0 "$($AppDataDir)\$($DistroName).png" 
        # }
        magick.exe composite -gravity $IconComboGravity "$($AppDataDir)\$($DistroName).png" "$($AppDataDir)\$($DLLIconName).png" "$($AppDataDir)\$($DistroName)$($DLLIconName).png"
        magick.exe -background transparent "$($AppDataDir)\$($DistroName)$($DLLIconName).png" -define icon:auto-resize=16,24,32,48,64,72,96,128,256 "$($AppDataDir)\$($DistroName)$($DLLIconName).ico"
    }
    return @("$($AppDataDir)\$($DistroName).png","$($AppDataDir)\$($DistroName)$($DLLIconName).ico")
}