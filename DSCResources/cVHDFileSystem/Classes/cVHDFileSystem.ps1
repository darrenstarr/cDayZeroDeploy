<#
This code is written and maintained by Darren R. Starr from Conscia Norway AS.

License :

Copyright (c) 2017 Conscia Norway AS

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software 
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

<# 
    .SYNOPSIS
        A resource for copying files into the contents of a VHD file
#>
[DscResource()]
class cVHDFileSystem 
{
    [DscProperty(Key)]
    [string] $VHDPath

    [DSCProperty()]
    [bool] $OkIfMounted = $true

    [DSCProperty()]
    [UInt64] $OkIfOverBytes = 4MB

    [DSCProperty(Mandatory)]
    [string[]] $ItemList

    [DSCProperty()]
    [string] $InitialMOF

    [DSCProperty()]
    [string] $MOFPath

    <#
        .SYNOPSIS
            Resource Get
    #>
    [cVHDFileSystem] Get()
    {
        [cVHDFileSystem]$result = [cVHDFileSystem]::new()

        $result.VHDPath = $this.VHDPath

        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (-not (Test-Path -Path $this.VHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.VHDPath + '] not present')
            return $false
        }

        if($this.OkIfOverBytes -gt 0) {
            Write-Verbose -Message ('OkIfOverBytes is ' + $this.OkIfOverBytes + ' bytes. Testing file size')
            $fileItem = Get-Item -Path $this.VHDPath

            if($null -eq $fileItem) {
                throw [System.Exception]::new(
                    'Failed to call Get-Item on ' + $this.VHDPath
                )
            }

            Write-Verbose ('File size is ' + $fileItem.Length.ToString() + ' bytes')
            if($fileItem.Length -gt $this.OkIfOverBytes) {
                Write-Verbose -Message 'Test condition met'
                return $true
            }

            return $false
        }

        Write-Verbose -Message ('Getting mounted information about VHD')
        try {
            $MountedDiskImage = Get-WmiObject -Namespace 'root\virtualization\v2' -query "SELECT * FROM MSVM_MountedStorageImage WHERE Name ='$($this.VHDPath.Replace("\", "\\"))'"

            if($null -ne $MountedDiskImage) {
                If($this.OkIfMounted) {
                    Write-Verbose -Message ('[' + $this.VHDPath + '], VHD is already mounted and OkIfMounted is $true, test is ok')
                    return $true
                }

                throw [System.Exception]::new(
                    '[' + $this.VHDPath + '], VHD is already mounted and cannot be altered in its current state'
                )
            }
        } catch {
            if($_.Exception.Message.StartsWith('[')) {
                throw $_.Exception
            }

            throw [System.Exception]::new(
                'Failed to get information from virtualization root regarding mounted images',
                $_.Exception
            )
        }

        # TODO : Add code to test contents of VHD against file list

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (-not (Test-Path -Path $this.VHDPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'VHD File not present',
                $this.VHDPath
            )
        }

        Write-Verbose -Message ('Checking initial validity of item list')
        if($null -eq $this.ItemList) {
            throw [System.ArgumentNullException]::new(
                'No item list was passed',
                'ItemList'
            )
        }

        if((($this.ItemList.Count % 2) -eq 1) -or ($this.ItemList.Count -eq 0)) {
            throw [System.ArgumentException]::new(
                'ItemList must be formatted as a list of strings of source path and destination path.',
                'ItemList'
            )
        }

        if((-not [string]::IsNullOrEmpty($this.InitialMOF))) {
            if (-not (Test-Path -Path $this.InitialMOF)) {
                throw [System.IO.FileNotFoundException]::new(
                    'Initial MOF file is specified but can''t be found [' + $this.InitialMOF + ']',
                    'InitialMOF'
                )
            }

            if ([string]::IsNullOrEmpty($this.MOFPath)) {
                throw [System.ArgumentException]::new(
                    'Initial MOF file is specified, but there is no destination to copy it to specified',
                    'InitialMOF'
                )
            }

            Write-Verbose -Message ('InitialMOF = [' + $this.InitialMOF + '], MOFPath = [' + $this.MOFPath + ']')
        }

        Write-Verbose -Message ('ItemList meets preliminary checks')

        $this.MountVHDImage()

        try {
            $this.CopyItems()
            $this.CopyInitialMOFAndDependencies()
        } catch {
            Write-Verbose -Message $_.Exception.Message
            throw [System.Exception]::new(
                'File copy operation failed',
                $_.Exception                
            )
        } finally {
            $this.DismountVHDImage()
        }
    }

    hidden static [string]$GptTypeUEFISystem = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    hidden static [string]$GptTypeMicrosoftReserved = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    hidden static [string]$GptTypeMicrosoftBasic = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    hidden [string] $WindowsPartitionRoot

    [void] CopyInitialMOFAndDependencies()
    {
        if([string]::IsNullOrEmpty($this.InitialMOF)) {
            Write-Verbose -Message 'No initial MOF specified'
            return
        }

        $fullMofPath = Join-Path -Path $this.WindowsPartitionRoot -ChildPath $this.MOFPath

        Write-Verbose -Message ('Checking for presence of MOF destination path [' + $fullMofPath + ']')
        if(-not (Test-Path -Path $fullMofPath)) {
            Write-Verbose -Message ('Creating [' + $fullMofPath + ']')
            New-Item -Path $fullMofPath -ItemType Directory
        }

        $fi = [System.IO.FileInfo]::new($this.InitialMOF)
        $initialMofDestination = Join-Path -Path $fullMofPath -ChildPath $fi.Name

        Write-Verbose -Message ('Copying [' + $this.InitialMOF + '] to [' + $initialMofDestination + ']')
        Copy-Item -Path $this.InitialMOF -Destination $initialMofDestination -Force

        Write-Verbose -Message ('Copying MOF DSC Resource Dependencies')
        [cOfflineMOFDependencyInstaller]::CopyMOFDependencies($this.InitialMOF, $this.WindowsPartitionRoot)
    }

    [void] CopyItems()
    {
        Write-Verbose -Message ('Refreshing PS Drive list')
        Get-PSDrive

        $itemCount = $this.ItemList.Count

        for($i = 0; $i -lt $itemCount; $i += 2) {
            $sourceItem = $this.ItemList[$i]
            $destinationItem = $this.ItemList[$i + 1]

            Write-Verbose -Message ('SourcePath = [' + $sourceItem + '], DestinationPath = [' + $destinationItem + ']')
            
            Write-Verbose -Message ('Verifying presence of source file [' + $sourceItem + ']')
            if(-not (Test-Path -Path $sourceItem)) {
                throw [System.IO.FileNotFoundException]::new(
                    'Source item not found',
                    $sourceItem
                )
            }

            $destinationPath = Join-Path -Path $this.WindowsPartitionRoot -ChildPath $destinationItem
            Write-Verbose -Message ('Checking for presence of destination file [' + $destinationPath + ']')
            if(Test-Path -Path $destinationItem) {
                throw [System.Exception]::new(
                    'Overwriting existing files is not currently supported [' + $destinationItem + ']'
                )
            }

            Write-Verbose -Message ('Constructing parent path name for [' + $destinationPath + ']')
            $destinationFileInfo = [System.IO.FileInfo]::new($destinationPath)
            $destinationParent = $destinationFileInfo.Directory.FullName

            Write-Verbose -Message ('Checking for parent directory of destination file [' + $destinationParent + ']')
            if (-not (Test-Path -Path $destinationParent)) {
                throw [System.IO.DirectoryNotFoundException]::new(
                    'Parent directory of destination item does not exist and force creation is not supported yet',
                    $destinationParent
                )
            }

            Write-Verbose -Message 'Parent directory exists, preparing to copy'

            $sourceFileItem = Get-Item -Path $sourceItem
            if ($sourceFileItem.GetType().Name -eq 'DirectoryInfo') {
                Write-Verbose -Message 'Source item is a directory'
                Copy-Item -Path $sourceItem -Destination $destinationPath -Recurse -Confirm:$false -Force
            } elseif ($sourceFileItem.GetType().Name -eq 'FileInfo') {
                Write-Verbose -Message 'Source item is a normal file'
                Copy-Item -Path $sourceItem -Destination $destinationPath -Confirm:$false -Force
            } else {
                Write-Verbose -Message 'WTF'
                throw [System.Exception]::new(
                    '[' + $sourceItem + '] is an unsupported type [' + $sourceFileItem.GetType() + ']'
                )
            }
        }
    }

    [void] MountVHDImage()
    {
        $vhd = $null
        try {
            Write-Verbose -Message ('Getting handle to the VHD file')
            $vhd = Get-Vhd -Path $this.VHDPath 
            if($null -eq $vhd) {
                throw [System.Exception]::new(
                    'Unknown error getting handle to the vhd'
                )
            }
        } catch {
            if($_.Exception.Message.BeginsWith('Unknown')) {
                throw $_.Exception
            }

            throw [System.Exception]::new(
                'Error obtaining VHD handle to ' + $this.VHDPath,
                $_.Exception
            )
        }

        $mountResult = $null
        try {
            Write-Verbose -Message ('Obtained VHD Handle, mounting VHD image')
            $mountResult = $vhd | Mount-VHD -Passthru
            if ($null -eq $mountResult) {
                throw [System.Exception]::new(
                    'Unknown error mounting VHD [' + $this.VHDPath + ']'
                )
            }
        } catch {
            if($_.Exception.Message.BeginsWith('Unknown')) {
                throw $_.Exception
            }

            throw [System.Exception]::new(
                'Error mounting VHD ' + $this.VHDPath,
                $_.Exception
            )            
        }

        try {
            Write-Verbose -Message 'Mounted VHD, getting windows disk handle'

            $disk = $mountResult | Get-Disk
            if ($null -eq $disk) {
                throw [System.Exception]::new(
                    'Failed to get disk handle'
                )
            }

            Write-Verbose -Message 'Obtained windows disk handle, getting partition table'

            $partitions = $disk | Get-Partition
            if ($null -eq $partitions) {
                throw [System.Exception]::new(
                    'Failed to get partition table'
                )
            }

            # TODO : Consider calling BCDBOOT to read the boot information for the drive.
            # TODO : Consider simply getting an NTFS partition with a drive letter assigned

            $windowsPartition = $null
            try {
                Write-Verbose -Message 'Obtained partition table, searching for first non-system and non-UEFI partition which has an assigned drive letter'
                $windowsPartition = $partitions | Where-Object { 
                    ($_.GptType -ne [cVhdFileSystem]::GptTypeUEFISystem) -and 
                    ($_.GptType -ne [cVhdFileSystem]::GptTypeMicrosoftReserved) -and 
                    ([char]::IsLetter($_.DriveLetter[0])) 
                }
            } catch {
                throw [System.Exception]::new(
                    'Failed to get a partition meeting the criteria of a Windows boot drive',
                    $_.Exception
                )
            }

            if ($null -eq $windowsPartition) {
                #TODO : Generate error if there is more than one item returned.
                throw [System.Exception]::new(
                    'Failed to find a non-UEFI or Reserved partition'
                )
            }

            Write-Verbose -Message ('Windows partition found, resolving drive letter')
            $this.WindowsPartitionRoot = $windowsPartition.DriveLetter + ':\'
            Write-Verbose -Message ('Windows drive root is ' + $this.WindowsPartitionRoot)

            try {
                Write-Verbose -Message ('Making drive root accessible to other commandlets')
                $psDrive = New-PSDrive -Name $windowsPartition.DriveLetter -PSProvider FileSystem -Root $this.WindowsPartitionRoot 
                if ($null -eq $psDrive) {
                    throw [System.Exception]::new(
                        'Unknown error when trying to make drive accessible to other commandlets'
                    )
                }
            } catch {
                if ($_.Exception.Message.BeginsWith('Unknown')) {
                    throw $_.Exception
                }

                throw [System.Exception]::new(
                    'Failed to make drive accessible to other commandlets',
                    $_.Exception
                )
            }

            Write-Verbose -Message ('Drive root now accessible to other commandlets')
        } catch {
            Write-Error -Message ('Failed to complete mounting system drive of [' + $this.VHDPath + '] dismounting image')

            try {
                $vhd | Dismount-VHD 
            } catch {
                Write-Error -Message ('Failed to unmount VHD')
            }

            $this.WindowsPartitionRoot = $null

            throw [System.Exception]::new(
                'Failed to complete mounting and making [' + $this.VHDPath + '] accessible to other commandslet',
                $_.Exception
            )
        } 
    }

    [void] DismountVHDImage()
    {
        $vhd = $null
        try {
            Write-Verbose -Message ('Getting handle to the VHD file')
            $vhd = Get-Vhd -Path $this.VHDPath 
            if($null -eq $vhd) {
                throw [System.Exception]::new(
                    'Unknown error getting handle to the vhd'
                )
            }
        } catch {
            if($_.Exception.Message.BeginsWith('Unknown')) {
                throw $_.Exception
            }

            throw [System.Exception]::new(
                'Error obtaining VHD handle to ' + $this.VHDPath,
                $_.Exception
            )
        }

        try {
            Write-Verbose -Message 'Dismounting VHD'
            $vhd | Dismount-VHD
        } catch {
            throw [System.Exception]::new(
                'Failed to dismount [' + $this.VHDPath + ']',
                $_.Exception
            )
        }
    }
}
