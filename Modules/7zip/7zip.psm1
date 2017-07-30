$PSModuleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent


$7zipExe = "$($PSModuleRoot)\Tools\7-zip\7za.exe"

if (!(Test-Path $7zipExe)) {
    throw "Could not find 7-zip executable at '$($7zipExe)'."
}

$version = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($7zipExe)

function EnsureDirectory ([string]$path, [boolean]$defaultToCurrentLocation) {
    if ($path) {
        $path = $path.Trim()
    }

    if (!$path -and $defaultToCurrentLocation) {
        $path = Get-Location
    }
    elseif (Test-Path $path) {
        $path = (Resolve-Path $path).Path
        if (!(Get-Item $path).PSIsContainer) {
            Write-Error "ERROR: Path $path is not a directory."
            exit 1
        }
    }
    
    return $path
}


function Compress-Archive {
	[CmdletBinding()]
	param(
	    [Parameter(Position=0, Mandatory=$true, HelpMessage="The path to the file or files to archive.")]
	    [Alias("InputPath")]
	    [string]$Path,
	
	    [Parameter(Position=1, Mandatory=$false, HelpMessage="The path to the archive file to create.")]
	    [Alias("OutputPath")]
	    [string]$DestinationPath,
	
	    [Parameter(HelpMessage="If the input path is a directory, recursively include sub-directories.")]
	    [boolean]$Recurse=$true,
	
	    [Parameter(HelpMessage="If the destination path exists, attempt to remove it before creating the archive.")]
	    [switch]$Force,
	
	    [Parameter(HelpMessage="Don't write output from the 7-zip command.")]
	    [switch]$Silent,
	
	    [Alias('IgnoreWarnings')]    
	    [switch]$IgnoreNonFatalErrors,
	
	    [switch]$IncludeArchives,
	
	    [string[]]$Exclude
	)
	
	
	# Ensure that the input path is a valid directory
	$Path = EnsureDirectory $Path $false
	
	Write-Verbose "Creating archive with 7-zip version '$($version.ProductVersion)'..."
	
	if (!(Test-Path $Path)) {
	    throw "Path '$($Path)' doesn't exist."
	}
	else {
	    $destinationItem = Get-Item $DestinationPath -ErrorAction SilentlyContinue
	
	    if ($destinationItem -and $destinationItem.PSIsContainer) {
	        # An existing directory was given, so put a new zip file in it, named based on the input path.
	        $DestinationPath = Join-Path $DestinationPath  "$(Split-Path $Path -Leaf).zip"
	        $destinationItem = Get-Item $DestinationPath -ErrorAction SilentlyContinue
	    }
	
	    if ($destinationItem -and !$destinationItem.PSIsContainer -and $Force.IsPresent) {
	        # Attempt to remove an existing file if '-Force' is specified.
	        Remove-Item $DestinationPath -Force | Out-Null
	        $destinationItem = Get-Item $DestinationPath -ErrorAction SilentlyContinue
	    }
	
	    if ($destinationItem -and !$destinationItem.PSIsContainer) {
	        # Fail if the destination path exists and is not a directory. If '-Force' was
	        # specified, this means that it could not be removed. Otherwise, the
	        # user should pass the '-Force' parameter if that is their intention.
	        if ($Force.IsPresent) {
	            throw "Could not remove the existing item at '$($DestinationPath)'."
	        }
	        else {
	            throw "Item exists at '$($DestinationPath)', you can specify '-Force' to remove it."
	        }
	    }
	
	    $arguments = "a -tzip"
	
	    if ($DestinationPath -match "^.+\.zip$") {
	        $arguments += " ""$DestinationPath"""
	    }
	    else {
	        # If the item doesn't doesn't have the 'zip' extension, assume that it is
	        # a directory and put a new zip file in it, named based on the input path.
	        $arguments += " ""$(Join-Path $DestinationPath "$(Split-Path $Path -Leaf).zip")"""
	    }
	
	    $inputItem = Get-Item $Path
	    if ($inputItem.PSIsContainer) {
	        if ($IncludeArchives.IsPresent) {
	            $childItems = Get-ChildItem $Path
	        } else {
	            $childItems = Get-ChildItem $Path -Exclude *.zip
	        }
	
	        $childItems | ForEach-Object {
	            if ($Recurse -or !$_.PSIsContainer) {
	                $arguments += " ""$($_.FullName)"""
	            }
	        }
	    }
		else {
			$arguments += " ""$Path"""
		}
	
	    if ($Recurse) {
	        $arguments += " -r"
	    }
	
	    $arguments += " -y"
	
	    if (-not($IncludeArchives.IsPresent)) {
	        $arguments += " -ax!*"
	    }
	
	    $excludeListFiles = @()
	
	    foreach ($x in $Exclude) {
	        if ([System.IO.Path]::IsPathRooted($x)) {
	            if (Test-Path $x) {
	                $excludeListFiles += (Resolve-Path $x).Path
	            } else {
	                Write-Warning "Path '$($x)' doesn't exist."
	                $excludeListFiles += $x
	            }
	        } elseif ($x -like '*\*') {
	            $arguments += " -x!"
	            if ($xPath -like '* *') {
	                $arguments += "`"$($x)`""
	            } else {
	                $arguments += "$($x)"
	            }
	        } else {
	            $arguments += " -xr!"
	            if ($xPath -like '* *') {
	                $arguments += "`"$($x)`""
	            } else {
	                $arguments += "$($x)"
	            }
	        }
	    }
	
	    if ($excludeListFiles) {
	        $listfile = [IO.Path]::GetTempFileName()
	
	        $excludeListFiles | Out-File $listfile -Encoding UTF8
	
	        $arguments += " -x@"
	        if ($listfile -like '* *') {
	            $arguments += "`"$($listfile)`""
	        } else {
	            $arguments += $listfile
	        }
	    }
	
	    Write-Verbose $arguments
	
	    $returnType = 'None'
	
	    if ($Silent.IsPresent) {
	        $returnType = 'Output'
	    }
	
	    $validExitCodes = @(0)
	
	    if ($IgnoreNonFatalErrors.IsPresent) {
	        $validExitCodes += 1
	    }
	
	    $output = Invoke-Application -FilePath $7zipExe -Arguments $arguments -EnsureSuccess $true -ValidExitCodes $validExitCodes -ReturnType $returnType
	
	    if ($Silent.IsPresent) {
	        ($output -split "`r`n") | ForEach-Object {
	            if ($_ -like 'WARNING: *') {
	                Write-Warning ($_.Substring(9))
	            }
	        }
	    }
	}
}

function Expand-Archive {
	[CmdletBinding()]
	param(
	    [Parameter(Position=0, Mandatory=$true, HelpMessage="The path to the file to extract.")]
	    [Alias("InputPath")]
	    [string]$Path,
	
	    [Parameter(Position=1, Mandatory=$false, HelpMessage="The path to the directory to extract the files to.")]
	    [Alias("OutputPath")]
	    [string]$DestinationPath,
	
	    [Parameter(HelpMessage="If the input path is not a '.zip' file, but you know that it is a file that 7zip can handle.")]
	    [switch]$SuppressExtensionCheck,
	
	    [Parameter(HelpMessage="Unzip all files to the top-level of the destination directory.")]
	    [switch]$Flatten,
	
	    [Parameter(HelpMessage="Don't write output from the 7-zip command.")]
	    [switch]$Silent,
	
	    [switch]$Force,
	
	    [Alias('IgnoreWarnings')]    
	    [switch]$IgnoreNonFatalErrors
	)
	
	
	# Ensure that the destination path is a valid directory if specified
	$DestinationPath = EnsureDirectory $DestinationPath $true
	
	Write-Verbose "Extracting archive with 7-zip version '$($version.ProductVersion)'..."
	
	if (!(Test-Path $Path)) {
	    throw "Path '$($Path)' doesn't exist."
	}
	else {
	    $item = Get-Item $Path
	    if ($item.PSIsContainer) {
	        throw "Input path should be a file, not a directory."
	    }
	    elseif (!$SuppressExtensionCheck.IsPresent -and !($Path -match "^.+\.zip$")) {
	        throw "Input path must be a valid ZIP file."
	    }
	
	    $destinationItem = Get-Item $DestinationPath -ErrorAction SilentlyContinue
	
	    if ($destinationItem) {
	        if (!$destinationItem.PSIsContainer) {
	            # Fail if the destination path exists and is not a directory. If '-Force' was
	            # specified, this means that it could not be removed. Otherwise, the
	            # user should pass the '-Force' parameter if that is their intention.
	            throw "File exists at '$($DestinationPath)', should be a directory if it exists."
	        }
	        else {
	            $isNonEmpty = $false
	            Get-ChildItem $destinationItem -Force | ForEach-Object {
	                $isNonEmpty = $true
	            }
	            if ($isNonEmpty) {
	                if ($Force.IsPresent) {
	                    Write-Verbose "Overwriting existing files in '$($DestinationPath)'."
	                } else {
	                    throw "Destination directory '$($DestinationPath)' is non-empty."
	                }
	            }
	        }
	    }
	
	    if ($Flatten.IsPresent) {
	        $arguments = "e"
	    }
	    else {
	        $arguments = "x"
	    }
	
	    $arguments += " ""-o$DestinationPath"""
	
	    $arguments += " ""$Path"""
	
	    $arguments += " -y"
	
	    Write-Verbose $arguments
	
	    $returnType = 'None'
	
	    if ($Silent.IsPresent) {
	        $returnType = 'Output'
	    }
	
	    $validExitCodes = @(0)
	
	    if ($IgnoreNonFatalErrors.IsPresent) {
	        $validExitCodes += 1
	    }
	 
	    $output = Invoke-Application -FilePath $7zipExe -Arguments $arguments -EnsureSuccess $true -ValidExitCodes $validExitCodes -ReturnType $returnType
	    
	    if ($Silent.IsPresent) {
	        ($output -split "`r`n") | ForEach-Object {
	            if ($_ -like 'WARNING: *') {
	                Write-Warning ($_.Substring(9))
	            }
	        }
	    }
	}
}

