<#
.SYNOPSIS
    PowerShell script for installing language packs and configuring the default MUI language on Windows devices.

.NOTES
    Author:         Robert Lohman
    Version:        1.4.0
    Creation Date:  30.03.2025
    Updated:        01.04.2025
    Compatibility:  Windows 11
    Requirements:   Must be executed with elevated privileges (System context) and in 64-bit PowerShell.
    Credit: Original script from https://www.inthecloud247.com/install-an-additional-language-pack-on-windows-11-during-autopilot-enrollment/
    Credit: https://msendpointmgr.com/2024/06/09/managing-windows-11-languages-and-region-settings/ 
    Version History:
        1.0.0 - Initial release.
        1.3.0 - Modernized logging, registry handling, and code cleanup.
        1.4.0 - Restored Intune-compatible logging and improved parameter handling.

.DESCRIPTION
    This script installs a specified language pack, sets the default display language, regional settings, 
    and input locale on Windows devices. It also ensures these settings are applied system-wide, including 
    for the Welcome screen and new user profiles.

.EXAMPLE
    %windir%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File ".\Change_Language_sv-SE.ps1"
    %windir%\SysNative\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File ".\Change_Language_sv-SE.ps1" -LPlanguage "sv-SE" -InputlocaleRegion "sv-SE" -GeoId 221

.PARAMETER LPlanguage
    The language tag of the language pack to install. Default is "sv-SE".
    Language tag can be found here: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-11#language-packs

.PARAMETER InputlocaleRegion
    The input locale and region to set. Default is "sv-SE".
    A list of input locales can be found here: https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-input-locales-for-windows-language-packs?view=windows-11#input-locales

.PARAMETER GeoId
    The geographical ID to set. Default is 221 (Sweden).
    Geographical ID we want to set. GeoID can be found here: https://learn.microsoft.com/en-us/windows/win32/intl/table-of-geographical-locations


#>

param (
    [string]$LPlanguage = "sv-SE",
    [string]$InputlocaleRegion = "sv-SE",
    [int]$GeoId = 221
)

# Ensure the script is running in 64-bit PowerShell
if (-not [Environment]::Is64BitProcess) {
    Write-Host "Restarting script in 64-bit PowerShell"
    Start-Process -FilePath "$env:SystemRoot\SysNative\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Wait
    Exit
}

# Logging function using Intune-compatible format
function Write-LogEntry {
    param (
        [parameter(Mandatory = $true)]
        [string]$Value,
        
        [parameter(Mandatory = $true)]
        [ValidateSet("1", "2", "3")]
        [string]$Severity
    )
    $LogFileName = "Invoke-ChangeDefaultLanguage-$LPlanguage.log"
    $LogFilePath = Join-Path -Path $env:ProgramData -ChildPath "Microsoft\IntuneManagementExtension\Logs\$LogFileName"

    $Time = (Get-Date -Format "HH:mm:ss.fff")
    $Date = (Get-Date -Format "MM-dd-yyyy")
    $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    $LogText = "<![LOG[$($Value)]LOG]!><time=""$($Time)"" date=""$($Date)"" component=""$($LogFileName)"" context=""$($Context)"" type=""$($Severity)"" thread=""$($PID)"" file="""">"

    try {
        Out-File -InputObject $LogText -Append -Encoding Default -FilePath $LogFilePath
    }
    catch {
        Write-Warning "Failed to write to log file: $LogFilePath. Error: $_"
    }
}

Write-LogEntry -Value "Starting language configuration script for language $LPlanguage." -Severity 1

# Install Language Pack
try {
    Write-LogEntry -Value "Attempting to install language pack: $LPlanguage" -Severity 1
    Install-Language -Language $LPlanguage -CopyToSettings -ErrorAction Stop
    Write-LogEntry -Value "$LPlanguage is installed successfully." -Severity 1
}
catch {
    Write-LogEntry -Value "Failed to install language pack: $($_.Exception.Message)" -Severity 3
    Exit 1
}

Write-LogEntry -Value "Setting Win UI Language Override to $InputlocaleRegion." -Severity 1
Set-WinUILanguageOverride -Language $InputlocaleRegion

Write-LogEntry -Value "Setting user language list to include $InputlocaleRegion." -Severity 1
$OldList = Get-WinUserLanguageList
$UserLanguageList = New-WinUserLanguageList -Language $InputlocaleRegion
$UserLanguageList += $OldList
Set-WinUserLanguageList -LanguageList $UserLanguageList -Force

Write-LogEntry -Value "Setting region location to GeoId $GeoId." -Severity 1
Set-WinHomeLocation -GeoId $GeoId

Write-LogEntry -Value "Setting region format to $InputlocaleRegion." -Severity 1
Set-Culture -CultureInfo $InputlocaleRegion

Write-LogEntry -Value "Copying user international settings to system." -Severity 1
Copy-UserInternationalSettingsToSystem -WelcomeScreen $True -NewUser $True

# Registry Setup for Intune Detection
$CompanyName = "Lohmans"
$KeyPath = "HKLM:\SOFTWARE\$CompanyName\LanguageXPWIN11ESP\v1.4.0"
$ValueName = "SetLanguage-$InputlocaleRegion"

Write-LogEntry -Value "Creating or verifying registry path: $KeyPath" -Severity 1

try {
    if (!(Test-Path $KeyPath)) {
        New-Item -Path $KeyPath -Force | Out-Null
    }
    New-ItemProperty -Path $KeyPath -Name $ValueName -PropertyType DWORD -Value 1 -Force | Out-Null
    Write-LogEntry -Value "Registry entry $ValueName created successfully." -Severity 1
}
catch {
    Write-LogEntry -Value "Failed to create registry key or value. Error: $($_.Exception.Message)" -Severity 3
    Exit 1
}

Write-LogEntry -Value "Script completed successfully. Restart required for changes to fully apply." -Severity 1
Exit 3010
