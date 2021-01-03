$ErrorActionPreference = "Stop"

Write-Output ":: Set network connection profile to private"
# Move all (non-domain) network interfaces into the private profile to make winrm happy (it needs at least one private interface)
Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -ne 'DomainAuthenticated' } | Set-NetConnectionProfile -NetworkCategory Private

Write-Output ":: Open RDP"
netsh advfirewall firewall add rule name="Open Port 3389" dir=in action=allow protocol=TCP localport=3389
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 0 /f

Write-Output ":: Reset auto logon count"
# https://docs.microsoft.com/en-us/windows-hardware/customize/desktop/unattend/microsoft-windows-shell-setup-autologon-logoncount#logoncount-known-issue
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name AutoLogonCount -Value 0

Write-Output ":: Setup pagefile"
$IsAutomaticManagedPagefile = Get-WmiObject -Class Win32_ComputerSystem | ForEach-Object { $_.AutomaticManagedPagefile }
If ($IsAutomaticManagedPagefile) {
    # We must enable all the privileges of the current user before the command makes the WMI call
    $SystemInfo = Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
    $SystemInfo.AutomaticManagedPageFile = $false
    [Void]$SystemInfo.Put()
}

$PageFile = Get-WmiObject -Class Win32_PageFileSetting
Try	{
    If ($null -ne $PageFile) {
        $PageFile.Delete()
    }
    $NewPageFile = Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{Name = "C:\pagefile.sys" }

    $NewPageFile.InitialSize = 256
    $NewPageFile.MaximumSize = 256
    [Void]$NewPageFile.Put()
}
Catch {
    Write-Output ":: Execution Results: No Permission - Failed to set page file size!"
}

Write-Output ":: Set power scheme to High performance"
$power_active = (POWERCFG /GETACTIVESCHEME).Split()[3]
$power_high = (POWERCFG /LIST | Select-String "High performance").Line.Split()[3]
if ($power_active -ne $power_high) {
    POWERCFG /SETACTIVE $power_high
    $power_active = (POWERCFG /GETACTIVESCHEME).Split()[3]
}

Write-Output ":: Disable the hibernate feature"
POWERCFG /HIBERNATE OFF

Write-Output ":: Stopping and disabling Windows Search indexing service..."
Get-WmiObject Win32_Volume -Filter "IndexingEnabled=$true" | Set-WmiInstance -Arguments @{IndexingEnabled = $false }

if (Get-Service -Name WSearch -ErrorAction SilentlyContinue) {
    Write-Output ":: Stopping and disabling WSearch service"
    Stop-Service "WSearch" -WarningAction SilentlyContinue
    Set-Service "WSearch" -StartupType Disabled
}

Write-Output ":: Stopping and disabling Print Spooler"
if (Get-Service -Name Spooler -ErrorAction SilentlyContinue) {
    Write-Output ":: Stopping and disabling Spooler service"
    Stop-Service "Spooler" -WarningAction SilentlyContinue
    Set-Service "Spooler" -StartupType Disabled
}

Write-Output ":: Disabling Windows Error Reporting"
Disable-WindowsErrorReporting

Write-Output ":: Disabling ngen scheduled task"
$ngen = Get-ScheduledTask '.NET Framework NGEN v4.0.30319', '.NET Framework NGEN v4.0.30319 64'
$ngen | Disable-ScheduledTask

Write-Output ":: Running ngen.exe"
. c:\Windows\Microsoft.NET\Framework64\v4.0.30319\ngen.exe executeQueuedItems

Write-Output ":: Cleaning Temp Files"
try {
    TAKEOWN /D Y /R /F "C:\Windows\Temp\*"
    ICACLS "C:\Windows\Temp\*" /grant:r administrators:F /T /C /Q  2>&1
    Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
}
catch { }

Write-Output ":: Cleaning updates..."
Stop-Service -Name wuauserv -Force
Remove-Item C:\Windows\SoftwareDistribution\Download\* -Recurse -Force
Start-Service -Name wuauserv

Write-Output ":: Optimizing Drive"
Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -ne $null } | Optimize-Volume

Write-Output ":: Wiping empty space on disk..."
$FilePath = "c:\zero.tmp"
$Volume = Get-WmiObject win32_logicaldisk -filter "DeviceID='C:'"
$ArraySize = 64kb
$SpaceToLeave = $Volume.Size * 0.05
$FileSize = $Volume.FreeSpace - $SpacetoLeave
$ZeroArray = New-Object byte[]($ArraySize)

$Stream = [io.File]::OpenWrite($FilePath)
try {
    $CurFileSize = 0
    while ($CurFileSize -lt $FileSize) {
        $Stream.Write($ZeroArray, 0, $ZeroArray.Length)
        $CurFileSize += $ZeroArray.Length
    }
}
finally {
    if ($Stream) {
        $Stream.Close()
    }
}
Remove-Item $FilePath

Write-Output ":: Setting timezone"
$timeZone = "Romance Standard Time"
Set-TimeZone $timezone

Write-Output ":: Cleaning all event logs..."
Get-EventLog -LogName * | ForEach-Object { Clear-EventLog $_.Log }
