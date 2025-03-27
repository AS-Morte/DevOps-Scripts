<#

Date:   27-3-2025
Auth:   A.S Morte
Ver:    1.1
Shell: PowerShell v5.1.2
Desc:   Calculates average cpu utilization for remote servers.
        Requires server.txt file as ref. Uses Jobs for parallel processing.

#>
param(
    [Parameter(Mandatory=$false)]
    [string]$ServersFile = "servers.txt",
    
    [Parameter(Mandatory=$false)]
    [int]$DurationMinutes = 10, # Minutes.
    
    [Parameter(Mandatory=$false)]
    [int]$SampleInterval = 5, # Seconds.
    
    [Parameter(Mandatory=$false)]
    [string]$ProcessName = "threatlockerservice"
)

# Check if servers file exists
if (-not (Test-Path $ServersFile)) {
    Write-Host "Error: Servers file '$ServersFile' not found." -ForegroundColor Red
    exit
}

# Read servers.txt from file
$Servers = Get-Content $ServersFile | Where-Object { $_ -ne "" }
if ($Servers.Count -eq 0) {
    Write-Host "Error: No servers found in '$ServersFile'." -ForegroundColor Red
    exit
}

Write-Host "Found $($Servers.Count) servers in file."

# Create script block for remote execution
$monitorScript = {
    param($DurationMins, $Interval, $Process)
    
    $processName = $Process
    $samples = ($DurationMins * 60) / $Interval
    $cpuValues = @()
    $serverName = $env:COMPUTERNAME
    
    for ($i = 0; $i -lt $samples; $i++) {
        try {
            $cpu = (Get-Counter "\Process($processName*)\% Processor Time" -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            if ($cpu -ne $null) {
                $cpuValues += $cpu
            }
        }
        catch {
            # Continue on error
        }
        
        if ($i -lt ($samples - 1)) {
            Start-Sleep -Seconds $Interval
        }
    }
    
    # Return only the statistics
    if ($cpuValues.Count -gt 0) {
        return @{
            ServerName = $serverName
            AverageCPU = ($cpuValues | Measure-Object -Average).Average
            MinCPU = ($cpuValues | Measure-Object -Minimum).Minimum
            MaxCPU = ($cpuValues | Measure-Object -Maximum).Maximum
            SamplesCollected = $cpuValues.Count
        }
    }
    else {
        return @{
            ServerName = $serverName
            Error = "No data collected or process not found"
        }
    }
}

# Start jobs for all servers
$jobs = @()
$jobServerMap = @{}

foreach ($server in $Servers) {
    Write-Host "Starting monitoring job for server: $server"
    $job = Invoke-Command -ComputerName $server -ScriptBlock $monitorScript -ArgumentList $DurationMinutes, $SampleInterval, $ProcessName -AsJob
    $jobs += $job
    $jobServerMap[$job.Id] = $server
}

Write-Host "Monitoring $ProcessName on $($Servers.Count) servers for $DurationMinutes minutes..."
Write-Host "Please wait for the results..."

# Wait for all jobs to complete
$jobs | Wait-Job | Out-Null

# Get and display results
$results = @()
foreach ($job in $jobs) {
    $jobResult = Receive-Job -Job $job
    
    # If job result doesn't have a valid ServerName, use the server name from our mapping
    if ([string]::IsNullOrEmpty($jobResult.ServerName)) {
        $jobResult.ServerName = $jobServerMap[$job.Id]
    }
    
    $results += $jobResult
}

# Display results in a table with proper formatting
$results | Select-Object ServerName, @{N='Avg CPU %';E={$_.AverageCPU.ToString("0.00")}}, @{N='Min CPU %';E={$_.MinCPU.ToString("0.00")}}, @{N='Max CPU %';E={$_.MaxCPU.ToString("0.00")}}, SamplesCollected, Error | Format-Table -AutoSize

# Clean up
$jobs | Remove-Job