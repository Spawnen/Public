<#
.SYNOPSIS
    PowerShell script for gathering and exporting Autopilot information from Microsoft Intune.

.NOTES
    Author:         Robert Lohman
    Version:        1.4.0
    Creation Date:  30.03.2025
    Updated:        01.04.2025


    Version History:
        1.0.0 - Initial release.
        1.3.0 - Improved data retrieval and Excel export handling.
        1.4.0 - Added interactive file path prompt and improved Microsoft Graph connection handling.

.DESCRIPTION
    This script retrieves Autopilot device information, profiles, and synchronization details from Microsoft Intune using Microsoft Graph API. It then exports the data to an Excel file with separate worksheets for each data type.

#>
# ===============================
# User Configurable Variables
# ===============================

# Path to XLSX if you want it pre-defined
[string]$DefaultOutputPath = "c:\temp\test.xlsx"

# Number of days back to filter in Autopilot deployment (0 = no filtering)
[int]$DaysToCheck = 0

# Number of hours back to filter in Autopilot deployment (0 = no filtering)
[int]$HoursToCheck = 0

# ===============================


# Prompt the user to select a file path to save the Excel file if DefaultOutputPath is not specified
if (-not $DefaultOutputPath) {
    $OutputFileName = Read-Host "Enter the full path and filename for the Excel file (e.g., C:\Reports\AutopilotReport.xlsx)"
} else {
    $OutputFileName = $DefaultOutputPath
    Write-Host "Using predefined output path: $OutputFileName" -ForegroundColor Cyan
}

# Validate file extension
if (-not ($OutputFileName.EndsWith('.xlsx'))) {
    Write-Warning "The specified filename must end with .xlsx. Exiting..."
    return
}

# Test file path and accessibility
try {
    if (Test-Path -Path $OutputFileName) {
        Write-Host "Specified file '$OutputFileName' already exists. Data will be appended." -ForegroundColor Yellow
    } else {
        New-Item -Path $OutputFileName -ItemType File -Force | Out-Null
        Remove-Item -Path $OutputFileName -Force
        Write-Host "Output file path is valid and accessible." -ForegroundColor Green
    }
}
catch {
    Write-Warning "Unable to access the specified file path. Exiting..."
    return
}

# Ensure necessary modules are installed
$modules = @('Microsoft.Graph.Authentication', 'Microsoft.Graph.Beta.DeviceManagement', 'ImportExcel', 'WindowsAutoPilotIntune')
$missingModules = $modules | Where-Object { -not (Get-Module -ListAvailable -Name $_) }

if ($missingModules) {
    Write-Host "Installing missing modules: $($missingModules -join ', ')..." -ForegroundColor Yellow
    try {
        Install-Module -Name $missingModules -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to install required modules. Exiting..."
        return
    }
}

# Connect to Microsoft Graph with login prompt
try {
    Disconnect-MgGraph -ErrorAction SilentlyContinue  # Disconnect any previous sessions
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All, DeviceManagementServiceConfig.Read.All'
    Write-Host "Successfully connected to Microsoft Graph." -ForegroundColor Green
}
catch {
    Write-Warning "Unable to connect to Microsoft Graph. Check permissions or network access. Exiting..."
    return
}

#Use Invoke-MgGraphRequest to get som info

$endpoint = "https://graph.microsoft.com/beta/deviceManagement/autopilotEvents"
$autopilotEvents = Invoke-MgGraphRequest -Method GET -Uri $endpoint
$autopilotEvents.value | Out-Null


# Filter for hours or days
if ($DaysToCheck -gt 0) {
    $FilteredEvents = $autopilotEvents.value | Where-Object { 
        if ($_.deploymentEndDateTime) {
            $EventDate = [datetime]::Parse($_.deploymentEndDateTime)  # Konvertera till DateTime
            $EventDate -gt (Get-Date).AddDays(-$DaysToCheck)
        }
    }
}
elseif ($HoursToCheck -gt 0) {
    $FilteredEvents = $autopilotEvents.value | Where-Object { 
        if ($_.deploymentEndDateTime) {
            $EventDate = [datetime]::Parse($_.deploymentEndDateTime)  # Konvertera till DateTime
            $EventDate -gt (Get-Date).AddHours(-$HoursToCheck)
        }
    }
}
else {
    $FilteredEvents = $autopilotEvents.value
}


Write-Host "Filtering completed. Proceeding to export..."

# Retrieve all Managed Devices for quick lookup later
$AllManagedDevices = Get-MgBetaDeviceManagementManagedDevice -All
$DeviceNameLookup = @{}
foreach ($Device in $AllManagedDevices) {
    $DeviceNameLookup[$Device.Id] = $Device.DeviceName
}

# Collect data from Microsoft Graph
try {
    $AutopilotDevices = Get-AutopilotDevice -ErrorAction Stop
    $AutopilotProfiles = Get-AutopilotProfile -ErrorAction Stop
    $AutoPilotSyncInfo = Get-AutopilotSyncInfo -ErrorAction Stop
    Write-Host "Autopilot data retrieved successfully." -ForegroundColor Green
}
catch {
    Write-Warning "Failed to retrieve Autopilot data. Check permissions or connectivity. Exiting..."
    return
}

#Set date format for the Excel tabs
$date = Get-Date -Format "yyyyMMdd_HHmm"

#Export AutopilotDevices
$totalDevices = foreach ($AutopilotDevice in $AutopilotDevices | Sort-Object serialNumber) {
    [PSCustomObject]@{
        DeviceId                               = $AutopilotDevice.azureActiveDirectoryDeviceId
        IntuneId                               = $AutopilotDevice.id
        DeviceName                             = (Get-MgBetaDeviceManagementManagedDevice -ManagedDeviceId $AutopilotDevice.managedDeviceId -ErrorAction SilentlyContinue).DeviceName
        GroupTag                               = $AutopilotDevice.groupTag
        'Assigned user'                        = $AutopilotDevice.addressableUserName
        'Last contacted'                       = $AutopilotDevice.lastContactedDateTime
        'Profile status'                       = $AutopilotDevice.deploymentProfileAssignmentStatus
        'Profile assignment Date'              = $AutopilotDevice.deploymentProfileAssignedDateTime
        'Purchase order'                       = $AutopilotDevice.purchaseOrderIdentifier
        'Remediation state'                    = $AutopilotDevice.remediationState
        'Remediation state last modified date' = $AutopilotDevice.remediationStateLastModifiedDateTime
        Manufacturer                           = $AutopilotDevice.manufacturer
        Model                                  = $AutopilotDevice.model
        Serialnumber                           = $AutopilotDevice.serialNumber
        SkuNumber                              = $AutopilotDevice.skuNumber
        'System family'                        = $AutopilotDevice.systemFamily        
        
    }
}

try {
    $totalDevices | Export-Excel -Path $OutputFileName -WorksheetName "AutopilotDevices_$date" -AutoFilter -AutoSize -Append -ErrorAction Stop
    Write-Host "Exported Autopilot Devices to $OutputFileName" -ForegroundColor Green
}
catch {
    Write-Warning "Error exporting Autopilot Devices to $OutputFileName"
}

# Export Autopilot Sync Information
$totalSync = [PSCustomObject]@{
    syncStatus              = $AutoPilotSyncInfo.syncStatus
    'Last sync time'        = $AutoPilotSyncInfo.lastSyncDateTime
    'Last manual sync time' = $AutoPilotSyncInfo.lastManualSyncTriggerDateTime
}

try {
    $totalSync | Export-Excel -Path $OutputFileName -WorksheetName "AutopilotSyncInfo_$date" -AutoFilter -AutoSize -Append
    Write-Host "Exported Autopilot Sync Information to $OutputFileName" -ForegroundColor Green
}
catch {
    Write-Warning "Error exporting Autopilot Sync Information to $OutputFileName"
}

# Count installation time

    $EndDateTime = $Event.deploymentEndDateTime
	$StartDateTime = $Event.deploymentStartDateTime
    

    $StartTime = $StartDateTime 
	$Formated_StartDateTime = [datetime]$StartTime

	$EndTime = $EndDateTime 
	$Formated_EndDateTime = [datetime]$EndTime	

	$Total_Duration = $Formated_EndDateTime - $Formated_StartDateTime
	$Formated_Duration = $Total_Duration.ToString("hh' hours 'mm' minutes 'ss' seconds'")

# Export Autopilot Deployment Information
$AutoPilot = foreach ($Event in $FilteredEvents) {
    [PSCustomObject]@{
        'Autopilot Start'   = $Event.deploymentStartDateTime
        'Autopilot End'     = $Event.deploymentEndDateTime
        'Installation time' = $Formated_Duration
         DeploymentState    = $Event.deploymentState         
         Enroller           = $Event.userPrincipalName
         deviceId           = $Event.deviceId
         'Device Name'      = $DeviceNameLookup[$Event.deviceId] # Hämtar Device Name från hashtable
         EnrollmentType     = $Event.enrollmentType
         OSVersion          = $Event.OSVersion
         SerialNumber = $Event.deviceSerialNumber

    }
}
try {
    $AutoPilot | Export-Excel -Path $OutputFileName -WorksheetName "Autopilot_$date" -AutoFilter -AutoSize -Append
    Write-Host "Exported Autopilot Deployment Information to $OutputFileName" -ForegroundColor Green
}
catch {
    Write-Warning "Error exporting Autopilot Deployment Information to $OutputFileName"
}
Write-Host "Script completed successfully." -ForegroundColor Green