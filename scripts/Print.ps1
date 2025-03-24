function Display-SpinupParams {
    param (
        [string]$distro_type,
        [string]$install_name,
        [string]$ps_distro_source,
        [string]$distro_lookupid,
        [string]$ps_install_dir,
        [string]$ps_logfile
    )

    Write-Host (
        "##### Spinup params
          distro type             : {0} 
          distro_name             : {1} 
          distro source           : {2} 
          distro id (from cloud)  : {3}
          install location        : {4}
          log file                : {5}
        " -f $distro_type, $install_name, $ps_distro_source, $distro_lookupid, $ps_install_dir,$ps_logfile
    )
}