. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
RunAsAdmin "$($PSCommandPath)"
$Tasks=(Get-ChildItem "$($PSScriptRoot)\..\Tasks\*.xml") # Do not include inactive tasks in the subfolder
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