Set-Location -Path 'C:\Installation SQL SERVER 2014 V1.1\Sources'
$ScriptToRun= ".\Install_SGBD_Node.ps1 -DatacenterId 2 -DomainNameInput 'contoso.com' -LoginNameInput 'SQLSERVERUSER' -LoginPassword 'AweS0me@PW' -SaPassword 'If1mdpSQL!' -InstallFailoverCluster 'Y'"
#&$ScriptToRun -DatacenterId 2 -DomainNameInput "contoso.com" -LoginNameInput "SQLSERVERUSER" -LoginPassword "AweS0me@PW" -SaPassword "If1mdpSQL!" -InstallFailoverCluster "N"
$username = 'contoso\testuser'
$password = 'AweS0me@PW'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword
Start-Process powershell -NoNewWindow -Credential $credential $ScriptToRun -Wait
