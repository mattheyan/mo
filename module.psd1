@{
    Name = 'mo'
    Author = 'Bryan Matthews'
    Version = '0.1.0'
    Dependencies = @{
        '7zip' = '~\Dropbox\Common\Workspace\MyProjects\PowerShell-Modules\7zip'
        'PsData' = '~\Dropbox\Common\Workspace\MyProjects\PowerShell-Modules\PsData'
        'PsTraverse' = '~\Dropbox\Common\Workspace\MyProjects\PowerShell-Modules\PsTraverse'
        'CredentialManager' = 'github: davotronic5000/PowerShell_Credential_Manager'
    }
    DevDependencies = @{
        'psake-assemble'
    }
}
