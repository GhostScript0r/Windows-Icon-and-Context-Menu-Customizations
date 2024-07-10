param(
    [switch]$OpenLink
)
foreach($PSFun in @("RegistryTweaks-BasicOps","RegistryTweaks-FileAssoc","CheckDefaultBrowser","BallonNotif")) {
    . "$($PSScriptRoot)\Functions\$($PSFun).ps1"
}
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
if($OpenLink) {
    BallonNotif "$($WpprXML.images.image.copyright)" -Title "$($WpprXML.images.image.headline)" # -NotifType "Info"
}
[string]$WpprLink=$WpprXML.images.image.copyrightlink
if(!(Test-Path $LocalWppr)) { # Bing wallpaper not downloaded for today
    $WpprURL=$WpprURL.Substring(0,$WpprURL.IndexOf('&'))
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($WpprURL,$LocalWppr)
 } # Download the latest wallpaper
$AllWpprs=(Get-ChildItem "$($LocalWpprLoc)\Bing*.jpg")
foreach ($OldWppr in $AllWpprs) {
    if($CurrentDate-[int]($OldWppr.BaseName -replace "[^0-9]" , '') -gt 14) {
        Remove-Item $OldWppr # Automatically remove 
    }
} # Adding versioning is necessary, as otherwise the wallpaper won't update properly
SetValue "HKCU\Control Panel\Desktop" -Name "Wallpaper" -Value "$($LocalWppr)" 2>&1>$null
SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundHistoryPath0" -Value "$($LocalWppr)" 2>&1>$null
Write-Host "There are $($AllWpprs.count-1) old wallpapers saved."
for($i=1;$i -le [math]::min($AllWpprs.count-1,4);$i++) {
    SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundHistoryPath$($i)" -Value "$(($AllWpprs[$AllWpprs.count-1-$i]).FullName)" | Out-Null
}
SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers" -Name "BackgroundType" -Type "4" -Value 0 2>&1>$null
# SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "Wallpaper" -Value "$($LocalWppr)"
# SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System" -Name "WallpaperStyle" -Type "4" -Value 0
RUNDLL32.EXE USER32.DLL,UpdatePerUserSystemParameters 1, True # Update Wallpaper
if($OpenLink) {
    # Start-Sleep -s 2
    $DefaultBrowser=(CheckDefaultBrowser)
    . "$($DefaultBrowser[0])" $WpprLink # Run Default Browser
}
else {
    CreateFileAssociation "DesktopBackground" -ShellOperations "SearchDesktopBackground" -Icon "ieframe.dll,-31048" -Command "powershell.exe -File `"$($PSCommandPath)`" -ArgumentList `"-OpenLink`"" -ShellOpDisplayName "Hintergrundbild online suchen"
    SetValue "HKCR\DesktopBackground\shell\SearchDesktopBackground" -Name "Position" -Value "Bottom"
    # No need to acquire admin rights, as this part shall always run with admin privilege when running from task scheduler
}