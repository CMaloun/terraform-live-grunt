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
  [Parameter(Mandatory=$true)]
  [string]$SiteJsonFile,
  [string]$MsiUrl = "https://downloads.puppetlabs.com/windows/puppet-agent-x64-latest.msi",
  [string]$PuppetVersion = $null
)

#########################
# Disable Firewall
#########################

Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

#########################
# Install NodePad plus plus
#########################

#choco install -y notepadplusplus

#########################
#Format Disk
#########################

    $disks = Get-Disk | Where partitionstyle -eq 'raw' | sort number

    $letters = "D","L"
    $count = 0
    $labels = "Data","Log"

    foreach ($disk in $disks) {
        $driveLetter = $letters[$count].ToString()
        $disk | 
        Initialize-Disk -PartitionStyle MBR -PassThru |
        New-Partition -UseMaximumSize -DriveLetter $driveLetter |
        Format-Volume -FileSystem NTFS -NewFileSystemLabel $labels[$count] -Confirm:$false -Force
    $count++
    }

#######################################
# Provisioning IIS 
#######################################

$ScriptToRun= $PSScriptRoot+"\configureIIS.ps1"
&$ScriptToRun $PSScriptRoot"\"$($SiteJsonFile)

#######################################
# Install puppet agent 
#######################################

if ($PuppetVersion) {
  $MsiUrl = "https://downloads.puppetlabs.com/windows/puppet-$($PuppetVersion).msi"
  Write-Host "Puppet version $PuppetVersion specified, updated MsiUrl to `"$MsiUrl`""
}

$PuppetInstalled = $false
#try {
#  $ErrorActionPreference = "Stop";
#  Get-Command puppet | Out-Null
#  $PuppetInstalled = $true
#  $PuppetVersion=&puppet "--version"
#  Write-Host "Puppet $PuppetVersion is installed. This process does not ensure the exact version or at least version specified, but only that puppet is installed. Exiting..."
#  Exit 0
#} catch {
#  Write-Host "Puppet is not installed, continuing..."
#}

if (!($PuppetInstalled)) {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (! ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-Host -ForegroundColor Red "You must run this script as an administrator."
    Exit 1
  }

  # Install it - msiexec will download from the url
  $install_args = @("/qn", "/norestart","/i", $MsiUrl, "PUPPET_AGENT_CERTNAME=$PuppetAgentCertName PUPPET_AGENT_ENVIRONMENT=$PuppetEnvironment")
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

  Restart-Computer -force
  Exit 0
}
