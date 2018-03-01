try {

$Chemin=[Environment]::CurrentDirectory

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
			Set-ItemProperty -Path "$Reg" -Name PATH –Value $NewPath
				   } #End of Process
			} 
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('LocalMachine',$env:computername)
$regKey= $reg.OpenSubKey("System\\CurrentControlSet\\Control\\Session Manager\\Environment\\" )
$PdfFilterPath = $regkey.GetValue("Path")
if ($PdfFilterPath -notlike "*C:\Program Files\Adobe\Adobe PDF iFilter 11 for 64-bit platforms\bin\*") {Add-Path  -ErrorAction Stop}	
if ($PDFFilterCheck.contains("End of search: 0 match(es) found.") -eq $True) {write-host "Setting PDFFilter FAILED `r`n" -foreground red 
								break}

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
if ($SQLVersion -ne 12050000) {write-host "SQL SERVER 2014 SP2 INSTALL FAILED `r`n" -foreground red 
						break}

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
if ($SQLVersion -ne 12055560) {write-host "SQL SERVER 2014 SP2 CU7 INSTALL FAILED `r`n" -foreground red 
break}

write-host "SQL SERVER 2014 SP2 CU7 INSTALL OK `r`n" -foreground green 


write-host "Post Conf SQL SERVER `r`n"

Start-Sleep -s 10

Set-Location $Chemin
$SQLConffile = Get-Content SQL_SERVER_ConfigurationTemplate.sql
$SQLConffile = $SQLConffile -replace "DataTempdb", $DataTempdbPath
$SQLConffile = $SQLConffile -replace "DatacenterId", $DatacenterId
$SQLConffile | out-file ".\SQL_SERVER_Configuration.sql"

$QueryFile = "SQL_SERVER_Configuration.sql";
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
