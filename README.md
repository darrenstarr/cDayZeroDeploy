# cDayZeroDeploy
## Powershell DSC Resources for Day Zero data center deployment

Copyright 2017 Conscia Norway AS

### Summary

cDayZeroDeploy is an effort to make use of Powershell DSC to build a full Powershell DSC managed datacenter. The concept is that from the moment that hardware arrives on site and is plugged in, absolutely no manual configuration will be done to deploy the servers. Once the day-zero scripts are finished running, the system left behind should be 100% maintained via DSC. The goal is to configure switches, routers, bare metal servers, storage, etc... all from Powershell DSC. 

The project is ambitious, but thanks to Microsoft's SDN Express deployment [scripts](https://github.com/Microsoft/SDN/tree/master/SDNExpress/scripts) which focus entirely on functionality before being "proper", it is clear that it can be done. [Darren Starr](https://github.com/darrenstarr) the initial contributor to this code is already shipping products using the underlying code distributed here.

### Current status

cDayZeroDeploy is in its very early stages of development. While there is far more code privately kept by Darren, that code is similar to SDN Express in the sense that it makes use of [Script resources](https://github.com/PowerShell/PSDscResources/tree/bba8fee7bd423dd9629a7a6cf3dea688de4b4e7d/DscResources/MSFT_ScriptResource) where it should instead make use of custom DSC resources.

### Direction/Guidelines

#### Class-based

All DSC resources contributed to this repository must be class based resources. There are however some drawbacks to this. Class based resources are in the infancy stages at Microsoft and can be very difficult to work with. In addition, since includes (dot-sourcing)  and neither does **using module**, don't appear to work from within DSC resources for classes, it is necessary to run a build script to concatenate all the class files together into a single file.

#### Integration tests

All resources must include at least an integration test that can be used to verify that it operates correctly. Optimally, this integration test will clean up after itself and always have before code that can cleanup any mess left behind due to earlier failures

#### Unit tests

Perform unit testing however you possibly can for now. As of the time, there's no good method to be able to mock tests for class based resources.

#### Prefer splatting

Prefer splatting over backticks for multi-line continuations.

#### Prefer Powershell

It is tempting at times to code in mixed languages, but so far, we haven't seen any cases where Powershell wasn't up to the task. Powershell can get fantastically ugly when performing some tasks, but the beauty of a system like this is that you don't need to download 10,000 tools and modules to make this system work. When in doubt, use Powershell.

### Resources

#### cWindowsVHD

[cWindowsVHD](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cWindowsVHD) converts a standard Windows Server 2016 installation DVD to a VHDX image that can be used for differencing images against. 

The way this does this is :
 1. Mount the ISO file
 2. Dot-Source the Convert-WindowsImage.ps1 from the NanoServer directory
 3. Execute Convert-WindowsImage to create a new VHDx file

##### [string] VHDPath (mandatory/key)
The path to the Windows VHD file to be created. The file extension must be '.vhdx'
##### [string] ISOPath (mandatory)
The path to the ISO image to be used for creating the VHD
##### [string] Edition (optional, default = 'SERVERDATACENTERCORE')
Specifies the Windows Server edition to install onto the VHD. As this is a data center, it's recommend to run strictly server core.
##### [UInt64] MaximumSizeBytes (optional, default = 100GB)
As this is a VHDX and the storage space is not preallocated, the default value is 100GB though can be increased if needed.

##### Exceptions (Throws)

* System.ArgumentException - For incorrect use of parameters
* System.Exception - For most cases where no standard exception exists
* System.IO.FileNotFoundException - When files are not found
* System.IO.IOException - When files or directories can't be created

##### Example

```
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
            NodeName                    = 'localhost'
            VHDPath                     = (Join-Path -Path $Env:TEMP -ChildPath 'test.vhdx')
            ISOPath                     = (Join-Path -Path $Env:TEMP -ChildPath 'en_windows_server_2016_x64_dvd_9718492.iso') 
        }
    )
}
```

