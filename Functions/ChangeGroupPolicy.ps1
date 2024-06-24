function ChangeSecPol {
    param(
        [string]$Item,
        [string]$Value,
        [switch]$Add
    )
    . "$($PSScriptRoot)\RunAsAdmin.ps1"
    if(-not $(RunAsAdmin "$($PSCommandPath)" -CheckOnly)) {
        Write-Host "SecEdit won't run without administator privilege." -ForegroundColor Red -BackgroundColor White
        exit        
    }
    SecEdit.exe /export /cfg "$($env:TEMP)\secpol.cfg"
    [string]$SecSetting=((Get-Content "$($env:TEMP)\secpol.cfg") | Where-Object {$_ -like "$($Item) =*"})
    if([string]$SecSetting -like "*$($Value)*") {
        Write-Host "Security Policy already set. No need to do anything."
        return
    }
    if($Add) {
        [string]$NewSetting="$($SecSetting),$($Value)"
    }
    else {
        [string]$NewSetting="$($Item) = $($Value)"
    }
    ((Get-Content "$($env:TEMP)\secpol.cfg").Replace("$($SecSetting)","$($NewSetting)")) | Out-File "$($env:TEMP)\secpol.cfg"
    SecEdit.exe /import /db C:\Windows\security\database\secedit.sdb /cfg "$($env:TEMP)\secpol.cfg" /overwrite /quiet
}