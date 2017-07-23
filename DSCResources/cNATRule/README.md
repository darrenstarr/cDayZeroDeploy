# cNATRule
[cNATRule](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cNATRule) 
Configures, updates or removes a NAT rule which is useful for NATing a virtual switch to an external network. cNATRule is a minimal
implementation and does not implement all features of Windows NAT at this time

## Parameters
### [string] Name (mandatory/key)
A unique identifer for this NAT rule
### [PresentState] Ensure (optional, default value = 'Present')
Specifies whether the rule should be present or absent
### [bool] Active (optional, default value = $true)
Specifies whether the rule should be active
### [string] InternalIPInterfaceAddressPrefix (optional)
Specifies the network prefix representing the network which should be NATed from the inside. As per New-NetNat, if the prefix length
is not provided, this method reverts to classful.

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
