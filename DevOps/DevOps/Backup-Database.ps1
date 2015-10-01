<#
.Synopsis
   Backup Database
.DESCRIPTION
   make a full backup of a given database
.EXAMPLE
   Backup-Database LSK -ServerInstance lissval-t02
.EXAMPLE
#>
[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    [string]
    $DataBaseName,

    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=1)]
    [string]
    $ServerInstance
)

Begin
{
}
Process
{
    Backup-SqlDatabase $DataBaseName -ServerInstance $ServerInstance
}
End
{
}