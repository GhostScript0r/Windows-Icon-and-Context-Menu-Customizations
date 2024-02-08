function GetDistroIcon {
    [OutputType([string])]
    param(
        [parameter(ParameterSetName='DistroName', Mandatory=$false, Position=0)]
        [string]$DistroName="",
        [switch]$CloudDrive,
        [switch]$IconForLnk
    )
    # Creating Distro Icon (PNG to ICO) requires ImageMagick
    if(-not ((where.exe magick.exe) -like "*magick.exe")) {
        Write-Host "Image Magick not installed. Icons cannot be created" -ForegroundColor Red
        return ""
    }
    [string]$AppDataDir = "$($env:LOCALAPPDATA)\Packages\MicrosoftCorporationII.WindowsSubsystemForLinux_8wekyb3d8bbwe"
    [int]$DLLIconNr=209 # Hard Drive
    [hashtable]$DistroLogoURLs=@{ Ubuntu = "https://avatars.githubusercontent.com/u/4604537"; Docker = "https://avatars.githubusercontent.com/u/5429470"; Android = "https://source.android.com/static/docs/setup/images/Android_symbol_green_RGB.png"; "Kali Linux" = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Kali-dragon-icon.svg/240px-Kali-dragon-icon.svg.png" ; openSUSE = "https://en.opensuse.org/images/4/44/Button-filled-colour.png"} # You can add more distros and matching logo URLs here
    [string]$IconComboGravity="NorthWest"
    if($CloudDrive) {
        if($DistroName -like "OneDrive") {
            return @("","imageres.dll,-1040") # OneDrive default icon
        }
        [string]$AppDataDir = "$($env:LOCALAPPDATA)\rclone"
        [int]$DLLIconNr=49
        [hashtable]$DistroLogoURLs=@{ Box = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Box%2C_Inc._logo.svg/320px-Box%2C_Inc._logo.svg.png" ; DropBox = "https://avatars.githubusercontent.com/u/559357" ; pCloud = "https://blog.pcloud.com/wp-content/uploads/2018/04/pCloud-logo.png"} # You can add more distros and matching logo URLs here
        [string]$IconComboGravity="Center"
    }
    if($IconForLnk) {
        $DistroLogoURLs=@{
            "WearOS" = "https://developer.android.com/static/codelabs/data-sources/img/39f4ebe8dc4800b0_960.png" ; `
            "Samsung Galaxy Tab S6 Lite" = "https://images.samsung.com/is/image/samsung/au-galaxy-tab-s6-lite-p610-sm-p610nzaexsa-frontgray-thumb-240547259" ; `
            "Google Pixel 6" = "https://lh3.googleusercontent.com/RDGvBMFqv2RoT_B77a-7rO0zBI7ntCH1_URNNiL_PB25ThrhxXvJgbxutLVwBYcmVXiF6yL0yJMQJEQ4IZWdIDZ4uIXIBxw0WA" ; `
            "Google Pixel Watch 2" = "https://lh3.googleusercontent.com/FKUmmkF5_b8PSBMWrB2IV7rKCAlPTgClaiImbwrDBNe1FOnaQlRGWaRYmyi6cKN6iixeTiQi1TAQPLR25S_r6qA4X3OQKhlNSw=s0" ; `
            "MS Copilot" = "https://copilot.microsoft.com/rp/heOXyRFzkLjRIgrn2jdcirMbXok.png" ; `
            "Adobe Acrobat" = "https://www.adobe.com/content/dam/dx-dc/us/en/acrobat/acrobat_prodc_appicon_noshadow_1024.png.img.png"
        }
        [string]$AppDataDir = "$($env:USERPROFILE)\Links"
    }
    else {
        # Download basic icon for VHD file. Needs 7z.exe to work
        if(-Not (Test-Path "$($AppDataDir)\VHD.png")) {
            [string]$ZipAppInstalled=(Get-Childitem "C:\Program files\*zip").name
            if($ZipAppInstalled -like "PeaZip") {
                [string]$ZipCommand="C:\Program files\PeaZip\res\bin\7z\7z.exe"
            }
            elseif($ZipAppInstalled -like "7*zip") {
                [string]$ZipCommand="C:\Program files\7-zip\7z.exe"
            }
            else {
                Write-Host "ZIP program not installed. Icons cannot be created" -ForegroundColor Red
                return
            }
            . "$($ZipCommand)" e -y C:\Windows\SystemResources\imageres.dll.mun -o"$($AppDataDir)" .rsrc/ICON/$DLLIconNr
            Rename-Item -Path "$($AppDataDir)\$($DLLIconNr)" -NewName "VHD.png"
        }
    }
    $wc = New-Object System.Net.WebClient
    if($IconForLnk) {
        foreach($hash in $DistroLogoURLs.GetEnumerator()) {
            $wc.DownloadFile($hash.value,"$($AppDataDir)\$($hash.Name).png")
            magick.exe "$($AppDataDir)\$($hash.Name).png" -trim -resize 256x256 -background '#00000000' -gravity center  -extent 256x256 "$($AppDataDir)\$($hash.Name).ico"
            Write-Host "$($hash.Name).ico created and can be used in shortcuts" -ForegroundColor Green
        }
        return
    }
    [string]$DistroLogoURL=$DistroLogoURLs."$DistroName"
    if($DistroLogoURL.length -ge 1) {
        # Download logo PNG
        $wc.DownloadFile($DistroLogoURL,"$($AppDataDir)\$($DistroName).png")
        magick.exe "$($AppDataDir)\$($DistroName).png" -trim -resize 128x128 "$($AppDataDir)\$($DistroName).png"
        # if($DistroName -like "Android") {
        #     magick.exe "$($AppDataDir)\$($DistroName).png" -gravity south -crop 128x74+0+0 "$($AppDataDir)\$($DistroName).png" 
        # }
        magick.exe composite -gravity $IconComboGravity "$($AppDataDir)\$($DistroName).png" "$($AppDataDir)\VHD.png" "$($AppDataDir)\$($DistroName)VHD.ico"
    }
    return @("$($AppDataDir)\$($DistroName).png","$($AppDataDir)\$($DistroName)VHD.ico")
}