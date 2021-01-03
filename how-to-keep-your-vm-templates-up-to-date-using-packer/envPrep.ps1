
. .\Get-Packer.ps1
Get-Packer -LocalPath C:\HashiCorp

$logFile = "$env:TEMP\packer.txt"
if (Test-Path -Path $logFile -ErrorAction SilentlyContinue) {
    Remove-Item -Path $logFile -Force -ErrorAction SilentlyContinue
}

# Packer log settings
$env:PACKER_LOG = 1
$env:PACKER_LOG_PATH = $logFile
