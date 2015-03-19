TFSBuild.proj is a simple project file that can be used to package files in a TFS Team build.
The project file calls package.ps1 to copy all files to the drop folder.

U can use this to package your dsc resources from a git repository using its own build. 

Use DSCResourcesConfiguration.ps1 to ensure the dsc resources on all machines before deploying any configurations...