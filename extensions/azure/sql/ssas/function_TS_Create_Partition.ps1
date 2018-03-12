
Function TS_Create_Partition
{

    [cmdletbinding()]
    Param (
        $DataDL,
        $DataAUS,
        $DataLabel#,
        # $LogDL,
        # $LogAUS,
        # $LogLabel
       )

    if ($DataAUS -Contains "") 
        {
        #Test Partitions
        # $PartTest = $DataTempdb+":"	
        # $TestDPartition = Test-Path $PartTest
        # if ($TestDPartition -eq $False) 
        #     {$m
        #     Throw "Partition "+$PartTest+" not found `r`n"}

        $PartTest = $DataDL+":"
        $TestDPartition = Test-Path $PartTest
        if ($TestDPartition -eq $False) 
            {Throw "Partition "+$PartTest+" not found `r`n"}

        # $PartTest = $LogDL+":"	
        # $TestDPartition = Test-Path $PartTest
        # if ($TestDPartition -eq $False) 
        #     {Throw "Partition "+$PartTest+" not found `r`n"}    
        }

    else {
        #Install Premium disk for AZURE VM

        $PartTest = "D:"	
        $TestDPartition = Test-Path $PartTest
        if ($TestDPartition -eq $False) 
            {Throw "Partition "+$PartTest+" not found `r`n"}

        Stop-Service -Name ShellHWDetection

        $DD = Get-Disk | Where-Object FriendlyName -eq "Microsoft Virtual Disk" | Select-Object Number
        
        $PartTest = $DataDL+":"
        $TestDPartition = Test-Path $PartTest
        if ($TestDPartition -eq $False) 
            {if ($DD.number -eq 2)
            {$DL=$DataDL
            $AUS=$DataAUS
            $DrvNumber=2
            $Label=$DataLabel
            $DiskState = Get-Disk  -Number $DrvNumber
            if ($DiskState.OperationalStatus -eq "Online" -and $DiskState.PartitionStyle -eq "RAW"){
            Initialize-Disk -Number $DrvNumber -PartitionStyle GPT}
            New-Partition -DiskNumber $DrvNumber -UseMaximumSize -DriveLetter $DL  -ErrorAction Stop
            Format-Volume -DriveLetter $DL -FileSystem NTFS -AllocationUnitSize $AUS -Confirm:$false -force -NewFileSystemLabel $Label}
            else {Throw "Partition "+$PartTest+" not exists"}}

        # $PartTest = $LogDL+":"	
        # $TestDPartition = Test-Path $PartTest
        # if ($TestDPartition -eq $False) 
        #     {if ($dd.number -eq 3)
        #     {$DL=$LogDL
        #     $AUS=$LogAUS
        #     $DrvNumber=3
        #     $Label=$LogLabel
        #     $DiskState = Get-Disk  -Number $DrvNumber
        #     if ($DiskState.OperationalStatus -eq "Online" -and $DiskState.PartitionStyle -eq "RAW"){
        #     Initialize-Disk -Number $DrvNumber -PartitionStyle GPT}
        #     New-Partition -DiskNumber $DrvNumber -UseMaximumSize -DriveLetter $DL  -ErrorAction Stop
        #     Format-Volume -DriveLetter $DL -FileSystem NTFS -AllocationUnitSize $AUS -Confirm:$false  -force -NewFileSystemLabel $Label}
        #     else {Throw "Partition "+$PartTest+" not exists"}}

        Start-Service -Name ShellHWDetection

        }
}