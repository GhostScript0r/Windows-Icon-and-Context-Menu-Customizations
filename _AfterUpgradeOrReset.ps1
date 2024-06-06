param(
    [switch]$OOBE
)
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
if($OOBE) {
    RunAsAdmin "$($PSCommandPath)" -Arguments @("OOBE")
}
else {
    RunAsAdmin "$($PSCommandPath)"
}
[version]$CurrentBuildVer=[System.Environment]::OSVersion.Version
[string]$LastBuildVerFile="$($env:LOCALAPPDATA)\Microsoft\LastBuildVer.json"
if(Test-Path $LastBuildVerFile) {
    [version]$LastBuildVer=(Get-Content "$($LastBuildVerFile)" | ConvertFrom-Json)
}
else {
    Write-Host "Last Build Version not found. Assuming this is the first time the script has been running."
    [version]$LastBuildVer=0.0.0.0
    $OOBE=$true
}
if($OOBE) {
    powershell.exe -File "$($PSScriptRoot)\InstallPrograms.ps1"
    powershell.exe -File "$($PSScriptRoot)\AppData_Symlink.ps1"
    powershell.exe -File "$($PSScriptRoot)\CreateShortcutIcon.ps1"
    # Import all tasks
    $Tasks=(Get-ChildItem "$($env:userprofile)\Onedrive\Anlagen\Tasks\*.xml") # Do not include inactive tasks in the subfolder
    foreach($Task in $Tasks) {
        [xml]$TaskXML=[string](Get-Content "$($Task.FullName)")
        [string]$TaskName=$TaskXML.Task.RegistrationInfo.Uri
        if($TaskName[0] -eq "\") {
            $TaskName=$TaskName.substring(1)
        }
        # Write-Host "Converting the encoding of file to ANSI so that schtasks.exe can inport it properly..." -ForegroundColor Magenta
        $XML=(Get-Content "$($Task.FullName)")
        # $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        # [System.IO.File]::WriteAllLines("$($env:Temp)\Task.xml", $XML,[Text.Encoding]::GetEncoding(1252)) # $Utf8NoBomEncoding)
        # $XML | Out-File "$($env:Temp)\Task.xml" -encoding Ascii
        Write-Host "Importing task `"$($TaskName)`" from XML file $($Task.FullName)" -ForegroundColor Yellow
        Register-ScheduledTask -xml ($XML | out-string) -TaskName "$($TaskName)" -Force
    }
}
if($LastBuildVer -ne $CurrentBuildVer) {
    powershell.exe -File "$($PSScriptRoot)\WriteRegistry.ps1"
    Start-Sleep -s 20
    powershell.exe -File "$($PSScriptRoot)\RefreshAppAndRemoveUselessApps.ps1"
    Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1'
    # 37969115 Desktop search bar
    # 38613007 new details pane
    # 40950262 new file explorer header design
    # 42592269,42105254 End Task from taskbar menu
    # 39710659,40268500,39880030 Windows Spotlight UI 
    ViVeTool.exe /enable /id:37969115,38613007,40950262,42592269,42105254,39710659,40268500,39880030
    ConvertTo-Json -InputObject $CurrentBuildVer | Out-File $LastBuildVerFile
}