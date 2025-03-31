<#
.SYNOPSIS
    Professional Azure AD SID and Object ID Conversion Script

.DESCRIPTION
    This script provides functions to convert Azure AD SIDs to Object IDs and vice versa.
    It is specifically designed to work with Azure AD SIDs starting with 'S-1-12-1-'.

.FUNCTIONS
    Convert-AzureAdObjectIdToSid - Converts an Azure AD Object ID (GUID) to an Azure AD SID (Security Identifier).
    Convert-SidToAzureAdObjectId - Converts an Azure AD SID back to an Object ID (GUID).

.NOTES
    Version:        1.0.0
    Author:         Robert Lohman
    Creation Date:  30.03.2025
    Updated:        30.03.2025

    Version history:
        1.0.0 - Initial release

    License: Provided "AS IS" with no warranties. Use at your own risk.

#>

# ========================
# Variables
# ========================

# Enter your SID here
$sidTest = ""

# Enter your Object ID here
$objectId = ""


# ========================
# Function: Convert-AzureAdObjectIdToSid
# ========================

function Convert-AzureAdObjectIdToSid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String] $ObjectID
    )

    try {
        $bytes = [Guid]::Parse($ObjectID).ToByteArray()
        $array = New-Object 'UInt32[]' 4

        [Buffer]::BlockCopy($bytes, 0, $array, 0, 16)
        $sid = "S-1-12-1-" + ($array -join '-')
        return $sid
    }
    catch {
        Write-Error "Failed to convert Object ID to SID. Verify that the Object ID is in the correct format and try again. Error message: $_"
    }
}

# ========================
# Function: Convert-SidToAzureAdObjectId
# ========================

function Convert-SidToAzureAdObjectId {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$SID
    )

    try {
        if ($SID -notmatch "^S-1-12-1-") {
            Throw "This script only supports SIDs that start with 'S-1-12-1-'"
        }

        $parts = $SID -replace "^S-1-12-1-", "" -split '-'

        if ($parts.Count -ne 4) {
            Throw "The SID must contain exactly four parts after 'S-1-12-1-'"
        }

        $bytes = New-Object byte[] 16

        for ($i = 0; $i -lt 4; $i++) {
            $partBytes = [BitConverter]::GetBytes([UInt32]::Parse($parts[$i]))
            [Array]::Reverse($partBytes)
            [Array]::Copy($partBytes, 0, $bytes, $i * 4, 4)
        }

        $guid = New-Object Guid (,$bytes)
        return $guid.ToString()
    }
    catch {
        Write-Error "Failed to convert SID to Object ID. Verify that the SID is in the correct format and try again. Error message: $_"
    }
}

# ========================
# Conversion Operations
# ========================

if ($objectId -ne "") {
    $sid = Convert-AzureAdObjectIdToSid -ObjectID $objectId
    Write-Output "Object ID to SID: $sid"
} else {
    Write-Output "No Object ID provided, skipping conversion."
}

if ($sidTest -ne "") {
    $objectIdTest = Convert-SidToAzureAdObjectId -SID $sidTest
    Write-Output "SID to Object ID: $objectIdTest"
} else {
    Write-Output "No SID provided, skipping conversion."
}
