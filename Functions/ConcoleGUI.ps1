function ImportConsoleGUI {
    try {
        Import-Module Microsoft.PowerShell.ConsoleGuiTools 
    }  
    catch {
        . "$($PSScriptRoot)\RunAsAdmin.ps1"
        RunAsAdmin "$($PSCommandPath)"
        Install-Module Microsoft.PowerShell.ConsoleGuiTools 
    }
}