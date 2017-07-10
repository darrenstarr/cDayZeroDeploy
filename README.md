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

##### Parameters
###### [string] VHDPath (mandatory/key)
The path to the Windows VHD file to be created. The file extension must be '.vhdx'
###### [string] ISOPath (mandatory)
The path to the ISO image to be used for creating the VHD
###### [string] Edition (optional, default = 'SERVERDATACENTERCORE')
Specifies the Windows Server edition to install onto the VHD. As this is a data center, it's recommend to run strictly server core.
###### [UInt64] MaximumSizeBytes (optional, default = 100GB)
As this is a VHDX and the storage space is not preallocated, the default value is 100GB though can be increased if needed.

##### Exceptions (Throws)
System.ArgumentException - For incorrect use of parameters
System.Exception - For most cases where no standard exception exists
System.IO.FileNotFoundException - When files are not found
System.IO.IOException - When files or directories can't be created

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
            NodeName   = 'localhost'
            VHDPath    = (Join-Path -Path $Env:TEMP -ChildPath 'test.vhdx')
            ISOPath    = (Join-Path -Path $Env:TEMP -ChildPath 'en_windows_server_2016_x64_dvd_9718492.iso') 
        }
    )
}
```

#### cDifferencingVHD
[cDifferencingVHD](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cDifferencingVHD) is a simple wrapper to create a differencing VHD file. This resource hopefully will have a short life-span as [xVHD](https://github.com/PowerShell/xHyper-V/tree/dev/DSCResources/MSFT_xVHD) from [xHyper-V](https://github.com/PowerShell/xHyper-V) has recently received attention from the team and there appears to be a lot of pull requests coming in. Once it goes "production ready", this module should hopefully be deprecated.

##### Parameters
###### [string] VHDPath (mandatory/key)
The path to the output VHD to be created. The file extension must be '.vhdx'
###### [string] ParentVHDPath(mandatory)
The path to parent VHD file to create the differencing image against

##### Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions
* System.IO.FileNotFoundException for when files (the parent VHD) is missing
* System.ArgumentException when arguments/parameters are incorrect
* System.IO.DirectoryNotFoundException when the parent folder for the new VHD is not present

##### Example

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

#### cUnattendXml
[cUnattendXml](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cUnattendXml) provides a DSC resource to produce well formatted unattend.xml files for the purpose of providing [answer files](https://social.technet.microsoft.com/wiki/contents/articles/36609.windows-server-2016-unattended-installation.aspx) that can automate the bootstrapping of a Windows Server 2016 installation.

This is one of the more complex resources in the system as it makes extensive use of the Powershell (.NET) XMLDocument APIs to produce name-space correct XML programmatically as opposed to the more common abuse of templating and pray generation. 

As this module is extremely complex, it is spread across two files. [UnattendXml.ps1](https://github.com/darrenstarr/cDayZeroDeploy/blob/master/DSCResources/cUnattendXml/Classes/UnattendXml.ps1) which is a straight forward Powershell class called UnattendXml that is heavily documented and mostly consistent. The second file [cUnattendXml.ps1](https://github.com/darrenstarr/cDayZeroDeploy/blob/master/DSCResources/cUnattendXml/Classes/cUnattendXml.ps1) is the DSC Resource around the class.

##### Parameters
###### [string] Path (mandatory/key)
The path to the output the unattend.xml file to. This is a full filename, not a directory. Beyond that it has no requirements.
###### [string] ComputerName (optional)
The computer name to configure on the machine
###### [string] RegisteredOwner(optional)
The registered owner to appear in System settings
###### [string] RegisteredOrganization(optional)
The registered organization to appear in System settings
###### [string] TimeZone(optional)
The time zone to set for the PC. This should be as it is documented at [Microsoft](https://technet.microsoft.com/en-us/library/cc749073(v=ws.10).aspx)
###### [string] LocalAdministratorPassword(optional)
The local system administrator password to be configured for the PC. While this is optional, it is important to set it in order to handle "runonce" commands and other specialization steps. This function "properly" implements Microsoft's obscurification of password via encoding the password as Base64 along with the word "AdministratorPassword" trailing the password itself. It is not to be considered secure as it is easily reversible, but should be good enough until after the machine is installed and reconfigured properly using secure channels. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766409(v=ws.10).aspx)
###### [string] InterfaceName(optional)
The name of the network interface to configure IP settings for during initial configuration. In Hyper-V, this is commonly 'Ethernet' however as later modules will allow changing this name, it is configurable.
###### [bool] DisableDHCP(optional)
This disables DHCP on the interface defined by InterfaceName. It is recommended (even required in this resource) to disable DHCP when configuring static addresses.  See [Microsoft](https://technet.microsoft.com/en-us/library/cc748924(v=ws.10).aspx)
###### [bool] DisableRouterDiscovery(optional)
Disables router discovery so that IPv4 router discovery is not performed which is part of the stateless address autoconfiguration for IPv4 within Windows (you know it from the 169.254.0.0/16 addresses that configure on Windows magically when DHCP is not present. It is recommended and even required (in this resource) to disable router discovery when configuring static IP address on the interface specified by InterfaceName. See [Microsoft](https://technet.microsoft.com/en-us/library/cc749578(v=ws.10).aspx)
###### [string] IPAddress(optional)
Specifies an IPv4 address to assign to the interface specified by InterfaceName. It is required that an IP Address, SubnetLength and DefaultGateway are configured as well as DHCP and router discovery being disabled to make this work. See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
###### [int] SubnetLength(optional)
Specifies the subnet prefix length (24 = 255.255.255.0) which is the number of  leading bits in the IP address for the interface (specificied by InterfaceName) that defines the prefix of the subnet upon which it resides. See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
###### [string] DefaultGateway(optional)
The IP address of the gateway to map to the routing table entry 0.0.0.0/0 bound to the interface specified by InterfaceName. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766470(v=ws.10).aspx)
###### [string[]] DNSServers(optional)
A list of DNS servers in the order which they should be "favored" as per the DNS search order for when there is connectivity available on the interface specified by InterfaceName.
###### [string] DNSDomainName(optional)
The fully qualified domain name to configure as the default search domain of the network connected to the interface specified by InterfaceName
###### [int] InterfaceMetric(optional, default value=10)
Configures the routing metric to apply to the interface (specified by InterfaceName) routes in the IPv4 routing table. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766415(v=ws.10).aspx)
###### [string] ReadyRegistryKeyName(optional, default value='Status')
###### [string] ReadyRegistryKeyValue(optional, default value='Ready')
ReadyRegistryKeyName and ReadyRegistryKeyValue are used together to configure a registry key that will be set within the Windows registry under (HKLM:\Software\Microsoft\Virtual Machine\Guest) that can be read via Windows WMI (namespace root\virtualization\v2) if the machine is running on Hyper-V. To set these keys, the tool '%windir%\System32\reg.exe' is called as the from the FirstLogonCommand section of the unattend.xml. Therefore, autologon is necessary for this to work.

##### Exceptions (Throws)
* System.ArgumentException when arguments/parameters are incorrect
* System.ArgumentNullException when arguments are null which shouldn't be. 

##### Example

```
Configuration UnattendXmlExample {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cUnattendXml BasicTest {
            Path = $Node.TestFilePath
            LocalAdministratorPassword = 'Minions987654321'
            IPAddress = '192.168.1.2'
            SubnetLength = 24
            DefaultGateway = '192.168.1.1'
            DNSServers = @('8.8.8.8')
            DNSDomainName = 'mrsmoothie.com'
            DisableDHCP = $true
            DisableRouterDiscovery = $true
            RegisteredOwner = 'Bob'
            RegisteredOrganization = 'Minions will take over Inc.'
        }
    }
}
```

#### cVHDFileSystem
[cVHDFileSystem](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cVHDFileSystem) is similar to [xVhdFileDirectory](https://github.com/PowerShell/xHyper-V/tree/dev/DSCResources/MSFT_xVhdFileDirectory) from [xHyper-V](https://github.com/PowerShell/xHyper-V). It mounts a VHD image and copies files or directories to a destination within the VHD and then unmounts it.

Since this is meant to be used for a special case which is to perform an initial file transfer to a new differencing image, there are some built-in "outs" in the sense that the test function doesn't simply reopen the file and compare the VHD file system to the list of files to copy. It can also check to see if the VHD file is already mounted or if the VHD file is over a certain size. This means that in the case of transferring things like unattend.xml to the image which will be deleted in the end, the test will still pass and therefore artificially be idempotent.

##### Parameters
###### [string] VHDPath (mandatory/key)
The path to VHD file to be modified. The file extension must be '.vhdx'
###### [bool] OkIfMounted(optional, default value = $true)
If the file is already mounted, then the test will simply pass and therefore not try editing the image again
###### [UInt64] OkIfOverBytes(optional, default value = 4MB)
If the size of the file is more than this value, then the test will immediately pass. The default value of 4MB was chosen because the initial size of a VHDX differencing file is precisely 4MB. Immediately after mounting and closing the image, the size of the image will grow. The risk with this is that if there was a failure copying files during the first use, this test will automatically pass and the problem will remain. Additional verification may be needed. A value of zero bytes means this option would be disabled.
###### [string[]] ItemList(mandatory)
This is a list of string pairs formatted as SourcePath, DestinationRelativePath, SourcePath, DestinationRelativePath, etc... A source path can be a file or a directory. This resource DOES NOT create directories, so the parent directory of any file or directory must be present beforehand or the function will fail. At this time, there are no permissions set on files or directories within the image.

##### Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions
* System.IO.FileNotFoundException for when files (the parent VHD) is missing
* System.ArgumentException when arguments/parameters are incorrect
* System.ArgumentNullException when arguments which should be null aren't
* System.IO.DirectoryNotFoundException when the parent folder objects to be copied are not present

##### Example

```
Configuration cVHDFileSystem_Example {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cVHDFileSystem BasicTest {
            VHDPath = $Node.VHDPath
            ItemList = @(
                ($Node.TestFile), '\teapot.txt'
            )
        }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName       = 'localhost'
            VHDPath        = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd2.vhdx')
            TestFile = (Join-Path -Path $Env:TEMP -ChildPath 'testfile.txt')
       }
    )
}

Set-Content -Path $configData.AllNodes[0].TestFile -Value 'I''m a little teapot short and stout'
```

#### cGuestRegistryKey
[cGuestRegistryKey](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cGuestRegistryKey) 
employs WMI to read the value of registry keys set within Hyper-V guest virtual machines as part of key-value exchange. The keys are set within the guest machine by adding and changing settings at HKLM:\Software\Microsoft\Virtual Machine\Guest, this code reads those keys by parsing the results of WMI namespace 'root\virtualization\v2'

This code is useful for letting the host machine read values set within the guest. So far, this code has been tested by writing registry keys and values from unattend.xml using reg.exe and also by using Set-ItemPropery from Powershell and also from using DSC Resource [Registry](https://github.com/PowerShell/PSDscResources/tree/bba8fee7bd423dd9629a7a6cf3dea688de4b4e7d/DscResources/MSFT_RegistryResource) as part of [PSDscResources](https://github.com/PowerShell/PSDscResources/tree/bba8fee7bd423dd9629a7a6cf3dea688de4b4e7d).

##### Parameters
###### [string] VMName (mandatory/key)
The name of the virtual machine within the Hyper-V hypervisor.
###### [string] KeyName(mandatory)
The key name under HKLM:\Software\Microsoft\Virtual Machine\Guest within the guest
###### [string] KeyValue(mandatory)
The value to wait for. This resource at this time only works with string values.
###### [int] TimeOutSeconds(optional, default value = 180)
The period of time to wait before giving up in seconds.
###### [int] PollIntervalSeconds(optional, default value = 1)
The period of time to wait between polling the WMI provider to look for the registry key. This is basically a retry timer and while it's not particularly heavy, it can have a minimal impact on performance. It would be great if a WMI watcher could be found to replace the polling.

##### Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions

##### Example

```
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
