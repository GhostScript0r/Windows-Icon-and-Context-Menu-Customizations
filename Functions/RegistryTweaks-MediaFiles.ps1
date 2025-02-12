function MediaPlayerFileAssoc {
    param()
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\GetIcons.ps1"
    GetDistroIcon -IconForMIME
    [string]$VideoIcon="$($env:USERPROFILE)\Links\Video.ico"
    [string]$MusicIcon="$($env:USERPROFILE)\Links\Music.ico"
    if(-not (Test-Path "$($VideoIcon)")) { 
        [string]$VideoIcon="imageres.dll,-133"
    }
    if(-not (Test-Path "$($MusicIcon)")) {
        if([System.Environment]::OSVersion.Version.Build -ge 22620) {
            [string]$MusicIcon="imageres.dll,-1026"
        }
        else {
            [string]$MusicIcon="imageres.dll,-131"
        }
    }
    # Check which media player is installed
    [string[]]$MPlayers=@("VLC","WMP Legacy","WMP UWP")
    [bool]$WMPLegacyInstalled=((Get-ItemProperty -Path "Registry::HKLM\Software\Microsoft\Active Setup\Installed Components\{22d6f312-b0f6-11d0-94ab-0080c74c7e95}" -ea 0).isinstalled -eq 1)
    [bool]$WMPUWPInstalled=((Get-AppxPackage *ZuneMusic*).count -gt 0)
    [bool[]]$MPlayersInstalled=@((Test-Path "C:\Program Files\VideoLAN"),`
    $WMPLegacyInstalled,` # Mentioned above to check if needed to take ownership of WMP11* keys
    $WMPUWPInstalled)
    if($MPlayersInstalled[0]) { # VLC installed
        Write-Host "$($MPlayers[0]) installed"
        CreateFileAssociation "Directory" -ShellOperations @("PlayWithVLC","AddtoPlaylistVLC") -LegacyDisable @(1,1)
        [string[]]$VLCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "VLC.*"})
        $VLCHKCR=$VLCHKCR+@("Applications\vlc.exe")
        [string]$VLCFileName=""
        foreach($VLCKey in $VLCHKCR) {
            if($VLCKey -like "VLC.VLC*") { # Skip VLC.VLC, as the following command will chang "VLC.VLC" to "." and break the file association of files without extension.
                continue
            }
            [string]$VLCExtension=($VLCKey -replace 'VLC','' -Replace '.Document','')
            if(@('.bin','.dat','.','.iso') -contains $VLCExtension) { # Skip VLC.VLC.Document
                continue
            }
            [string]$VLCFileType=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($VLCExtension)" -ea 0).'PerceivedType'
            if($VLCFileType -like "audio") { # VLC Audio File
                [string]$VLCFileIcon="$($MusicIcon)" # "imageres.dll,-22"
                [string]$VLCFileName="@wiashext.dll,-279"
                if($VLCExtension -like ".mid*") {
                    [string]$VLCFileName="@unregmp2.dll,-9993"
                }
            }
            elseif($VLCFileType -like "video" -or (@(".rmvb",".flv") -contains $VLCFileType)) {
                [string]$VLCFileIcon="$($VideoIcon)"
                if($VLCExtension -like ".mp4") {
                    [string]$VLCFileName="@unregmp2.dll,-9932"
                }
                elseif($VLCExtension -like ".mkv") {
                    [string]$VLCFileName="@unregmp2.dll,-9950"
                }
                elseif($VLCExtension -like ".avi") {
                    [string]$VLCFileName="@unregmp2.dll,-9997"
                }
                elseif($VLCExtension -like ".wmv") {
                    [string]$VLCFileName="@unregmp2.dll,-10000"
                }
                elseif($VLCExtension -like ".3gp") {
                    [string]$VLCFileName="@unregmp2.dll,-9937"
                }
                elseif($VLCExtension -like ".3g*2") {
                    [string]$VLCFileName="@unregmp2.dll,-9938"
                }
                else {
                    [string]$VLCFileName="@unregmp2.dll,-9905"
                }
            }
            elseif(@(".cda",".CDAudio") -contains $VLCExtension) {
                [string]$VLCFileIcon="imageres.dll,-180"
            }
            else {
                [string]$VLCFileIcon="imageres.dll,-134"
            }
            SetValue "HKCR\$($VLCExtension)\OpenWithProgids" -Name "$($VLCKey)" -EmptyValue $true
            CreateFileAssociation "$($VLCKey)" -DefaultIcon "$($VLCFileIcon)" -ShellOperations "open" -Icon "imageres.dll,-5201" -MUIVerb "@shell32.dll,-22072" -TypeName "$($VLCFileName)"
            [string]$EnqueueEntry=""
            if(Test-Path "Registry::HKCR\$($VLCKey)\shell\enqueue") {
                $EnqueueEntry="enqueue"
            }
            elseif(Test-Path "Registry::HKCR\$($VLCKey)\shell\AddToPlaylistVLC") {
                $EnqueueEntry="AddtoPlaylistVLC"
            }
            CreateFileAssociation "$($VLCKey)" -ShellOperations $enqueueentry -MUIVerb "@shell32.dll,-37427" -Icon "wlidcli.dll,-1008"
            if("Registry::HKCR\$($VLCKey)\shell\PlayWithVLC") {
                CreateFileAssociation "$($VLCKey)" -ShellOperations "PlayWithVLC" -LegacyDisable $true
            }
        }
    }
    elseif($MPlayersInstalled[1]) { # WMP Legacy installed
        Write-Host "$($MPlayers[1]) installed"
        foreach($Key in $WMPHKCR) { # WMPHKCR includes "HKCR\" at the beginning
            if((Get-ItemProperty -LiteralPath "Registry::$($Key)\shell\play" -ea 0)."Icon" -like "imageres.dll,-5201") {
                break
            }
            CreateFileAssociation $Key -ShellOperations @("Enqueue","play") `
                -Icon @("wlidcli.dll,-1008","imageres.dll,-5201") `
                -MUIVerb @("@shell32.dll,-37427","@shell32.dll,-22072")
        }
    }
    elseif($MPlayersInstalled[2]) { # WMP UWP installed
        [string]$WMPAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)\Application" -ea 0).ApplicationName -like "*Microsoft.ZuneMusic*"})[0]
        CreateFileAssociation "$($WMPAppHKCR)" -ShellOperations @("open","enqueue","play") -ShellDefault "play" -LegacyDisable @(1,0,0) -Icon @("","shell32.dll,-16752","imageres.dll,-5201") -DefaultIcon "imageres.dll,-134" -MUIVerb @("","@shell32.dll,-37427","")
    }
}