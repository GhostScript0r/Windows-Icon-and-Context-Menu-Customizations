function GitHubReleaseDownload {
    param(
        [parameter(ParameterSetName='RepoName', Mandatory=$true, Position=0)]
        [string]$RepoName,
        [string]$DownloadLoc="$($env:TEMP)",
        [string]$Arch="x64",
        [string]$OtherStringsInFileName="",
        [switch]$DownloadOnly,
        [string]$InstallationName
    )
    $response = Invoke-WebRequest -Uri "https://api.github.com/repos/$($RepoName)/releases/latest"
    $JsonObj = ConvertFrom-Json $response.content
    try {
        [System.Version]$GitHubVersion=$JsonObj.tag_name
    }
    catch {
        [System.Version]$GitHubVersion="0.0.0.1"
        Write-Host "Cannot get the latest version of GitHub. $($JsonObj.tag_name) cannot be converted to System.Version type. You need to manually check if the version is new or not." -ForegroundColor Magenta
        Start-Sleep -s 5
    }
    if((-not $DownloadOnly) -and ($InstallationName.length -gt 0)) {
        [bool]$AlreadyInstalled=$false
        [bool]$IsAppx=$false
        $InstalledPackage=(Get-Package | Where-Object {$_.Name -like "$($InstallationName)" } )
        if(InstalledPackage.count -eq 0) {
            $InstalledPackage=(Get-AppxPackage "$($InstallationName)")
            if(InstalledPackage.count -gt 0) {
                $AlreadyInstalled=$true
                $IsAppx=$true
            }
        }
        else {
            $AlreadyInstalled=$true
        }
        if($AlreadyInstalled) {
            Write-Host "$($InstallationName)" -ForegroundColor Black -BackgroundColor White -NoNewLine 
            Write-Host " is already installed on this PC."
            [System.Version]$InstalledVersion=$InstalledPackage[0].Version  
            if($InstalledVersion -ge $GitHubVersion) {
                Write-Host "The latest version is already installed.`n" -ForegroundColor Green
                return
            }
            else {
                Write-Host "A newer version is available: $($GitHubVersion)."
            }
        }
    }
    $AllLatestReleases=$JsonObj.assets | Where-Object {($_.name -like "*$($Arch)*") -and ($_.name -like "*$($OtherStringsInFileName)*")}
    if($AllLatestReleases.count -eq 0) {
        Write-Host "Cannot find download link for the file from GitHub. Exiting..." -ForegroundColor Red
        return
    }
    [string]$DownloadFile="$($DownloadLoc)\$($AllLatestReleases.name)"
    Write-Host "Downloading the latest release " -NoNewline
    Write-Host "$($AllLatestReleases[0].name)" -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " version " -NoNewline
    Write-Host "$($GitHubVersion)" -ForegroundColor Black -BackgroundColor White
    Invoke-WebRequest -Uri $AllLatestReleases[0].browser_download_url -OutFile "$($DownloadFile)"
    if(-not $DownloadOnly) {
        switch ((Get-Item "$($DownloadFile)").extension) {
            ".msi" {
                Start-Process -FilePath msiexec.exe -ArgumentList "/I `"$($DownloadFile)`" /quiet"
            }
            ".msixbundle" {
                Add-AppPackage -path "$($DownloadFile)"
            }
        }
    }
}
