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
    [string]$AppDataDir = "$($env:USERPROFILE)\Links"
    Write-Host "Downloading $($DistroName) icon"
    if($IconForLnk) {
        $DistroLogoURLs=@{
            "WearOS" = "https://developer.android.com/static/codelabs/data-sources/img/39f4ebe8dc4800b0_960.png" ; `
            "Samsung Galaxy Tab S6 Lite" = "https://images.samsung.com/is/image/samsung/au-galaxy-tab-s6-lite-p610-sm-p610nzaexsa-frontgray-thumb-240547259" ; `
            "Google Pixel 6" = "https://lh3.googleusercontent.com/RDGvBMFqv2RoT_B77a-7rO0zBI7ntCH1_URNNiL_PB25ThrhxXvJgbxutLVwBYcmVXiF6yL0yJMQJEQ4IZWdIDZ4uIXIBxw0WA" ; `
            "Google Pixel Watch 2" = "https://lh3.googleusercontent.com/FKUmmkF5_b8PSBMWrB2IV7rKCAlPTgClaiImbwrDBNe1FOnaQlRGWaRYmyi6cKN6iixeTiQi1TAQPLR25S_r6qA4X3OQKhlNSw=s0" ; `
            "MS Copilot" = "https://copilot.microsoft.com/rp/heOXyRFzkLjRIgrn2jdcirMbXok.png" ; `
            "OWASP Juice Shop" = "https://raw.githubusercontent.com/juice-shop/juice-shop/develop/frontend/src/assets/public/images/JuiceShop_Logo.png" ; `
            "Adobe Acrobat" = "https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Adobe_Acrobat_DC_logo_2020.svg/256px-Adobe_Acrobat_DC_logo_2020.svg.png" # "https://www.adobe.com/content/dam/dx-dc/us/en/acrobat/acrobat_prodc_appicon_noshadow_1024.png.img.png"
        }
        if([System.Environment]::OSVersion.Version.Build -lt 18200) {
            # Old Windows version like 2019 LTSC does not have an icon for WSL.
            $DistroLogoURLs.Add("Tux","https://www.kernel.org/theme/images/logos/favicon.png")
            Write-Host $DistroLogoURLs.'Tux'
        }
        foreach($hash in $DistroLogoURLs.GetEnumerator()) {
            [string]$DownloadTargetFile="$($AppDataDir)\$($hash.Name -replace '.png','').png" # Removing and adding the extension to unify the results
            if(!(Test-Path $DownloadTargetFile)) {
                Invoke-WebRequest -Uri $hash.value -OutFile "$($DownloadTargetFile)"
            }
            magick.exe "$($AppDataDir)\$($hash.Name).png" -trim -resize 256x256 -background '#00000000' -gravity center  -extent 256x256 "$($AppDataDir)\$($hash.Name).png"
            magick.exe -background transparent  "$($AppDataDir)\$($hash.Name).png" -define icon:auto-resize=16,24,32,48,64,72,96,128,256 "$($AppDataDir)\$($hash.Name).ico"
            Write-Host "$($hash.Name).ico created and can be used in shortcuts" -ForegroundColor Green
        }
        return # no need to return anything.
    }
    elseif($CloudDrive) {
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
        [hashtable]$DistroLogoURLs=@{ 
            Box = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Box%2C_Inc._logo.svg/320px-Box%2C_Inc._logo.svg.png" ; `
            DropBox = "https://avatars.githubusercontent.com/u/559357" ; `
            pCloud = "https://blog.pcloud.com/wp-content/uploads/2018/04/pCloud-logo.png"`
        } # You can add more distros and matching logo URLs here  
    }
    else {
        if( [System.Environment]::OSVersion.Version.Build -ge 22000) {
            [int]$DLLIconNr=209
        }
        else {
            [int]$DLLIconNr=216
        }
        [string]$DLLIconName="VHD"
        [hashtable]$DistroLogoURLs=@{ Ubuntu = "https://avatars.githubusercontent.com/u/4604537"; `
            Docker = "https://avatars.githubusercontent.com/u/5429470"; `
            Android = "https://source.android.com/static/docs/setup/images/Android_symbol_green_RGB.png"; `
            "Kali Linux" = "https://upload.wikimedia.org/wikipedia/commons/thumb/2/2b/Kali-dragon-icon.svg/240px-Kali-dragon-icon.svg.png" ; `
            openSUSE = "https://en.opensuse.org/images/4/44/Button-filled-colour.png" # You can add more distros and matching logo URLs here
        }
        [string]$IconComboGravity="NorthWest"
    }
    # Download basic icon for VHD file / folder. Needs 7z.exe to work
    if(!(Test-Path "$($AppDataDir)\$($DLLIconName).png")) {
        [string]$IconPNGSource="C:\Windows\SystemResources\imageres.dll.mun"
        if(-not (Test-Path "$($IconPNGSource)")) {
            $IconPNGSource="C:\Windows\System32\imageres.dll"
        }
        [string]$ZipCommand=(FindDefaultZipApp)
        if(!($ZipCommand)) {
            Write-Error "There's no 7z app installed." -Category NotInstalled
            exit
        }
        Write-Host "Extracting hard drive icon from imageres.dll" -ForegroundColor Yellow
        . "$($ZipCommand)" e -y "$($IconPNGSource)" -o"$($AppDataDir)" .rsrc/ICON/$DLLIconNr
        Rename-Item -Path "$($AppDataDir)\$($DLLIconNr)" -NewName "$($DLLIconName).png"
    }
    # $wc = New-Object System.Net.WebClient
    [string]$DistroLogoURL=$DistroLogoURLs."$($DistroName)"
    if($DistroLogoURL.length -ge 1) {
        # Download logo PNG
        if(!(Test-Path "$($AppDataDir)\$($DistroName).png")) {
            Weite-Host "Downloading $($DistroName)." -ForegroundColor Yellow
            Invoke-WebRequest -Uri $DistroLogoURL -OutFile "$($AppDataDir)\$($DistroName).png"
            # $wc.DownloadFile($DistroLogoURL,"$($AppDataDir)\$($DistroName).png")
            if(!($?)) {
                Write-Error "Download of $($DistroName) icon has failed." -Category WriteError
            }
        }
        magick.exe "$($AppDataDir)\$($DistroName).png" -trim -resize 128x128 "$($AppDataDir)\$($DistroName).png"
        # if($DistroName -like "Android") {
        #     magick.exe "$($AppDataDir)\$($DistroName).png" -gravity south -crop 128x74+0+0 "$($AppDataDir)\$($DistroName).png" 
        # }
        magick.exe composite -gravity $IconComboGravity "$($AppDataDir)\$($DistroName).png" "$($AppDataDir)\$($DLLIconName).png" "$($AppDataDir)\$($DistroName)$($DLLIconName).png"
        magick.exe -background transparent "$($AppDataDir)\$($DistroName)$($DLLIconName).png" -define icon:auto-resize=16,24,32,48,64,72,96,128,256 "$($AppDataDir)\$($DistroName)$($DLLIconName).ico"
    }
    return @("$($AppDataDir)\$($DistroName).png","$($AppDataDir)\$($DistroName)$($DLLIconName).ico")
}