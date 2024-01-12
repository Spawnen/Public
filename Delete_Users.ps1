

<#
.SYNOPSIS
    This script will help you to remove old user accounts.
    # To Exclude users configure line 31
    # You must set the threshold "$inactiveThreshold" on line 30 (default value is 20 days), If the user has been inactive for more days, it will be up for deletion
    # Remove "-WhatIf" on line-222 to remove Script's Safety, and it will remove users
    See "Script Configuration" for more functions 

.DESCRIPTION
    Detailed description not here yet.

.NOTES
    File Name      : Delete_users.ps1
    Version        : 1.0.1
    Author         : Robert Lohman
    Prerequisite   : Ensure that the major powershell version is 3 or higher to use
    


#>
###########################################
# Script Configuration
###########################################

# Set exclusion usernames
$excludedUsers = @("Administratör", "sccm_admi", "sccm_na")

# Set the threshold for accounts inactivity (days). If the user has been inactive for more days, it will be up for deletion
$inactiveThreshold = (Get-Date).AddDays(-20)

# Get the current date for log filename
$dateStamp = Get-Date -Format "yyyyMMdd"

# Home of Log-file 
$LogFolderPath ="C:\windows\temp\Deletedusers"
$logPath = ("$LogFolderPath\$($env:computername)_$($dateStamp)_Removedusers.log")

# Set destination to FileShare
$LogdestinationPath = "\\sccm\logs$\deletedusers"


############################################

if (Test-Path $logPath -PathType Leaf) {
    # File exists, so remove it
    Remove-Item $logPath -Force
    Write-Host "Old Log-File removed: $logPath" -ForegroundColor Red
} else {
    Write-Host "File does not exist: $logPath"
}

### Disk calculations
$FreespaceonC = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -ExpandProperty FreeSpace) / 1GB, 0)

###########################################
# Create LogFolder if not exists
###########################################

function Create-Folder {
    param (
        [Parameter(Mandatory=$true)] [string] $LogFolderPath
    )

    if (-not (Test-Path -Path $LogFolderPath -PathType Container)) {
        # Log Folder doesn't exist, create it
        New-Item -Path $LogFolderPath -ItemType Directory | Out-Null
        Write-Host "Log Folder created $LogFolderPath" -ForegroundColor Green
    } else {
        Write-Host "$LogFolderPath already exists" -ForegroundColor Cyan
    }
}

Create-Folder -LogFolderPath ($LogFolderPath)

###########################################
# Logging Functions
###########################################

# Counter for deleted user accounts
$deletedUserCount = 0
$savedUserCount = 0

function Log-Message {
    param (
        [Parameter(Mandatory=$true)] [string] $Message,
        [Parameter(Mandatory=$true)] [string] $LogFilePath
    )

    try {
        # Add content to the log file
        Add-Content -Path $LogFilePath -Value "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) - $Message"
        Write-Host "Message: '$Message'" -ForegroundColor Yellow
    }
    catch {
        Write-Host -ForegroundColor Red "Error: $($_.Exception.Message)"
    }
}

function Log-DeletionFailure {
    param (
        [Parameter(Mandatory=$true)] [string] $Username,
        [Parameter(Mandatory=$true)] [string] $Reason,
        [Parameter(Mandatory=$true)] [string] $LogFilePath
    )

    $failureMessage = "$(Get-Date) - Deletion of user account $Username failed. Reason: $Reason"
    Log-Message -Message $failureMessage -LogFilePath $LogFilePath
}

###########################################
# Main Script
###########################################

# Initialize hashtable for storing last logon times
$lastlogin = @{}

# Retrieve last logon times using WMI
Get-CimInstance -ClassName Win32_NetworkLoginProfile |
Sort-Object -Property LastLogon -Descending |
ForEach-Object {
    $lastUse = $_.LastLogon
    $username = $_.Name.Split("\")[-1]
    $lastlogin[$username] = $lastUse
}

# Get the current date and time
$timestamp = Get-Date -Format "yyyy.MM.dd-HH:mm:ss"

# Initialize the log file
Add-Content -Path $logPath -Value "$($timestamp) - Script Execution Started"


# Get the total disk size
$TotalDiskSpace = [math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='C:'" | Select-Object -ExpandProperty Size) / 1GB, 0)

# Get the remaining disk space on the C: drive before any operation
$freeDiskSpaceBefore = $FreespaceonC

$logMessage = "Total Disk Size: $TotalDiskSpace GB"
Log-Message -Message $logMessage -LogFilePath $logPath

$logMessage = "Initial remaining DiskSpace: $freeDiskSpaceBefore GB`r`n"
Log-Message -Message $logMessage -LogFilePath $logPath

# Get a list of all user accounts
$allUsers = Get-CimInstance Win32_UserProfile | Where-Object { $_.Special -eq $false }

# Initialize arrays for users to be deleted and users not to be deleted
$usersToDelete = @()
$usersToKeep = @()

foreach ($user in $allUsers) {
    $lastUse = $lastlogin[$user.LocalPath.Split('\')[-1]]
    $username = $user.LocalPath.Split('\')[-1]
    # Get the size of the user's directory
    $directorySize = [math]::Round((Get-ChildItem -Path $user.LocalPath -Recurse | Measure-Object -Property Length -Sum).Sum  / 1MB, 3)

    # Log information about the user
    $logMessage = "User found: $username, Account last Activity: $lastUse"
    Log-Message -Message $logMessage -LogFilePath $logPath

    # Check if the user account is excluded or inactive for more than the InactivityThreshold
    if ($excludedUsers -notcontains $username -and $lastUse -lt $inactiveThreshold) {

        # Add the user to the array of users to be deleted
        $usersToDelete += @{
            "Username" = $username
            "DirectorySize" = $directorySize
        }

        # Increment the deleted user count
        $deletedUserCount++

        # Log the information about the account to be deleted
        $logMessage = "User account $username is scheduled for deletion.`r`n" 
        Log-Message -Message $logMessage -LogFilePath $logPath
    }
    else {
        # Log the exclusion status
        $logMessage = "User account $username is excluded from deletion.`r`n"
        Log-Message -Message $logMessage -LogFilePath $logPath

        # Add the user to the array of users not to be deleted
        $usersToKeep += @{
            "Username" = $username
            "DirectorySize" = $directorySize
        }
        # Increment the deleted user count
        $savedUserCount++
    }
}

# Display the users not to be deleted
if ($usersToKeep.Count -gt 0) {
    Write-Host "Users to Keep:" -ForegroundColor Green -BackgroundColor Black
    $usersToKeep | ForEach-Object { 
        $logMessage = "Keep User: $($_.Username), Directory Size: $($_.DirectorySize) MB`r`n"
        Log-Message -Message $logMessage -LogFilePath $logPath
    }
} else {
    Write-Host "No users found to save (all users found get's deleted). `r`n" -ForegroundColor Red -BackgroundColor Black
}


# Display the users to be deleted if there are users to delete
if ($usersToDelete.Count -gt 0) {
    Write-Host "Users to delete:" -ForegroundColor Red -BackgroundColor Black
    $usersToDelete | ForEach-Object {      
        $logMessage = "Delete User: $($_.Username), Directory Size: $($_.DirectorySize) MB`r`n"
        Log-Message -Message $logMessage -LogFilePath $logPath
    }
} else {
    Write-Host "No users found to delete. `r`n" -ForegroundColor Cyan -BackgroundColor Black
}

# Remove the user accounts
foreach ($userToDelete in $usersToDelete) {
    try {
        $userToDeleteName = $userToDelete["Username"]
        Remove-CimInstance -CimInstance (Get-CimInstance Win32_UserProfile | Where-Object { $_.LocalPath.Split('\')[-1] -eq $userToDeleteName }) -WhatIf
        Write-Host "User: $userToDeleteName is Deleted!" -ForegroundColor White -BackgroundColor DarkCyan
    }
    catch {
        $errorMessage = $_.Exception.Message
        Log-DeletionFailure -Username $userToDeleteName -Reason $errorMessage -LogFilePath $logPath
    }
}

# Log the total number of saved user accounts
$logMessage = "Total number of user accounts NOT deleted: $savedUserCount"
Log-Message -Message $logMessage -LogFilePath $logPath

# Log the total number of deleted user accounts
$logMessage = "Total number of user accounts deleted: $deletedUserCount`r`n"
Log-Message -Message $logMessage -LogFilePath $logPath

# Get the remaining disk space on the C: drive
$freeDiskSpaceAfter = $FreespaceonC

# Remaining Disk space check after Users Cleanup
$logMessage = "Remaining space after cleanup: $freeDiskSpaceAfter GB"
Log-Message -Message $logMessage -LogFilePath $logPath

# Calculate the space saved after cleanup
$TotalSpaceSaved = $freeDiskSpaceBefore - $freeDiskSpaceAfter

# Log the space saved by the cleanup
$logMessage = "Gained this amount of space: $TotalSpaceSaved GB`r`n"
Log-Message -Message $logMessage -LogFilePath $logPath


# Log the completion of the script
Add-Content -Path $logPath -Value "$(Get-Date) - Script Execution Completed"


# Copy log to Fileshare
#Start-Sleep 3
# Robocopy "$LogFolderPath" "$LogdestinationPath" /R:20
