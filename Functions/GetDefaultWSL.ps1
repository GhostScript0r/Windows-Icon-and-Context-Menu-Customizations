function GetDefaultWSL {
    [OutputType([string])]
    param(
        [switch]$GetCLSID
    )
    if(!(Test-Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss")) { # WSL not installed
        $DistroName=""
        Remove-Item "Registry::HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" # Remove WSL entry
    }
    [string]$DefaultWSL_CLSID=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss").DefaultDistribution
    if($GetCLSID) {
        return $DefaultWSL_CLSID
    }
    else {
        [string]$DistroName=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").DistributionName
        Return $DistroName
    }
}