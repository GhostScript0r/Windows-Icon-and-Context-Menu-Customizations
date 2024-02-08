function CheckDefaultBrowser {
    [OutputType([string[]])]
    param()
    Write-Host "Checking what is the default browser, Chrome or Edge?"
    [string]$ChromePath="C:\Program Files\Google\Chrome\Application\chrome.exe"
    [bool]$ChromeInstalled=(Test-Path "$($ChromePath)")
    if($ChromeInstalled) {
        [string]$BrowserPath=$ChromePath
        [string]$BrowserOpenAction="`"$($BrowserPath)`" %1"
        [string]$BrowserIcon="`"$($BrowserPath)`",0"
        [string]$OpenInBrowserText="@SearchFolder.dll-10496"
    }
    else { # Microsoft Edge Installed
        [string]$BrowserPath="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
        [string]$BrowserOpenAction="`"$($BrowserPath)`" --single-argument %1"
        [string]$BrowserIcon="ieframe.dll,-31065"
        [string]$OpenInBrowserText="@ieframe.dll,-21819"
    }
    return @($BrowserPath,$BrowserOpenAction,$BrowserIcon,$OpenInBrowserText)
}