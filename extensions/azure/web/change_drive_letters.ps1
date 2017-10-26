
#Should be convert in Powershel DSC to manage the reboot  or just create partition on the OS Disks
#http://clemmblog.azurewebsites.net/change-temporary-drive-azure-vm-use-d-persistent-data-disks/
$CurrentPageFile = Get-WmiObject -Query 'select * from Win32_PageFileSetting'
$CurrentPageFile.delete()
Set-WMIInstance -Class Win32_PageFileSetting -Arguments @{name='c:\pagefile.sys';InitialSize = 0; MaximumSize = 0}
#Reboot the machine

$drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'D:'"
Set-WmiInstance -input $drive -Arguments @{ DriveLetter='Z:' }

$CurrentPageFile = Get-WmiObject -Query 'select * from Win32_PageFileSetting'
$CurrentPageFile.delete()
Set-WMIInstance -Class Win32_PageFileSetting -Arguments @{name='e:\pagefile.sys';InitialSize = 0; MaximumSize = 0}
#Reboot the machine
