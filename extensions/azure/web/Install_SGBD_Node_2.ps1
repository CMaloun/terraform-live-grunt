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

try {

write-host "Post Conf SQL SERVER `r`n"

Start-Sleep -s 10

Set-Location $Chemin
$SQLConffile = Get-Content SQL_SERVER_ConfigurationTemplate.sql
$SQLConffile = $SQLConffile -replace "DataTempdb", $DataTempdbPath
$SQLConffile = $SQLConffile -replace "DatacenterId", $DatacenterId
$SQLConffile | out-file ".\SQL_SERVER_Configuration.sql"

$QueryFile = "SQL_SERVER_Configuration.sql";
write-host "Before Invoke-SQL-Cmd"
Invoke-SQLCmd -InputFile $QueryFile -Server $env:computername -Database master  -ErrorAction Stop
write-host "SQL SERVER 2014 post configuration OK `r`n" -foreground green 

write-host "Cleaning install `r`n"
try {
	if ($DatacenterId -eq 2)
		{
		$DataToDelete = $DataTempdbPath+"\MSSQL"
		$testpathDataToDelete  = Test-Path $DataToDelete
		if ($testpathDataToDelete -match "True") {	Stop-Service "SQLSERVERAGENT"
													Stop-Service "MSSQLSERVER"
													Remove-Item $DataToDelete -ErrorAction Continue -Recurse}
		Start-Service "MSSQLSERVER"
		Start-Service "SQLSERVERAGENT"
		}
	}

	catch {
		Write-Warning -Message "Cleaning Failed `r`n"
		}
	
if ($DatacenterId -eq 2) {
		#Check Free Space on AZURE Temporary Storage
		$logicaldisk = Get-WMIObject Win32_Logicaldisk
		$logicaldiskMB = $logicaldisk | Select-Object DeviceID,VolumeName,@{Name="FreeMB";Expression={[math]::Round($_.Freespace/1MB,0)}}
		$FreeMBD = $logicaldiskMB | Where-Object {$_.VolumeName -eq "Temporary Storage"}
		$Query = "select cast(value_in_use as nvarchar(100)) as BPEValueToSet  from sys.configurations where name = 'max server memory (MB)'"
		$BPEValueToSet = Invoke-SQLCmd -Query $Query -Server $env:computername -Database master  -ErrorAction Stop		
		[int]$BPEValueToSet = $BPEValueToSet.BPEValueToSet
		if ($FreeMBD.FreeMB -gt ($BPEValueToSet + 1000)) {$IsBPEActive = 1} #1000 for minimum free space on disk
		else {$IsBPEActive = 0}
		if ($IsBPEActive -eq 1){
				write-host "SQL SERVER 2014 BPE configuration `r`n"
				Set-Location $Chemin
				$SQLConfBPE = Get-Content SQL_SERVER_BPETemplate.sql
				$SQLConfBPE = $SQLConfBPE -replace "DataTempdb", $DataTempdbPath
				$SQLConfBPE = $SQLConfBPE -replace "DatacenterId", $DatacenterId
				$SQLConfBPE = $SQLConfBPE -replace "IsBPEActive", $IsBPEActive
				$SQLConfBPE = $SQLConfBPE -replace "BPEValueToSet", $BPEValueToSet
				$SQLConfBPE | out-file ".\SQL_SERVER_BPE.sql"
				$QueryFile = "SQL_SERVER_BPE.sql";
				Invoke-SQLCmd -InputFile $QueryFile -Server $env:computername -Database master  -ErrorAction Stop
				write-host "SQL SERVER 2014 BPE configuration OK `r`n" -foreground green 
				}

		}

write-host "DBAtools install `r`n"
Set-Location $Chemin
Set-Location .\DbatoolsInstall
./dbatoolsInstall.ps1 -ErrorAction Stop
write-host "DBAtools install OK `r`n" -foreground green 

Write-Host "Master Stored Procedure Installation `r`n" 
Set-Location $Chemin
$MasterStoredProcedure = Get-ChildItem .\TSStoredProcedure\*.sql -file | Select-Object fullname,name
If ($MasterStoredProcedure -eq $null) {throw "No files for Master Stored Procedure Installation"}
$MasterStoredProcedure | ForEach-Object  -process {Write-Host $_.name
												Invoke-SQLCmd -InputFile $_.fullname -Server $CPUInstance -Database master  -ErrorAction Stop}
												
write-host "Master Stored Procedure install OK `r`n" -foreground green 

Set-Location $Chemin

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
#Restart-Computer -Force 




