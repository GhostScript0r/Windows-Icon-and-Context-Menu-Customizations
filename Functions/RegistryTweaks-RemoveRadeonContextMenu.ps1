. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
. "$($PSScriptRoot)\RegistryTweaks-AccessControl.ps1"
function RemoveAMDContextMenu {
    [string]$AMDcontextMenu="HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers\ACE"
    if(Test-Path "Registry::$($AMDcontextMenu)") {
        Remove-DefaultRegValue $AMDcontextMenu -ErrorAction SilentlyContinue
        MakeReadOnly $AMDcontextMenu -InclAdmin
    }
}