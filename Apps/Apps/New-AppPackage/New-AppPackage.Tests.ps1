$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"

Describe "New-AppPackage" {
    context "Given the SourceDirectory does not exit"{
        It "New-AppPackage throws an exception"{
            { New-AppPackage -SourceDirectory "C:\XYZ" } | Should throw
        }
    }

    context "Given the Binary directory does not exit"{
        setup -Dir "SourceDir"

        It "creates the directory"{
            $actual = New-AppPackage -SourceDirectory "$TestDrive\SourceDir" -BinariesDirectory "$TestDrive\XYZ"
            { Test-Path "$TestDrive\XYZ" } | Should Be $true
        }
    }

    context "Given a single app"{
        setup -Dir "SourceDir"
        setup -Dir "BinariesDir"
        setup -File "SourceDir\MySample.app"


        It "copies the app to the binaries directory"{
            $actual = New-AppPackage -SourceDirectory "$TestDrive\SourceDir" -BinariesDirectory "$TestDrive\BinariesDir"
            $actual | should be 0
            { Test-Path "$TestDrive\BinariesDir\MySample.app" } | Should Be $true
        }
    }
}
