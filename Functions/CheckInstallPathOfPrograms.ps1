# Checks if a certain program is installed for all users or current user only
function CheckInstallPath {
    [OutputType([string])]
    param(
        [parameter(ParameterSetName='Program', Mandatory=$true, Position=0)]
        [string]$Program,
        [string[]]$InstallLocation=@("C:\Program Files","$($env:LOCALAPPDATA)\Programs")
    )
    if(($Program -like "*OneDrive.exe") -or ($Program -like "*SumatraPDF.exe")) {
        $InstallLocation[1]="$($env:LOCALAPPDATA)"
    }
    for($i=0;$i -lt $InstallLocation.length;$i++) {
        if(Test-Path "$($InstallLocation[$i])\$($Program)") {
            [string]$ProgramLocation="$($InstallLocation[$i])\$($Program)"
            break
        }
        else {
            [string]$ProgramLocation=""
        }
    }
    # if($i -eq $InstallLocation.length) { # None found
    #     [string]$ProgramLocation=""
    # }
    [string]$ProgramLocation=(Get-Item "$($ProgramLocation)").FullName # Use Get-Item in case the input includes wildcard ? or *
    return $ProgramLocation
}