<#

Date:   27-3-2025
Auth:   A.S Morte
Ver:    1.2
Shell: PowerShell v5.1.2
Desc:   Calculates average cpu utilization for .exe with support for multiple instances
        For Windows based systems

#>

# Script to monitor <service>.exe CPU usage for 10 minutes
$processName = "brave"
$totalMinutes = 10 # Run for total minutes
$interval = 5  # Sample every X seconds
$samples = ($totalMinutes * 60) / $interval  # Calculate total samples needed
$processStats = @{}

Write-Host "Monitoring $processName.exe instances for $totalMinutes minutes..."
Write-Host "Press Ctrl+C to stop early if needed"

# Take samples
for ($i = 0; $i -lt $samples; $i++) {
    $currentSecond = $i * $interval
    $elapsedMinutes = [Math]::Floor($currentSecond / 60)
    $remainingSeconds = $currentSecond % 60
    
    # Get all instances of the process
    $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
    
    # If no processes found, show message
    if ($processes.Count -eq 0) {
        Write-Host "Time $elapsedMinutes`:$($remainingSeconds.ToString("00")) - No $processName processes found."
        if ($i -lt ($samples - 1)) {
            Start-Sleep -Seconds $interval
        }
        continue
    }
    
    # Process each instance
    foreach ($process in $processes) {
        $id = $process.Id
        $cpu = 0
        
        # Try to get accurate CPU usage using Get-Counter
        try {
            $instanceName = ($process.Name + "#" + $id)
            $counterPath = "\Process($instanceName)\% Processor Time"
            $counterData = Get-Counter -Counter $counterPath -ErrorAction SilentlyContinue
            if ($counterData) {
                $cpu = $counterData.CounterSamples.CookedValue
            }
        }
        catch {
            # Fallback to less precise CPU calculation
            $cpu = $process.CPU
        }
        
        # Add to stats dictionary for each process ID
        if (-not $processStats.ContainsKey($id)) {
            $processStats[$id] = @{
                "Name" = $process.Name
                "CPUValues" = @()
                "CommandLine" = (Get-WmiObject Win32_Process -Filter "ProcessId = '$id'").CommandLine
            }
        }
        
        $processStats[$id].CPUValues += $cpu
        
        Write-Host "Time $elapsedMinutes`:$($remainingSeconds.ToString("00")) - Process ID: $id - CPU: $($cpu.ToString("0.00"))%"
    }
    
    if ($i -lt ($samples - 1)) {
        Start-Sleep -Seconds $interval
    }
}

# Output results
Write-Host "`nResults after $totalMinutes minutes of monitoring:"
Write-Host "------------------------------------------"

foreach ($id in $processStats.Keys) {
    $cpuValues = $processStats[$id].CPUValues
    
    if ($cpuValues.Count -eq 0) {
        continue
    }
    
    $avgCPU = ($cpuValues | Measure-Object -Average).Average
    $minCPU = ($cpuValues | Measure-Object -Minimum).Minimum
    $maxCPU = ($cpuValues | Measure-Object -Maximum).Maximum
    $command = $processStats[$id].CommandLine
    
    # Truncate command line if too long
    if ($command.Length -gt 60) {
        $command = $command.Substring(0, 57) + "..."
    }
    
    Write-Host "Process ID: $id"
    Write-Host "Command: $command"
    Write-Host "Average CPU usage: $($avgCPU.ToString("0.00"))%"
    Write-Host "Minimum CPU: $($minCPU.ToString("0.00"))%"
    Write-Host "Maximum CPU: $($maxCPU.ToString("0.00"))%"
    Write-Host "------------------------------------------"
}

# Calculate overall statistics
$allCPUValues = @()
foreach ($id in $processStats.Keys) {
    $allCPUValues += $processStats[$id].CPUValues
}

if ($allCPUValues.Count -gt 0) {
    $overallAvg = ($allCPUValues | Measure-Object -Average).Average
    $overallMin = ($allCPUValues | Measure-Object -Minimum).Minimum
    $overallMax = ($allCPUValues | Measure-Object -Maximum).Maximum
    
    Write-Host "`nOverall Statistics for all $processName processes:"
    Write-Host "Average CPU usage: $($overallAvg.ToString("0.00"))%"
    Write-Host "Minimum CPU: $($overallMin.ToString("0.00"))%"
    Write-Host "Maximum CPU: $($overallMax.ToString("0.00"))%"
}