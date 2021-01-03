$isCore = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\').InstallationType -eq "Server Core"

if ($isCore -eq $true) {
    Write-Output ":: Configuring Default Shell"

    # Use C# to leverage the Win32API
    $definition = @"
using System;
using System.Runtime.InteropServices;

namespace Win32Api {
    public class NtDll {
        [DllImport("ntdll.dll", EntryPoint = "RtlAdjustPrivilege")]
        public static extern int RtlAdjustPrivilege(ulong Privilege, bool Enable, bool CurrentThread, ref bool Enabled);
    }
}
"@

    Add-Type -TypeDefinition $definition -PassThru
    $bEnabled = $false

    # Enable SeTakeOwnershipPrivilege
    $res = [Win32Api.NtDll]::RtlAdjustPrivilege(9, $true, $false, [ref]$bEnabled)

    # Take ownership of the registry key
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AlternateShells\AvailableShells", [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
    $acl = $key.GetAccessControl()
    $acl.SetOwner([System.Security.Principal.NTAccount]"Administrators")
    $key.SetAccessControl($acl)

    # Set Full Control for Administrators
    $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Administrators", "FullControl", "Allow")
    $acl.AddAccessRule($rule)
    [void]$key.SetAccessControl($acl)

    # Create Registry Value
    $customArgs = '-noexit -command "& {Set-Location $env:USERPROFILE; Clear-Host}"'
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AlternateShells\AvailableShells" -Name 90000 -Value "%SYSTEMROOT%\System32\WindowsPowerShell\v1.0\Powershell.exe ${customArgs}" -PropertyType String
}
else {
    Write-Output ":: Configuring Default Shell - not needed as we're not running Core"
}
