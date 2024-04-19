function CheckDefaultBrowser {
    [OutputType([string[]])]
    param()
    Write-Host "Checking what is the default browser, Chrome or Edge?"
    [string[]]$ChromePath=(Get-ChildItem "C:\Program Files\Google\Chrome*\Application\chrome.exe" -ErrorAction SilentlyContinue).FullName+(Get-ChildItem "$($env:LocalAppdata)\Google\Chrome*\Application\chrome.exe" -ErrorAction SilentlyContinue).FullName
    [bool]$ChromeInstalled=$ChromePath.count
    if($ChromeInstalled) {
        [string]$BrowserPath=$ChromePath[0]
        [string]$BrowserOpenAction="`"$($BrowserPath)`" `"%1`""
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