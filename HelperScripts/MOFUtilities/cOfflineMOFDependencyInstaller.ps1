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
        A class to perform an offline installation of DSC resources needed by a MOF file

    .DESCRIPTION
        This class opens, parses and extracts a list of all DSC resource dependencies needed by
        a MOF file. Then it catalogs a manifest of all the files and directories needed for the
        DSC resources and copies them to a location, assumed to be the root directory of a mounted
        Windows Server VHD based virtual machine to the directory structure of that virtual machine.

  .AUTHOR
      Darren R. Starr
 
  .COPYRIGHT
      2017 Conscia Norway AS
 
    .NOTES
        I am not 1000% percent secure in my means of identifying the root of a DSC resource as
        there is no mechanism I could find on Get-DSCResource to return the GUID of the resource
        so I could read the contents of a PSD1 file and match it to the resource module.
#>
class cOfflineMOFDependencyInstaller
{
    <#
        .SYNOPSIS
            Read the contents of a MOF file and return DSC resource dependencies
    #>
    static hidden [string[]] GetDSCResourceDependenciesFromMOF([string]$MOFPath)
    {
        if(-not (Test-Path -Path $MOFPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'MOF file [' + $MOFPath + '] not found'
            )
        }

        # Read the contents of the MOF file
        $mofText = Get-Content -Path $MOFPath

        # Attempt to parse the MOF file
        $result = $null
        try {
            $testMOFParser = [MOFParser]::new()
            $result = $testMOFParser.Parse($mofText)
        } catch {
            throw [Exception]::new(
                'Failed to parse ' + $MOFPath,
                $_.Exception
            )
        }

        # Throw an exception if there was no result
        if($null -eq $result) {
            throw [Exception]::new(
                'Failed to parse ' + $MOFPath
            )
        }

        # Find MOF objects which contain 'As' clauses
        $instanceOfObjects = $result.Where{
            $_ -is [MOFInstanceOf] -and 
            ($null -ne ($_ -as [MOFInstanceOf]).As) 
        }

        if ($null -eq $instanceOfObjects) {
            return $null
        }

        # Find the names of the module dependencies when inheriting using 'As'
        $dscResourceModuleNames = $instanceOfObjects.ForEach{
            $_.Value.Values.Where{ 
                $_.Name.Name -eq 'ModuleName' -and 
                $_.Value -is [MOFStringValue] 
            }
        }.ForEach{
            $_.Value.Value
        } | Select-Object -Unique

        return $dscResourceModuleNames
    }

    static [void]CopyMOFDependencies([string]$MOFPath, [string]$WindowsVHDRoot)
    {
        $dscResourceDependencies = [cOfflineMOFDependencyInstaller]::GetDSCResourceDependenciesFromMOF($MOFPath)
        Write-Verbose -Message ('Identified ' + $dscResourceDependencies.Count.ToString() + ' resource dependencies')
        $dscResourceDependencies.ForEach{ 
            Write-Verbose -Message ('Dependency - ' + $_)
        }

        $resources = $null
        try {
            $resources = $dscResourceDependencies.ForEach{ [cDSCResourceInformation]::new($_) }        
        } catch {
            Write-Verbose -Message ('Failed to get resource information for ' + $_)
            throw $_.Exception
        }
    
        $resources.ForEach{ 
            Write-Host $_

            $_.Manifest.ForEach{
                $destinationPath = Join-Path -Path $WindowsVHDRoot -ChildPath $_.RecommendedDestinationPath
                if(-not (Test-Path -Path $destinationPath)) {
                    Write-Verbose -Message ('  Creating - [' + $destinationPath + ']')
                    New-Item -Path $destinationPath -ItemType Directory
                }

                $itemDestinationPath = Join-Path -Path $destinationPath -ChildPath $_.RelativePath
                if($_.Item -is [System.IO.DirectoryInfo]) {
                    if(-not (Test-Path -Path $itemDestinationPath)) {
                        Write-Verbose ('  Creating - [' + $itemDestinationPath + ']')
                        New-Item -Path $itemDestinationPath -ItemType Directory
                    }
                } elseif($_.Item -is [System.IO.FileInfo]) {
                    if(-not (Test-Path -Path $itemDestinationPath)) {
                        Write-Verbose -Message ('    Copying - [' + $_.item.FullName + '] to [' + $itemDestinationPath + ']')
                        Copy-Item -Path $_.item.FullName -Destination $itemDestinationPath 
                    }
                } else {
                    throw [System.Exception]::new(
                        'Cannot process unknown file system type - ' + $_.Item.FullName
                    )
                }
            } 
        }
    }
}
