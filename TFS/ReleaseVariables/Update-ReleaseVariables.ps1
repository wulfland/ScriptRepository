<#
.Synopsis
   Updates a variable with a given value in all release definitions.
.DESCRIPTION
   If you have specific values (like server names or certificate thumbprints) in a lot of release definitions, you may need to update them at once.
   The script iterates all projects and checks for a value and replaces it. 

   Use -whatif to test without updating the values.
.EXAMPLE
   Update-ReleaseVariables.ps1 -AccountName <vstsaccountname> -Accesstoken <PAT token> -VariableName <name of variable> -OldValues <value to look for> -NewValues <new value to set> -Verbose -WhatIf
.EXAMPLE
   Update-ReleaseVariables.ps1 -AccountName <vstsaccountname> -Accesstoken <PAT token> -VariableName <name of variable> -OldValues @("old1", "old2") -NewValues @("new1", "new2") -Verbose -WhatIf  
#>
[CmdletBinding(SupportsShouldProcess=$true)]
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
    $VariableName,   

    # The old values for the variable
    [Parameter(Mandatory=$true, Position=2, ParameterSetName='TFS')]
    [Parameter(Mandatory=$true, Position=3, ParameterSetName='VSTS')]
    [string[]]
    $OldValues,

    # The new values for the variable
    [Parameter(Mandatory=$true, Position=3, ParameterSetName='TFS')]
    [Parameter(Mandatory=$true, Position=4, ParameterSetName='VSTS')]
    [string[]]
    $NewValues
)

if ($OldValues.Count -ne $NewValues.Count){
        throw "You must supply the same number for old and new values."
}

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

function Update-EnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        # The url to the project (i.e. https://tfs.hugoboss.com/tfs/HBCollaboration/VisitorManagement)
        [Parameter(Mandatory=$true, Position=0)]
        [string]
        $ProjectUrl,

        # The id of the build definition (i.e. 1)
        [Parameter(Mandatory=$true, Position=1)]
        [int]
        $DefinitionId,

        # The id of the environment (i.e. 2)
        [Parameter(Mandatory=$true, Position=2)]
        [int]
        $EnvironmentId,

        # The name of the variable to update (i.e. CertificateThumbprint)
        [Parameter(Mandatory=$true, Position=3)]
        [string]
        $VariableName,

        # The new value for the variable
        [Parameter(Mandatory=$true, Position=4)]
        [string]
        $VariableValue,

        $additionalParameters
    )

    $url = "$ProjectUrl/_apis/release/definitions/$($DefinitionId)?api-version=$ApiVersion"

    $definition = Invoke-RestMethod $url -Method Get @additionalParameters

    $env = $definition.environments | ? { $_.id -eq $EnvironmentId }

    $currentValue = $env.variables.$VariableName.value

    $env.variables.$VariableName.value = $VariableValue

    Write-Verbose "Change value of '$VariableName' in environment '$($env.name)' from '$currentValue' to '$VariableValue'."

    $url = "$ProjectUrl/_apis/release/definitions/$($DefinitionId)?api-version=$ApiVersion"

    $body = ConvertTo-Json -InputObject $definition -Depth 100 -Compress

    if ($pscmdlet.ShouldProcess("$url", "Update"))
    {
        $result = Invoke-RestMethod $url -Method Put -Body $body -ContentType "application/json" @additionalParameters
        Write-Verbose "Updated '$url' to revision '$($result.revision)"
    }
}

   
$ProjectCollections | % {

    $projectCollection = $_
    Write-Verbose "Processing ProjectCollection '$projectCollection'..."

    $projectsResult = Invoke-RestMethod "$projectCollection/_apis/projects?`$top=1000api-version=1.0" -Method Get @additionalParameters

    if ($PSCmdlet.ParameterSetName -eq "VSTS") 
    {
        $projectCollection = "https://$AccountName.vsrm.visualstudio.com"
    }

    $projectsResult.value | % {

        $project = $_.name

        Write-Verbose "Processing project '$project'..."

        $url = "$ProjectCollection/$project/_apis/release/definitions?`$expand=environments&api-version=$ApiVersion"

        $result = Invoke-RestMethod $url -Method Get @additionalParameters

        if ($result.count -gt 0){

            $result.value | % {

                $url = "$ProjectCollection/$project/_apis/release/definitions/$($_.id)?api-version=$ApiVersion"

                $definition = Invoke-RestMethod $url -Method Get @additionalParameters

                $definitionName = $_.Name 
                $definitionId = $_.Id 

                $definition.environments | % {

                    $environmentId = $_.id
                    $environmentName = $_.Name

                    Write-Verbose "Process environment '$environmentName' ($environmentId) in definition '$definitionName' ($definitionId)..."
                    
                    $oldValue = $_.variables.$VariableName.value

                    if ($OldValues.Contains($oldValue)){
                        
                        $newValue = $NewValues[$OldValues.IndexOf($oldValue)]

                        Write-Verbose "Found old value '$oldValue' in environemnt. Replace it with '$newValue'"

                        Update-EnvironmentVariable -ProjectUrl "$ProjectCollection/$project" -DefinitionId $definitionId -EnvironmentId $environmentId -VariableName $VariableName -VariableValue $newValue -additionalParameters $additionalParameters

                        $releases += [pscustomobject]@{ 
                            Collection = $ProjectCollection
                            Project = $project 
                            Name = $definitionName 
                            Env = $_.Name
                            Match = $oldValue
                            Replacement = $newValue
                        }
                    
                    }
                    else
                    {
                        Write-Verbose "No matching value found in environment."
                    }
                }
            }
        }
    }
} 

$releases | Sort-Object -Property Collection,Project -Descending | Format-Table -AutoSize