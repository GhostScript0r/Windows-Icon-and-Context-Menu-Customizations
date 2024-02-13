function RunAsAdmin {
    param(
        [parameter(ParameterSetName='PSScriptPath', Mandatory=$true, Position=0)]
        [string]$PSScriptPath, # an array to arrange multiple registry keys at once
        [string[]]$Arguments=@()
    )
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    [bool]$ScriptIsRunningOnAdmin=($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    if(!($ScriptIsRunningOnAdmin)) {
        Write-Host "The script $(Split-Path "$($PSScriptPath)" -leaf) is NOT running with Admin privilege." -ForegroundColor Red -BackgroundColor White
        [string]$ScriptWithArgs="`"$($PSScriptPath)`"" 
        foreach($Argument in $Arguments) {
            $ScriptWithArgs=$ScriptWithArgs + " -$($Argument) "
        }
        Start-Process powershell.exe -ArgumentList "-File $($ScriptWithArgs)" -verb runas
        exit
    }
    else {
        Write-Host "The script $(Split-Path "$($PSScriptPath)" -leaf) is running with Admin privilege" -ForegroundColor Green -BackgroundColor White
        return
    }
}