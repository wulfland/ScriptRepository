# Get-ReleasesWithVariables
## Synopsis
   Lists all releases with all environments that contain a specific variable.
## DESCRIPTION
   Iterates one or more ProjectCollections and lists all environments in all release definitions in all projects. If the environment contains a CertificateThumbprint it will be displayed as well. 
## EXAMPLE
   Get-ReleasesWithVariable https://<tfsserver>/tfs/<collection> MyVariable
## EXAMPLE
   Get-ReleasesWithVariable -ProjectCollections @("https://<tfsserver>m/tfs/<collection1>", "https://<tfsserver>m/tfs/<collection2>") -VariableName MyVariable -verbose
## EXAMPLE
   Get-ReleasesWithVariable -AccountName VSTSAccountName -AccessToken PAT -VariableName MyVariable

# Update-ReleaseVariables
## Synopsis
   Updates a variable with a given value in all release definitions.
## DESCRIPTION
   If you have specific values (like server names or certificate thumbprints) in a lot of release definitions, you may need to update them at once.
   The script iterates all projects and checks for a value and replaces it. 

   Use -whatif to test without updating the values.
## EXAMPLE
   Update-ReleaseVariables.ps1 -AccountName <vstsaccountname> -Accesstoken <PAT token> -VariableName <name of variable> -OldValues <value to look for> -NewValues <new value to set> -Verbose -WhatIf
## EXAMPLE
   Update-ReleaseVariables.ps1 -AccountName <vstsaccountname> -Accesstoken <PAT token> -VariableName <name of variable> -OldValues @("old1", "old2") -NewValues @("new1", "new2") -Verbose -WhatIf  