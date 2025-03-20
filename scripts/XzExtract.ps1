# sample code to extract tar file from cloud image
Function DeGZip-File{
    Param(
        $infile
        )
    $outFile = $infile.Substring(0, $infile.LastIndexOfAny('.'))
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
    $buffer = New-Object byte[](1024)
    while($true){
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0){break}
        $output.Write($buffer, 0, $read)
        }
    $gzipStream.Close()
    $output.Close()
    $input.Close()
    return $outFile
}

Function GetUncompressedFileName{
    Param(
        $infile
        )
    $outFile = $infile.Substring(0, $infile.LastIndexOfAny('.'))
    return $outFile
}

# https://stackoverflow.com/a/46876070/847953
function Extract-Tar {
    [cmdletbinding(SupportsShouldProcess=$True)]
    param(
        [Parameter(Mandatory=$true)]
        [string] $tarFile,
        [Parameter(Mandatory=$true)]
        [string] $dest
    )

    if ($PSCmdlet.ShouldProcess($tarFile,"Expand tar file")) {
        Expand-7Zip $tarFile $dest
    }
}


# $rel_infile='.\ubuntu-16.04-server-cloudimg-amd64.tar.gz'
# Write-Host( "##### rel_infile  {0}  " -f "$rel_infile")

# Write-Host( "##### cur path  {0}  " -f "$pwd")
# $infile=[IO.Path]::GetFullPath(($pwd).path+$rel_infile)
# Write-Host( "##### infile  {0}  " -f "$infile")
# DeGZip-File $infile 


# Write-Host( "##### RunTime  {0}... " -f "$elapsedTime")

