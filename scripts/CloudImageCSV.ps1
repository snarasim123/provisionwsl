$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath

$global:UrlDict = @{}
function Init-CloudImageDb {
    param (
        [string]$PATH
    )
    $DictionaryFilePath = $Path
    $data = Import-Csv -Path $DictionaryFilePath

    foreach ($row in $data) {
        $key = $row.ID  
        $global:UrlDict[$key] = @{
            URL = $row.URL
            MD5 = $row.MD5
            PLATFORM = $row.PLATFORM
        }
    }
    return $global:UrlDict
}

function Get-CloudImagePlatform {
    param (
        [string]$ID
    )
    $result = ""
    if ($global:UrlDict.ContainsKey($ID)) {
        $result =  $($global:UrlDict[$ID].PLATFORM) 
    } 
    return $result
}

function Get-CloudImageURL {
    param (
        [string]$ID
    )
    $result = ""
    if ($global:UrlDict.ContainsKey($ID)) {
        $result =  $($global:UrlDict[$ID].URL) 
        # Write-Host "result type "+ $result.GetType()        
    } 
    return $result
}

function Get-CloudImageMD5 {
    param (
        [string]$ID
    )
    # $result = ""
    if ($global:UrlDict.ContainsKey($ID)) {
        $result =  $($global:UrlDict[$ID].MD5) 
        # Write-Host "result type "+ $result.GetType()        
    } 
    return $result
}
function Get-CloudImageSHA256 {
    param (
        [string]$ID
    )
    if ($global:UrlDict.ContainsKey($ID)) {
        $result =  $($global:UrlDict[$ID].SHA256) 
    } 
    return $result
}

function Get-CloudImageSHA512 {
    param (
        [string]$ID
    )
    if ($global:UrlDict.ContainsKey($ID)) {
        $result =  $($global:UrlDict[$ID].SHA512) 
    } 
    return $result
}

function Get-CloudImageType {
    param (
        [string]$ID
    )
    if ($global:UrlDict.ContainsKey($ID)) {
        $result =  $($global:UrlDict[$ID].TYPE) 

    } 
    return $result
}