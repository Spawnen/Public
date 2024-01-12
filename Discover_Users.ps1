<#
.SYNOPSIS

    This script is designed to check user profiles on a Windows system and identify inactive users based on a specified threshold, this determines whether a remediation script should be executed. 
    If the script generates "1," the remediation script will run
    # To Exclude users configure line 26
    # Set the threshold on line 29 (Default value is 20 days)

.DESCRIPTION
    Detailed description not here yet.

.NOTES
    File Name      : Discovery_Script.ps1
    Version        : 1.0.1 20240111 Revised
    Author         : Robert Lohman
    Prerequisite   : Ensure that the major version is 3 or higher to use
    


#>
###########################################
# Script Configuration
###########################################

# Set exclusion usernames
$excludedUsers = @("Administratör", "sccm_admi", "sccm_na")

# Set threshold for accounts inactivity (days). If the user has been inactive for more days, it will be up for deletion
$inactiveThreshold = (Get-Date).AddDays(-20)

###########################################
# Main Script
###########################################

# Initialize hashtable for storing last logon times
$lastlogin = @{}

# Retrieve last logon times using WMI
Get-WmiObject -Class Win32_NetworkLoginProfile | 
Sort-Object -Property LastLogon -Descending | 
Where-Object { $_.LastLogon -match "(\d{14})" } | 
ForEach-Object { $lastlogin[$_.Name.Split("\")[-1]] = [datetime]::ParseExact($matches[0], "yyyyMMddHHmmss", $null) }

# Initialize a variable to track whether any user meets the criteria
$allUsersMeetCriteria = $true

# Get all user profiles
$allUsers = Get-WmiObject -Class Win32_UserProfile  | Where-Object { $_.Special -eq $false }

# Iterate through each user profile
foreach ($user in $allUsers) {
    # Check if the current user is in the exclusion list
    if ($excludedUsers -contains $user.LocalPath.Split("\")[-1]) {
        Write-Host "Excluded user: $($user.LocalPath.Split("\")[-1])`r`n" -ForegroundColor Green -BackgroundColor Black
        continue  # Skip this user and move to the next one
    }

    # Check if the user has a last logon time in the $lastlogin hashtable
    if ($lastlogin.ContainsKey($user.LocalPath.Split("\")[-1])) {
        $lastLogonTime = $lastlogin[$user.LocalPath.Split("\")[-1]]

        # Check if the user has been inactive for more than the threshold
        if ($lastLogonTime -lt $inactiveThreshold) {
            Write-Host "Inactive user: $($user.LocalPath.Split("\")[-1])" -ForegroundColor Red -BackgroundColor Black
            Write-Host "Last Logon: $($lastLogonTime)`r`n" -ForegroundColor Red -BackgroundColor Black
            Write-Host "Will set remediation script to run (1)`r`n"
            $allUsersMeetCriteria = $false
            continue  # Skip this user and move to the next one
        }
        else {
            Write-Host "Active user: $($user.LocalPath.Split("\")[-1])" -ForegroundColor Green -BackgroundColor Black
            Write-Host "Last Logon: $($lastLogonTime)`r`n" -ForegroundColor Green -BackgroundColor Black
            
        }
    }
}

# Print "0" if any user does not meet the criteria, otherwise, print "1"
if ($allUsersMeetCriteria) {
    Write-Host "Remediation script will NOT run (0)`r`n"
    Write-Host "0"
} else {
    Write-Host "1"
}
