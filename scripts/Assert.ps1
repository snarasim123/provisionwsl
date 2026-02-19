
function Assert {
    param (
        [bool]$Condition,
        [string]$Message = "Assertion failed"
    )
    if (-not $Condition) {
        throw $Message
    }
}