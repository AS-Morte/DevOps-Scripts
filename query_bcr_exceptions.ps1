# Array of computer names
$computers = @(
    "XAPP-504",
    "XAPP-505",
    "XAPP-506",
    "XAPP-507",
    "XAPP-508",
    "XAPP-509",
    "XAPP-510",
    "XAPP-511"
)

# Function to query registry remotely
function Get-RemoteRegistryValue {
    param (
        [string]$ComputerName
    )

    try {
        # Attempt to connect to the remote computer
        $registryValue = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            try {
                # Get the registry key value for the local machine
                $value = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Citrix\HDXMediaStream" -Name WebBrowserRedirectionBlacklist -ErrorAction Stop).WebBrowserRedirectionBlacklist
                return $value
            }
            catch {
                return "Registry key not found"
            }
        } -ErrorAction Stop

        return $registryValue
    }
    catch {
        return "Machine not found or inaccessible"
    }
}

# Create an array to store results
$results = @()

# Iterate through computers and query registry
foreach ($computer in $computers) {
    $registryValue = Get-RemoteRegistryValue -ComputerName $computer
    
    $results += [PSCustomObject]@{
        Server = $computer
        WebBrowserRedirectionBlacklist = $registryValue
    }
}

# Display results in a table
$results | Format-Table -AutoSize