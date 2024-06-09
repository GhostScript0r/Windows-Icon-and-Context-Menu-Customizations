param(
    [switch]$OpenLink
)
. "$($PSScriptRoot)\Functions\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\Functions\RegistryTweaks-FileAssoc.ps1"
. "$($PSScriptRoot)\Functions\CheckDefaultBrowser.ps1"
function GetBingXML {
    [OutputType([xml])]
    param(
    )
    [xml]$BingWpprXML=(Invoke-WebRequest -uri "https://www.bing.com/HPImageArchive.aspx?format=xml&idx=0&n=1").Content
    return $BingWpprXML
}
# Main part of the script
[string]$LocalWpprLoc="$($env:LOCALAPPDATA)\Microsoft\Windows\WallpaperBackup\Theme\DesktopBackground"
New-Item -ItemType Directory -Path "$($LocalWpprLoc)" -ea 0
[string]$CurrentDate=((Get-Date -Format "o") -replace "[^0-9]" , '')
[int]$CurrentDate=$CurrentDate.Substring(0,8)
[string]$LocalWppr="$($LocalWpprLoc)\Bing$($CurrentDate).jpg"
[xml]$WpprXML=(GetBingXML)
while(!($?)) { # ERROR Level 1: No internet connection or internet connection failed
    Write-Host "Keine Verbindung zum Bing-Wallpaper-Server" -ForegroundColor White -BackgroundColor Red
    Start-Sleep -s 300 # Repeat each 5 minutes, until internet connection is established
    [xml]$WpprXML=(GetBingXML)
}
[string]$WpprURL= "https://bing.com" + $WpprXML.images.image.url
Write-Host $WpprXML.images.image.copyright
[string]$WpprLink=$WpprXML.images.image.copyrightlink
if(!(Test-Path $LocalWppr)) { # Bing wallpaper not downloaded for today
    $WpprURL=$WpprURL.Substring(0,$WpprURL.IndexOf('&'))
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($WpprURL,$LocalWppr) # Download the latest wallpaper
    foreach ($OldWppr in (Get-ChildItem "$($LocalWpprLoc)\Bing*.jpg")) {
        if($OldWppr.Name -notlike "Bing$($CurrentDate).jpg") {
            Remove-Item $OldWppr # Remove Older Bing Wallpapers
        }
    } # Adding versioning is necessary, as otherwise the wallpaper won't update properly
}
else {
    SetValue "HKCU\Control Panel\Desktop" -Name "Wallpaper" -Value "$($LocalWppr)"
    SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundHistoryPath0" -Value "$($LocalWppr)"
    SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Type "4" -Value 0
    SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "Wallpaper" -Value "$($LocalWppr)"
    SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "WallpaperStyle" -Type "4" -Value 0
    Start-Process "RUNDLL32.EXE" -ArgumentList "USER32.DLL,UpdatePerUserSystemParameters 1, True" # Update Wallpaper
}
if($OpenLink) {
    Start-Sleep -s 2
    $DefaultBrowser=(CheckDefaultBrowser)
    . "$($DefaultBrowser[0])" $WpprLink # Run Default Browser
}
else {
    CreateFileAssociation "DesktopBackground" -ShellOperations "SearchDesktopBackground" -Icon "ieframe.dll,-31048" -Command "powershell.exe -File `"$($PSCommandPath)`" -ArgumentList `"-OpenLink`"" -ShellOpDisplayName "Hintergrundbild online suchen"
    SetValue "HKCR\DesktopBackground\shell\SearchDesktopBackground" -Name "Position" -Value "Bottom"
    # No need to acquire admin rights, as this part shall always run with admin privilege when running from task scheduler
}