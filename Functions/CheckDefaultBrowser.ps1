function CheckDefaultBrowser {
    [OutputType([hashtable])]
    param(
        [switch]$EdgeCoreUpdateOnly,
        [switch]$ForceEdgeIfAvailable
        # [switch]$AddEdgeCoreToBrowserOption
    )
    [string]$BrowserPath="C:\Program Files (x86)\Microsoft\Edge\Application"
    if((Test-Path "$($BrowserPath)") -and ((Get-Item "$($BrowserPath)").Mode -like "d-----")) { # Edge installed properly and is not a symlink
        if(Test-Path "$($BrowserPath)\msedge.exe") {
            [string[]]$EdgeUninstaller=(Get-Item "$($BrowserPath)\*.*.*.*\Installer\setup.exe").FullName
            foreach($Uninstaller in $EdgeUninstaller) {
                Start-Process -FilePath "$($Uninstaller)" -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall"
            }
        }
        if($EdgeCoreUpdateOnly) { # No need to update the edge version, as msedge.exe is not under a path with changing folder name
            return
        }
    }
    else{ # Edge is removed. EdgeCore and EdgeWebView not known
        [string]$EdgeSymbolicLink="C:\Program Files (x86)\Microsoft\EdgeCore\CurrentVersion"
        [string[]]$InstalledEdgeCores=(Get-Item "C:\Program Files (x86)\Microsoft\EdgeCore\*.*.*.*\msedge.exe")
        if($InstalledEdgeCores.count -eq 0) { # MS Edge Core is also removed
            $BrowserPath="" # No Edge exists.
            if($EdgeCoreUpdateOnly) {
                return
            }
        }
        else { # EdgeCore still exists
            [version]$CurrentEdgeVersion=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView").Version
            if((Test-Path "$($EdgeSymbolicLink)") -and ((Get-Item "$($EdgeSymbolicLink)").Mode -like "d----l")) { # Edge is a link
                [version]$LinkedEdgeVersion=Split-Path (Get-Item "$($EdgeSymbolicLink)" | Select-Object -ExpandProperty Target) -leaf
                Write-Host "Currently linked Edge version is $($LinkedEdgeVersion)"
            }
            else {
                [version]$LinkedEdgeVersion=0.0.0.0
            }
            Write-Host "Latest installed Edge version is $($CurrentEdgeVersion)"
            if($LinkedEdgeVersion -lt $CurrentEdgeVersion) {
                (Get-Item "$($EdgeSymbolicLink)" -ea 0).Delete() # Remove the symlink without touching the target
                New-Item -Path "C:\Program Files (x86)\Microsoft\Edge" -ItemType directory -Erroraction ignore
                cmd.exe /c mklink /d "$($EdgeSymbolicLink)" "..\EdgeCore\$($CurrentEdgeVersion)"
            }
            $BrowserPath="$($EdgeSymbolicLink)\msedge.exe"
        }
        if($EdgeCoreUpdateOnly) {
            return
        }
    }
    [string]$BrowserOpenAction="`"$($BrowserPath)`" --single-argument %1"
    if([System.Environment]::OSVersion.Version.Build -ge 22000) {
        [string]$BrowserIcon="ieframe.dll,-31065"
    }
    else {
        [string]$BrowserIcon="`"$($BrowserPath)`",0"
    }
    [string]$OpenInBrowserText="@ieframe.dll,-21819" # Open in Edge
    if($BrowserPath -like "*msedge.exe") {
        . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
        foreach($EdgeURL in @("http","https","microsoft-edge")) {
            CreateFileAssociation $EdgeURL -shelloperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)" -IsURLProtocol
        }
        CreateFileAssociation "MSEdgeHTM" -DefaultIcon "ieframe.dll,-210" -shelloperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)" -MUIVerb "@ieframe.dll,-21819"
    }
    if(!(($ForceEdgeIfAvailable) -and ($BrowserPath -like "*msedge.exe"))) {
        [string[]]$ChromePath=(Get-ChildItem "C:\Program Files\Google\Chrome*\Application\chrome.exe" -ErrorAction SilentlyContinue).FullName+(Get-ChildItem "$($env:LocalAppdata)\Google\Chrome*\Application\chrome.exe" -ErrorAction SilentlyContinue).FullName
        [string]$FirefoxPath="C:\Program Files\Mozilla Firefox\firefox.exe"
        [bool]$ChromeInstalled=$ChromePath.count
        if($ChromeInstalled) {
            [string]$BrowserPath=$ChromePath[0]
        }
        elseif(Test-Path $FirefoxPath) {
            [string]$BrowserPath=$FirefoxPath
        }
        else {
            foreach($ChromeHTMLReg in @("HKCR\ChromeHTML","HKCR\Applications\chrome.exe","HKCR\ChromePDF")) {
                Remove-Item -Path "Registry::$($ChromeHTMLReg)" -Force -Recurse -ea 0
            }
        }
        [string]$BrowserOpenAction="`"$($BrowserPath)`" `"%1`""
        [string]$BrowserIcon="`"$($BrowserPath)`",0"
        [string]$OpenInBrowserText="@SearchFolder.dll,-10496" # Im Browser öffnen
    }
    if ($BrowserPath.length -eq 0) {
        write-host "No browser installed." -ForegroundColor Red -BackgroundColor White
        return @{}
    }
    return @{Path=$BrowserPath;OpenAction=$BrowserOpenAction;Icon=$BrowserIcon;Text=$OpenInBrowserText}
}

function EdgeCoreUpdate {
    [string[]]$InstalledEdgeCores=(Get-Item "C:\Program Files (x86)\Microsoft\EdgeCore\*.*.*.*\msedge.exe")
        if($InstalledEdgeCores.count -eq 0) { # MS Edge Core is also removed
            Write-Host "Edge Core removed!"
            return
        }
    $response = Invoke-WebRequest -Uri "https://edgeupdates.microsoft.com/api/products"
    $json = $response.Content | ConvertFrom-Json
    Write-Host $json
    [string[]]$latestVersions = ($json | Where-Object { $_.Product -eq "Stable" }).Releases | Select-Object -ExpandProperty ProductVersion
    [version]$latestVersion=$latestVersions[0]
    [version]$CurrentEdgeVersion=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView").Version
    if($latestVersion -gt $CurrentEdgeVersion) {
        # New version available. Run Edge WebView2 repair.
        Start-Process "C:\Program Files (x86)\Microsoft\EdgeUpdate\MicrosoftEdgeUpdate.exe" -ArgumentList "/install appguid={F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}&appname=Microsoft%20Edge%20WebView&needsadmin=true&repairtype=windowsonlinerepair /installsource otherinstallcmd /silent"
    }
    CheckDefaultBrowser -EdgeCoreUpdateOnly
}