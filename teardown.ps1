$Path = ".\variables.sh"
# $distro_name = ""
$file = get-content $Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_name"){$distro_name = $items[1]}   
  if ($items[0] -eq "export ps_distro_source"){$ps_distro_source = $items[1]}   
  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]+"\"+$distro_name}
  if ($items[0] -eq "export source_base"){$source_base = $items[1]}  
}

$install_name=$distro_name

Write-Host ( "##### Teardown  {0} from dir {1} " -f $install_name,$ps_install_dir)

$match=((wsl -l | Where {$_.Replace("`0","") -match "$install_name"}))
if ($match -eq "$install_name") {
    Write-Host ( "##### Instance exists. Tearing down {0}... " -f $install_name)
    wsl  --unregister  $install_name
    rmdir $ps_install_dir -ea 0
}
else {
    Write-Host( "##### Instance with name {0} does not exist. returning... " -f "$install_name")    
}


