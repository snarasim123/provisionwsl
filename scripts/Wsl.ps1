function Assert-WslAvailable {
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        Write-Error "WSL is not installed or not available in PATH. Please install WSL first."
        exit 1
    }
}

function Test-DistroExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DistroName
    )
    $existingDistros = (wsl -l -q) -replace "`0", "" | Where-Object { $_ -ne "" }
    return ($DistroName -in $existingDistros)
}
