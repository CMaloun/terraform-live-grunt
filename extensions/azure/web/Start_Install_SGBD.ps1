TRY {
    Set-Location -Path 'C:\Installation SQL SERVER 2014 V1.1\Sources'
    New-Item 'C:\Installation SQL SERVER 2014 V1.1\Sources\install_done.txt' -ItemType file
    $ScriptToRun = "C:\Installation SQL SERVER 2014 V1.1\Sources\Install_SGBD_Node_2.ps1"
    &$ScriptToRun -DatacenterId 2 -DomainNameInput "contoso.com" -LoginNameInput "SQLSERVERUSER" -LoginPassword "AweS0me@PW" -SaPassword "If1mdpSQL!" -InstallFailoverCluster "Y"
}
catch {
    Write-Host $_.Exception.Message
}
$ScriptToRunAfter = "C:\Installation SQL SERVER 2014 V1.1\Sources\ChangeUser.ps1"
$computerName = get-childitem -path env:computername
&$ScriptToRunAfter -UserName .\LocalSystem -Password 'nothing' -Service 'puppet' -ServerN $computerName.Value -SecondsToWait 10