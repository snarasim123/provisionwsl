param(
    [Parameter(Position=0)]
    $ProfilePath
)

$basedir=$PSScriptRoot
. $basedir\scripts\PathUtils.ps1
. $basedir\scripts\Logs.ps1
. $basedir\scripts\Profile.ps1
. $basedir\scripts\Wsl.ps1
. $basedir\scripts\CloudInstallPrep.ps1
. $basedir\scripts\CloudImageCSV.ps1
. $basedir\scripts\UrlDownload.ps1
. $basedir\scripts\GzExtract.ps1
. $basedir\scripts\XzExtract.ps1
. $basedir\scripts\CompressionUtils.ps1
. $basedir\scripts\Print.ps1

$UrlsCsvPath = $PSScriptRoot+"\data\urls.csv"

function Kickoff {
  param($ProfilePath)

  $Profile_Path = Get-ValidatedAbsolutePath -Path $ProfilePath -ScriptRoot $PSScriptRoot
  $Distro_Name = Split-Path $Profile_Path -Leaf
  $Urls_Csv_Path = Get-ValidatedAbsolutePath -Path $UrlsCsvPath -ScriptRoot $PSScriptRoot

  $LogFile = Get-LogFilePath -BaseDir $basedir -Name $Distro_Name
  "" | Out-File -FilePath $LogFile -Force
  $PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile

  Write-Log ( "`r`n##### Installing wsl instance using Profile {0} ##### " -f $Profile_Path)
  # Read target_user from Ansible vars (single source of truth)
  $Target_User = Get-TargetUser -BaseDir $basedir
  if ([string]::IsNullOrWhiteSpace($Target_User)) {
      Write-Log "\`r\`n##### Could not read target_user from vars/user_environment.yml. exiting."
      exit
  }
  Write-Log ( "\`r\`n##### Target user: {0}" -f $Target_User)
  $Distro_Source = $null; $Install_Dir = $null; $distro_lookupid = $null
  Get-Profile -ProfilePath $Profile_Path -DistroSource ([ref]$Distro_Source) -InstallDir ([ref]$Install_Dir) -LookupId ([ref]$distro_lookupid)

  if ([string]::IsNullOrWhiteSpace($Install_Dir) -or [string]::IsNullOrEmpty($Install_Dir)) {
      $Install_Dir = $PSScriptRoot+"\install\"+$Distro_Name
  } else {
    $Install_Dir = $Install_Dir+"\"+$Distro_Name
  }

  if ([string]::IsNullOrWhiteSpace($Distro_Source)) {
    $install_method="cloud"
  } else {  
    $install_method="local"
  }

  if (Test-DistroExists -DistroName $Distro_Name) {
    Write-Log "`r`n##### Distro name present in already installed distros list. cannot reinstall. exiting."
    exit
  }

  if ([string]::IsNullOrWhiteSpace($Distro_Source) -and [string]::IsNullOrWhiteSpace($distro_lookupid)) {
      Write-Log ( "`r`n##### No distro .tar file (export ps_distro_source) or cloud image id (export distro_lookupid) in profile file. exiting.")
      exit
  }

  if($install_method -eq "cloud"){    
    $Distro_Source = Prepare-CloudInstall -UrlsCsvPath $Urls_Csv_Path -DistroLookupId $distro_lookupid -BaseDir $basedir -LogFile $LogFile
  }

  Display-SpinupParams  $Distro_Name $Distro_Source $distro_lookupid $Install_Dir "$basedir\$Distro_Name.log"

  (mkdir $Install_Dir  -ea 0) | Out-File  "$basedir\$Distro_Name.log"
  (wsl --import $Distro_Name $Install_Dir $Distro_Source) | Out-File  -Append  "$basedir\$Distro_Name.log"
  (wsl --terminate $Distro_Name) | Out-File  -Append  "$basedir\$Distro_Name.log"

  $Profile_Path_unix = ConvertTo-WslPath -WindowsPath $Profile_Path
  $basedir_unixpath = ConvertTo-WslPath -WindowsPath $PSScriptRoot

  Write-Log( "`r`n##### Installing Prerequisites for the {0} instance ... " -f "$Distro_Name")
  wsl -d $Distro_Name ls /
  
  # Install bash first for Alpine (uses sh/ash by default)
  wsl -d $Distro_Name -u root sh -c "command -v bash >/dev/null 2>&1 || apk add --no-cache bash"
  
  (wsl -d $Distro_Name -u root bash $basedir_unixpath/prep-install.sh $Profile_Path_unix $basedir_unixpath $Target_User) | Out-File  -Append  "$basedir\$Distro_Name.log" 

  

  Write-Log( "\`r\`n##### Configuring  {0} instance... " -f "$Distro_Name")
  wsl -d $Distro_Name $basedir_unixpath/install.sh $Profile_Path_unix $basedir_unixpath $Target_User -u root 2>&1 | Tee-Object -Append -FilePath "$basedir\$Distro_Name.log"

  Write-Log( "`r`n##### Restarting {0} instance... " -f "$Distro_Name")
  wsl --terminate $Distro_Name

  $dummyoutput=(wsl -d $Distro_Name ls /)
  Write-Log( "`r`n##### Instance  {0} ready. " -f "$Distro_Name")
}

$sw = [Diagnostics.Stopwatch]::StartNew()
Kickoff -ProfilePath $ProfilePath 
$sw.Stop()

$ts = $sw.Elapsed;
$elapsedTime = [string]::Format("{0:00} Hours :{1:00} Mins :{2:00} Secs",$ts.Hours, $ts.Minutes, $ts.Seconds);
$RunTimeMsg = "##### RunTime  {0}... " -f "$elapsedTime"
Write-Host $RunTimeMsg
$Profile_Path_Global = Get-ValidatedAbsolutePath -Path $ProfilePath -ScriptRoot $PSScriptRoot
$Distro_Name_Global = Split-Path $Profile_Path_Global -leaf 
$RunTimeMsg | Out-File -Append "$basedir\$Distro_Name_Global.log"