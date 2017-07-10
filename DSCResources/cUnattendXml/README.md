# cUnattendXml
[cUnattendXml](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cUnattendXml) provides a DSC resource to produce well formatted unattend.xml files for the purpose of providing [answer files](https://social.technet.microsoft.com/wiki/contents/articles/36609.windows-server-2016-unattended-installation.aspx) that can automate the bootstrapping of a Windows Server 2016 installation.

This is one of the more complex resources in the system as it makes extensive use of the Powershell (.NET) XMLDocument APIs to produce name-space correct XML programmatically as opposed to the more common abuse of templating and pray generation. 

As this module is extremely complex, it is spread across two files. [UnattendXml.ps1](https://github.com/darrenstarr/cDayZeroDeploy/blob/master/DSCResources/cUnattendXml/Classes/UnattendXml.ps1) which is a straight forward Powershell class called UnattendXml that is heavily documented and mostly consistent. The second file [cUnattendXml.ps1](https://github.com/darrenstarr/cDayZeroDeploy/blob/master/DSCResources/cUnattendXml/Classes/cUnattendXml.ps1) is the DSC Resource around the class.

## Parameters
### [string] Path (mandatory/key)
The path to the output the unattend.xml file to. This is a full filename, not a directory. Beyond that it has no requirements.
### [string] ComputerName (optional)
The computer name to configure on the machine
### [string] RegisteredOwner(optional)
The registered owner to appear in System settings
### [string] RegisteredOrganization(optional)
The registered organization to appear in System settings
### [string] TimeZone(optional)
The time zone to set for the PC. This should be as it is documented at [Microsoft](https://technet.microsoft.com/en-us/library/cc749073(v=ws.10).aspx)
### [string] LocalAdministratorPassword(optional)
The local system administrator password to be configured for the PC. While this is optional, it is important to set it in order to handle "runonce" commands and other specialization steps. This function "properly" implements Microsoft's obscurification of password via encoding the password as Base64 along with the word "AdministratorPassword" trailing the password itself. It is not to be considered secure as it is easily reversible, but should be good enough until after the machine is installed and reconfigured properly using secure channels. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766409(v=ws.10).aspx)
### [string] InterfaceName(optional)
The name of the network interface to configure IP settings for during initial configuration. In Hyper-V, this is commonly 'Ethernet' however as later modules will allow changing this name, it is configurable.
### [bool] DisableDHCP(optional)
This disables DHCP on the interface defined by InterfaceName. It is recommended (even required in this resource) to disable DHCP when configuring static addresses.  See [Microsoft](https://technet.microsoft.com/en-us/library/cc748924(v=ws.10).aspx)
### [bool] DisableRouterDiscovery(optional)
Disables router discovery so that IPv4 router discovery is not performed which is part of the stateless address autoconfiguration for IPv4 within Windows (you know it from the 169.254.0.0/16 addresses that configure on Windows magically when DHCP is not present. It is recommended and even required (in this resource) to disable router discovery when configuring static IP address on the interface specified by InterfaceName. See [Microsoft](https://technet.microsoft.com/en-us/library/cc749578(v=ws.10).aspx)
### [string] IPAddress(optional)
Specifies an IPv4 address to assign to the interface specified by InterfaceName. It is required that an IP Address, SubnetLength and DefaultGateway are configured as well as DHCP and router discovery being disabled to make this work. See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
### [int] SubnetLength(optional)
Specifies the subnet prefix length (24 = 255.255.255.0) which is the number of  leading bits in the IP address for the interface (specificied by InterfaceName) that defines the prefix of the subnet upon which it resides. See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
### [string] DefaultGateway(optional)
The IP address of the gateway to map to the routing table entry 0.0.0.0/0 bound to the interface specified by InterfaceName. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766470(v=ws.10).aspx)
### [string[]] DNSServers(optional)
A list of DNS servers in the order which they should be "favored" as per the DNS search order for when there is connectivity available on the interface specified by InterfaceName.
### [string] DNSDomainName(optional)
The fully qualified domain name to configure as the default search domain of the network connected to the interface specified by InterfaceName
### [int] InterfaceMetric(optional, default value=10)
Configures the routing metric to apply to the interface (specified by InterfaceName) routes in the IPv4 routing table. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766415(v=ws.10).aspx)
### [string] ReadyRegistryKeyName(optional, default value='Status')
### [string] ReadyRegistryKeyValue(optional, default value='Ready')
ReadyRegistryKeyName and ReadyRegistryKeyValue are used together to configure a registry key that will be set within the Windows registry under (HKLM:\Software\Microsoft\Virtual Machine\Guest) that can be read via Windows WMI (namespace root\virtualization\v2) if the machine is running on Hyper-V. To set these keys, the tool '%windir%\System32\reg.exe' is called as the from the FirstLogonCommand section of the unattend.xml. Therefore, autologon is necessary for this to work.

## Exceptions (Throws)
* System.ArgumentException when arguments/parameters are incorrect
* System.ArgumentNullException when arguments are null which shouldn't be. 

## Example

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
