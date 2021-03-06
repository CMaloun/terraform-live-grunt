﻿# Author :		JPP
# Created :		29/01/2018
# Description :	INSTALLATION SCRIPT OF SQL SERVER Analysis Services 2014 
# Parameter :		CHECK VARIABLES BEFORE START 
# Initial Release: 1.0
# Release: 1.0
# Desc:	
# Quadria & AZURE Release

#Variables


param (
    [Parameter(Mandatory=$true)]
    [int]$DatacenterId,
    [Parameter(Mandatory=$true)]
    [string]$DomainNameInput,
    [Parameter(Mandatory=$true)]
	[string]$LoginNameInput,
	[Parameter(Mandatory=$true)]
	[string]$LoginPassword 
)

$WinSources = "C:\Sources\W2K12R2\sources\sxs"


[Environment]::CurrentDirectory=(Get-Location -PSProvider FileSystem).ProviderPath
$Chemin=[Environment]::CurrentDirectory
$TEMP  =Get-Item Env:TEMP| Select-Object -inputobject {$_.value}

Start-Transcript $TEMP\SQL_SERVER_2014_Install.log
Write-Host "INSTALLATION SCRIPT OF SQL SERVER 2014 Analysis Services Ver 1.0 `r`n"

#SQL SERVER Variable
$SQLPort = 1433
$SQLProbePort = 59999

#Partition configuration
$DatacenterPartitionConf = @{}
$DatacenterPartitionConf = Import-Csv Datacenter_Partition_Conf.csv | select-object DatacenterId,Datacenter,DataDL,DataLabel,DataAUS
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
# $LogDL=$DatacenterPartitionConfTarget.LogDL
# $LogAUS=$DatacenterPartitionConfTarget.LogAUS
# $LogLabel=$DatacenterPartitionConfTarget.LogLabel
# $DataTempdb=$DatacenterPartitionConfTarget.DataTempdb
# $DataTempdbLabel=$DatacenterPartitionConfTarget.DataTempdbLabel


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

# $SecurePassword = Read-Host -assecurestring "Password of the Sa Account"
# $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
# $SAPWD = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR) 

# if ($DatacenterId -eq 1) {
# 	$DataTempdbPath = $DataTempdb+":\MSSQL\DATA"
# 	$IsBPEActive = 0
# 	}
# else {$DataTempdbPath = $DataTempdb+":\MSSQL"
# 	 }

$inifile = Get-Content ConfigurationFileTemplateAS.ini
$inifile = $inifile -replace "DomainName", $DomainName
$inifile = $inifile -replace "LoginName", $LoginName
$inifile = $inifile -replace "DataDL", $DataDL
# $inifile = $inifile -replace "LogDL", $LogDL
# $inifile = $inifile -replace "DataTempdb", $DataTempdbPath
$inifile | out-file ".\ConfigurationFileAS.ini"

# $InstallFailoverCluster = Read-Host "Install Failover-Clustering (Y)es or (N)o :Default Y `r`n"
# if ($InstallFailoverCluster -Contains "") {$InstallFailoverCluster = "Y"}

TRY {

write-host "Partition CHECK `r`n"
Import-module .\function_TS_Create_Partition.ps1  -force
TS_Create_Partition -DataDL $DataDL -DataAUS $DataAUS -DataLabel $DataLabel #-LogDL $LogDL -LogAUS $LogAUS -LogLabel $LogLabel 
write-host "OK `r`n" -foreground green 

# if ($DatacenterId -eq 2) {iCACLS $DataTempdbPath /Grant ("$LoginDomain" + ':(OI)(CI)F') /T}

# Pending Reboot
write-host "Pending Reboot `r`n"
Import-module .\Get-PendingReboot.ps1  -force
$RebootPending = Get-PendingReboot | Select-Object RebootPending  -ErrorAction Stop
if ($RebootPending.RebootPending -match "True")
	{Throw "Server must restart before the begining of the install"}
write-host "OK `r`n" -foreground green 

write-host "Install .Net 3.5 Framework `r`n"
#Install-WindowsFeature -Name NET-Framework-Core -Source $WinSources  -ErrorAction Stop
$CheckInstall = Get-WindowsFeature  NET-Framework-Core |  Select-Object -inputobject {$_.installstate}
if ($CheckInstall -ne "Installed") 	
	{Install-WindowsFeature -Name NET-Framework-Core -Source $WinSources -ErrorAction Stop} 
write-host "OK `r`n" -foreground green 

# if ($InstallFailoverCluster -Contains "Y") 
# 	{
# 	write-host "Install Failover-Clustering `r`n"
# 	$CheckInstall = Get-WindowsFeature  Failover-Clustering |  Select-Object -inputobject {$_.installstate}
# 	if ($CheckInstall -ne "Installed") 	
# 		{Install-windowsfeature -Name RSAT-Clustering -IncludeAllSubFeature -Source $WinSources  -ErrorAction Stop
# 		Install-WindowsFeature -Name Failover-Clustering –IncludeManagementTools -Source $WinSources  -ErrorAction Stop} 
# 	write-host "OK `r`n" -foreground green }

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

write-host "Install SQL SERVER Analysis Services Instance `r`n"
$ConfigIni = "/ConfigurationFile=ConfigurationFileAS.ini"
function global:InstallSQL ($SQLServiceAccountPwd,$ConfigIni)	{./Setup.exe /ASSVCPASSWORD=$SQLServiceAccountPwd $ConfigIni}
InstallSQL $SQLServiceAccountPwd $ConfigIni	-ErrorAction Stop


#Install check
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSAS12.MSSQLSERVER\\MSSQLServer\\CurrentVersion\\" )
if ($regkey.count -eq 0) {write-host "SQL SERVER 2014 INSTALL FAILED `r`n" -foreground red 
						break}
write-host "Install SQL SERVER Analysis Services 2014 OK `r`n" -foreground green 

$env:PSModulePath += ";C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\"

# write-host "Installation complements TalentSoft `r`n"

# write-host "FilterPack64bit `r`n"
# Start-Process ./Complements\Setup1.exe -ArgumentList "/quiet /passive /norestart" -wait -ErrorAction Stop
# write-host "filterpacksp2010-kb2687447-fullfile-x64-en-us `r`n"
# Start-Process ./Complements\Setup2.exe -ArgumentList "/quiet /passive /norestart" -wait -ErrorAction Stop
# write-host "PDFFilter64Setup `r`n"
# Start-Process ./Complements\Setup3.msi -ArgumentList "/quiet /passive /norestart" -wait -ErrorAction Stop


# write-host "Configuration PDFFilter `r`n"
# regsvr32.exe "C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\PDFFilter.dll" /s
# $PDFFilterCheck = reg query HKLM\SOFTWARE\Classes /s /f PDFFilter.dll
# Function Global:Add-Path {
# 			Param (
# 			[String]$NewPath ="C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\"
# 					 )
# 			Process {
# 			$Reg = "Registry::HKLM\System\CurrentControlSet\Control\Session Manager\Environment"
# 			$OldPath = (Get-ItemProperty -Path "$Reg" -Name PATH).Path
# 			$NewPath = $OldPath + ’;’ + $NewPath
# 			Set-ItemProperty -Path "$Reg" -Name PATH –Value $NewPath
# 				   } #End of Process
# 			} 
# $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
# $regKey= $reg.OpenSubKey("System\\CurrentControlSet\\Control\\Session Manager\\Environment\\" )
# $PdfFilterPath = $regkey.GetValue("Path")
# if ($PdfFilterPath -notlike "*C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\*") {Add-Path  -ErrorAction Stop}	
# if ($PDFFilterCheck.contains("End of search: 0 match(es) found.") -eq $True) {write-host "Setting PDFFilter FAILED `r`n" -foreground red 
# 								break}

# write-host "Install Complements TalentSoft OK `r`n" -foreground green 


write-host "SQL SERVER 2014 SP2 `r`n"
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSAS12.MSSQLSERVER\\MSSQLServer\\CurrentVersion\\" )
$SQLVersion = $regkey.GetValue("CurrentVersion")
$SQLVersion = $SQLVersion -replace '[.]',''
Set-Location $Chemin

if ($SQLVersion -lt 12041001) {Start-Process ./SQLServer2014SP2-KB3171021-x64-ENU.exe  -ArgumentList "/quiet /ACTION=Patch /INSTANCENAME=MSSQLSERVER /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS"  -ErrorAction Stop -wait -Verb runas}

Set-Location $Chemin
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSAS12.MSSQLSERVER\\MSSQLServer\\CurrentVersion\\" )
$SQLVersion = $regkey.GetValue("CurrentVersion")
$SQLVersion = $SQLVersion -replace '[.]',''
if ($SQLVersion -ne 12050000) {write-host "SQL SERVER 2014 SP2 INSTALL FAILED `r`n" -foreground red 
						break}

write-host "SQL SERVER 2014 SP2 INSTALL OK `r`n" -foreground green 


write-host "SQL SERVER SP2 CU7 `r`n"
Set-Location $Chemin

$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSAS12.MSSQLSERVER\\Setup\\Analysis_Server_Full\\" )
$SQLVersion = $regkey.GetValue("PatchLevel")
$SQLVersion = $SQLVersion -replace '[.]',''
Set-Location $Chemin

if ($SQLVersion -eq 12250000) 
	{Start-Process ./SQLServer2014-KB4032541-x64.exe  -ArgumentList "/quiet /ACTION=Patch /INSTANCENAME=MSSQLSERVER /IACCEPTSQLSERVERLICENSETERMS /INDICATEPROGRESS"  -ErrorAction Stop -wait -Verb runas}

$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSAS12.MSSQLSERVER\\Setup\\Analysis_Server_Full\\" )
$SQLVersion = $regkey.GetValue("PatchLevel")
$SQLVersion = $SQLVersion -replace '[.]',''

if ($SQLVersion -ne 12255560) {write-host "SQL SERVER 2014 SP2 CU7 INSTALL FAILED `r`n" -foreground red 
break}

write-host "SQL SERVER 2014 SP2 CU7 INSTALL OK `r`n" -foreground green 
Set-Location $Chemin

# write-host "Post Conf SQL SERVER `r`n"

# Start-Sleep -s 10

# Set-Location $Chemin
# $SQLConffile = Get-Content SQL_SERVER_ConfigurationTemplate.sql
# $SQLConffile = $SQLConffile -replace "DataTempdb", $DataTempdbPath
# $SQLConffile = $SQLConffile -replace "DatacenterId", $DatacenterId
# $SQLConffile | out-file ".\SQL_SERVER_Configuration.sql"

# $QueryFile = "SQL_SERVER_Configuration.sql";
# Invoke-SQLCmd -InputFile $QueryFile -Server $env:computername -Database master  -ErrorAction Stop
# write-host "SQL SERVER 2014 post configuration OK `r`n" -foreground green 

# write-host "Cleaning install `r`n"
# try {
# 	if ($DatacenterId -eq 2)
# 		{
# 		$DataToDelete = $DataTempdbPath+"\MSSQL"
# 		$testpathDataToDelete  = Test-Path $DataToDelete
# 		if ($testpathDataToDelete -match "True") {	Stop-Service "SQLSERVERAGENT"
# 													Stop-Service "MSSQLSERVER"
# 													Remove-Item $DataToDelete -ErrorAction Continue -Recurse}
# 		Start-Service "MSSQLSERVER"
# 		Start-Service "SQLSERVERAGENT"
# 		}
# 	}

# 	catch {
# 		Write-Warning -Message "Cleaning Failed `r`n"
# 		}
	
# if ($DatacenterId -eq 2) {
# 		#Check Free Space on AZURE Temporary Storage
# 		$logicaldisk = Get-WMIObject Win32_Logicaldisk
# 		$logicaldiskMB = $logicaldisk | Select-Object DeviceID,VolumeName,@{Name="FreeMB";Expression={[math]::Round($_.Freespace/1MB,0)}}
# 		$FreeMBD = $logicaldiskMB | Where-Object {$_.VolumeName -eq "Temporary Storage"}
# 		$Query = "select cast(value_in_use as nvarchar(100)) as BPEValueToSet  from sys.configurations where name = 'max server memory (MB)'"
# 		$BPEValueToSet = Invoke-SQLCmd -Query $Query -Server $env:computername -Database master  -ErrorAction Stop
# 		[int]$BPEValueToSet = $BPEValueToSet.BPEValueToSet
# 		if ($FreeMBD.FreeMB -gt ($BPEValueToSet + 1000)) {$IsBPEActive = 1} #1000 for minimum free space on disk
# 		else {$IsBPEActive = 0}
# 		if ($IsBPEActive -eq 1){
# 				write-host "SQL SERVER 2014 BPE configuration `r`n"
# 				Set-Location $Chemin
# 				$SQLConfBPE = Get-Content SQL_SERVER_BPETemplate.sql
# 				$SQLConfBPE = $SQLConfBPE -replace "DataTempdb", $DataTempdbPath
# 				$SQLConfBPE = $SQLConfBPE -replace "DatacenterId", $DatacenterId
# 				$SQLConfBPE = $SQLConfBPE -replace "IsBPEActive", $IsBPEActive
# 				$SQLConfBPE = $SQLConfBPE -replace "BPEValueToSet", $BPEValueToSet
# 				$SQLConfBPE | out-file ".\SQL_SERVER_BPE.sql"
# 				$QueryFile = "SQL_SERVER_BPE.sql";
# 				Invoke-SQLCmd -InputFile $QueryFile -Server $env:computername -Database master  -ErrorAction Stop
# 				write-host "SQL SERVER 2014 BPE configuration OK `r`n" -foreground green 
# 				}

# 		}



 write-host "DBAtools install `r`n"
 Set-Location $Chemin
 Set-Location .\DbatoolsInstall
 #./dbatoolsInstall.ps1 -ErrorAction Stop
 write-host "DBAtools install OK `r`n" -foreground green 

# Write-Host "Master Stored Procedure Installation `r`n" 
# Set-Location $Chemin
# $MasterStoredProcedure = Get-ChildItem .\TSStoredProcedure\*.sql -file | Select-Object fullname,name
# If ($MasterStoredProcedure -eq $null) {throw "No files for Master Stored Procedure Installation"}
# $MasterStoredProcedure | ForEach-Object  -process {Write-Host $_.name
# 												Invoke-SQLCmd -InputFile $_.fullname -Server $CPUInstance -Database master  -ErrorAction Stop}
												
# write-host "Master Stored Procedure install OK `r`n" -foreground green 

#Set-Location $Chemin

 }
 CATCH {throw}

write-host "SQL Server Services Recovery restart option `r`n"
$service = Get-WMIObject win32_service | Where-Object {$_.name -eq "MSSQLSERVER" -or $_.name -eq "SQLSERVERAGENT" -or $_.name -eq "SQLBrowser" }
$service  | ForEach-Object  -process {sc.exe failure $_.name reset= 86400 actions= restart/120000/restart/120000/restart/120000}	

write-host "Windows Power plan `r`n"
Try {
        $HighPerf = powercfg -l | ForEach-Object{if($_.contains("High performance")) {$_.split()[3]}}
        $CurrPlan = $(powercfg -getactivescheme).split()[3]
        if ($CurrPlan -ne $HighPerf) 
		{powercfg -setactive $HighPerf
		write-host "Power plan set to high performance `r`n" -foregroundcolor green}
    } 
Catch {
        Write-Warning -Message "Unable to set power plan to high performance `r`n"
    }



# REBOOT THE SERVER AFTER INSTALLATION
Write-host "INSTALL DONE - REBOOT THE SERVER AFTER INSTALLATION - Press any key to Reboot `r`n" -foreground green
#Stop-Transcript
#$EndBatch = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
#Restart-Computer -Force -Confirm:$false
#Restart-Computer -Force



