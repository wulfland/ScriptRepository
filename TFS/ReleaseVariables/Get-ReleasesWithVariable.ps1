<#
.Synopsis
   Lists all releases with all environments that contain a specific variable.
.DESCRIPTION
   Iterates one or more ProjectCollections and lists all environments in all release definitions in all projects. If the environment contains a CertificateThumbprint it will be displayed as well. 
.EXAMPLE
   Get-ReleasesWithVariable https://<tfsserver>/tfs/<collection> MyVariable
.EXAMPLE
   Get-ReleasesWithVariable -ProjectCollections @("https://<tfsserver>m/tfs/<collection1>", "https://<tfsserver>m/tfs/<collection2>") -VariableName MyVariable -verbose
.EXAMPLE
   Get-ReleasesWithVariable -AccountName VSTSAccountName -AccessToken PAT -VariableName MyVariable
#>
[CmdletBinding(DefaultParameterSetName='TFS')]
Param
(
    # One or more URLs to project collections on your on premise TFS.
    [Parameter(Mandatory=$true, Position=0, ParameterSetName='TFS')]
    [string[]]
    $ProjectCollections,

    # The name of the VSTS account
    [Parameter(Mandatory=$true, Position=0, ParameterSetName='VSTS')]
    [string]
    $AccountName,

    # The private access token (PAT). See https://www.visualstudio.com/en-us/docs/setup-admin/team-services/use-personal-access-tokens-to-authenticate
    [Parameter(Mandatory=$true, Position=1, ParameterSetName='VSTS')]
    $Accesstoken,

    # The name of the variable to search for.
    [Parameter(Mandatory=$true, Position=1, ParameterSetName='TFS')]
    [Parameter(Mandatory=$true, Position=2, ParameterSetName='VSTS')]
    [ValidateNotNullOrEmpty()]
    [string]
    $VariableName    
)


if ($PSCmdlet.ParameterSetName -eq "TFS") 
{
    # TFS On Premise
    $apiVersion = "2.2-preview.1"
    $additionalParameters = @{ UseDefaultCredentials = $null }
}
else
{
    # VSTS
    $passkey = ":$($Accesstoken)"
    $encodedKey = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($passkey))
    $token = "Basic $encodedKey"
    $apiVersion = "3.0-preview.2"

    $ProjectCollections = "https://$AccountName.visualstudio.com"

    $additionalParameters = @{ Headers = @{ Authorization = $token } }
}
 
$releases = @()

$ProjectCollections | % {

    $projectCollection = $_
    Write-Verbose "Processing ProjectCollection '$projectCollection'..."

    $projectsResult = Invoke-RestMethod "$projectCollection/_apis/projects?`$top=1000&api-version=1.0" -Method Get @additionalParameters

    if ($PSCmdlet.ParameterSetName -eq "VSTS") 
    {
        $projectCollection = "https://$AccountName.vsrm.visualstudio.com"
    }

    $projectsResult.value | % {

        $project = $_.name

        Write-Host "Processing ProjectCollection '$project'..."

        $url = "$ProjectCollection/$project/_apis/release/definitions?`$expand=environments&api-version=$ApiVersion"

        $result = Invoke-RestMethod $url -Method Get @additionalParameters

        if ($result.count -gt 0){

            $result.value | % {

                $url = "$ProjectCollection/$project/_apis/release/definitions/$($_.id)?api-version=$ApiVersion"

                $definition = Invoke-RestMethod $url -Method Get @additionalParameters

                $name = $_.Name 

                $definition.environments | % {

                    if ($null -eq $_.variables.$VariableName)
                    {
                        Write-Verbose "Environment '$($_.Name)' does not contain a variable '$VariableName'."
                    }
                    else
                    {
                        $releases += [pscustomobject]@{ 
                            Collection = $ProjectCollection
                            Project = $project 
                            Name = $name 
                            Env = $_.Name
                            $VariableName = $_.variables.$VariableName.value
                        }
                    }
                }
            }
        }
    }
}   

$releases | Sort-Object -Property Collection,Project | Format-Table -AutoSize