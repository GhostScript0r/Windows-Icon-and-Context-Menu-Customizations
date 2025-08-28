function RunAsAdmin {
    [OutputType([bool])]
    param(
        [parameter(Mandatory = $true)]
        [string]$PSScriptPath,
        [Hashtable]$Arguments = @{}
    )

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        Write-Host "Script $($(Split-Path -Leaf $PSScriptPath)) is NOT running with admin privileges." -ForegroundColor Red

        # Build argument string
        $argstring = @('-File', $PSScriptPath)
    
        foreach ($param in $Arguments.GetEnumerator()) {
            $argstring += "-$($param.Key)"
            if ($param.Value -isnot [System.Management.Automation.SwitchParameter] -and $param.Value -isnot [bool]) {
                $argstring += $param.Value
            }
        }

        # Check Developer Mode
        [bool]$devModeEnabled = $false
        $reg = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" `
            -Name "AllowDevelopmentWithoutDevLicense" -ErrorAction SilentlyContinue
        if ($($reg.AllowDevelopmentWithoutDevLicense) -eq 1) {
            $devModeEnabled = $true
        }

        if ((Get-Command sudo.exe -ErrorAction SilentlyContinue) -and $devModeEnabled) {
            Write-Host "Running elevated via sudo.exe..." -ForegroundColor Cyan
            . sudo.exe powershell.exe @argString
        } else {
            Write-Host "sudo.exe not available or Developer Mode disabled. Falling back to Start-Process..." -ForegroundColor Yellow
            Write-Host "Command: powershell.exe $($argString)" -ForegroundColor DarkGray
            Start-Process -FilePath "powershell.exe" -ArgumentList "$($argString)" -Verb RunAs
        }

        exit
    } else {
        Write-Host "Script $($(Split-Path -Leaf $PSScriptPath)) is running with admin privileges." -ForegroundColor Green
        return $null
    }
}
