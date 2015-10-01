<#
.Synopsis
   Backup an existing Database
.DESCRIPTION
   Moves or copies all the content of a website to a backup folder.
.EXAMPLE
   Backup-Website -WebsiteName LSK.Portal
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
    $BackupPath = "C:\Deployment\Backup\",

    [switch]
    $Clean
)

Begin
{
    $BackupFolder = Join-Path $BackupPath $WebSiteName
    $WebSiteFullName = Join-Path $WebSitePath $WebSiteName

    if (-not (Test-Path $WebSiteFullName))
    {
        $message = "Website '$WebSiteFullName' does not exist."
        $exception = New-Object InvalidOperationException $message
        $errorID = 'FolderNotFound'
        $errorCategory = [Management.Automation.ErrorCategory]::InvalidArgument
        $target = $WebSiteName
        $errorRecord = New-Object Management.Automation.ErrorRecord $exception, $errorID, $errorCategory, $target
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    if (Test-Path $BackupFolder)
    {
        Write-Verbose "Cleaning up old backup in '$BackupFolder'..."
        Remove-Item $BackupFolder -Force -Recurse
        Write-Verbose "Done."
    }

    Write-Verbose "Create backup folder '$BackupFolder'..."
    md $BackupFolder | Out-Null
    Write-Verbose "Done."
}

Process
{
    Write-Verbose "Backup site '$WebSiteFullName' to backup location '$BackupFolder'..."
    Get-ChildItem -Path $WebSiteFullName | % {  
        if ($Clean.IsPresent)
        {
            Write-Verbose "Move '$_.FullName'..."
            Move-Item $_.FullName "$BackupFolder" -Force
        }
        else
        {
            Write-Verbose "Copy '$_.FullName'..."
            Copy-Item $_.FullName "$BackupFolder" -Force -Recurse
        }  

        Write-Verbose "Done."
    }
}

End
{
}