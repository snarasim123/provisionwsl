
. $basedir\scripts\Logs.ps1
function Prepare-CloudInstall {
    param(
        [string]$UrlsCsvPath,
        [string]$DistroLookupId,
        [string]$BaseDir,
        [string]$LogFile
    )

    if (-not [string]::IsNullOrWhiteSpace($LogFile)) {
        $PSDefaultParameterValues['Write-Log:LogFile'] = $LogFile
    }

    $initresult = Init-CloudImageDb -PATH $UrlsCsvPath
    $imageurl1 = Get-CloudImageURL  -ID $DistroLookupId
    if($imageurl1 -eq ""){
        Write-Log  ( "`r`n##### invalid cloud image name, cannot resolve ps_distro_id to a valid download url. exiting")
        exit
    }

    $compressedFile = [System.IO.Path]::GetFileName($imageurl1)
    $compressedFilePath = Join-Path -Path $BaseDir\tmp\ -ChildPath $compressedFile  
    $uncompressedFileName = GetUncompressedFileName  -infile $compressedFile

    if (-not (Test-Path -Path $compressedFilePath)) {
        Write-Log ( "`r`n##### Downloading file $compressedFilePath...")
        Download-URL -Url $imageurl1 -FolderLocation $BaseDir\tmp\ | Out-Null
    } else {
        Write-Log (  "`r`n##### Reusing existing file $compressedFilePath for installation...")
    }
  
    $compressionType = Get-CompressionType -FilePath $compressedFilePath
     Write-Host (  "`r`n---- compression type: {0}" -f  "$compressionType" )
    if ($compressionType -eq 'gz') {
        $resultfile = DeGZip-File -infile $compressedFilePath
    } elseif ($compressionType -eq 'xz') {
        $resultfile = UnXz-File-WithCleanup -infile $compressedFilePath
    } else {
        Write-Log (  "`r`n##### Unknown or unsupported compression type for file: $compressionType" )
        exit 1
    }
     Write-Log (  "`r`n---- Extracted file: $BaseDir\tmp\$uncompressedFileName" )
    return "$BaseDir\tmp\$uncompressedFileName"
}