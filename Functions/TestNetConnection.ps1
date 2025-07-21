function TestNetConnection {
    <#
    .SYNOPSIS
    Tests IPv4 cloud connectivity using a two-tier approach: ICMP (ping) first,
    then Invoke-WebRequest simulating a default browser.

    .DESCRIPTION
    This function first attempts to ping the TargetSite (IPv4 only). If ping is successful,
    it assumes connectivity. If ping fails (due to blocking or actual unreachability),
    it then attempts an HTTPS connection using Invoke-WebRequest, which simulates
    a typical browser request (including using a system-default browser User-Agent).
    This is ideal for environments where ICMP is blocked but web traffic is allowed,
    potentially through proxies or specific firewall rules.
    By default, it tests connectivity to drive.google.com.

    .PARAMETER TargetSite
    The hostname of the site to test for IPv4 connectivity (e.g., "reddit.com", "bing.com").
    Defaults to "drive.google.com". This parameter can be passed by position.

    .OUTPUTS
    [boolean]
        Returns $true if either the ping or the simulated browser connection to the
        TargetSite is successful, otherwise returns $false.

    .EXAMPLE
    TestCloudConnection
    # Tests IPv4 connectivity to drive.google.com using ping, then Invoke-WebRequest if needed.

    .EXAMPLE
    TestCloudConnection "box.com"
    # Tests IPv4 connectivity to box.com using ping, then Invoke-WebRequest if needed.

    .EXAMPLE
    if (TestCloudConnection "example.com" -Verbose) {
        Write-Host "Connectivity to example.com is confirmed."
    }
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [string]$TargetSite = "drive.google.com" # Default value
    )
    $connectionSuccessful = $false # Initialize return value

    Write-Verbose "Starting connectivity test for $($TargetSite)..."

    ## Level 1: ICMP (Ping) Test ##
    Write-Verbose "Attempting IPv4 Ping test to $($TargetSite)..."
    try {
        # Resolve DNS for IPv4 first to ensure we ping an IPv4 address
        $ipv4Addresses = (Resolve-DnsName -Name $($TargetSite) -Type A -ErrorAction Stop).IPAddress |
                         Where-Object { $_ -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" }

        if ($ipv4Addresses.Count -eq 0) {
            Write-Warning "No IPv4 addresses found for $($TargetSite). Skipping ping test."
        } else {
            # Try to ping the first resolved IPv4 address
            $firstIpv4 = $ipv4Addresses[0]
            Write-Verbose "Pinging $($firstIpv4)..."
            $pingResult = Test-Connection -ComputerName $($firstIpv4) -Count 1 -ErrorAction SilentlyContinue -WarningAction SilentlyContinue

            if ($pingResult.StatusCode -eq 0 -or $pingResult.IPV4Address) { # StatusCode 0 means success
                Write-Verbose "SUCCESS: IPv4 Ping to $($firstIpv4) was successful. Connection assumed active."
                $connectionSuccessful = $true
            } else {
                Write-Verbose "INFO: IPv4 Ping to $($firstIpv4) failed or was blocked. Proceeding to Invoke-WebRequest test."
            }
        }
    } catch {
        Write-Verbose "INFO: An error occurred during ping DNS resolution or ping attempt: $($_.Exception.Message). Proceeding to Invoke-WebRequest test."
    }

    ## Level 2: Invoke-WebRequest (Browser Simulation) Test (only if ping failed) ##
    if (-not $connectionSuccessful) {
        Write-Verbose "Attempting Invoke-WebRequest test to $($TargetSite) (simulating browser)..."
        $targetUrl = "https://$($TargetSite)"

        try {
            $response = Invoke-WebRequest -Uri $($targetUrl) -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 400) {
                Write-Verbose "SUCCESS: Simulated browser connection to $($TargetSite) (HTTP Status: $($response.StatusCode)). Connection confirmed."
                $connectionSuccessful = $true
            } else {
                Write-Warning "FAILED: Simulated browser connection to $($TargetSite) (HTTP Status: $($response.StatusCode))."
            }
        } catch {
            Write-Error "An error occurred during web request to $($TargetSite): $($_.Exception.Message)"
            $connectionSuccessful = $false
        }
    }

    if ($connectionSuccessful) {
        Write-Verbose "Connectivity test for $($TargetSite) completed successfully."
    } else {
        Write-Warning "Connectivity test for $($TargetSite) failed completely."
    }

    return $connectionSuccessful
}