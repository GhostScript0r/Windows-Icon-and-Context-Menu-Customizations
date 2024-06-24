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