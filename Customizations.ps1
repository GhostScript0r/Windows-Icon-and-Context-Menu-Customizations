param(
    [switch]$RemoveCommonStartFolder,
    [switch]$UWPRefreshOnly,
    [switch]$Win32GoogleRefreshOnly
)
# Get admin privilege
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
[bool]$ScriptIsRunningOnAdmin=($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
if(!($ScriptIsRunningOnAdmin)) {
	Write-Host "The script $($PSCommandPath.Name) is NOT running with Admin privilege." -ForegroundColor Red -BackgroundColor White
	Start-Process powershell.exe -ArgumentList "-File `"$($PSCommandPath)`"" -verb runas
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
    $balloon.BalloonTipTitle = "Restart require to make changes take effect" 
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
      [switch]$AddHKCR
    )
    if($AddHKCR -and ($RegPath -notlike "*HKCR\*") -and ($RegPath -notlike "*HKEY_CLASSES_ROOT\*")) {
        $RegPath="HKCR\$($RegPath)"
    }
    if(($RegPath.Substring(0,8)) -ne "Registry") {
        $RegPath="Registry::$($RegPath)"
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
    Write-Host "Checking if key $($RegPath) already exists..." -ForegroundColor Yellow
    if($(CheckIfKeyExist $RegPath)) {
        Write-Host "Key `"$($RegPath)`" already exists." -ForegroundColor DarkGreen
    }
    else {
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
        Write-Host "The value $($Name) is already defined in key $($RegPath)" -ForegroundColor Cyan
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
    if($i -eq $InstallLocation.length) {
        [string]$ProgramLocation="$($InstallLocation[$i-1])\$($Program)"
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
                # If command is not defined: just let the original command be, don't bother!
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
        [switch]$InclAdmin
    )
}
function FixUWPCommand {
    [string]$UWPCommand="$($args[0])"
    if($args[1] -eq $true) {
        if($args[0] -like "*Ubuntu*") {
            $UWPCommand="C:\Windows\System32\wsl.exe $($UWPCommand) && sleep 0.2"
        }
        elseif($args[0] -like "*mspaint*") {
            $UWPCommand="cmd.exe /min /c start $($UWPCommand) && exit"
        }
    }
    return $UWPCommand
}
function RefreshGoogleDriveIcons {
    [object[]]$GoogleDriveApps=(Get-ChildItem "C:\Program Files\Google\Drive File Stream\*\GoogleDriveFS.exe" -recurse)
    if($GoogleDriveApps.count -eq 0) {
        Write-Host "Google Drive FS not yet installed." -ForegroundColor Red
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

# ————————————————————————
# Main part of the script
# ————————————————————————
[bool]$UWPFolderModded=((Get-Acl 'C:\Program Files\WindowsApps\').Owner -like "$($env:UserDomain)\$($env:Username)")
[int]$WtErrorMsgCount=((Get-EventLog -InstanceID 1000 -LogName Application -EntryType Error) | Where-Object {$_.Message -like "*WindowsTerminal.exe*ucrtbase.dll*"}).count
if(!($UWPFolderModded) -and ($WtErrorMsgCount -gt 0)) {
    takeown /r /f "C:\Program Files\WindowsApps\"
    $UWPFolderModded=$true
}
if($UWPFolderModded) {
    # UWP Apps folder is modified to allow access. UWP Icons will be possible but MSPaint, Terminal can't run without cmd /c argument
    # > Find file location of paint app
    [string]$PaintAppLocation=$(Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.Paint*" | Where-Object {Test-Path "$($_.FullName)\PaintApp\mspaint.exe"})[0]
    $PaintAppLocation="$($PaintAppLocation)\PaintApp\mspaint.exe"
    # > Find file location of Windows Terminal app
    [string]$WTLocation=$(Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.WindowsTerminal*" | Where-Object {Test-Path "$($_.FullName)\WindowsTerminal.exe"})[0]
    $WTLocation="$($WTLocation)\WindowsTerminal.exe"
    [string]$WSLLocation=$(Get-ChildItem "C:\Program Files\WindowsApps\MicrosoftCorporationII.WindowsSubsystemForLinux*" | Where-Object {Test-Path "$($_.FullName)\wsl.exe"})[0]
    $WSLLocation="$($WSLLocation)\wsl.exe"
    # > Find file location of WMP UWP
    [string]$WMPUWPLocation=$(Get-ChildItem "C:\Program Files\WindowsApps\Microsoft.ZuneMusic*"  | Where-Object {Test-Path "$($_.FullName)\Microsoft.Media.Player.exe" })[0] >$null 2>&1
    $WMPUWPLocation="$($WMPUWPLocation)\Microsoft.Media.Player.exe"
}
else {
    [string]$WSLLocation="wsl.exe"
}
# If called by script "RefreshAppAndRemoveUselessApps": only change the icon for UWP app file associations
if($UWPRefreshOnly) {
    if($UWPFolderModded) {
        CreateFileAssociation "SystemFileAssociations\image" -ShellOperations "edit" -Icon "`"$($PaintAppLocation)`",0"
        CreateFileAssociation @("Directory\Background","Directory") -ShellOperations @("Powershell","PowershellWithAdmin") -Icon @("`"$($WTLocation)`",0","`"$($WTLocation)`",0")
        
    } # else: do nothing further
    exit
}
# Things to do if Google Drive gets an update
if($Win32GoogleRefreshOnly) {
    RefreshGoogleDriveIcons
    exit
}
# Check if MS Office installed
[bool]$MSOfficeInstalled=$false
foreach($ProgramFilesLoc in @("Program Files","Programe Files (x86)")) {
    [string]$MSOfficeLoc="C:\$($ProgramFilesLoc)\Microsoft Office\root"
    if(Test-Path "$($MSOfficeLoc)") {
        $MSOfficeInstalled=$true
        break
    }
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
    "HKCR\InternetShortcut\shell\open",`
    "HKCR\InternetShortcut\shell\open\command",`
    "HKCR\InternetShortcut\shell\print",`
    "HKCR\InternetShortcut\shell\printto",`
    "HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}",`
    "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\empty",`
    "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage",`
    "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}\DefaultIcon",`
    "HKCR\CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}\shell\open",`
    "HKCR\CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}\DefaultIcon",`
    "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}",`
    "HKCR\CLSID\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}\DefaultIcon",`
    "HKCR\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}",`
    "HKCR\CLSID\{679f85cb-0220-4080-b29b-5540cc05aab6}\shell\pintohome"
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
[string[]]$LockedHKLM=@("HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{B2B4A4D1-2754-4140-A2EB-9A76D9D7CDC6}")
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
        -ShellOpDisplayName "Mit Dragon Age Toolset ansehen und bearbeiten"
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
    # New-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name "MUIVerb" -Value "@zipfldr.dll,-10091" -PropertyType "string" -ErrorAction SilentlyContinue
    # if(!($?)) {
    #     Set-ItemProperty -LiteralPath "Registry::HKCR\*\shell\PeaZip" -Name "MUIVerb" -Value "@zipfldr.dll,-10091" -ErrorAction SilentlyContinue
    # }
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
            Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "zipfldr.dll,-101" # Open as archive
        }
        elseif((Get-ItemProperty -LiteralPath "Registry::$($SubCommand)")."Icon" -like "`"C:\Program Files\PeaZip\res\share\icons\peazip_seven.icl`",10") {
            Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "imageres.dll,-175" # Compress
        }
        elseif((Get-ItemProperty -LiteralPath "Registry::$($SubCommand)")."Icon" -like "`"C:\Program Files\PeaZip\res\share\icons\peazip_seven.icl`",4") {
            Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "shell32.dll,-46" # Extract
        }
        elseif((Get-ItemProperty -LiteralPath "Registry::$($SubCommand)")."Icon" -like "`"C:\Program Files\PeaZip\res\share\icons\peazip_seven.icl`",6") {
            Set-ItemProperty -Path "Registry::$($SubCommand)" -Name "Icon" -Value "shell32.dll,-16777" #Erase
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
    -Icon @("main.cpl,-606","imageres.dll,-5322","imageres.dll,-116","","shell32.dll,-51380") `
    -LegacyDisable @(0,0,0,1,0) `
    -MUIVerb @("@shell32.dll,-32960","","","","") `
    -TypeName "@shell32.dll,-9338"
# ---------Hard drives--------
CreateFileAssociation "Drive" `
    -ShellOperations @("manage-bde","encrypt-bde","encrypt-bde-elev") `
    -Icon @("shell32.dll,-194","shell32.dll,-194","shell32.dll,-194")
# Check if VS Code is installed systemwide or for current user only
[string]$VSCodeLocation=(CheckInstallPath "Microsoft VS Code\code.exe")
# --------Directories--------
[string[]]$PowerShellDef=@("Windows-PowerShell Fenster hier öffnen (Admin)","powershell.exe,0") # [0]: Display Name; [1]: Icon file
if($UWPFolderModded) { # Have access to WindowsApps folders and the icons inside
    if($WTLocation -like "*Preview*") {
        $PowerShellDef=@("In Terminal  Vorschau öffnen (Admin)","`"$($WTLocation)`",0")
    }
    else {
        $PowerShellDef=@("In  Terminal öffnen (Admin)","`"$($WTLocation)`",0")
    }
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
    -ShellOpDisplayName @("","Hier VS Code öffnen","Hier VS Code öffnen (Admin)","","","","$($PowerShellDef[0])","") `
    -Icon @("cmd.exe,0","`"$($VSCodeLocation)`",0","`"$($VSCodeLocation)`",0","`"C:\Program Files\Git\git-bash.exe`",0","`"C:\Program Files\Git\git-bash.exe`",0","$($PowerShellDef[1])","$($PowerShellDef[1])","`"$($WSLLocation)`",0") `
    -Extended @(0,0,0,1,1,$UWPFolderModded,0,0) `
    -LegacyDisable @(1,0,0,0,0,$UWPFolderModded,0,0) `
    -HasLUAShield @(0,0,1,0,0,0,1,0) `
    -Command @($(FixUWPCommand "wt.exe -d `"%V `" -p `"Eingabeaufforderung`"" $UWPFolderModded),`
        "`"$($VSCodeLocation)`" `"%v `"",`
        "PowerShell -windowstyle hidden -Command `"Start-Process '$($VSCodeLocation)' -ArgumentList '-d `"`"%V`"`"`"' -Verb RunAs`"",`
        $(FixUWPCommand "wt new-tab --title Git-Bash --tabColor #300a16 --suppressApplicationTitle `"C:\Program Files\Git\bin\bash.exe`"" $UWPFolderModded),`
        "",` # git-gui no need to define
        $(FixUWPCommand "wt.exe  -d `"%V `" -p `"PowerShell`"" $UWPFolderModded),"PowerShell -windowstyle hidden -Command `"Start-Process wt.exe -ArgumentList '-d `"`"%V `"`"`"' -Verb RunAs`"",$(FixUWPCommand "wt.exe -d `"%V `" -p `"Ubuntu`"" $UWPFolderModded))
Remove-Item -Path "Registry::HKCR\Directory\Background\DefaultIcon" -ErrorAction SilentlyContinue # Not needed
# Desktop functionality
CreateFileAssociation "DesktopBackground" -ShellOperations @("Display","Personalize") -Icon @("ddores.dll,-2109","shell32.dll,-270")
# Find Spotlight CLSID
[string]$SpotlightCLSID="HKEY_CLASSES_ROOT\CLSID\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}"
if((Test-Path "Registry::$($SpotlightCLSID)\shell\SpotlightClick")) {
    CreateFileAssociation "$($SpotlightCLSID)" -TypeName "Hintergrund Spotlight" -DefaultIcon "ddores.dll,-2553" -ShellOperations @("spotlightclick","spotlightdislike","spotlightlike","spotlightnext") -Icon @("ieframe.dll,-31074","netshell.dll,-2301","netshell.dll,-2300","shell32.dll,-16805") -MUIVerb @("@msctfuimanager.dll,-16211","","","")
    Remove-Item -Path "Registry::HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace" -Force -Recurse -ErrorAction SilentlyContinue
    CreateFileAssociation "HKCR\DesktopBackground" -ShellOperations "Windows-Blickpunkt" -Icon "ddores.dll,-2553"
    SetValue "HKCR\DesktopBackground\shell\WIndows-Blickpunkt" -Name "Position" -Value "Bottom"
    SetValue "HKCR\DesktopBackground\shell\WIndows-Blickpunkt" -Name "MultiSelectModel" -Value "Player"
    [string]$AllSpotlightCommands=""
    foreach($SpotlightShell in ((Get-ChildItem "Registry::HKCR\CLSID\{2cc5ca98-6485-489a-920e-b3e88a6ccce3}\shell").Name)) {
        [string]$SpotlightShellPur = $SpotlightShell.replace("$($SpotlightCLSID)\shell\","")
        Copy-Item -Path "Registry::$($SpotlightShell)" -Destination "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\" -Force
        # To avoid error on result hierarchy: Not using recurse here
        Copy-Item -Path "Registry::$($SpotlightShell)\command" -Destination "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CommandStore\shell\$($SpotlightShellPur)" -Force
        $AllSpotlightCommands=$AllSpotlightCommands+"$($SpotlightShellPur); "
    }
    SetValue "HKCR\DesktopBackground\shell\Windows-Blickpunkt" -Name "SubCommands" -Value "$($AllSpotlightCommands)"
}
# Show above mentioned entries only on directory background, NOT when clicking a folder
CreateFileAssociation "Directory" -ShellOperations @("cmd","VSCodeNoAdmin","VSCodeWithAdmin","git_shell","git_gui","Powershell","PowershellWithAdmin","WSL") -Extended @(1,1,1,1,1,1,1,1) -LegacyDisable @(1,1,1,1,1,1,1,1)
# -------Image files-------
[string]$GIMPLocation=(CheckInstallPath "GIMP 2\bin\gimp-2.10.exe")
[string]$PaintAppHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_.Name)\Application" -ErrorAction SilentlyContinue).ApplicationName -like "*Microsoft.Paint*"})[0]
[string]$PaintEditIcon="eudcedit.exe,-2"
if($UWPFolderModded) {
    [string]$PaintEditIcon="`"$($PaintAppLocation)`",0"
}
CreateFileAssociation "SystemFileAssociations\image" -ShellOperations @("edit","edit2","print") `
    -Icon @("$($PaintEditIcon)","`"$($GIMPLocation)`",0","ddores.dll,-2413") `
     -Command @($(FixUWPCommand "mspaint.exe `"%1`"" $UWPFolderModded),"`"$($GIMPLocation)`" `"%1`"","") `
     -ShellOpDisplayName @("","Mit GIMP öffnen","") -MUIVerb @("@mshtml.dll,-2210","","")
Copy-Item -Path "Registry::$($PaintAppHKCR)\Shell\Edit" -Destination "Registry::HKCR\SystemFileAssociations\image\shell" -Force
Copy-Item -Path "Registry::$($PaintAppHKCR)\Shell\Edit\Command" -Destination "Registry::HKCR\SystemFileAssociations\image\shell\Edit" -Force
[string[]]$ImageFileExts=@("bmp","jpg","jpeg","png","016","256","ico","cur","ani","dds","tif","tiff")
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
CreateFileAssociation "PhotoViewer.FileAssoc.Tiff" -ShellOperations "open" -Icon "`"C:\Program Files\Windows Photo Viewer\PhotoViewer.dll`",0" -DefaultIcon "`"C:\Program Files\Windows Photo Viewer\PhotoAcq.dll`",-7"
$SysFileAssoExt=(Get-ChildItem "Registry::HKEY_CLASSES_ROOT\SystemFileAssociations\.*")
foreach($AssoExt in $SysFileAssoExt) {
    if(Test-Path "Registry::$($AssoExt.name)\shell\setdesktopwallpaper") {
        if((Get-ItemProperty -LiteralPath "Registry::$($AssoExt.name)\shell\setdesktopwallpaper" -ErrorAction SilentlyContinue)."Icon" -notlike "imageres.dll,-110") {
            break # Already written. No need to get again
        }
        CreateFileAssociation "$($AssoExt.name)" -ShellOperations "setdesktopwallpaper" -Icon "imageres.dll,-110"
    }
}
# -------Audio and video files-------
# Check which media player is installed
[string[]]$MPlayers=@("VLC","WMP Legacy","WMP UWP")
[bool[]]$MPlayersInstalled=@((Test-Path "C:\Program Files\VideoLAN"),`
$WMPLegacyInstalled,` # Mentioned above to check if needed to take ownership of WMP11* keys
((Get-AppxPackage "*ZuneMusic*").Name -like "*ZuneMusic*"))
if($MPlayersInstalled[0]) { # VLC installed
    Write-Host "$($MPlayers[0]) installed"
    CreateFileAssociation "Directory" -ShellOperations @("PlayWithVLC","AddtoPlaylistVLC") -LegacyDisable @(1,1)
    [string[]]$VLCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "VLC.*.Document"})
    [string]$VLCFileName=""
    foreach($VLCKey in $VLCHKCR) {
        if((Get-ItemProperty -LiteralPath "Registry::HKCR\$($VLCKey)\shell\open" -ErrorAction SilentlyContinue)."Icon" -like "imageres.dll,-5201") {
            break # Registry already written. No need to continue
        }
        [string]$VLCExtension=($VLCKey -replace 'VLC','' -Replace '.Document','')
        [string]$VLCFileType=(Get-ItemProperty -LiteralPath "Registry::HKCR\$($VLCExtension)" -ErrorAction SilentlyContinue).'PerceivedType'
        if($VLCFileType -like "audio") {
            [string]$VLCFileIcon="imageres.dll,-1026"
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
        elseif(@(".cda",".CDAudio") -contains $VLCFileType) {
            [string]$VLCFileIcon="imageres.dll,-180"
        }
        else {
            [string]$VLCFileIcon="imageres.dll,-134"
        }
        SetValue "HKCR\$($VLCExtension)\OpenWithProgids" -Name "$($VLCKey)" -EmptyValue $true
        CreateFileAssociation "$($VLCKey)" -DefaultIcon "$($VLCFileIcon)" -ShellOperations "open" -Icon "imageres.dll,-5201" -MUIVerb "@shell32.dll,-22072" -TypeName "$($VLCFileName)"
        if(Test-Path "Registry::HKCR\$($VLCKey)\shell\enqueue") {
            CreateFileAssociation "$($VLCKey)" -ShellOperations "enqueue" -MUIVerb "@shell32.dll,-37427" -Icon "wlidcli.dll,-1008"
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
    -Icon @("imageres.dll,-5306","imageres.dll,-5306") `
    -Command @("`"$($VSCodeLocation)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"") `
    -MUIVerb @("@mshtml.dll,-2210","")
if(Test-Path "Registry::HKCR\txtfile\shell\print\command") {
    CreateFileAssociation @("txtfile","textfile") -ShellOperations @("print","printto") `
        -Icon @("ddores.dll,-2413","ddores.dll,-2414") `
        -Extended @(1,1) -LegacyDisable @(1,1)
}

# --------VBE, VBS and JSE (JavaScript) Script--------
CreateFileAssociation @("VSCode.vb","VBSFile","VBEFile","JSEFile") `
    -ShellOperations @("open","open2","print","edit") `
    -Icon @("wscript.exe,-1","cmd.exe,0","DDOres.dll,-2414","imageres.dll,-5306") `
    -MUIVerb @("@shell32.dll,-12710","@wshext.dll,-4511","","") `
    -Command @("WScript.exe `"%1`" %*","CScript.exe `"%1`" %*","","`"$($VSCodeLocation)`" `"%1`"") `
    -FileAssoList @("vb","vbs","vbe","jse") `
    -Extended @(0,0,1,0) -LegacyDisable @(0,0,1,0)
# --------BAT, CMD, COM script-------
CreateFileAssociation @("BATFile","CMDFile","COMFile") `
    -DefaultIcon "cmd.exe,0" `
    -ShellOperations @("open","print","edit","runas") `
    -Icon @("cmd.exe,0","DDOres.dll,-2414","imageres.dll,-5306","cmd.exe,0") `
    -MUIVerb @("@shell32.dll,-12710","","","") `
    -Command @("","","`"$($VSCodeLocation)`" `"%1`"","") `
    -Extended @(0,1,0,0) -LegacyDisable @(0,1,0,0)
# --------Registry file--------
CreateFileAssociation "regfile" -ShellOperations @("open","edit","print") `
    -Icon @("regedit.exe,0","imageres.dll,-5306","DDORes.dll,-2413") `
    -Extended @(0,0,1) -ShellDefault "open"`
    -command @("","`"$($VSCodeLocation)`" `"%1`"","")
# ------- Python script -------
[string[]]$PythonVerInstalled=(Get-AppxPackage "*.Python.*").Name
if(($PythonVerInstalled.Count -gt 0) -and ($UWPFolderModded)) {
    [string]$PythonInstalledLoc=$(Get-ChildItem "C:\Program Files\WindowsApps\$($PythonVerInstalled[$PythonVerInstalled.count-1])*" | Where-Object {Test-Path "$($_.FullName)\python.exe"})[0]
    $PythonInstallLoc=$PythonInstalledLoc+"\python.exe"
    [string]$PythonFileHKCR=(Get-ChildItem "Registry::HKCR\AppX*" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)" -ErrorAction SilentlyContinue).'(default)' -like "Python File"})[0] # Includes HKCR\ prefix
    CreateFileAssociation "$($PythonFileHKCR)" -shelloperations @("open","edit") -Icon @("$($PythonInstallLoc)","imageres.dll,-5306") -Command ("","`"$($VSCodeLocation)`" `"%1`"") -MUIVerb @("@shell32.dll,-12710","")
    Remove-Item -Path "Registry::HKCR\VSCode.py\shell\open" -Force -Recurse
    Copy-Item -Path "Registry::$($PythonFileHKCR)\shell\open" -Destination "Registry::HKCR\VSCode.py\shell" -Force
    Copy-Item -Path "Registry::$($PythonFileHKCR)\shell\open\command" -Destination "Registry::HKCR\VSCode.py\shell\open" -Force
    Copy-Item -Path "Registry::$($PythonFileHKCR)\shell\edit" -Destination "Registry::HKCR\VSCode.py\shell" -Force
    Copy-Item -Path "Registry::$($PythonFileHKCR)\shell\edit\command" -Destination "Registry::HKCR\VSCode.py\shell\edit" -Force
}
# -------XML Document-------
Remove-ItemProperty -Path "Registry::HKCR\.xml" -Name "PreceivedType" -ErrorAction SilentlyContinue
foreach($ML_Ext in @("xml","htm","html")) {    
    Remove-ItemProperty -Path "Registry::HKCR\.$($ML_Ext)\OpenWithProgids" -Name "MSEdgeHTM" -ErrorAction SilentlyContinue 
}
CreateFileAssociation @("xmlfile","VSCode.xml") -FileAssoList ".xml" -DefaultIcon "msxml3.dll,-128" `
    -ShellOperations @("open","edit") -ShellDefault "edit" `
    -Icon @("ieframe.dll,-31065","imageres.dll,-5306") -MUIVerb @("@ieframe.dll,-21819","")`
    -Command @("`"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`" --single-argument %1","`"$($VSCodeLocation)`" `"%1`"") `
    -CommandId @("IE.File","") `
    -DelegateExecute @("{17FE9752-0B5A-4665-84CD-569794602F5C}","")
Remove-Item "Registry::HKCR\xmlfile\ShellEx\IconHandler" -ErrorAction SilentlyContinue
# ------- PS1 Script ------
CreateFileAssociation @("Microsoft.PowerShellScript.1","VSCode.ps1") -ShellOperations @("open","edit","runas") -Icon @("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,0","imageres.dll,-5306","C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe,1") -MUIVerb @("@`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`",-108","","") -Command @("`"C:\Windows\system32\windowspowershell\v1.0\powershell.exe`"  `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`"","`"$($VSCodeLocation)`" `"%1`"","`"C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`" `"-Command`" `"if((Get-ExecutionPolicy) -ne 'AllSigned') { Set-ExecutionPolicy -Scope Process Bypass }; & '%1'`" -Verb RunAs")
Remove-Item "Registry::HKCR\Microsoft.PowerShellScript.1\shell\0" -ErrorAction SilentlyContinue
# ------- LOG File ------
SetValue "HKCR\.log" -Name "Content Type" -Value "text/plain"
SetValue "HKCR\.log" -Name "PerceivedType" -Value "text"
# ------- All the rest VSCode files ------
[string[]]$VSCHKCR=([Microsoft.Win32.Registry]::ClassesRoot.GetSubKeyNames() | Where-Object {$_ -like "VSCode*"})
foreach($Key in $VSCHKCR) {
    if((Get-ItemProperty "Registry::HKCR\$($Key)\shell\open" -ErrorAction SilentlyContinue)."Icon" -like "imageres.dll,-5306") {
        break # Registry already written. No need to do it again
    }
    if((Get-ItemProperty "Registry::HKCR\$($Key)\shell\open\command" -ErrorAction SilentlyContinue).'(default)' -like "*$($VSCodeLocation)*") {
        CreateFileAssociation "$($Key)" -ShellOperations "open" -Icon "imageres.dll,-5306" -MUIVerb "@shell32.dll,-37398" -Extended 0
    }
    else {
        # Do nothing. Those are probably defined somewhere else.
    }
}
# Give "Text" property to all VS Code related files
foreach($FileExt in (Get-ChildItem "Registry::HKCR\.*").Name) {
    [string]$ProgID=(Get-ItemProperty -LiteralPath "Registry::$($FileExt)\OpenWithProgIds" -ErrorAction SilentlyContinue) 
    if(($ProgID -like "*VSCode.*") -and (-not (Test-Path "Registry::$($FileExt)\PersistentHandler"))) {
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
        if((Get-ItemProperty -LiteralPath "Registry::HKCR\$($Key)\shell\open")."MUIVerb" -like "@appmgr.dll,-652") {
            break # Registry already written. No need to continue
        }
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
CreateFileAssociation @("htmlfile","VSCode.htm","VSCode.html","MSEdgeHTM","Applications\MSEdge.exe") -DefaultIcon "ieframe.dll,-211" -ShellOperations @("open","edit","print","printto") -Icon @("$($BrowserIcon)","imageres.dll,-5306","DDORes.dll,-2414","DDORes.dll,-2413") -Command @("$($BrowserOpenAction)","`"$($VSCodeLocation)`" `"%1`"","","") -MUIVerb @("$($OpenHTMLVerb)","","","") -LegacyDisable @(0,0,1,1)
# ------- URL Internet Shortcut -------
foreach($PropertyToBeRemoved in @("NeverShowExt")) { #,"IsShortcut"
    Remove-ItemProperty -Path "Registry::HKCR\InternetShortcut" -Name $PropertyToBeRemoved -ErrorAction SilentlyContinue
}
Remove-Item -Path "Registry::HKCR\InternetShortcut\ShellEx\ContextMenuHandlers\{FBF23B40-E3F0-101B-8488-00AA003E56F8}" -Force
CreateFileAssociation "InternetShortcut" -DefaultIcon "url.dll,-5" -ShellOperations @("open","print","printto") -Icon @("$($BrowserIcon)","ddores.dll,-2414","ddores.dll,-2413") -MUIVerb @("@synccenter.dll,-6102","","") -LegacyDisable @(0,1,1) -Command @("powershell.exe -Command `"`$URL= ((Get-Content '%1') -like 'URL=*') -replace 'URL=',' '; Start-Process 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' -ArgumentList `$URL`"","","")
# --------Google Chrome HTML (if Chrome installed)--------
if($ChromeInstalled) {
    CreateFileAssociation "ChromeHTML" -DefaultIcon "shell32.dll,-14" `
    -ShellOperations @("open","edit") -MUIVerb @("@ieframe.dll,-10064","") `
    -Icon @("`"$($ChromePath)`",0","imageres.dll,-5306") `
    -Command @("`"$($ChromePath)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"")
}
# -------- Google Docs ---------
RefreshGoogleDriveIcons
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
}
# PFX Certificate
CreateFileAssociation "pfxfile" -ShellOperations @("add","open") -Extended @(0,0) `
    -Icon @("certmgr.dll,-6169","certmgr.dll,-6169") -MUIVerb @("@cryptext.dll,-6126","") -ShellDefault "add"
# INI /INF Config file
CreateFileAssociation @("inifile","inffile") `
    -FileAssoList "forger2" `
    -ShellOperations @("open","print") `
    -Command @("`"$($VSCodeLocation)`" `"%1`"","") `
    -MUIVerb @("@mshtml.dll,-2210","") `
    -Icon @("imageres.dll,-5306","DDORes.dll,-2413") `
    -Extended @(0,1) -LegacyDisable @(0,1) `
    -DefaultIcon "imageres.dll,-69"
# INF File Install
CreateFileAssociation "SystemFileAssociations\.inf" -ShellOperations "install" -Icon "msihnd.dll,-10"
# SRT Subtitles
[string]$SEditLoc="E:\Programme\SubtitleEdit\SubtitleEdit.exe"
if(Test-Path "$($SEditLoc)") {
    [string[]]$SubtitleTypes=("$($SEditLoc.replace("SubtitleEdit.exe","Icons\"))").BaseName
    foreach($SubtitleType in $SubtitleTypes) {
        if($SubtitleType -like "uninstall") {
            continue
        }
    CreateFileAssociation "SubtitleEdit.$($SubtitleType)" `
        -DefaultIcon "`"$($SEditLoc -replace "SubtitleEdit.exe","icons\$($SubtitleType).ico")`"" `
        -ShellOperations @("open","edit") `
        -Icon @("`"$($SEditLoc)`",0","imageres.dll,-5306") `
        -Command @("`"$($SEditLoc)`" `"%1`"","`"$($VSCodeLocation)`" `"%1`"") `
    }
}
# CRDownload and !qB partially downloaded files
CreateFileAssociation "Downloading" -FileAssoList @("crdownload","!qB") -DefaultIcon "shell32.dll,-231"
# _____________________________
# ____Explorer Namespaces_____
# Change trash bin empty icon
SetValue -RegPath "HKCR\CLSID\{645FF040-5081-101B-9F08-00AA002F954E}\shell\empty" -Name "Icon" -Value "imageres.dll,-5305"
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{645FF040-5081-101B-9F08-00AA002F954E}"
# Change "Manage" icon
SetValue -RegPath "HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "Icon" -Value "mycomput.dll,-204"
Remove-ItemProperty -Path "Registry::HKCR\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\shell\Manage" -Name "HasLUAShield" -ErrorAction SilentlyContinue
# Change control panel icons
CreateFileAssociation @("CLSID\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}","CLSID\{26EE0668-A00A-44D7-9371-BEB064C98683}") -DefaultIcon "Control.exe,0" -Icon "Control.exe,0" -ShellOperations "open" -MUIVerb "@shell32.dll,-10018" -command "control.exe"
CreateKey "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}"
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
foreach($LibraryFolder in (Get-ChildItem "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\").Name) {
    Remove-ItemProperty -Path "Registry::$($LibraryFolder)" -Name "HideIfEnabled" -ErrorAction SilentlyContinue
    if(((Get-ItemProperty -LiteralPath "Registry::$($LibraryFolder)").'(default)') -like "CLSID_*RegFolder") {
        Remove-Item "Registry::$($LibraryFolder)"
        CreateKey "$($LibraryFolder)"
    }
}
# Change desktop icon
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{20D04FE0-3AEA-1069-A2D8-08002B30309D}\DefaultIcon" -StandardValue "DDORes.dll,-2068" # My PC
CreateKey "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\CLSID\{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}\DefaultIcon" -StandardValue "ncpa.cpl,-1001" # Network places
foreach($SearchCLSID in @("HKCR\CLSID","HKCR\WOW6432Node\CLSID")) {
    # Change OneDrive (private) and OneDrive (business) icon and name
    [string]$OneDriveInstallLoc=(CheckInstallPath "Microsoft\OneDrive\OneDrive.exe")
    [object[]]$OneDriveCLSIDs=((Get-ChildItem "Registry::$($SearchCLSID)" | Where-Object {(Get-ItemProperty -LiteralPath "Registry::$($_)").'(default)' -like "Onedrive -*"} ))
    foreach($OneDriveCLSID in $OneDriveCLSIDs) {
        [string]$OneDriveCLSIDPur=$OneDriveCLSID.Name.Substring($OneDriveCLSID.Name.LastIndexOf('\')+1,$OneDriveCLSID.Name.length-$OneDriveCLSID.Name.LastIndexOf('\')-1)
        [string]$OneDriveName=((Get-ItemProperty -LiteralPath "Registry::$($OneDriveCLSID)").'(default)')
        if(($OneDriveName -like "*Personal") -or ($OneDriveName -like "*Privat")) {
            CreateKey "$($OneDriveCLSID.Name)" -StandardValue "OneDrive - Privat"
            CreateFileAssociation "$($OneDriveCLSID.Name)" -DefaultIcon "`"$($OneDriveInstallLoc)`",-588"
        }
        elseif(($OneDriveName -like "*Arbeit") -or ($OneDriveName -like "*YOURCOMPANYNAME*")) {
            CreateKey "$($OneDriveCLSID.Name)" -StandardValue "OneDrive - Arbeit"
            CreateFileAssociation "$($OneDriveCLSID.Name)" -DefaultIcon "`"$($OneDriveInstallLoc)`",-589"
        }
        SetValue "$($OneDriveCLSID.Name)" -Name "System.IsPinnedToNameSpaceTree" -Type "4" -Value 1
        Remove-ItemProperty -Path "Registry::$($OneDriveCLSID.Name)" -Name "DescriptionID"
        SetValue "$($OneDriveCLSID.Name)" -Name "DescriptionID" -Type "4" -Value 9 # 4=DWORD
        CreateKey "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\$($OneDriveCLSIDPur)"
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
            MakeReadOnly "$($BoxDriveCLSID.Name)" -InclAdmin
        }
    }
}
