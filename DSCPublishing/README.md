# DSC Publishing
## TFSBuild.proj and Package.ps1
TFSBuild.proj is a simple project file that can be used to package files in a TFS Team build.
The project file calls package.ps1 to copy all files to the drop folder.

U can use this to package your dsc resources from a git repository using its own build. 

## DSCResourcesConfiguration.ps1 and Ensure-DSCResources.ps1
Use DSCResourcesConfiguration.ps1 to ensure the dsc resources on all machines before deploying any configurations in Releasemanagement. Use Ensure-DSCResources.ps1 to locally deploy the resources.