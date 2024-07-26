function GetDefaultWSL {
    [OutputType([string])]
    param(
        [switch]$GetCLSID,
        [switch]$GetWSLver,
        [switch]$GetVHDPath,
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
        [string]$DistroVHDPath=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").BasePath
        [int]$DistroVer=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").Version
        $DistroName=$DistroName.Replace('-',' ')
        $TextInfo = (Get-Culture).TextInfo
        $DistroName=$TextInfo.ToTitleCase($DistroName)
        if($GetWSLver) {
            return $DistroVer
        }
        elseif($GetVHDPath) {
            return $DistroVHDPath
        }
        elseif($GetWSLPath) {
            switch($Distrover) {
                1 {
                    return $DistroVer+"\rootfs"
                }
                2 {
                    return "\\wsl.localhost\$($DistroName.Replace(' ','-'))"
                }
            }
        }
        else {
            return $DistroName
        }
    }
}

function GetExtraWSL {
    [OutputType([string[]])]
    param(
        [switch]$GetWSLver,
        [switch]$GetVHDPath,
        [switch]$GetCLSID,
        [switch]$GetWSLPath
    )
    if($(GetDefaultWSL) -eq "") { # No WSL installed
        return
    }
    [System.Collections.ArrayList]$AllDistroCLSIDs=[string[]](Split-path (Get-ChildItem "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss").Name -leaf)
    $AllDistroCLSIDs.Remove($(GetDefaultWSL -GetCLSID)) # Remove Default WSL distro
    if($GetCLSID) {
        return $AllDistroCLSIDs
    }
    [string[]]$DistroNames=@()
    [string[]]$distroVHDpaths=@()
    [int[]]$DistroVers=@()
    foreach($DistroCLSID in [string[]]$AllDistroCLSIDs) {
        [string]$DistroName=(Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DistroCLSID)").DistributionName
        $DistroName=$DistroName.Replace('-',' ')
        $TextInfo = (Get-Culture).TextInfo
        $DistroName=$TextInfo.ToTitleCase($DistroName)
        $DistroNames=$DistroNames+@($DistroName)
        $distroVHDpaths=$distroVHDpaths+@((Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DistroCLSID)").BasePath)
        $DistroVers=$DistroVers+@((Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss\$($DefaultWSL_CLSID)").Version)
    }
    [string[]]$DistroPaths=@("")*$DistroNames.count
    for($i=0;$i -lt $DistroPaths.count;$i++) {
        $DistroPaths[$i]=$DistroPaths[$i].replace(' ','-')
        switch($DistroVers[$i]) {
            1 {
                $DistroPaths[$i]=$DistroVHDPaths[$i]+"\rootfs"
            }
            2 {
                $DistroPaths[$i]="\\wsl.localhost\$($DistroPaths[$i])"
            }
        }
    }
    if($GetVHDPath) {
        return $distroVHDpaths
    }
    elseif($GetWSLVer) {
        return $DistroVers
    }
    elseif($GetWSLPath) {
        return $DistroPaths
    }
    return $DistroNames
}