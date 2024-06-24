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
    [int]$DLLIconNr=209 # Hard Drive
    [hashtable]$DistroLogoURLs=@{ Ubuntu = "https://avatars.githubusercontent.com/u/4604537"; `
        Docker = "https://avatars.githubusercontent.com/u/5429470"; `
        Android = "https://source.android.com/static/docs/setup/images/Android_symbol_green_RGB.png"; `
        "Kali Linux" = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Kali-dragon-icon.svg/240px-Kali-dragon-icon.svg.png" ; `
        openSUSE = "https://en.opensuse.org/images/4/44/Button-filled-colour.png" # You can add more distros and matching logo URLs here
    }
    [string]$IconComboGravity="NorthWest"
    [string]$AppDataDir = "$($env:USERPROFILE)\Links"
    Write-Host "Downloading $($DistroName) icon"
    if($CloudDrive) {
        if($DistroName -like "OneDrive") {
            return @("","imageres.dll,-1040") # OneDrive default icon
        }
        [string]$AppDataDir = "$($env:LOCALAPPDATA)\rclone"
        [int]$DLLIconNr=49
        [hashtable]$DistroLogoURLs=@{ 
            Box = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Box%2C_Inc._logo.svg/320px-Box%2C_Inc._logo.svg.png" ; `
            DropBox = "https://avatars.githubusercontent.com/u/559357" ; `
            pCloud = "https://blog.pcloud.com/wp-content/uploads/2018/04/pCloud-logo.png"`
        } # You can add more distros and matching logo URLs here
        [string]$IconComboGravity="Center"
    }
    elseif($IconForLnk) {
        $DistroLogoURLs=@{
            "WearOS" = "https://developer.android.com/static/codelabs/data-sources/img/39f4ebe8dc4800b0_960.png" ; `
            "Samsung Galaxy Tab S6 Lite" = "https://images.samsung.com/is/image/samsung/au-galaxy-tab-s6-lite-p610-sm-p610nzaexsa-frontgray-thumb-240547259" ; `
            "Google Pixel 6" = "https://lh3.googleusercontent.com/RDGvBMFqv2RoT_B77a-7rO0zBI7ntCH1_URNNiL_PB25ThrhxXvJgbxutLVwBYcmVXiF6yL0yJMQJEQ4IZWdIDZ4uIXIBxw0WA" ; `
            "Google Pixel Watch 2" = "https://lh3.googleusercontent.com/FKUmmkF5_b8PSBMWrB2IV7rKCAlPTgClaiImbwrDBNe1FOnaQlRGWaRYmyi6cKN6iixeTiQi1TAQPLR25S_r6qA4X3OQKhlNSw=s0" ; `
            "MS Copilot" = "https://copilot.microsoft.com/rp/heOXyRFzkLjRIgrn2jdcirMbXok.png" ; `
            "OWASP Jiuce Shop" = "https://raw.githubusercontent.com/juice-shop/juice-shop/develop/frontend/src/assets/public/images/JuiceShop_Logo.png" ; `
            "Adobe Acrobat" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Adobe_Acrobat_DC_logo_2020.svg/256px-Adobe_Acrobat_DC_logo_2020.svg.png" # "https://www.adobe.com/content/dam/dx-dc/us/en/acrobat/acrobat_prodc_appicon_noshadow_1024.png.img.png"
        }
        # [string]$AppDataDir = "$($env:USERPROFILE)\Links"
    }
    else {
        Write-Host "This is an icon for WSL distro or WSA"
        # Download basic icon for VHD file. Needs 7z.exe to work
        if(!(Test-Path "$($AppDataDir)\VHD.png")) {
            [string]$ZipCommand=(FindDefaultZipApp)
            if(!($ZipCommand)) {
                exit
            }
            Write-Host "Extracting hard drive icon from imageres.dll" -ForegroundColor Yellow
            . "$($ZipCommand)" e -y C:\Windows\SystemResources\imageres.dll.mun -o"$($AppDataDir)" .rsrc/ICON/$DLLIconNr
            Rename-Item -Path "$($AppDataDir)\$($DLLIconNr)" -NewName "VHD.png"
        }
    }
    $wc = New-Object System.Net.WebClient
    if($IconForLnk) {
        foreach($hash in $DistroLogoURLs.GetEnumerator()) {
            [string]$DownloadTargetFile="$($AppDataDir)\$($hash.Name -replace '.png','').png" # Removing and adding the extension to unify the results
            if(!(Test-Path $DownloadTargetFile)) {
                $wc.DownloadFile($hash.value,$DownloadTargetFile)
            }
            magick.exe "$($AppDataDir)\$($hash.Name).png" -trim -resize 256x256 -background '#00000000' -gravity center  -extent 256x256 "$($AppDataDir)\$($hash.Name).ico"
            Write-Host "$($hash.Name).ico created and can be used in shortcuts" -ForegroundColor Green
        }
        return
    }
    [string]$DistroLogoURL=$DistroLogoURLs."$($DistroName)"
    if($DistroLogoURL.length -ge 1) {
        # Download logo PNG
        if(!(Test-Path "$($AppDataDir)\$($DistroName).png")) {
            $wc.DownloadFile($DistroLogoURL,"$($AppDataDir)\$($DistroName).png")
            if(!($?)) {
                Write-Host "Download of $($DistroName) icon has failed." -ForegroundColor Red -BackgroundColor White
            }
        }
        magick.exe "$($AppDataDir)\$($DistroName).png" -trim -resize 128x128 "$($AppDataDir)\$($DistroName).png"
        # if($DistroName -like "Android") {
        #     magick.exe "$($AppDataDir)\$($DistroName).png" -gravity south -crop 128x74+0+0 "$($AppDataDir)\$($DistroName).png" 
        # }
        magick.exe composite -gravity $IconComboGravity "$($AppDataDir)\$($DistroName).png" "$($AppDataDir)\VHD.png" "$($AppDataDir)\$($DistroName)VHD.ico"
    }
    return @("$($AppDataDir)\$($DistroName).png","$($AppDataDir)\$($DistroName)VHD.ico")
}