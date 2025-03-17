$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
. $dir\scripts\CloudImageCSV.ps1

$profile_name=$args[0]

$sw = [Diagnostics.Stopwatch]::StartNew()
$Profile_Path = [IO.Path]::GetFullPath($profile_name) 
Write-Host ( "#####  Install Profile {0} ##### " -f $Profile_Path)

$distro_name = ""
$file = get-content $Profile_Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_type"){$distro_type = $items[1]}
  if ($items[0] -eq "export distro_name"){$distro_name = $items[1]}
  if ($items[0] -eq "export ps_distro_source"){$ps_distro_source = $items[1]}
  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]}
  if ($items[0] -eq "export debug_mode"){$debug_mode = $items[1]}
  if ($items[0] -eq "export ps_distro_id"){$distro_lookupid = $items[1]}
}

$install_name=$distro_name
$ps_install_dir = $ps_install_dir+"\"+$distro_name

if($ps_distro_source -eq ""){
    $ps_distro_source="cloud download"
    Init-CloudImageDb
    $imageurl1 = Get-CloudImageURL  -ID $distro_lookupid
    if($imageurl1 -eq ""){
      Write-Host ( "#####  invalid cloud image name, cannot resolve ps_distro_id to a valid download url")

    }
  }
Write-Host ( 
"#####  Spinup params
          distro type       : {0} 
          distro_name       : {1} 
          distro source     : {2} 
          install location  : {3}
#####  " -f $distro_type, $install_name, $ps_distro_source,$ps_install_dir)

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

if ($debug_mode -eq "check"){
      Write-Host ( "##### Running in check mode.  ")
      # todo turn it on
      # wsl -d $install_name  ./install.sh  $distro_type --check -u root
      exit
  }


Write-Host( "##### Preliminary setup  {0} Step 2... " -f "$install_name")
$Profile_Path_unix = $Profile_Path.replace('\','/')
wsl -d $install_name ./prep-install.sh $Profile_Path_unix -u root

Write-Host( "##### Main setup  {0} Step 3... " -f "$install_name")
wsl -d $install_name  ./install.sh  $Profile_Path_unix -u root

Write-Host( "##### Restarting instance  {0}... " -f "$install_name")
wsl --terminate $install_name
wsl -d $install_name lsb_release -d 
wsl -d $install_name ls /
Write-Host( "##### Instance  {0} ready. " -f "$install_name")

$sw.Stop()
$ts = $sw.Elapsed;
$elapsedTime = [string]::Format("{0:00} Hours :{1:00} Mins",$ts.Hours, $ts.Minutes);
Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")

 # Write-Host ( "##### Creating  {0} from source {1} to dir {2} " -f $install_name,$ps_distro_source, $ps_install_dir)
# Read-Host -Prompt "Press any key to continue"
