
$Path = ".\variables.sh"
$distro_name = ""
$file = get-content $Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_name"){$distro_name = $items[1]}   
  if ($items[0] -eq "export ps_distro_source"){$ps_distro_source = $items[1]}   
  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]+"\"+$distro_name}
  if ($items[0] -eq "export source_base"){$source_base = $items[1]}  
  if ($items[0] -eq "export light_install"){$light_install = $items[1]} 
  if ($items[0] -eq "export install_file"){$install_file = $items[1]} 
  if ($items[0] -eq "export fedora_source_base"){$fedora_source_base = $items[1]} 
  if ($items[0] -eq "export default_user"){$default_user = $items[1]} 
  }

$install_name=$distro_name

Write-Host ( "##### Creating  {0} from source {1} to dir {2} " -f $install_name,$ps_distro_source, $ps_install_dir)

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
wsl -d $install_name lsb_release -d 

Write-Host( "##### Preliminary setup  {0} Step 2... " -f "$install_name")
wsl -d $install_name "./prelude.sh"  -u "$default_user"

Write-Host( "##### Restarting instance  {0}... " -f "$install_name")
wsl --terminate $install_name
wsl -d $install_name lsb_release -d 

# Write-Host( "##### Running ansible setup  {0} Step 3... " -f "$install_name")
# wsl -d $install_name "./run-ansible.sh"  -u "$default_user"


Write-Host( "##### Instance  {0} ready. " -f "$install_name")

 