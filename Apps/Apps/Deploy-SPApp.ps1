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

function Install-App($clientContext, $appPackage, $productId) {     
    $appName = [System.IO.Path]::GetFileNameWithoutExtension($appPackage)
    $web = $clientContext.Web

    Write-Verbose "Start to install app $appName..."
    
    # Try to uninstall any existing app instances first.
    Uninstall-App $clientContext $productId

    Write-Verbose "Installing app $appName..." 
    $appInstance = $web.LoadAndInstallAppInSpecifiedLocale(([System.IO.FileInfo]$appPackage).OpenRead(), $web.Language)
    $clientContext.Load($appInstance)
    $clientContext.ExecuteQuery()

    $appInstance = WaitForAppOperationComplete $clientContext $appInstance.Id

    if (!$appInstance -Or $appInstance.Status -ne [Microsoft.SharePoint.Client.AppInstanceStatus]::Installed) 
    {
        if ($appInstance -And $appInstance.Id) 
        {
            Write-Error "App installation failed. To check app details, go to '$($web.Url.TrimEnd('/'))/_layouts/15/AppMonitoringDetails.aspx?AppInstanceId=$($appInstance.Id)'."
        }

        throw "App installation failed."
    }

    return $appInstance.Id
}

function Uninstall-App($clientContext, $productId) {
    $appInstances = $web.GetAppInstancesByProductId($productId)
    $clientContext.Load($appInstances)
    $clientContext.ExecuteQuery()

    if ($appInstances -And $appInstances.Length -gt 0) 
    {
        $appInstance = $appInstances[0]

        Write-Verbose "Uninstalling app with instance id $($appInstance.Id)..."
        $appInstance.Uninstall() | out-null
        $clientContext.Load($appInstance)
        $clientContext.ExecuteQuery()

        $appInstance = WaitForAppOperationComplete $clientContext $appInstance.Id
        
        # Assume the app uninstallation succeeded
        Write-Verbose "App was uninstalled successfully."
    }
}

function WaitForAppOperationComplete($clientContext, $appInstanceId) {

    for ($i = 0; $i -le 2000; $i++) 
    {
        try 
        {
            $web = $clientContext.Web
            $instance = $web.GetAppInstanceById($appInstanceId)
            $clientContext.Load($instance)
            $clientContext.ExecuteQuery()
        }
        catch [Microsoft.SharePoint.Client.ServerException] 
        {
            # When the uninstall finished, "app is not found" server exception will be thrown.
            # Assume the uninstalling operation succeeded.
            break
        }

        if (!$instance) 
        {
            break
        }

        $result = $instance.Status;
        if ($result -ne [Microsoft.SharePoint.Client.AppInstanceStatus]::Installed -And
            !$instance.InError -And 
            # If an app has failed to install correctly, it would return to initialized state if auto-cancel was enabled
            $result -ne [Microsoft.SharePoint.Client.AppInstanceStatus]::Initialized) 
        {
            Write-Verbose "Instance status: $result"
            Start-Sleep -m 1000
        }
        else 
        {
            break
        }
    }

    return $instance;
}

function Enable-SideLoading {

    param($clientContext, $enable = $true, $force = $false)

    # this is the side-loading Feature ID..
    $FeatureId = [GUID]("AE3A1339-61F5-4f8f-81A7-ABD2DA956A7D")

    # ..and this one is site-scoped, so using $clientContext.Site.Features..
    $siteFeatures = $clientContext.Site.Features 
    $clientContext.Load($siteFeatures)
    $clientContext.ExecuteQuery()

    $feature = $siteFeatures | Where-Object { $_.DefinitionId -eq $FeatureId } | Select-Object -First 1

    if ($feature)
    {
        if ($enable) 
        { 
            Write-Verbose "Feature is already activated in this site." 
            return
        } 
        else
        {
            $siteFeatures.Remove($featureId, $force)
        }
    }
    else
    {
        if ($enable)
        {
	        $siteFeatures.Add($featureId, $force, [Microsoft.SharePoint.Client.FeatureDefinitionScope]::None)
        }
        else
        {
            Write-Verbose "The feature is not active at this scope."
            return
        }
    }

    try 
    {
	    $clientContext.ExecuteQuery()
	    if ($enable)
	    {
		    Write-Verbose "Feature '$FeatureId' successfully activated.."
	    }
	    else
	    {
		    Write-Verbose "Feature '$FeatureId' successfully deactivated.."
	    }
    }
    catch 
    {
	    throw "An error occurred whilst activating/deactivating the Feature. Error detail: $($_)"
    }
}

function Load-Assemblies {

    # suppress output
    $assembly1 = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client")
    $assembly2 = [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SharePoint.Client.Runtime")

    Write-Verbose "Assemblies loaded."
}

function WaitFor-IEReady {

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
function Invoke-JavaScript {

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

function Get-AppPackageInformations {

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

        if ($env:ClientId){
            $clientId = $env:ClientId
        }else{
            $clientId = $xml.App.AppPrincipal.RemoteWebApplication.ClientId
        }
       
        $appInformations = @{
                         ClientId = $clientId
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
   
            if ($env:ClientId){
                Write-Verbose "Found ClientId '$env:ClientId' in environment. Replace it in app."
                $xml.App.AppPrincipal.RemoteWebApplication.ClientId = $env:ClientId
            }

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

function WaitFor-IEReady {

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
function Invoke-JavaScript {

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

function Trust-SPAddIn {

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

        Write-Verbose $ie.Document.Title -Verbose

        if ($ie.Document.Title -match "Sign in to Office 365.*") {
        
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

        Write-Verbose $ie.Document.Title -Verbose

        
        if ($ie.Document.Title -match "Do you trust.*")
        {
            sleep -seconds 5


            $button = $ie.Document.getElementById("ctl00_PlaceHolderMain_BtnAllow")

			if ($button -eq $null) {
				$button = $ie.Document.getElementById("ctl00_PlaceHolderMain_LnkRetrust")
			}
            
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

    Write-Host "Trust the app."
    Trust-SPAddIn -AppInstanceId $appId -WebUrl $WebUrl -UserName $DeployUserName -Password $DeployPassword
}
finally
{
    $clientContext.Dispose()
}