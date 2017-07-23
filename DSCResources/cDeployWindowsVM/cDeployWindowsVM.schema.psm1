Configuration cDeployWindowsVM
{
    Param (
        <#
            .SYNOPSIS
                The name of the virtual machine to deploy
        #>
        [Parameter(Mandatory)]
        [string] $VMName,

        <#
            .SYNOPSIS
                The path to store the VM VHD file on
        #>
        [Parameter(Mandatory)]
        [string] $VHDPath,
        
        <#
            .SYNOPSIS
                The path which specifies the parent VHD to create a differencing image from
        #>
        [Parameter(Mandatory)]
        [string] $ParentVHDPath,

        <#
            .SYNOPSIS
                The path to store the unattend.xml script for the given virtual machine. 
                
            .DESCRIPTION
                Is is a full filename and not just the directory to save it in.
        #>
        [Parameter(Mandatory)]
        [string] $UnattendXMLPath,

        <#
            .SYNOPSIS
                The computer name to configure on the machine
        #>
        [Parameter()]
        [string] $ComputerName,

        <#
            .SYNOPSIS
                The registered owner to appear in System settings
        #>
        [Parameter()]
        [string] $RegisteredOwner,

        <#
            .SYNOPSIS
                The registered organization to appear in System settings
        #>
        [Parameter()]
        [string] $RegisteredOrganization,

        <#
            .SYNOPSIS
                The time zone to set for the PC.

            .NOTES
                This should be as it is documented at [Microsoft](https://technet.microsoft.com/en-us/library/cc749073(v=ws.10).aspx)
        #>
        [Parameter()]
        [string] $TimeZone,

        <#
            .SYNOPSIS
                The local system administrator password to be configured for the PC. 
                
            .NOTES
                While this is optional, it is important to set it in order to handle "runonce" commands 
                and other specialization steps. This function "properly" implements Microsoft's obscurification
                of password via encoding the password as Base64 along with the word "AdministratorPassword" 
                trailing the password itself. It is not to be considered secure as it is easily reversible, 
                but should be good enough until after the machine is installed and reconfigured properly using 
                secure channels. See [Microsoft](https://technet.microsoft.com/en-us/library/cc766409(v=ws.10).aspx)
        #>
        [Parameter()]
        [string] $LocalAdministratorPassword,

        <#
            .SYNOPSIS
                The name of the network interface to configure IP settings for during initial configuration.
                
            .NOTES
                In Hyper-V, this is commonly 'Ethernet' however as later modules will allow changing this name, it is configurable.
        #>
        [Parameter()]
        [string] $InterfaceName = 'Ethernet',

        <#
            .SYNOPSIS
                This disables DHCP on the interface defined by InterfaceName. 
                
            .NOTES
                It is recommended (even required in this resource) to disable DHCP when configuring static addresses.  
                See [Microsoft](https://technet.microsoft.com/en-us/library/cc748924(v=ws.10).aspx)
        #>
        [Parameter()]
        [bool] $DisableDHCP = $false,

        <#
            .SYNOPSIS
                Disables router discovery so that IPv4 router discovery is not performed which is part of the stateless address autoconfiguration for IPv4 within Windows.
                
            .NOTES
                You know it from the 169.254.0.0/16 addresses that configure on Windows magically when DHCP is not present. 
                It is recommended and even required (in this resource) to disable router discovery when configuring static IP 
                address on the interface specified by InterfaceName. 
                See [Microsoft](https://technet.microsoft.com/en-us/library/cc749578(v=ws.10).aspx)
        #>
        [Parameter()]
        [bool] $DisableRouterDiscovery = $false,

        <#
            .SYNOPSIS
                Specifies an IPv4 address to assign to the interface specified by InterfaceName. 
                It is required that an IP Address, SubnetLength and DefaultGateway are configured as well as DHCP and router 
                discovery being disabled to make this work. 
                See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
        #>
        [Parameter()]
        [string] $IPAddress,

        <#
            .SYNOPSIS
                Specifies the subnet prefix length.
                
            .NOTES
                This refers to CIDR notation (24 = 255.255.255.0) which is the number of  leading bits in the 
                IP address for the interface (specificied by InterfaceName) that defines the prefix of the subnet 
                upon which it resides. 
                See [Microsoft](https://technet.microsoft.com/en-us/library/cc721852(v=ws.10).aspx)
        #>
        [Parameter()]
        [int] $SubnetLength,

        <#
            .SYNOPSIS
                The IP address of the gateway to map to the routing table entry 0.0.0.0/0 bound to the interface specified by InterfaceName. 
                
            .NOTES
                See [Microsoft](https://technet.microsoft.com/en-us/library/cc766470(v=ws.10).aspx)
        #>
        [Parameter()]
        [string] $DefaultGateway,

        <#
            .SYNOPSIS
                A list of DNS servers in the order which they should be "favored" as per the DNS search order for when there is connectivity available on the interface specified by InterfaceName.
        #>
        [Parameter()]
        [string[]] $DNSServers,

        <#
            .SYNOPSIS
                The fully qualified domain name to configure as the default search domain of the network connected to the interface specified by InterfaceName
        #>
        [Parameter()]
        [string] $DNSDomainName,

        <#
            .SYNOPSIS
                Configures the routing metric to apply to the interface (specified by InterfaceName) routes in the IPv4 routing table. 
                
            .NOTES
                See [Microsoft](https://technet.microsoft.com/en-us/library/cc766415(v=ws.10).aspx)                
        #>
        [Parameter()]
        [int] $InterfaceMetric = 10,

        <#
            .SYNOPSIS
                Sets a registry key on first boot
            
            .NOTES
                ReadyRegistryKeyName and ReadyRegistryKeyValue are used together to configure a registry key 
                that will be set within the Windows registry under (HKLM:\Software\Microsoft\Virtual Machine\Guest) 
                that can be read via Windows WMI (namespace root\virtualization\v2) if the machine is running on Hyper-V. 
                To set these keys, the tool '%windir%\System32\reg.exe' is called as the from the FirstLogonCommand 
                section of the unattend.xml. Therefore, autologon is necessary for this to work.
        #>
        [Parameter()]
        [string] $ReadyRegistryKeyName = 'Status',

        <#
            .SYNOPSIS
                Sets a registry key on first boot
            
            .NOTES
                ReadyRegistryKeyName and ReadyRegistryKeyValue are used together to configure a registry key 
                that will be set within the Windows registry under (HKLM:\Software\Microsoft\Virtual Machine\Guest) 
                that can be read via Windows WMI (namespace root\virtualization\v2) if the machine is running on Hyper-V. 
                To set these keys, the tool '%windir%\System32\reg.exe' is called as the from the FirstLogonCommand 
                section of the unattend.xml. Therefore, autologon is necessary for this to work.                
        #>
        [Parameter()]
        [string] $ReadyRegistryKeyValue = 'Ready',

        <#
            .SYNOPSIS
                The amount of memory to assign to the VM at startup
        #>
        [Parameter()]
        [UInt64] $StartupMemory = 1GB,

        <#
            .SYNOPSIS
                The minimum amount of memory to assign to the VM
        #>
        [Parameter()]
        [UInt64] $MinimumMemory = 512MB,

        <#
            .SYNOPSIS
                The maximum amount of memory to assign to the VM
        #>
        [Parameter()]
        [UInt64] $MaximumMemory = 4GB,

        <#
            .SYNOPSIS
                The number of processor cores to assign to the VM
        #>
        [Parameter()]
        [int] $ProcessorCount = 2,

        <#
            .SYNOPSIS
                The name of the virtual switch to connect the first network interface to.
        #>
        [Parameter()]
        [string] $SwitchName,

        <#
            .SYNOPSIS
                The MOF file to copy to the image
        #>
        [Parameter()]
        [string] $InitialMOF,

        <#
            .SYNOPSIS
                Where to copy the MOF to on the VHD
        #>
        [Parameter()]
        [string] $MOFPath
    )

    Import-DscResource -Name xVMHyperV -ModuleName xHyper-V

    cDifferencingVHD VirtualMachineDisk {
        VHDPath         = $VHDPath
        ParentVHDPath   = $ParentVHDPath
    }

    cUnattendXml UnattendXml {
        Path                                = $UnattendXMLPath
        ComputerName                        = $ComputerName
        RegisteredOwner                     = $RegisteredOwner
        RegisteredOrganization              = $RegisteredOrganization
        TimeZone                            = $TimeZone
        LocalAdministratorPassword          = $LocalAdministratorPassword
        InterfaceName                       = $InterfaceName
        DisableDHCP                         = $DisableDHCP
        DisableRouterDiscovery              = $DisableRouterDiscovery
        IPAddress                           = $IPAddress
        SubnetLength                        = $SubnetLength
        DefaultGateway                      = $DefaultGateway
        DNSServers                          = $DNSServers
        DNSDomainName                       = $DNSDomainName
        InterfaceMetric                     = $InterfaceMetric
        EnableLocalWindowsRemoteManagement  = $true
        ConfigurePushLCM                    = $true
        MOFPath                             = $MOFPath
        ReadyRegistryKeyName                = $ReadyRegistryKeyName
        ReadyRegistryKeyValue               = $ReadyRegistryKeyValue
    }

    cVHDFileSystem VHDFileSystem {
        VHDPath     = $VHDPath
        ItemList    = @(
                          ($UnattendXMLPath), 'unattend.xml'
                      )
        InitialMOF  = $InitialMOF
        MOFPath     = $MOFPath
        DependsOn   = @('[cDifferencingVHD]VirtualMachineDisk', '[cUnattendXml]UnattendXml')
    }

    xVMHyperV VirtualMachine {
        Ensure              = 'Present'
        Name                = $VMName
        VhdPath             = $VHDPath
        Generation          = 2
        StartupMemory       = $StartupMemory
        MinimumMemory       = $MinimumMemory
        MaximumMemory       = $MaximumMemory
        ProcessorCount      = $ProcessorCount
        State               = 'Running'
        SecureBoot          = $true
        RestartIfNeeded     = $true
        EnableGuestService  = $true
        SwitchName          = $SwitchName
        DependsOn           = @('[cVHDFileSystem]VHDFileSystem')
        
    }

    cGuestRegistryKey StatusReadyKey {
        VMName          = $VMName
        KeyName         = $ReadyRegistryKeyName
        KeyValue        = $ReadyRegistryKeyValue
        DependsOn       = @('[xVMHyperV]VirtualMachine')
        TimeOutSeconds  = 600
    }
}
