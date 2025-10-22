param(
    [switch]$OOBE
)
. "$($PSScriptRoot)\Functions\RunAsAdmin.ps1"
if($OOBE) {
    RunAsAdmin "$($PSCommandPath)" -Arguments @("OOBE")
}
else {
    RunAsAdmin "$($PSCommandPath)"
}
[version]$CurrentBuildVer=[System.Environment]::OSVersion.Version
[string]$LastBuildVerFile="$($env:LOCALAPPDATA)\Microsoft\LastBuildVer.json"
if(Test-Path $LastBuildVerFile) {
    [version]$LastBuildVer=(Get-Content "$($LastBuildVerFile)" | ConvertFrom-Json)
}
else {
    Write-Host "Last Build Version not found. Assuming this is the first time the script has been running."
    [version]$LastBuildVer=0.0.0.0
    $OOBE=$true
}
# [version]$LastBuildVer=0.0.0.0
if($OOBE) {
    # Change computer name - Comment out if not needed
    # [string]$WishedComputerName="MACBOOKPRO"
    # if($env:computername -notlike $WishedComputerName) {
    #     Rename-Computer -NewName $WishedComputerName
    #     . "$($PSScriptRoot)\Functions\BallonNotif.ps1"
    #     BallonNotif "Need to restart computer to make sure the change of computer name takes effect."
    # }
    # Run accompanying programs
    powershell.exe -File "$($PSScriptRoot)\InstallPrograms.ps1"
    powershell.exe -File "$($PSScriptRoot)\AppDataSymlink.ps1"
    powershell.exe -File "$($PSScriptRoot)\CreateShortcutIcon.ps1"
    # Import all tasks
    powershell.exe -File "$($PSScriptRoot)\ImportTasks.ps1"
    # Local security policy: Enable current account to create symbolic link
    ChangeSecPol -Category "user_rights" -Item "SeCreateSymbolicLinkPrivilege" -Add -Value "*$((Get-WmiObject win32_useraccount | Where-Object {$_.name -like $env:username}).sid)"
    # ___________PowerCfg settings_____________
    # Disable sleep or hibernate after some time
    [string[]]$PowerCFGOptions=@("monitor-timeout-dc","monitor-timeout-ac","standby-timeout-dc","standby-timeout-ac","disk-timeout-dc","disk-timeout-ac","hibernate-timeout-dc","hibernate-timeout-ac")
    [string[]]$PowerCFGValue=@(30,30,60,0,0,0,0,0)
    for($i=0;$i -lt $PowerCFGOptions.count;$i++) {
        Write-Host "Changing option $($PowerCFGOptions[$i]) to $($PowerCFGValue[$i])"
        powercfg.exe /change $PowerCFGOptions[$i] $PowerCFGValue[$i]
    }
    # Change "close lid" to do nothing
    [string]$CurrentPowerCfgScheme=$(powercfg.exe -getactivescheme) -replace "Power Scheme GUID: ",""
    [string]$CurrentPowerCfgScheme=($CurrentPowerCfgScheme -split " ")[0]
    powercfg.exe -SETACVALUEINDEX $CurrentPowerCfgScheme 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0 # close lid does noting while powered on
    powercfg.exe -SETDCVALUEINDEX $CurrentPowerCfgScheme 4f971e89-eebd-4455-a8de-9e59040e7347 5ca83367-6e45-459f-a27b-476b1d01c936 0 # close lid does noting while on battery
    [version]$LastBuildVer=0.0.0.0 # Force next part to run
}
if($LastBuildVer -ne $CurrentBuildVer) {
    powershell.exe -File "$($PSScriptRoot)\WriteRegistry.ps1"
    Start-Sleep -s 5
    if((Get-AppxPackage "Microsoft.WindowsStore").count -eq 1) { # Only when MS Store is installed (non LTSC version).
        powershell.exe -File "$($PSScriptRoot)\RefreshAppAndRemoveUselessApps.ps1"
    }
    Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1'
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
    if($CurrentBuildVer.Build -ge 22600) { # Latest Windows 11
        # 37969115 Desktop search bar
        # 38613007 new details pane
        # 40950262 new file explorer header design
        # 42592269,42105254 End Task from taskbar menu
        # 39710659,40268500,39880030 Windows Spotlight UI 
        # ViVeTool.exe /enable /id:37969115,38613007,40950262,42592269,42105254,39710659,40268500,39880030
    }
    if($CurrentBuildVer.Build -ge 26100) { # With Microsoft Recall
        Dism.exe /Online /Disable-Feature /FeatureName:"Recall"​
    }
    [string]$CurrentBuildVer_Str=$CurrentBuildVer
    ConvertTo-Json -InputObject $CurrentBuildVer_Str | Out-File $LastBuildVerFile
}
if($OOBE) {
    # ________ Enable and disable Windows features __________
    [string[]]$FeaturesToEnable=@("LegacyComponents","DirectPlay","HypervisorPlatform","Microsoft-Hyper-V-All","Microsoft-Hyper-V","Microsoft-Hyper-V-Tools-All","Microsoft-Hyper-V-Management-Clients","Microsoft-Hyper-V-Services","Microsoft-Hyper-V-Management-PowerShell","Microsoft-Hyper-V-Hypervisor")
    if($CurrentBuildVer.Build -ge 19042) {
        $FeaturesToEnable=$FeaturesToEnable+@("Microsoft-Windows-Subsystem-Linux")
    }
    [string[]]$FeaturesToDisable=@("Printing-XPSServices-Features","MediaPlayback")
    foreach($Feature in $FeaturesToEnable) {
        if((Get-WindowsOptionalFeature -online -FeatureName $Feature).State -like "Disabled") {
            Enable-WindowsOptionalFeature -online -featurename $feature
        }
    }
    foreach($Feature in $FeaturesToDisable) {
        if((Get-WindowsOptionalFeature -online -FeatureName $Feature).State -like "Enabled") {
            Disable-WindowsOptionalFeature -online -featurename $feature
        }
    }
    # Install Powershell modules
    foreach($PSMdl in @("Microsoft.PowerShell.ConsoleGuiTools")) {
        Install-Module $PSMdl
    }
}