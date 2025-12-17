function Write-Log {
    param(
        [Parameter(Position=0)]
        [string]$Message,
        [string]$LogFile
    )
    Write-Host $Message
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        $Message | Out-File -Append $LogFile
    }
}