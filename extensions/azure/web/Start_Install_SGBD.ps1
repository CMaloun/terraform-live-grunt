Set-Location -Path 'C:\Installation SQL SERVER 2014 V1.1\Sources'
$ScriptToRun = "C:\Installation SQL SERVER 2014 V1.1\Sources\Install_SGBD_Node_2.ps1"
&$ScriptToRun -DatacenterId 2 -DomainNameInput "contoso.com" -LoginNameInput "SQLSERVERUSER" -LoginPassword "AweS0me@PW" -SaPassword "If1mdpSQL!" -InstallFailoverCluster "Y"
