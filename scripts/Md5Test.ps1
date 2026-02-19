
$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
. $dir\Assert.ps1
. $dir\Md5.ps1


function Test-MD5Hash {
    $targetFolder = $dir

    $fileName = [System.IO.Path]::GetRandomFileName()
    $newFilePath = Join-Path -Path $targetFolder -ChildPath $fileName

    $content = @(
        "This is line 1.",
        "This is line 2.",
        "This is line 3."
    )
    $content | Out-File -FilePath $newFilePath -Encoding UTF8
    $knownMD5Hash = "88bf7a6a73f69ec759563c0a9c4f3c0c" # This is incorrect for the given content; replace with the correct hash.
    
    $calculatedMD5Hash = Get-MD5Hash -FilePath $newFilePath

    Assert ($calculatedMD5Hash -eq $knownMD5Hash) "test1 failed"
    if ($calculatedMD5Hash -eq $knownMD5Hash) {
        Write-Output "Test Passed"
    } 
    Remove-Item -Path $newFilePath -Force
}

Test-MD5Hash