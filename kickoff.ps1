$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$basedir=$PSScriptRoot
. $basedir\scripts\CloudImageCSV.ps1
. $basedir\scripts\UrlDownload.ps1
. $basedir\scripts\GzExtract.ps1

$profile_name=$args[0]

$sw = [Diagnostics.Stopwatch]::StartNew()
$Profile_Path = Convert-Path($profile_name) 

Write-Host ( "#####  Install Profile {0} ##### " -f $Profile_Path)

$distro_name = ""
$install_method=""
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
if($ps_distro_source -eq "" -or $ps_distro_source -eq $null){
  $install_method="cloud"
} else {
  $install_method="local"
}

$distroslist=(wsl -l) 
foreach ($i in $distroslist) {
  $finalstring=($i.ToString().Replace("`0",""))
  $found=($finalstring  -match  $distro_name)
  if ($found) {
    Write-Host "Distro name already in installed distros list. cannot reinstall. exiting."
    exit
  } 
}

if($ps_distro_source -eq "" -And $distro_lookupid -eq ""){
    Write-Host ( "#####  No distro .tar file (export ps_distro_source) or cloud image id (export distro_lookupid) in profile file. exiting.")
    exit
}

if($install_method -eq "cloud"){    
  Init-CloudImageDb
  $imageurl1 = Get-CloudImageURL  -ID $distro_lookupid
  if($imageurl1 -eq ""){
    Write-Host ( "#####  invalid cloud image name, cannot resolve ps_distro_id to a valid download url. exiting")
    exit
  }
  # parse filename from imageurl
  $compressedFile = [System.IO.Path]::GetFileName($imageurl1)
  #  check if file exists under $dir\tmp, if yes, skip out of this method
  $compressedFilePath = Join-Path -Path $basedir\tmp\ -ChildPath $compressedFile
  $uncompressedFileName = GetUncompressedFileName  -infile $compressedFile
  if (-not (Test-Path -Path $compressedFilePath)) {
    Write-Host "The file does not exist. downloading..."
    Download-URL -Url $imageurl1 -FolderLocation $basedir\tmp\
    # extract tar file    
  } 
  DeGZip-File -infile $compressedFilePath
  $ps_distro_source="$basedir\tmp\$uncompressedFileName"
  # populate distro_source var and continue out of this method.  
  # need to have $ps_distro_source populated correctly by end of this method
}


Write-Host ( 
"#####  Spinup params
          distro type             : {0} 
          distro_name             : {1} 
          distro source           : {2} 
          distro id (from cloud)  : {3}
          install location        : {4}
#####  " -f $distro_type, $install_name, $ps_distro_source,$distro_lookupid,$ps_install_dir)




Write-Host( "##### Creating new instance with name {0} Step 1... " -f "$install_name")
mkdir $ps_install_dir  -ea 0
wsl --import $install_name $ps_install_dir $ps_distro_source


Write-Host( "##### Restarting instance  {0}... " -f "$install_name")
wsl --terminate $install_name
# wsl -d $install_name lsb_release -d


Write-Host( "##### Preliminary setup  {0} Step 2... " -f "$install_name")
# Write-Host "Profile_Path result type "+ $Profile_Path.GetType()  
$Profile_Path_unix = ($Profile_Path.replace('\','/')).replace('D:','/mnt/d')
$basedir_unixpath = ($PSScriptRoot.replace('\','/')).replace('D:','/mnt/d')
wsl -d $install_name $basedir_unixpath/prep-install.sh $Profile_Path_unix -u root
# wsl -d $install_name ./prep-install.sh /mnt/d/code/setup/ansible/profiles/r37-ubu2004-test1 -u root

Write-Host( "##### Main setup  {0} Step 3... " -f "$install_name")
wsl -d $install_name  $basedir_unixpath/install.sh  $Profile_Path_unix -u root
# wsl -d $install_name  ./install.sh  "/mnt/d/code/setup/ansible/profiles/r37-ubu2004-test1"  -u root

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

# test relatve path from same folder, same drive, different drive
# test absolute path from same drive, different drive
#     d:\code\setup\ansible\kickoff.ps1 D:\code\setup\ansible\profiles\r37-alp320-mini - fails
# add support for few more drives