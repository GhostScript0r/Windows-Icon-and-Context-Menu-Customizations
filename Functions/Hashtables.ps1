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
                "Proton_Drive"="drive.proton.me"
                JottaCloud="www.jottacloud.com"
            }
        }
        "CloudIcons" {
            $Result=@{ 
                Box = "https://upload.wikimedia.org/wikipedia/commons/thumb/5/57/Box%2C_Inc._logo.svg/320px-Box%2C_Inc._logo.svg.png"
                DropBox = "https://avatars.githubusercontent.com/u/559357"
                pCloud = "https://blog.pcloud.com/wp-content/uploads/2018/04/pCloud-logo.png"
                MEGA="https://avatars.githubusercontent.com/u/4920706"
                rClone="https://avatars.githubusercontent.com/u/24937341"
                "Google_Drive"="https://ssl.gstatic.com/images/branding/product/2x/hh_drive_96dp.png"
                Koofr="https://app.koofr.net/app/favicon.png"
                nextCloud="https://upload.wikimedia.org/wikipedia/commons/thumb/6/60/Nextcloud_Logo.svg/141px-Nextcloud_Logo.svg.png"
                "Proton_Drive"="https://proton.me/favicons/favicon-32x32.png"
                JottaCloud="https://jottacloud.com/cms_assets/images/fav-icon/favicon-196x196.png"
            } 
        }
        "LinuxDistro" {
            $Result=@{ 
                Ubuntu = "https://avatars.githubusercontent.com/u/4604537"
                Docker = "https://avatars.githubusercontent.com/u/5429470"
                Android = "https://source.android.com/static/docs/setup/images/Android_symbol_green_RGB.png"
                "Kali Linux" = "https://gitlab.com/kalilinux/documentation/graphic-resources/-/raw/master/kali-icon/sqaure-1/kali-dragon-square-detailed.png" ; `
                openSUSE = "https://en.opensuse.org/images/4/44/Button-filled-colour.png" # You can add more distros and matching logo URLs here
            }
        }
        "ContextMenuLinks" {
            $Result=@{
                "Google Photos" = "photos.google.com"
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
        "IconForLnk" {
            $Result=@{
                "WearOS" = "https://developer.android.com/static/codelabs/data-sources/img/39f4ebe8dc4800b0_960.png"
                "Samsung Galaxy Tab S6 Lite" = "https://images.samsung.com/is/image/samsung/au-galaxy-tab-s6-lite-p610-sm-p610nzaexsa-frontgray-thumb-240547259"
                "Google Pixel 6" = "https://lh3.googleusercontent.com/RDGvBMFqv2RoT_B77a-7rO0zBI7ntCH1_URNNiL_PB25ThrhxXvJgbxutLVwBYcmVXiF6yL0yJMQJEQ4IZWdIDZ4uIXIBxw0WA"
                "Google Pixel 8a"="https://lh3.googleusercontent.com/V3FhyMfBy2thvj3xcAX0j_mgvQsEbhi7f1GpWmN7wk8AHp_B4kzRkrgwOWDBa3P_xwYZZXQy9ZA3ps3a71p1ICFTBVzociSyHiw=e365-pa-nu-s0"
                "Google Pixel Watch 2" = "https://lh3.googleusercontent.com/FKUmmkF5_b8PSBMWrB2IV7rKCAlPTgClaiImbwrDBNe1FOnaQlRGWaRYmyi6cKN6iixeTiQi1TAQPLR25S_r6qA4X3OQKhlNSw=s0"
                "Redmi Note 5" = "https://i01.appmifile.com/webfile/globalimg/2018/02141/overall-ram-img.png"
                "MS Copilot" = "https://copilot.microsoft.com/rp/heOXyRFzkLjRIgrn2jdcirMbXok.png"
                "OWASP Juice Shop" = "https://raw.githubusercontent.com/juice-shop/juice-shop/develop/frontend/src/assets/public/images/JuiceShop_Logo.png" ; `
                "Google Photos"="https://www.gstatic.com/social/photosui/images/logo/1x/photos_512dp.png"
                "Flickr"="https://combo.staticflickr.com/pw/images/favicons/favicon-228.png"
                "Google Drive"="https://ssl.gstatic.com/docs/doclist/images/drive_2022q3_32dp.png";
                "Google Docs"="https://www.gstatic.com/images/branding/product/1x/docs_2020q4_96dp.png"
                "Google Play Books"="https://www.gstatic.com/images/branding/product/2x/play_books_96dp.png"
                "YouTube"="https://www.youtube.com/s/desktop/bad7252b/img/logos/favicon_144x144.png"
                "Epic Games Store"="https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Epic_Games_logo.svg/207px-Epic_Games_logo.svg.png"
                "Spotify"="https://open.spotifycdn.com/cdn/images/favicon.0f31d2ea.ico"
                "ZDF Mediathek"="https://www.zdf.de/static/0.110.2341/img/appicons/zdf-152.png"
                "ARD Mediathek"="https://www.tagesschau.de/resources/assets/image/favicon/favicon.ico"
                "Radio"="https://raw.githubusercontent.com/segler-alex/RadioDroid/master/app/src/main/res/drawable-xxxhdpi/ic_launcher.png"
                "Google Keep"="https://www.gstatic.com/images/branding/product/2x/keep_2020q4_48dp.png"
                "GMail"="https://www.gstatic.com/images/branding/product/2x/gmail_2020q4_64dp.png"
                "Google Play Store"="https://www.gstatic.com/images/branding/product/2x/play_prism_64dp.png"
                "Google Calender"="https://www.gstatic.com/images/branding/product/2x/calendar_2020q4_64dp.png"
            }
            for($i=1;$i -le 31; $i++) {
                $Result.Add("Google Calender $($i)","https://ssl.gstatic.com/calendar/images/dynamiclogo_2020q4/calendar_$($i)_2x.png")
            }
        }
        "MIME" {
            $Result=@{
                Music = "https://www.apkmirror.com/wp-content/themes/APKMirror/ap_resize/ap_resize.php?src=https%3A%2F%2Fdownloadr2.apkmirror.com%2Fwp-content%2Fuploads%2F2016%2F03%2F56dcd1bab5e3c.png&w=192&h=192&q=100"
                Image = "https://www.apkmirror.com/wp-content/themes/APKMirror/ap_resize/ap_resize.php?src=https%3A%2F%2Fdownloadr2.apkmirror.com%2Fwp-content%2Fuploads%2F2018%2F03%2F5aaa2f8d1e34e.png&w=192&h=192&q=100"
                Video = "https://www.apkmirror.com/wp-content/themes/APKMirror/ap_resize/ap_resize.php?src=https%3A%2F%2Fdownloadr2.apkmirror.com%2Fwp-content%2Fuploads%2F2017%2F03%2F58b87eeae2441.png&w=192&h=192&q=100"
                "Adobe Acrobat" = "https://www.apkmirror.com/wp-content/themes/APKMirror/ap_resize/ap_resize.php?src=https%3A%2F%2Fdownloadr2.apkmirror.com%2Fwp-content%2Fuploads%2F2019%2F04%2F5cac8328dad65.png&w=192&h=192&q=100" # "https://upload.wikimedia.org/wikipedia/commons/1/1a/Adobe_Reader_XI_icon.png"
            }
        }
    }
    return $Result
}
