[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$RootFolder,

    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$FileName
)


function Replace-Tokens
{
    [CmdletBinding()]
    Param
    (
        # Hilfebeschreibung zu Param1
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ValueFromPipeline=$true, Position=0)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path $_ })]
        [string]$FileFullName
    )
    
    Write-Verbose "Replace tokens in '$FileFullName'..."
 
    # get the environment variables
    $vars = Get-ChildItem -Path env:*
 
    # read in the setParameters file
    $contents = Get-Content -Path $FileFullName
 
    # perform a regex replacement
    $newContents = "";
    $contents | ForEach-Object {

        $line = $_
        if ($_ -match "__(\w+)__") {
            $setting = $vars | Where-Object { $_.Name -eq $Matches[1]  }

            if ($setting) {
                Write-Verbose "Replacing key '$($setting.Name)' with value '$($setting.Value)' from environment"
                $line = $_ -replace "__(\w+)__", $setting.Value
            }
        }

        $newContents += $line + [Environment]::NewLine
    }
 
    Write-Verbose -Verbose "Save content to '$FileFullName'."
    Set-Content $FileFullName -Value $newContents

    Write-Verbose "Done"
}

Write-Verbose "Look for file '$FileName' in '$RootFolder'..."

$files = Get-ChildItem -Path $RootFolder -Recurse -Filter $FileName

Write-Verbose "Found $($files.Count) files."

$files | ForEach-Object { Replace-Tokens -FileFullName $_.FullName }

Write-Verbose "All files processed."

