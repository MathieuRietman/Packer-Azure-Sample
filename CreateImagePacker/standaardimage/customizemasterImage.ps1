Set-ExecutionPolicy -ExecutionPolicy Unrestricted

#The reason I install the Azure Modules on the session hosts is in the event I need to run something that has to be on a domain joined machine, I know any session host I have has the Azure modules installed.
#Install-Module -Name PowerShellGet -Repository PSGallery -Force -ErrorAction Stop
#Install-Module -Name Az -AllowClobber

# Set this variable to your FSLogix profile directory
$FSLUNC = "\\xxxxxxxx.file.core.windows.net\profiles"
$tenantid = "xxxxxxx-xxxxx-xxxxx-xxxxx-xxxxxxxx"

Write-Host "This script will prepare your image for capture and eventual upload to Azure."

#Disable Automatic Updates
Write-Host "Disabling Automatic Updates..."
New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\ -Name AUe -Force
Set-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AUe -Name "NoAutoUpdate" -Type "Dword" -Value "1"



#Some settings taken from https://www.robinhobo.com/how-to-start-onedrive-and-automatically-sign-in-when-using-a-remoteapp-in-windows-virtual-desktop-wvd/
#You must have OneDrive installed using the /allusers command! If you are not sure, just remove it and reinstall it with the switch.
Write-Host "Setting OneDrive for Business policies" Run this after you install One Drive



#Silently configure user accounts
New-Item -Path HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\ -Name Apps -Force
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "SilentAccountConfig" -Type "Dword" -Value "1"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "FilesOnDemandEnabled" -Type "Dword" -Value "1"
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\OneDrive" -Name "EnableADAL" -Type "Dword" -Value "2"



New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\" -Name RailRunonce -Force
New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\RailRunonce\" -Name "OneDrive" -Force
Set-ItemProperty -Path "HKLM:SYSTEM\CurrentControlSet\Control\Terminal Server\RailRunonce\" -Name "OneDrive" -Value "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe /background" -Type String

#Redirect and move Windows known folders to OneDrive
REG ADD "HKLM\SOFTWARE\Policies\Microsoft\OneDrive" /v "KFMSilentOptIn" /t REG_SZ /d "Your AAD ID GOES HERE" /f

# Enter the following commands into the registry editor to fix 5k resolution support
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxMonitors /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxXResolution /t REG_DWORD /d 5120 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" /v MaxYResolution /t REG_DWORD /d 2880 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs" /v MaxMonitors /t REG_DWORD /d 4 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs" /v MaxXResolution /t REG_DWORD /d 5120 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\rdp-sxs" /v MaxYResolution /t REG_DWORD /d 2880 /f

# Enable timezone redirection
Write-Host "Enabling time zone redirection..."
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" /v fEnableTimeZoneRedirection /t REG_DWORD /d 1 /f

# Disable Storage Sense
Write-Host "Disabling Storage Sense..."
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy /v 01 /t REG_DWORD /d 0 /f

# Remove the WinHTTP proxy
netsh winhttp reset proxy

# Set Coordinated Universal Time (UTC) time for Windows and the startup type of the Windows Time (w32time) service to Automatically
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -name "RealTimeIsUniversal" -Value 1 -Type DWord -force
Set-Service -Name w32time -StartupType Automatic

# Set the power profile to the High Performance
powercfg /setactive SCHEME_MIN

# Make sure that the environmental variables TEMP and TMP are set to their default values
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -name "TEMP" -Value "%SystemRoot%\TEMP" -Type ExpandString -force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -name "TMP" -Value "%SystemRoot%\TEMP" -Type ExpandString -force

# Set Windows services to defaults - This typically fails due to a permissions error, need to investigate why. May be due to differences in client vs Server os
Set-Service -Name dhcp -StartupType Automatic
Set-Service -Name IKEEXT -StartupType Automatic
Set-Service -Name iphlpsvc -StartupType Automatic
Set-Service -Name netlogon -StartupType Manual
Set-Service -Name netman -StartupType Manual
Set-Service -Name nsi -StartupType Automatic
Set-Service -Name termService -StartupType Manual
#Set-Service -Name RemoteRegistry -StartupType Automatic
#Set-Service -Name Winrm -startuptype Automatic

# Ensure RDP is enabled
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -name "fDenyTSConnections" -Value 0 -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -name "fDenyTSConnections" -Value 0 -Type DWord -force

# Set RDP Port to 3389 - Unnecessary for WVD due to reverse connect, but helpful for backdoor administration with a jump box 
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -name "PortNumber" -Value 3389 -Type DWord -force

# Listener is listening on every network interface
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -name "LanAdapter" -Value 0 -Type DWord -force

# Configure NLA
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "UserAuthentication" -Value 1 -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "SecurityLayer" -Value 1 -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -name "fAllowSecProtocolNegotiation" -Value 1 -Type DWord -force

# Set keep-alive value
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -name "KeepAliveEnable" -Value 1  -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -name "KeepAliveInterval" -Value 1  -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -name "KeepAliveTimeout" -Value 1 -Type DWord -force

# Reconnect
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services' -name "fDisableAutoReconnect" -Value 0 -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -name "fInheritReconnectSame" -Value 1 -Type DWord -force
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -name "fReconnectSame" -Value 0 -Type DWord -force

# Limit number of concurrent sessions
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Winstations\RDP-Tcp' -name "MaxInstanceCount" -Value 4294967295 -Type DWord -force


# Turn on Firewall
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True

# Allow WinRM - Optional
#REG add "HKLM\SYSTEM\CurrentControlSet\services\WinRM" /v Start /t REG_DWORD /d 2 /f
#net start WinRM
#Enable-PSRemoting -force
#Set-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Enabled True

# Allow RDP
Set-NetFirewallRule -DisplayGroup "Remote Desktop" -Enabled True

# Enable File and Printer sharing for ping
# Set-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Enabled True

# Add Defender exclusion for FSLogix
# Add-MpPreference -ExclusionPath $FSLUNC

#Add FSLogix settings
New-Item -Path HKLM:\Software\FSLogix\ -Name Profiles -Force
New-Item -Path HKLM:\Software\FSLogix\Profiles\ -Name Apps -Force
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "Enabled" -Type "Dword" -Value "1"
New-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "VHDLocations" -Value $FSLUNC -PropertyType MultiString -Force
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "SizeInMBs" -Type "Dword" -Value "2048"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "IsDynamic" -Type "Dword" -Value "1"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "VolumeType" -Type String -Value "vhd"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "LockedRetryCount" -Type "Dword" -Value "12"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "LockedRetryInterval" -Type "Dword" -Value "5"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "ProfileType" -Type "Dword" -Value "3"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "ConcurrentUserSessions" -Type "Dword" -Value "1"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "RoamSearch" -Type "Dword" -Value "2" 
New-ItemProperty -Path HKLM:\Software\FSLogix\Profiles\Apps -Name "RoamSearch" -Type "Dword" -Value "2"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "FlipFlopProfileDirectoryName" -Type "Dword" -Value "1" 
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "SIDDirNamePattern" -Type String -Value "%username%%sid%"
Set-ItemProperty -Path HKLM:\Software\FSLogix\Profiles -Name "SIDDirNameMatch" -Type String -Value "%username%%sid%"

#install fslogix 
New-Item -ItemType Directory -Force -Path  D:\install
Set-Location D:\install
Invoke-WebRequest -Uri "https://aka.ms/fslogix_download" -OutFile "FSLogix_Apps.zip"
Expand-Archive -LiteralPath 'D:\install\FSLogix_Apps.zip' -DestinationPath "D:\install\FSLogix"

Start-Process -wait  -FilePath "D:\install\FSLogix\x64\Release\FSLogixAppsSetup.exe" -ArgumentList "\install /passive /norestart"

# InstallTeams Onedrive for all useers

Set-Location D:\install
Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/p/?LinkId=248256" -OutFile "OneDriveSetup.exe"

#Configure OneDrive to start at sign-in for all users
REG ADD "HKLM\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /t REG_SZ /d "C:\Program Files (x86)\Microsoft OneDrive\OneDrive.exe /background" /f

Start-Process  -FilePath "D:\install\OneDriveSetup.exe" -ArgumentList "/allusers /qn"
# As this process start also onedrive no wait in this one.
Sleep 20
Set-ItemProperty -Path HKLM:\Software\Policies\Microsoft\OneDrive -Name "KFMSilentOptIn" -Type String -Value $tenantid


# InstallTeams multiuser need HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Teams\IsWVDEnvironment = 1 

New-Item -Path HKLM:\Software\Microsoft\ -Name Teams -Force
Set-ItemProperty -Path HKLM:\Software\Microsoft\Teams -Name "IsWVDEnvironment" -Type "Dword" -Value "1"


Set-Location D:\install
#Download in a seperate steps because error 
#Invoke-WebRequest : Unable to read data from the transport connection: An existing connection was forcibly closed by the remote host

#Add it as a separate item
#{
#    "type": "powershell",
#    "inline": [
#        "Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope LocalMachine -Force",
#        "New-Item -ItemType Directory -Force -Path  D:\\install",
#        "Set-Location D:\\install",
#        "Invoke-WebRequest -Uri 'https://aka.ms/teams64bitmsi' -OutFile 'Teams_windows_x64.msi'"
#                 ]
#},

if (!(Test-Path "d:\install\Teams_windows_x64.msi"))  {
    Invoke-WebRequest -Uri "https://aka.ms/teams64bitmsi" -OutFile "Teams_windows_x64.msi"
  }


Start-Process -wait  -FilePath "msiexec.exe" -ArgumentList "/i D:\install\Teams_windows_x64.msi /l*v  `"D:/install/Teams_windows_x64.log`" ALLUSERS=1 ALLUSER=1"


# InstallTeams Microsoft Visual C++ Redistributable x64: vc_redist.x64.exe needed for WebRTC – Teams WebSocket Optimizations client i

Set-Location d:\install


Invoke-WebRequest -Uri "https://aka.ms/vs/16/release/vc_redist.x64.exe" -OutFile "vc_redist.x64.exe"


Start-Process -wait  -FilePath "d:\install\vc_redist.x64.exe" -ArgumentList "\install /passive /norestart"

 
# InstallTeams WebRTC – Teams WebSocket Optimizations client 

Set-Location d:\install
Invoke-WebRequest -Uri "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4vkL6" -OutFile "MsRdcWebRTCSvc_HostSetup_x64.msi"


Start-Process -wait  -FilePath "msiexec" -ArgumentList " /i d:\install\MsRdcWebRTCSvc_HostSetup_x64.msi /l*v  `"d:/install/MsRdcWebRTCSvc_HostSetup_x64.log`" ALLUSERS=1 ALLUSER=1 ACCEPT_EULA=1 /qn"
