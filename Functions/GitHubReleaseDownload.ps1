function GitHubReleaseDownload {
    param(
        [parameter(ParameterSetName='RepoName', Mandatory=$true, Position=0)]
        [string]$RepoName,
        [string]$DownloadLoc="$($env:TEMP)",
        [string]$Arch="x64",
        [string]$OtherStringsInFileName="",
        [switch]$DownloadOnly,
        [switch]$IsZIP,
        [string]$InstallationName,
        [string]$InstallPath="",
        [string]$Extension="",
        [switch]$NoUpdate,
        [string]$TokenLocation="$($env:USERPROFILE)\OneDrive\Anlagen\GithubToken.txt"
    )
    if($IsZIP) {
        $Extension=".zip"
    }
    if($InstallPath.length -eq 0) {
        $installpath="$($env:LOCALAPPDATA)\Programs\$([io.path]::GetFileNameWithoutExtension($RepoName))"
    }
    if($InstallationName.Length -eq 0) {
        $InstallationName=(Split-Path $RepoName -leaf)
    }
    [string]$VersionJSONSuffix=""
    if($InstallPath -like "$($env:LOCALAPPDATA)\Microsoft\WindowsApps") {
        # Common folder - need to distinguish the version.json files between different apps.
        [string]$VersionJSONSuffix="_$($InstallationName)"
    }
    # ___________________________________
    # Check if the user has a Token.
    if(Test-Path "$($TokenLocation)") {
        [string]$Token=(Get-Content "$($TokenLocation)")
        $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$token"))
        $headers = @{
            "Authorization" = "Basic $base64AuthInfo"
            "User-Agent" = "PowerShell"
        }
    }
    else {
        $headers = @{
            "User-Agent" = "PowerShell"
        }
    }
    # Get current information from GitHub
    $response = Invoke-WebRequest -Uri "https://api.github.com/repos/$($RepoName)/releases/latest" -Headers $headers
    $JsonObj = ConvertFrom-Json $response.content
    try {
        [Version]$GitHubVersion=($JsonObj.tag_name -replace "[^0-9.]")
    }
    catch {
        [Version]$GitHubVersion="0.0.0.0"
        Write-Host "Cannot get the latest version of $($RepoName) on Github. $($JsonObj.tag_name) cannot be converted to Version type. You need to manually check if the version is new or not." -ForegroundColor Magenta
    }
    [bool]$AlreadyInstalled=$false
    $AllLatestReleases=$JsonObj.assets | Where-Object {($_.name -like "*$($Arch)*") -and ($_.name -like "*$($OtherStringsInFileName)*") -and ($_.name -like "*$($Extension)")}
    if($AllLatestReleases.count -eq 0) {
        Write-Host "Cannot find download link for the file $(Split-Path $RepoName -leaf) from GitHub. Exiting..." -ForegroundColor Red
        return
    }
    [string]$DownloadFile="$($DownloadLoc)\$($AllLatestReleases[0].name)"
    if($DownloadOnly) {
        New-Item -ItemType Directory -Path "$($InstallPath)" -ea 0
        $DownloadFile="$($installpath)"+"\"+"$([io.path]::GetFileNameWithoutExtension($RepoName)+$Extension)"
        if(Test-Path "$($DownloadFile)") {
            $AlreadyInstalled=$true
        }
    }
    elseif(((-not $DownloadOnly) -and ($InstallationName.length -gt 0)) -or ($IsZIP)) {
        [bool]$IsAppx=$false
        if($IsZIP) {
            if(-not $InstallPath) {
                [string]$InstallPath="$($env:LOCALAPPDATA)\Programs\$($InstallationName)"
            }
            if(Test-Path "$($InstallPath)\*") {
                $AlreadyInstalled=$true
            }
            else {
                New-Item "$($InstallPath)" -Itemtype Directory -ea 0
            }
        }
        else {
            $InstalledPackage=(Get-Package | Where-Object {$_.Name -like "$($InstallationName)" } )
            if(!($InstalledPackage.count -gt 0)) {
                $InstalledPackage=(Get-AppxPackage "$($InstallationName)")
                if(InstalledPackage.count -gt 0) {
                    $AlreadyInstalled=$true
                    $IsAppx=$true
                }
            }
            else {
                $AlreadyInstalled=$true
            }
        }
    }
    if($AlreadyInstalled) {
        Write-Host "$($InstallationName)" -ForegroundColor Black -BackgroundColor White -NoNewLine 
        Write-Host " is already installed on this PC." -ForegroundColor Green
        if($IsZIP -or $DownloadOnly) {
            [Version]$InstalledVersion=(Get-Content "$($InstallPath)\version$($VersionJSONSuffix).json" -ea 0 | ConvertFrom-Json)
        }
        else {
            [Version]$InstalledVersion=$InstalledPackage[0].Version
        }
        if(-not [bool]$InstalledVersion) {
            Write-Host "Cannot determin the local version number." -ForegroundColor Red
            $InstalledVersion=0.0.0.0
        }
        if($InstalledVersion -ge $GitHubVersion) {
            Write-Host "The latest version is already installed.`n" -ForegroundColor Green
            return # No need for further downloading
        }
        elseif($NoUpdate) {
            Write-Host "Update checking skipped, as this program can auto update itself."
        }
        else {
            Write-Host "A newer version is available:" -ForegroundColor Yellow -NoNewLine
            Write-Host " $($GitHubVersion)." -BackgroundColor White -ForegroundColor Black
            $AlreadyInstalled=$false
        }
    }
    Write-Host "Downloading the latest release " -NoNewline
    Write-Host "$($AllLatestReleases[0].name)" -ForegroundColor Black -BackgroundColor White -NoNewline
    Write-Host " version " -NoNewline
    Write-Host "$($GitHubVersion)" -ForegroundColor Black -BackgroundColor White
    Invoke-WebRequest -Uri $AllLatestReleases[0].browser_download_url -OutFile "$($DownloadFile)"
    if(!($DownloadOnly)) {
        switch ((Get-Item "$($DownloadFile)").extension) {
            ".msi" {
                msiexec.exe /I "$($DownloadFile)" /quiet
            }
            ".msixbundle" {
                Add-AppPackage -path "$($DownloadFile)"
            }
            ".zip" {
                [string]$UnzippedPath="$($DownloadLoc)\$($DownloadFile.BaseName)_Unzipped"
                Write-Host "Expanding $($DownloadFile) ZIP file to $($UnzippedPath)"
                Expand-Archive -Path "$($DownloadFile)" -DestinationPath "$($UnzippedPath)" -Force
                $ExpandedFiles=(Get-ChildItem "$($UnzippedPath)")
                if(($ExpandedFiles.count -eq 1) -and ($ExpandedFiles[0].Mode -like "d-----")) { # The expanded archive has its own root folder
                    $UnzippedPath=$ExpandedFiles[0].FullName
                }
                Move-Item -Path "$($UnzippedPath)\*" -Destination "$($InstallPath)" -Force
            }
        }
    }
    [string]$GitHubVersionString=$GitHubVersion
    Convertto-Json -InputObject $GitHubVersionString | Out-File "$($InstallPath)\version$($VersionJSONSuffix).json"
}