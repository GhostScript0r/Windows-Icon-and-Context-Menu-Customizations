function GetThisScriptVariable {
    [OutputType([string[]])]
    param(
        [parameter(ParameterSetName='GetVariableLocal', Mandatory=$true, Position=0)]
        [Object[]]$GetVariableLocal
    )
    [string[]]$DefaultVariables=@("$","?","^","__LastHistoryId","__VSCodeHaltCompletions","__VSCodeOriginalPrompt","args","Argum","ArgumentToPass","ConfirmPreference","ConsoleFileName","DebugPreference","Error","ErrorActionPreference","ErrorView","ExecutionContext","false","foreach","FormatEnumerationLimit","Function","HOME","Host","InformationPreference","input","LASTEXITCODE","MaximumAliasCount","MaximumDriveCount","MaximumErrorCount","MaximumFunctionCount","MaximumHistoryCount","MaximumVariableCount","MyInvocation","NestedPromptLevel","Nonce","null","OutputEncoding","PID","PROFILE","ProgressPreference","PSBoundParameters","PSCommandPath","PSCulture","PSDefaultParameterValues","PSEdition","psEditor","PSEmailServer","PSFunctions","PSHOME","PSScriptRoot","PSSessionApplicationName","PSSessionConfigurationName","PSSessionOption","PSUICulture","PSVersionTable","PWD","ShellId","StackTrace","true","var","VerbosePreference","WarningPreference","WhatIfPreference","A","B")
    [string[]]$ScriptVariables=($GetVariableLocal.Name | Where-Object {$_ -NotIn $DefaultVariables})
    return $ScriptVariables
}
function RunAsAdmin {
    [OutputType([bool])]
    param(
        [parameter(ParameterSetName='PSScriptPath', Mandatory=$true, Position=0)]
        [string]$PSScriptPath, # an array to arrange multiple registry keys at once
        [string[]]$Arguments=@(),
        [switch]$CheckOnly
    )
    $Arguments=$Arguments.Where({ $_ -ne "" })  # Remove possible empty strings
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    [bool]$ScriptIsRunningOnAdmin=($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
    if(!($ScriptIsRunningOnAdmin)) {
        Write-Host "The script $(Split-Path "$($PSScriptPath)" -leaf) is NOT running with Admin privilege." -ForegroundColor Red -BackgroundColor White
        if($CheckOnly) {
            return $false
        }
        [string]$ScriptWithArgs="`"$($PSScriptPath)`"" 
        foreach($Argument in $Arguments) {
            $ScriptWithArgs=$ScriptWithArgs + " -$($Argument) "
        }
        if(Test-Path "C:\Windows\System32\sudo.exe") {
            . sudo.exe powershell.exe -File "$($ScriptWithArgs)"
        }
        else {
            Start-Process powershell.exe -ArgumentList "-File $($ScriptWithArgs)" -verb runas
        }
        exit
    }
    else {
        Write-Host "The script $(Split-Path "$($PSScriptPath)" -leaf) is running with Admin privilege" -ForegroundColor Green -BackgroundColor White
        return $null
    }
}