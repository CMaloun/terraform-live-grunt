$MsiUrl = "http://www.7-zip.org/a/7z920-x64.msi"

$install_args = @("/qn", "/norestart","/i", $MsiUrl)
Write-Host "Installing 7zip"
$process = Start-Process -FilePath msiexec.exe -ArgumentList $install_args -Wait -PassThru
if ($process.ExitCode -ne 0) {
  Write-Host "Installer failed."
  Exit 1
}
