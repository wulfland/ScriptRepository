[CmdletBinding()]
Param (
    [Parameter(Mandatory=$true, Position=0)]
    $Account,

    [Parameter(Mandatory=$true, Position=1)]
    $Accesstoken
)

$passkey = ":$($Accesstoken)"
$encodedKey = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($passkey))
$token = "Basic $encodedKey"

$projectsResult = Invoke-RestMethod "https://$Account.visualstudio.com/_apis/projects?api-version=1.0" -Method Get  -Headers @{ Authorization = $token }

$releases = @()

$projectsResult.value | % {

    $project = $_.name

    $url = "https://$Account.vsrm.visualstudio.com/$project/_apis/release/releases?api-version=3.0-preview.2"

    $result = Invoke-RestMethod $url -Method Get -Headers @{ Authorization = $token }

    if ($result.count -gt 0){

        $result.value | % {
            
            $releases += [pscustomobject]@{ 
                Project = $project 
                Name = $_.Name 
                Status = $_.status
                CreatedOn = [datetime]$_.createdOn
                ModifiedOn = [datetime]$_.modifiedOn 
            }
        }
    }
}

$releases | Sort-Object -Property ModifiedOn -Descending | Format-Table -AutoSize