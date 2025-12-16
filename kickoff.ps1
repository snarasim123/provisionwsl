param(
    [Parameter(Position=0)]
    $ProfilePath
)

$basedir=$PSScriptRoot
. $basedir\scripts\PathUtils.ps1
. $basedir\scripts\CloudInstallPrep.ps1
. $basedir\scripts\CloudImageCSV.ps1
. $basedir\scripts\UrlDownload.ps1
. $basedir\scripts\GzExtract.ps1
. $basedir\scripts\XzExtract.ps1
. $basedir\scripts\CompressionUtils.ps1
. $basedir\scripts\Print.ps1

$UrlsCsvPath = ".\data\urls.csv"


function Run-Kickoff {
  param($ProfilePath)

  $Profile_Path = Get-ValidatedAbsolutePath -Path $ProfilePath -ScriptRoot $PSScriptRoot
  $Profile_Name = Split-Path $Profile_Path -leaf 
  $Urls_Csv_Path = Get-ValidatedAbsolutePath -Path $UrlsCsvPath -ScriptRoot $PSScriptRoot

  Write-Host ( "##### Installing wsl instance using Profile {0} ##### " -f $Profile_Path)

  $file = get-content $Profile_Path
  $file | foreach {
    $items = $_.split("=")
    if ($items[0] -eq "export ps_distro_source"){$ps_distro_source = $items[1]}
    if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]}
    if ($items[0] -eq "export ps_distro_id"){$distro_lookupid = $items[1]}
  }


  $distro_name = Split-Path $Profile_Path -Leaf


if ([string]::IsNullOrWhiteSpace($ps_install_dir) -or [string]::IsNullOrEmpty($ps_install_dir)) {
    $ps_install_dir = $PSScriptRoot+"\install\"+$distro_name
} else {
  $ps_install_dir = $ps_install_dir+"\"+$distro_name
}

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
  $ps_distro_source = Prepare-CloudInstall -UrlsCsvPath $Urls_Csv_Path -DistroLookupId $distro_lookupid -BaseDir $basedir
}

Display-SpinupParams  $distro_name $ps_distro_source $distro_lookupid $ps_install_dir "$basedir\$Profile_Name.log"


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

}

$sw = [Diagnostics.Stopwatch]::StartNew()

Run-Kickoff -ProfilePath $ProfilePath 

$sw.Stop()
$ts = $sw.Elapsed;
$elapsedTime = [string]::Format("{0:00} Hours :{1:00} Mins :{2:00} Secs",$ts.Hours, $ts.Minutes, $ts.Seconds);
Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")