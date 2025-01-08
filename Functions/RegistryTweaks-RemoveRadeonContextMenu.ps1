. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\RegistryTweaks-AccessControl.ps1"
function RemoveAMDContextMenu {
    [string]$AMDcontextMenu="HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers\ACE"
    if(Test-Path "Registry::$($AMDcontextMenu)") {
        Remove-DefaultRegValue $AMDcontextMenu -ErrorAction SilentlyContinue
        MakeReadOnly $AMDcontextMenu -InclAdmin
    }
    SetValue "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{FDADFEE3-02D1-4E7C-A511-380F4C98D73B}" -Value " "
}