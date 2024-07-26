function HideMouseShadowPlay {
    param()
    . "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
    $nVidiaShadowPlayReg=@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS]
"{079461D0-727E-4C86-A84A-CBF9A0D2E5EE}"=hex:01,00,00,00
'@
    ImportReg $nVidiaShadowPlayReg
}