$distro_type_param=$args[0]

$Path = ".\variables.sh"
# $distro_name = ""
$file = get-content $Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_name_ubuntu"){$distro_name_ubuntu = $items[1]}   
  if ($items[0] -eq "export distro_name_fedora"){$distro_name_fedora = $items[1]}   
  if ($items[0] -eq "export distro_name_alpine"){$distro_name_alpine = $items[1]}   

  if ($items[0] -eq "export ps_distro_source_ubuntu"){$ps_distro_source_ubuntu = $items[1]}   
  if ($items[0] -eq "export ps_distro_source_fedora"){$ps_distro_source_fedora = $items[1]}   
  if ($items[0] -eq "export ps_distro_source_alpine"){$ps_distro_source_alpine = $items[1]}   

  # if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]+"\"+$distro_name}
  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]}
}

if ($distro_type_param -eq "ubuntu"){  
      Write-Host ( "##### distro type ubuntu {0}  " -f $distro_type_param)
      $distro_name = $distro_name_ubuntu
      $distro_type = "ubuntu"
      $ps_distro_source = $ps_distro_source_ubuntu
      $ps_install_dir = $ps_install_dir+"\"+$distro_name_ubuntu
  } elseif ($distro_type_param -eq "fedora"){  
        Write-Host ( "##### distro type fedora {0}  " -f $distro_type_param)
        $distro_name = $distro_name_fedora
        $distro_type = "fedora"
        $ps_distro_source = $ps_distro_source_fedora
        $ps_install_dir = $ps_install_dir+"\"+$distro_name_fedora
    } elseif ($distro_type_param -eq "alpine"){  
        Write-Host ( "##### distro type alpine {0}  " -f $distro_type_param)
        $distro_name = $distro_name_alpine
        $distro_type = "alpine"
        $ps_distro_source = $ps_distro_source_alpine
        $ps_install_dir = $ps_install_dir+"\"+$ps_distro_source_alpine
      } else {
        Write-Host ( "##### Specify a distro type as param (ubuntu/fedora/alpine) " )
        Exit 
      } 

Write-Host ( 
    "#####  Teardown params 
        distro type : {0} 
        distro_name : {1} 
        distro source : {2} " -f $distro_type, $distro_name, $ps_distro_source)
Read-Host -Prompt "Press any key to continue"

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


