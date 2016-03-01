[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
[OutputType([int])]
Param
(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$AppName,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]$WebUrl,

    [Parameter(Mandatory=$true, Position=2)]
    [ValidateNotNullOrEmpty()]
    [string]$RemoteAppUrl,

    [Parameter(Mandatory=$true, Position=3)]
    [ValidateNotNullOrEmpty()]
    [string]$DeployUserName,

    [Parameter(Mandatory=$true, Position=4)]
    [ValidateNotNullOrEmpty()]
    [string]$DeployPassword
)

function Load-Assemblies
{
    # suppress output
    $assembly1 = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")
    $assembly2 = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")

    Write-Verbose "Assemblies loaded."
}

function WaitFor-IEReady
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        $ie,

        [Parameter(Mandatory=$false, Position=1)]
        $initialWaitInSeconds = 1
    )

    sleep -Seconds $initialWaitInSeconds

    while ($ie.Busy) {

        sleep -milliseconds 50
    }
} 

<#
.Synopsis
   Invoke a java script function.
.DESCRIPTION
   Use this function to run JavaScript on a web page. Your $Command can
   return a value which will be returned by this function unless $global
   switch is specified in which case $Command will be executed in global
   scope and cannot return a value. If you received error 80020101 it means
   you need to fix your JavaScript code.
.EXAMPLE
   Invoke-JavaScript -IE $ie -Command 'Post.IsSubmitReady();setTimeout(function() {Post.SubmitCreds(); }, 1000);'
.EXAMPLE
   $result = Invoke-JavaScript -IE $ie -Command 'Post.IsSubmitReady();setTimeout(function() {Post.SubmitCreds(); }, 1000);' -Global
#>
function Invoke-JavaScript
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        $IE,

        [Parameter(Mandatory=$true, Position=1)]
        $Command,

        [switch]$Global
    )

    if (-not $Global.IsPresent) {
        $Command = "document.body.setAttribute('PSResult', (function(){ $Command })());"
    }

    $document = $IE.document
    $window = $document.parentWindow
    $window.execScript($Command, 'javascript') | Out-Null

    if (-not $Global.IsPresent) {
        return $document.body.getAttribute('PSResult')
    }
}

function Trust-SPAddIn
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [guid]$AppInstanceId,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$WebUrl,

        [parameter(Mandatory=$true, Position=2)] 
        [string]$UserName, 

        [parameter(Mandatory=$true, Position=3)] 
        [string]$Password
    )

    $authorizeURL = "$($WebUrl.TrimEnd('/'))/_layouts/15/appinv.aspx?AppInstanceId={$AppInstanceId}"

    $ie = New-Object -com internetexplorer.application

    try
    {
        $ie.Visible = $false
        $ie.Navigate2($authorizeURL)

        WaitFor-IEReady $ie

        if ($ie.LocationName -eq "Sign in to Office 365"){
        
            Write-Verbose "Authenticate $UserName to O365..."
            # Authorize against O365        
            $useAnotherLink = $ie.Document.getElementById("use_another_account_link")
            if ($useAnotherLink) {
            
                WaitFor-IEReady $ie

                $useAnotherLink.Click()

                WaitFor-IEReady $ie

            }

            $credUseridInputtext = $ie.Document.getElementById("cred_userid_inputtext")
            $credUseridInputtext.value = $UserName

            $credPasswordInputtext = $ie.Document.getElementById("cred_password_inputtext")
            $credPasswordInputtext.value = $Password
        
            WaitFor-IEReady $ie
           

            # make a jQuery call
            $result = Invoke-JavaScript -IE $ie -Command "`nPost.IsSubmitReady();`nsetTimeout(function() {`nPost.SubmitCreds();`n}, 1000);"
     
            WaitFor-IEReady $ie -initialWaitInSeconds 5
            
        }

        Write-Verbose $ie.Document.Title

        
        if ($ie.LocationName -eq "Do you trust CalculatorApp-Dev?")
        {
            sleep -seconds 5

            $button = $ie.Document.getElementById("ctl00_PlaceHolderMain_BtnAllow")
            if ($button -eq $null) {

                throw "Could not find button to press"

            }else{

                $button.click()
 
                WaitFor-IEReady $ie

                #if the button press was successful, we should now be on the Site Settings page.. 
                if ($ie.Document.title -like "*trust*") {

                    throw "Error: $($ie.Document.body.getElementsByClassName("ms-error").item().InnerText)"

                }else{

                    Write-Verbose "App was trusted successfully!"
                }
            }

        }else{

            throw "Unexpected page '$($ie.LocationName)' was loaded. Please check your url."
        }
    }
    finally
    {
        $ie.Quit()
    } 
}


function Get-AppPackageInformations{

    [CmdletBinding()]
    [OutputType([Hashtable])]
    param([string]$Path, [string]$AppWebUrl)

    # Open zip
    Add-Type -assembly  System.IO.Compression.FileSystem
    Write-Verbose "Open zip file '$Path'..."
    $zip =  [System.IO.Compression.ZipFile]::Open($Path, "Update")

    try{
        $fileToEdit = "AppManifest.xml"
        $file = $zip.Entries.Where({$_.name -eq $fileToEdit})

        Write-Verbose "Read app manifest from '$file'."
        $desiredFile = [System.IO.StreamReader]($file).Open()
        [xml]$xml = $desiredFile.ReadToEnd()
        $desiredFile.Close()
       
        $appInformations = @{
                         ClientId = $xml.App.AppPrincipal.RemoteWebApplication.ClientId
                          Version = $xml.App.Version
               AllowAppOnlyPolicy = [bool]$xml.App.AppPermissionRequests.AllowAppOnlyPolicy
                            Title = $xml.App.Properties.Title
                        ProductID = $xml.App.ProductID
        }

        if ($AppWebUrl){
            # Replace URL
            $value = $xml.App.Properties.StartPage
            Write-Verbose "Replace URL in '$value' with '$AppWebUrl'."
            $value = $value -replace "^.*\?","$($AppWebUrl)?" 
            $xml.App.Properties.StartPage = $value
   

            # Save file
            Write-Verbose "Save manifest to '$file'."
            $desiredFile = [System.IO.Stream]($file).Open()
            $desiredFile.SetLength(0)
            $xml.Save($desiredFile)
            $desiredFile.Flush()
            $desiredFile.Close()
            $desiredFile.Dispose()

            $desiredFile = [System.IO.StreamReader]($file).Open()
            [xml]$xml = $desiredFile.ReadToEnd()
            Write-Host $xml
            $desiredFile.Close()
            $desiredFile.Dispose()
        }

        return $appInformations

    }finally{
        # Write the changes and close the zip file
        $zip.Dispose()
    }
}

Write-Host "Look for '$AppName' in '$applicationPath'..."
$appPackage = Get-ChildItem -Path $applicationPath -Recurse -Include $AppName

if (-not($appPackage)){ throw "No ap ppackage '$AppName' found in '$applicationPath'..." }

Write-Host "Get package informations and set url in package to '$RemoteAppUrl'"
$appPackageInformations = Get-AppPackageInformations -Path $appPackage.FullName -AppWebUrl $RemoteAppUrl


Load-Assemblies

Write-Host "Connect to '$WebUrl' as '$DeployUserName'..."
$clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($webUrl) 
$clientContext.Credentials = New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($DeployUserName, (ConvertTo-SecureString $DeployPassword -AsPlainText -Force)) 

try
{
    $web = $clientContext.Web
    $clientContext.Load($web)

    $clientContext.ExecuteQuery();

    Write-Host "Successfully connected to '$WebUrl'..."
    
    Write-Host "Update SharePoint app '$AppName' in '$WebUrl' to Version '$($appPackageInformations.Version)'..."
    $appId = Install-App -clientContext $clientContext -appPackage $appPackage.FullName -productId $appPackageInformations.ProductID
    Write-Host "Done."

    Write-Host "Trust App..."
    Trust-SPAddIn -AppInstanceId $appId -WebUrl $WebUrl -UserName $DeployUserName -Password $DeployPassword
    Write-Host "Done."
}
finally
{
    $clientContext.Dispose()
}