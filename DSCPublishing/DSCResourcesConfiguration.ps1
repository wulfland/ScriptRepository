<#
 # Ensure the current state of the DSC resource modules on the current server. 
 # This file is optimized for release management.
 # Use Ensure-DSCResources.ps1 to manually deploy the resources.
#>
Configuration DSCResourceConfiguration
{
    Node  $env:COMPUTERNAME
    {
        File DSCModules
        {
            SourcePath      = "$applicationPath\DSCResources"
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\Modules"
            Type            = "Directory"
            Recurse         = $true
            Ensure          = "Present"
        }
    }
}

DSCResourceConfiguration