# Specify file types to exclude    
$FileTypes = $("*.log","*.proj","*.vsprops")

$SourceDir = "$($Env:TF_BUILD_SOURCESDIRECTORY.TrimEnd('\'))\DSCResources"

# Find the files
$files = gci $SourceDir -Recurse -Exclude $FileTypes

if($files)
{
    Write-Verbose "Found $files.count files:"

    foreach ($file in $files) {
        Write-Verbose $file.FullName 
    }
}
else
{
    Write-Warning "Found no files."
}

# If binary output directory exists, make sure it is empty
# If it does not exist, create one
# (this happens when 'Clean workspace' build process parameter is set to True)
if ([IO.Directory]::Exists($Env:TF_BUILD_BINARIESDIRECTORY)) 
{ 
    $DeletePath = $Env:TF_BUILD_BINARIESDIRECTORY + "\*"
    Write-Verbose "$Env:TF_BUILD_BINARIESDIRECTORY exists."
    if(-not $Disable)
    {
        Write-Verbose "Ready to delete $DeletePath"
        Remove-Item $DeletePath -recurse
        Write-Verbose "Files deleted."
    }    
} 
else
{ 
    Write-Verbose "$Env:TF_BUILD_BINARIESDIRECTORY does not exist."

    if(-not $Disable)
    {
        Write-Verbose "Ready to create it."
        [IO.Directory]::CreateDirectory($Env:TF_BUILD_BINARIESDIRECTORY) | Out-Null
        Write-Verbose "Directory created."
    }
} 

# Copy the binaries 
Write-Verbose "Ready to copy files."
if(-not $Disable)
{
    Copy $SourceDir $Env:TF_BUILD_BINARIESDIRECTORY -Recurse -Exclude $FileTypes
    Write-Verbose "Files copied."
}
