

# $profile_name=$args[0]
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
. $dir\Assert.ps1
. $dir\CloudImage.ps1
. $dir\UrlDownload.ps1

# $test1="ubuntu1604"
# $result1="http://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"
# $url = Get-ImageURL $test1
# Assert ($url -eq $result1) "test1 failed"
# Write-Host "test1 passed"

# $url = Get-ImageURL "mint"
# Assert ($url -eq "") "test2 failed"
# Write-Host "test2 passed"

# $rel_infile='.\ubuntu-16.04-server-cloudimg-amd64.tar.gz'
# Write-Host( "##### rel_infile  {0}  " -f "$rel_infile")
$test1="ubuntu1604"
$result1="http://cloud-images.ubuntu.com/releases/xenial/release/ubuntu-16.04-server-cloudimg-amd64-wsl.rootfs.tar.gz"
$url = Get-ImageURL $test1

Download-URL -Url $url -FolderLocation $dir
# Write-Host( "##### cur path  {0}  " -f "$pwd")
# $infile=[IO.Path]::GetFullPath(($pwd).path+$rel_infile)
# Write-Host( "##### infile  {0}  " -f "$infile")
# DeGZip-File $infile 


# Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")

