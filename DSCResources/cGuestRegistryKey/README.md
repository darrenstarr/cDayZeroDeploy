# cGuestRegistryKey
[cGuestRegistryKey](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cGuestRegistryKey) 
employs WMI to read the value of registry keys set within Hyper-V guest virtual machines as part of key-value exchange. The keys are set within the guest machine by adding and changing settings at HKLM:\Software\Microsoft\Virtual Machine\Guest, this code reads those keys by parsing the results of WMI namespace 'root\virtualization\v2'

This code is useful for letting the host machine read values set within the guest. So far, this code has been tested by writing registry keys and values from unattend.xml using reg.exe and also by using Set-ItemPropery from Powershell and also from using DSC Resource [Registry](https://github.com/PowerShell/PSDscResources/tree/bba8fee7bd423dd9629a7a6cf3dea688de4b4e7d/DscResources/MSFT_RegistryResource) as part of [PSDscResources](https://github.com/PowerShell/PSDscResources/tree/bba8fee7bd423dd9629a7a6cf3dea688de4b4e7d).

## Parameters
### [string] VMName (mandatory/key)
The name of the virtual machine within the Hyper-V hypervisor.
### [string] KeyName(mandatory)
The key name under HKLM:\Software\Microsoft\Virtual Machine\Guest within the guest
### [string] KeyValue(mandatory)
The value to wait for. This resource at this time only works with string values.
### [int] TimeOutSeconds(optional, default value = 180)
The period of time to wait before giving up in seconds.
### [int] PollIntervalSeconds(optional, default value = 1)
The period of time to wait between polling the WMI provider to look for the registry key. This is basically a retry timer and while it's not particularly heavy, it can have a minimal impact on performance. It would be great if a WMI watcher could be found to replace the polling.

## Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions

## Example

```Powershell
Configuration cGuestRegistryKeyExample {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy
    Import-DscResource -ModuleName xHyper-V

    node $ComputerName {
        cDifferencingVHD VMDisk {
            VHDPath = $Node.VHDPath
            ParentVHDPath = $Node.ParentVHDPath
        }

        cUnattendXml UnattendXml {
            Path = $Node.UnattendXmlPath
            LocalAdministratorPassword = 'Minions867-5309'
            RegisteredOwner = 'Bob'
            RegisteredOrganization = 'Minions will take over Inc.'
            ReadyRegistryKeyName = 'SystemStatus'
            ReadyRegistryKeyValue = 'Ready'
        }

        cVHDFileSystem VHDFileSystem {
            VHDPath = $Node.VHDPath
            ItemList = @(
                ($Node.UnattendXmlPath), 'unattend.xml'
            )
            DependsOn = @('[cDifferencingVHD]VMDisk', '[cUnattendXml]UnattendXml')
        }

        xVMHyperV TestVM {
            Ensure        = 'Present'
            Name          = 'TestVM'
            VhdPath       = $Node.VHDPath
            Generation    = 2
            StartupMemory = 1GB
            MinimumMemory = 512MB
            MaximumMemory = 4GB
            ProcessorCount = 2
            State = 'Running'
            SecureBoot = $true
            DependsOn     = @('[cVHDFileSystem]VHDFileSystem')
        }

        cGuestRegistryKey BasicTest {
            VMName = 'TestVM'
            KeyName = 'SystemStatus'
            KeyValue = 'Ready'
            DependsOn = @('[xVMHyperV]TestVM')
        }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName       = 'localhost'
            VHDPath        = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd2.vhdx')
            ParentVHDPath  = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd.vhdx')
            TestFile       = (Join-Path -Path $Env:TEMP -ChildPath 'testfile.txt')
       }
    )
}
```
