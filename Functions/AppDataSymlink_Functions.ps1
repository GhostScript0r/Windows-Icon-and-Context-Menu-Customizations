function MkLKFolders {
    if(Test-Path "$($args[0])") {
        cmd /c rmdir $args[0] # Use CMD to prevent deletion of non empty folder that is not symlink
        if(Test-Path "$($args[0])") {
            Read-Host "
            Cannot delete directory:
            $($args[0])
            Maybe the directory is not a symlink?
            Please deal with the issue then hit ENTER to run this script again"
            Start-Process -FilePath powershell.exe -ArgumentList "-File $($PSCommandPath)"
            exit
        }
    }
    Write-Host "Creating Symlink for $($args[0])" -ForegroundColor green
    New-Item -Path "$($args[0])" -ItemType SymbolicLink -Value "$($args[1])" 
}
function MkLKFile {
    param(
        [string]$LkPath,
        [string]$LkFileName,
        [string]$TargetFilePath="",
        [switch]$HasLocalState
    )
    if(!(Test-Path "$($LkPath)")) {
        New-Item -ItemType directory -Path "$($LkPath)"
    }
    if($HasLocalState) {
        $LkPath="$($LkPath)\LocalState"
    }
    if(!(Test-Path "$($LkPath)")) {
        New-Item -ItemType directory -Path "$($LkPath)"
    }
    (Get-Item "$($LkPath)\$($LkFileName)").Delete() >$null 2>&1
    try {
        New-Item -ItemType SymbolicLink -Path "$($LkPath)\$($LkFileName)" -Value "$($TargetFilePath)"
    }
    catch {
        . "$($PSScriptRoot)\RunAsAdmin.ps1"
        RunAsAdmin "$($PSScriptRoot)\..\AppDataSymlink.ps1"
    }
}