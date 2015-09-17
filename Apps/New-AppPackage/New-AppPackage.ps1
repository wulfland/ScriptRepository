<#
.Synopsis
   Script that copies the app package to the drop folder.
.DESCRIPTION
   This script van be used in a TFS build definition to ensure that an app is created and published to the build folder.
   You must use the script together with the build parameters /p:IsPackaging=True
.EXAMPLE
   New-AppPackage -SourceDirectory $Env:TF_BUILD_SOURCESDIRECTORY -BinariesDirectory $Env:TF_BUILD_BINARIESDIRECTORY
#>
function New-AppPackage
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        # The source directory
        [Parameter(Mandatory=$false, Position=0)]
        [string]$SourceDirectory = $Env:TF_BUILD_SOURCESDIRECTORY,

        #The binaries directory
        [Parameter(Mandatory=$false, Position=1)]
        [string]$BinariesDirectory = $Env:TF_BUILD_BINARIESDIRECTORY
    )

    Begin
    {
        if (-not (Test-Path $SourceDirectory)) {
            throw "The directory '$SourceDirectory' does not exist."
        }

        if (-not (Test-Path $BinariesDirectory)) {
            md $BinariesDirectory
            Write-Warning "The directory '$BinariesDirectory' did not exist and was created."
        }
    }
    Process
    {
        # Specify file types to include    
        $FileTypes = $("*.app")

        # Specify the sub-folders to include
        $SourceSubFolders = $("*app.publish*")

        # Find the files
        $files = gci $SourceDirectory -recurse -include $SourceSubFolders | 
        ?{ $_.PSIsContainer } | 
        foreach { gci -Path $_.FullName -Recurse -include $FileTypes }

        if($files)
        {
            Write-Verbose "Found $files.count files:"

            foreach ($file in $files) {
                Write-Verbose $file.FullName 
                Copy-Item $file $BinariesDirectory
            }
        }
        else
        {
            Write-Warning "Found no files."
        }
    }
    End
    {
        return 0
    }
}
