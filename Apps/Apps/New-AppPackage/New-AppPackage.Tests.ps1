$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "New-AppPackage" {
    context "Given the SourceDirectory does not exit, it"{
        It "throws an exception"{
            { New-AppPackage -SourceDirectory "C:\XYZ" } | Should throw
        }
    }

    context "Given the Binary directory does not exit, it"{
        setup -Dir "SourceDir"

        It "creates the directory"{
            $actual = New-AppPackage -SourceDirectory "$TestDrive\SourceDir" -BinariesDirectory "$TestDrive\XYZ"
            { Test-Path "$TestDrive\XYZ" } | Should Be $true
        }
    }

    context "Given a single app, it"{
        setup -Dir "SourceDir"
        setup -Dir "BinariesDir"
        setup -File "SourceDir\app.publish\0.0.1.6\MySample.app"

        $actual = New-AppPackage -SourceDirectory "$TestDrive\SourceDir" -BinariesDirectory "$TestDrive\BinariesDir"

        It "copies exactly one app"{
            $actual | should be 1
        }

        It "copies the app to the binaries directory"{
            { Test-Path "$TestDrive\BinariesDir\MySample.app" } | Should Be $true
        }
    }

    context "Given two apps, it"{
        setup -Dir "SourceDir"
        setup -Dir "BinariesDir"
        setup -File "SourceDir\app1\app.publish\0.0.1.6\MySample1.app"
        setup -File "SourceDir\app2\app.publish\0.0.1.6\MySample2.app"

        $actual = New-AppPackage -SourceDirectory "$TestDrive\SourceDir" -BinariesDirectory "$TestDrive\BinariesDir"

        It "copies both apps"{
            $actual | should be 2
        }
    }

    context "Given an app in a different folders then 'app.publish', it"{
        setup -Dir "SourceDir"
        setup -Dir "BinariesDir"
        setup -File "SourceDir\app1\xxxx\0.0.1.6\MySample1.app"

        $actual = New-AppPackage -SourceDirectory "$TestDrive\SourceDir" -BinariesDirectory "$TestDrive\BinariesDir"

        It "ignores the app"{
            $actual | should be 0
        }
    }
}
