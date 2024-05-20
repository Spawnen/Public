<#
.SYNOPSIS
    This script removes old user accounts based on inactivity, calculates disk space freed, and visually displays found user accounts.

.DESCRIPTION
    Identifies and removes user accounts inactive for a specified period. Excluded users can be configured. The inactivity threshold is 40 days by default. It includes disk space calculations and visual feedback on user accounts processed.

.NOTES
    File Name      : Delete_OldUserAccounts_VisualFeedback.ps1
    Version        : 1.0.7
    Author         : Robert Lohman
    Prerequisite   : PowerShell version 3 or higher
#>

###########################################
# Script Configuration
###########################################

$EnableWhatIf = $true# Set to $true for a dry run
$excludedUsers = @("Administrator", "testuser", "sccm_na")
$inactiveThreshold = 0 # In days
$LogFolderPath = "C:\windows\temp\DeletedUsers"
$dateStamp = Get-Date -Format "yyyyMMdd"
$logPath = Join-Path $LogFolderPath "$($env:computername)_${dateStamp}_RemovedUsers.log"
$LogdestinationPath = "" # Set destination for log copying if needed

###########################################
# Initialize Log and Folder
###########################################

if (-not (Test-Path -Path $LogFolderPath)) {
    New-Item -Path $LogFolderPath -ItemType Directory | Out-Null
    Write-Host "Log Folder created: $LogFolderPath" -ForegroundColor Green
} else {
    Write-Host "$LogFolderPath already exists" -ForegroundColor Cyan
}

if (Test-Path $logPath) {
    Remove-Item $logPath -Force
    Write-Host "Old Log-File removed: $logPath" -ForegroundColor Red
}
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Script Execution Started"

# Get initial disk space
$initialFreeSpace = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Initial Free Disk Space: $initialFreeSpace GB"

###########################################
# Main Script
###########################################

$deletedUserCount = 0
$savedUserCount = 0

$allUsers = Get-CimInstance Win32_UserProfile | Where-Object { $_.Special -eq $false }

foreach ($user in $allUsers) {
    $username = $user.LocalPath.Split('\')[-1]
    $lastUse = [datetime]$user.LastUseTime
    $daysInactive = (New-TimeSpan -Start $lastUse -End (Get-Date)).Days

    if ($excludedUsers -contains $username -or $daysInactive -le $inactiveThreshold) {
        $savedUserCount++
        $excludeMessage = "User account $username is excluded from deletion or not inactive long enough. Inactivity: $daysInactive days"
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $excludeMessage"
        Write-Host $excludeMessage -ForegroundColor Cyan
        continue
    }

    $deleteMessage = "User account $username marked for deletion. Inactive for $daysInactive days."
    Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $deleteMessage"
    Write-Host $deleteMessage -ForegroundColor Red

    try {
        if (-not $EnableWhatIf) {
            Remove-CimInstance -CimInstance $user
            $deletedUserCount++
            $deleteSuccessMessage = "Successfully deleted user account $username."
            Write-Host $deleteSuccessMessage -ForegroundColor Green
        } else {
            $whatIfMessage = "WhatIf: User account $username would be deleted."
            Write-Host $whatIfMessage -ForegroundColor Yellow
        }
    } catch {
        $errorMessage = "Failed to delete user account $username. Error: $($_.Exception.Message)"
        Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $errorMessage"
        Write-Host $errorMessage -ForegroundColor Red
    }
}

# Final disk space calculation
$finalFreeSpace = [math]::Round((Get-PSDrive C).Free / 1GB, 2)
$spaceFreed = $finalFreeSpace - $initialFreeSpace

Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Final Free Disk Space: $finalFreeSpace GB"
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Total Disk Space Freed: $spaceFreed GB"
Add-Content -Path $logPath -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Total Deleted: $deletedUserCount, Total Saved: $savedUserCount"

# Optional: Copy log to a network share
if ($LogdestinationPath) {
    Start-Sleep -Seconds 3
    Robocopy $LogFolderPath $LogdestinationPath "$($env:computername)_${dateStamp}_RemovedUsers.log" /R:5 /W:1
    Write-Host "Log file copied to $LogdestinationPath" -ForegroundColor Yellow
} else {
    Write-Host "Log destination path is not set. Skipping log copy." -ForegroundColor Yellow
}
