function FindDefaultZipApp {
    [OutputType([string])]
    param(
        [switch]$GetName,
        [switch]$GetIcon,
        [switch]$GetFM
    )
    [string]$ZipAppInstalled=(Get-Childitem "C:\Program files\*zip").name
    if($ZipAppInstalled -like "PeaZip") {
        [string]$ZipCommand="C:\Program files\PeaZip\res\bin\7z\7z.exe"
        [string]$ZipFM="C:\Program files\PeaZip\PeaZip.exe"
        [string]$ZipName="PeaZip"
    }
    elseif($ZipAppInstalled -like "7*zip") {
        [string]$ZipCommand="C:\Program files\7-zip\7z.exe"
        [string]$ZipName="7-Zip"
        [string]$ZipFM="C:\Program files\7-zip\7zFM.exe"

    }
    else {
        Write-Host "ZIP program not installed. Icons cannot be created" -ForegroundColor Red
        return ""
    }
    if($GetName) { return $ZipName }
    elseif($GetIcon) { return "`"$($ZipFM)`",0" }
    elseif($GetFM) { return $ZipFM }
    else { return $ZipCommand }
}

function ExtractZip {
    param(
        [parameter(ParameterSetName='Source', Mandatory=$true, Position=0)]
        [string]$Source,
        [string]$Destination="$($env:temp)",
        [string]$SubFolder=""
    )
    [string]$ZipApp=(FindDefaultZipApp)
    if($ZipApp.length -eq 0) {
        Write-Host "No 7z program installed. Using default extractors (only works with ZIP and CAB files!)" -ForegroundColor Yellow -BackgroundColor Black
        Expand-Archive -Path "$($Source)" -DestinationPath "$($Destination)" -Force
    }
    else {
        . "$($ZipApp)" e -y "$($Source)" -o"$($Destionation)" $SubFolder
    }
}