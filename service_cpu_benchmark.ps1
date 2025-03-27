<#

Date:   27-3-2025
Auth:   A.S Morte
Ver:    1.1
Shell: PowerShell v5.1.2
Desc:   Calculates average cpu utilization for .exe
        For Windows based systems

#>

# Script to monitor <service>.exe CPU usage for 10 minutes
$processName = "explorer"
$totalMinutes = 10 # Run for total minutes
$interval = 5  # Sample every X seconds
$samples = ($totalMinutes * 60) / $interval  # Calculate total samples needed
$cpuValues = @()

Write-Host "Monitoring $processName.exe for $totalMinutes minutes..."
Write-Host "Press Ctrl+C to stop early if needed"

# Take samples
for ($i = 0; $i -lt $samples; $i++) {
    $currentSecond = $i * $interval
    $elapsedMinutes = [Math]::Floor($currentSecond / 60)
    $remainingSeconds = $currentSecond % 60
    
    $cpu = (Get-Counter "\Process($processName*)\% Processor Time").CounterSamples.CookedValue
    $cpuValues += $cpu
    
    Write-Host "Time $elapsedMinutes`:$($remainingSeconds.ToString("00")) - CPU: $($cpu.ToString("0.00"))%"
    
    if ($i -lt ($samples - 1)) {
        Start-Sleep -Seconds $interval
    }
}

# Calculate average and other statistics
$avgCPU = ($cpuValues | Measure-Object -Average).Average
$minCPU = ($cpuValues | Measure-Object -Minimum).Minimum
$maxCPU = ($cpuValues | Measure-Object -Maximum).Maximum

# Output results
Write-Host "`nResults after $totalMinutes minutes of monitoring:"
Write-Host "------------------------------------------"
Write-Host "Average CPU usage: $($avgCPU.ToString("0.00"))%"
Write-Host "Minimum CPU: $($minCPU.ToString("0.00"))%"
Write-Host "Maximum CPU: $($maxCPU.ToString("0.00"))%"