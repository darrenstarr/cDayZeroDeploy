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
        A resource for creating a differencing VHD disk image relative to a parent image
#>
[DscResource()]
class cDifferencingVHD 
{
    [DscProperty(Key)]
    [string] $VHDPath

    [DSCProperty(Mandatory)]
    [string] $ParentVHDPath

    <#
        .SYNOPSIS
            Resource Get
    #>
    [cDifferencingVHD] Get()
    {
        $result = [cDifferencingVHD]::new()
        $result.ParentVHDPath = $this.ParentVHDPath
        $result.VHDPath = $this.VHDPath
        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.ParentVHDPath +'])')
        if (-not (Test-Path -Path $this.PArentVHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.ParentVHDPath + '] not present')
            return $false
        }

        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (-not (Test-Path -Path $this.VHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.VHDPath + '] not present')
            return $false
        }

        Write-Verbose -Message ('Attempt to get handle to the VHD file')
        $vhd = $null
        try {
            $vhd = Get-VHD -Path $this.VHDPath
            
            if($null -eq $vhd) {
                # TODO: throw here?
                Write-Error -Message ('Unknown error getting handle to [' + $this.VHDPath + ']')
                return $false
            }
        } catch {
            # TDOD : throw here?
            Write-Error -Message ('Failed to get handle to VHD file [' + $this.VHDPath + ']')
            return $false
        }

        Write-Verbose -Message ('Handle obtained')

        if($null -eq $vhd.ParentPath) {
            throw [Exception]::new(
                'Existing VHD [' + $this.VHDPath + '] is not a differencing image'
            )
        }

        Write-Verbose -Message ('Parent path of VHD (as seen within the VHD) is [' + $vhd.ParentPath + ']')

        $resolvedParentVhdPath = Resolve-Path -Path $this.ParentVHDPath -Relative:$false
        if(-not ($resolvedParentVhdPath -like $vhd.ParentPath)) {
            throw [Exception]::new(
                'Path specified as option [' + $this.ParentVHDPath + '] is not equal to the path within the VHD [' + $resolvedParentVhdPath + ']'
            )
        }

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.ParentVHDPath +'])')
        if (-not (Test-Path -Path $this.PArentVHDPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'Parent VHD file not found',
                $this.ParentVHDPath ,
                [System.ArgumentException]::new(
                    'VHD file specified not present',
                    'ParentVHDPath'
                )
            )
        }

        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (Test-Path -Path $this.VHDPath) {
            throw [System.ArgumentException]::new(
                'VHD File [' + $this.VHDPath + '] already exists and should not be overwritten',
                'VHDPath'
            )
        }

        $parentVHD = $null
        Write-Verbose -Message ('Getting handle to parent VHD')
        try {
            $parentVHD = Get-VHD -Path $this.ParentVHDPath
        } catch {
            throw [Exception]::new(
                'Failed to get handle to parent VHD [' + $this.ParentVHDPath + ']',
                $_.Exception
            )
        }

        Write-Verbose -Message ('Getting mounted position of parent VHD')
        try {
            $MountedDiskImage = Get-WmiObject -Namespace 'root\virtualization\v2' -query "SELECT * FROM MSVM_MountedStorageImage WHERE Name ='$($this.ParentVHDPath.Replace("\", "\\"))'"

            if($null -ne $MountedDiskImage) {
                throw [System.ArgumentException]::new(
                    '[' + $this.ParentVHDPath + '], ParentVHD is already mounted and can''t be used as a differencing disk',
                    'ParentVHDPath'
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

        $vhdFolderInfo = [System.IO.FileInfo]::new($this.VHDPath)
        if(($null -eq $vhdFolderInfo) -or ($null -eq $vhdFolderInfo.Directory)) {
            throw [System.ArgumentException]::new(
                '[' + $this.VHDPath + '] does not appear to contain a valid parent directory within its path'
            )
        }
        
        Write-Verbose -Message ('Testing for presence of folder of new VHD file [' + $vhdFolderInfo.Directory.FullName + ']')
        if(-not (Test-Path -Path $vhdFolderInfo.Directory.FullName)) {
            throw [System.IO.DirectoryNotFoundException]::new(
                'Containing directory for new VHD file does not exist',
                $vhdFolderInfo.Directory.FullName
            )
        }

        Write-Verbose -Message ('Attempting to create new differencing VHD file [' + $this.VHDPath + '] using [' + $this.ParentVHDPath + '] as its parent')
        $vhd = $null
        try {
            $vhd = New-VHD -Path $this.VHDPath -ParentPath $this.ParentVHDPath -Differencing 

            if ($null -eq $vhd) {
                throw [Exception]::new(
                    'Unknown error calling New-VHD, aborting'
                )
            }
        } catch {
            throw [Exception]::new(
                'Failed to create differencing VHD file with source  VHD file [' + $this.VHDPath + '] using [' + $this.ParentVHDPath + '] as its parent',
                $_.Exception
            )
        }

        Write-Verbose -Message ('New VHD file [' + $this.VHDPath + '] created')
    }
}
