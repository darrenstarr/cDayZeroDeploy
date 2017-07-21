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

# TODO: Horrible hack to make sure that Get-DSCResource and all related types are available
Get-Command -Name 'Get-DSCResource' | Out-Null

<#
    .SYNOPSIS
        A class to identify and catalog information about a DSC resource locally available and where to copy it within a VHD 
        for offline installation.

    .DESCRIPTION
        cDSCResourceInformation, when provided with a DSC Resource module name identifies :
            <li>all the files that incorporate the</li>
            <li>whether the resource is a system resource (installed under system32)</li>
            <li>recommends where to copy the files (individually) relative to the root of a Windows VHD</li>

    .NOTES
        There are some oddities as to the implementation of this class. There are certain leaps of faith with regards
        to where the files are found (classifying them) and as to where to copy them (hard coded destination paths).
        Ideally, location roots would be identified via the system registry of the guest and host machines.

        This class has some groundwork implemented to identify whether the given DSC resource has any other module dependencies
        that should be able to be used to copy module dependencies as well. This has not been needed thus far, but may be needed later.
#>
class cDSCResourceInformation
{
    <#
        .SYNOPSIS
            The name of the DSC resource module
    #>
    [string]$ResourceName

    <#
        .SYNOPSIS
            The root directory of the version associated with the module
    #>
    [string]$VersionRootDirectory

    <#
        .SYNOPSIS
            The root directory of all versions of the module
    #>
    [string]$RootDirectory

    <#
        .SYNOPSIS
            The path of the PSD1 file within the module
    #>
    [string]$PSD1Path

    <#
        .SYNOPSIS
            Ther version number of the resource as reported by Get-DSCResource
    #>
    [string]$ResourceVersion

    <#
        .SYNOPSIS
            Is the module located in the System32 directory?
    #>
    [bool]$SystemModule

    <#
        .SYNOPSIS
            A manifest of files and directories to be copied to the VHD file. Recommended destination paths are also included.
    #>
    [cDSCResourceManifestItem[]]$Manifest

    <#
        .SYNOPSIS
            The destination root path of modules to be located under System32
    #>
    hidden static [string]$SystemModulePath = '\Windows\System32\WindowsPowerShell\v1.0\Modules'

    <#
        .SYNOPSIS
            The destination root path of modules to be located under program files
    #>
    hidden static [string]$ProgramFilesModulePath = '\Program Files\WindowsPowerShell\Modules'

    <#
        .SYNOPSIS
            The local system path for where System32 rooted modules should be found
    #>
    hidden static [string]$HostSystemModulePath = [cDSCResourceInformation]::GetExactPathName((Join-Path -Path $Env:windir -ChildPath 'System32\WindowsPowershell\v1.0\Modules'))

    <#
        .SYNOPSIS
            The local system path for where Program Files rooted modules should be found
    #>
    hidden static [string]$HostProgramFileModulePath = [cDSCResourceInformation]::GetExactPathName((Join-Path -Path $Env:ProgramFiles -ChildPath 'WindowsPowershell\Modules'))

    <#
        .SYNOPSIS
            Constructor and worker

        .DESCRIPTION
            The constructor queries the system for all pertainant information regarding the provided module name. It then makes
            a list of all the files within the module and calculated recommended destination paths for each item.
    #>
    cDSCResourceInformation([string]$name)
    {
        $this.ResourceName = $name

        # Find information about the resource from the system
        Write-Verbose -Message ('Calling Get-DscResource for module ' + $name)
        $resource = Get-DscResource -Module $name -Verbose:$false | Where-Object { $_.ModuleName -eq $Name } | Select-Object -Unique
        if($null -eq $resource) {
            throw [System.Exception]::new(
                'Invalid module name passed'
            )
        }

        if([string]::IsNullOrEmpty($resource.Path)) {
            throw [System.Exception]::new(
                'Cannot identify the path of where to find DSC resource [' + $name + ']'
            )
        }

        # Gather directory information
        $this.ResourceVersion = $resource.Version
        Write-Verbose -Message ('Resource version = ' + $this.ResourceVersion)

        $this.PSD1Path = $this.FindDSCResourcePSD1($resource.Path)
        Write-Verbose -Message ('PSD1 file = ' + $this.PSD1Path)

        $this.VersionRootDirectory = $this.GetDSCResourceVersionRootDirectory($this.PSD1Path)
        Write-Verbose -Message ('Version root directory = ' + $this.VersionRootDirectory)
        
        $this.RootDirectory = $this.GetDSCResourceRoot($this.VersionRootDirectory, $this.ResourceVersion)
        Write-Verbose -Message ('Resource root directory = ' + $this.RootDirectory)

        # Identify whether this is a system module (under System32)
        $this.SystemModule = [cDSCResourceInformation]::IsWindowsSystemModule($this.RootDirectory)
        Write-Verbose -Message ('Is system resource? ' + $this.SystemModule.ToString())

        # Catalog all files in the resource and produce a manifest for the copy operation.
        $dscResourceItems = Get-ChildItem -Path $this.VersionRootDirectory -Recurse
        $this.Manifest = $dscResourceItems.foreach{ 
            $relativePath = [cDSCResourceInformation]::GetRelativePath($this.VersionRootDirectory, $_.FullName)

            [cDSCResourceManifestItem] @{
                Item = $_
                RelativePath = $relativePath
                RecommendedDestinationPath = $this.GetRecommendedDestinationPath($relativePath)
            }
        }
    }

    <#
        .SYNOPSIS
            Overload of ToString() to make debugging easier
    #>
    [string]ToString()
    {
        return $this.ResourceName + ', ' + $this.ResourceVersion + ', ' + $this.RootDirectory + ', System?=' + $this.SystemModule.ToString()
    }

    <#
        .SYNOPSIS
            Checks to see whether the given path is rooted beneath %WINDIR%\System32
    #>
    hidden static [bool] IsWindowsSystemModule([string]$path)
    {
        return $path.StartsWith([cDSCResourceInformation]::HostSystemModulePath)
    }

    <#
        .SYNOPSIS
            Provides a recommendation for where to copy a file within a VHD file

        .DESCRIPTION
            For system modules, \Windows\System32\WindowsPowerShell\v1.0\Modules is used

            For non-system modules, \Program Files\WindowsPowerShell\Modules\{ResourceName}\{ResourceVersion} is used
    #>
    hidden [string] GetRecommendedDestinationPath([string]$RelativePath)
    {
        if($this.SystemModule) {
            return [System.IO.Path]::Combine([cDSCResourceInformation]::SystemModulePath)
        }

        return [System.IO.Path]::Combine(
            [System.IO.Path]::Combine([cDSCResourceInformation]::ProgramFilesModulePath, $this.ResourceName),
            $this.ResourceVersion
        )
    }

    <#
        .SYNOPSIS
            Returns the relative path from a base file path to a child file path.

        .NOTES
            This code may not be 100% Powershell Core friendly
    #>
    static hidden [string] GetRelativePath([string]$BasePath, [string]$ChildPath)
    {
        if(-not $BasePath.EndsWith('\')) {
            $BasePath += '\'
        }
            
        $basePathURI = [System.Uri]::new($BasePath)
        $childPathURI = [System.Uri]::new($ChildPath)

        $relativeUri = $basePathURI.MakeRelativeUri($childPathURI)

        return $relativeUri.ToString().Replace('/', '\')
    }

    <#
        .SYNOPSIS
            Given a full path name, resolves with correct case sensetivity of the path as is seen on the filesystem itself

        .NOTES
            This code was necessary because [System.IO.FileSystemInfo]::FullName does not resolve and correct paths
    #>
    static hidden [string] GetExactPathName([string]$PathName) 
    {
        if (-not (Test-Path -Path $PathName)) {
            return $PathName
        }

        $di = [System.IO.DirectoryInfo]::new($PathName)
        if ($null -ne $di.Parent) {
            return [System.IO.Path]::Combine(
                [cDSCResourceInformation]::GetExactPathName($di.Parent.FullName),
                $di.Parent.GetFileSystemInfos($di.Name)[0].Name
            )
        } else {
            return $di.Name.ToUpper()
        }
    }

    <#
        .SYNOPSIS
            From a given file or directory path, traverses the file path and locates a .PSD1 file to correlate to the module
    #>
    hidden [string] FindDSCResourcePSD1([string]$ResourcePath)
    {
        if(-not (Test-Path -Path $ResourcePath)) {
            throw [System.IO.FileNotFoundException](
                'Failed to find file',
                $ResourcePath
            )
        }

        Write-Verbose -Message ('Getting file system info for ' + $ResourcePath)
        $fi = [System.IO.FileInfo]::new($ResourcePath)
        if($fi.Extension.ToLower() -eq '.psd1') {
            return $ResourcePath
        }

        $resultPath = $fi.Directory.FullName
        while(-not [String]::IsNullOrEmpty($resultPath)) {
            $fi = [System.IO.FileInfo]::new($resultPath)

            Write-Verbose -Message ('Getting PSD1 files for ' + $fi.Directory.FullName)
            $psd1Files = $fi.Directory.GetFiles($this.ResourceName + '.psd1')
            if($null -ne $psd1Files) {
                if($psd1Files.Count -eq 1) {
                    return [cDSCResourceInformation]::GetExactPathName($psd1Files[0].FullName)
                }
            }

            $resultPath = $fi.Directory.FullName
        }

        if([String]::IsNullOrEmpty($resultPath)) {
            throw [System.Exception]::new(
                'Unhandled case, module ' + $this.ResourceName + ' is lacking a PSD1 file with the name [' + $this.ResourceName + '.psd1' 
            )
        }

        return [cDSCResourceInformation]::GetExactPathName($resultPath)
    }

    <#
        .SYNOPSIS
            Identifies the root path of a DSC resource from the path which contains the .PSD1 file

        .NOTES
            With Windows PowerShell 5 side-by-side module versioning, it is necessary to sometimes
            traverse upwards an additional level from where the .PSD1 is found
    #>
    hidden [string] GetDSCResourceRoot([string]$VersionRoot, [string]$Version)
    {
        if(-not (Test-Path -Path $VersionRoot -PathType Container)) {
            throw [System.IO.DirectoryNotFoundException]::new(
                'DSC Resource VersionRoot is not present'
            )
        }

        $di = [System.IO.DirectoryInfo]::new($VersionRoot)
        if($di.BaseName -eq $Version) {
            return [cDSCResourceInformation]::GetExactPathName($di.Parent.FullName)
        }

        return $VersionRoot
    }

    <#
        .SYNOPSIS
            Returns the directory containing the .PSD1 file for the given resource path.

        .NOTES
            TODO: This should be altered to use the PSD1 path instead of the resource path as the
            input variable
    #>
    hidden [string] GetDSCResourceVersionRootDirectory([string]$ResourcePath)
    {
        if(-not [String]::IsNullOrEmpty($ResourcePath)) {
            $psdPath = $this.FindDSCResourcePSD1($ResourcePath)
                        
            $fi = [System.IO.FileInfo]::new($psdPath)

            return $fi.Directory.FullName
        }

        return $null
    }

    <#
        .SYNOPSIS
            Reads the contents of a mpdule's PSD1 to identofy whether any other modules are listed as
            dependencies to this resource.
    #>
    hidden [string[]] GetResourceModuleDependencies([string]$PSD1Path)
    {
        $psdContent = Get-Content -Path $PSD1Path -raw
        $psd = Invoke-Expression -Command $psdContent
        return $psd.PSDModules
    }
}
