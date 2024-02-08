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
    [xml]$BingWpprXML=(Invoke-WebRequest -uri "https://www.bing.com/HPImageArchive.aspx?format=xml&idx=0&n=1&mkt=de-DE").Content
    return $BingWpprXML
}
[xml]$WpprXML=(GetBingXML)
while(!($?)) {
    # No internet connection or internet connection failed
    Write-Host "Keine Verbindung zum Bing-Wallpaper-Server" -ForegroundColor White -BackgroundColor Red
    Start-Sleep -s 300
    [xml]$WpprXML=(GetBingXML)
}
[string]$WpprURL= "https://bing.com" + $WpprXML.images.image.url
Write-Host $WpprXML.images.image.copyright
[string]$WpprLink=$WpprXML.images.image.copyrightlink
$WpprURL=$WpprURL.Substring(0,$WpprURL.IndexOf('&'))
[string]$LocalWppr="$($env:LOCALAPPDATA)\Microsoft\Windows\WallpaperBackup\Theme\DesktopBackground\Bing.jpg"
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($WpprURL,$LocalWppr)
Set-ItemProperty -Path "Registry::HKCU\Control Panel\Desktop" -Name "Wallpaper" -Value $LocalWppr
RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters 1, True
if($OpenLink) {
    Start-Sleep -s 2
    $DefaultBrowser=(CheckDefaultBrowser)

    . "$($DefaultBrowser[0])" $WpprLink
}
else {
    CreateFileAssociation "DesktopBackground" -ShellOperations "SearchDesktopBackground" -Icon "ieframe.dll,-31048" -Command "powershell.exe -File `"$($PSCommandPath)`" -ArgumentList `"-OpenLink`"" -ShellOpDisplayName "Hintergrundbild online suchen"
SetValue "HKCR\DesktopBackground\shell\SearchDesktopBackground" -Name "Position" -Value "Bottom"
}