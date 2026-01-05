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

function ConvertTo-WslPath {
    param (
        [Parameter(Mandatory=$true)]
        [string]$WindowsPath
    )
    
    # Convert backslashes to forward slashes
    $unixPath = $WindowsPath.Replace('\', '/')
    
    # Normalize multiple consecutive slashes to single slash (except at start for UNC)
    # Preserve leading // for potential UNC-like paths
    if ($unixPath -match '^//') {
        # UNC path - keep the leading // but normalize the rest
        $unixPath = '//' + ($unixPath.Substring(2) -replace '/+', '/')
    } else {
        $unixPath = $unixPath -replace '/+', '/'
    }
    
    # Convert drive letter (C: -> /mnt/c) with lowercase drive letter
    if ($unixPath -match '^([A-Za-z]):') {
        $driveLetter = $matches[1].ToLower()
        $unixPath = "/mnt/$driveLetter" + $unixPath.Substring(2)
    }
    
    return $unixPath
}
