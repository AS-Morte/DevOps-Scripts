# PowerShell script to query services that are stuck, crashed, or in unexpected states
param(
    [Parameter(Mandatory=$true)]
    [string]$ComputerName
)

Write-Host "Checking for problematic services on $ComputerName..." -ForegroundColor Cyan
Write-Host "----------------------------------------`n"

# Get services that should be running but are stopped (potential crashes)
Write-Host "SERVICES THAT SHOULD BE RUNNING BUT ARE STOPPED:" -ForegroundColor Yellow
Get-Service -ComputerName $ComputerName | 
    Where-Object {$_.StartType -eq 'Automatic' -and $_.Status -ne 'Running'} |
    Select-Object Name, DisplayName, Status, StartType |
    Format-Table -AutoSize

# Get services in "Starting" state (potentially stuck)
Write-Host "`nSERVICES STUCK IN STARTING STATE:" -ForegroundColor Yellow
Get-Service -ComputerName $ComputerName | 
    Where-Object {$_.Status -eq 'StartPending'} |
    Select-Object Name, DisplayName, Status |
    Format-Table -AutoSize

# Get services in "Stopping" state (potentially stuck)
Write-Host "`nSERVICES STUCK IN STOPPING STATE:" -ForegroundColor Yellow
Get-Service -ComputerName $ComputerName | 
    Where-Object {$_.Status -eq 'StopPending'} |
    Select-Object Name, DisplayName, Status |
    Format-Table -AutoSize

# Get services that have crashed (Windows services with non-zero exit codes)
Write-Host "`nSERVICES WITH NON-ZERO EXIT CODES (POTENTIAL CRASHES):" -ForegroundColor Yellow
Try {
    $CrashedServices = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        Get-WmiObject Win32_Service | 
        Where-Object {$_.ExitCode -ne 0 -and $_.ExitCode -ne $null} |
        Select-Object Name, DisplayName, State, ExitCode
    }
    $CrashedServices | Format-Table -AutoSize
}
Catch {
    Write-Host "Unable to retrieve service exit codes: $_" -ForegroundColor Red
}