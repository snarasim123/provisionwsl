function Get-MD5Hash {
    param (
        [string]$FilePath
    )

    if (-Not (Test-Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    $md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
    $fileStream = [System.IO.File]::OpenRead($FilePath)
    $hashBytes = $md5.ComputeHash($fileStream)
    $fileStream.Close()

    $hashString = [System.BitConverter]::ToString($hashBytes) -replace '-', ''

    return $hashString.ToLower()
}
