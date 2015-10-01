$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut" -AppPackageFullName "lala" -TargetWebFullUrl "http://localhost"

Describe "Install-SPAddIn" {
    context "Given the app package does not exist, it" {
        It "throws an excpetion" {
            { Install-SPAddIn -AppPackageFullName "C:\lala.app" -TargetWebFullUrl http://localhost } | Should throw "The package 'C:\lala.app' does not exit."
        }
    }

    context "Given the app package does exist, it" {
        In $TestDrive {
            Setup -File ".\lala.app"
            Mock Install-SPAddInInternal {  } -Verifiable

            It "does not throw an exception, and" {
                { Install-SPAddIn -AppPackageFullName ".\lala.app" -TargetWebFullUrl http://localhost } | Should not throw
            }

            It "installes the package in all sites."{
                Install-SPAddIn -AppPackageFullName ".\lala.app" -TargetWebFullUrl @("http://localhost/sites/a", "http://localhost/sites/b")    
            
                Assert-MockCalled Install-SPAddInInternal -Times 2     
            }
        }
    }
}

Describe "Install-SPAddInInternal"{
    context "Given the app cannot be installed, it" {
        Mock WaitFor-InstallJob { return 'Error' }

        $actual = Install-SPAddInInternal -AppPackageFullName "C:\lala.app" -webUrl http://localhost -sourceApp "ObjectModel" -Whatif -erroraction silentlycontinue

        It "does return one, and"{
            $actual | should be 1
        }
    }

    context "the app is installed, and it" {
        Mock WaitFor-InstallJob { return 'Installed' }

        $actual = Install-SPAddInInternal -AppPackageFullName "C:\lala.app" -webUrl http://localhost -sourceApp "ObjectModel" -Whatif

        It "returns zero."{
            $actual | should be 0
        }
    }
}

Describe "Trust-SPAddIn"{

    context "Given a web URL, it"{

        Mock Write-Message { } -Verifiable
        Mock New-Object { 
            $doc = [PSCustomObject]@{ }
            $doc | Add-Member -MemberType ScriptMethod getElementById  { 
                param($id)

                $btn = [PSCustomObject]@{ }
                $btn | Add-Member -MemberType ScriptMethod -Name click -Value { } 

                return $btn
            }

            $obj = [PSCustomObject]@{ visible = $false; busy = $false; Document = $doc }  
            $obj | Add-Member -MemberType ScriptMethod -Name navigate2 -Value { }
            $obj | Add-Member -MemberType ScriptMethod -Name Quit -Value { }
            
            return $obj
        }

        $id = [Guid]::NewGuid()
        $actual = Trust-SPAddIn -WebUrl "http://server/sites/web/subsite/" -AppInstanceId $id -verbose 

        It "constructs the correct trust url."{
            Assert-MockCalled Write-Message -ParameterFilter { $message -like "http://server/sites/web/subsite/_layouts/15/appinv.aspx?AppInstanceId={$id}"  } 
        }
    }
}

Describe "WaitFor-InstallJob" {

    Mock Get-ParentSite { } 

    context "Given the package cannot be installed, it"{
        
        Mock Get-AppInstance { return [PSCustomObject]@{ Status = 'Error' } }

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid()) -WebUrl "http://localhost"

        It "returns the state returned from SharePoint." {
            $result | Should be "Error"
        }
    }

    context "Given the package cannot be installed in timeout period, it"{

        Mock Get-AppInstance { return [PSCustomObject]@{ Status = 'Installing' } } -Verifiable

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid()) -WebUrl "http://localhost"

        It "requeries the status 5 times, and" {
            Assert-MockCalled Get-AppInstance -Times 5
        }

        It "returns the state from SharePoint." {
            $result | Should be "Installing"
        }
    }

    context "Given the package was installed immediattly, it"{

        Mock Get-AppInstance { return [PSCustomObject]@{ Status = 'Installed' } } -Verifiable

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid()) -WebUrl "http://localhost"

        It "queries the app 1 time, and" {
            Assert-MockCalled Get-AppInstance -Times 1
        }

        It "returns the state 'Installed'." {
            $result | Should be "Installed"
        }
    }


    context "Given the package was installed after 6 seconds, it" {

        $Global:iteration = 0

        Mock Get-AppInstance { 
            $Global:iteration++
            if ($Global:iteration -lt 3) {
                return [PSCustomObject]@{ Status = 'Installing' } 
            }else{
                return [PSCustomObject]@{ Status = 'Installed' } 
            } } -Verifiable

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid()) -WebUrl "http://localhost"

        It "queries the app 3 times, and" {
            Assert-MockCalled Get-AppInstance -Times 3
        }

        It "returns the state 'Installed'." {
            $result | Should be "Installed"
        }
    }
}
