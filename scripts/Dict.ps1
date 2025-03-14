
# Function to load the dictionary from the file
$global:Dictionary  = @{}
function Load-Dictionary {
    param (
        [string]$FilePath
    )
    # $dictionary = @{}
    if (Test-Path $FilePath) {
        $content = Get-Content -Path $FilePath
        Get-Content -Path $FilePath | ForEach-Object {
            $key, $value = $_ -split '=', 2
            if ($key -and $value) {
                $global:Dictionary[$key] = $value
            }
        }
    }
    # return $Dictionary
}

# Function to get a value from the dictionary by key
function Get-DictionaryValue {
    param (
        [string]$Key
    )
    $val = $global:Dictionary[$Key]
    return $val
}

# Function to save the dictionary to the file
function Save-Dictionary {
    param (
        [string]$FilePath
    )
    $content = $global:Dictionary.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }
    Set-Content -Path $FilePath -Value $content
}

# # Function to add or update a key-value pair in the dictionary
function Set-DictionaryValue {
    param (
        [string]$Key,
        [string]$Value
    )
    $global:dictionary[$Key] = $Value
}

# # Function to remove a key-value pair from the dictionary
function Remove-DictionaryValue {
    param (
        [string]$Key
    )
    if ($global:dictionary.ContainsKey($Key)) {
        $global:dictionary.Remove($Key)
    }
}
