<#

Date:   April-14-2025
Auth:   A.S Morte
Ver:    1
Shell: PowerShell v5.1.2
Desc:   Get all file share hosted on a windows machine
        

#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName
)

function Get-FileShares {
    param(
        [Parameter(Mandatory=$false)]
        [string]$RemoteComputer
    )
    
    if ($RemoteComputer) {
        Write-Host "Getting file shares from remote computer: $RemoteComputer"
        try {
            # Try using Get-SmbShare for modern systems
            $shares = Invoke-Command -ComputerName $RemoteComputer -ScriptBlock {
                Get-SmbShare | Select-Object Name, Path, Description
            } -ErrorAction Stop
        }
        catch {
            # Fallback to WMI if Get-SmbShare fails
            Write-Host "Falling back to WMI method for remote computer"
            $shares = Get-WmiObject -Class Win32_Share -ComputerName $RemoteComputer |
                Select-Object Name, Path, Description
        }
    }
    else {
        Write-Host "Getting file shares from local computer"
        try {
            # Try using Get-SmbShare for modern systems
            $shares = Get-SmbShare | Select-Object Name, Path, Description
        }
        catch {
            # Fallback to WMI if Get-SmbShare fails
            Write-Host "Falling back to WMI method for local computer"
            $shares = Get-WmiObject -Class Win32_Share |
                Select-Object Name, Path, Description
        }
    }
    
    return $shares
}

# Execute the function with the provided parameter
if ($ComputerName) {
    Get-FileShares -RemoteComputer $ComputerName
}
else {
    Get-FileShares
}