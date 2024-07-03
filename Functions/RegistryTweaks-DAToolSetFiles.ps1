. "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
. "$($PSScriptRoot)\CheckInstallPath.ps1"
function DAToolSetFileAssoc {
    [string]$DAToolsetLocation=(CheckInstallPath "Dragon Age *\DragonAgeToolset.exe" -InstallLocation @("D:\Spiele","$($env:USERPROFILE)\Saved Games"))
    if($DAToolSetLocation -like "*DragonAgeToolset.exe") {
        [string]$DAToolsetCommand="`"$($DAToolSetLocation)`" `"%1`""
        if(Test-Path "C:\Windows\System32\wscript.exe") { 
           $DAToolsetCommand="wscript.exe `"$($DAToolSetLocation.replace(".exe",".vbe"))`" `"%1`"" 
        }
        CreateFileAssociation "DAToolSetFile" `
            -FileAssoList @("arl","cif","das","are","dlb","dlg","erf","gda","rim","uti","cut","cub","mor","mao","mop","mmh","msh") `
            -DefaultIcon "`"$($DAToolSetLocation)`",0" `
            -shelloperations "open" `
            -ShellOpDisplayName "Mit Dragon Age Toolset ansehen und bearbeiten" `
            -Icon "`"$($DAToolSetLocation)`",0" `
            -Command "$($DAToolsetCommand)"
        if($JREInstalled) {
            CreateFileAssociation "UTCFile" -FileAssoList "utc" -DefaultIcon "javaw.exe,0" -ShellOperations "run" -ShellDefault "run" -Command "javaw.exe -jar `"$($DAToolSetL.replace("\Tools\DragonAgeToolset.exe","\TlkEdit-R13d\tlkedit.jar"))`" `"%1`""
        }
        Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "PerceivedType" -ea 0
        Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "Content Type" -ea 0
    }
}