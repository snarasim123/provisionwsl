$profile_name=$args[0]

$Path = ".\profile\"+$profile_name
Write-Host ( "#####  Install Profile {0} ##### " -f $Path)

$distro_name = ""
$file = get-content $Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_type"){$distro_type = $items[1]}
  if ($items[0] -eq "export distro_name"){$distro_name = $items[1]}
  if ($items[0] -eq "export ps_distro_source"){$ps_distro_source = $items[1]}
  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]}
  if ($items[0] -eq "export debug_mode"){$debug_mode = $items[1]}
}

Write-Host ( 
"#####  Teardown params
          distro type   : {0} 
          distro_name   : {1} 
          distro source : {2}
#####   " -f $distro_type, $distro_name, $ps_distro_source)

# Read-Host -Prompt "Press any key to continue"
$install_name=$distro_name

Write-Host ( "##### Teardown  {0} from dir {1} " -f $install_name,$ps_install_dir)

$match=((wsl -l | Where {$_.Replace("`0","") -match "$install_name"}))
if ($match -eq "$install_name") {
    Write-Host ( "##### Instance exists. Tearing down {0}... " -f $install_name)
    $i=5
    Write-Host ( "Wait {0} Seconds"  -f $i)
    while ($i -gt 0){
        write-host -nonewline ("#")
        sleep 1
        $i--
    }
    write-host  ("")
    wsl  --unregister  $install_name
    # rmdir $ps_install_dir -ea 0
}
else {
    Write-Host( "##### Instance with name {0} does not exist. returning... " -f "$install_name")    
}


