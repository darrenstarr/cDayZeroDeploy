# cDifferencingVHD
[cDifferencingVHD](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cDifferencingVHD) is a simple wrapper to create a differencing VHD file. This resource hopefully will have a short life-span as [xVHD](https://github.com/PowerShell/xHyper-V/tree/dev/DSCResources/MSFT_xVHD) from [xHyper-V](https://github.com/PowerShell/xHyper-V) has recently received attention from the team and there appears to be a lot of pull requests coming in. Once it goes "production ready", this module should hopefully be deprecated.

## Parameters
### [string] VHDPath (mandatory/key)
The path to the output VHD to be created. The file extension must be '.vhdx'
### [string] ParentVHDPath(mandatory)
The path to parent VHD file to create the differencing image against

## Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions
* System.IO.FileNotFoundException for when files (the parent VHD) is missing
* System.ArgumentException when arguments/parameters are incorrect
* System.IO.DirectoryNotFoundException when the parent folder for the new VHD is not present

## Example

```
Configuration DifferencingDiskExample {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cDifferencingVHD BasicTest {
            VHDPath = $Node.VHDPath
            ParentVHDPath = $Node.ParentVHDPath
        }
    }
}


$configData = @{
    AllNodes = @(
        @{
            NodeName       = 'localhost'
            VHDPath        = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd2.vhdx')
            ParentVHDPath  = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd.vhdx')
        }
    )
}
```
