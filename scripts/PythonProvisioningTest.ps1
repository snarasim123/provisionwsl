$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\Assert.ps1"

$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    "$PSScriptRoot\..\test.ps1", [ref]$null, [ref]$parseErrors)
Assert (-not $parseErrors) ($parseErrors | Out-String)
$testFunctions = @('Test-PythonVersion', 'Test-AnsibleRuntime', 'Test-PythonBootstrap', 'Test-PyenvSetup')
$ast.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $testFunctions
}, $true) | ForEach-Object { Invoke-Expression $_.Extent.Text }

function Get-TestRepositoryPath { return '/mock-repository' }
function Run-Test {
    param($DistroName, $User, $TestName, $Command)
    $script:LastTestExitCode = $script:MockExit
    if ($TestName -eq 'Read configured pyenv versions' -and $script:ValidConfig) {
        return 'PYENV_CONFIG={"versions":["3.11.9","3.12.4"],"global":"3.12.4"}'
    }
    return $script:MockOutput
}
function Record-Result {
    param($TestName, $Passed, $Details)
    $script:CapturedPass = $Passed
}

$checks = 0
foreach ($testFunction in $testFunctions) {
    foreach ($case in @(@('== Python pyenv version ==', 0), @('command not found', 127))) {
        $script:MockOutput = $case[0]
        $script:MockExit = $case[1]
        $script:ValidConfig = $false
        & $testFunction -DistroName mock -User mock
        Assert (-not $script:CapturedPass) "False positive in $testFunction"
        $checks++
    }
}

foreach ($pair in @(
    @('Test-PythonVersion', 'SYSTEM_PYTHON_OK'),
    @('Test-AnsibleRuntime', 'ANSIBLE_RUNTIME_OK'),
    @('Test-PythonBootstrap', 'Python bootstrap regression checks passed: 38'),
    @('Test-PyenvSetup', 'PYENV_SETUP_OK')
)) {
    foreach ($exitCode in @(0, 1)) {
        $script:MockOutput = $pair[1]
        $script:MockExit = $exitCode
        $script:ValidConfig = $true
        & $pair[0] -DistroName mock -User mock
        Assert ($script:CapturedPass -eq ($exitCode -eq 0)) "Exit status ignored in $($pair[0])"
        $checks++
    }
}

$script:ValidConfig = $true
$script:MockExit = 0
$script:MockOutput = '== pyenv version =='
Test-PyenvSetup -DistroName mock -User mock
Assert (-not $script:CapturedPass) 'Heading-only pyenv output passed after valid configuration.'
$checks++
Write-Output "Python provisioning harness checks passed: $checks"