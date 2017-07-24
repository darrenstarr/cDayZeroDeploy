<#
This code is written and maintained by Darren R. Starr from Conscia Norway AS.

License :

Copyright (c) 2017 Conscia Norway AS AS Norway

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
        Powershell DSC Resource to convert Windows Server 2016 ISO images to VHD files

    .DESCRIPTION
        While it would not be difficult to extend this class to support more than simply deploying 
        Windows Server 2016 as a virtual machine image for use with Hyper-V, it would take little
        effort to extend this resource to support all the features of Convert-WindowsImage.ps1 as
        found on the ISO itself.

        This intention of this resource is to create a base VHD image that can be used by differencing
        images for rapid deployment of data center resources using other resources within this series
        of resources.

    .NOTES
        There are some issue I'm less than happy with in this code.
            <li>This code is non-reentrant</li>
            While this is generally an issue, due to a limitation with Mount-DiskImage, when an ISO
            is mounted, it is not really possible to mount the same image twice and not lose track of
            its mount points.
            <li>New-PSDrive isn't cleaned up</li>
            The New-PSDrive mounted in this code does not have any cleanup code associated with it and 
            it should.
            <li>Error handling on image dismount in case of error</li>
            There is a case where Dismount-DiskImage is called during a catch and is not properly handled.
#>
[DscResource()]
class cWindowsVHD 
{
    [DscProperty(Key)]
    [string] $VHDPath

    [DSCProperty(Mandatory)]
    [string] $ISOPath

    [DSCProperty()]
    [string] $Edition = 'SERVERDATACENTERCORE'

    [DscProperty()]
    [UInt64] $MaximumSizeBytes = 100GB

    hidden [string] $ISORoot

    <#
        .SYNOPSIS
            Resource Get
    #>
    [cWindowsVHD] Get()
    {
        [cWindowsVHD]$result = [cWindowsVHD]::new()

        $vhd = Get-VHD -Path $this.VHDPath
        $result.MaximumSizeBytes = $vhd.Size

        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        If (-not (Test-Path -Path $this.ISOPath)) {
            throw [System.ArgumentException]::new(
                ('ISO file [' + $this.ISOPath + '] is not present'),
                '$ISOPath'
            )
        }

        If (-not (Test-Path -Path $this.VHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.VHDPath + '] not present')
            return $false
        }

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        Write-Verbose -Message ('Checking for a preexisting VHD [' + $this.VHDPath + '] file')
        If (Test-Path -Path $this.VHDPath) {
            throw [Exception]::(
                'VHD File [' + $this.VHDPath + '] is already present'
            )
        }

        Write-Verbose -Message ('VHD does not exist, mounting ISO')
        $this.MountISO()

        try {
            Write-Verbose -Message ('Start conversion of Windows image to VHD')
            $this.ConvertWindowsImage()
        } catch {
            throw [Exception] (
                'Windows image conversion failed', 
                $_.Exception
            )
        } finally {
            $this.DismountISO()
        }
    }

    hidden [void] MountISO()
    {
        Write-Verbose -Message ('Testing for the presence of the ISO image [' + $this.ISOPath + ']')

        If (-not (Test-Path -Path $this.ISOPath)) {
            throw [System.ArgumentException]::new(
                ('ISO file [' + $this.ISOPath + '] is not present'),
                '$ISOPath'
            )
        }

        $mountIsoResult = $null
        try {
            Write-Verbose -Message ('Attempting to mount the ISO image [' + $this.ISOPath + ']')
            $mountIsoResult = Mount-DiskImage -ImagePath $this.ISOPath -PassThru
        } catch {
            throw [Exception]::New(
                'Failed to mount Windows ISO [' + $this.ISOPath + ']',
                $_.Exception
                )
        }

        try {
            Write-Verbose -Message ('ISO mounted, getting mount information (compensate for possible powershell bug in Mount-DiskImage)')
            # TODO : Refresh variable... might be a bug... see Convert-WindowsImage.
            $mountIsoResult = Get-DiskImage -ImagePath $this.ISOPath

            Write-Verbose -Message ('Attempting to get drive letter of where the ISO was mounted')
            $driveLetter = ($mountIsoResult | Get-Volume).DriveLetter

            $this.ISORoot = "$($driveLetter):\"
            Write-Verbose -Message ('The drive where the ISO is mounted is -> ' + $this.ISORoot)

            Write-Verbose -Message ('Attempting to register ' + $this.ISORoot + ' so that it may be accessible to Powershell')
            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $this.ISORoot
        } Catch {
            Write-Verbose -Message ('Failed to complete making ISO accessible. Dismounting ISO')
            # TODO : Should I add an exception to the dismount operation?
            Dismount-DiskImage -ImagePath $this.ISOPath

            $this.ISORoot = $null

            throw [Exception]::new(
                'The Windows ISO Image [' + $this.ISOPath + '] mounted successfully but a drive letter could not be obtained',
                $_.Exception
            )
        }

        Write-Verbose -Message ('ISO mounted and accessible at [' + $this.ISORoot + ']')
    }

    hidden [void] DismountISO()
    {
        try {
            Write-Verbose -Message ('Getting mount information as to where ISO [' + $this.ISOPath + '] is mounted')
            # TODO : Refresh variable... might be a bug... see Convert-WindowsImage.
            $mountIsoResult = Get-DiskImage -ImagePath $this.ISOPath

            Write-Verbose -Message ('Attempting to get drive letter of where the ISO was mounted')
            $driveLetter = ($mountIsoResult | Get-Volume).DriveLetter

            $this.ISORoot = "$($driveLetter):\"
            Write-Verbose -Message ('The drive where the ISO is mounted is -> ' + $this.ISORoot)

#            Write-Verbose -Message ('Attempting to register ' + $this.ISORoot + ' so that it may be accessible to Powershell')
#            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $this.ISORoot

            # TODO : Delete PS drive?

            Write-Verbose -Message ('Attempting to dismount ISO image')
            Dismount-DiskImage -ImagePath $this.ISOPath

            $this.ISORoot = $null
        } Catch {
            throw [Exception]::new(
                'The Windows ISO Image [' + $this.ISOPath + '] failed to dismount',
                $_.Exception
            )
        }        
    }

    hidden [void] ConvertWindowsImage()
    {
        $convertWindowsImageScriptPath = [cWindowsVHD]::JoinPath($this.ISORoot, 'NanoServer\NanoServerImageGenerator\Convert-WindowsImage.ps1')
        $installWimPath =[cWindowsVHD]::JoinPath($this.ISORoot, 'sources\install.wim')
        $temporaryConversionPath = [cWindowsVHD]::JoinPath($env:TEMP, 'ConvertWindowsImage')

        Write-Verbose -Message ('Convert-WindowsImage.ps1 should be located at -> ' + $convertWindowsImageScriptPath)
        Write-Verbose -Message ('install.wim should be located at -> ' + $installWimPath)
        Write-Verbose -Message ('Path to give to Convert-WindowsImage a a temporary directory is -> ' + $temporaryConversionPath)

        # TODO : Get-PSDrive seems to refresh the drives here which has been a problem with Join-Path and Test-Path. Is there a better way?
        Get-PSDrive
        
        if(-not (Test-Path -Path $convertWindowsImageScriptPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'Is this not a Windows Server 2016 ISO?', 
                $convertWindowsImageScriptPath
            )
        }

        if(-not (Test-Path -Path $installWimPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'The Windows ISO may be invalid', 
                $installWimPath
            )
        }

        if(Test-Path -Path $temporaryConversionPath) {
            Write-Verbose -Message ('The path [' + $temporaryConversionPath + '] is already present, attempting to remove it first')
            try {
                Remove-Item -Path $temporaryConversionPath -Recurse -Force -Confirm:$false
            } catch {
                throw [System.IO.IOException]::new(
                    'Failed to delete [' + $temporaryConversionPath + ']. This directory should not be present before using this function', 
                    $_.Exception
                )
            }
        }

        # TODO : The following should not be necessary, but I'm not convinced that Remove-Item will throw an exception properly
        if(Test-Path -Path $temporaryConversionPath) {
            throw [Exception]::new(
                'Failed to delete [' + $temporaryConversionPath + ']. This directory should not be present before using this function'
            )
        }

        try {
            Write-Verbose -Message ('Creating temporary path [' + $temporaryConversionPath + '] to use for image conversion operations')
            New-Item -Path $temporaryConversionPath -Confirm:$false -ItemType Directory -Force
        } catch {
            throw [Exception]::new(
                'Failed to create path [' + $temporaryConversionPath + ']. Cannot continue', 
                $_.Exception
            )
        }

        . $convertWindowsImageScriptPath

        $Params = @{
                SourcePath = $installWimPath
                Edition = $this.Edition 
                VHDPath = $this.VHDPath
                TempDirectory = $temporaryConversionPath 
                SizeBytes = $this.MaximumSizeBytes 
                VHDFormat = 'VHDX'
                DiskLayout = 'UEFI'
            }

        # Write-Verbose -Message ('-SourcePath ''' + $installWimPath + ''' -Edition ''' + $this.Edition + ''' -VHDPath ''' + $this.VHDPath + ''' -TempDirectory ''' + $temporaryConversionPath + ''' -VHDFormat VHDX -DiskLayout UEFI' )

        Write-Verbose -Message ('Initiating ISO to VHD conversion')
        Convert-WindowsImage @Params -Passthru 

        Write-Verbose -Message ('Conversion complete, removing temporary directory')
        try {
            Remove-Item -Path $temporaryConversionPath -Recurse -Force -Confirm:$false
        } catch {
            throw [System.IO.IOException]::new(
                'Failed to delete [' + $temporaryConversionPath + ']. This directory should be removed before continuing', 
                $_.Exception
            )
        }
    }
    
    <#
        .SYNOPSIS
            Dirty nasty hack to get the same functionality of Join-Path without the actual file system dependencies
    #>
    hidden static [string]JoinPath([string]$path, [string]$childPath)
    {
        return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($path, $childPath))
    }
}
