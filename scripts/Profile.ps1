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
