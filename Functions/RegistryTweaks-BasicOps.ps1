# Function to import the reg file as whole string
function ImportReg {
    param(
        [parameter(ParameterSetName='RegContent', Mandatory=$true, Position=0)]
        [string]$RegContent
    )
    $RegContent | Out-File "$($env:TEMP)\1.reg"
    reg.exe import "$($env:TEMP)\1.reg"
    Remove-Item "$($env:TEMP)\1.reg"
}
# Function to convert path to add HKCR and Registry:: prefix
function CorrectPath {
    [OutputType([string])]
    Param (
      [parameter(ParameterSetName='RegPath', Mandatory=$true, Position=0)]
      [String]$RegPath,
      [switch]$AddHKCR,
      [switch]$Convert
    )
    if($Convert) { # Convert from HKCR to HKCU\Software\Classes or HKLM\Software\Classes
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
        if($AddHKCR -and ($RegPath -notlike "*HKCR\*") -and ($RegPath -notlike "*HKEY_CLASSES_ROOT\*") -and ($RegPath -notlike "*HKLM\*") -and ($RegPath -notlike "*HKEY_LOCAL_MACHINE\*") -and ($RegPath -notlike "*HKCU\*") -and ($RegPath -notlike "*HKEY_CURRENT_USER\*")) {
            $RegPath="HKCR\$($RegPath)"
        }
        if(($RegPath.Substring(0,8)) -ne "Registry") {
            $RegPath="Registry::$($RegPath)"
        }
    }
    return $RegPath
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
function Remove-DefaultRegValue { # Remove the 
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