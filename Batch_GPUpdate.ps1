<#

Date:   2-3-2025
Auth:   A.S Morte
Ver:    2
Shell: PowerShell v5.1.2
Desc:   Batch GP Update. Updates on 5 Servers at once.
        

#>

$computers = @(
    "Server-001",
    "Server-002"
)

# Results tracking
$results = @{
    Successful = @()
    Failed = @()
}

# Function to process a batch of computers
function Process-ComputerBatch {
    param (
        [array]$ComputerBatch
    )
    
    # Create jobs for each computer in the batch
    $jobs = @()
    foreach ($computer in $ComputerBatch) {
        $job = Start-Job -ScriptBlock {
            param ($computerName)
            try {
                $result = Invoke-Command -ComputerName $computerName -ScriptBlock { gpupdate /force } -ErrorAction Stop
                return @{
                    ComputerName = $computerName
                    Success = $true
                    Message = "Successfully ran gpupdate /force"
                }
            }
            catch {
                return @{
                    ComputerName = $computerName
                    Success = $false
                    Message = "Failed: $_"
                }
            }
        } -ArgumentList $computer
        
        $jobs += $job
    }
    
    # Wait for all jobs to complete
    $jobResults = $jobs | Wait-Job | Receive-Job
    
    # Process results
    foreach ($result in $jobResults) {
        if ($result.Success) {
            Write-Host "✓ $($result.ComputerName): $($result.Message)" -ForegroundColor Green
            $script:results.Successful += $result.ComputerName
        }
        else {
            Write-Host "✗ $($result.ComputerName): $($result.Message)" -ForegroundColor Red
            $script:results.Failed += $result.ComputerName
        }
    }
    
    # Clean up jobs
    $jobs | Remove-Job -Force
}

# Initialize counters
$total = $computers.Count
$processed = 0
$batchSize = 5

Write-Host "Starting gpupdate /force for $total computers (5 at a time)..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------" -ForegroundColor Cyan

# Process computers in batches of 5
for ($i = 0; $i -lt $computers.Count; $i += $batchSize) {
    # Get current batch (up to 5 computers)
    $batch = $computers[$i..([Math]::Min($i + $batchSize - 1, $computers.Count - 1))]
    
    # Display batch information
    $batchNum = [Math]::Floor($i / $batchSize) + 1
    $totalBatches = [Math]::Ceiling($computers.Count / $batchSize)
    Write-Host "`nProcessing Batch $batchNum of $totalBatches" -ForegroundColor Yellow
    
    # Process the batch
    Process-ComputerBatch -ComputerBatch $batch
    
    # Update progress
    $processed += $batch.Count
    Write-Progress -Activity "Running gpupdate /force" -Status "Processed $processed of $total" -PercentComplete (($processed / $total) * 100)
}

# Display final summary
Write-Host "`n======== GPUpdate Summary ========" -ForegroundColor Cyan
Write-Host "Total computers: $total" -ForegroundColor Cyan
Write-Host "Successful: $($results.Successful.Count)" -ForegroundColor Green
Write-Host "Failed: $($results.Failed.Count)" -ForegroundColor Red

# List failed computers if any
if ($results.Failed.Count -gt 0) {
    Write-Host "`nFailed Computers:" -ForegroundColor Red
    $results.Failed | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    
    # Option to retry failed computers
    $retry = Read-Host "`nDo you want to retry failed computers? (Y/N)"
    if ($retry -eq "Y" -or $retry -eq "y") {
        Write-Host "`nRetrying failed computers..." -ForegroundColor Yellow
        
        # Process failed computers in batches of 5
        for ($i = 0; $i -lt $results.Failed.Count; $i += $batchSize) {
            $retryBatch = $results.Failed[$i..([Math]::Min($i + $batchSize - 1, $results.Failed.Count - 1))]
            Write-Host "`nRetry Batch $([Math]::Floor($i / $batchSize) + 1) of $([Math]::Ceiling($results.Failed.Count / $batchSize))" -ForegroundColor Yellow
            Process-ComputerBatch -ComputerBatch $retryBatch
        }
        
        # Updated summary after retry
        Write-Host "`n======== Final GPUpdate Summary ========" -ForegroundColor Cyan
        Write-Host "Total computers: $total" -ForegroundColor Cyan
        Write-Host "Successful: $($results.Successful.Count)" -ForegroundColor Green
        Write-Host "Failed: $($results.Failed.Count)" -ForegroundColor Red
        
        if ($results.Failed.Count -gt 0) {
            Write-Host "`nComputers still failing:" -ForegroundColor Red
            $results.Failed | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        }
    }
}

Write-Host "`nGPUpdate process completed." -ForegroundColor Cyan