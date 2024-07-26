function WebsiteInContextMenu {
    param(
        [parameter(ParameterSetName='CLSID', Mandatory=$true, Position=0)]
        [string]$CLSID,
        # [parameter(ParameterSetName='SiteNames', Mandatory=$true)]
        [string[]]$SiteNames
    )
    . "$($PSScriptRoot)\GetIcons.ps1"
    . "$($PSScriptRoot)\HashTables.ps1"
    . "$($PSScriptRoot)\RegistryTweaks-FileAssoc.ps1"
    . "$($PSScriptRoot)\CheckDefaultBrowser.ps1"
    [string[]]$SiteLinks=@("")*$SiteNames.count
    [string[]]$SiteIcons=@("")*$SiteNames.count
    [string[]]$SiteCtxtMenuEntries=@("")*$SiteNames.count
    [string[]]$SiteCommands=@("")*$SiteNames.count
    [hashtable]$Sites=(GetHashTables "ContextMenuLinks")
    GetDistroIcon -IconForLnk
    for($ii=0;$ii -lt $SiteNames.count;$ii++) { # Use ii instead of i because there's already an i used in the uppler level loop
        $SiteLinks[$ii]=$Sites."$($SiteNames[$ii])"
        if($SiteLinks[$ii].length -eq 0) {
            Write-Host "No weblink for $($SiteNames[$ii])"
            continue
        }
        $SiteCommands[$ii]="$($DefaultBrowser[1].replace('`"%1`"',$SiteLinks[$ii]))"
        $SiteIcons[$ii]="$($env:USERPROFILE)\Links\$($SiteNames[$ii]).ico"
        if(!(Test-Path "$($SiteIcons[$ii])")) {
            if($SiteNames[$ii] -like "Adobe *") {
                $SiteIcons[$ii]="$($env:USERPROFILE)\Links\Adobe Acrobat.ico"
            }
            elseif($SiteNames[$ii] -like "*OneDrive*") {
                $SiteIcons[$ii]="imageres.dll,-1043"
            }
            elseif($SiteNames[$ii] -like "YouTube *") {
                $SiteIcons[$ii]="$($env:USERPROFILE)\Links\YouTube.ico"
            }
            else {
                $SiteIcons[$ii]="$($(CheckDefaultBrowser)[2])"
            }
        }
        $SiteCtxtMenuEntries[$ii]="$($SiteNames[$ii].replace('_',' '))"
    }
    CreateFileAssociation "CLSID\$($CLSID)" -ShellOperations $SiteNames -Command $SiteCommands -Icon $SiteIcons -ShellOpDisplayName $SiteCtxtMenuEntries
}