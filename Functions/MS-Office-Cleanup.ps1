function MSOfficeCleanup {
    [OutputType([bool])]
    param(
        [switch]$CheckOfficeInstalledOnly
    )
    # Remove unwanted MS Office components
    # For the following scripts to work Office Deployment Tool need to be downloaded https://www.microsoft.com/en-us/download/details.aspx?id=49117 and put to location %localappdata%\Programs\Office Deployment Tool
    # Check if MS Office is installed
    [bool]$MSOfficeInstalled=$false
    foreach($ProgramFilesLoc in @("Program Files","Programe Files (x86)")) {
        [string]$MSOfficeLoc="C:\$($ProgramFilesLoc)\Microsoft Office\root\Office16" # As OneNote can be installed separately without license, it's better to test if Office (license needed) is installed via word.exe
        if(Test-Path "$($MSOfficeLoc)\WINWORD.exe") {
            Write-Host "MS Office installed in `"$($MSOfficeLoc)`""
            $MSOfficeInstalled=$true
            break
        }
    }
    if($CheckOfficeInstalledOnly) {
        return $MSOfficeInstalled
    }
    if($MSOfficeInstalled) {
        # [string]$CurrentOfficeVer=(Get-WmiObject win32_product | Where-Object {$_.Name -like "Office 16 Click-to-Run Licensing Component"}).Version
        # [string]$LastCheckedVer=(Get-Content "$($env:LOCALAPPDATA)\Programs\Office Deployment Tool\CurrentOfficeVer.json" -ErrorAction SilentlyContinue | ConvertFrom-Json)
        # if($CurrentOfficeVer -like $LastCheckedVer) {
        #     Write-Host "Office was not updated since last time the program was running"
        # }
        # else
        if((Test-Path "$($MSOfficeLoc)\MSACCESS.EXE") ) { 
            # Access is one of the things I definitely dont't need. If they are present, it means a cleanup is needed.
            Write-Host "Running cleanup..."
            $MSCleanupConfig=@'
            <Configuration>
                <Remove> 
                    
                    <Product ID="Access" />
                    <!--
                    <Product ID="SkypeforBusinessRetail"/>
                    <Product ID="Publisher" />
                    <Product ID="OneDrive" />
                    <Product ID="Groove" />
                    <Product ID="Lynk" />
                    <Product ID="OneNote" />
                    -->
                </Remove>
                <!--
                <Add OfficeClientEdition="64" Channel="Current">
                <Product ID="O365ProPlusRetail">
                    <Language ID="de-de" />
                    <ExcludeApp ID="Access" />
                    <ExcludeApp ID="Publisher" />
                    <ExcludeApp ID="OneDrive" />
                    <ExcludeApp ID="Groove" />
                    <ExcludeApp ID="Lynk" />
                    <ExcludeApp ID="OneNote" />
                    <ExcludeApp ID="SkypeforBusinessRetail"/>
                    <!-- If not using Outlook UWP App comment out the next line to avoid removing Outlook -->
                    <!-- <ExcludeApp ID="Outlook" /> -->
                </Product>
                </Add>
                <Updates Enabled="TRUE" Channel="Broad" />
                <Display Level="None" AcceptEULA="TRUE" />
                -->
            </Configuration>
'@
            $MSCleanupConfig | Out-File "$($env:TEMP)\OfficeCleanupCfg.xml"
            Start-Process -FilePath "$($env:LOCALAPPDATA)\Programs\Office Deployment Tool\setup.exe" -ArgumentList "/configure ""$($env:TEMP)\OfficeCleanupCfg.xml"""
            ConvertTo-Json -InputObject $CurrentOfficeVer | Out-File "$($env:LOCALAPPDATA)\Programs\Office Deployment Tool\CurrentOfficeVer.json"
        }
    }
    else {
        Write-Host "MS Office is not installed at all."
    }
    return $false
}