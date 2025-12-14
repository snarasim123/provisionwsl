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

Function UnXz-File{
    Param(
        $infile
        )
    
    if (-not (Test-Path $infile)) {
        Write-Error "File '$infile' does not exist."
        return
    }

    # Check for xz command
    $xzCommand = Get-Command xz -ErrorAction SilentlyContinue
    $xzPath = if ($xzCommand) { $xzCommand.Source } else { $null }

    if (-not $xzPath) {
        $installDir = Join-Path $env:USERPROFILE "xz-utils"
        
        # Check if already installed in the custom location
        $found = Get-ChildItem -Path $installDir -Filter "xz.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $xzPath = $found.FullName
        }

        if (-not $xzPath) {
            Write-Host "xz tool not found. Downloading and installing..."
            $downloadUrl = "https://tukaani.org/xz/xz-5.8.1-windows.zip"
            $zipPath = Join-Path $env:TEMP "xz-utils.zip"
            
            try {
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
                Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
                
                # Find xz.exe again
                $found = Get-ChildItem -Path $installDir -Filter "xz.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $xzPath = $found.FullName
                } else {
                    Write-Error "Could not find xz.exe after extraction."
                    return
                }
            }
            catch {
                Write-Error "Failed to download or install xz utils: $_"
                return
            }
            finally {
                if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
            }
        }
    }

    $fullPath = (Resolve-Path $infile).Path
    $outFile = $fullPath.Substring(0, $fullPath.LastIndexOfAny('.'))

    # Using xz command line tool
    # -d : decompress
    # -k : keep original file
    # -f : force (overwrite output)
    $process = Start-Process -FilePath $xzPath -ArgumentList "-d", "-k", "-f", "`"$fullPath`"" -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Error "Uncompression failed."
        return
    }

    return $outFile
}

Function UnXz-File-WithCleanup{
    Param(
        $infile
        )
    
    if (-not (Test-Path $infile)) {
        Write-Error "File '$infile' does not exist."
        return
    }

    $fullPath = (Resolve-Path $infile).Path
    $outFile = $fullPath.Substring(0, $fullPath.LastIndexOfAny('.'))
    
    $xzTool = Ensure-XzTool
    if (-not $xzTool) {
        return
    }

    $xzPath = $xzTool.Path
    $cleanupNeeded = $xzTool.CleanupNeeded
    $installDir = $xzTool.InstallDir

    try {
        # Using xz command line tool
        $process = Start-Process -FilePath $xzPath -ArgumentList "-d", "-k", "-f", "`"$fullPath`"" -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -ne 0) {
            Write-Error "Uncompression failed."
        } else {
            return $outFile
        }
    }
    finally {
        if ($cleanupNeeded -and $installDir -and (Test-Path $installDir)) {
            Write-Host "Cleaning up temporary xz utils..."
            Remove-Item $installDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
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

