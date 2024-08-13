. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
function HideDriveLetters {
    . "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
    [string[]]$DriveLetters=(Get-PSDrive -PSProvider FileSystem).Name
    [int]$HiddenDrives=0
    if(($DriveLetters -contains "A")) { # -and ((Get-Volume A).FileSystemLabel -like "Google Drive*")
        $HiddenDrives=$HiddenDrives+1
    }
    if(($DriveLetters -contains "P") -and ((Get-Volume P).FileSystemLabel -like "pcloud*")) { # Check the drive label extra to see if it's actually pCloud drive
        # PCloud installed
        $HiddenDrives=$HiddenDrives+[math]::pow(2,15) # P is the 16th letter in Latin alphabet. begin with A  2^0=1, P will be 2^15. The equvilant in Python is 2 ** 15
        MkDirCLSID "{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Name "pCloud" -FolderType 9 -TargetPath "P:\" -Icon "`"C:\Program Files\pCloud Drive\pcloud.exe`",0"
    }
    else {
        Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -Recurse -ea 0 # Google Drive entry
        Remove-Item -Path "Registry::HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -Recurse -ea 0
    }
    SetValue "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDrives" -Type 4 -Value $HiddenDrives
}
function ChangeBitLockerIcon {
    if([System.Environment]::OSVersion.Version.Build -ge 22000) {
        [string]$BitLockerIcon="shell32.dll,-194"
    }
    else {
        [string]$BitLockerIcon="sppcomapi.dll,-1"
    }
    CreateFileAssociation "Drive" -ShellOperations @("manage-bde","encrypt-bde","encrypt-bde-elev","pintohome") -Icon @($BitLockerIcon,$BitLockerIcon,$BitLockerIcon,"shell32.dll,-322") # Hard drives
}