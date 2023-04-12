param(
    [switch]$RemoveCommonStartFolder,
    [switch]$UWPRefreshOnly,
    [switch]$Win32GoogleRefreshOnly,
    [switch]$CascadeSpotlight,
    [switch]$UseSpotlightDesktopIcon
)
$host.UI.RawUI.WindowTitle="Write Registry"
[string]$ScriptWithArgs="`"$($PSCommandPath)`""
foreach($Argument in @("RemoveCommonStartFolder","UWPRefreshOnly","Win32GoogleRefreshOnly","CascadeSpotlight","UseSpotlightDesktopIcon")) {
    if((Get-Variable "$($Argument)").value -eq $true) {
        $ScriptWithArgs=$ScriptWithArgs + " -$($Argument) "
    }
}
# Get admin privilege
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
[bool]$ScriptIsRunningOnAdmin=($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
if(!($ScriptIsRunningOnAdmin)) {
	Write-Host "The script $($PSCommandPath.Name) is NOT running with Admin privilege." -ForegroundColor Red -BackgroundColor White
	Start-Process powershell.exe -ArgumentList "-File $($ScriptWithArgs)" -verb runas
	exit
}
Write-Host "——————————————————
This script is inteneded to write in the usual registry stuff after Windows OOBE or in-place upgrade
——————————————————"
function BallonNotif {
    param(
        [switch]$OnHold
    )
    Add-Type -AssemblyName System.Windows.Forms 
    $balloon = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path) 
    $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning 
    $balloon.BalloonTipText = $args[0]
    $balloon.BalloonTipTitle = "Restart required to make changes take effect" 
    $balloon.Visible = $true 
    $balloon.ShowBalloonTip(5000)
    if($OnHold) {
        $Report=(Read-Host $args[0])
    }
    else {
        $Report=""
    }
    return $Report
}
function ImportReg {
    param(
        [parameter(ParameterSetName='RegContent', Mandatory=$true, Position=0)]
        [string]$RegContent
    )
    $RegContent | Out-File "$($env:TEMP)\1.reg"
    reg.exe import "$($env:TEMP)\1.reg"
    Remove-Item "$($env:TEMP)\1.reg"
}
function CorrectPath {
    [OutputType([string])]
    Param (
      [parameter(ParameterSetName='RegPath', Mandatory=$true, Position=0)]
      [String]$RegPath,
      [switch]$AddHKCR,
      [switch]$Convert
    )
    if($Convert) {
        if(($RegPath -like "HKCR\*") -or ($RegPath -like "HKEY_CLASSES_ROOT\*")) {
            $RegPath=$RegPath -replace "HKCR","" -replace "HKEY_CLASSES_ROOT",""
            foreach($RootPath in @("HKCU","HKLM")) {
                [string]$PossiblePath="$($RootPath)\Software\Classes$($RegPath)"
                if(Test-Path "Registry::$($PossiblePath)") {
                    $RegPath="$($PossiblePath)"
                    break
                } 
            }
        }
    }
    else {
        if($AddHKCR -and ($RegPath -notlike "*HKCR\*") -and ($RegPath -notlike "*HKEY_CLASSES_ROOT\*") -and ($RegPath -notlike "*HKLM\*") -and ($RegPath -notlike "*HKEY_LOCAL_MACHINE\*")) {
            $RegPath="HKCR\$($RegPath)"
        }
        if(($RegPath.Substring(0,8)) -ne "Registry") {
            $RegPath="Registry::$($RegPath)"
        }
    }
    return $RegPath
}
function Remove-DefaultRegValue {
    Param (
      [parameter(ParameterSetName='RegPath', Mandatory=$true, Position=0)]
      [String]$RegPath,
      [parameter(ParameterSetName='Key', Mandatory=$true, ValueFromPipeline=$true)]
      [Microsoft.Win32.RegistryKey]$Key
    )
    $RegPath=(CorrectPath $RegPath)
    Write-Host "Removing the default value of $($RegPath)"
    if ($RegPath) {$Key = Get-Item -LiteralPath "$($RegPath)"}
    $ParentKey = Get-Item -LiteralPath $Key.PSParentPath
    $KeyName = $Key.PSChildName
    ($ParentKey.OpenSubKey($KeyName, $True)).DeleteValue('')
  }
function CheckIfKeyExist {
    [OutputType([bool])]
    param(
        [parameter(ParameterSetName='RegPath', Mandatory=$true, Position=0)]
        [string]$RegPath,
        [string]$Name=""
    )
    $RegPath=(CorrectPath "$($RegPath)")
    [bool]$RegKeyExist=(Test-Path "$($RegPath)")
    if(($RegKeyExist) -and ($Name.length -gt 0)) {
        $RegKeyValues=(Get-ItemProperty -Path $RegPath)
        if(!($RegKeyValues -like "*$($Name)*")) {
            $RegKeyExist=$false
        }
    }
    return $RegKeyExist
}
function CreateKey {
    param(
        [parameter(ParameterSetName='RegPath', Mandatory=$true, Position=0)]
        [string]$RegPath,
        [string]$StandardValue=""
    )
    $RegPath=$(CorrectPath "$($RegPath)")
    if(!($(CheckIfKeyExist $RegPath))) {
        # Check how many level the key has by counting the occurance of "\" character
        [int]$ParentLevels=($RegPath.ToCharArray() | Where-Object {$_ -eq '\'} | Measure-Object).Count
        if($ParentLevels -eq 0) {
            Write-Host "ERROR:Can't create new registry on root level" -ForegroundColor Red -BackgroundColor Black
            exit
        }
        else {
            $RegPathParent=[string[]]::new($ParentLevels) # ParentLevel
            $RegPathParent[0]=$RegPath.Substring(0,$RegPath.lastIndexOf('\'))
            for($i=1;$i -lt $ParentLevels;$i++) {
                $RegPathParent[$i]=$RegPathParent[$i-1].Substring(0,$RegPathParent[$i-1].lastIndexOf('\'))
            }
            for($i=0;$i -lt $ParentLevels;$i++) {
                if(!($(CheckIfKeyExist $RegPathParent[$i]))) {
                    # If current parent level registry key also doesn't exist.
                    [int]$IndexFirstExistingKey=$i+1
                    # When the first existing parent key is found the number above won't increase anymore
                }
                else {
                    [int]$IndexFirstExistingKey=$i
                    break
                }
            }
            if($IndexFirstExistingKey -eq $ParentLevels) {
                Write-Host "ERROR: Existing parent key not found. Is the key $($RegPath) correct?" -ForegroundColor Red
                exit
            }
            else {
                for($i=$IndexFirstExistingKey-1;$i -ge 0;$i--) {
                    Write-Host "Creating necessary parent keys $($RegPathParent[$i])"
                    New-Item $RegPathParent[$i] >$null
                }
                New-Item $RegPath >$null
            }
        }
    }
    # Write standard value, if available
    if($StandardValue.Length -gt 0) {
        if($StandardValue -eq "RemoveDefaultValue") {
            Remove-DefaultRegValue "$($RegPath)" -ErrorAction SilentlyContinue
        } 
        else{
            Set-ItemProperty -Path "$($RegPath)" -Name '(Default)' -Value "$($StandardValue)"
            Write-Host "Default value $($StandardValue) written for the key $($RegPath)" -ForegroundColor Green
        }
    }
}
function SetValue {
    param(
        [parameter(ParameterSetName='RegPath', Mandatory=$true, Position=0)]
        [string]$RegPath,
        [string]$Name,
        [string]$Type="String",
        [string]$Value="",
        [bool]$EmptyValue=$false
    )
    $RegPath=(CorrectPath "$($RegPath)")
    # Check if RegPath already exists
    if(-not (Test-Path "$($RegPath)")) {
        CreateKey "$($RegPath)"
    }
    # Check if value is already defined
    [bool]$ValueExists=$(CheckIfKeyExist "$($RegPath)" -Name $Name)
    if($ValueExists) {
        if(!($EmptyValue) -and ($Value -eq "EmptyStringHereRemoveIfBooleanFalse")) {
            Write-Host "This value need to be removed." -ForegroundColor DarkMagenta
            Remove-ItemProperty -LiteralPath "$($RegPath)" -Name $Name
        }
        else { # Needs to be rewritten
            if($EmptyValue) {
                Set-ItemProperty -LiteralPath $RegPath -Name $Name -Value ""
                # IMPORTANT: Set-ItemProperty does not have PropertyType argument, as the type was pre-defined by existing value.
                # Only New-ItemProperty need definition of PropertyType
                Write-Host "Value $($Name) with empty string set in key $($RegPath)" -ForegroundColor green
            }
            elseif(($Value.Length -gt 0) -and ($Value -ne "EmptyStringHereRemoveIfBooleanFalse")) {
                Set-ItemProperty -LiteralPath $RegPath -Name $Name  -Value "$($Value)"
                Write-Host "Value $($Name) with string $($Value) set in key $($RegPath)" -ForegroundColor green
            }
        } 
    }
    else { # Value not yet defined
        Write-Host "The value $($Name) does not exist yet in key $($RegPath)" -ForegroundColor Yellow
        if($EmptyValue) {
            New-ItemProperty -LiteralPath $RegPath -Name $Name -PropertyType String -Value ""
            Write-Host "Value $($Name) with empty string created in key $($RegPath)" -ForegroundColor green
        }
        elseif(($Value.Length -gt 0) -and ($Value -ne "EmptyStringHereRemoveIfBooleanFalse")) {
            New-ItemProperty -LiteralPath $RegPath -Name $Name -PropertyType "$($Type)" -Value "$($Value)"
            Write-Host "Value $($Name) with string $($Value) created in key $($RegPath)" -ForegroundColor green
        }
    }
}
function CheckInstallPath {
    param(
        [parameter(ParameterSetName='Program', Mandatory=$true, Position=0)]
        [string]$Program,
        [string[]]$InstallLocation=@("C:\Program Files","$($env:LOCALAPPDATA)\Programs")
    )
    if(($Program -like "*OneDrive.exe") -or ($Program -like "*SumatraPDF.exe")) {
        $InstallLocation[1]="$($env:LOCALAPPDATA)"
    }
    for($i=0;$i -lt $InstallLocation.length;$i++) {
        if(Test-Path "$($InstallLocation[$i])\$($Program)") {
            [string]$ProgramLocation="$($InstallLocation[$i])\$($Program)"
            break
        }
    }
    if($i -eq $InstallLocation.length) { # None found
        [string]$ProgramLocation=""
    }
    return $ProgramLocation
}
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
                        SetValue "$($RegPath)\shell\$($ShellOperations[$i])" -Name $Property -EmptyValue (Get-Variable $Property).Value[$i] -Value "EmptyStringHereRemoveIfBooleanFalse"
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
        [string]$TargetKnownFolder,
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
function TakeRegOwnership {
    param(
        [parameter(ParameterSetName='LockedKey', Mandatory=$true, Position=0)]
        [string]$LockedKey,
        [string]$Description=""
    )
    if(!(Test-Path "Registry::$($LockedKey)")) { # Key does not exist
        if($LockedKey -like "*\shell\*") { # Edit key of "Internet Shortcut"
            New-Item "Registry::$($LockedKey)"
        }
        else {
            return
        }
    }
    if($Description.length -eq 0) {
        $Description=$LockedKey
    }
    Write-Host "Trying to take ownership of key $($LockedKey)" -ForegroundColor DarkGray
    $definition = @'
    using System;
    using System.Runtime.InteropServices;
     
    public class AdjPriv
    {
     [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
     internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall,
      ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);
     
     [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
     internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);
     [DllImport("advapi32.dll", SetLastError = true)]
     internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);
     [StructLayout(LayoutKind.Sequential, Pack = 1)]
     internal struct TokPriv1Luid
     {
      public int Count;
      public long Luid;
      public int Attr;
     }
     
     internal const int SE_PRIVILEGE_ENABLED = 0x00000002;
     internal const int SE_PRIVILEGE_DISABLED = 0x00000000;
     internal const int TOKEN_QUERY = 0x00000008;
     internal const int TOKEN_ADJUST_PRIVILEGES = 0x00000020;
     public static bool EnablePrivilege(long processHandle, string privilege, bool disable)
     {
      bool retVal;
      TokPriv1Luid tp;
      IntPtr hproc = new IntPtr(processHandle);
      IntPtr htok = IntPtr.Zero;
      retVal = OpenProcessToken(hproc, TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY, ref htok);
      tp.Count = 1;
      tp.Luid = 0;
      if(disable)
      {
       tp.Attr = SE_PRIVILEGE_DISABLED;
      }
      else
      {
       tp.Attr = SE_PRIVILEGE_ENABLED;
      }
      retVal = LookupPrivilegeValue(null, privilege, ref tp.Luid);
      retVal = AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
      return retVal;
     }
    }
'@
    $processHandle = (Get-Process -id $pid).Handle
    $type = Add-Type $definition -PassThru
    $type[0]::EnablePrivilege($processHandle, "SeTakeOwnershipPrivilege",$false)
    $LockedKey=(CorrectPath "$($LockedKey)")
    $MyAccount = [System.Security.Principal.NTAccount]"$env:userdomain\$env:username"
    $import = '[DllImport("ntdll.dll")] public static extern int RtlAdjustPrivilege(ulong a, bool b, bool c, ref bool d);'
    $ntdll = Add-Type -Member $import -Name NtDll -PassThru
    $privileges = @{ SeTakeOwnership = 9; SeBackup =  17; SeRestore = 18 }
    foreach ($i in $privileges.Values) {
        $ntdll::RtlAdjustPrivilege($i, 1, 0, [ref]0)
    }
    [string]$LockedKeyRoot=$LockedKey.Substring(0,$LockedKey.IndexOf('\'))
    [string]$LockedKeyBody=$LockedKey.Substring($LockedKey.IndexOf('\'),$LockedKey.Length-$LockedKey.IndexOf('\'))
    if($LockedKeyRoot -like "*HKCR") {
        $R=[Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("$($LockedKeyBody)",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::takeownership)
    }
    elseif($LockedKeyRoot -like "*HKLM") {
        $R=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$($LockedKeyBody)",[Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,[System.Security.AccessControl.RegistryRights]::takeownership)
    }
    $acl = $R.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
    $acl.SetOwner($MyAccount)
    $R.SetAccessControl($acl)
    $acl = $R.GetAccessControl()
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($MyAccount,"FullControl","Allow")
    $acl.SetAccessRule($rule)
    $R.SetAccessControl($acl)
}
function MakeReadOnly {
    param(
        [parameter(ParameterSetName='Key', Mandatory=$true, Position=0)]
        [string]$Key,
        [switch]$InclAdmin
    )
    $Key=(CorrectPath "$($Key)")
    [string[]]$UserToDeny=@("$($env:UserDomain)\$($env:Username)","VORDEFINIERT\Benutzer")
    if($InclAdmin) {
        $UserToDeny=$UserToDeny + @("VORDEFINIERT\Administratoren")
    }
    foreach($User in $UserToDeny) {
        $ACL=(Get-Acl "$($Key)")
        $CurrentStatus=($ACL.Access | Where-Object {$_.IdentityReference -like "$($User)"})[0]
        if(!($?)) {
            continue # Last key failed -- user does not exist at all in the list
        }
        if($CurrentStatus.RegistryRights -like "ReadKey") {
            continue # Write access already denied. No need to do
        }
        Write-Host "Deprive $($User) of write access to key $($Key)" -ForegroundColor DarkYellow
        if($CurrentStatus.IsInherited -eq $true) {
            Write-Host "Disable interitence of $($Key)"
            $ACL.SetAccessRuleProtection($true,$true) | Out-Null
            $ACL | Set-Acl -Path "$($Key)" | Out-Null
        }
        $ReadOnlyAccess=[System.Security.AccessControl.RegistryRights]::ReadKey
        $UserAccount=[System.Security.Principal.NTAccount]("$($User)")
        $inhFlags = [System.Security.AccessControl.InheritanceFlags]::None
        $prFlags = [System.Security.AccessControl.PropagationFlags]::None
        $acType = [System.Security.AccessControl.AccessControlType]::Allow
        $ReadOnlyACL=New-Object System.Security.AccessControl.RegistryAccessRule ($UserAccount, $ReadOnlyAccess, $inhFlags, $prFlags, $acType) 
        $Acl.RemoveAccessRule($CurrentStatus) | Out-Null
        $Acl.AddAccessRule($ReadOnlyACL) | Out-Null
        $Acl | Set-Acl -Path "$($Key)" | Out-Null
    }
}
function FixUWPCommand {
    [string]$UWPCommand="$($args[0])"
    # if($args[0] -like "*Ubuntu*") {
    #     $UWPCommand="C:\Windows\System32\wsl.exe $($UWPCommand) && sleep 0.8"
    # }
    # elseif($args[0] -like "*mspaint*") {
    #     $UWPCommand="cmd.exe /min /c start $($UWPCommand) && exit"
    # }
    return $UWPCommand
}
function RefreshGoogleDriveIcons {
    [object[]]$GoogleDriveApps=(Get-ChildItem "C:\Program Files\Google\Drive File Stream\*\GoogleDriveFS.exe" -recurse)
    if($GoogleDriveApps.count -eq 0) {
        Write-Host "Google Drive FS not yet installed." -ForegroundColor Red
        Remove-Item "Registry::HKCR\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}"
    }
    else {
        [string]$GDriveLoc=$GoogleDriveApps[$GoogleDriveApps.count-1].FullName
        CreateFileAssociation "CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -DefaultIcon "`"$($GDriveLoc)`",-61"
        foreach($GDocExt in @(".gdoc",".gsheet",".gslides")) {
            Remove-Item "Registry::HKCR\$($GDocExt)\ShellNew" -ErrorAction SilentlyContinue
        }
        foreach($GDoc in (Get-ChildItem "Registry::HKCR\GoogleDriveFS.*").Name) {
            [string]$GDocIcon=(Get-ItemProperty -LiteralPath "Registry::$($GDoc)\DefaultIcon").'(default)'
            CreateFileAssociation "$($GDoc)" -ShellOperations "open" -Icon "$($GDocIcon)"
        }
    }
}
function RegCopyPaste {
    param(
        [parameter(ParameterSetName='RegLoc', Mandatory=$true, Position=0)]
        [string]$RegLoc,
        [string]$Target,
        [string[]]$Shell=@(),
        [switch]$DefaultIcon
    )
    if($Shell.count -gt 0) {
        $ShellLinks=[string[]]::new($Shell.count)
        for($i=0; $i -lt $Shell.count;$i++) {
            $ShellLinks[$i]="shell\$($Shell[$i])"
        }
        CreateKey "$($regloc)\shell"
    }
    if($DefaultIcon) {
        $ShellLinks = $ShellLinks + @("DefaultIcon")
    }
    foreach($ShellKey in $ShellLinks) {
        [string]$CopyDestination="Registry::$($RegLoc)"
        if($ShellKey -like "shell\?*") {
            $CopyDestination="$($CopyDestination)\shell"
        }
        Copy-Item -Path "Registry::$($Target)\$($ShellKey)" -Destination "$($CopyDestination)" -Force
        if($ShellKey -like "shell\?*") {
            Copy-Item -Path "Registry::$($Target)\$($ShellKey)\command" -Destination "$($CopyDestination -replace 'shell',$ShellKey)" -Force
        }
    }
}
function RefreshAppAfterUpdate {
    param(
        [parameter(ParameterSetName='Key', Mandatory=$true, Position=0)]
        [string]$Key,
        [string]$Shell,
        [string]$AppLocation="",
        [string]$TargetCommand="",
        [string]$AppxHKCR="",
        [switch]$IconOnly
    )
    $Key=(CorrectPath "$($Key)" -AddHKCR)
    if($AppxHKCR.length -gt 0) {
        $AppxHKCR=(CorrectPath "$($AppxHKCR)" -AddHKCR)
    }
    [string]$LastWrittenAppVer=(Get-ItemProperty -LiteralPath "$($Key)\shell\$($Shell)")."Icon" -replace "`"C","C" -replace "`",0",""
    if($LastWrittenAppVer -notlike $AppLocation) {
        Write-Host "App $($LastWrittenAppVer.substring($LastWrittenAppVer.LastIndexOf("\"),$LastWrittenAppVer.Length-4-$LastWrittenAppVer.LastIndexOf("\"))) was updated. Updating entries accordingly."
        # Refresh Icon
        Set-ItemProperty -Path "$($Key)\shell\$($Shell)" -Name "Icon" -Value "`"$($AppLocation)`",0"
        # Refresh command
        if(!($IconOnly) -and ($AppHKCR.length -gt 0)) {
            Copy-Item -Path "$($AppHKCR)\shell\$($Shell)\Command" -Destination "$($Key)\shell\$($Shell)" -Force
        }
    }
}
function RemoveAMDContextMenu {
    [string]$AMDcontextMenu="HKEY_CLASSES_ROOT\Directory\Background\shellex\ContextMenuHandlers\ACE"
    if(Test-Path "Registry::$($AMDcontextMenu)") {
        Remove-DefaultRegValue $AMDcontextMenu -ErrorAction SilentlyContinue
        MakeReadOnly $AMDcontextMenu -InclAdmin
    }
}
function ModifyMusicLibraryNamespace {
    [string[]]$LibraryCLSID=@("{A0C69A99-21C8-4671-8703-7934162FCF1D}","My Music") #",{35286A68-3C57-41A1-BBB1-0EAE73D76C95}","{374DE290-123F-4565-9164-39C4925E467B}","My Video"
[string[]]$LibraryLoc=@("%USERPROFILE%\Box\Music","%USERPROFILE%\Box\Music") #,"D:\Videos","D:\Downloads","D:\Videos"
for($i=0; $i -lt $LibraryCLSID.length ; $i++) {
    SetValue "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders" -Name "$($LibraryCLSID[$i])" -Value "$($LibraryLoc[$i])"
}
MakeReadOnly "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
}
# ————————————————————————
# Main part of the script
# ————————————————————————
# NVidia Shadow Play - hide mouse button
$nVidiaShadowPlayReg=@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\NVIDIA Corporation\Global\ShadowPlay\NVSPCAPS]
"{079461D0-727E-4C86-A84A-CBF9A0D2E5EE}"=hex:01,00,00,00
'@
ImportReg $nVidiaShadowPlayReg
[bool]$UWPFolderModded=$false #((Get-Acl 'C:\Program Files\WindowsApps\').Owner -like "$($env:UserDomain)\$($env:Username)")
# [int]$WtErrorMsgCount=((Get-EventLog -InstanceID 1000 -LogName Application -EntryType Error) | Where-Object {$_.Message -like "*WindowsTerminal.exe*ucrtbase.dll*"}).count
# if(!($UWPFolderModded) -and ($WtErrorMsgCount -gt 0)) {
#     takeown /r /f "C:\Program Files\WindowsApps\"
#     $UWPFolderModded=$true
# }
# UWP Apps folder is modified to allow access. UWP Icons will be possible but MSPaint, Terminal can't run without cmd /c argument
# > Find file location of paint app
[string]$PaintAppLocation="$($(Get-AppxPackage Microsoft.Paint).InstallLocation)\PaintApp\mspaint.exe"
[string]$PaintAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_.Name)\Application" -ErrorAction SilentlyContinue).ApplicationName -like "*Microsoft.Paint*"})[0]
# > Find file location of Windows Terminal app
[string]$WTLocation="$($(Get-AppxPackage Microsoft.WindowsTerminal*).InstallLocation)"
[string]$WSLLocation="$((Get-AppxPackage MicrosoftCorporationII.WindowsSubsystemForLinux).InstallLocation)\wsl.exe"
# > Find file location of WMP UWP
[bool]$WMPUWPInstalled=((Get-AppxPackage *ZuneMusic*).count -gt 0)
# > Find file location of Python
[string[]]$PythonVerInstalled=(Get-AppxPackage "*.Python.*").Name
if($PythonVerInstalled.Count -gt 0) {
    [string]$PythonInstallLoc="$((Get-AppxPackage "$($PythonVerInstalled)").InstallLocation)\python.exe"
    [string]$PythonFileHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)" -ErrorAction SilentlyContinue).'(default)' -like "Python File*"})[0] # Includes HKCR\ prefix
}
# Refresh PowerRename
if((Get-AppxPackage Microsoft.PowerToys.PowerRenameContextMenu).count -gt 0) {
    Remove-Item "Registry::HKCR\AllFilesystemObjects\shellex\ContextMenuHandlers\PowerRenameEx" -Force -ErrorAction SilentlyContinue
}
# Check if Desktop Spotlight is enabled
[int]$CurrentBackgroundType=(Get-ItemProperty -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Wallpapers").'BackgroundType'
[string]$SpotlightCLSID="r"
# If called by script "RefreshAppAndRemoveUselessApps": only change the icon for UWP app file associations
RefreshAppAfterUpdate "SystemFileAssociations\image" -Shell "edit" -AppLocation "$($PaintAppLocation)" -AppxHKCR "$($PaintAppHKCR)"
# RefreshAppAfterUpdate "Directory\Background" -AppLocation "$($WTLocation)" -Shell "PowershellWithAdmin" -IconOnly # Not used if using PowerShell icon
RefreshAppAfterUpdate "Directory\Background" -AppLocation "$($WSLLocation)" -Shell "WSL" -IconOnly
RefreshAppAfterUpdate "$($PythonFileHKCR)" -AppLocation "$($PythonInstallLoc)" -Shell "open" -IconOnly
$TerminalJSON=(Get-Content "$($env:USERPROFILE)\OneDrive\Anlagen\AppData\Terminal_settings.json")
for($i=0;$i -lt $TerminalJSON.count; $i++) {
    if($TerminalJSON[$i] -like "*`"icon`": `"C:\\Program Files\\WindowsApps\\Microsoft.WindowsTerminal*.png`"*") {
        $TerminalJSON[$i]="`"icon`": `""+($WTLocation -replace "\\","\\")+"\\ProfileIcons\"+$TerminalJSON[$i].substring($TerminalJSON[$i].lastindexof("\"),$TerminalJSON[$i].length-$TerminalJSON[$i].lastindexof("\"))
    }
    elseif($TerminalJSON[$i] -like "*`"icon`": `"C:\\Program Files\\WindowsApps\\MicrosoftCorporationII.WindowsSubsystemForLinux*.png`"*") {
        $TerminalJSON[$i]="`"icon`": `""+($WSLLocation -replace "\\","\\" -replace "wsl.exe","")+"Images\"+$TerminalJSON[$i].substring($TerminalJSON[$i].lastindexof("\"),$TerminalJSON[$i].length-$TerminalJSON[$i].lastindexof("\"))
    }
}
$TerminalJSON | Out-File "$($env:USERPROFILE)\OneDrive\Anlagen\AppData\Terminal_settings.json" -Encoding utf8
if($CurrentBackgroundType -eq 3) {
    [string]$CurrentBackgroundLink=(Get-Itemproperty -literalpath "Registry::$($SpotlightCLSID)\shell\spotlightclick").contentid
    $CurrentBackgroundLink=$CurrentBackgroundLink.substring(0,$CurrentBackgroundLink.IndexOf("%"))
    [string]$CurrentBackgroundDesc=(Get-Itemproperty -literalpath "Registry::$($SpotlightCLSID)").infotip
    [string]$CurrentBackgroundDesc=$CurrentBackgroundDesc.substring(0,$CurrentBackgroundDesc.IndexOf("`n"))
    # SetValue "HKCR\DesktopBackground\shell\SpotlightClick" -Name "contentId" -value $CurrentBackgroundLink
}
else {
    Remove-Item -Path "Registry::HKCR\DesktopBackground\shell\Spotlight*" -Force
    Remove-Item -Path "Registry::HKCR\DesktopBackground\shell\Windows-Blickpunkt" -Force -Recurse -ErrorAction SilentlyContinue
}
Remove-Item "Registry::HKCR\Directory\Background\shellex\ContextMenuHandlers\ACE" -Force -ErrorAction SilentlyContinue
Remove-Item "Registry::HKCR\Directory\Background\shellex\ContextMenuHandlers\DropboxExt" -Force -ErrorAction SilentlyContinue
if((Test-Path "$($env:USERPROFILE)\old_Box") -or ((Get-ItemProperty -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders").'{A0C69A99-21C8-4671-8703-7934162FCF1D}' -notlike "*\Box\Music")) {
    ModifyMusicLibraryNamespace
    Remove-Item "$($env:USERPROFILE)\old_Box" -Force -Recurse -ErrorAction SilentlyContinue
}
if($UWPRefreshOnly) {
    exit
}
# Check if MS Office is installed
[bool]$MSOfficeInstalled=$false
foreach($ProgramFilesLoc in @("Program Files","Programe Files (x86)")) {
    [string]$MSOfficeLoc="C:\$($ProgramFilesLoc)\Microsoft Office\root"
    if(Test-Path "$($MSOfficeLoc)") {
        $MSOfficeInstalled=$true
        break
    }
}
# Check if LibreOffice is installed
[bool]$LibreOfficeInstalled=$false
if(Test-Path "C:\Program Files\LibreOffice\program\soffice.exe") { 
    $LibreOfficeInstalled=$true
}

# --------------------------------
# Get privileges to take ownership
Write-Host "Preparing to take ownership of keys owned by SYSTEM or TrustedInstaller"
#Take ownership of keys owned by SYSTEM or TrustedInstaller
[string[]]$LockedHKCR=@(`
    "HKCR\DesktopBackground\Shell\Display",`
    "HKCR\DesktopBackground\Shell\Personalize",`
    "HKCR\Directory\shell\cmd",`
    "HKCR\Directory\shell\cmd\command",`
    "HKCR\Directory\shell\powershell",`
    "HKCR\Directory\shell\powershell\command",`
    "HKCR\Directory\shell\wsl",`
    "HKCR\Directory\shell\wsl\command",`
    "HKCR\Directory\Background\shell\cmd",`
    "HKCR\Directory\Background\shell\cmd\command",`
    "HKCR\Directory\Background\shell\powershell",`
    "HKCR\Directory\Background\shell\powershell\command",`
    "HKCR\Directory\Background\shell\wsl",`
    "HKCR\Directory\Background\shell\wsl\command",`
    "HKCR\PhotoViewer.FileAssoc.Tiff\shell\open",`
    "HKCR\PhotoViewer.FileAssoc.Tiff\DefaultIcon",`
    "HKCR\InternetShortcut",`
    "HKCR\InternetShortcut\CLSID",`
    "HKCR\InternetShortcut\shell",`
    "HKCR\InternetShortcut\shell\edit",`
    "HKCR\InternetShortcut\shell\edit\command",`
    "HKCR\InternetShortcut\shell\open",`
    "HKCR\InternetShortcut\shell\open\command",`
    "HKCR\InternetShortcut\shell\print",`
    "HKCR\InternetShortcut\shell\printto",`
    "HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}",` # Remove IE functionality of URL link
    "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}",` # Trash Bin
    "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\empty",` # Trash Bin
    "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage",` # This PC
    "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}",` # Control Panel
    "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}\DefaultIcon",` # Control Panel
    "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}\shell\open",` # Control Panel
    "HKCR\CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}\DefaultIcon",` # Control Panel Category View
    "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}",` # WSL
    "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}\DefaultIcon",` #WSL
    "HKCR\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",` # Network places
    "HKCR\CLSID\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}",` # Pictures
    "HKCR\CLSID\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}",` # Videos
    "HKCR\CLSID\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}",` # Music
    "HKCR\CLSID\{088e3905-0323-4b02-9826-5d99428e115f}",` # Downloads
    "HKCR\CLSID\{d3162b92-9365-467a-956b-92703aca08af}",` # Documents
    "HKCR\CLSID\{59031a47-3f72-44a7-89c5-5595fe6b30ee}",` # User profile
    "HKCR\CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}",` # Quick Access
    "HKCR\CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}\DefaultIcon",` # Quick Access
    "HKCR\CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}\Shell\PinToHome",` # Quick Access
    "HKCR\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}",` # Quick Access
    "HKCR\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}\DefaultIcon",` # Quick Access
    "HKCR\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}\Shell\PinToHome",` # Quick Access
    "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}",` # Recent Folders
    "HKCR\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}",` # Newest Gallery / Catalog
    "HKCR\CLSID\{60632754-c523-4b62-b45c-4172da012619}\DefaultIcon",` # Control panel - user accounts
    "HKCR\CLSID\{6DFD7C5C-2451-11d3-A299-00C04F8EF6AF}\shell",` # Control panel - folder options
    "HKCR\CLSID\{7b81be6a-ce2b-4676-a29e-eb907a5126c5}\DefaultIcon",` # Control panel - Programs and Features
    "HKCR\CLSID\{62D8ED13-C9D0-4CE8-A914-47DD628FB1B0}\DefaultIcon",` # Control panel - Region and Language
    "HKCR\CLSID\{725BE8F7-668E-4C7B-8F90-46BDB0936430}\DefaultIcon",` # Control panel - Keyboard properties
    "HKCR\CLSID\{6C8EEC18-8D75-41B2-A177-8831D59D2D50}\DefaultIcon",` # Control panel - Mouse properties
    "HKCR\CLSID\{D555645E-D4F8-4c29-A827-D93C859C4F2A}\DefaultIcon",` # Control panel - Ease of access center
    "HKCR\CLSID\{ECDB0924-4208-451E-8EE0-373C0956DE16}\DefaultIcon",` # Control panel - Work folders
    "HKCR\CLSID\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}\DefaultIcon",` # Control panel - Power options
    "HKCR\CLSID\{93412589-74D4-4E4E-AD0E-E0CB621440FD}\DefaultIcon",` # Control panel - Font settings
    "HKCR\CLSID\{BD84B380-8CA2-1069-AB1D-08000948F534}\DefaultIcon",` # Control panel - Font folder
    "HKCR\CLSID\{58E3C745-D971-4081-9034-86E34B30836A}\DefaultIcon",` # Control panel - Speech recognition
    "HKCR\CLSID\{BB06C0E4-D293-4f75-8A90-CB05B6477EEE}\DefaultIcon",` # Control panel - System
    "HKCR\CLSID\{9C60DE1E-E5FC-40f4-A487-460851A8D915}\DefaultIcon",` # Control panel - Autoplay
    "HKCR\CLSID\{9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF}\DefaultIcon",` # Control panel - Sync center
    "HKCR\CLSID\{80F3F1D5-FECA-45F3-BC32-752C152E456E}\DefaultIcon",` # Control panel - Tablet PC Settings
    "HKCR\CLSID\{5ea4f148-308c-46d7-98a9-49041b1dd468}\DefaultIcon",` # Control panel - Windows Mobility Center
    "HKCR\CLSID\{F942C606-0914-47AB-BE56-1321B8035096}\DefaultIcon",` # Control panel - Storage spaces
    "HKCR\CLSID\{87D66A43-7B11-4A28-9811-C86EE395ACF7}\DefaultIcon",` # Control panel - Indexing options
    "HKCR\CLSID\{A3DD4F92-658A-410F-84FD-6FBBBEF2FFFE}\DefaultIcon",` # Control panel - Internet options (IE)
    "HKCR\CLSID\{F82DF8F7-8B9F-442E-A48C-818EA735FF9B}\DefaultIcon",` # Control panel - Pen and touch
    "HKCR\CLSID\{A8A91A66-3A7D-4424-8D24-04E180695C7A}\DefaultIcon",` # Control panel - Devices and Printers
    "HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}",` # Libraries
    "HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell",` # Libraries
    "HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" # Libraries
)
[bool]$WMPLegacyInstalled=((Get-ItemProperty -Path "Registry::HKLM\Software\Microsoft\Active Setup\Installed Components\{22d6f312-b0f6-11d0-94ab-0080c74c7e95}" -ErrorAction SilentlyContinue).isinstalled -eq 1)
if($WMPLegacyInstalled) {
    [string[]]$WMPHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "WMP11.AssocFile.*") -and (Test-Path "Registry::HKCR\$($_)\shell\play")})
    $WMPLockedHKCR=[string[]]::new($WMPHKCR.length)
    for($i=1;$i -lt $WMPHKCR.length;$i++) {
        $WMPLockedHKCR[$i]="HKCR\$($WMPHKCR[$i])\shell\play"
    }
}
else {
    [string[]]$WMPLockedHKCR=@()
}
[string[]]$LockedHKLM=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell\Update\Packages\MicrosoftWindows.Client.40729001_cw5n1h2txyewy")
[string[]]$AllLockedKeys= $LockedHKCR + $WMPLockedHKCR + $LockedHKLM
foreach($LockedKey in $AllLockedKeys) {
    if((Test-Path "Registry::$($LockedKey)") -and ((Get-Acl "Registry::$($LockedKey)").Owner -NotLike "$($env:UserDomain)\$($env:Username)")) {
        TakeRegOwnership "$($LockedKey)" | Out-Null
    }
}
# Check if Chrome is installed
[string]$ChromePath="C:\Program Files\Google\Chrome\Application\chrome.exe"
[bool]$ChromeInstalled=(Test-Path "$($ChromePath)")
if($ChromeInstalled) {
    [string]$BrowserOpenAction="`"$($ChromePath)`" %1"
    [string]$BrowserIcon="`"$($ChromePath)`",0"
}
else {
    [string]$BrowserOpenAction="`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`" --single-argument %1"
    [string]$BrowserIcon="ieframe.dll,-31065"
}
# ——————————————————————————————————
# ————————KEYBOARD TWEAKS—————————
# Use SpeedCrunch as calculator
[string]$SpeedCrunchPath="C:\Program Files (x86)\SpeedCrunch\speedcrunch.exe"
if(Test-Path "$($SpeedCrunchPath)") {
    CreateFileAssociation "ms-calculator" -ShellOperations "open" -Icon "`"$($SpeedCrunchPath)`"" -Command "`"$($SpeedCrunchPath)`""
}
# Replace Microsoft People with Google Contacts
CreateFileAssociation "ms-people" -ShellOperations "open" -Command "$($BrowserOpenAction.Replace(" %1"," contacts.google.com"))"
# Use QWERTZ German keyboard layout for Chinese IME
[string]$CurrentKeyboardLayout=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804")."Layout File"
if($CurrentKeyboardLayout -notlike "KBDGR.DLL") {
    SetValue "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\00000804" -Name "Layout File" -Value "KBDGR.DLL"
    BallonNotif "Computer needs to be restarted to let keyboard layout change take effect"
}
# ——————————————————————————————————
# ————————FILE ASSOCIATIONS—————————
# ——————————————————————————————————
# --------Any file---------
New-ItemProperty -LiteralPath "Registry::HKCR\*\shell\pintohomefile" -Name "Icon" -PropertyType "string" -Value "shell32.dll,-322" -ErrorAction SilentlyContinue
if(!($?)) {
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\pintohomefile" -Name "Icon" -Value "shell32.dll,-322" -ErrorAction SilentlyContinue
}
# --------Java files--------
[bool]$JREInstalled=((Get-Command javaw -ErrorAction SilentlyContinue).name -like "javaw.exe")
if($JREInstalled) {
    CreateFileAssociation "jarfile" -ShellOperations "open" -MUIVerb "@shell32.dll,-12710" -Icon "javaw.exe"
}
# --------Dragon Age Toolset--------
[string]$DAToolSetD="D:\Spiele\Dragon Age Origins\Tools\DragonAgeToolset.exe"
[string]$DAToolSetE="E:\Spiele\Dragon Age Origins\Tools\DragonAgeToolset.exe"
[bool]$DAToolSetInstalled=((Test-Path $DAToolSetD) -or (Test-Path $DAToolSetE))
if($DAToolSetInstalled) {
    if(Test-Path $DAToolSetD) {
        [string]$DAToolSetL=$DAToolSetD
    }
    elseif(Test-Path $DAToolSetE) {
        [string]$DAToolSetL=$DAToolSetE
    }
    CreateFileAssociation "DAToolSetFile" `
        -FileAssoList @("arl","cif","das","are","dlb","dlg","erf","gda","rim","uti","cut","cub","mor","mao","mop","mmh","msh") `
        -DefaultIcon "`"$($DAToolSetL)`",0" `
        -shelloperations "open" `
        -ShellOpDisplayName "Mit Dragon Age Toolset ansehen und bearbeiten" `
        -Icon "`"$($DAToolSetL)`",0" `
        -Command "wscript.exe `"$($DAToolSetL.replace(".exe",".vbe"))`" `"%1`""
    if($JREInstalled) {
        CreateFileAssociation "UTCFile" -FileAssoList "utc" -DefaultIcon "javaw.exe,0" -ShellOperations "run" -ShellDefault "run" -Command "javaw.exe -jar `"$($DAToolSetL.replace("\Tools\DragonAgeToolset.exe","\TlkEdit-R13d\tlkedit.jar"))`" `"%1`""
    }
    Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "PerceivedType" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "Registry::HKCR\.erf" -Name "Content Type" -ErrorAction SilentlyContinue
}

# --------- zip relevant, compressed archives ---------
[string[]]$ZipFileAssoExt=@("7z","apk","zip","cbz","cbr","rar","vdi","001","gz")
if($DAToolSetInstalled) {
    $ZipFileAssoExt = $ZipFileAssoExt + @("override")
}
[string]$ZipAppInstalled=(Get-Childitem "C:\Program files\*zip").name
if($ZipAppInstalled -like "*PeaZip*") {
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2browseasarchive; PeaZip.add2separate; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
    Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name 'Icon' -Value "C:\Program files\Peazip\peazip.exe"
    <# PeaZip Commands include:
    PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2smart; PeaZip.ext2folder; PeaZip.ext2test; PeaZip.ext2browseasarchive; PeaZip.ext2browsepath; PeaZip.add2separate; PeaZip.add2separatesingle; PeaZip.add2separatesfx; PeaZip.add2separate7z; PeaZip.add2separate7zfastest; PeaZip.add2separate7zultra; PeaZip.add2separatezip; PeaZip.add2separatezipfastest; PeaZip.add2separate7zencrypt; PeaZip.add2separatezipmail; PeaZip.add2split; PeaZip.add2convert; PeaZip.analyze; PeaZip.add2wipe; 
    #>
    [string[]]$PeaZipHKCR=(Get-ChildItem Registry::HKCR\PeaZip.*).Name # Include HKCR\ prefix
    CreateFileAssociation $($PeaZipHKCR+@("Applications\PEAZIP.exe")) -DefaultIcon "imageres.dll,-174" -ShellOperations "open" -ShellOpDisplayName "Mit PeaZip öffnen" -Icon "`"C:\Program Files\PeaZip\peazip.exe`",0" -Command "`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"%1`""
    CreateFileAssociation "Directory\Background" -ShellOperations @("Browse path with PeaZip","ZPeaZip") -ShellOpDisplayName @("","Hier PeaZip öffnen") -Icon @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`",0") -Command @("","`"C:\Program Files\PeaZip\PEAZIP.EXE`" `"-ext2browsepath`" `"%V`"") -LegacyDisable @(1,0)
    foreach($Key in $PeaZipHKCR) {
        Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::$($Key)\shell" -Force
        CreateFileAssociation "$($Key)" -ShellOperations "PeaZip" -Icon "zipfldr.dll,-101" -MUIVerb "@zipfldr.dll,-10148"
        SetValue "$($Key)\shell\PeaZip" -Name "SubCommands" -Value "PeaZip.ext2main; PeaZip.ext2here; PeaZip.ext2folder; PeaZip.add2split; PeaZip.add2convert; PeaZip.add2separate7zencrypt; PeaZip.analyze; PeaZip.add2wipe; "
        Remove-Item -Path "Registry::$($Key)\shell\PeaZipCompressedFolder" -Force -Recurse -ErrorAction SilentlyContinue
    }
    Copy-Item -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Destination "Registry::HKCR\AllFilesystemObjects\shell" -Force
    [string[]]$PeaZipCommandHKCR=(Get-ChildItem Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\PeaZip.*).Name # Include HKLM\..... whole path
    foreach($SubCommand in $PeaZipCommandHKCR) {
        if($SubCommand -like "*PeaZip.ext2browseasarchive") {
            [string]$ZipIcon="zipfldr.dll,-101" # Open as archive
        }
        elseif($SubCommand -like "*PeaZip.add2separate*") {
            [string]$ZipIcon="imageres.dll,-175" # Compress/Add2archive
            if($SubCommand -like "*PeaZip.add2separatezipmail") {
                [string]$ZipIcon="mssvp.dll,-500" # Send via E-Mail
            }
            if($SubCommand -like "*PeaZip.*encrypt") {
                [string]$ZipIcon="imageres.dll,-5360" # Encrypt archive
            }
        }
        elseif(($SubCommand -like "*Peazip.ext2*") -and ($SubCommand -notlike "*Peazip.ext2browsepath")) {
            [string]$ZipIcon="shell32.dll,-46" # Extract
        }
        elseif($SubCommand -like "*PeaZip.add2wipe") {
            [string]$ZipIcon="shell32.dll,-16777" #Erase
        }
        else {
            [string]$ZipIcon=""
        }
        if($ZipIcon.length -gt 1) {
            Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "$($ZipIcon)"
        }
    }
    # Remove PeaZip "SendTo" entries
    $SendToItems=(Get-ChildItem "$($env:APPDATA)\Microsoft\Windows\SendTo")
    $sh=New-Object -ComObject WScript.Shell
    foreach($SendToItem in $SendToItems) {
        $LNKTarget=$sh.CreateShortcut("$($SendToItem.FullName)").TargetPath
        if($LNKTarget -like "*Pea*Zip*") {
            Remove-Item $SendToItem
        }
    }
}
elseif($ZipAppInstalled -like "*7-Zip*") {
    CreateFileAssociation @("CompressedArchive","Applications\7zFM.exe") `
    -FileAssoList $ZipFileAssoExt `
    -DefaultIcon "imageres.dll,-174" `
    -ShellOperations "open" `
    -ShellOpDisplayName "Mit 7-Zip öffnen" `
    -Icon "`"C:\Program Files\7-Zip\7zFM.exe`",0" `
    -Command "`"C:\Program Files\7-Zip\7zFM.exe`" `"%1`""
}
# --------Windows Update package (MSU)--------
CreateFileAssociation "Microsoft.System.Update.1" `
    -ShellOperations "open" `
    -Icon "wusa.exe,-101" `
    -MUIVerb "@ActionCenter.dll,-2107"
# ---------Windows folders--------
CreateFileAssociation "Folder" `
    -ShellOperations @("open","opennewwindow","opennewtab","opennewprocess","pintohome") `
    -Icon @("main.cpl,-606","imageres.dll,-5322","imageres.dll,-116","","shell32.dll,-322") `
    -LegacyDisable @(0,0,0,1,0) `
    -MUIVerb @("@shell32.dll,-32960","","","","") `
    -TypeName "@shell32.dll,-9338"
# ---------Hard drives--------
CreateFileAssociation "Drive" `
    -ShellOperations @("manage-bde","encrypt-bde","encrypt-bde-elev","pintohome") `
    -Icon @("shell32.dll,-194","shell32.dll,-194","shell32.dll,-194","shell32.dll,-322")
# Check if VS Code is installed systemwide or for current user only
[string[]]$VSCodeVersion=@("Microsoft VS Code\code.exe","Microsoft VS Code Insiders\Code - Insiders.exe")
for ($i=0;$i -lt $VScodeVersion.count;$i++) {
    [string]$VSCodeLocation=(CheckInstallPath "$($VSCodeVersion[$i])")
    if($VSCodeLocation.length -gt 0) {
        break
    }
}
[string]$VSCodeIconsLoc="$(Split-Path "$($VSCodeLocation)" -Parent)\resources\app\resources\win32"
[string]$VSCodeVerHKCR="VSCode"
if($VSCodeLocation -like "*Insiders*") {
    [string]$VSCodeVerHKCR="VSCodeInsiders"
}
# --------Directories--------
[string[]]$PowerShellDef=@("","powershell.exe,0") # [0]: Display Name; [1]: Icon file
if($UWPFolderModded) { # Have access to WindowsApps folders and the icons inside
#     if($WTLocation -like "*Preview*") {
#         $PowerShellDef=@("In Terminal  Vorschau öffnen (Admin)","`"$($WTLocation)`",0")
#     }
#     else {
#         $PowerShellDef=@("In  Terminal öffnen (Admin)","`"$($WTLocation)`",0")
#     }
    Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{9F156763-7844-4DC4-B2B1-901F640F5155}" -ErrorAction SilentlyContinue # Terminal
    Remove-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" -Name "{02DB545A-3E20-46DE-83A5-1329B1E88B6B}" -ErrorAction SilentlyContinue # Terminal preview
}
else { # Hide "Open in terminal" entry to unify how the menu looks.
    SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
        -Name "{9F156763-7844-4DC4-B2B1-901F640F5155}" -EmptyValue $true # Terminal
    SetValue "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Shell Extensions\Blocked" `
        -Name "{02DB545A-3E20-46DE-83A5-1329B1E88B6B}" -EmptyValue $true # Terminal preview
}
CreateFileAssociation @("Directory\Background","Directory") `
    -ShellOperations @("cmd","VSCodeNoAdmin","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") `
    -ShellOpDisplayName @("","Hier VS Code öffnen","Hier VS Code öffnen (Administrator)","","","","$($PowerShellDef[0])","") `
    -Icon @("cmd.exe,0","`"$($VSCodeLocation)`",0","`"$($VSCodeLocation)`",0","`"C:\Program Files\Git\git-bash.exe`",0",`
        "`"C:\Program Files\Git\git-bash.exe`",0","$($PowerShellDef[1])","$($PowerShellDef[1])","`"$($WSLLocation)`",0") `
    -Extended @(0,0,0,1,1,$UWPFolderModded,0,0) `
    -LegacyDisable @(1,0,0,0,0,$UWPFolderModded,0,0) `
    -HasLUAShield @(0,0,1,0,0,0,1,0) `
    -MUIVerb @("","","","","","","@twinui.pcshell.dll,-10929","@wsl.exe,-2") `
    -Command @($(FixUWPCommand "wt.exe -d `"%V `" -p `"Eingabeaufforderung`"" $UWPFolderModded),`
        "`"$($VSCodeLocation)`" `"%v `"",`
        "PowerShell -windowstyle hidden -Command `"Start-Process '$($VSCodeLocation)' -ArgumentList '-d `"`"%V`"`"`"' -Verb RunAs`"",`
        $(FixUWPCommand "wt.exe new-tab --title Git-Bash --tabColor #300a16 --suppressApplicationTitle `"C:\Program Files\Git\bin\bash.exe`"" $UWPFolderModded),`
        "",` # git-gui no need to define
        $(FixUWPCommand "wt.exe  -d `"%V `" -p `"PowerShell`"" $UWPFolderModded),`
        "PowerShell -windowstyle hidden -Command `"Start-Process wt.exe -ArgumentList '-d `"`"%V `"`"`"' -Verb RunAs`"",$(FixUWPCommand "wt.exe -d `"%V `" -p `"Ubuntu`"" $UWPFolderModded))
Remove-Item -Path "Registry::HKCR\Directory\Background\DefaultIcon" -ErrorAction SilentlyContinue # Not needed
# Desktop functionality
CreateFileAssociation "DesktopBackground" -ShellOperations @("Display","Personalize") -Icon @("ddores.dll,-2109","shell32.dll,-270")
# Windows-Spotlight
if($CurrentBackgroundType -eq 3) {
    if((Test-Path "Registry::$($SpotlightCLSID)\shell\SpotlightClick")) {
        CreateFileAssociation "$($SpotlightCLSID)" -DefaultIcon "ddores.dll,-2553" -ShellOperations @("spotlightclick","spotlightdislike","spotlightlike","spotlightnext") `
            -Icon @("shell32.dll,-239","netshell.dll,-2301","netshell.dll,-2300","shell32.dll,-16805") -ShellOpDisplayName @("Hintergrundbild online suchen","","","")
        [string]$AllSpotlightCommands=""
        foreach($SpotlightShell in ((Get-ChildItem "Registry::HKCR\CLSID\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}\shell").Name)) {
            if($SpotlightShell -like "SpotlightClick") {
                Remove-Item "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\SpotlightClick" -Force `
                    -ErrorAction SilentlyContinue
                continue
            }
            [string]$SpotlightShellPur = $SpotlightShell.replace("$($SpotlightCLSID)\shell\","")
            Copy-Item -Path "Registry::$($SpotlightShell)" -Destination "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\" -Force
            # To avoid error on result hierarchy: Not using recurse here
            Copy-Item -Path "Registry::$($SpotlightShell)\command" -Destination `
                "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\$($SpotlightShellPur)" -Force
            $AllSpotlightCommands=$AllSpotlightCommands+"$($SpotlightShellPur); "
        }
        if($UseSpotlightDesktopIcon) {
            CreateKey "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
            SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Type 4 -Value 0 # Show "Windows Spotlight" icon from desktop
            Remove-Item "Registry::HKCR\DesktopBackground\Spotlight*" -Force
            Remove-Item "Registry::HKCR\DesktopBackground\Windows-Blickpunkt" -Force -ErrorAction SilentlyContinue
        }
        else {
            SetValue "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel" -Name "{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Type 4 -Value 1   # Hide "Windows Spotlight" icon from desktop
            Remove-Item -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}" -Force
            if($CascadeSpotlight) {
                Remove-Item "Registry::HKCR\DesktopBackground\Spotlight*" -Force
                CreateFileAssociation "HKCR\DesktopBackground" -ShellOperations "Windows-Blickpunkt" -Icon "ddores.dll,-2553"
                SetValue "HKCR\DesktopBackground\shell\Windows-Blickpunkt" -Name "MultiSelectModel" -Value "Player"
                SetValue "HKCR\DesktopBackground\shell\Windows-Blickpunkt" -Name "SubCommands" -Value "$($AllSpotlightCommands)"
                [string]$SpotlightClickHKCRLoc="HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell"
            }
            else {
                Remove-Item "Registry::HKCR\DesktopBackground\Windows-Blickpunkt" -Force -ErrorAction SilentlyContinue
                foreach($SpotlightShellOps in @("SpotlightNext")) {
                    Copy-Item -Path "Registry::$($SpotlightCLSID)\shell\$($SpotlightShellOps)" -Destination "Registry::HKCR\DesktopBackground\shell" -Force
                    Copy-Item -Path "Registry::$($SpotlightCLSID)\shell\$($SpotlightShellOps)\command" -Destination "Registry::HKCR\DesktopBackground\shell\$($SpotlightShellOps)" -Force
                }
                [string]$SpotlightClickHKCRLoc="DesktopBackground"
            }
            CreateFileAssociation $SpotlightClickHKCRLoc -ShellOperations "spotlightclick" -Icon "shwebsvc.dll,-201" -ShellOpDisplayName "Hintergrundbild online suchen" -Command "powershell.exe -Command `"`$URL= (Get-ItemProperty -LiteralPath 'Registry::$($SpotlightCLSID)\shell\SpotlightClick').EdgeUri ; `$URL=`$URL.substring(0,`$URL.IndexOf('%%')) ; Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -ArgumentList `$URL`""
        }
        foreach($PersonalizeHKCR in (Get-ChildItem "Registry::HKCR\DesktopBackground\shell\*").Name) {
            if(($PersonalizeHKCR -like "*Windows-Blickpunkt") -or ($PersonalizeHKCR -like "*Spotlight*")) {
                SetValue "$($PersonalizeHKCR)" -Name "Position" -Value "Bottom"
            }  
        }
    }
}
else {
    foreach($Key in @("HKCR\DesktopBackground\shell\Spotlightnext","HKCR\DesktopBackground\shell\Windows-Blickpunkt","HKCR\DesktopBackground\shell\PersonalizeNextPhoto","HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}","HKCR\DesktopBackground\shell\Spotlight*")) {
        Remove-Item -Path "Registry::$($Key)" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
# Show above mentioned entries only on directory background, NOT when clicking a folder
CreateFileAssociation "Directory" -ShellOperations @("cmd","VSCodeNoAdmin","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") -Extended @(1,1,1,1,1,1,1,1) -LegacyDisable @(1,1,1,1,1,1,1,1)
# Remove AMD Radeon context menu entries
RemoveAMDContextMenu
# -------Image files-------
[string]$GIMPLocation=(CheckInstallPath "GIMP 2\bin\gimp-2.10.exe")
[string]$PaintEditIcon="`"$($PaintAppLocation)`",0"
CreateFileAssociation "$($PaintAppHKCR)" -ShellOperations @("edit","edit2","print","printto") -Icon @("$($PaintEditIcon)","`"$($GIMPLocation)`",0","ddores.dll,-2414","ddores.dll,-2413") -ShellOpDisplayName @("","Mit GIMP öffnen","","") -MUIVerb @("@mshtml.dll,-2210","","@shell32.dll,-31250","@printui.dll,-14935") -Command @("","`"$($GIMPLocation)`" `"%1`"","","")
RegCopyPaste "HKCR\SystemFileAssociations\image" -Target "$($PaintAppHKCR)" -Shell @("edit","edit2","print","printto")
[string[]]$ImageFileExts=@("bmp","jpg","jpeg","png","016","256","ico","cur","ani","dds","tif","tiff","rri")
SetValue "HKCR\.256" -Name "PerceivedType" -Value "image"
foreach($ImageExt in $ImageFileExts) {
    if($ImageExt[0] -ne ".") {
        $ImageExt=".$($ImageExt)"
    }
    if($ImageExt -eq ".ani") {
        [string]$PhotoViewerCap="anifile"
    }
    elseif($ImageExt -eq ".cur") {
        [string]$PhotoViewerCap="curfile"
    }
    else {
        [string]$PhotoViewerCap="PhotoViewer.FileAssoc.Tiff"
        SetValue -RegPath "HKCR\$($ImageExt)" -Name "PerceivedType" -Value "image"
    }
    SetValue -RegPath "Registry::HKLM\SOFTWARE\Microsoft\Windows Photo Viewer\Capabilities\FileAssociations" -Type "string" -Name $ImageExt -Value "$($PhotoViewerCap)"
}
# Cursor file: show icon directly af file: DefaultIcon="%1"
foreach($CursorType in @("anifile","curfile")) {
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell" -Destination "Registry::HKCR\$($CursorType)" -force
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open" -Destination "Registry::HKCR\$($CursorType)\shell" -force
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open\command" -Destination "Registry::HKCR\$($CursorType)\shell\open" -force
    Copy-item -Path "Registry::HKCR\PhotoViewer.FileAssoc.Tiff\shell\open\droptarget" -Destination "Registry::HKCR\$($CursorType)\shell\open" -force
}
CreateFileAssociation "PhotoViewer.FileAssoc.Tiff" -ShellOperations "open" -Icon "`"C:\Program Files\Windows Photo Viewer\PhotoViewer.dll`",0" -DefaultIcon "shell32.dll,-51586" # "`"C:\Program Files\Windows Photo Viewer\PhotoAcq.dll`",-7"
$SysFileAssoExt=(Get-ChildItem "Registry::HKEY_CLASSES_ROOT\SystemFileAssociations\.*")
foreach($AssoExt in $SysFileAssoExt) {
    if(Test-Path "Registry::$($AssoExt.name)\shell\setdesktopwallpaper") {
        CreateFileAssociation "$($AssoExt.name)" -ShellOperations "setdesktopwallpaper" -Icon "imageres.dll,-110"
    }
}
# -------Audio and video files-------
# Check which media player is installed
[string[]]$MPlayers=@("VLC","WMP Legacy","WMP UWP")
[bool[]]$MPlayersInstalled=@((Test-Path "C:\Program Files\VideoLAN"),`
$WMPLegacyInstalled,` # Mentioned above to check if needed to take ownership of WMP11* keys
$WMPUWPInstalled)
if($MPlayersInstalled[0]) { # VLC installed
    Write-Host "$($MPlayers[0]) installed"
    CreateFileAssociation "Directory" -ShellOperations @("PlayWithVLC","AddtoPlaylistVLC") -LegacyDisable @(1,1)
    [string[]]$VLCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "VLC.*"})
    [string]$VLCFileName=""
    foreach($VLCKey in $VLCHKCR) {
        if($VLCKey -like "VLC.VLC*") {
            continue
        }
        [string]$VLCExtension=($VLCKey -replace 'VLC','' -Replace '.Document','')
        if(@('.bin','.dat','.','.iso') -contains $VLCExtension) { # Skip VLC.VLC.Document
            continue
        }
        [string]$VLCFileType=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($VLCExtension)" -ErrorAction SilentlyContinue).'PerceivedType'
        if($VLCFileType -like "audio") {
            [string]$VLCFileIcon="imageres.dll,-22"
            [string]$VLCFileName="@wiashext.dll,-279"
            if($VLCExtension -like ".mid*") {
                [string]$VLCFileName="@unregmp2.dll,-9993"
            }
        }
        elseif($VLCFileType -like "video" -or (@(".rmvb",".flv") -contains $VLCFileType)) {
            [string]$VLCFileIcon="imageres.dll,-23"
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
        if((Get-ItemProperty -LiteralPath "Registry::$($Key)\shell\play" -ErrorAction SilentlyContinue)."Icon" -like "imageres.dll,-5201") {
            break
        }
        CreateFileAssociation $Key -ShellOperations @("Enqueue","play") `
            -Icon @("wlidcli.dll,-1008","imageres.dll,-5201") `
            -MUIVerb @("@shell32.dll,-37427","@shell32.dll,-22072")
    }
}
elseif($MPlayersInstalled[2]) { # WMP UWP installed
    [string]$WMPAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)\Application" -ErrorAction SilentlyContinue).ApplicationName -like "*Microsoft.ZuneMusic*"})[0]
    CreateFileAssociation "$($WMPAppHKCR)" -ShellOperations @("open","enqueue","play") -ShellDefault "play" -LegacyDisable @(1,0,0) -Icon @("","shell32.dll,-16752","imageres.dll,-5201") -DefaultIcon "imageres.dll,-134" -MUIVerb @("","@shell32.dll,-37427","")
}
# --------EXE File--------
CreateFileAssociation "exefile" -ShellOperations @("open","runas") `
    -Icon @("imageres.dll,-100","imageres.dll,-100") `
    -MUIVerb @("@shell32.dll,-12710","") -HasLUAShield @(0,1)
# -------Screensaver-------
CreateFileAssociation "scrfile" -FileAssoList ".scr" -DefaultIcon "%1" `
    -ShellOperations @("config","install","open") `
    -Icon @("mmcndmgr.dll,-30572","setupugc.exe,-133","webcheck.dll,-407")
# ---------TXT File---------
CreateFileAssociation @("txtfile","textfile","SystemFileAssociations\text") `
    -DefaultIcon "imageres.dll,-19" `
    -ShellOperations @("open","edit") `
    -ShellDefault "open" `
    -LegacyDisable @(0,1) `
    -Icon @("`"$($VSCodeLocation)`",0","`"$($VSCodeLocation)`",0") `
    -Command @("`"$($VSCodeLocation)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"") `
    -MUIVerb @("@mshtml.dll,-2210","")
if(Test-Path "Registry::HKCR\txtfile\shell\print\command") {
    CreateFileAssociation @("txtfile","textfile") -ShellOperations @("print","printto") `
        -Icon @("ddores.dll,-2413","ddores.dll,-2414") `
        -Extended @(1,1) -LegacyDisable @(1,1)
}
# ------- Cheat Engine Cheat Table-------
if(Test-Path "Registry::HKCR\CheatEngine\DefaultIcon") {
    [string]$CheatEnginePath=(Get-ItemProperty -LiteralPath "Registry::HKCR\CheatEngine\DefaultIcon").'(default)' -replace ',0',''
    CreateFileAssociation "CheatEngine" -shelloperations @("open","edit") -Icon @("$($CheatEnginePath)","`"$($VSCodeLocation)`",0") -Command @("","`"$($VSCodeLocation)`" `"%1`"")
}

# --------VBE, VBS and JSE (JavaScript) Script--------
CreateFileAssociation @("$($VSCodeVerHKCR).vb","VBSFile","VBEFile","JSEFile") `
    -ShellOperations @("open","open2","print","edit") `
    -Icon @("wscript.exe,-1","cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeLocation)`",0") `
    -MUIVerb @("@shell32.dll,-12710","@wshext.dll,-4511","","") `
    -Command @("WScript.exe `"%1`" %*","CScript.exe `"%1`" %*","","`"$($VSCodeLocation)`" `"%1`"") `
    -FileAssoList @("vb","vbs","vbe","jse") `
    -Extended @(0,0,1,0) -LegacyDisable @(0,0,1,0)
# --------BAT, CMD, COM script-------
CreateFileAssociation @("BATFile","CMDFile","COMFile") `
    -DefaultIcon "$($VSCodeIconsLoc)\shell.ico" `
    -ShellOperations @("open","print","edit","runas") `
    -Icon @("cmd.exe,0","DDOres.dll,-2414","`"$($VSCodeLocation)`",0","cmd.exe,0") `
    -MUIVerb @("@shell32.dll,-12710","","","") `
    -Command @("","","`"$($VSCodeLocation)`" `"%1`"","") `
    -Extended @(0,1,0,0) -LegacyDisable @(0,1,0,0)
# --------Registry file--------
CreateFileAssociation "regfile" -ShellOperations @("open","edit","print") `
    -Icon @("regedit.exe,0","`"$($VSCodeLocation)`",0","DDORes.dll,-2413") `
    -Extended @(0,0,1) -ShellDefault "open"`
    -command @("","`"$($VSCodeLocation)`" `"%1`"","")
# ------- Python script -------
if(($PythonVerInstalled.Count -gt 0) -and ($UWPFolderModded)) {
    CreateFileAssociation "$($PythonFileHKCR)" -shelloperations @("open","edit") -Icon @("$($PythonInstallLoc)","`"$($VSCodeLocation)`",0") -Command ("","`"$($VSCodeLocation)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","")
}
# -------XML Document-------
Remove-ItemProperty -Path "Registry::HKCR\.xml" -Name "PreceivedType" -ErrorAction SilentlyContinue
foreach($ML_Ext in @("xml","htm","html")) {    
    Remove-ItemProperty -Path "Registry::HKCR\.$($ML_Ext)\OpenWithProgids" -Name "MSEdgeHTM" -ErrorAction SilentlyContinue 
}
CreateFileAssociation @("xmlfile","$($VSCodeVerHKCR).xml") -FileAssoList ".xml" -DefaultIcon "msxml3.dll,-128" `
    -ShellOperations @("open","edit") -ShellDefault "edit" `
    -Icon @("ieframe.dll,-31065","`"$($VSCodeLocation)`",0") -MUIVerb @("@ieframe.dll,-21819","")`
    -Command @("`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`" --single-argument %1","`"$($VSCodeLocation)`" `"%1`"") `
    -CommandId @("IE.File","") `
    -DelegateExecute @("{17FE9752-0B5A-4665-84CD-569794602F5C}","")
Remove-Item "Registry::HKCR\xmlfile\ShellEx\IconHandler" -ErrorAction SilentlyContinue
# ------- PS1 Script ------
CreateFileAssociation @("Microsoft.PowerShellScript.1","$($VSCodeVerHKCR).ps1") `
    -DefaultIcon "$($VSCodeIconsLoc)\powershell.ico"`
    -ShellOperations @("open","edit","runas") `
    -Icon @("scrptadm.dll,-7","`"$($VSCodeLocation)`",0","C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,1") -MUIVerb @("@`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`",-108","","") `
    -Command @("`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`"  `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`"","`"$($VSCodeLocation)`" `"%1`"","`"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`" `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`" -Verb RunAs")
CreateFileAssociation "SystemFileAssociations\.ps1" -ShellOperations "Windows.PowerShell.Run" -LegacyDisable $true
Remove-Item "Registry::HKCR\Microsoft.PowerShellScript.1\shell\0" -ErrorAction SilentlyContinue
# ------- LOG File ------
SetValue "HKCR\.log" -Name "Content Type" -Value "text/plain"
SetValue "HKCR\.log" -Name "PerceivedType" -Value "text"
# ------- All the rest VSCode files ------
[string[]]$VSCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "$($VSCodeVerHKCR).*"})
foreach($Key in $VSCHKCR) {
    if((Get-ItemProperty "Registry::HKCR\$($Key)\shell\open\command" -ErrorAction SilentlyContinue).'(default)' -like "*$($VSCodeLocation)*") {
        CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "`"$($VSCodeLocation)`",0" -MUIVerb "@shell32.dll,-37398" -Extended 0
    }
    else {
        # Do nothing. Those are probably defined somewhere else.
    }
}
foreach($VSCodeAppHKCR in @("Code.exe","Code - Insiders.exe")) {
    if(Test-Path "Registry::HKCR\Applications\$($VSCodeAppHKCR)") {
        CreateFileAssociation "Applications\$($VSCodeAppHKCR)" -ShellOperations "open" -Icon "`"$($VSCodeLocation)`",0" -MUIVerb "@certmgr.dll,-291"
    }
}
# Give "Text" property to all VS Code related files
foreach($FileExt in (Get-ChildItem "Registry::HKCR\.*").Name) {
    [string]$ProgID=(Get-ItemProperty -LiteralPath "Registry::$($FileExt)\OpenWithProgIds" -ErrorAction SilentlyContinue) 
    if(($ProgID -like "*$($VSCodeVerHKCR).*") -and (-not (Test-Path "Registry::$($FileExt)\PersistentHandler"))) {
        # Change item type to text. Let Windows Search index the items
        CreateKey "$($FileExt)\PersistentHandler" -StandardValue "{5e941d80-bf96-11cd-b579-08002b30bfeb}"
    }
}
# ________________
# PDF Document
CreateFileAssociation "MSEdgePDF" -ShellOperations "open" -Icon "ieframe.dll,-31065" -MUIVerb "@ieframe.dll,-21819"
# SumatraPDF related
[string]$SumatraPDFLoc=$(CheckInstallPath "SumatraPDF\sumatrapdf.exe")
[bool]$SumatraPDFInstalled=$(Test-Path "$($SumatraPDFLoc)")
if($SumatraPDFInstalled) {
    [string[]]$SumatraPDFHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "SumatraPDF*"})
    foreach($Key in $SumatraPDFHKCR) { # $SumatraPDFHKCR do not contain HKCR\ prefix
        if($Key -like "*epub") {
            [int]$IconNr=3
        }
        if($Key -like "*cb?") {
            [int]$IconNr=4
        }
        else {
            [int]$IconNr=2
        }
        [string]$SumatraICO="`"$($SumatraPDFLoc)`",-$($IconNr)"
        CreateFileAssociation "$($Key)" -DefaultIcon "$($SumatraICO)" -ShellOperations "open" -MUIVerb "@appmgr.dll,-652"
        if($Key -like "*chm") {
            CreateFileAssociation "$($Key)" -DefaultIcon "imageres.dll,-99" -ShellOperations @("open","open2") -MUIVerb @("@appmgr.dll,-652","@srh.dll,-1359") -Icon ("","C:\Windows\hh.exe") -Command @("","C:\Windows\hh.exe `"$1`"")
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\print") {
            SetValue "HKCR\$($Key)\shell\print" -Name "Icon" -Value "ddores.dll,-2414" -LegacyDisable $true
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\printto") {
            SetValue "HKCR\$($Key)\shell\printto" -Name "Icon" -Value "ddores.dll,-2413" -LegacyDisable $true
            [string]$KeyWithPrint="$($Key)"
        }
    }
    CreateFileAssociation "MSEdgePDF" -ShellOperations @("open2","print") -Icon @("`"$($SumatraPDFLoc)`",0","ddores.dll,-2414") -ShellOpDisplayName @("Mit SumatraPDF öffnen","")
    Copy-Item -Path "Registry::HKCR\$($Key)\shell\open\command" -Destination "Registry::HKCR\MSEdgePDF\shell\open2" -Force
    foreach($PrintAction in @("print","printto")) {
        Copy-Item -Path "Registry::HKCR\$($KeyWithPrint)\shell\$($PrintAction)" -Destination "Registry::HKCR\MSEdgePDF\shell" -Force -Recurse -ErrorAction SilentlyContinue
    }
}
# --------HTML file--------
[string]$OpenHTMLVerb="@ieframe.dll,-14756"
if($BrowserIcon -like "ieframe.dll,-31065") {
    $OpenHTMLVerb="@ieframe.dll,-21819"
}
CreateFileAssociation @("htmlfile","$($VSCodeVerHKCR).htm","$($VSCodeVerHKCR).html","MSEdgeHTM","Applications\MSEdge.exe") -DefaultIcon "ieframe.dll,-210" -ShellOperations @("open","edit","print","printto") -Icon @("$($BrowserIcon)","`"$($VSCodeLocation)`",0","DDORes.dll,-2414","DDORes.dll,-2413") -Command @("$($BrowserOpenAction)","`"$($VSCodeLocation)`" `"%1`"","","") -MUIVerb @("$($OpenHTMLVerb)","","","") -LegacyDisable @(0,0,1,1)
# ------- URL Internet Shortcut -------
foreach($PropertyToBeRemoved in @("NeverShowExt")) { #,"IsShortcut"
    Remove-ItemProperty -Path "Registry::HKCR\InternetShortcut" -Name $PropertyToBeRemoved -ErrorAction SilentlyContinue
}
Remove-Item -Path "Registry::HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}" -Force
CreateFileAssociation "InternetShortcut" -DefaultIcon "url.dll,-5" -ShellOperations @("open","edit","print","printto") -Icon @("$($BrowserIcon)","`"$($VSCodeLocation)`",0","ddores.dll,-2414","ddores.dll,-2413") -MUIVerb @("@synccenter.dll,-6102",,"","","") -LegacyDisable @(0,0,1,1) -Command @("powershell.exe -Command `"`$URL= ((Get-Content '%1') -like 'URL=*') -replace 'URL=',' '; Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -ArgumentList `$URL`"","`"$($VSCodeLocation)`" `"%1`"","","")
# --------Google Chrome HTML (if Chrome installed)--------
if($ChromeInstalled) {
    CreateFileAssociation "ChromeHTML" -DefaultIcon "shell32.dll,-14" `
    -ShellOperations @("open","edit") -MUIVerb @("@ieframe.dll,-10064","") `
    -Icon @("`"$($ChromePath)`",0","`"$($VSCodeLocation)`",0") `
    -Command @("`"$($ChromePath)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"")
}
# ---------MS Office files---------
if($MSOfficeInstalled) {
    # PPT
    [string[]]$PPTHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {(($_ -like "PowerPoint.Show*") -or ($_ -like "PowerPoint.Slide*")) -and (Test-Path "Registry::HKCR\$_\shell\edit")})
    foreach($Key in $PPTHKCR) {
        CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","Open","OpenAsReadOnly","Print","PrintTo","Show","ViewProtected") -Icon @("","shell32.dll,-133","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`",-1300","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`",-1300","ddores.dll,-2414","ddores.dll,-2413","imageres.dll,-103","") -LegacyDisable @(1,0,0,0,0,0,0,1) -Extended @(1,0,0,0,0,0,0,1) -Command ("","","","","","`"$($MSOfficeLoc)\Office16\POWERPNT.EXE`" /pt `"%2`" `"%3`" `"%4`" `"%1`"","","")
    }
    # WORD
    [string[]]$DOCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Word.*Document*.*") -and (Test-Path "Registry::HKCR\$_\shell\edit")})
    foreach($Key in $DOCHKCR) {
        CreateFileAssociation "$($Key)" -ShellOperations @("Edit","New","OnenotePrintto","Open","OpenAsReadOnly","Print","PrintTo","ViewProtected") -Icon @("","shell32.dll,-133","","`"$($MSOfficeLoc)\Office16\WINWORD.EXE`",-1","`"$($MSOfficeLoc)\Office16\WINWORD.EXE`",-1","ddores.dll,-2414","ddores.dll,-2413","") -LegacyDisable @(1,0,1,0,0,0,0,1) 
    }
    # EXCEL
    [string[]]$XLSHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {($_ -like "Excel.*") -and (Test-Path "Registry::HKCR\$_\shell\print")})
    foreach($Key in $XLSHKCR) {
        CreateFileAssociation "$($Key)" -ShellOperations @("Open","print") -Icon @("$($MSOfficeLoc)\Office16\EXCEL.EXE,-257","ddores.dll,-2414")
        foreach($OtherShellOp in @("Edit","New","OpenAsReadOnly","Printto","ViewProtected")) {
            if(Test-Path "Registry::HKCR\$($Key)\shell\$($OtherShellOp)") {
                [bool]$ExcelHidden=$false
                if($OtherShellOp -like "New") {
                    [string]$ExcelIcon="shell32.dll,-133"
                }
                elseif($OtherShellOp -like "PrintTo") {
                    [string]$ExcelIcon="ddores.dll,-2413"
                }
                else {
                    [string]$ExcelIcon="$($MSOfficeLoc)\Office16\EXCEL.EXE,-257"
                    if(@("Edit","ViewProtected") -contains $OtherShellOp) {
                        [bool]$ExcelHidden=$true
                    }
                }
                CreateFileAssociation "$($Key)" -ShellOperations "$($OtherShellOp)" -Icon "$($ExcelIcon)" -LegacyDisable $ExcelHidden
            }
        }
    }
    # Outlook ICS Calender
    CreateFileAssociation "Outlook.File.ics.15" -DefaultIcon "dfrgui.exe,-137" -ShellOperations "open" -Icon "$($MSOfficeLoc)\Office16\OUTLOOK.exe,-3"
}
elseif($LibreOfficeInstalled) {
    [string[]]$LibreOfficeHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "LibreOffice.*"})
    foreach($Key in $LibreofficeHKCR) {
        $OfficeIcon=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\DefaultIcon").'(default)'
        CreateFileAssociation "$($Key)" -ShellOperations "Open" -Icon "$($OfficeIcon)"
        if(Test-Path "Registry::HKCR\$($Key)\shell\New") {
            CreateFileAssociation "$($Key)" -ShellOperations "New" -Icon "shell32.dll,-133"
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\Print") {
            CreateFileAssociation "$($Key)" -ShellOperations "Print" -Icon "DDORes.dll,-2414"
        }
        if(Test-Path "Registry::HKCR\$($Key)\shell\PrintTo") {
            CreateFileAssociation "$($Key)" -ShellOperations "PrintTo" -Icon "DDORes.dll,-2413"
        }
    }
}
else {
    # PPT
    CreateFileAssociation "PPTFile" -FileAssoList @(".ppt",".pptx") -DefaultIcon "imageres.dll,-8312" -TypeName "@explorerframe.dll,-50295" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    # WORD
    CreateFileAssociation "DOCFile" -FileAssoList @(".doc",".docx","odt") -DefaultIcon "imageres.dll,-8302" -TypeName "@explorerframe.dll,-50293" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
    # EXCEL
    CreateFileAssociation "XLSFile" -FileAssoList @(".xls",".xlsx","xlsm") -DefaultIcon "imageres.dll,-8320" -TypeName "@explorerframe.dll,-50294" -ShellOperations "open" -Icon "$($BrowserIcon)" -command "$($BrowserOpenAction)"
}
# PFX Certificate
CreateFileAssociation "pfxfile" -ShellOperations @("add","open") -Extended @(0,1) -LegacyDisable @(0,1) `
    -Icon @("certmgr.dll,-6169","certmgr.dll,-6169") -MUIVerb @("@cryptext.dll,-6126","") -ShellDefault "add"
# INI /INF Config file
CreateFileAssociation @("inifile","inffile") `
    -FileAssoList @("forger2","conf") `
    -ShellOperations @("open","print") `
    -Command @("`"$($VSCodeLocation)`" `"%1`"","") `
    -MUIVerb @("@mshtml.dll,-2210","") `
    -Icon @("`"$($VSCodeLocation)`",0","DDORes.dll,-2413") `
    -Extended @(0,1) -LegacyDisable @(0,1) `
    -DefaultIcon "imageres.dll,-69"
# INF File Install
CreateFileAssociation "SystemFileAssociations\.inf" -ShellOperations "install" -Icon "msihnd.dll,-10"
# SRT Subtitles
[string]$SEditLoc="C:\Program Files\Subtitle Edit\SubtitleEdit.exe"
if(Test-Path "$($SEditLoc)") {
    [string[]]$SubtitleTypes=(Get-ChildItem "$($SEditLoc.replace("\SubtitleEdit.exe","\Icons\*"))").BaseName # Only file name without extension
    foreach($SubtitleType in $SubtitleTypes) {
        if($SubtitleType -like "uninstall") {
            continue
        }
    CreateFileAssociation "SubtitleEdit.$($SubtitleType)" `
        -DefaultIcon "`"$($SEditLoc -replace "\SubtitleEdit.exe","\icons\$($SubtitleType).ico")`"" `
        -ShellOperations @("open","edit") -FileAssoList "$($SubtitleType)" `
        -Icon @("`"$($SEditLoc)`",0","`"$($VSCodeLocation)`",0") `
        -Command @("`"$($SEditLoc)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"")
    }
}
# CRDownload and !qB partially downloaded files
CreateFileAssociation "Downloading" -FileAssoList @("crdownload","!qB") -DefaultIcon "shell32.dll,-231"
# ISO File
CreateFileAssociation "Windows.ISOFile" -ShellOperations "burn" -Icon "shell32.dll,-16768"
# _____________________________
# ____Explorer Namespaces_____
# Change trash bin empty icon
SetValue -RegPath "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\empty" -Name "Icon" -Value "imageres.dll,-5305"
# Add trash bin to this PC
SetValue -RegPath "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}" -Name "DescriptionID" -Type "dword" -Value 0x16
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{645FF040-5081-101B-9F08-00AA002F954E}"
# Change "Manage" icon
SetValue -RegPath "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "Icon" -Value "mycomput.dll,-204"
Remove-ItemProperty -Path "Registry::HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "HasLUAShield" -ErrorAction SilentlyContinue
# ------ CONTROL PANEL ------
# Change control panel icons
CreateFileAssociation @("CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}","CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}") -DefaultIcon "Control.exe,0" -Icon "Control.exe,0" -ShellOperations "open" -MUIVerb "@shell32.dll,-10018" -command "control.exe"
SetValue -RegPath "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}" -name "DescriptionID" -Type "dword" -Value 0x16
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
CreateFileAssociation "CLSID\{60632754-c523-4b62-b45c-4172da012619}" -DefaultIcon "imageres.dll,-79" # Control panel - user accounts
CreateFileAssociation "CLSID\{7b81be6a-ce2b-4676-a29e-eb907a5126c5}" -DefaultIcon "wusa.exe,-101" # Control panel - Programs and Features
CreateFileAssociation "CLSID\{62D8ED13-C9D0-4CE8-A914-47DD628FB1B0}" -DefaultIcon "imageres.dll,-144" # Control panel - Region and Language
CreateFileAssociation "CLSID\{725BE8F7-668E-4C7B-8F90-46BDB0936430}" -DefaultIcon "ddores.dll,-2210" # Control panel - Keyboard properties
CreateFileAssociation "CLSID\{6C8EEC18-8D75-41B2-A177-8831D59D2D50}" -DefaultIcon "ddores.dll,-2212" # Control panel - Mouse properties
CreateFileAssociation "CLSID\{D555645E-D4F8-4c29-A827-D93C859C4F2A}" -DefaultIcon "shell32.dll,-268" # Control panel - Ease of access center
CreateFileAssociation "CLSID\{9C60DE1E-E5FC-40f4-A487-460851A8D915}" -DefaultIcon "imageres.dll,-5362" # Control panel - AutoPlay
CreateFileAssociation "CLSID\{A8A91A66-3A7D-4424-8D24-04E180695C7A}" -DefaultIcon "imageres.dll,-196" # Control panel - Devices and Printers
[string]$OneDriveInstallLoc=(CheckInstallPath "Microsoft\OneDrive\OneDrive.exe")
if(Test-Path "$($OneDriveInstallLoc)") {
    [string]$WorkFolderIcon="`"$($OneDriveInstallLoc)`",-589"
}
else {
    [string]$WorkFolderIcon="WorkFoldersRes.dll,-1"
}
CreateFileAssociation "CLSID\{ECDB0924-4208-451E-8EE0-373C0956DE16}" -DefaultIcon "$($WorkFolderIcon)" # Control panel - Work folders
CreateFileAssociation "CLSID\{BB06C0E4-D293-4f75-8A90-CB05B6477EEE}" -DefaultIcon "mstsc.exe,-20022" # Control panel - System
CreateFileAssociation "CLSID\{BD84B380-8CA2-1069-AB1D-08000948F534}" -DefaultIcon "imageres.dll,-129" # Control panel - Font folder
CreateFileAssociation "CLSID\{93412589-74D4-4E4E-AD0E-E0CB621440FD}" -DefaultIcon "main.cpl,-106" # Control panel - Font settings
CreateFileAssociation "CLSID\{58E3C745-D971-4081-9034-86E34B30836A}" -DefaultIcon "ddores.dll,-2014" # Control panel - Speech recognition
CreateFileAssociation "CLSID\{025A5937-A6BE-4686-A844-36FE4BEC8B6D}" -DefaultIcon "ddores.dll,-2143" # Power options
CreateFileAssociation "CLSID\{80F3F1D5-FECA-45F3-BC32-752C152E456E}" -DefaultIcon "ddores.dll,-2108" # Tabet PC Settings
CreateFileAssociation "CLSID\{87D66A43-7B11-4A28-9811-C86EE395ACF7}" -DefaultIcon "imageres.dll,-1025" # Indexing options
CreateFileAssociation "CLSID\{9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF}" -DefaultIcon "mobsync.exe,-1" # Sync center
CreateFileAssociation "CLSID\{A3DD4F92-658A-410F-84FD-6FBBBEF2FFFE}" -DefaultIcon "ieframe.dll,-211" # Internet options
# Add "Personalization" to Control Panel
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel\NameSpace\{ED834ED6-4B5A-4bfe-8F11-A626DCB6A921}"
# ------
# Use legacy context menu
CreateKey "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
# Remove common groups folder
if($RemoveCommonStartFolder) {
    foreach($RegRt in @("HKCU","HKLM")) {
        SetValue "$($RegRt)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoCommonGroups" -Type "dword" -Value "0"
    }
}
# Show "Details" tile in Windows Explorer
# SetValue "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Modules\GlobalSettings\DetailsContainer" -Name "DetailsContainer" -Type 3 -Value "01,00,00,00,02,00,00,00" # Type 3 means binary
# Show library folders in Explorer
foreach($LibraryFolder in ((Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\")+(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\")).Name) {
    Remove-ItemProperty -Path "Registry::$($LibraryFolder)" -Name "HideIfEnabled" -ErrorAction SilentlyContinue
    if(((Get-ItemProperty -LiteralPath "Registry::$($LibraryFolder)").'(default)') -like "CLSID_*RegFolder") {
        Remove-Item -Path "Registry::$($LibraryFolder)" -ErrorAction SilentlyContinue
        New-Item -Path "Registry::$($LibraryFolder)"
    }
}
foreach($LibraryFolder in @("{d3162b92-9365-467a-956b-92703aca08af}","{088e3905-0323-4b02-9826-5d99428e115f}","{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}","{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}","{24ad3ad4-a569-4530-98e1-ab02f9417aa8}")) {
    Rename-ItemProperty -Path "Registry::HKCR\CLSID\$($LibraryFolder)" -Name "System.IsPinnedToNameSpaceTree_Old" -NewName "System.IsPinnedToNameSpaceTree" -ErrorAction SilentlyContinue
    if($LibraryFolder -Notlike "{088e3905-0323-4b02-9826-5d99428e115f}") { 
        # Hide "Music", "Photos", "Videos" and "Documents" because they are also retrievable from library. Keep "Download" only
        SetValue "HKCR\CLSID\$($LibraryFolder)" -Name "System.IsPinnedToNameSpaceTree" -Type "dword" -Value 0 
    }
}
# Icon revert to standard library
CreateFileAssociation "CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -ShellOperations "restorelibraries" -Icon "shell32.dll,-16803" -Extended 1
Remove-ItemPeoperty -Path "Registry::HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" -Name "SeparatorBefore" -ErrorAction SilentlyContinue
Remove-ItemPeoperty -Path "Registry::HKCR\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}\shell\restorelibraries" -Name "SeparatorAfter" -ErrorAction SilentlyContinue
# Remove most folders from desktop
foreach($DesktopFolderNamespace in (Get-ChildItem "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace_3*")) {
    Remove-Item $DesktopFolderNamespace
}
# Recover some folders to desktop
foreach($DesktopFolderNamespaceRec in @("{f874310e-b6b7-47dc-bc84-b9e6b38f5903}","{679f85cb-0220-4080-b29b-5540cc05aab6}","{59031a47-3f72-44a7-89c5-5595fe6b30ee}")) {
    New-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$($DesktopFolderNamespaceRec)"
}
# Pin Userprofile to tree
New-ItemProperty -Path "Registry::HKCR\CLSID\{59031a47-3f72-44a7-89c5-5595fe6b30ee}" -Name "System.IsPinnedToNameSpaceTree" -Value 1 -PropertyType "4"
# Change Quick Access icon
CreateFileAssociation @("CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}","CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}") -DefaultIcon "shell32.dll,-51380" -ShellOperations "pintohome" -Icon "shell32.dll,-322" -TypeName "@propsys.dll,-42249"
# Change desktop icon
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon" -StandardValue "DDORes.dll,-2068" # My PC
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{59031A47-3F72-44A7-89C5-5595FE6B30EE}\DefaultIcon" -StandardValue "Shell32.dll,-279" # User profile
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon" -StandardValue "imageres.dll,-120" # Network places
foreach($SearchCLSID in @("HKCR\CLSID")) { # ,"HKCR\WOW6432Node\CLSID"
    # Change OneDrive (private) and OneDrive (business) icon and name
    [object[]]$OneDriveCLSIDs=((Get-ChildItem "Registry::$($SearchCLSID)" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)").'(default)' -like "Onedrive -*"} ))
    foreach($OneDriveCLSID in $OneDriveCLSIDs) {
        [string]$OneDriveCLSIDPur=$OneDriveCLSID.Name.Substring($OneDriveCLSID.Name.LastIndexOf('\')+1,$OneDriveCLSID.Name.length-$OneDriveCLSID.Name.LastIndexOf('\')-1)
        [string]$OneDriveName=((Get-ItemProperty -LiteralPath "Registry::$($OneDriveCLSID)").'(default)')
        if(($OneDriveName -like "*Personal") -or ($OneDriveName -like "*Privat")) {
            CreateKey "$($OneDriveCLSID.Name)" -StandardValue "OneDrive - Privat"
            CreateFileAssociation "$($OneDriveCLSID.Name)" -DefaultIcon "`"$($OneDriveInstallLoc)`",-588"
        }
        elseif(($OneDriveName -like "*Arbeit") -or ($OneDriveName -like "*GmbH*")) {
            CreateKey "$($OneDriveCLSID.Name)" -StandardValue "OneDrive - Arbeit"
            CreateFileAssociation "$($OneDriveCLSID.Name)" -DefaultIcon "`"$($OneDriveInstallLoc)`",-589"
        }
        SetValue "$($OneDriveCLSID.Name)" -Name "System.IsPinnedToNameSpaceTree" -Type "4" -Value 1
        Remove-ItemProperty -Path "Registry::$($OneDriveCLSID.Name)" -Name "DescriptionID"
        SetValue "$($OneDriveCLSID.Name)" -Name "DescriptionID" -Type "4" -Value 9 # 4=DWORD
        CreateKey "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSIDPur)"
    }
    $BusinessOneDrive=(Get-ChildItem "Registry::HKEY_CURRENT_USER\Software\Microsoft\OneDrive\Accounts\Business*").Name
    foreach($Business in $BusinessOneDrive) {
        Set-ItemProperty -Path "Registry::$($Business)" -Name "DisplayName" -Value "Arbeit"
    }
    # ——————————————
    # DropBox
    [string]$DropBoxInstallLoc="C:\Program Files (x86)\Dropbox\Client\Dropbox.exe"
    if(Test-Path "$($DropBoxInstallLoc)") {
        [object[]]$DropBoxCLSIDs=((Get-ChildItem "Registry::$($SearchCLSID)" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)").'(default)' -like "Dropbox"} ))
        foreach($DropBoxCLSID in $DropBoxCLSIDs) {
            SetValue "$($DropBoxCLSID)" -Name "DescriptionID" -Type "dword" -Value 9
            CreateFileAssociation "$($DropBoxCLSID)" -DefaultIcon "`"$($DropBoxInstallLoc)`",-13001"
            $CLSID=(Split-Path  $DropboxCLSID.Name -leaf)
            SetValue "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons" -Name "$($CLSID)" -Type "dword" -Value 1
            if(Test-Path "Registry::$($DropBoxCLSID)\Instance\InitPropertyBag") {
                MakeReadOnly "$($DropboxCLSID)"
                CreateKey "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\Namespace\$($CLSID)"
                break
            }
        }
    }
    # ——————————————
    # Box Drive
    [string]$BoxInstallLoc="C:\Program Files\Box\Box\Box.exe"
    if(Test-Path "$($BoxInstallLoc)") {
        [object[]]$BoxDriveCLSIDs=((Get-ChildItem "Registry::$($SearchCLSID)" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)").'(default)' -like "Box"} ))
        foreach($BoxDriveCLSID in $BoxDriveCLSIDs) {
            SetValue "$($BoxDriveCLSID.Name)" -Name "DescriptionID" -Type "4" -Value 9
            Set-ItemProperty -Path "Registry::$($BoxDriveCLSID.Name)\DefaultIcon" -Name '(Default)' -Value "`"$($BoxInstallLoc)`""
            if(Test-Path "Registry::$($BoxDriveCLSID)\Instance") { # Box Drive Entry without online status overlay. Looks like traditional folder
                Set-ItemProperty -Path "Registry::$($BoxDriveCLSID)" -Name "System.IsPinnedToNameSpaceTree" -Value 0
            }
            if($?) {
                MakeReadOnly "$($BoxDriveCLSID.Name)\DefaultIcon" -InclAdmin
            }
            
        }
    }
}
# ————————————————
# Modify Google Drive
$GoogleDriveReg=@'
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}]
@="Google Drive"
"DescriptionID"=dword:00000009
"System.IsPinnedToNameSpaceTree"=dword:00000001
"SortOrderIndex"=dword:00000042

[HKEY_CLASSES_ROOT\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}\DefaultIcon]
@="\"C:\\Program Files\\Google\\Drive File Stream\\drive_fs.ico\",0"

[HKEY_CLASSES_ROOT\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}\InProcServer32]
@=hex(2):25,00,73,00,79,00,73,00,74,00,65,00,6d,00,72,00,6f,00,6f,00,74,00,25,\
  00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,73,00,68,00,\
  65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,00,00

[HKEY_CLASSES_ROOT\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}\Instance]
"CLSID"="{0E5AAE11-A475-4c5b-AB00-C66DE400274E}"

[HKEY_CLASSES_ROOT\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}\Instance\InitPropertyBag]
"Attributes"=dword:00000011
"TargetFolderPath"="A:\\"

[HKEY_CLASSES_ROOT\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}\ShellFolder]
"FolderValueFlags"=dword:00000028
"Attributes"=dword:f080004d

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{9499128F-5BF8-4F88-989C-B5FE5F058E79}]
@="Google Drive"

[HKEY_CURRENT_USER\SOFTWARE\Google\DriveFS]
"PerAccountPreferences"="{\"per_account_preferences\":[{\"key\":\"111142118877551513951\",\"value\":{\"mount_point_path\":\"A\"}}]}"
"DoNotShowDialogs"="{\"mount_point_changed\":true,\"preferences_dialog_tour\":true,\"spork_tour_notification\":true}"
"PromptToBackupDevices"=dword:00000000

[HKEY_CURRENT_USER\SOFTWARE\Google\DriveFS\Share]
"SyncTargets"=hex:0a,1d,0a,17,0a,15,31,31,31,31,34,32,31,31,38,38,37,37,35,35,\
  31,35,31,33,39,35,31,12,02,41,3a
"ShellIpcEnabled"=dword:00000001

; Remove Google Docs in "New" context menu. Need to turn these keys to read-only to prevent changing.
'@
if(Test-Path "C:\Program Files\Google\Drive File Stream\drive_fs.ico") {
    ImportReg $GoogleDriveReg
    SetValue -RegPath "HKEY_CURRENT_USER\Software\Google\DriveFS\Share" -Name "BasePath" -Value "$($env:LOCALAPPDATA)\Google\DriveFS"
    SetValue -RegPath "HKEY_CURRENT_USER\Software\Google\DriveFS\Share" -Name "ShellIpcPath" -Value "\\.\Pipe\GoogleDriveFSPipe_$($env:UserName)_shell"
}
else {
    remove-item "Registry::HKCR\CLSID\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -Force -Recurse -ErrorAction SilentlyContinue
    remove-item "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{9499128F-5BF8-4F88-989C-B5FE5F058E79}" -ErrorAction SilentlyContinue
}
# ________________
# Hide unwanted drive letters
[string[]]$DriveLetters=(Get-PSDrive -PSProvider FileSystem).Name
[int]$HiddenDrives=0
if($DriveLetters -contains "A") {
    $HiddenDrives=$HiddenDrives+1
}
if($DriveLetters -contains "P") {
    if((Get-Volume P).FileSystemLabel -like "pcloud*") {
        # PCloud installed
        $HiddenDrives=$HiddenDrives+[math]::pow(2,15)
        $pDriveReg=@'
Windows Registry Editor Version 5.00

[HKEY_CLASSES_ROOT\CLSID\{e24083fc-bbef-441f-8590-a2c92966f2bf}]
@="pCloud Drive"
"DescriptionID"=dword:00000009
"System.IsPinnedToNameSpaceTree"=dword:00000001
"SortOrderIndex"=dword:00000042

[HKEY_CLASSES_ROOT\CLSID\{e24083fc-bbef-441f-8590-a2c92966f2bf}\DefaultIcon]
@="\"C:\\Program Files\\pCloud Drive\\pcloud.exe\",0"

[HKEY_CLASSES_ROOT\CLSID\{e24083fc-bbef-441f-8590-a2c92966f2bf}\InProcServer32]
@=hex(2):25,00,73,00,79,00,73,00,74,00,65,00,6d,00,72,00,6f,00,6f,00,74,00,25,\
  00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,73,00,68,00,\
  65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,00,00

[HKEY_CLASSES_ROOT\CLSID\{e24083fc-bbef-441f-8590-a2c92966f2bf}\Instance]
"CLSID"="{0E5AAE11-A475-4c5b-AB00-C66DE400274E}"

[HKEY_CLASSES_ROOT\CLSID\{e24083fc-bbef-441f-8590-a2c92966f2bf}\Instance\InitPropertyBag]
"Attributes"=dword:00000011
"TargetFolderPath"="P:\\"

[HKEY_CLASSES_ROOT\CLSID\{e24083fc-bbef-441f-8590-a2c92966f2bf}\ShellFolder]
"FolderValueFlags"=dword:00000028
"Attributes"=dword:f080004d

[HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}]
@="pCloud Drive"
'@
        ImportReg $pDriveReg
    }
}
else {
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{e24083fc-bbef-441f-8590-a2c92966f2bf}" -Force -ErrorAction SilentlyContinue
}
SetValue "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDrives" -Type 4 -Value $HiddenDrives
# ________________
# Modify library namespaces
ModifyMusicLibraryNamespace
# Remove "3D objects" and "Desktop" from Windows Explorer namespace
foreach($UselessNamespace in @("{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}","{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}")) {
    Remove-Item -Path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($UselessNamespace)" -ErrorAction SilentlyContinue
}
# _______________
# Create "Games" folder
[string]$SpielePath="$($env:APPDATA)\Microsoft\Windows\Start Menu\Programs\Spiele"
<#  SortOrderIndex
    0x42 = Der Ordner "Bibliotheken" wird an oberster Position angezeigt
    0x43 = Der Ordner "Bibliotheken" wird unter dem Eintrag "OneDrive" (falls vorhanden) angezeigt .
    0x44 = Der Ordner "Bibliotheken" wird unter dem Eintrag "Heimnetzwerkgruppe" angezeigt .
    0x54 = Der Ordner "Bibliotheken" wird unter Computer / PC angezeigt 
    0x60 = Der Ordner "Bibliotheken" wird an unterster Position (unter Netzwerk) angezeigt.
#>
$GameFolderReg=@'
Windows Registry Editor Version 5.00

[HKEY_CURRENT_USER\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}]
@="Spiele"
"DescriptionID"=dword:00000003
"Infotip"="@SearchFolder.dll,-9031"
"System.IsPinnedToNameSpaceTree"=dword:00000000
"MUIVerb"="@shell32.dll,-30579"
"SortOrderIndex"=dword:00000042

[HKEY_CURRENT_USER\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\DefaultIcon]
@="imageres.dll,-186"

[HKEY_CURRENT_USER\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\InProcServer32]
@=hex(2):25,00,73,00,79,00,73,00,74,00,65,00,6d,00,72,00,6f,00,6f,00,74,00,25,\
  00,5c,00,73,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,73,00,68,00,\
  65,00,6c,00,6c,00,33,00,32,00,2e,00,64,00,6c,00,6c,00,00,00
"ThreadingModel"="Both"

[HKEY_CURRENT_USER\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\Instance]
"CLSID"="{0E5AAE11-A475-4c5b-AB00-C66DE400274E}"

[HKEY_CURRENT_USER\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\Instance\InitPropertyBag]
"Attributes"=dword:00000011
"TargetKnownFolder"=-

[HKEY_CURRENT_USER\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\ShellFolder]
"Attributes"=dword:f080004d
"FolderValueFlags"=dword:00000029
"SortOrderIndex"=dword:00000048
'@
if (Test-Path "$($SpielePath)") {
    ImportReg $GameFolderReg
    SetValue -RegPath "HKCU\Software\Classes\CLSID\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "$($env:Appdata)\Microsoft\Windows\Start Menu\Programs\Spiele"
    foreach($SubKey in @("","WOW6432Node\")) {
        CreateKey "HKLM\SOFTWARE\$($SubKey)Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{a235a4f4-3349-42e1-b81d-a476cd7e33c0}"
    }
}
# Add Recent Items to folders
# SetValue "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}" -Name "System.IsPinnedToNameSpaceTree" -Type 4 -Value 0
# SetValue "HKCR\CLSID\{22877a6d-37a1-461a-91b0-dbda5aaebc99}" -Name "DescriptionID" -Type 4 -Value 3
# CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{22877a6d-37a1-461a-91b0-dbda5aaebc99}"
# Change "Linux" Entry icon and location
if(Test-Path "Registry::HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}") {
    SetValue "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}\Instance\InitPropertyBag" -Name "TargetFolderPath" -Value "\\wsl.localhost\Ubuntu"
    CreateKey "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}\DefaultIcon" -StandardValue "$($WSLLocation)"
    # SetValue "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -Name "System.IsPinnedToNameSpaceTree" -Type 4 -Value 0
    # Remove "Linux" Entry from desktop
    Remove-Item -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}" -ErrorAction SilentlyContinue
}
# ----- Folder Options ------
Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\HideFileExt" -Name "DefaultValue" -Value 0 # Show file extensions
Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\ShowCompColor" -Name "DefaultValue" -Value 1 # Show compressed / encrypted files in blue/green
foreach($HiddenOption in @("NOHIDDEN","SHOWALL")) {
    Set-ItemProperty -Path "Registry::HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Folder\Hidden\$($HiddenOption)" -Name "DefaultValue" -Value 1 # Show hidden files
}
# ------ Remove all later-added desktop icons ------
Remove-Item "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\*" -Force -ErrorAction SilentlyContinue
MakeReadOnly "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace"
# ------ System PATH Environment -----
[string]$SysEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment").Path
[string]$UsrEnv=(Get-ItemProperty -LiteralPath "Registry::HKEY_CURRENT_USER\Environment").Path
[string[]]$PathsToBeAdded=@("$($env:Localappdata)\Programs\Scrcpy")
foreach($PathToBeAdded in $PathsToBeAdded) {
    if($PathToBeAdded -like "$($env:Userprofile)*") {
        if($UsrEnv -Notlike "*$($PathToBeAdded)*") {
            Write-Host "Adding `"$($PathToBeAdded)`" to user PATH"
            $UsrEnv="$($UsrEnv);$($PathToBeAdded)"
            Set-ItemProperty -Path "Registry::HKEY_CURRENT_USER\Environment" -Name "Path" -Value "$($UsrEnv)"
        }
    }
    else {
        if($SysEnv -Notlike "*$($PathToBeAdded)*") {
            Write-Host "Adding `"$($PathToBeAdded)`" to system PATH"
            $SysEnv="$($SysEnv);$($PathToBeAdded)"
            Set-ItemProperty -Path "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" -Name "Path" -Value "$($SysEnv)"
        }
    }
}
# Remove Windows.old folder
[string[]]$VolCaches=(Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\").Name
foreach($TempFileCleanup in $VolCaches) {
    if(($TempFileCleanup -like "*Downloads*") -or ($TempFileCleanup -like "*Recycle Bin")) {
        Remove-ItemProperty -LiteralPath "Registry::$($TempFileCleanup)" -Name "StateFlags0001" -ErrorAction SilentlyContinue
    }
    else {
        SetValue -RegPath "$($TempFileCleanup)" -Name "StateFlags0001" -Type "dword" -Value 2
    }
}
# Enable Windows 11 25300+ preview feature
SetValue -RegPath "HKLM\Software\Microsoft\Windows\CurrentVersion\Shell\Update\Packages\MicrosoftWindows.Client.40729001_cw5n1h2txyewy" -Name "Compatible" -Type "dword" -Value 1
