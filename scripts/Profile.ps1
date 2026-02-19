function Get-Profile {
    param(
        [string]$ProfilePath,
        [ref]$DistroSource,
        [ref]$InstallDir,
        [ref]$LookupId
    )
    
    $file = get-content $ProfilePath
    $file | foreach {
        $items = $_.split("=")
        if ($items[0] -eq "export ps_distro_source"){$DistroSource.Value = $items[1]}
        if ($items[0] -eq "export ps_install_dir"){$InstallDir.Value = $items[1]}
        if ($items[0] -eq "export ps_distro_id"){$LookupId.Value = $items[1]}
    }
}

function Get-TargetUser {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BaseDir
    )
    $varsFile = Join-Path $BaseDir "vars\user_environment.yml"
    if (-not (Test-Path $varsFile)) {
        Write-Error "Ansible vars file not found: $varsFile"
        return $null
    }
    $target_user = $null
    Get-Content $varsFile | ForEach-Object {
        if ($_ -match '^\s*target_user:\s*(.+)$') { $target_user = $Matches[1].Trim() }
    }
    return $target_user
}
