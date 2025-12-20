function Assert-WslAvailable {
    <#
    .SYNOPSIS
        Verifies that WSL is installed and available in PATH.
    .DESCRIPTION
        Checks if the wsl command is available. Exits with error code 1 if not found.
    #>
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        Write-Error "WSL is not installed or not available in PATH. Please install WSL first."
        exit 1
    }
}

function Test-DistroExists {
    <#
    .SYNOPSIS
        Checks if a WSL distro with the given name already exists.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$DistroName
    )
    $existingDistros = (wsl -l -q) -replace "`0", "" | Where-Object { $_ -ne "" }
    return ($DistroName -in $existingDistros)
}
