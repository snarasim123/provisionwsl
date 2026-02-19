

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
. $dir\CloudImageCSV.ps1
. $dir\Assert.ps1

$test1="ubuntu1604-wsl"
$test2="ubuntu1604-wsl2"
$result1="http://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"
$md5="913d522e612424350b80c3c5651047af"

# Init
Init-CloudImageDb
Write-Host "Testing cloud image url for "$test1
$imageurl1 = Get-CloudImageURL  -ID $test1
Assert ( $imageurl1 -eq $result1) "test1 failed"

Write-Host "Testing cloud image md5 for "$test1
$mdresult = Get-CloudImageMD5  -ID $test1
Assert ( $md5 -eq $mdresult) "test2 failed"

Write-Host "Testing invalid cloud image id 'mint'"
$url = Get-CloudImageURL  -ID  "mint"
Assert ($url -eq "") "test3 failed"

Write-Host "Testing empty md5 for "$test2
$mdresult = Get-CloudImageMD5  -ID  $test2
Assert ("" -eq $mdresult) "test4 failed"

Write-Host "4 tests run"

