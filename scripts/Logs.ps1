function Get-LogFilePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseDir,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Suffix = ""
    )
    
    if ([string]::IsNullOrWhiteSpace($Suffix)) {
        return Join-Path $BaseDir "$Name.log"
    } else {
        return Join-Path $BaseDir "$Name-$Suffix.log"
    }
}

function Init-LogFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogFile
    )
    $null = New-Item -Path $LogFile -ItemType File -Force
}

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