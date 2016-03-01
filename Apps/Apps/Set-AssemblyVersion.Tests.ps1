$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\$sut"


Describe "Set-AssemblyVersion" {

    context "Given the SourceDirectory does not exit, it"{

        It "throws an exception"{
            { Set-AssemblyVersion -SourceDirectory "$TestDrive\XYZ" -BuildNumber "Dev_1.0.20150922.01" } | Should throw
        }
    }

    context "Given the SourceDirectory does exit, it"{
        setup -File "SourceDir\Properties\AssemblyInfo.cs" -Content "[assembly: AssemblyVersion(""1.0.0.0"")]"

        It "does not throw an exception"{
            { Set-AssemblyVersion -SourceDirectory "$TestDrive\SourceDir" -BuildNumber "Dev_1.0.20150922.01" } | Should not Throw
        }

        $content = Get-Content "$TestDrive\SourceDir\Properties\AssemblyInfo.cs"

        It "sets the version to the extracted verion of the build number"{
            $content | should match "[assembly: AssemblyVersion(""1.0.20150922.01"")]"
        }
    }
}

Describe "Get-Version"{
    
    context "Given a valid regex, it"{

        It "returns the expected version if one match was found"{
            $actual = Get-Version -BuildNumber "Build HelloWorld_0000.00.00.0" -VersionFormat "\d+\.\d+\.\d+\.\d+"

            $actual | Should be "0000.00.00.0"
        }

        It "returns the first result, if two results were found"{
            $actual = Get-Version -BuildNumber "1111.00.00.0_Build HelloWorld_0000.00.00.0" -VersionFormat "\d+\.\d+\.\d+\.\d+"

            $actual | Should be "1111.00.00.0"
        }

        It "throws an exception, if no match could be found"{

            { Get-Version -BuildNumber "Build HelloWorld_0" -VersionFormat "\d+\.\d+\.\d+\.\d+" } | Should throw
        }
    }

    context "Given an invalid regex, it"{
    
        It "throws an exception."{

            { Get-Version -BuildNumber "Build HelloWorld_0" -VersionFormat "lala" } | Should throw
        }
    }
}

Describe "Get-Files"{
    
    context "Given two projects in a solution folder, it"{
        
        setup -File "SourceDir\SolutionDir\Project1\Properties\AssemblyInfo.cs"
        setup -File "SourceDir\SolutionDir\Project2\Properties\AssemblyInfo.cs"

        $actual = Get-Files -SourceDir $TestDrive\SourceDir

        It "returns two Assembly.cs files"{
            $actual | should not BeNullOrEmpty
            $actual.Count | should be 2
        }
    }

    context "Given two projects in different subfolders, it"{
        
        setup -File "SourceDir\SolutionDir\Subfolder1\Project1\Properties\AssemblyInfo.cs"
        setup -File "SourceDir\SolutionDir\Sub1\Sub2\Project2\Properties\AssemblyInfo.cs"

        $actual = Get-Files -SourceDir $TestDrive\SourceDir

        It "returns two Assembly.cs files"{
            $actual | should not BeNullOrEmpty
            $actual.Count | should be 2
        }
    }

    context "Given a visual basic project, it"{
        
        setup -File "SourceDir\Properties\AssemblyInfo.vb"

        $actual = Get-Files -SourceDir $TestDrive\SourceDir

        It "returns two Assembly.cs files"{
            $actual | should not BeNullOrEmpty
            $actual.Count | should be 1
        }
    }
}

Describe "Set-FileContent"{

    context "Given an AssemblyInfo.cs file, it"{
    
        setup -File "SourceDir\AssemblyInfo.cs" -Content "//comment`r`n[assembly: AssemblyVersion(""1.0.0.0"")]`r`n[assembly: AssemblyFileVersion(""1.0.0.0"")]`r`n"

        Set-FileContent (gci "$TestDrive\SourceDir") "15.88.99.17" "\d+\.\d+\.\d+\.\d+"

        $content = Get-Content "$TestDrive\SourceDir\AssemblyInfo.cs"

        It "sets the Version to the given version"{
            $content[1] | should match "[assembly: AssemblyVersion(""15.88.99.1"")]"
        }

        It "sets the FileVersion to the given version"{
            $content[2] | should match "[assembly: AssemblyFileVersion(""15.88.99.1"")]"
        }
    }
}