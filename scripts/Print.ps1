function Display-SpinupParams {
    param (
        [string]$distro_name,
        [string]$ps_distro_source,
        [string]$distro_lookupid,
        [string]$ps_install_dir,
        [string]$ps_logfile
    )

    Write-Host (
        "##### Spinup params
          distro_name             : {0} 
          distro source           : {1} 
          distro id (from cloud)  : {2}
          install location        : {3}
          log file                : {4}
        " -f $distro_name, $ps_distro_source, $distro_lookupid, $ps_install_dir,$ps_logfile
    )
}