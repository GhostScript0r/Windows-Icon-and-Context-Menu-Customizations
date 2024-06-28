function FindDefaultZipApp {
    [OutputType([string])]
    param()
    [string]$ZipAppInstalled=(Get-Childitem "C:\Program files\*zip").name
    if($ZipAppInstalled -like "PeaZip") {
        [string]$ZipCommand="C:\Program files\PeaZip\res\bin\7z\7z.exe"
    }
    elseif($ZipAppInstalled -like "7*zip") {
        [string]$ZipCommand="C:\Program files\7-zip\7z.exe"
    }
    else {
        Write-Host "ZIP program not installed. Icons cannot be created" -ForegroundColor Red
        [string]$ZipCommand=""
    }
    return $ZipCommand
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