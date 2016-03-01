<#
 # Script to run the "DSCResourcesConfiguration.ps1" and start the DSC-Configuration.
 # Note: run this script in the root of the git repository (i.e. \Source\Repos\SPAdministration\DSCResources).
#>
$applicationPath = Resolve-Path .

. .\DSCResourcesConfiguration.ps1

Start-DscConfiguration DSCResourceConfiguration -Wait -Force -Verbose