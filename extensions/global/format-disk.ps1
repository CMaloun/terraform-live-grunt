[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$DriveLetter,

  [Parameter(Mandatory=$True)]
  [integer]$DiskNumber,

  [Parameter(Mandatory=$True)]
  [string]$DriveLabel

)

Initialize-Disk -Number $DiskNumber -PartitionStyle GPT
New-Partition -UseMaximumSize -DriveLetter $DriveLetter -DiskNumber $DiskNumber
Format-Volume -DriveLetter $DriveLetter -FileSystemLabel $DriveLabel -Confirm:$false -FileSystem NTFS -force 
