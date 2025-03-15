$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$DictionaryFilePath = "$dir\urls.csv"
$global:UrlDict = @{}
function Init-CloudImageDb {
    $data = Import-Csv -Path $DictionaryFilePath

    foreach ($row in $data) {
        $key = $row.ID  
        $global:UrlDict[$key] = @{
            URL = $row.URL
            MD5 = $row.MD5
        }
    }
    return $global:UrlDict
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