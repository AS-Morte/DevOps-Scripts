<#

Date:   2-3-2025
Auth:   A.S Morte
Ver:    2
Shell: PowerShell v5.1.2
Desc:   Batch GP Update. Updates on 5 Servers at once.
        Execute as: .\get_server_shutdown.ps1 -ComputerName Server-01

#>

param(
    [Parameter(Mandatory=$false)]
    [string]$ComputerName = $env:COMPUTERNAME
)

# Output header with target computer information
Write-Output "Analyzing shutdown events for computer: $ComputerName"
Write-Output "=================================================="

# Find the last shutdown event
$shutdownEvents = Get-WinEvent -FilterHashtable @{
    LogName = 'System'
    Id = 1074, 6006, 6008, 41, 1076
} -MaxEvents 50 -ErrorAction SilentlyContinue -ComputerName $ComputerName

$lastShutdownEvent = $null

foreach ($event in $shutdownEvents) {
    # Event ID 1074: Normal shutdown initiated by user or application
    # Event ID 6006: Clean shutdown
    # Event ID 6008: Unexpected shutdown
    # Event ID 41: System rebooted without clean shutdown
    # Event ID 1076: Unexpected shutdown usually due to BSOD
    
    if ($event.Id -eq 1074) {
        $lastShutdownEvent = $event
        $message = $event.Message
        $time = $event.TimeCreated
        $user = $message -replace '.*User:\s*\\?(\S+).*', '$1'
        $reason = $message -replace '.*Reason:\s*([^\.]+).*', '$1'
        $processName = $message -replace '.*Process:\s*([^\s]+).*', '$1'
        
        Write-Output "=========================="
        Write-Output "Last shutdown detected at: $shutdownTime"
        Write-Output "Type: Normal shutdown/restart"
        Write-Output "Initiated by user: $user"
        Write-Output "Reason: $reason"
        Write-Output "Process: $processName"
        Write-Output "Full message: $message"
        break
    }
    elseif ($event.Id -eq 6008 -and $lastShutdownEvent -eq $null) {
        $lastShutdownEvent = $event
        $shutdownTime = $event.TimeCreated
        
        Write-Output "=========================="
        Write-Output "Last shutdown detected at: $shutdownTime"
        Write-Output "Type: Unexpected/Dirty shutdown"
        Write-Output "Reason: The system was not properly shut down"
        Write-Output "Full message: $($event.Message)"
        break
    }
    elseif ($event.Id -eq 41 -and $lastShutdownEvent -eq $null) {
        $lastShutdownEvent = $event
        $shutdownTime = $event.TimeCreated
        
        Write-Output "=========================="
        Write-Output "Last shutdown detected at: $shutdownTime"
        Write-Output "Type: System crash / power failure"
        Write-Output "Reason: The system has rebooted without cleanly shutting down first"
        Write-Output "Full message: $($event.Message)"
        break
    }
    elseif ($event.Id -eq 1076 -and $lastShutdownEvent -eq $null) {
        $lastShutdownEvent = $event
        $shutdownTime = $event.TimeCreated
        
        Write-Output "=========================="
        Write-Output "Last shutdown detected at: $shutdownTime"
        Write-Output "Type: BSOD / System crash"
        Write-Output "Reason: The system has been shut down due to a serious error"
        Write-Output "Full message: $($event.Message)"
        break
    }
}

if ($lastShutdownEvent -eq $null) {
    Write-Output "No shutdown events found in the event log."
    
    # Try checking for more generic restart events
    $restartEvents = Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        Id = 6005, 6013
    } -MaxEvents 10 -ErrorAction SilentlyContinue -ComputerName $ComputerName
    
    if ($restartEvents -and $restartEvents.Count -gt 0) {
        $lastRestartEvent = $restartEvents[0]
        $time = $lastRestartEvent.TimeCreated
        Write-Output "Found system start event at: $shutdownTime"
        Write-Output "The system was started, but the reason for the previous shutdown couldn't be determined."
    } else {
        Write-Output "No system restart events found either. Event logs may have been cleared."
        Exit
    }
}
