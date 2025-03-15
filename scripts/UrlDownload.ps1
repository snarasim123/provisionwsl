
function Test-Url {
    param (
        [string]$Url
    )
    try {
        $uri = [System.Uri]::new($Url)
        return $uri.IsAbsoluteUri -and ($uri.Scheme -eq 'http' -or $uri.Scheme -eq 'https')
    } catch {
        return $false
    }
}

function Test-FolderLocation {
    param (
        [string]$FolderLocation
    )
    return (Test-Path -Path $FolderLocation -PathType Container)
}

function Download-URL {
    param (
        [string]$Url,              # URL of the file to download
        [string]$FolderLocation    # Folder location to save the downloaded file
    )
        
    if (-not (Test-Url -Url $Url)) {
        Write-Error "Invalid URL: $Url. Please provide a valid HTTP or HTTPS URL."
        return ""
    }

    if (-not (Test-FolderLocation -FolderLocation $FolderLocation)) {
        Write-Error "Invalid folder location: $FolderLocation. Please provide a valid folder path."
        return ""
    }

    $fileName = [System.IO.Path]::GetFileName($Url)

    $destinationPath = Join-Path -Path $FolderLocation -ChildPath $fileName

    try {
        Write-Output "Downloading file from $Url to $destinationPath..."
        (New-Object Net.WebClient).DownloadFile($Url, $destinationPath)
        Write-Output "File downloaded successfully to $destinationPath."
        return $destinationPath
    } catch {
        Write-Error "Failed to download the file: $_"
        return ""
    }
}