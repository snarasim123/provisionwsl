Function Get-CompressionType {
    Param(
        [string]$FilePath
    )
    
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    if ($extension -eq '.gz' -or $extension -eq '.tgz') {
        return 'gz'
    }
    elseif ($extension -eq '.xz') {
        return 'xz'
    }
    else {
        return 'unknown'
    }
}

Function Ensure-XzTool {
    # Check for global xz command first
    $xzCommand = Get-Command xz -ErrorAction SilentlyContinue
    $xzPath = if ($xzCommand) { $xzCommand.Source } else { $null }
    
    if ($xzPath) {
        return @{
            Path = $xzPath
            CleanupNeeded = $false
            InstallDir = $null
        }
    }

    # Check if already installed in the custom location
    $installDir = Join-Path $env:USERPROFILE "xz-utils"
    $found = Get-ChildItem -Path $installDir -Filter "xz.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        return @{
            Path = $found.FullName
            CleanupNeeded = $false
            InstallDir = $null
        }
    }

    # Not found, so we download to the custom location
    $zipPath = Join-Path $env:TEMP "xz-utils.zip"

    Write-Host "xz tool not found. Downloading and installing..."
    $downloadUrl = "https://tukaani.org/xz/xz-5.8.1-windows.zip"

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $installDir -Force
        
        $found = Get-ChildItem -Path $installDir -Filter "xz.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            $xzPath = $found.FullName
            return @{
                Path = $xzPath
                CleanupNeeded = $false
                InstallDir = $null
            }
        } else {
            Write-Error "Could not find xz.exe after extraction."
            return $null
        }
    }
    catch {
        Write-Error "Failed to download or setup xz utils: $_"
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
        # We don't remove installDir here as it might be a partial install we want to inspect or retry
        return $null
    }
    finally {
        # Clean up zip file immediately
        if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    }
}
