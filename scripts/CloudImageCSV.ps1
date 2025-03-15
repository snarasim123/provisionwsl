$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath
$DictionaryFilePath = "$dir\urls.csv"
$global:UrlDict = @{}
function New-CsvLookupTable {
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

function Get-CsvLookupURL {
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

function Get-CsvMD5 {
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