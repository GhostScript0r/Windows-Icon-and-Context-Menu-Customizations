function PowerToysFileAsso 
{
    param(
        [switch]$RegFile
    )
    if([System.Environment]::OSVersion.Version.Build -ge 19041) { # PowerToys installed
        . "$($PSScriptRoot)\CheckInstallPath.ps1"
        [string]$PowerToysInstallLoc=$(CheckInstallPath "PowerToys (Preview)")
        [string]$VSCodeLocation=$(FindVSCodeInstallPath)[0]
        if($PowerToysInstallLoc.length -gt 0) {
            . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
            CreateFileAssociation "PowerToys.RegistryPreview" -DefaultIcon "regedit.exe,-101" -shelloperations @("open","edit") -Icon @("`"$($PowerToysInstallLoc)\WinUI3Apps\PowerToys.RegistryPreview.exe`",0","`"$($VSCodeLocation)`",0") -Command @("$($PowerToysInstallLoc)\WinUI3Apps\PowerToys.RegistryPreview.exe `"----ms-protocol:ms-encodedlaunch:App?ContractId=Windows.File&Verb=open&File=%1`"","`"$($VSCodeLocation)`" `"%1`"")
        }
        if($RegFile) {
            return
        }
    }
}