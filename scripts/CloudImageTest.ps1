

$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
. $dir\CloudImageCSV.ps1
. $dir\Assert.ps1

$test1="ubuntu1604-wsl"
$result1="http://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"
$md5="913d522e612424350b80c3c5651047af"

# Init
New-CsvLookupTable
$imageurl1 = Get-CsvLookupURL  -ID $test1
Assert ( $imageurl1 -eq $result1) "test1 failed"

$mdresult = Get-CsvMD5  -ID $test1
Assert ( $md5 -eq $mdresult) "test2 failed"

$url = Get-CsvLookupURL  -ID  "mint"
Assert ($url -eq "") "test3 failed"
Write-Host "3 tests passed"

