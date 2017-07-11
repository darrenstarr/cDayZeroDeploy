# cWindowsVHD
[cWindowsVHD](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cWindowsVHD) converts a standard Windows Server 2016 installation DVD to a VHDX image that can be used for differencing images against. 

The way this does this is :
 1. Mount the ISO file
 2. Dot-Source the Convert-WindowsImage.ps1 from the NanoServer directory
 3. Execute Convert-WindowsImage to create a new VHDx file

## Parameters
### [string] VHDPath (mandatory/key)
The path to the Windows VHD file to be created. The file extension must be '.vhdx'
### [string] ISOPath (mandatory)
The path to the ISO image to be used for creating the VHD
### [string] Edition (optional, default = 'SERVERDATACENTERCORE')
Specifies the Windows Server edition to install onto the VHD. As this is a data center, it's recommend to run strictly server core.
### [UInt64] MaximumSizeBytes (optional, default = 100GB)
As this is a VHDX and the storage space is not preallocated, the default value is 100GB though can be increased if needed.

## Exceptions (Throws)
System.ArgumentException - For incorrect use of parameters
System.Exception - For most cases where no standard exception exists
System.IO.FileNotFoundException - When files are not found
System.IO.IOException - When files or directories can't be created

## Example

```Powershell
Configuration WindowsVHDExample {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cWindowsVHD BasicTest {
            VHDPath = $Node.VHDPath
            ISOPath = $Node.ISOPath
        }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName   = 'localhost'
            VHDPath    = (Join-Path -Path $Env:TEMP -ChildPath 'test.vhdx')
            ISOPath    = (Join-Path -Path $Env:TEMP -ChildPath 'en_windows_server_2016_x64_dvd_9718492.iso') 
        }
    )
}
```
