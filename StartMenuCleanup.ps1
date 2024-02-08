# the start menu items in C:\ProgramData and user folder are listed below. Customize in case of need
[string[]]$UnwantedLnkSys=@("WSL.lnk","Java","ImageMagick*","GhostScript*","ONLYOFFICE\*install*")
[string[]]$UnwantedLnkUsr=@("Google.lnk")
foreach ($Lnk in $UnwantedLnkSys) {Remove-Item "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\$($Lnk)" -Force -Recurse -ErrorAction SilentlyContinue} 
foreach ($Lnk in $UnwantedLnkUsr) {Remove-Item "$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\$($Lnk)" -Force -Recurse -ErrorAction SilentlyContinue}