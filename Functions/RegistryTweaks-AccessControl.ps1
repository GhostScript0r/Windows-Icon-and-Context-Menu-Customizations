. "$($PSScriptRoot)\RegistryTweaks-BasicOps.ps1"
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
    switch -regex ($LockedKeyRoot) {
        'Registry::HKCU|Registry::HKEY_CURRENT_USER'    { $RegRoot = 'CurrentUser' }
        'Registry::HKLM|Registry::HKEY_LOCAL_MACHINE'   { $RegRoot = 'LocalMachine' }
        'Registry::HKCR|Registry::HKEY_CLASSES_ROOT'    { $RegRoot = 'ClassesRoot' }
        'Registry::HKCC|Registry::HKEY_CURRENT_CONFIG'  { $RegRoot = 'CurrentConfig' }
        'Registry::HKU|Registry::HKEY_USERS'            { $RegRoot = 'Users' }
    }
        $R=[Microsoft.Win32.Registry]::$RegRoot.OpenSubKey($LockedKeyBody,'ReadWriteSubTree', 'TakeOwnership')
    $acl = $acl = New-Object System.Security.AccessControl.RegistrySecurity
    $acl.SetOwner($MyAccount)
    $R.SetAccessControl($acl)
    $acl.SetAccessRuleProtection($false, $false)
    $R.SetAccessControl($acl)
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule ($MyAccount,'FullControl', 'ContainerInherit', 'None', 'Allow')
    $acl.ResetAccessRule($rule)
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
        try {
            $CurrentStatus=($ACL.Access | Where-Object {$_.IdentityReference -like "$($User)"})[0]
        }
        catch {
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