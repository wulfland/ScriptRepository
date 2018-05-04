<#
.Synopsis
   Set the permissions for a git repository to enforce naming policies
.DESCRIPTION
   This script sets the permission of a git repository. It denys to create branches in the root and only allows the creation of branches in specific folders.
.EXAMPLE
   Set-RepositoryPermission.ps1 -AccountOrCollection https://tfs.contoso.com/tfs/DefaultCollection -ProjectName MyProject -Repository MyProject -Verbose 
.EXAMPLE
   Set-RepositoryPermission.ps1 -AccountOrCollection https://constoso.visualstudio.com -ProjectName MyProject -Repository MyProject -Verbose 
.EXAMPLE
   Set-RepositoryPermission.ps1 -AccountOrCollection https://constoso.visualstudio.com -ProjectName MyProject -Repository MyProject -AllowedFolders @("features", "users")
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param
(
    # Your VSTS account or TFS project collection url
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidatePattern("http://.*|https://.*")]
    [string]
    $AccountOrCollection,

    # The name of the project that contains your repository
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ProjectName,

    # The name of the repository
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Repository,

    # The list of folders where contributors can create branches in (default: features, bufixes, users)
    [Parameter(Mandatory=$false)]
    [string[]]
    $AllowedFolders = @("features", "bugfixes", "users"),

    # The list of folders where contributors can create branches in (default: features, bufixes, users, releases, master)
    [Parameter(Mandatory=$false)]
    [string[]]
    $AdminAllowedFolders = @("features", "bugfixes", "users", "releases", "master"),

    # The path where tf.exe is installed (default: Visual Studio 2017 location 'C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer').
    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -PathType Container $_ })]
    [string]
    $PathToTfExe = "C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer"
)

pushd $PathToTfExe


# block the Create Branch permission at the repository root for the project's contributors
Write-Verbose "Deny the 'CreateBranch' permission to the group '[$ProjectName]\Contributors' in repository '$Repository' ($AccountOrCollection)."
if ($pscmdlet.ShouldProcess("$Repository", "Deny CreateBranch"))
{
    & .\tf.exe git permission /deny:CreateBranch /group:[$ProjectName]\Contributors /collection:$AccountOrCollection /teamproject:$ProjectName /repository:$Repository
}

# block the Create Branch permission at the repository root for the project's admins
Write-Verbose "Deny the 'CreateBranch' permission to the group '[$ProjectName]\Project Administrators' in repository '$Repository' ($AccountOrCollection)."
if ($pscmdlet.ShouldProcess("$Repository", "Deny CreateBranch"))
{
    & .\tf.exe git permission /deny:CreateBranch /group:"[$ProjectName]\Project Administrators" /collection:$AccountOrCollection /teamproject:$ProjectName /repository:$Repository
}

# Allow contributors to create branches under configured folders
$AllowedFolders | ForEach-Object {
    
    Write-Verbose "Allow the 'CreateBranch' permission to the group '[$ProjectName]\Contributors' for folder '$_' in repository '$Repository' ($AccountOrCollection)."
    if ($pscmdlet.ShouldProcess("$Repository/$_", "Allow CreateBranch"))
    {
        & .\tf.exe git permission /allow:CreateBranch /group:[$ProjectName]\Contributors /collection:$AccountOrCollection /teamproject:$ProjectName /repository:$Repository /branch:$_
    }
}

# Allow admins to create branches under configured folders
$AdminAllowedFolders | ForEach-Object {
    
    Write-Verbose "Allow the 'CreateBranch' permission to the group '[$ProjectName]\Project Administrators' for folder '$_' in repository '$Repository' ($AccountOrCollection)."
    if ($pscmdlet.ShouldProcess("$Repository/$_", "Allow CreateBranch"))
    {
        & .\tf.exe git permission /allow:CreateBranch /group:"[$ProjectName]\Project Administrators" /collection:$AccountOrCollection /teamproject:$ProjectName /repository:$Repository /branch:$_
    }
}

popd 


