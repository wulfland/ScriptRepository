# NAME
Set-RepositoryPermission.ps1
    
# SYNOPSIS
Set the permissions for a git repository to enforce naming policies
     
# SYNTAX
``` PowerShell
.\Set-RepositoryPermission.ps1 [-AccountOrCollection] <String> [-ProjectName] <String> [-Repository] <String> [[-AllowedFolders] <String[]>] [[-AdminAllowedFolders] <String[]>] [[-PathToTfExe] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
``` 
    
# DESCRIPTION
This script sets the permission of a git repository. It denys to create branches in the >>root and only allows the creation of branches in specific folders.
    
# PARAMETERS
    -AccountOrCollection <String>
        Your VSTS account or TFS project collection url
        
    -ProjectName <String>
        The name of the project that contains your repository
        
    -Repository <String>
        The name of the repository
        
    -AllowedFolders <String[]>
        The list of folders where contributors can create branches in (default: features, bufixes, users)
        
    -AdminAllowedFolders <String[]>
        The list of folders where contributors can create branches in (default: features, bufixes, users, releases, master)
        
    -PathToTfExe <String>
        The path where tf.exe is installed (default: Visual Studio 2017 location 'C:\Program Files (x86)\Microsoft Visual Studio\2017\Enterprise\Common7\IDE\CommonExtensions\Microsoft\TeamFoundation\Team Explorer').
        
    -WhatIf [<SwitchParameter>]
        
    -Confirm [<SwitchParameter>]
        
    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see 
        about_CommonParameters (http://go.microsoft.com/fwlink/?LinkID=113216). 
    
# Examples

## -------------------------- EXAMPLE 1 --------------------------
``` PowerShell
C:\PS>Set-RepositoryPermission.ps1 -AccountOrCollection https://tfs.contoso.com/tfs/DefaultCollection -ProjectName MyProject -Repository MyProject -Verbose
 ```   

## -------------------------- EXAMPLE 2 --------------------------
 ``` PowerShell 
C:\PS>Set-RepositoryPermission.ps1 -AccountOrCollection https://constoso.visualstudio.com -ProjectName MyProject -Repository MyProject -Verbose
```    
   
## -------------------------- EXAMPLE 3 --------------------------
``` PowerShell    
C:\PS>Set-RepositoryPermission.ps1 -AccountOrCollection https://constoso.visualstudio.com -ProjectName MyProject -Repository MyProject -AllowedFolders @("features", "users")
```    
    
    
# REMARKS
 To see the examples, type: "get-help .\Set-RepositoryPermission.ps1 -examples".  
 For more information, type: "get-help .\Set-RepositoryPermission.ps1 -detailed".  
 For technical information, type: "get-help .\Set-RepositoryPermission.ps1 -full".
