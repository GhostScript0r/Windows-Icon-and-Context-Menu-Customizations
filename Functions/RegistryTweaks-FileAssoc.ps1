. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
function CreateFileAssociation {
    # Create file association structure, containing default icon, shell open entry commands and icons, can be in multiple places
    param(
        [parameter(ParameterSetName='HKCRList', Mandatory=$true, Position=0)]
        [string[]]$HKCRList, # an array to arrange multiple registry keys at once
        [string[]]$FileAssoList,
        # If HKCRList has multiple elements: File Association must be at 1st place (index 0)
        [string]$DefaultIcon="",
        [string]$TypeName="",
        [string[]]$ShellOperations=@(),
        [string]$ShellDefault="",
        # The length (number of elements) of following arrays must either be the same as "ShellOperations" or zero.
        [string[]]$ShellOpDisplayName=@(),
        [string[]]$MUIVerb=@(),
        [string[]]$Icon=@(),
        [string[]]$Command=@(),
        [bool[]]$Extended=@(),
        [bool[]]$LegacyDisable=@(),
        [bool[]]$HasLUAShield=@(),
        [string[]]$CommandId=@(),
        [string[]]$DelegateExecute=@()
    )
    Write-Host "Creating shell actions for $($HKCRList[0]) type"
    $PathList=[string[]]::new($HKCRList.Length)
    for($i=0;$i -lt $HKCRList.length; $i++) {
        $PathList[$i]=$(CorrectPath $HKCRList[$i] -AddHKCR) 
    }
    foreach($RegPath in $PathList) {
        if($DefaultIcon.length -gt 0) {
            CreateKey "$($RegPath)\DefaultIcon" -StandardValue "$($DefaultIcon)"
        }
        if($ShellDefault.length -gt 0) {
            CreateKey "$($RegPath)\shell" -StandardValue "$($ShellDefault)"
        }
        if($TypeName.length -gt 0) {
            if($TypeName[0] -eq "@") {
                SetValue "$($RegPath)" -Name "FriendlyTypeName" -Value "$($TypeName)"
            }
            else {
                Set-ItemProperty "$($RegPath)" -Name '(default)' -Value "$($TypeName)"
            }
        }
        for($i=0;$i -lt $ShellOperations.Count;$i++) {
            CreateKey "$($RegPath)\shell\$($ShellOperations[$i])"
            if($ShellOpDisplayName.count -eq $ShellOperations.count) {
                CreateKey "$($RegPath)\shell\$($ShellOperations[$i])" -StandardValue "$($ShellOpDisplayName[$i])"
            }
            if($Command.Count -eq $ShellOperations.Count) {
                if($Command[$i].Length -gt 0) {
                    CreateKey "$($RegPath)\shell\$($ShellOperations[$i])\command" -StandardValue "$($Command[$i])"
                }
                # If command is not defined - just let the original command be, don't bother!
            }
            # Remove "HideBasedOnVelocityId" entry of all shell operations. Will use LegacyDisable instead
            Remove-ItemProperty -Literalpath "$($RegPath)\shell\$($ShellOperations[$i])" -Name "HideBasedOnVelocityId" -ErrorAction SilentlyContinue
            foreach($Property in @("MUIVerb","Icon","Extended","LegacyDisable","HasLUAShield","CommandID","DelegateExecute")) {
                if((Get-Variable $Property).Value.Length -gt 0) {
                    Write-Host "Writing $($Property) values to key $($RegPath)\$($ShellOperations[$i])"
                    if((Get-Variable $Property).Value.GetType().Name -like "Boolean*") {
                        # HasLUAShield, Extended and LegacyDisable property
                        $CurrentVariable=(Get-Variable $Property).Value
                        SetValue "$($RegPath)\shell\$($ShellOperations[$i])" -Name $Property -EmptyValue $CurrentVariable[$i] -Value "EmptyStringHereRemoveIfBooleanFalse"
                    }
                    else {
                        [string]$TargetValue=(Get-Variable $Property).Value[$i]
                        if($Property -eq "DelegateExecute") {
                            SetValue "$($RegPath)\shell\$($ShellOperations[$i])\command" -Name $Property -Value "$($TargetValue)"
                        }
                        else {
                            if(($Property -eq "MUIVerb") -and ($TargetValue -notlike "@*") -and ($TargetValue.length -ge 1)) {
                                $TargetValue="@$($TargetValue)"
                            }
                            SetValue "$($RegPath)\shell\$($ShellOperations[$i])" -Name $Property -Value "$($TargetValue)"
                        }
                    }
                }
            }
        }
    }
    if($FileAssoList.count -gt 0) {
        Write-Host "Associating file extensions $($FileAssoList) to type $($HKCRList[0])"
        foreach($FileExt in $FileAssoList) {
            if($FileExt[0] -ne ".") {
                $FileExt=".$($FileExt)"
            }
            [string]$ProgID=($HKCRList[0] -replace "Registry::","" -replace "HKCR\\","" -replace "HKEY_CLASSES_ROOT\\","")
            SetValue "HKCR\$($FileExt)\OpenWithProgids" -Name "$($ProgID)" -EmptyValue $true
        }
    }  
}
function CreateShellFolder {
    param(
        [parameter(ParameterSetName='TargetPath', Mandatory=$true, Position=0)]
        [string]$TargetPath,
        [string]$CLSID="",
        [switch]$HKCU,
        [switch]$HKLM,
        [string]$Icon="",
        [string]$MUIVerb="",
        [string]$Infotip="",
        [switch]$DoNotPin,
        [string]$DefaultIcon,
        [string]$Name="",
        [int]$Category=3
    )
    [string]$RegRoot="HKCR\CLSID"
    if($HKCU) {
        $RegRoot="HKCU\Software\Classes\CLSID"
    }
    elseif($HKLM) {
        $RegRoot="HKLM\Software\Classes\CLSID"
    }
    if($CLSID.length -eq 0) {
        $CLSID="{$([guid]::NewGuid())}"
    }
    # Copy a known item (in this case "Downloads") to target folder
    CreateKey "$($RegRoot)\$($CLSID)" -StandardValue "$($Name)"
    [string[]]$SubKeys=(Get-ChildItem "Registry::HKCR\CLSID\{374DE290-123F-4565-9164-39C4925E467B}").name
    foreach($SubKey in $SubKeys) {
        Copy-Item -Path "Registry::$($SubKey)" -Destination "Registry::$($RegRoot)\$($CLSID)" -Force -Recurse
    }
    SetValue "$($RegRoot)\$($CLSID)" -Name "DescriptionId" -type 4 -value $Category
    SetValue "$($RegRoot)\$($CLSID)" -Name "MUIVerb" -value "$($MUIVerb)"
    SetValue "$($RegRoot)\$($CLSID)" -Name "Infotip" -value "$($Infotip)"
    [int]$PinToTree=1
    if($DoNotPin) {
        $PinToTree=0
    }
    SetValue "$($RegRoot)\$($CLSID)" -Name "System.IsPinnedToNameSpaceTree" -type 4 -value $PinToTree
    if($DefaultIcon.length -gt 0) {
        CreateKey "$($RegRoot)\$($CLSID)\DefaultIcon" -StandardValue "$($DefaultIcon)"
    }
    SetValue "$($RegRoot)\$($CLSID)\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "$($TargetPath)"
    Remove-ItemProperty -LiteralPath "Registry::$($RegRoot)\$($CLSID)\Instance\InitPropertyBag" -Name "TargetKnownFolder"
}

function MkDirCLSID {
    param(
        [parameter(ParameterSetName='GUID', Mandatory=$true, Position=0)]
        [string]$GUID,
        [string]$Name="",
        [string]$Icon="",
        [string]$TargetPath="",
        [string]$InfoTip="",
        [int]$FolderType=3, # 3 - Folder ; 6 - Devices ; 9 - Network ; 0x16 Others
        [bool]$Pinned=$true,
        [int]$Sorting=0x42,
        <#  SortOrderIndex
            0x42 = Der Ordner wird an oberster Position angezeigt
            0x43 = Der Ordner wird unter dem Eintrag "OneDrive" (falls vorhanden) angezeigt .
            0x44 = Der Ordner wird unter dem Eintrag "Heimnetzwerkgruppe" angezeigt .
            0x54 = Der Ordner wird unter Computer / PC angezeigt 
            0x60 = Der Ordner wird an unterster Position (unter Netzwerk) angezeigt.
        #>
        [switch]$MkInHKLM, # Create CLSID and add to Namespace in HKLM instead of HKCU
        [int]$FolderValueFlags=0x28,
        [switch]$DoNotAddToNameSpace, # No Adding to Explorer\MyComputer Namespace
        [switch]$IsShortcut, # the target is a shortcut to a command, which has different structure to folders
        [switch]$RemoveCLSID
    )
    [string]$RegRoot="HKCU"
    if($MkInHKLM) {
        $RegRoot="HKLM"
    }
    if($RemoveCLSID) {
        Remove-Item "Registry::$($RegRoot)\Software\Classes\CLSID\$($GUID)" -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item "Registry::$($RegRoot)\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($GUID)" -Force -Recurse -ErrorAction SilentlyContinue
        return
    }
    CreateKey "$($RegRoot)\Software\Classes\CLSID\$($GUID)" -StandardValue "$($Name)"
    SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)" -Name "DescriptionID" -Type 4 -Value $FolderType
    SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)" -Name "SortOrderIndex" -Type 4 -Value $Sorting
    [int]$Pinned_1_0=($Pinned -and (!($ISShortcut)))  # Shortcuts shall not have show in tree views
    SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)" -Name "System.IsPinnedToNameSpaceTree" -Type 4 -Value $Pinned_1_0
    if($InfoTip.length -gt 0) {
        SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)" -Name "InfoTip" -Value "$($InfoTip)"
    }
    if($Icon.length -gt 0) {
        CreateKey "$($RegRoot)\Software\Classes\CLSID\$($GUID)\DefaultIcon" -StandardValue "$($Icon)"
    }
    if($IsShortcut) { # Shortcuts have no InProcServer32, Instance and ShellFolder entries. Instead it has structures similar to context menu commands
        CreateFileAssociation "CLSID\$($GUID)" -ShellOperations "Open" -Icon "$($Icon)" -Command "$($TargetPath)"

    }
    else {
        CreateKey "$($RegRoot)\Software\Classes\CLSID\$($GUID)\InProcServer32" -StandardValue "shell32.dll"
        SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\InProcServer32" -Name "Threadingmodel" -Value "Both"
        SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\Instance" -Name "CLSID" -Value "{0E5AAE11-A475-4c5b-AB00-C66DE400274E}"
        SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\Instance\InitPropertyBag" -Name "Attributes" -Type 4 -Value 0x11
        if($TargetPath -like "*{*-*-*-*-*}*") { # Target path is CLSID
            SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\Instance\InitPropertyBag" -Name "TargetKnownFolder" -Value "$($TargetPath)"
            Remove-ItemProperty -Path "$($RegRoot)\Software\Classes\CLSID\$($GUID)\Instance\InitPropertyBag" -Name "TargetFolderPath" -ErrorAction SilentlyContinue
        }
        else { # Target Path is regular file path
            Remove-ItemProperty -Path "$($RegRoot)\Software\Classes\CLSID\$($GUID)\Instance\InitPropertyBag" -Name "TargetKnownFolder" -ErrorAction SilentlyContinue
            if($TargetPath.length -gt 0) {
                SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "$($TargetPath)"
            }
        }
        SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\ShellFolder" -Name "Attributes" -Type 4 -Value 0xf080004d
        SetValue "$($RegRoot)\Software\Classes\CLSID\$($GUID)\ShellFolder" -Name "FolderValueFlags" -Type 4 -Value $FolderValueFlags
    }
    if(!($DoNotAddToNameSpace)) {
        CreateKey "$($RegRoot)\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($GUID)"
    }
}