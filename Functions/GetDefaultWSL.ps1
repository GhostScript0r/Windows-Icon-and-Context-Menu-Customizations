function GetDefaultWSL {
    [OutputType([string])]
    param(
        [switch]$GetCLSID,
        [switch]$GetWSLver,
        [switch]$GetWSLPath
    )
    if(!(Test-Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss")) { # WSL not installed
        return ""
    }
    [string]$DefaultWSL_CLSID=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss").DefaultDistribution
    if($GetCLSID) {
        return $DefaultWSL_CLSID
    }
    else {
        [string]$DistroName=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").DistributionName
        [string]$DistroPath=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").BasePath
        [int]$DistroVer=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").Version
        $DistroName=$DistroName.Replace('-',' ')
        $TextInfo = (Get-Culture).TextInfo
        $DistroName=$TextInfo.ToTitleCase($DistroName)
        if($GetWSLver) {
            return $DistroVer
        }
        elseif($GetWSLPath) {
            return $DistroPath
        }
        else {
            return $DistroName
        }
    }
}