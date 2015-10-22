# Set assembly versions in TFS team build
## Introduction
One of the most common customizations in TFS XAML build templates was to automatically update the assembly version number. This can also be done in build vNext using a small power shell script.


## Description
A build script that can be included in TFS 2015 or Visual Studio Online (VSO) vNevt builds that update the version of all assemblies in a workspace.
It uses the name of the build to extract the version number and updates all AssemblyInfo.cs files to use the new version.

Add the variables MajorVersion and MinorVersion to your build. Set the Build number format (Tab General) to:

$(BuildDefinitionName)_$(MajorVersion).$(MinorVersion)_$(Year:yy)$(DayOfYear)$(rev:.rr)

> Zitat

* Liste
* Liste2
* Liste3

```csharp
function test() {
  console.log("notice the blank line before this function?");
}
```

[foo]("http://incyclesoftware.com/2015/06/vnext-build-awesomeness-managing-version-numbers/)
