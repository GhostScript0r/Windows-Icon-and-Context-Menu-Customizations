# This is a fork of https://github.com/lord-carlos/nvidia-update
# Windows version and arch fixed to Win11 64-bit
# Task scheduler part removed

param (
    [switch]$clean # Perform clean install
)
if(-Not (Test-Path "$($env:TEMP)\NVIDIA-Driver")) {
    mkdir "$($env:TEMP)\NVIDIA-Driver"
}
Write-Host "Attempting to detect currently installed driver version..." -ForegroundColor Yellow
try {
    $nVidiaGPU = Get-WmiObject -ClassName Win32_VideoController | Where-Object { $_.Name -like "*NVIDIA*" }
    $InstalledNVDriverVer = ($nVidiaGPU.DriverVersion.Replace('.', '')[-5..-1] -join '').insert(3, '.')
}
catch {
    Write-Host -ForegroundColor Red -BackgroundColor White "No compatible Nvidia GPU detected"
    exit
}
Write-Host "Driver v$($InstalledNVDriverVer) for $($nVidiaGPU.Name) installed" -ForegroundColor Cyan
$link = Invoke-WebRequest -Uri "https://www.nvidia.com/Download/processFind.aspx?osid=57&whql=1&dtcid=1" -Method GET -UseBasicParsing
$link -match '<td class="gridItem">([^<]+?)</td>' | Out-Null
$LatestNVDriverVer = $matches[1]
Write-Host "Latest version ist `t`t$LatestNVDriverVer"
if (!$clean -and ($LatestNVDriverVer -eq $InstalledNVDriverVer)) {
    Write-Host "The installed version is the same as the latest version. No further activities needed." -ForegroundColor Green
    Start-Sleep -s 3
    exit
}
# Create a new temp folder NVIDIA
New-Item -Path "$($env:TEMP)\NVIDIA" -ItemType Directory 2>&1 | Out-Null
# Generating the download link
$url = "https://international.download.nvidia.com/Windows/$LatestNVDriverVer/$LatestNVDriverVer-desktop-win10-win11-64bit-international-dch-whql.exe"
$rp_url = "https://international.download.nvidia.com/Windows/$LatestNVDriverVer/$LatestNVDriverVer-desktop-win10-win11-64bit-international-dch-whql-rp.exe"
# Downloading the installer
$dlFile = "$($env:TEMP)\NVIDIA-Driver\$LatestNVDriverVer.exe"
Write-Host "Downloading the latest version to $dlFile"
Start-BitsTransfer -Source $url -Destination $dlFile

if ($?) {
    Write-Host "Proceed..."
}
else {
    Write-Host "Download failed, trying alternative RP package now..."
    Start-BitsTransfer -Source $rp_url -Destination $dlFile
}

# Extracting setup files
$extractFolder = "$($env:TEMP)\NVIDIA-Driver\$LatestNVDriverVer"
$filesToExtract = "Display.Driver HDAudio NVI2 PhysX EULA.txt ListDevices.txt setup.cfg setup.exe"
Write-Host "Download finished, extracting the files now..." -ForegroundColor Green
Start-Process -FilePath "C:\Program Files\PeaZip\res\bin\7z\7z.exe" -NoNewWindow -ArgumentList "x -bso0 -bsp1 -bse1 -aoa $dlFile $filesToExtract -o""$extractFolder""" -wait
# Remove unneeded dependencies from setup.cfg
(Get-Content "$extractFolder\setup.cfg") | Where-Object { $_ -notmatch 'name="\${{(EulaHtmlFile|FunctionalConsentFile|PrivacyPolicyFile)}}' } | Set-Content "$extractFolder\setup.cfg" -Encoding UTF8 -Force


# Installing drivers
Write-Host "Installing Nvidia drivers now..."
$install_args = "-passive -noreboot -noeula -nofinish -s"
if ($clean) {
    $install_args = $install_args + " -clean"
}
Start-Process -FilePath "$extractFolder\setup.exe" -ArgumentList $install_args -wait
# Cleaning up downloaded files
Write-Host "Deleting downloaded files"
Remove-Item "$($env:TEMP)\NVIDIA-Driver\" -Recurse -Force