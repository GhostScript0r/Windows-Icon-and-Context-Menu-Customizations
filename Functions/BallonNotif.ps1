# Function to create ballon notification
function BallonNotif {
    param(
        [parameter(ParameterSetName='Info', Mandatory=$true, Position=0)]
        [string]$Info,
        [string]$Title,
        [switch]$OnHold,
        [string]$Icon="",
        [string]$NotifType=""
    )
    Add-Type -AssemblyName System.Windows.Forms 
    $balloon = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path
    if($Icon.length -eq 0) {
        $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
    }
    else {
        # if($Icon -match ",?\d+$") {
        #     # Icon is from a dll or exe, with index. The index must be a positive value. Negative values cannot be used.
        #     [int]$IconCommaIndex=$Icon.LastIndexOf(',') # Breaks up the balloon index
        #     [string]$IconPath=$Icon.Substring(0,$IconCommaIndex)
        #     [int]$IconIndex=$Icon.Substring($IconCommaIndex+1)
        #     $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($IconPath,$IconIndex)
        # }
        if(Test-Path "$($Icon)") {
            $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($Icon)
        }
    }
    switch($NotifType) {
        "Warning" {
            $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Warning 
        }
        "Error" {
            $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Error
        }
        "Info" {
            $balloon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        }
    }
    $balloon.BalloonTipText = $Info
    $balloon.BalloonTipTitle = $Title 
    $balloon.Visible = $true 
    $balloon.ShowBalloonTip(5000)
    if($OnHold) {
        $Report=(Read-Host $Info) # Wait for input before continuing. Python equvilant: input("...")
    }
    else {
        $Report=""
    }
    return $Report
}