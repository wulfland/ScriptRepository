$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "Install-SPAddIn" {
    context "The app package does not exist" {
        It "Throws an excpetion" {
            { Install-SPAddIn -AppPackageFullName "C:\lala.app" -TargetWebFullUrl http://localhost } | Should throw "The package 'C:\lala.app' does not exit."
        }
    }

    context "The app package does exist" {
        In $TestDrive {
            Setup -File ".\lala.app"
            Mock Install-SPAddInInternal {  } -Verifiable

            It "Does not throw an exception" {
                { Install-SPAddIn -AppPackageFullName ".\lala.app" -TargetWebFullUrl http://localhost } | Should not throw
            }

            It "Installes package in all sites"{
                Install-SPAddIn -AppPackageFullName ".\lala.app" -TargetWebFullUrl @("http://localhost/sites/a", "http://localhost/sites/b")    
            
                Assert-MockCalled Install-SPAddInInternal -Times 2     
            }
        }
    }
}

Describe "Install-SPAddInInternal"{
    context "The app cannot be installed" {
        Mock WaitFor-InstallJob { return 'Error' }

        $actual = Install-SPAddInInternal -AppPackageFullName "C:\lala.app" -webUrl http://localhost -sourceApp "ObjectModel" -Whatif -erroraction silentlycontinue

        It "Does write an error"{
            $actual | should be 1
        }
    }

    context "The app is installed" {
        Mock WaitFor-InstallJob { return 'Installed' }

        $actual = Install-SPAddInInternal -AppPackageFullName "C:\lala.app" -webUrl http://localhost -sourceApp "ObjectModel" -Whatif

        It "Does write an error"{
            $actual | should be 0
        }
    }
}

Describe "WaitFor-InstallJob" {
    context "The package cannot be installed"{

        Mock Get-AppInstance { return [PSCustomObject]@{ Status = 'Error' } }

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid())

        It "Returns the state" {
            $result | Should be "Error"
        }
    }

    context "The package cannot be installed in timeout period"{

        Mock Get-AppInstance { return [PSCustomObject]@{ Status = 'Installing' } } -Verifiable

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid())

        It "Returns the state" {
            $result | Should be "Installing"
        }

        It "Requeries status 5 times" {
            Assert-MockCalled Get-AppInstance -Times 5
        }
    }

    context "The package was installed immediattly"{

        Mock Get-AppInstance { return [PSCustomObject]@{ Status = 'Installed' } } -Verifiable

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid())

        It "Returns the state 'Installed'" {
            $result | Should be "Installed"
        }

        It "App queried 1 time" {
            Assert-MockCalled Get-AppInstance -Times 1
        }
    }


    context "The package was installed after 6 seconds" {

        $Global:iteration = 0

        Mock Get-AppInstance { 
            $Global:iteration++
            if ($Global:iteration -lt 3) {
                return [PSCustomObject]@{ Status = 'Installing' } 
            }else{
                return [PSCustomObject]@{ Status = 'Installed' } 
            } } -Verifiable

        $result = WaitFor-InstallJob -AppInstanceId ([guid]::NewGuid())

        It "Returns the state 'Installed'" {
            $result | Should be "Installed"
        }


        It "Requeries app 3 times" {
            Assert-MockCalled Get-AppInstance -Times 3
        }

    }
}
