function CheckDefaultBrowser {
    [OutputType([hashtable])]
    param(
        [switch]$EdgeCoreUpdateOnly,
        [switch]$ForceEdgeIfAvailable
        # [switch]$AddEdgeCoreToBrowserOption
    )
    [string]$BrowserPath="C:\Program Files (x86)\Microsoft\Edge\Application"
    if((Test-Path "$($BrowserPath)") -and ((Get-Item "$($BrowserPath)").Mode -like "d-----")) { # Edge installed properly and is not a symlink
        if($EdgeCoreUpdateOnly) { # No need to update the edge version, as msedge.exe is not under a path with changing folder name
            return
        }
    }
    else{
        [string]$EdgeSymbolicLink=$BrowserPath
        [string[]]$InstalledEdgeCores=(Get-Item "C:\Program Files (x86)\Microsoft\EdgeCore\*.*.*.*\msedge.exe")
        if($InstalledEdgeCores.count -eq 0) { # MS Edge Core also Not Installed
            $BrowserPath="" # No edge exists.
            if($EdgeCoreUpdateOnly) {
                return
            }
        }
        else {
            [version]$CurrentEdgeVersion=(Get-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView").Version
            if((Test-Path "$($EdgeSymbolicLink)") -and ((Get-Item "$($EdgeSymbolicLink)").Mode -like "d----l")) {
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
        if($EdgeCoreUpdateOnly) { return }
    }
    [string]$BrowserOpenAction="`"$($BrowserPath)`" --single-argument %1"
    if([System.Environment]::OSVersion.Version.Build -ge 22000) {
        [string]$BrowserIcon="ieframe.dll,-31065"
    }
    else {
        [string]$BrowserIcon="`"$($BrowserPath)`",0"
    }
    [string]$OpenInBrowserText="@ieframe.dll,-21819"
    if($BrowserPath -like "*msedge.exe") {
        . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
        foreach($EdgeURL in @("http","https","microsoft-edge")) {
            CreateFileAssociation $EdgeURL -shelloperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)" -IsURLProtocol
        }
        CreateFileAssociation "MSEdgeHTM" -DefaultIcon "ieframe.dll,-210" -shelloperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)" -MUIVerb "@ieframe.dll,-21819"
    }
    if(!(($ForceEdgeIfAvailable) -and ($BrowserPath -like "*msedge.exe"))) {
        [string[]]$ChromePath=(Get-ChildItem "C:\Program Files\Google\Chrome*\Application\chrome.exe" -ErrorAction SilentlyContinue).FullName+(Get-ChildItem "$($env:LocalAppdata)\Google\Chrome*\Application\chrome.exe" -ErrorAction SilentlyContinue).FullName
        [bool]$ChromeInstalled=$ChromePath.count
        if($ChromeInstalled) {
            [string]$BrowserPath=$ChromePath[0]
            [string]$BrowserOpenAction="`"$($BrowserPath)`" `"%1`""
            [string]$BrowserIcon="`"$($BrowserPath)`",0"
            [string]$OpenInBrowserText="@SearchFolder.dll-10496"
        }
        else {
            foreach($ChromeHTMLReg in @("HKCR\ChromeHTML","HKCR\Applications\chrome.exe","HKCR\ChromePDF")) {
                Remove-Item -Path "Registry::$($ChromeHTMLReg)" -Force -Recurse -ea 0
            }
        }
    }
    if ($BrowserPath.length -eq 0) {
        write-host "No browser installed." -ForegroundColor Red -BackgroundColor White
        return @{}
    }
    return @{Path=$BrowserPath;OpenAction=$BrowserOpenAction;Icon=$BrowserIcon;Text=$OpenInBrowserText}
}

function EdgeCoreUpdate {
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