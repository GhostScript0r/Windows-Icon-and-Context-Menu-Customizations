. "$($PSScriptRoot)\Functions\GitHubReleaseDownload.ps1"
[string[]]$TermuxApps=@("termux/termux-app","termux/termux-api","termux/termux-styling","GhostScript0r/termux-boot")
foreach($app in $TermuxApps) {
    GitHubReleaseDownload $app -Arch "apk" -DownloadOnly -DownloadLoc "$((New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path)" -OtherStringsInFileName "debug"
}