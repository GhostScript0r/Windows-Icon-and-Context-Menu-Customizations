# Need to open a photo in MSEdge first
$wshell = new-object -com wscript.shell
[int]$ScannedPhotos=0
[int]$PhotosThatUseSpace=0
[string[]]$NamesOfPhotos=@()
[bool]$LastPhotoUsesSpace=$false
while($true) {
    [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [string]$PhotoName=""
    while($PhotoName.Length -eq 0) {
        $wshell.appactivate('Edge') | Out-Null
        Start-Sleep -s 4
        [System.Windows.Forms.SendKeys]::SendWait("^{a}")
        Start-Sleep -s 2
        [System.Windows.Forms.SendKeys]::SendWait("^{c}") # Copy entire page text
        [string[]]$CopiedText=(Get-Clipboard)
        [string]$PhotoName=($CopiedText -like "*.jpg") + ($CopiedText -like "*.MP4*") + ($CopiedText -like "*.M4V*") + ($CopiedText -like "*.PNG*")
    }
    $CopiedText | Out-File "$($env:USERPROFILE)\Downloads\LastCheckedPhoto.txt"
    [string]$NotUsingSpace=($CopiedText -like "Dieses Element wird nicht auf deinen Kontospeicherplatz angerechnet*")
    [string]$LackGeoTag=($CopiedText -like "Aufnahmeort hinzuf*gen")
    if($LackGeoTag.length -gt 1) {
        Write-Host "$($PhotoName) lacks GeoTag" -ForegroundColor Yellow -BackgroundColor Black
        "$($PhotoName)"| Out-File "$($env:USERPROFILE)\Downloads\PhotosWOGeoTag.txt" -Append
    }
    if($NotUsingSpace.length -eq 0) {
        Write-Host "$($PhotoName) is using drive space!" -ForegroundColor Magenta
        $NamesOfPhotos = $NamesOfPhotos + $PhotoName
        $PhotosThatUseSpace+=1
        $CopiedText | Out-File "$($env:USERPROFILE)\Downloads\PhotoThatUsedSpace$($PhotosThatUseSpace).txt"
        [System.Windows.Forms.SendKeys]::SendWait("+{d}") # Emulate
        Start-Sleep -s 7
        if($PhotoName -like "*.mp4") { # Creating of video link normally takes longer
            Start-Sleep -s 14
        }
        [System.Windows.Forms.SendKeys]::SendWait("+{a}")
        [bool]$LastPhotoUsesSpace=$true
        "$($PhotoName)"| Out-File "$($env:USERPROFILE)\Downloads\PhotosUsingSpace.txt" -Append
    }
    else {
        Start-Sleep -s 3
        if($PhotoName -like "*.mp4") { # A video file
            Start-Sleep -s 5 # Wait for a total of 8 seconds
        }
        [bool]$LastPhotoUsesSpace=$false
    While($true) {
        [System.Windows.Forms.SendKeys]::SendWait("{pgdn}")
        Start-Sleep -s 1
    }
    }
    $ScannedPhotos+=1
}