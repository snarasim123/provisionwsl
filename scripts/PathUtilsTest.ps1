# Tests for ConvertTo-WslPath function
# Run: .\scripts\PathUtilsTest.ps1

$basedir = Split-Path $PSScriptRoot -Parent
. $PSScriptRoot\PathUtils.ps1

$testsPassed = 0
$testsFailed = 0

function Test-ConvertToWslPath {
    param(
        [string]$WindowsPath,
        [string]$Expected,
        [string]$Description
    )
    
    $result = ConvertTo-WslPath -WindowsPath $WindowsPath
    
    if ($result -eq $Expected) {
        Write-Host "[PASS] $Description" -ForegroundColor Green
        Write-Host "       Input:    $WindowsPath"
        Write-Host "       Expected: $Expected"
        Write-Host "       Got:      $result"
        $script:testsPassed++
    } else {
        Write-Host "[FAIL] $Description" -ForegroundColor Red
        Write-Host "       Input:    $WindowsPath"
        Write-Host "       Expected: $Expected"
        Write-Host "       Got:      $result"
        $script:testsFailed++
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ConvertTo-WslPath Tests" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Basic drive letter tests
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\Test" `
    -Expected "/mnt/c/Users/Test" `
    -Description "Basic C: drive path"

Test-ConvertToWslPath `
    -WindowsPath "D:\Projects\Code" `
    -Expected "/mnt/d/Projects/Code" `
    -Description "D: drive path"

Test-ConvertToWslPath `
    -WindowsPath "E:\Data" `
    -Expected "/mnt/e/Data" `
    -Description "E: drive path"

# Case sensitivity tests
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\Test" `
    -Expected "/mnt/c/Users/Test" `
    -Description "Uppercase C: converts to lowercase /mnt/c"

Test-ConvertToWslPath `
    -WindowsPath "c:\users\test" `
    -Expected "/mnt/c/users/test" `
    -Description "Already lowercase drive letter"

# Backslash conversion tests
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\Name\Documents\File.txt" `
    -Expected "/mnt/c/Users/Name/Documents/File.txt" `
    -Description "Multiple backslashes converted"

Test-ConvertToWslPath `
    -WindowsPath "C:\Path\With\Many\Nested\Folders" `
    -Expected "/mnt/c/Path/With/Many/Nested/Folders" `
    -Description "Deeply nested path"

# Edge cases - spaces and special characters
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\John Doe\My Documents" `
    -Expected "/mnt/c/Users/John Doe/My Documents" `
    -Description "Path with spaces"

Test-ConvertToWslPath `
    -WindowsPath "C:\Program Files (x86)\App" `
    -Expected "/mnt/c/Program Files (x86)/App" `
    -Description "Path with parentheses"

# Root drive path
Test-ConvertToWslPath `
    -WindowsPath "C:\" `
    -Expected "/mnt/c/" `
    -Description "Root of C: drive"

Test-ConvertToWslPath `
    -WindowsPath "D:\" `
    -Expected "/mnt/d/" `
    -Description "Root of D: drive"

# File with extension
Test-ConvertToWslPath `
    -WindowsPath "C:\scripts\prep-install.sh" `
    -Expected "/mnt/c/scripts/prep-install.sh" `
    -Description "Path with file extension"

# Actual project paths
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\SrinivasaNarasimhan\code\setup2\ansible" `
    -Expected "/mnt/c/Users/SrinivasaNarasimhan/code/setup2/ansible" `
    -Description "Actual project path"

Test-ConvertToWslPath `
    -WindowsPath "C:\Users\SrinivasaNarasimhan\code\setup2\ansible\profiles\aa-alpine320" `
    -Expected "/mnt/c/Users/SrinivasaNarasimhan/code/setup2/ansible/profiles/aa-alpine320" `
    -Description "Profile path"

# Trailing slash tests
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\Test\" `
    -Expected "/mnt/c/Users/Test/" `
    -Description "Path with trailing backslash"

Test-ConvertToWslPath `
    -WindowsPath "C:\Users\Test\\" `
    -Expected "/mnt/c/Users/Test/" `
    -Description "Path with double trailing backslash (normalized)"

Test-ConvertToWslPath `
    -WindowsPath "D:\Projects\Code\" `
    -Expected "/mnt/d/Projects/Code/" `
    -Description "D: drive with trailing backslash"

Test-ConvertToWslPath `
    -WindowsPath "C:\Program Files\" `
    -Expected "/mnt/c/Program Files/" `
    -Description "Path with space and trailing backslash"

# Multiple consecutive backslashes in middle of path
Test-ConvertToWslPath `
    -WindowsPath "C:\Users\\Test\\Folder" `
    -Expected "/mnt/c/Users/Test/Folder" `
    -Description "Multiple backslashes in middle (normalized)"

# UNC path tests (negative - not converted to /mnt/)
Test-ConvertToWslPath `
    -WindowsPath "\\server\share" `
    -Expected "//server/share" `
    -Description "UNC path - preserved as //server/share (no /mnt/)"

Test-ConvertToWslPath `
    -WindowsPath "\\server\share\folder\file.txt" `
    -Expected "//server/share/folder/file.txt" `
    -Description "UNC path with subfolders"

Test-ConvertToWslPath `
    -WindowsPath "\\192.168.1.1\share" `
    -Expected "//192.168.1.1/share" `
    -Description "UNC path with IP address"

# Edge case: backslashes before drive letter (malformed path)
Test-ConvertToWslPath `
    -WindowsPath "\\C:\Users\Test" `
    -Expected "//C:/Users/Test" `
    -Description "Backslashes before drive letter (treated as UNC-like)"

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Passed: $testsPassed" -ForegroundColor Green
Write-Host "Failed: $testsFailed" -ForegroundColor $(if ($testsFailed -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($testsFailed -gt 0) {
    exit 1
}
