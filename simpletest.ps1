function Run-Test {
    param(
        [string]$DistroName,
        [string]$User,
        [string]$TestName,
        [string]$Command
    )

    try {
        # change this to inmemory exec of command
        # Using -Raw, read the file in full, as a single, multi-line string.
        # $simple_script = Get-Content -Raw ./simple_script.sh

        # !! The \-escaping is needed up to PowerShell 7.2.x
        # wsl bash -c ($simple_script -replace '"', '\"')
        # $tmpFile = [System.IO.Path]::GetTempFileName()
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        # Ensure standard PATH is set (Alpine's login shell may not include /usr/bin, /bin etc.)
        $pathPrefix = 'export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"'
        $lfCommand = ($pathPrefix + "`n" + $Command) -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText($tmpFile, $lfCommand, $utf8NoBom)
        $tmpWslPath = (wsl -d $DistroName wslpath -u $tmpFile.Replace('\','\\')) -replace '\s',''
        $output = wsl -d $DistroName -u $User -- bash -l $tmpWslPath 2>&1 | Out-String
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
        Write-Log $output
        return $output
    } catch {
        $err = $_.Exception.Message
        Write-Log "ERROR: $err"
        return "ERROR: $err"
    }
}

function Write-Log {
    param(
        [Parameter(Position=0)]
        [string]$Message,
        [string]$LogFile
    )
    Write-Host $Message
    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        $Message | Out-File -Append $LogFile
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

function Test-GitSetup {
    param([string]$DistroName, [string]$User)
    $testName = "Simple test"
    $cmd = @"
    echo '== ls -la ~ ==';
    ls -la ~/ 2>&1;
"@
    $out = Run-Test -DistroName $DistroName -User $User -TestName $testName -Command $cmd
    Record-Result $testName $gitOk $out
}
