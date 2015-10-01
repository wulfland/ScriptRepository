# TFS Build Scripts
A solution for build scripts that can be used in vNext build tasks.

## AssemblyVersion
A build script that can be included in TFS 2015 or Visual Studio Online (VSO) vNevt builds that update the version of all assemblies in a workspace.
It uses the name of the build to extract the version number and updates all AssemblyInfo.cs files to use the new version.

Add the variables MajorVersion and MinorVersion to your build. Set the Build number format (Tab General) to:

$(BuildDefinitionName)_$(MajorVersion).$(MinorVersion)_$(Year:yy)$(DayOfYear)$(rev:.rr)

