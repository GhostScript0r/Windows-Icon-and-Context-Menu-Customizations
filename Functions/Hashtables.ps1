function GetHashTables {
    [OutputType([hashtable])]
    param(
        [parameter(ParameterSetName='TableName', Mandatory=$true, Position=0)]
        [string]$TableName
    )
    [hashtable]$Result=@{}
    switch($TableName) {
        "CloudWebsites" {
            $Result=@{"OneDrive"="onedrive.live.com"
                "Google_Photos"=  "photos.google.com"
                "pCloud"=  "my.pcloud.com"
                "Google_Drive"=  "drive.google.com"
                "Box"=  "app.box.com"
                "Dropbox"="dropbox.com"
                MEGA="mega.nz"
                Koofr="app.koofr.net"
            }
        }
        "IconForLnk" {
            $Result=@{
                "WearOS" = "https://developer.android.com/static/codelabs/data-sources/img/39f4ebe8dc4800b0_960.png"
                "Samsung Galaxy Tab S6 Lite" = "https://images.samsung.com/is/image/samsung/au-galaxy-tab-s6-lite-p610-sm-p610nzaexsa-frontgray-thumb-240547259"
                "Google Pixel 6" = "https://lh3.googleusercontent.com/RDGvBMFqv2RoT_B77a-7rO0zBI7ntCH1_URNNiL_PB25ThrhxXvJgbxutLVwBYcmVXiF6yL0yJMQJEQ4IZWdIDZ4uIXIBxw0WA"
                "Google Pixel Watch 2" = "https://lh3.googleusercontent.com/FKUmmkF5_b8PSBMWrB2IV7rKCAlPTgClaiImbwrDBNe1FOnaQlRGWaRYmyi6cKN6iixeTiQi1TAQPLR25S_r6qA4X3OQKhlNSw=s0"
                "MS Copilot" = "https://copilot.microsoft.com/rp/heOXyRFzkLjRIgrn2jdcirMbXok.png"
                "OWASP Juice Shop" = "https://raw.githubusercontent.com/juice-shop/juice-shop/develop/frontend/src/assets/public/images/JuiceShop_Logo.png" ; `
                "Adobe Acrobat" = "https://upload.wikimedia.org/wikipedia/commons/1/1a/Adobe_Reader_XI_icon.png"
                Google_Photos="https://www.gstatic.com/social/photosui/images/logo/1x/photos_512dp.png"
                Flickr="https://combo.staticflickr.com/pw/images/favicons/favicon-228.png"
                "Google Drive"="https://ssl.gstatic.com/docs/doclist/images/drive_2022q3_32dp.png";
                "Google Docs"="https://www.gstatic.com/images/branding/product/1x/docs_2020q4_96dp.png"
                "Google Play Books"="https://www.gstatic.com/images/branding/product/2x/play_books_96dp.png"
                YouTube="https://www.youtube.com/s/desktop/bad7252b/img/logos/favicon_144x144.png"
                "Epic Games Store"="https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Epic_Games_logo.svg/207px-Epic_Games_logo.svg.png"
                Spotify="https://open.spotifycdn.com/cdn/images/favicon.0f31d2ea.ico"
                "ZDF Mediathek"="https://www.zdf.de/static/0.110.2341/img/appicons/zdf-152.png"
                "ARD Mediathek"="https://www.tagesschau.de/resources/assets/image/favicon/favicon.ico"
                "Radio"="https://raw.githubusercontent.com/segler-alex/RadioDroid/master/app/src/main/res/drawable-xxxhdpi/ic_launcher.png"
            }
        }
        "CloudIcons" {
            $Result=@{ 
                Box = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Box%2C_Inc._logo.svg/320px-Box%2C_Inc._logo.svg.png"
                DropBox = "https://avatars.githubusercontent.com/u/559357"
                pCloud = "https://blog.pcloud.com/wp-content/uploads/2018/04/pCloud-logo.png"
                MEGA="https://avatars.githubusercontent.com/u/4920706"
                rClone="https://avatars.githubusercontent.com/u/24937341"
                "Google Drive"="https://ssl.gstatic.com/images/branding/product/2x/hh_drive_96dp.png"
                Koofr="https://app.koofr.net/app/favicon.png"
            } # You can add more distros and matching logo URLs here  
        }
        "LinuxDistro" {
            $Result=@{ Ubuntu = "https://avatars.githubusercontent.com/u/4604537"
                Docker = "https://avatars.githubusercontent.com/u/5429470"
                Android = "https://source.android.com/static/docs/setup/images/Android_symbol_green_RGB.png"
                "Kali Linux" = "https://gitlab.com/kalilinux/documentation/graphic-resources/-/raw/master/kali-icon/sqaure-1/kali-dragon-square-detailed.png" ; `
                openSUSE = "https://en.opensuse.org/images/4/44/Button-filled-colour.png" # You can add more distros and matching logo URLs here
            }
        }
        "ContextMenuLinks" {
            $Result=@{
                Google_Photos = "photos.google.com"
                Flickr = "flickr.com"
                "Adobe Document Cloud"="acrobat.adobe.com/link/documents/files/"
                "Google Play Books"="play.google.com/books"
                "Google Docs"="docs.google.com"
                "YouTube"="youtu.be"
                "YouTube Studio"="studio.youtube.com"
                "Epic Games Store"="store.epicgames.com"
                "Spotify"="open.spotify.com"
                "YouTube Music"="music.youtube.com"
                "ZDF Mediathek"="zdf.de"
                "ARD Mediathek"="ardmediathek.de"
                "Radio"="radiolise.gitlab.io"
            }
        }
    }
    return $Result
}
