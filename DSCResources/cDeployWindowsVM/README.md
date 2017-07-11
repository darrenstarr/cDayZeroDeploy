# cDeployWindowsVM
[cDeployWindowsVM](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cDeployWindowsVM) is a composite resource that make use of a few of the other resources ([cDifferencingVHD](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cDifferencingVHD), [cUnattendXml](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cUnattendXml), [cVHDFileSystem](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cVHDFileSystem), and [cGuestRegistryKey](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cGuestRegistryKey)) to automate the deployment of a Windows Server 2016 Server with an answer file to prepare the server for additional DSC configuration.

## Parameters
### [string] VMName (Mandatory, Key)
The name of the virtual machine to deploy

### [string] VHDPath (Mandatory)
The path to store the VM VHD file on

### [string] ParentVHDPath (Mandatory)
The path which specifies the parent VHD to create a differencing image from

### [string] UnattendXMLPath (Mandatory)
The path to store the unattend.xml script for the given virtual machine. Is is a full filename and not just the directory to save it in.

### [string] ComputerName (Optional)
The computer name to configure on the machine

### [string] RegisteredOwner (Optional)
The registered owner to appear in System settings

### [string] RegisteredOrganization (Optional)
The registered organization to appear in System settings

### [string] TimeZone (Optional)
The time zone to set for the PC. This should be as it is documented at [Microsoft](https://technet.microsoft.com/en-us/library/cc749073(v=ws.10).aspx)

### [string] LocalAdministratorPassword (Optional)
The local system administrator password to be configured for the PC. While this is optional, it is important to set it in order to handle "runonce" commands  and other specialization steps. This function "properly" implements Microsoft's obscurification of password via encoding the password as Base64 along with the word "AdministratorPassword" trailing the password itself. It is not to be considered secure as it is easily reversible, but should be good enough until after the machine is installed and reconfigured properly using secure channels. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766409(v=ws.10).aspx)

### [string] InterfaceName (Optional, Default='Ethernet')
The name of the network interface to configure IP settings for during initial configuration. In Hyper-V, this is commonly 'Ethernet' however as later modules will allow changing this name, it is configurable.

### [bool] DisableDHCP (Optional, Default = $false)
This disables DHCP on the interface defined by InterfaceName. It is recommended (even required in this resource) to disable DHCP when configuring static addresses. See [Microsoft](https://technet.microsoft.com/en-us/library/cc748924(v=ws.10).aspx)

### [bool] DisableRouterDiscovery (Optional, Default = $false)
Disables router discovery so that IPv4 router discovery is not performed which is part of the stateless address autoconfiguration for IPv4 within Windows. You know it from the 169.254.0.0/16 addresses that configure on Windows magically when DHCP is not present. It is recommended and even required (in this resource) to disable router discovery when configuring static IP address on the interface specified by InterfaceName. See [Microsoft](https://technet.microsoft.com/en-us/library/cc749578(v=ws.10).aspx)

### [string] IPAddress (Optional)
Specifies an IPv4 address to assign to the interface specified by InterfaceName. It is required that an IP Address, SubnetLength and DefaultGateway are configured as well as DHCP and router discovery being disabled to make this work. See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
                
### [int] SubnetLength (Optional, Default = 0)
Specifies the subnet prefix length. This refers to CIDR notation (24 = 255.255.255.0) which is the number of leading bits in the IP address for the interface (specificied by InterfaceName) that defines the prefix of the subnet upon which it resides. See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)

### [string] DefaultGateway (Optional)
The IP address of the gateway to map to the routing table entry 0.0.0.0/0 bound to the interface specified by InterfaceName. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766470(v=ws.10).aspx)

### [string] DNSServers (Optional)
A list of DNS servers in the order which they should be "favored" as per the DNS search order for when there is connectivity available on the interface specified by InterfaceName.

### [string] DNSDomainName (Optional)
The fully qualified domain name to configure as the default search domain of the network connected to the interface specified by InterfaceName

### [int] InterfaceMetric (Optional, Default = 10)
Configures the routing metric to apply to the interface (specified by InterfaceName) routes in the IPv4 routing table. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766415(v=ws.10).aspx)                

### [string] ReadyRegistryKeyName (Optional, = 'Status')
### [string] ReadyRegistryKeyValue (Optional, = 'Ready')
Sets a registry key on first boot. ReadyRegistryKeyName and ReadyRegistryKeyValue are used together to configure a registry key that will be set within the Windows registry under (HKLM:\Software\Microsoft\Virtual Machine\Guest) that can be read via Windows WMI (namespace root\virtualization\v2) if the machine is running on Hyper-V. To set these keys, the tool '%windir%\System32\reg.exe' is called as the from the FirstLogonCommand section of the unattend.xml. Therefore, autologon is necessary for this to work.

### [UInt64] StartupMemory (Optional, Default = 1GB)
The amount of memory to assign to the VM at startup

### [UInt64] MinimumMemory (Optional, Default = 512MB)
The minimum amount of memory to assign to the VM

### [UInt64] MaximumMemory (Optional, Default = 4GB)
The maximum amount of memory to assign to the VM

### [int] ProcessorCount (Optional, Default = 2)
The number of processor cores to assign to the VM

### [string] SwitchName (Optional)
The name of the virtual switch to connect the first network interface to.

## Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions
* System.IO.FileNotFoundException for when files (the parent VHD) is missing
* System.ArgumentException when arguments/parameters are incorrect
* System.IO.DirectoryNotFoundException when the parent folder for the new VHD is not present

## Example

```Powershell
Configuration cDeployWindowsVMExample {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {

        node $ComputerName {

        cDeployWindowsVM BasicTest {
            VHDPath                     = $node.VHDPath
            ParentVHDPath               = $node.ParentVHDPath
            UnattendXMLPath             = $node.UnattendXMLPath

            VMName                      = $node.VMName
            StartupMemory               = 512MB
            SwitchName                  = 'DemoLabSwitch'

            ReadyRegistryKeyName        = 'SystemStatus'
            ReadyRegistryKeyValue       = 'Ready'

            ComputerName                = $Node.VMName
            LocalAdministratorPassword  = 'Minions8675309'
            RegisteredOwner             = 'Bob'
            RegisteredOrganization      = 'Minions will take over Inc.'

            InterfaceName               = 'Ethernet'
            IPAddress                   = $Node.IPAddress
            SubnetLength                = $Node.SubnetLength
            DefaultGateway              = $Node.DefaultGateway
            DisableDHCP                 = $true
            DisableRouterDiscovery      = $true
        }
    }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName                    = 'localhost'
            PsDscAllowPlainTextPassword = $true
            VMName                      = 'MinionsRule'
            VHDPath                     = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd2.vhdx')
            ParentVHDPath               = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd.vhdx')
            UnattendXmlPath             = (Join-Path -Path $Env:TEMP -ChildPath 'testunattend.xml')
            IPAddress                   = '10.0.0.219'
            SubnetLength                = 24
            DefaultGateway              = '10.0.0.1'
        }
    )
}
```
