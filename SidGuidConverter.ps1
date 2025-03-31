<#
.SYNOPSIS
    Azure AD SID and Object ID Conversion Script

.DESCRIPTION
    This script provides functions to convert Azure AD SIDs to Object IDs and vice versa.
    It supports Azure AD SIDs starting with 'S-1-12-1-' and allows for user-defined input.

.PARAMETERS
    $objectId - The Azure AD Object ID (GUID) to convert to a SID.
    $sidTest  - The Azure AD SID to convert to an Object ID.

.NOTES
    Version:        1.1.0
    Author:         Robert Lohman
    Creation Date:  30.03.2025
    Updated:        31.03.2025

    Version history:
        1.0.0 - Initial release
        1.0.1 - Fixed byte order conversion in SID to Object ID conversion
        1.1.0 - Improved script structure, added user-friendly input handling, enhanced logging

    License: Provided "AS IS" with no warranties. Use at your own risk.

#>

# ========================
# USER-DEFINED VARIABLES (Edit these as needed)
# ========================

$objectId = ""  # Provide the Azure AD Object ID (GUID) here. Leave blank if not needed.
$sidTest = ""   # Provide the Azure AD SID here. Leave blank if not needed.

# ========================
# Function: Convert-AzureAdObjectIdToSid
# ========================

function Convert-AzureAdObjectIdToSid {

    param([String] $ObjectId)

    try {
        if (![string]::IsNullOrWhiteSpace($ObjectId)) {
            $bytes = [Guid]::Parse($ObjectId).ToByteArray()
            $array = New-Object 'UInt32[]' 4
            [Buffer]::BlockCopy($bytes, 0, $array, 0, 16)
            $sid = "S-1-12-1-$array".Replace(' ', '-')
            return $sid
        } else {
            Write-Host "No Object ID provided. Conversion skipped." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to convert Object ID to SID. Error: $_" -ForegroundColor Red
    }
}

# ========================
# Function: Convert-AzureAdSidToObjectId
# ========================

function Convert-AzureAdSidToObjectId {

    param([String] $Sid)

    try {
        if (![string]::IsNullOrWhiteSpace($Sid)) {
            $text = $Sid.Replace('S-1-12-1-', '')
            $array = [UInt32[]]$text.Split('-')
            $bytes = New-Object 'Byte[]' 16
            [Buffer]::BlockCopy($array, 0, $bytes, 0, 16)
            [Guid]$guid = $bytes
            return $guid
        } else {
            Write-Host "No SID provided. Conversion skipped." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "Failed to convert SID to Object ID. Error: $_" -ForegroundColor Red
    }
}

# ========================
# Conversion Operations
# ========================

Write-Host "Starting Azure AD SID and Object ID Conversion Script..." -ForegroundColor Cyan

# Convert Object ID to SID if Object ID is provided
if (![string]::IsNullOrWhiteSpace($objectId)) {
    $sid = Convert-AzureAdObjectIdToSid -ObjectId $objectId
    if ($sid) {
        Write-Host "Object ID to SID Conversion:" -ForegroundColor Green
        Write-Host "Input Object ID: $objectId" -ForegroundColor DarkGray
        Write-Host "Converted SID:   $sid" -ForegroundColor White
    }
}

# Convert SID to Object ID if SID is provided
if (![string]::IsNullOrWhiteSpace($sidTest)) {
    $objectIdTest = Convert-AzureAdSidToObjectId -Sid $sidTest
    if ($objectIdTest) {
        Write-Host "`nSID to Object ID Conversion:" -ForegroundColor Green
        Write-Host "Input SID:       $sidTest" -ForegroundColor DarkGray
        Write-Host "Converted Object ID: $objectIdTest" -ForegroundColor White
    }
}

Write-Host "`nScript completed." -ForegroundColor Cyan
