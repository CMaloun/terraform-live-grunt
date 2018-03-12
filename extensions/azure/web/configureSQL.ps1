<#
.SYNOPSIS
    Installs Puppet on this machine.
.DESCRIPTION
    Downloads and installs the PuppetLabs Puppet MSI package.
    This script requires administrative privileges.
    You can run this script from an old-style cmd.exe prompt using the
    following:
      powershell.exe -ExecutionPolicy Unrestricted -NoLogo -NoProfile -Command "& '.\windows.ps1'"
.PARAMETER MsiUrl
    This is the URL to the Puppet MSI file you want to install. This defaults
    to a version from PuppetLabs.
.PARAMETER PuppetVersion
    This is the version of Puppet that you want to install. If you pass this it will override the version in the MsiUrl.
    This defaults to $null.
.PARAMETER PuppetEnvironment
.PARAMETER PuppetAgentCertName
.PARAMETER PuppetMasterIpAddress
.PARAMETER PuppetMasterHostName
.PARAMETER PuppetAgentRole
#>
param(
  [Parameter(Mandatory=$true)]
  [string]$PuppetEnvironment,
  [Parameter(Mandatory=$true)]
  [string]$PuppetAgentCertName,
  [Parameter(Mandatory=$true)]
  [string]$PuppetMasterIpAddress,
  [Parameter(Mandatory=$true)]
  [string]$PuppetMasterHostName,
  [Parameter(Mandatory=$true)]
  [string]$PuppetAgentRole,
  [string]$MsiUrl = "https://downloads.puppetlabs.com/windows/puppet-agent-x64-latest.msi",
  [string]$PuppetVersion = $null
)

#########################
# Disable Firewall
#########################

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

#########################
#Format Disk
#########################

    $disks = Get-Disk | Where partitionstyle -eq 'raw' | sort number

    $letters = "F","G"
    $count = 0
    $labels = "Data","Logs"

    foreach ($disk in $disks) {
        $driveLetter = $letters[$count].ToString()
        $disk | 
        Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $labels[$count] -Confirm:$false -Force
    $count++
    }


#######################################
# Copy required file for SQL
#######################################
Copy-Item "Install_SGBD_Node.ps1" -Destination "C:\Installation SQL SERVER 2014 V1.1\Sources"
Copy-Item "Install_SGBD_Node_1.ps1" -Destination "C:\Installation SQL SERVER 2014 V1.1\Sources"
Copy-Item "Install_SGBD_Node_2.ps1" -Destination "C:\Installation SQL SERVER 2014 V1.1\Sources"
Copy-Item "Start_Install_SGBD.ps1" -Destination "C:\Installation SQL SERVER 2014 V1.1\Sources"
Copy-Item "ChangeUser.ps1" -Destination "C:\Installation SQL SERVER 2014 V1.1\Sources"

#######################################
# Install puppet agent 
#######################################

if ($PuppetVersion) {
  $MsiUrl = "https://downloads.puppetlabs.com/windows/puppet-$($PuppetVersion).msi"
  Write-Host "Puppet version $PuppetVersion specified, updated MsiUrl to `"$MsiUrl`""
}

$PuppetInstalled = $false
try {
    $ErrorActionPreference = "Stop";
    Get-Command puppet | Out-Null
    $PuppetInstalled = $true
    $PuppetVersion=&puppet "--version"
    Write-Host "Puppet $PuppetVersion is installed. This process does not ensure the exact version or at least version specified, but only that puppet is installed. Exiting..."
} catch {
    Write-Host "Puppet is not installed, continuing..."
}

if (!($PuppetInstalled)) {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (! ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Host -ForegroundColor Red "You must run this script as an administrator."
    Exit 1
  }

  # Install it - msiexec will download from the url
  If ($PuppetAgentCertName -Match "contoso"){
    $install_args = @("/qn", "/norestart","/i", $MsiUrl, "PUPPET_AGENT_CERTNAME=$PuppetAgentCertName PUPPET_AGENT_ENVIRONMENT=$PuppetEnvironment PUPPET_AGENT_ACCOUNT_DOMAIN=contoso.com PUPPET_AGENT_ACCOUNT_USER=testuser PUPPET_AGENT_ACCOUNT_PASSWORD=AweS0me@PW")
  }
  else {
    $install_args = @("/qn", "/norestart","/i", $MsiUrl, "PUPPET_AGENT_CERTNAME=$PuppetAgentCertName PUPPET_AGENT_ENVIRONMENT=$PuppetEnvironment")
  }
  Write-Host "Installing Puppet. Running msiexec.exe $install_args"
  $process = Start-Process -FilePath msiexec.exe -ArgumentList $install_args -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    Write-Host "Installer failed."
    Exit 1
  }

  # Stop the service that it autostarts
  #Write-Host "Stopping Puppet service that is running by default..."
  #Start-Sleep -s 5
  #Stop-Service -Name puppet

  Write-Host "Puppet successfully installed."

  Write-Host "update host file"
  ac -Encoding UTF8  "$($env:windir)\system32\Drivers\etc\hosts" "$PuppetMasterIpAddress puppet puppetmaster $PuppetMasterHostName"
  Write-Host "Host file updated"

  Write-Host "set environment variable"
  [Environment]::SetEnvironmentVariable("FACTER_role", $PuppetAgentRole, "Machine")
  Write-Host "Environment variable updated"
  
}

#######################################
# Install SQL SERVER
#######################################

Set-Location -Path 'C:\Installation SQL SERVER 2014 V1.1\Sources'
$ScriptToRun= "C:\Installation SQL SERVER 2014 V1.1\Sources\Install_SGBD_Node_1.ps1"
&$ScriptToRun -DatacenterId 2 -DomainNameInput "contoso.com" -LoginNameInput "SQLSERVERUSER" -LoginPassword "AweS0me@PW" -SaPassword "If1mdpSQL!" -InstallFailoverCluster "N"
 
Restart-Computer -Force
#Exit 0
