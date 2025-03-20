$basedir=$PSScriptRoot
. $basedir\scripts\CloudImageCSV.ps1
. $basedir\scripts\UrlDownload.ps1
. $basedir\scripts\GzExtract.ps1
. $basedir\scripts\Print.ps1

$profile_name=$args[0]

$sw = [Diagnostics.Stopwatch]::StartNew()
$formattedTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Start Provision/configuration at: $formattedTime"

$Profile_Path = Convert-Path($profile_name) 

Write-Host ( "##### Installing wsl instance using Profile {0} ##### " -f $Profile_Path)

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
  # Write-Host( "##### Downloading source .gz from cloud. ")
} else {  
  $install_method="local"
  # Write-Host( "##### Using local source .gz file from disk. ")
}

$distroslist=(wsl -l) 
foreach ($i in $distroslist) {
  $finalstring=($i.ToString().Replace("`0",""))
  $found=($finalstring  -match  $distro_name)
  if ($found) {
    Write-Host "##### Distro name already in installed distros list. cannot reinstall. exiting."
    exit
  } 
}

if($ps_distro_source -eq "" -And $distro_lookupid -eq ""){
    Write-Host ( "##### No distro .tar file (export ps_distro_source) or cloud image id (export distro_lookupid) in profile file. exiting.")
    exit
}

if($install_method -eq "cloud"){    
  $initresult = Init-CloudImageDb
  $imageurl1 = Get-CloudImageURL  -ID $distro_lookupid
  if($imageurl1 -eq ""){
    Write-Host ( "##### invalid cloud image name, cannot resolve ps_distro_id to a valid download url. exiting")
    exit
  }

  $compressedFile = [System.IO.Path]::GetFileName($imageurl1)
  $compressedFilePath = Join-Path -Path $basedir\tmp\ -ChildPath $compressedFile  
  $uncompressedFileName = GetUncompressedFileName  -infile $compressedFile

  if (-not (Test-Path -Path $compressedFilePath)) {
    Write-Host "The file $compressedFilePath\$compressedFile does not exist. downloading..."
    Download-URL -Url $imageurl1 -FolderLocation $basedir\tmp\
  } 
  $resultfile = DeGZip-File -infile $compressedFilePath
  $ps_distro_source="$basedir\tmp\$uncompressedFileName"
}
$params = @{
    distro_type      = $distro_type
    install_name     = $install_name
    ps_distro_source = $ps_distro_source
    distro_lookupid  = $distro_lookupid
    ps_install_dir   = $ps_install_dir
}  
Display-SpinupParams @params

mkdir $ps_install_dir  -ea 0
wsl --import $install_name $ps_install_dir $ps_distro_source

Write-Host( "##### Restarting {0} instance... " -f "$install_name")
wsl --terminate $install_name
wsl -d $install_name lsb_release -d

Write-Host( "##### Installing Prerequisites in {0} instance ... " -f "$install_name")
$Profile_Path_unix = (($Profile_Path.replace('\','/')).replace('D:','/mnt/d')).replace('C:','/mnt/c')
$basedir_unixpath = (($PSScriptRoot.replace('\','/')).replace('D:','/mnt/d')).replace('C:','/mnt/c')

wsl -d $install_name $basedir_unixpath/prep-install.sh $Profile_Path_unix -u root

Write-Host( "##### Configuring  {0} instance... " -f "$install_name")
wsl -d $install_name  $basedir_unixpath/install.sh  $Profile_Path_unix -u root

Write-Host( "##### Restarting {0} instance... " -f "$install_name")
wsl --terminate $install_name
wsl -d $install_name lsb_release -d 
wsl -d $install_name ls /
Write-Host( "##### Instance  {0} ready. " -f "$install_name")



if (Test-Path $basedir\tmp\$uncompressedFileName) {
  Remove-Item -Path $basedir\tmp\$uncompressedFileName -Force
  Write-Host "##### Cleaned up leftover install source files : $basedir\tmp\$uncompressedFileName"
} 

$sw.Stop()
$ts = $sw.Elapsed;
$elapsedTime = [string]::Format("{0:00} Hours :{1:00} Mins :{2:00} Secs",$ts.Hours, $ts.Minutes, $ts.Seconds);
Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")
$formattedTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host "Finished at: $formattedTime"

# test relatve path from same folder, same drive, different drive
# test absolute path from same drive, different drive
#     d:\code\setup\ansible\kickoff.ps1 D:\code\setup\ansible\profiles\r37-alp320-mini - fails
# add support for few more drives