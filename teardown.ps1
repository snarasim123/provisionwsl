$basedir = $PSScriptRoot
. $basedir\scripts\Logs.ps1

$Path=$args[0]



$distro_name = ""
$file = get-content $Path
$file | foreach {
  $items = $_.split("=")
  if ($items[0] -eq "export distro_type"){$distro_type = $items[1]}
  if ($items[0] -eq "export distro_name"){$distro_name = $items[1]}
  if ($items[0] -eq "export ps_distro_source"){$ps_distro_source = $items[1]}
  if ($items[0] -eq "export ps_install_dir"){$ps_install_dir = $items[1]}
  if ($items[0] -eq "export debug_mode"){$debug_mode = $items[1]}
}

$LogFile = Get-LogFilePath -BaseDir $basedir -Name $distro_name -Suffix "teardown"
Init-LogFile -LogFile $LogFile
$PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile

Write-Log ( "`r`n#####  Teardown Profile {0} ##### " -f $Path)

Write-Log ( 
"`r`n#####  Teardown params   
    `r`n`tdistro type   : {0} 
    `r`n`tdistro_name   : {1} 
    `r`n`tdistro source : {2} 
#####   " -f $distro_type, $distro_name, $ps_distro_source)

# Read-Host -Prompt "Press any key to continue"
$install_name=$distro_name

Write-Log ( "`r`n##### Teardown  {0} from dir {1} " -f $install_name,$ps_install_dir)

$match=((wsl -l | Where {$_.Replace("`0","") -match "$install_name"}))
if ($match -eq "$install_name") {
    Write-Log ( "`r`n##### Instance exists. Tearing down {0}... " -f $install_name)
    Write-Log ""
    $unregisterOutput = wsl --unregister $install_name 2>&1
    Write-Log ($unregisterOutput | Out-String)
}
else {
    Write-Log ( "`r`n##### Instance with name {0} does not exist. returning... " -f "$install_name")    
}


