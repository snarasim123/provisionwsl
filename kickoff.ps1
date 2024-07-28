$distro_type_param=$args[0]

$sw = [Diagnostics.Stopwatch]::StartNew()
$Path = ".\variables.sh"
$distro_name = ""
$file = get-content $Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_name_ubuntu"){$distro_name_ubuntu = $items[1]}   
  if ($items[0] -eq "export distro_name_fedora"){$distro_name_fedora = $items[1]}   
  if ($items[0] -eq "export distro_name_alpine"){$distro_name_alpine = $items[1]}   

  if ($items[0] -eq "export ps_distro_source_ubuntu"){$ps_distro_source_ubuntu = $items[1]}   
  if ($items[0] -eq "export ps_distro_source_fedora"){$ps_distro_source_fedora = $items[1]}   
  if ($items[0] -eq "export ps_distro_source_alpine"){$ps_distro_source_alpine = $items[1]}   

  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]}
  # if ($items[0] -eq "export source_base"){$source_base = $items[1]}  
  # if ($items[0] -eq "export light_install"){$light_install = $items[1]} 
  # if ($items[0] -eq "export install_file"){$install_file = $items[1]} 
  # if ($items[0] -eq "export fedora_source_base"){$fedora_source_base = $items[1]} 
  # if ($items[0] -eq "export default_user"){$default_user = $items[1]} 
  }

if ($distro_type_param -eq "ubuntu"){  
      # Write-Host ( "##### distro type  {0}  " -f $distro_type_param)
      $distro_name = $distro_name_ubuntu
      $distro_type = "ubuntu"
      $ps_distro_source = $ps_distro_source_ubuntu      
  } elseif ($distro_type_param -eq "fedora"){  
        # Write-Host ( "##### distro type  {0}  " -f $distro_type_param)
        $distro_name = $distro_name_fedora
        $distro_type = "fedora"
        $ps_distro_source = $ps_distro_source_fedora
    } elseif ($distro_type_param -eq "alpine"){  
        # Write-Host ( "##### distro type  {0}  " -f $distro_type_param)
        $distro_name = $distro_name_alpine
        $distro_type = "alpine"
        $ps_distro_source = $ps_distro_source_alpine
      } else {
        Write-Host ( "##### Specify a distro type as param (ubuntu/fedora/alpine) " )
        Exit 
      } 



$install_name=$distro_name
$ps_install_dir = $ps_install_dir+"\"+$distro_name

Write-Host ( 
  "#####  Spinup params - 
        distro type : {0} 
        distro_name : {1} 
        distro source : {2} 
        install location: {3}" -f $distro_type, $install_name, $ps_distro_source,$ps_install_dir)
# Write-Host ( "##### Creating  {0} from source {1} to dir {2} " -f $install_name,$ps_distro_source, $ps_install_dir)
Read-Host -Prompt "Press any key to continue"

$match=((wsl -l | Where {$_.Replace("`0","") -match "$install_name"}))
if ($match -eq "$install_name") {
    Write-Host ( "##### Instance exists. Skip creating instance with name {0}... " -f $install_name)
}
else {
    Write-Host( "##### Creating new instance with name {0} Step 1... " -f "$install_name")
    mkdir $ps_install_dir  -ea 0
    wsl --import $install_name $ps_install_dir $ps_distro_source
}

Write-Host( "##### Restarting instance  {0}... " -f "$install_name")
wsl --terminate $install_name
# wsl -d $install_name lsb_release -d 

Write-Host( "##### Preliminary setup  {0} Step 2... " -f "$install_name")
wsl -d $install_name ./prep-install.sh $distro_type -u root
wsl -d $install_name  ./install.sh  $distro_type -u root

Write-Host( "##### Restarting instance  {0}... " -f "$install_name")
wsl --terminate $install_name
wsl -d $install_name lsb_release -d 

Write-Host( "##### Instance  {0} ready. " -f "$install_name")
$sw.Stop()
$ts = $sw.Elapsed;
$elapsedTime = [string]::Format("{0:00} Hours :{1:00} Mins",$ts.Hours, $ts.Minutes);
Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")

 