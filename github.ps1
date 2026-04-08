param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$ProfilePath
)

$basedir = $PSScriptRoot
. $basedir\scripts\PathUtils.ps1
. $basedir\scripts\Logs.ps1
. $basedir\scripts\Wsl.ps1

$Profile_Path = Get-ValidatedAbsolutePath -Path $ProfilePath -ScriptRoot $PSScriptRoot
$Distro_Name = Split-Path $Profile_Path -Leaf

if (-not (Test-DistroExists -DistroName $Distro_Name)) {
    Write-Error "WSL distro '$Distro_Name' is not installed. Provision the instance before running github.ps1."
    exit 1
}

$LogFile = Get-LogFilePath -BaseDir $basedir -Name $Distro_Name -Suffix "github"
Init-LogFile -LogFile $LogFile
$PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile

$Profile_Path_unix = ConvertTo-WslPath -WindowsPath $Profile_Path
$basedir_unixpath = ConvertTo-WslPath -WindowsPath $PSScriptRoot

Write-Log ("`r`n##### Running GitHub-only playbook for profile {0} #####" -f $Profile_Path)
Write-Log ("`r`n##### Distro: {0}" -f $Distro_Name)

wsl -d $Distro_Name -u root -- bash $basedir_unixpath/install-github.sh $Profile_Path_unix 2>&1 | Tee-Object -Append -FilePath $LogFile

if ($LASTEXITCODE -ne 0) {
    Write-Log ("`r`n##### GitHub-only playbook failed for {0}. exit code: {1}" -f $Distro_Name, $LASTEXITCODE)
    exit $LASTEXITCODE
}

Write-Log ("`r`n##### GitHub-only playbook completed for {0}." -f $Distro_Name)