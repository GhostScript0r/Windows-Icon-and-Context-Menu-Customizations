# Function to create ballon notification
function BallonNotif {
    param(
        [parameter(ParameterSetName='Info', Mandatory=$true, Position=0)]
        [string]$Info,
        [string]$Title,
        [switch]$OnHold,
        [string]$NotifType=""
    )
    Add-Type -AssemblyName System.Windows.Forms 
    $balloon = New-Object System.Windows.Forms.NotifyIcon
    $path = (Get-Process -id $pid).Path
    $balloon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
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