PSPM
====

A package manager for PowerShell, inspired by NPM.

## Background

> The Madness Must Stop! - PowerShell Package Management
> 
> Wishlist:
> * Ability to deploy multiple versions of the same package
> * Different levels of isolation (System | Profile | Project ) levels
> * A management tool so that projects can declare versions and packages...
> * Packages can be stored in different locations (Nuget.org, github, url)

-- http://scottmuc.com/blog/development/the-madness-must-stop-powershell-package-management/

### Similar Projects:

**[PsGet](http://psget.net/):**

- PowerShell module that provides an `Install-Module` cmdlet.
- Designed to install modules from various sources (NuGet, zip, etc.)
- Doesn't like it when you install module in a non-PSModulePath location

**[PowerShellGet](https://technet.microsoft.com/en-us/library/dn807169.aspx):**

- Relatively new offering, from Microsoft
- PowerShell modules that provides an `Install-Module` cmdlet, and others...
- Prior to Win10, requires installing WMF or running a standalone installer
- Appears to only support installing modules globally

## References

* http://scottmuc.com/blog/development/the-madness-must-stop-powershell-package-management/
* https://blog.stangroome.com/2012/02/23/requirements-for-a-powershell-module-manager/
* https://technet.microsoft.com/en-us/library/dn807169.aspx
* http://www.powershellgallery.com
* https://blogs.msdn.microsoft.com/mvpawardprogram/2014/10/06/package-management-for-powershell-modules-with-powershellget/
