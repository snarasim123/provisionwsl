function Prepare-CloudInstall {
    param(
        [string]$UrlsCsvPath,
        [string]$DistroLookupId,
        [string]$BaseDir
    )

    $initresult = Init-CloudImageDb -PATH $UrlsCsvPath
    $imageurl1 = Get-CloudImageURL  -ID $DistroLookupId
    if($imageurl1 -eq ""){
        Write-Host ( "##### invalid cloud image name, cannot resolve ps_distro_id to a valid download url. exiting")
        exit
    }

    $compressedFile = [System.IO.Path]::GetFileName($imageurl1)
    $compressedFilePath = Join-Path -Path $BaseDir\tmp\ -ChildPath $compressedFile  
    $uncompressedFileName = GetUncompressedFileName  -infile $compressedFile

    if (-not (Test-Path -Path $compressedFilePath)) {
        Write-Host "##### Downloading file $compressedFilePath\$compressedFile..."
        Download-URL -Url $imageurl1 -FolderLocation $BaseDir\tmp\
    } else {
        Write-Host "##### Reusing existing file $compressedFilePath\$compressedFile for installation..."
    }
  
    $compressionType = Get-CompressionType -FilePath $compressedFilePath
    if ($compressionType -eq 'gz') {
        $resultfile = DeGZip-File -infile $compressedFilePath
    } elseif ($compressionType -eq 'xz') {
        $resultfile = UnXz-File-WithCleanup -infile $compressedFilePath
    } else {
        Write-Error "##### Unknown or unsupported compression type for file: $compressedFilePath"
        exit 1
    }

    return "$BaseDir\tmp\$uncompressedFileName"
}