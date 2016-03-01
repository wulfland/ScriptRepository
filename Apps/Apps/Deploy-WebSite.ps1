[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$RootFolder,

    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$DeployScript
)


Write-Verbose "Look for batch '$DeployScript' in '$RootFolder'..."

$files = Get-ChildItem -Path $RootFolder -Recurse -Filter $DeployScript

if (-not ($files)) { throw "'$DeployScript' could not be found in '$RootFolder'."}

if ($files.Count -gt 1) { throw "Found more then one deployment script." }

$file = $files[0]

Write-Verbose "Execute '$($file.FullName) /Y /M:https://$($env:WebDeploySiteName).scm.azurewebsites.net:443/msdeploy.axd /u:$($env:AzureUserName) /p:$($env:AzurePassword) /a:Basic'..."

& $file /Y /M:https://$($env:WebDeploySiteName).scm.azurewebsites.net:443/msdeploy.axd /u:$($env:AzureUserName) /p:$($env:AzurePassword) /a:Basic


Write-Verbose "Done."

