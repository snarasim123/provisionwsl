<#
.SYNOPSIS
    Test script for WSL distro instances created by the ansible setup.
.DESCRIPTION
    Reads a profile file to get the distro name and default_user,
    then runs a series of validation tests inside the WSL instance.
    Results are saved to a log file and printed to console.
.EXAMPLE
    .\test.ps1 .\profiles\gcp3
    .\test.ps1 .\profiles\gcp3 -LogSuffix "smoketest"
#>
param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$ProfilePath,

    [Parameter(Position=1)]
    [string]$LogSuffix = "test"
)

$basedir = $PSScriptRoot
. $basedir\scripts\Assert.ps1
. $basedir\scripts\PathUtils.ps1
. $basedir\scripts\Logs.ps1
. $basedir\scripts\Wsl.ps1
. $basedir\scripts\Profile.ps1

$pass_count = 0
$fail_count = 0
$results = @()

# --- Configuration ---

$BashProfileFiles  = @(".alias", ".bash_funcs", ".kc_funcs", ".py_funcs", ".bash_profile", ".bashrc", ".bashrc_custom", "prompt.sh", "variables.sh")
$BashCompareSkip   = @(".bashrc_custom",".bashrc")  # modified by Ansible post-copy (lineinfile tasks)
$BashSourceSubDir  = "files\common"
$KubeDirectories   = @(".kube", ".kube_aws", ".kube_gcp")
$SshKeyFiles       = @("~/.ssh/id_rsa", "~/.ssh/id_rsa.pub")
$VimPluginPaths    = @("~/.vim/pack/", "~/.vim/plugged/", "~/.vim/bundle/")
$NvimPluginPaths   = @("~/.local/share/nvim/site/pack/", "~/.local/share/nvim/plugged/")
$KubeSwitchers     = @("kube_aws.sh", "kube_gcp.sh")
$ExpectedFolders   = @("bashfiles", "bin", "tmp")

# --- Helper Functions ---

function Run-Test {
    param(
        [string]$DistroName,
        [string]$User,
        [string]$TestName,
        [string]$Command
    )
    Write-Log "`r`n`r`n`r`n"
    Write-Log ("=" * 50)
    Write-Log ("  TEST: $TestName")
    Write-Log ("=" * 50)
    $script:LastTestExitCode = 1
    try {
        # change this to inmemory exec of command
        # Using -Raw, read the file in full, as a single, multi-line string.
        # $simple_script = Get-Content -Raw ./simple_script.sh

        # !! The \-escaping is needed up to PowerShell 7.2.x
        # wsl bash -c ($simple_script -replace '"', '\"')
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        # Ensure standard PATH is set (Alpine's login shell may not include /usr/bin, /bin etc.)
        $pathPrefix = 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"'
        $lfCommand = ($pathPrefix + "`n" + $Command) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($tmpFile, $lfCommand, $utf8NoBom)
        $tmpWslPath = (wsl -d $DistroName wslpath -u $tmpFile.Replace('\','\\')) -replace '\s',''
        if ($LASTEXITCODE -ne 0) { throw "Cannot resolve temporary test script in WSL." }
        $output = wsl -d $DistroName -u $User -- bash -l $tmpWslPath 2>&1 | Out-String
        $script:LastTestExitCode = $LASTEXITCODE
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        Write-Log $output
        return $output
    } catch {
        $err = $_.Exception.Message
        Write-Log "ERROR: $err"
        return "ERROR: $err"
    }
}

function Record-Result {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details
    )
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    if ($Passed) { $script:pass_count++ } else { $script:fail_count++ }
    $script:results += [PSCustomObject]@{
        Test    = $TestName
        Status  = $status
        Details = $Details.Trim()
    }
    Write-Log ("  [{0}] {1}" -f $status, $TestName)
}

# --- Test Functions ---

function Test-Logging {
    $testName = "PowerShell stdout/stderr logging"
    $ErrorActionPreference = 'Continue'
    $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("provisionwsl-logs-" + [guid]::NewGuid())
    try {
        $null = New-Item -ItemType Directory -Path $sandbox -ErrorAction Stop
        $captureLog = Join-Path $sandbox 'combined output.log'
        Init-LogFile -LogFile $captureLog
        'LOG_HEADER' | Out-File -Append $captureLog

        & $env:ComSpec /d /c 'echo STDOUT_MARKER& echo [WARNING]: STDERR_MARKER 1>&2& exit /b 7' 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -Append -FilePath $captureLog | Out-Null
        $exitCode = $LASTEXITCODE
        $content = Get-Content -Raw $captureLog
        Assert ($exitCode -eq 7) 'Nonzero native exit code was not preserved.'
        Assert ($content.Contains('STDOUT_MARKER')) 'stdout was not logged.'
        Assert ($content.Contains('[WARNING]: STDERR_MARKER')) 'stderr was not logged.'
        Assert ($content -notmatch 'NativeCommandError|CategoryInfo|FullyQualifiedErrorId') 'PowerShell error formatting leaked into the log.'
        Assert ($content.Contains('LOG_HEADER')) 'Initial log content was overwritten.'

        & $env:ComSpec /d /c 'echo [WARNING]: NONFATAL_WARNING 1>&2& exit /b 0' 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -Append -FilePath $captureLog | Out-Null
        $exitCode = $LASTEXITCODE
        Assert ($exitCode -eq 0) 'A diagnostic on stderr was treated as command failure.'
        $content = Get-Content -Raw $captureLog
        Assert ($content.Contains('STDOUT_MARKER') -and $content.Contains('NONFATAL_WARNING')) 'Log output was overwritten rather than appended.'

        $longWarning = '[WARNING]: ' + ('diagnostic-' * 30)
        & $env:ComSpec /d /c "echo $longWarning 1>&2& exit /b 0" 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -Append -FilePath $captureLog | Out-Null
        Assert ((Get-Content -Raw $captureLog).Contains($longWarning)) 'A long diagnostic was wrapped or truncated in the log.'
        Write-Log 'Logging regression checks passed: 8'
        Record-Result $testName $true 'All eight logging regression checks passed.'
    } catch {
        Write-Log "ERROR: $($_.Exception.Message)"
        Record-Result $testName $false $_.Exception.Message
    } finally {
        if (Test-Path $sandbox) {
            Remove-Item -Path $sandbox -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Test-UserSshProfileSymlinks {
    param([string]$DistroName, [string]$User, [string[]]$ProfileFiles, [string[]]$SshKeys)
    $testName = "User, SSH key, profile files & symlinks"
    $sshCheck = ($SshKeys | ForEach-Object { "ls -la $_ 2>&1" }) -join "; "
    $symlinkCheck = ($ProfileFiles | ForEach-Object { "~/$_" }) -join " "
    $cmd = "echo '== user check =='; id $User 2>&1; echo '== ssh key =='; $sshCheck; echo '== bashfiles dir =='; ls -la ~/bashfiles/ 2>&1; echo '== symlinks =='; ls -la $symlinkCheck 2>&1;"
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $userOk = $out -match "uid="
    $sshOk = $out -match "id_rsa"
    $symlinkOk = $out -match "bashfiles"
    Record-Result $testName ($userOk -and $sshOk -and $symlinkOk) $out
}

function Test-BashInitScripts {
    param(
        [string]$DistroName,
        [string]$User,
        [string]$SourceDir,
        [string[]]$ProfileFiles,
        [string[]]$SkipFiles = @()
    )
    $testName = "Bash init scripts sourced without error"

    # Part 1: Bash login check
    $cmd = @"
echo 'Sourcing bash login...';
bash -l -c 'echo BASH_LOGIN_OK' 2>&1;
echo 'Exit code:' \$?;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $bashOk = $out -match "BASH_LOGIN_OK"

    # Part 2: Compare source files to installed files (size + md5 hash)
    $wslSourceDir = (wsl -d $DistroName wslpath -u ($SourceDir.Replace('\','\\'))) -replace '\s',''
    $compareFiles = $ProfileFiles | Where-Object { $_ -notin $SkipFiles }
    if ($SkipFiles.Count -gt 0) {
        Write-Log ("  Skipping comparison for: {0}" -f ($SkipFiles -join ', '))
    }
    $fileList = ($compareFiles -join " ")
    $compareCmd = @"
source_dir='$wslSourceDir'
for f in $fileList; do
  echo "== `$f =="
  src="`$source_dir/`$f"
  dst=~/bashfiles/`$f
  if [ -f "`$src" ] && [ -f "`$dst" ]; then
    src_size=`$(stat -c%s "`$src")
    dst_size=`$(stat -c%s "`$dst")
    src_hash=`$(md5sum "`$src" | cut -d' ' -f1)
    dst_hash=`$(md5sum "`$dst" | cut -d' ' -f1)
    echo "  source:    size=`$src_size hash=`$src_hash"
    echo "  installed: size=`$dst_size hash=`$dst_hash"
    if [ "`$src_size" = "`$dst_size" ] && [ "`$src_hash" = "`$dst_hash" ]; then
      echo "  MATCH"
    else
      echo "  MISMATCH"
    fi
  else
    [ ! -f "`$src" ] && echo "  source MISSING: `$src"
    [ ! -f "`$dst" ] && echo "  installed MISSING: `$dst"
    echo "  MISMATCH"
  fi
done
"@
    $compareOut = Run-Test -DistroName $DistroName -User $User -TestName "File comparison (source vs installed)" -Command $compareCmd
    $filesMatch = -not ($compareOut -match "MISMATCH")

    Record-Result $testName ($bashOk -and $filesMatch) ($out + "`n" + $compareOut)
}

function Test-GitSetup {
    param([string]$DistroName, [string]$User)
    $testName = "Git version & SSH key"
    $cmd = @"
echo '== git version ==';
git --version 2>&1;
echo '== git binary ==';
which git 2>&1;
echo '== git ssh key ==';
ls -la ~/.ssh/id_rsa 2>&1;
echo '== git config ==';
git config --global user.email 2>&1;
git config --global user.name 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $gitOk = $out -match "git version"
    Record-Result $testName $gitOk $out
}

function Test-JavaSetup {
    param([string]$DistroName, [string]$User)
    $testName = "Java setup"
    $cmd = @"
echo '== java version ==';
java -version 2>&1;
echo '== java binary ==';
which java 2>&1;
echo '== javac version ==';
javac -version 2>&1;
echo '== javac binary ==';
which javac 2>&1;
echo '== JAVA_HOME ==';
echo \$JAVA_HOME 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $javaOk = $out -match "version"
    Record-Result $testName $javaOk $out
}

function Test-PythonVersion {
    param([string]$DistroName, [string]$User)
    $testName = "Python version"
    $cmd = @'
set -eo pipefail
/usr/bin/python3 --version
/usr/bin/python3 -c 'import sys; assert sys.version_info.major == 3; assert sys.prefix == sys.base_prefix'
source /etc/os-release
case "$ID" in
    ubuntu)
        native_version=$(awk -F ' *= *' '$1 == "default-version" {print $2}' /usr/share/python3/debian_defaults)
        [[ -n "$native_version" && "$(readlink /usr/bin/python3)" == "$native_version" ]]
        /usr/bin/python3 -c 'import apt, apt_pkg'
        ;;
    fedora) /usr/bin/python3 -c 'import dnf' ;;
    alpine) /usr/bin/python3 -c 'import cryptography, passlib' ;;
    *) exit 1 ;;
esac
echo SYSTEM_PYTHON_OK
'@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $pythonOk = $script:LastTestExitCode -eq 0 -and $out -cmatch '(?m)^SYSTEM_PYTHON_OK\r?$'
    Record-Result $testName $pythonOk $out
}

function Get-TestRepositoryPath {
    param([string]$DistroName)
    $root = wsl -d $DistroName -- wslpath -u $basedir.Replace('\','\\')
    if ($LASTEXITCODE -ne 0) { throw "Cannot resolve repository path in WSL." }
    return ($root | Out-String).Trim()
}

function Test-AnsibleRuntime {
    param([string]$DistroName, [string]$User)
    $testName = "Ansible controller and managed-host Python"
    $root = Get-TestRepositoryPath $DistroName
    $cmd = @'
set -eo pipefail
source '__REPOSITORY__/scripts/bash/python-bootstrap.sh'
read_python_bootstrap_mode '__REPOSITORY__'
require_prepared_python_mode
source /etc/os-release
distro_type=$ID
configure_ansible_runtime
validate_ansible_runtime
echo ANSIBLE_RUNTIME_OK
'@
    $out = Run-Test -DistroName $DistroName -User root -TestName $testName -Command ($cmd.Replace('__REPOSITORY__', $root))
    $passed = $script:LastTestExitCode -eq 0 -and $out -cmatch '(?m)^ANSIBLE_RUNTIME_OK\r?$'
    Record-Result $testName $passed $out
}

function Test-PyenvSetup {
    param([string]$DistroName, [string]$User)
    $testName = "Pyenv versions & virtualenv plugin"
    $root = Get-TestRepositoryPath $DistroName
    $configCmd = @'
set -eo pipefail
mode=$(cat "$HOME/.local/state/provisionwsl/python-bootstrap-mode")
source /etc/os-release
case "$mode:$ID" in
    safe:alpine) controller=/usr/bin/python3 ;;
    safe:*) controller="$HOME/.local/share/provisionwsl/ansible/bin/python" ;;
    legacy:*)
        IFS= read -r controller < "$(command -v ansible-playbook)"
        controller=${controller#\#!}
        ;;
    *) exit 1 ;;
esac
read -r -a controller_command <<< "$controller"
"${controller_command[@]}" -c 'import json, sys, yaml; config = yaml.safe_load(open(sys.argv[1])); print("PYENV_CONFIG=" + json.dumps({"versions": config["pyenv_python_versions"], "global": config["pyenv_global_version"]}))' '__REPOSITORY__/vars/language_versions.yml'
'@
    $configOut = Run-Test -DistroName $DistroName -User root -TestName "Read configured pyenv versions" -Command ($configCmd.Replace('__REPOSITORY__', $root))
    if ($script:LastTestExitCode -ne 0 -or $configOut -cnotmatch '(?m)^PYENV_CONFIG=(.+)\r?$') {
        Record-Result $testName $false $configOut
        return
    }
    $expected = $Matches[1] | ConvertFrom-Json
    if (@($expected.versions).Count -eq 0 -or $expected.global -notin $expected.versions -or
        @($expected.versions | Where-Object { $_ -notmatch '^3\.[0-9]+\.[0-9]+$' }).Count -gt 0) {
        Record-Result $testName $false "Invalid pyenv version configuration."
        return
    }
    $cmd = @'
set -eo pipefail
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
unset PYENV_VERSION
cd /
pyenv --version
pyenv virtualenv --help >/dev/null
for version in __VERSIONS__; do
    prefix=$(pyenv prefix "$version")
    "$prefix/bin/python" -c 'import platform, sys; assert platform.python_version() == sys.argv[1]' "$version"
done
[[ "$(pyenv global)" == '__GLOBAL__' ]]
pyenv exec python -c 'import platform; assert platform.python_version() == "__GLOBAL__"'
echo PYENV_SETUP_OK
'@
    $cmd = $cmd.Replace('__VERSIONS__', ($expected.versions -join ' ')).Replace('__GLOBAL__', $expected.global)
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $pyenvOk = $script:LastTestExitCode -eq 0 -and $out -cmatch '(?m)^PYENV_SETUP_OK\r?$'
    Record-Result $testName $pyenvOk $out
}

function Test-CloudCli {
    param([string]$DistroName, [string]$User)
    $testName = "AWS & GCP CLI versions"
    $cmd = @"
echo '== aws cli ==';
aws --version 2>&1;
echo '== aws binary ==';
which aws 2>&1;
echo '== gcloud cli ==';
gcloud --version 2>&1 | head -5;
echo '== gcloud binary ==';
which gcloud 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $awsOk = $out -match "aws-cli"
    $gcpOk = $out -match "Google Cloud SDK"
    Record-Result $testName ($awsOk -or $gcpOk) $out
}

function Test-KubeDirectories {
    param([string]$DistroName, [string]$User, [string[]]$KubeDirs)
    $testName = "Kube config directories"
    $dirChecks = ($KubeDirs | ForEach-Object { "echo '== $_ =='; ls -la ~/$_/ 2>&1" }) -join "; "
    $cmd = $dirChecks
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $kubeOk = $out -match "\.kube"
    Record-Result $testName $kubeOk $out
}

function Test-BinScripts {
    param([string]$DistroName, [string]$User)
    $testName = "Bash scripts in ~/bin"
    $cmd = @"
echo '== ~/bin contents ==';
ls -la ~/bin/ 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $binOk = -not ($out -match "No such file or directory" -and -not ($out -match "total"))
    Record-Result $testName $binOk $out
}

function Test-VimNeovim {
    param([string]$DistroName, [string]$User, [string[]]$VimPaths, [string[]]$NvimPaths)
    $testName = "Vim & Neovim versions and plugins"
    $vimPluginCheck = ($VimPaths | ForEach-Object { "ls $_ 2>&1" }) -join " || "
    $nvimPluginCheck = ($NvimPaths | ForEach-Object { "ls $_ 2>&1" }) -join " || "
    $cmd = @"
echo '== vim version ==';
vim --version 2>&1 | head -2;
echo '== vim binary ==';
which vim 2>&1;
echo '== nvim version ==';
nvim --version 2>&1 | head -2;
echo '== nvim binary ==';
which nvim 2>&1;
echo '== vim plugins ==';
$vimPluginCheck || echo 'no vim plugins found';
echo '== nvim plugins ==';
$nvimPluginCheck || echo 'no nvim plugins found';
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $vimOk = $out -match "VIM|NVIM"
    Record-Result $testName $vimOk $out
}

function Test-K9s {
    param([string]$DistroName, [string]$User)
    $testName = "k9s installed"
    $cmd = @"
echo '== k9s version ==';
k9s version 2>&1 | head -3;
echo '== k9s binary ==';
which k9s 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $k9sOk = $out -match "k9s|Version"
    Record-Result $testName $k9sOk $out
}

function Test-Lazygit {
    param([string]$DistroName, [string]$User)
    $testName = "lazygit installed"
    $cmd = @"
echo '== lazygit version ==';
lazygit --version 2>&1;
echo '== lazygit binary ==';
which lazygit 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $lazygitOk = $out -match "lazygit" -and -not ($out -match "not found")
    Record-Result $testName $lazygitOk $out
}

function Test-Helm {
    param([string]$DistroName, [string]$User)
    $testName = "Helm installed"
    $cmd = @"
echo '== helm version ==';
helm version 2>&1;
echo '== helm binary ==';
which helm 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $helmOk = $out -match "Version" -or $out -match "v[0-9]+\.[0-9]+"
    Record-Result $testName $helmOk $out
}

function Test-Kubectl {
    param([string]$DistroName, [string]$User)
    $testName = "Kubectl installed"
    $cmd = @"
echo '== kubectl version ==';
kubectl version --client 2>&1;
echo '== kubectl binary ==';
which kubectl 2>&1;
ls -la `$(which kubectl) 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $kubectlOk = $out -match "Client Version" -or $out -match "kubectl"
    Record-Result $testName $kubectlOk $out
}

function Test-KubeConfigSwitchers {
    param([string]$DistroName, [string]$User, [string[]]$Switchers)
    $testName = "Kube config switcher scripts"
    $checks = ($Switchers | ForEach-Object { "echo '== $_ =='; ls -la ~/bin/$_ 2>&1; file ~/bin/$_ 2>&1" }) -join "; "
    $cmd = $checks
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $allFound = $true
    foreach ($s in $Switchers) {
        if ($out -match "$s.*No such file") { $allFound = $false }
    }
    Record-Result $testName $allFound $out
}

function Test-WslConf {
    param([string]$DistroName, [string]$User)
    $testName = "WSL conf (default user & systemd)"
    $cmd = @"
echo '== /etc/wsl.conf ==';
cat /etc/wsl.conf 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $userOk = $out -match "default=$User"
    $systemdOk = $out -match "systemd=true"
    Record-Result $testName ($userOk -and $systemdOk) $out
}

function Test-GitConfig {
    param([string]$DistroName, [string]$User)
    $testName = "Git global config settings"
    $cmd = @"
echo '== git config list ==';
git config --global --list 2>&1;
echo '== core.editor ==';
git config --global core.editor 2>&1;
echo '== core.autocrlf ==';
git config --global core.autocrlf 2>&1;
echo '== core.eol ==';
git config --global core.eol 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $configOk = $out -match "user\.email" -or $out -match "user\.name"
    Record-Result $testName $configOk $out
}

function Test-FolderStructure {
    param([string]$DistroName, [string]$User, [string[]]$Folders)
    $testName = "Home directory folder structure"
    $checks = ($Folders | ForEach-Object { "echo '== ~/$_ =='; stat -c '%n %U %G %a' ~/$_ 2>&1" }) -join "; "
    $cmd = $checks
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $allExist = $true
    foreach ($f in $Folders) {
        if ($out -match "$f.*No such file") { $allExist = $false }
    }
    Record-Result $testName $allExist $out
}

function Test-HomeDirectoryPermissions {
    param([string]$DistroName, [string]$User)
    $testName = "Home & SSH directory permissions"
    $cmd = @"
echo '== home dir ==';
stat -c '%n owner=%U group=%G perms=%a' ~ 2>&1;
echo '== .ssh dir ==';
stat -c '%n owner=%U group=%G perms=%a' ~/.ssh 2>&1;
echo '== .ssh/id_rsa ==';
stat -c '%n owner=%U group=%G perms=%a' ~/.ssh/id_rsa 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $homeOk = $out -match "owner=$User"
    $sshDirOk = $out -match "\.ssh owner=$User.*perms=700"
    Record-Result $testName ($homeOk -and $sshDirOk) $out
}

function Test-DefaultShell {
    param([string]$DistroName, [string]$User)
    $testName = "Default shell is /bin/bash"
    $cmd = @"
echo '== default shell ==';
getent passwd $User | cut -d: -f7 2>&1;
echo '== current shell ==';
echo \`$SHELL;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $shellOk = $out -match "/bin/bash"
    Record-Result $testName $shellOk $out
}

function Test-SudoAccess {
    param([string]$DistroName, [string]$User)
    $testName = "User in sudo group"
    $cmd = @"
echo '== groups ==';
groups $User 2>&1;
echo '== id ==';
id $User 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    $sudoOk = $out -match "sudo"
    Record-Result $testName $sudoOk $out
}

# --- Main ---

function Run-AllTests {
    param(
        [string]$ProfilePath,
        [string]$LogSuffix,
        [string]$BaseDir
    )

    # Parse Profile
    $script:Profile_Path = Get-ValidatedAbsolutePath -Path $ProfilePath -ScriptRoot $PSScriptRoot
    $distro_name = Split-Path $Profile_Path -Leaf

    # Read target_user from Ansible vars (single source of truth)
    $default_user = Get-TargetUser -BaseDir $BaseDir
    if ([string]::IsNullOrWhiteSpace($default_user)) {
        Write-Error "Could not read target_user from vars/user_environment.yml"
        exit 1
    }

    # Read skipsteps from profile
    $skipsteps = @()
    $file = Get-Content $Profile_Path
    $file | ForEach-Object {
        $items = $_.split("=")
        if ($items[0] -eq "export skipsteps") { $skipsteps = $items[1].Split(",") | ForEach-Object { $_.Trim() } }
    }

    # Check distro exists
    if (-not (Test-DistroExists -DistroName $distro_name)) {
        Write-Error "WSL distro '$distro_name' is not installed."
        exit 1
    }

    # Setup Logging
    $script:LogFile = Get-LogFilePath -BaseDir $BaseDir -Name $distro_name -Suffix $LogSuffix
    Init-LogFile -LogFile $LogFile
    $PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile

    Write-Log ("=" * 60)
    Write-Log ("  WSL Instance Test - {0}" -f $distro_name)
    Write-Log ("  Profile: {0}" -f $Profile_Path)
    Write-Log ("  User: {0}" -f $default_user)
    Write-Log ("  Log: {0}" -f $LogFile)
    Write-Log ("  Start: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    if ($skipsteps.Count -gt 0) {
        Write-Log ("  Skip: {0}" -f ($skipsteps -join ', '))
    }
    Write-Log ("=" * 60)

    # Start timer
    $sw = [Diagnostics.Stopwatch]::StartNew()

    # Common params for all tests
    $tp = @{ DistroName = $distro_name; User = $default_user }

    # Run all tests
    Test-Logging
    Test-UserSshProfileSymlinks @tp -ProfileFiles $BashProfileFiles -SshKeys $SshKeyFiles
    $sourceDir = Join-Path $BaseDir $BashSourceSubDir
    Test-BashInitScripts        @tp -SourceDir $sourceDir -ProfileFiles $BashProfileFiles -SkipFiles $BashCompareSkip
    Test-GitSetup               @tp
    Test-JavaSetup              @tp
    Test-PythonVersion          @tp
    Test-AnsibleRuntime         @tp
    Test-PyenvSetup             @tp
    Test-CloudCli               @tp
    Test-KubeDirectories        @tp -KubeDirs $KubeDirectories
    Test-BinScripts             @tp
    Test-VimNeovim              @tp -VimPaths $VimPluginPaths -NvimPaths $NvimPluginPaths
    Test-K9s                    @tp
    # Only test lazygit if binary exists in the instance
    $lazygitCheck = wsl -d $distro_name -u $default_user -- which lazygit 2>&1
    if ($lazygitCheck -match '/lazygit') {
        Test-Lazygit            @tp
    } else {
        Write-Log "`r`n--- SKIPPED: lazygit test (binary not installed) ---"
    }
    Test-Helm                   @tp
    Test-Kubectl                @tp
    Test-KubeConfigSwitchers    @tp -Switchers $KubeSwitchers
    Test-WslConf                @tp
    Test-GitConfig              @tp
    Test-FolderStructure        @tp -Folders $ExpectedFolders
    Test-HomeDirectoryPermissions @tp
    Test-DefaultShell           @tp
    Test-SudoAccess             @tp

    # Summary
    $sw.Stop()
    $ts = $sw.Elapsed
    $elapsed = [string]::Format("{0:00}m {1:00}s", [int]$ts.TotalMinutes, $ts.Seconds)

    Write-Log ("`r`n" + "=" * 60)
    Write-Log "  TEST SUMMARY"
    Write-Log ("=" * 60)
    Write-Log ""

    $results | ForEach-Object {
        Write-Log ("  [{0}]  {1}" -f $_.Status, $_.Test)
    }

    Write-Log ""
    Write-Log ("  Total: {0}  |  Passed: {1}  |  Failed: {2}" -f ($pass_count + $fail_count), $pass_count, $fail_count)
    Write-Log ("  End: {0}  |  Duration: {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $elapsed)
    Write-Log ("=" * 60)
    Write-Log ("`r`nResults saved to: {0}" -f $LogFile)
}

# Entry point
Run-AllTests -ProfilePath $ProfilePath -LogSuffix $LogSuffix -BaseDir $basedir
if ($script:fail_count -gt 0) { exit 1 }
