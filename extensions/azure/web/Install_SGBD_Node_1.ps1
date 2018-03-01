# Author :		JPP
# Created :		20/08/2016
# Description :	INSTALLATION SCRIPT OF SQL SERVER 2014 
# Parameter :		CHECK VARIABLES BEFORE START 
# Initial Release: 1.3
# Release: 1.5
# Desc:	Merge Quadria & AZURE install scripts
#		Add SP2 + CU7
# Quadria & AZURE Release
param (
    [Parameter(Mandatory=$true)]
    [int]$DatacenterId,
    [Parameter(Mandatory=$true)]
    [string]$DomainNameInput,
    [Parameter(Mandatory=$true)]
	[string]$LoginNameInput,
	[Parameter(Mandatory=$true)]
	[string]$LoginPassword,
	[Parameter(Mandatory=$true)]
	[string]$SaPassword,
	[Parameter(Mandatory=$true)]
	$InstallFailoverCluster 
)

#Variables
$WinSources = "C:\Sources\W2K12R2\sources\sxs"


[Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath
$Chemin=[Environment]::CurrentDirectory
$TEMP  =Get-Item Env:TEMP| Select-Object -inputobject {$_.value}

Start-Transcript $TEMP\SQL_SERVER_2014_Install.log
Write-Host "INSTALLATION SCRIPT OF SQL SERVER 2014 Ver 1.5 `r`n"

#SQL SERVER Variable
$SQLPort = 1433
$SQLProbePort = 59999

#Partition configuration
$DatacenterPartitionConf = @{}
$DatacenterPartitionConf = Import-Csv Datacenter_Partition_Conf.csv | select-object DatacenterId,Datacenter,DataDL,DataLabel,DataAUS,LogDL,LogLabel,LogAUS,DataTempdb,DataTempdbLabel
[int]$first = $DatacenterPartitionConf | select-object -inputobject {$_.DatacenterId} -first 1
[int]$last = $DatacenterPartitionConf | select-object -inputobject {$_.DatacenterId} -last 1
$DatacenterPartitionConf | select-object DatacenterId,Datacenter
#[int]$Read = Read-host  "Enter Datacenter ID"
if ($DatacenterId -notin $first..$last ) {Throw "No Datacenter Choosen - Install abort"}
$DatacenterPartitionConfTarget = $DatacenterPartitionConf | where-object {$_.DatacenterId -eq $DatacenterId}

$DatacenterId=$DatacenterPartitionConfTarget.DatacenterId
$DataDL=$DatacenterPartitionConfTarget.DataDL
$DataAUS=$DatacenterPartitionConfTarget.DataAUS
$DataLabel=$DatacenterPartitionConfTarget.DataLabel
$LogDL=$DatacenterPartitionConfTarget.LogDL
$LogAUS=$DatacenterPartitionConfTarget.LogAUS
$LogLabel=$DatacenterPartitionConfTarget.LogLabel
$DataTempdb=$DatacenterPartitionConfTarget.DataTempdb
$DataTempdbLabel=$DatacenterPartitionConfTarget.DataTempdbLabel


$USERDOMAIN=Get-ChildItem Env:USERDOMAIN
#$DomainNameInput = Read-Host "Name of the Domain (default: "$USERDOMAIN.Value")"
if ($DomainNameInput -match $null) {$DomainName = $USERDOMAIN.Value}
else {$DomainName = $DomainNameInput}
#$LoginNameInput = Read-Host "Name of the Service Account (default: SQLSERVERUSER)"
if ($LoginNameInput -match $null) {$LoginName = "SQLSERVERUSER"}
else {$LoginName = $LoginNameInput}

$LoginDomain =  $DomainName+"\"+$LoginName

#$SecurePassword = Read-Host -assecurestring "Password of the Service Account "$LoginName""
$SecurePassword = ConvertTo-SecureString $LoginPassword -AsPlainText -Force
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
$SQLServiceAccountPwd = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

#$SecurePassword = Read-Host -assecurestring "Password of the Sa Account"
$SecureSaPassword = ConvertTo-SecureString $SaPassword -AsPlainText -Force
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureSaPassword)
$SAPWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 

if ($DatacenterId -eq 1) {
	$DataTempdbPath = $DataTempdb+":\MSSQL\DATA"
	$IsBPEActive = 0
	}
else {$DataTempdbPath = $DataTempdb+":\MSSQL"
	 }

$inifile = Get-Content ConfigurationFileTemplate.ini
$inifile = $inifile -replace "DomainName", $DomainName
$inifile = $inifile -replace "LoginName", $LoginName
$inifile = $inifile -replace "DataDL", $DataDL
$inifile = $inifile -replace "LogDL", $LogDL
$inifile = $inifile -replace "DataTempdb", $DataTempdbPath
$inifile | out-file ".\ConfigurationFile.ini"

#$InstallFailoverCluster = Read-Host "Install Failover-Clustering (Y)es or (N)o :Default Y `r`n"
if ($InstallFailoverCluster -Contains "") {$InstallFailoverCluster = "Y"}

TRY {

write-host "Partition CHECK `r`n"
Import-module .\function_TS_Create_Partition.ps1  -force
TS_Create_Partition -DataDL $DataDL -DataAUS $DataAUS -DataLabel $DataLabel -LogDL $LogDL -LogAUS $LogAUS -LogLabel $LogLabel -DataTempdb $DataTempdb -DataTempdbLabe $DataTempdbLabel
write-host "OK `r`n" -foreground green 

#if ($DatacenterId -eq 2) {iCACLS $DataTempdbPath /Grant ("$LoginDomain" + ':(OI)(CI)F') /T}

# Pending Reboot
#write-host "Pending Reboot `r`n"
#Import-module .\Get-PendingReboot.ps1  -force
#$RebootPending = Get-PendingReboot | Select-Object RebootPending  -ErrorAction Stop
#if ($RebootPending.RebootPending -match "True")
#	{Throw "Server must restart before the begining of the install"}
#write-host "OK `r`n" -foreground green 

write-host "Install .Net 3.5 Framework `r`n"
#Install-WindowsFeature -Name NET-Framework-Core -Source $WinSources  -ErrorAction Stop
$CheckInstall = Get-WindowsFeature  NET-Framework-Core |  Select-Object -inputobject {$_.installstate}
if ($CheckInstall -ne "Installed") 	
	{Install-WindowsFeature -Name NET-Framework-Core -Source $WinSources -ErrorAction Stop} 
write-host "OK `r`n" -foreground green 

if ($InstallFailoverCluster -Contains "Y") 
	{
	write-host "Install Failover-Clustering `r`n"
	$CheckInstall = Get-WindowsFeature  Failover-Clustering |  Select-Object -inputobject {$_.installstate}
	if ($CheckInstall -ne "Installed") 	
		{Install-windowsfeature -Name RSAT-Clustering -IncludeAllSubFeature -Source $WinSources  -ErrorAction Stop
		Install-WindowsFeature -Name Failover-Clustering -IncludeManagementTools -Source $WinSources  -ErrorAction Stop} 
	write-host "OK `r`n" -foreground green }

write-host "Set Policy	Security Setting `r`n"
write-host "Perform volume maintenance tasks for login "$DomainName"\"$LoginName" `r`n"
# DO IT BEFORE install SQL SERVER
Import-module .\function_Add-LoginToLocalPrivilege.ps1  -force
Add-LoginToLocalPrivilege -Domain $DomainName -Account $LoginName -Privilege "SeManageVolumePrivilege" -Confirm:$false   -ErrorAction Stop
write-host "OK `r`n" -foreground green 

write-host "Disable Firewall Domain,Public,Private Profile`r`n"
#netsh advfirewall set allprofiles state off  -ErrorAction Stop #old one
netsh advfirewall firewall add rule name='Load Balance Probe (TCP-In)' localport=$SQLProbePort dir=in action=allow protocol=TCP | Out-Null #Probe port for ILB
netsh advfirewall firewall add rule name='Availability Group Listener (TCP-In)' localport=$SQLPort dir=in action=allow protocol=TCP | Out-Null #SQL SERVER Instance Port
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False -ErrorAction Stop
write-host "OK `r`n" -foreground green 

write-host "Install SQL SERVER Instance `r`n"
$ConfigIni = "/ConfigurationFile=ConfigurationFile.ini"
function global:InstallSQL ($SQLServiceAccountPwd,$SAPWD,$ConfigIni)	{./Setup.exe /AGTSVCPASSWORD=$SQLServiceAccountPwd  /SQLSVCPASSWORD=$SQLServiceAccountPwd /SAPWD=$SAPWD $ConfigIni}
InstallSQL $SQLServiceAccountPwd $SAPWD $ConfigIni	-ErrorAction Stop


#Install check
Write-Host "Install Check"

$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
Write-Host $reg
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSSQL12.MSSQLSERVER\\MSSQLServer\\CurrentVersion\\" )
Write-Host $regKey
if ($regkey.count -eq 0) {write-host "SQL SERVER 2014 INSTALL FAILED `r`n"}

write-host "Install SQL SERVER 2014 OK `r`n" -foreground green 

$env:PSModulePath += ";C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\"

write-host "Installation complements TalentSoft `r`n"

write-host "FilterPack64bit `r`n"
Start-Process ./Complements\Setup1.exe -ArgumentList "/quiet /passive /norestart" -wait -ErrorAction Stop
write-host "filterpacksp2010-kb2687447-fullfile-x64-en-us `r`n"
Start-Process ./Complements\Setup2.exe -ArgumentList "/quiet /passive /norestart" -wait -ErrorAction Stop
write-host "PDFFilter64Setup `r`n"
Start-Process ./Complements\Setup3.msi -ArgumentList "/quiet /passive /norestart" -wait -ErrorAction Stop


write-host "Configuration PDFFilter `r`n"
regsvr32.exe "C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\PDFFilter.dll" /s
$PDFFilterCheck = reg query HKLM\SOFTWARE\Classes /s /f PDFFilter.dll
Function Global:Add-Path {
			Param (
			[String]$NewPath ="C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\"
					 )
			Process {
			$Reg = "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment"
			$OldPath = (Get-ItemProperty -Path "$Reg" -Name PATH).Path
			$NewPath = $OldPath + ’;’ + $NewPath
			Set-ItemProperty -Path "$Reg" -Name PATH -Value $NewPath
				   } #End of Process
			} 
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
Write-Host $reg
$regKey= $reg.OpenSubKey("System\\CurrentControlSet\\Control\\Session Manager\\Environment\\" )
Write-Host $regKey
$PdfFilterPath = $regkey.GetValue("Path")
Write-Host $PdfFilterPath
if ($PdfFilterPath -notlike "*C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\*") {Add-Path  -ErrorAction Stop}
Write-Host $PDFFilterCheck
if ($PDFFilterCheck.contains("End of search: 0 match(es) found.") -eq $True) {write-host "Setting PDFFilter FAILED `r`n" -foreground red}

write-host "Install Complements TalentSoft OK `r`n" -foreground green 


write-host "SQL SERVER SP2 `r`n"
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSSQL12.MSSQLSERVER\\MSSQLServer\\CurrentVersion\\" )
$SQLVersion = $regkey.GetValue("CurrentVersion")
$SQLVersion = $SQLVersion -replace '[.]',''
Set-Location $Chemin

if ($SQLVersion -lt 12041001) {Start-Process ./SQLServer2014SP2-KB3171021-x64-ENU.exe  -ArgumentList "/quiet /ACTION=Patch /INSTANCENAME=MSSQLSERVER /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS"  -ErrorAction Stop -wait -Verb runas}

Set-Location $Chemin
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSSQL12.MSSQLSERVER\\MSSQLServer\\CurrentVersion\\" )
$SQLVersion = $regkey.GetValue("CurrentVersion")
$SQLVersion = $SQLVersion -replace '[.]',''
if ($SQLVersion -ne 12050000) {write-host "SQL SERVER 2014 SP2 INSTALL FAILED `r`n" -foreground red}

write-host "SQL SERVER 2014 SP2 INSTALL OK `r`n" -foreground green 


write-host "SQL SERVER SP2 CU7 `r`n"
Set-Location $Chemin
$query = "SELECT  SERVERPROPERTY('ProductVersion') AS ProductVersion"
$SQLVersion = Invoke-SQLCmd -Query $Query -Server $env:computername -Database master  -ErrorAction Stop
$SQLVersion = $SQLVersion.ProductVersion -replace '[.]',''
Set-Location $Chemin

if ($SQLVersion -eq 12050000) 
	{Start-Process ./SQLServer2014-KB4032541-x64.exe  -ArgumentList "/quiet /ACTION=Patch /INSTANCENAME=MSSQLSERVER /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS"  -ErrorAction Stop -wait -Verb runas}

$query = "SELECT  SERVERPROPERTY('ProductVersion') AS ProductVersion"
$SQLVersion = Invoke-SQLCmd -Query $Query -Server $env:computername -Database master  -ErrorAction Stop
$SQLVersion = $SQLVersion.ProductVersion -replace '[.]',''
if ($SQLVersion -ne 12055560) {write-host "SQL SERVER 2014 SP2 CU7 INSTALL FAILED `r`n" -foreground red}

write-host "SQL SERVER 2014 SP2 CU7 INSTALL OK `r`n" -foreground green 

}
CATCH {throw}
