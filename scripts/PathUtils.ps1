function Get-ValidatedAbsolutePath {
    param (
        [string]$Path,
        [string]$ScriptRoot
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        Write-Error "##### ProfilePath is required. exiting."
        exit 1
    }

    if (Test-Path $Path) {
        return (Get-Item $Path).FullName
    }

    # Check if the provided path is already absolute (and just missing)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        Write-Error "##### ProfilePath '$Path' is absolute but does not exist."
        exit 1
    }

    $candidatePath = Join-Path $ScriptRoot $Path
    $candidatePath = [System.IO.Path]::GetFullPath($candidatePath)
    
    if (Test-Path $candidatePath) {
        return $candidatePath
    } else {
        Write-Error "##### Path '$Path' not found. Also failed to find '$candidatePath'."
        exit 1
    }
}
