$scriptpath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptpath

. $dir\Dict.ps1

# Prompt the user for the dictionary file path
$DictionaryFilePath = "$dir\urls.db"
# $global:ImageDict = @{}
$global:isInit = $false


function Init {
    # $global:ImageDict = Load-Dictionary $DictionaryFilePath $global:ImageDict
    Load-Dictionary $DictionaryFilePath 
}
function Get-ImageURL {
    param (
        [string]$ImageName
    )
    
    if ($global:isInit  -eq $false) {
        Init
        $global:isInit = $true
    }
    $value = Get-DictionaryValue -Key $ImageName
    if ($value) {
        # Write-Host "Value for key '$key': $value"
        return $value
    } else {
        # Write-Host "Key '$key' not found."
        return ""
    }
}
       