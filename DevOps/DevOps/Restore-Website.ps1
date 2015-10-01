<#
.Synopsis
   Restores a website.
.DESCRIPTION
   Restores a website to its original location.
.EXAMPLE
   Restore-Website -WebsiteName LSK.Portal
#>
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true, Position=0, ValueFromPipelineByPropertyName=$true)]
    [string]
    $WebSiteName,

    [string]
    $WebSitePath = "C:\inetpub\wwwroot\",

    [string]
    $BackupPath = "C:\Deployment\Backup\"
)

Begin
{
    $BackupFolder = Join-Path $BackupPath $WebSiteName
    $WebSiteFullName = Join-Path $WebSitePath $WebSiteName

    if (-not (Test-Path $BackupFolder))
    {
        $message = "Backup '$BackupFolder' does not exist."
        $exception = New-Object InvalidOperationException $message
        $errorID = 'FolderNotFound'
        $errorCategory = [Management.Automation.ErrorCategory]::InvalidArgument
        $target = $BackupFolder
        $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $target
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    if (-not (Test-Path $WebSiteFullName))
    {
        Write-Verbose "Create folder '$WebSiteFullName'..."
        md $WebSiteFullName | Out-Null
        Write-Verbose "Done."
    }
}

Process
{
    Write-Verbose "Moving web site '$WebsiteName' from backup location '$BackupFolder' to '$WebSiteFullName'..."
    Get-ChildItem -Path $BackupFolder | % {  
        Write-Verbose "Copy '$_.FullName'..."
        Copy-Item $_.FullName "$WebSiteFullName" -Force -Recurse 

        Write-Verbose "Done."
    }
}

End
{
}