<#
.SYNOPSIS
This script provides functions to convert Azure AD SIDs to Object IDs and vice versa.

.DESCRIPTION
The SidGuidConverter script includes two main functions:
Convert-AzureAdObjectIdToSid: Converts an Azure AD Object ID (GUID) to an Azure AD SID (Security Identifier).
Convert-SidToAzureAdObjectId: Converts an Azure AD SID back to an Object ID (GUID).

The script is designed to work specifically with Azure AD SIDs starting with 'S-1-12-1-'.

    Version:        1.0.0
    Author:         Robert Lohman
    Creation Date:  30.03.2025
    Updated:    
    Version history:
        1.0.0 - (30.03.2025) Script released

The script is provided "AS IS" with no warranties.
#>

#Variables

#Put your SID here
$sidTest = ""

#or Object ID here
$objectId = ""


function Convert-AzureAdObjectIdToSid {
    param(
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

function Convert-SidToAzureAdObjectId {
    param (
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

        # Create an empty byte array
        $bytes = New-Object byte[] 16

        # Convert each part to bytes and fill the byte array
        for ($i = 0; $i -lt 4; $i++) {
            $partBytes = [BitConverter]::GetBytes([UInt32]::Parse($parts[$i]))

            # Reverse byte order for each UInt32 (little-endian to big-endian)
            [Array]::Reverse($partBytes)

            # Copy into the byte array (4 bytes at a time)
            [Array]::Copy($partBytes, 0, $bytes, $i * 4, 4)
        }

        # Create GUID from the byte array
        $guid = New-Object Guid (,$bytes)
        return $guid.ToString()
    }
    catch {
        Write-Error "Failed to convert SID to Object ID. Verify that the SID is in the correct format and try again. Error message: $_"
    }
}

#conversion from Object ID to SID
if ($objectId -ne "") {
    $sid = Convert-AzureAdObjectIdToSid -ObjectID $objectId
    Write-Output "Object ID to SID: $sid"
} else {
    Write-Output "No Object ID provided, skipping conversion."
}

#conversion from SID to Object ID
if ($sidTest -ne "") {
    $objectIdTest = Convert-SidToAzureAdObjectId -SID $sidTest
    Write-Output "SID to Object ID: $objectIdTest"
} else {
    Write-Output "No SID provided, skipping conversion."
}
