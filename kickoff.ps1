$basedir=$PSScriptRoot
. $basedir\scripts\CloudImageCSV.ps1
. $basedir\scripts\UrlDownload.ps1
. $basedir\scripts\GzExtract.ps1
. $basedir\scripts\Print.ps1

$sw = [Diagnostics.Stopwatch]::StartNew()
$Profile_Name = Split-Path $args[0] -leaf 
$Profile_Path = Convert-Path($args[0]) 

Write-Host ( "##### Installing wsl instance using Profile {0} ##### " -f $Profile_Path)

# $distro_name = ""
# $install_method=""
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
    Write-Host "##### Distro name present in already installed distros list. cannot reinstall. exiting."
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
    distro_name     = $distro_name
    ps_distro_source = $ps_distro_source
    distro_lookupid  = $distro_lookupid
    ps_install_dir   = $ps_install_dir
    ps_logfile = "$basedir\$Profile_Name.log"
}  
Display-SpinupParams @params

$dummyoutput = (mkdir $ps_install_dir  -ea 0)
$dummyoutput = (wsl --import $distro_name $ps_install_dir $ps_distro_source)

$dummyoutput = (wsl --terminate $distro_name)

$Profile_Path_unix = (($Profile_Path.replace('\','/')).replace('D:','/mnt/d')).replace('C:','/mnt/c')
$basedir_unixpath = (($PSScriptRoot.replace('\','/')).replace('D:','/mnt/d')).replace('C:','/mnt/c')

Write-Host( "##### Installing Prerequisites for the {0} instance ... " -f "$distro_name")
$dummyoutput = (wsl -d $distro_name $basedir_unixpath/prep-install.sh $Profile_Path_unix -u root) 

$dummyoutput | Out-File   "$basedir\$Profile_Name.log"

Write-Host( "##### Configuring  {0} instance... " -f "$distro_name")
$dummyoutput2 = (wsl -d $distro_name  $basedir_unixpath/install.sh  $Profile_Path_unix -u root) 2>&1 >  "$basedir\$Profile_Name.err"
$dummyoutput2 | Out-File -append  ("$basedir\$Profile_Name.log")

Write-Host( "##### Restarting {0} instance... " -f "$distro_name")
wsl --terminate $distro_name

$dummyoutput=(wsl -d $distro_name ls /)
Write-Host( "##### Instance  {0} ready. " -f "$distro_name")

if (Test-Path $basedir\tmp\$uncompressedFileName) {
  Remove-Item -Path $basedir\tmp\$uncompressedFileName -Force
} 

$sw.Stop()
$ts = $sw.Elapsed;
$elapsedTime = [string]::Format("{0:00} Hours :{1:00} Mins :{2:00} Secs",$ts.Hours, $ts.Minutes, $ts.Seconds);
Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")
