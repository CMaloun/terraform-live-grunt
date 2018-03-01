Set-Location -Path 'C:\Installation SQL SERVER 2014 V1.1\Sources'
$ScriptToRun= ".\Post_Install_SGBD_Node.ps1"
$username = 'contoso\testuser'
$password = 'AweS0me@PW'
$securePassword = ConvertTo-SecureString $password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential $username, $securePassword
Start-Process powershell -NoNewWindow -Credential $credential $ScriptToRun -Wait
