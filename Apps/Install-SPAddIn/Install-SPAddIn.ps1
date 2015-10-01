<#
.Synopsis
   Installs a SharePoint AddIn A.K.A. SharePoint App to one or more specific sites.
.DESCRIPTION
   This function installs a SharePoint AddIn A.K.A. SharePoint App to one or more specific sites.
.EXAMPLE
   Install-SPAddIn -AppPackageFullName C:\MyCustomAppPackage.app -TargetWebFullUrl http://localhost
.EXAMPLE
   Install-SPAddIn -AppPackageFullName C:\MyCustomAppPackage.app -TargetWebFullUrl @("http://localhost/sites/a", "http://localhost/sites/b")
#>
[CmdletBinding(SupportsShouldProcess=$true)]
Param
(
    # The full name of the app package (i.e. 'C:\temp\MyCustomAppPackage.app')
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
    [string]$AppPackageFullName,

    # The urls of the webs youwant to deploy the app to.
    [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
    [string[]]$TargetWebFullUrl,

    # The package source
    [Parameter(Mandatory=$false, Position=2)]
    [ValidateSet("ObjectModel", "Marketplace", "CorporateCatalog", "DeveloperSite", "RemoteObjectModel")]
    [string]$PackageSource = "ObjectModel"
)

<#
.Synopsis
   Installs a SharePoint AddIn A.K.A. SharePoint App to one or more specific sites.
.DESCRIPTION
   This function installs a SharePoint AddIn A.K.A. SharePoint App to one or more specific sites.
.EXAMPLE
   Install-SPAddIn -AppPackageFullName C:\MyCustomAppPackage.app -TargetWebFullUrl http://localhost
.EXAMPLE
   Install-SPAddIn -AppPackageFullName C:\MyCustomAppPackage.app -TargetWebFullUrl @("http://localhost/sites/a", "http://localhost/sites/b")
#>
function Install-SPAddIn 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param
    (
        # The full name of the app package (i.e. 'C:\temp\MyCustomAppPackage.app')
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
        [string]$AppPackageFullName,

        # The urls of the webs youwant to deploy the app to.
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, Position=1)]
        [string[]]$TargetWebFullUrl,

        # The package source
        [Parameter(Mandatory=$false, Position=2)]
        [ValidateSet("ObjectModel", "Marketplace", "CorporateCatalog", "DeveloperSite", "RemoteObjectModel")]
        [string]$PackageSource = "ObjectModel"
    )

    Begin
    {
        if (-not (Test-Path $AppPackageFullName))
        {
            throw "The package '$AppPackageFullName' does not exit."
        }

        Ensure-PSSnapin   
        $sourceApp = [microsoft.sharepoint.administration.spappsource]$PackageSource    
    }
    Process
    {
        foreach ($webUrl in $TargetWebFullUrl)
        {
            Install-SPAddInInternal -AppPackageFullName $AppPackageFullName -webUrl $webUrl -sourceApp $sourceApp
        }
    }
    End
    {
        Release-PSSnapin
    }
}

function Install-SPAddInInternal
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$true, Position=0)]
        [string]$AppPackageFullName,

        [Parameter(Mandatory=$true, Position=1)]
        [string]$webUrl,

        [Parameter(Mandatory=$true, Position=2)]
        [microsoft.sharepoint.administration.spappsource]$sourceApp
    )

    Write-Verbose "Start to deploy '$AppPackageFullName' to '$webUrl'..."

    if ($PSCmdlet.ShouldProcess("$webUrl", "Import-SPAppPackage"))
    {
        $spapp = Import-SPAppPackage -Path "$AppPackageFullName" -Site $webUrl -Source $sourceApp -Confirm:$false -ErrorAction Stop
    }

    $appId = [Guid]::Empty;

    if ($PSCmdlet.ShouldProcess("$webUrl", "Install-SPApp"))
    {
        $app = Install-SPApp -Web $WebUrl -Identity $spapp -Confirm:$false -ErrorAction Stop
        $appId = $app.Id
    }

    if ($PSCmdlet.ShouldProcess("$webUrl", "Trust-SPAddIn"))
    {
        Trust-SPAddIn -AppInstanceId $appId -WebUrl $webUrl   
    }

    $status = WaitFor-InstallJob -AppInstanceId $appId -WebUrl $webUrl

    if ($status -ne [Microsoft.SharePoint.Administration.SPAppInstanceStatus]::Installed)
    {
        Write-Error "The app could not be installed. Current state is '$status'."

        $result = 1
    }
    else
    {
        $result = 0
    }

    Write-Verbose "End deploying '$AppPackageFullName' to '$webUrl'."

    return $result
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
        [string]$WebUrl
    )

    $authorizeURL = "$($WebUrl.TrimEnd('/'))/_layouts/15/appinv.aspx?AppInstanceId={$AppInstanceId}"

    Write-Message -message $authorizeURL

    $oIE = New-Object -com internetexplorer.application

     try
     {
         $oIE.visible=$true
         $oIE.navigate2($authorizeURL)

         sleep -Seconds 1
         while ($oIE.busy) {
            sleep -milliseconds 50
         }

         Write-Verbose "Loaded Page: $($oIE.Document.Title)"

         sleep -seconds 5

         $button = $oIE.Document.getElementById("ctl00_PlaceHolderMain_BtnAllow")
         if ($button -eq $null)
         {
            Write-Error "Could not find button to press"
            Write-Error $oIE.Document.documentElement.outerText
         }
         else
         {
             $button.click()
 
             sleep -Seconds 1
     
             while ($oIE.busy) {
                sleep -milliseconds 50
             }

             Write-Verbose "Now we're on page: $($oIE.Document.Title) - $($oIE.LocationURL)"

             #if the button press was successful, we should now be on the Site Settings page.. 
             if ($oIE.Document.title -like "*trust*")
             {
                Write-Error "Error: " $oIE.Document.body.getElementsByClassName("ms-error").item().InnerText
                throw ("Error Trusting App:" + $oIE.Document.body.getElementsByClassName("ms-error").item().InnerText)
             }
             else
             {
                Write-Verbose "App was trusted successfully!"
             }
         }
     }
     finally
     {
        $oIE.Quit()
     } 
}

function WaitFor-InstallJob
{
    [CmdletBinding()]
    param
    (
        [guid]$AppInstanceId,

        [string]$WebUrl
    )

    $site = Get-ParentSite -webUrl $WebUrl

    $AppInstance = Get-AppInstance -id $AppInstanceId -site $site

    Write-Verbose "Waiting for app..."
    
    $i = 0
    $max = 5 
    $sleepTime = 2

    start-sleep -s $sleepTime

    while(($AppInstance.Status -eq [Microsoft.SharePoint.Administration.SPAppInstanceStatus]::Installing) -and ($i -le $max))
    {
        [int]$complete = ($i / $max) * 100
        Write-Progress -Activity "Install app..." -Status "$($complete)% completed" -PercentComplete $complete

        $i++

        start-sleep -s $sleepTime

        $AppInstance = Get-AppInstance -id $AppInstanceId -site $site
    }

    Write-Progress -Activity "Install app" -Completed
    Write-Verbose "Result of installation is '$($AppInstance.Status)'."

    return $AppInstance.Status
}

function Get-AppInstance
{
    param([guid]$id, $site)

    return Get-SPAppInstance -AppInstanceId $id -Site $site
}

function Get-ParentSite
{
    param([string]$webUrl)

    return (Get-SPWeb $WebUrl).Site
}

function Write-Message
{
    param([string]$message)

    Write-Verbose $message
}

function Ensure-PSSnapin
{
    if ((Get-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -eq $null) 
    {
        Add-PSSnapin "Microsoft.SharePoint.PowerShell" -Verbose:$false | Out-Null
        Write-Verbose "SharePoint Powershell Snapin loaded."
    } 
}

function Release-PSSnapin
{
    if ((Get-PSSnapin "Microsoft.SharePoint.PowerShell" -ErrorAction SilentlyContinue) -ne $null) 
    {
        Remove-PSSnapin "Microsoft.SharePoint.PowerShell" -Verbose:$false | Out-Null
        Write-Verbose "SharePoint Powershell Snapin removed."
    } 
}

if (-not $MyInvocation.Line.Contains("`$here\`$sut")){
    Install-SPAddIn -AppPackageFullName $AppPackageFullName -TargetWebFullUrl $TargetWebFullUrl -PackageSource $PackageSource
}