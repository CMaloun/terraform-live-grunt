[CmdletBinding()]
 Param(
   [Parameter(Mandatory=$True)]
    [string]$JsonFile
   
 )

Import-Module WebAdministration
Function CreateAppPool {
    Param([string] $appPoolName)
 
    if(Test-Path ("IIS:\AppPools\" + $appPoolName)) {
        Write-Host "The App Pool $appPoolName already exists" -ForegroundColor Yellow
        return
    }
    $appPool = New-WebAppPool -Name $appPoolName
}

Function CreatePhysicalPath {
     Param([string] $fpath)
     
     if(Test-path $fpath) {
         Write-Host "The folder $fpath already exists" -ForegroundColor Yellow
         return
         }
     else{
         New-Item -ItemType directory -Path $fpath -Force
        }
 }


#Change defaut website binding to port 81 
New-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 81 -HostHeader ""
Remove-WebBinding -Name "Default Web Site" -IPAddress "*" -Port 80 -HostHeader ""

$sites =  ConvertFrom-Json -InputObject (Get-Content $JsonFile -Raw)

foreach ($site in $sites.sites) {

    Write-Host $site.iisAppName $site.directoryPath
    CreatePhysicalPath $site.directoryPath

    $appPoolName = $site.iisAppName
    CreateAppPool $appPoolName
    
     If(!(Test-Path "IIS:\Sites\$($site.iisAppName)")) {
          New-Website -Name $site.iisAppName -PhysicalPath $site.directoryPath  -ApplicationPool $site.iisAppName
          
          }
      else {
          Write-Host "The IIS site $($site.iisAppName) already exists" -ForegroundColor Yellow
      }


     foreach ($bindings in $site.bindings) {
        Write-Host $bindings.protocol $bindings.port $bindings.IPAddress $bindings.url
        New-WebBinding -Name $site.iisAppName -IPAddress $bindings.IPAddress -Port $bindings.port -HostHeader $bindings.url
     }
}
