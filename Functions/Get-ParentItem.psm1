function Get-ParentItem {
	[CmdletBinding()]
	param(
	    [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
	    [string[]]$Path,
	
	    [switch]$Recurse
	)
	
	begin {
	    if (-not(Test-Path $Path)) {
	        Write-Error "Path '$($Path)' could not be found."
	        return
	    }
	}
	
	process {
	    foreach ($fromPath in $Path) {
	        do {
	            $fromPath = Resolve-Path $fromPath
	            $parentPath = Split-Path $fromPath -Parent
	            if ($parentPath) {
	                Write-Output (Get-Item $parentPath)
	            }
	            $fromPath = $parentPath
	        } while ($Recurse.IsPresent -and $fromPath)
	    }
	}
}
