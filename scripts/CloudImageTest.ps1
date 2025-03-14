

# $profile_name=$args[0]
$CWD = [Environment]::CurrentDirectory
[Environment]::CurrentDirectory = "\"

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath

function Assert {
    param (
        [bool]$Condition,
        [string]$Message = "Assertion failed"
    )
    if (-not $Condition) {
        throw $Message
    }
}

. $dir\CloudImage.ps1

$test1="ubuntu1604"
$result1="http://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"
$url = Get-ImageURL $test1
Assert ($url -eq $result1) "test1 failed"
Write-Host "test1 passed"

$url = Get-ImageURL "mint"
Assert ($url -eq "") "test2 failed"
Write-Host "test2 passed"

