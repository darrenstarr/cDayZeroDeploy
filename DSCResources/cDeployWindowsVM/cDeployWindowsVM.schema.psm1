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

        [Parameter(Mandatory)]
        [string] $UnattendXMLPath,

        [Parameter()]
        [string] $ComputerName,

        [Parameter()]
        [string] $RegisteredOwner,

        [Parameter()]
        [string] $RegisteredOrganization,

        [Parameter()]
        [string] $TimeZone,

        [Parameter()]
        [string] $LocalAdministratorPassword,

        [Parameter()]
        [string] $InterfaceName = 'Ethernet',

        [Parameter()]
        [bool] $DisableDHCP = $false,

        [Parameter()]
        [bool] $DisableRouterDiscovery = $false,

        [Parameter()]
        [string] $IPAddress,

        [Parameter()]
        [int] $SubnetLength,

        [Parameter()]
        [string] $DefaultGateway,

        [Parameter()]
        [string[]] $DNSServers,

        [Parameter()]
        [string] $DNSDomainName,

        [Parameter()]
        [int] $InterfaceMetric = 10,


        [Parameter()]
        [string] $ReadyRegistryKeyName = 'Status',

        [Parameter()]
        [string] $ReadyRegistryKeyValue = 'Ready'
    )

    Import-DscResource -Name xVMHyperV -ModuleName xHyper-V

    cDifferencingVHD VirtualMachineDisk {
        VHDPath = $VHDPath
        ParentVHDPath = $ParentVHDPath
    }

    cUnattendXml UnattendXml {
        Path = $UnattendXMLPath
        ComputerName = $ComputerName
        RegisteredOwner = $RegisteredOwner
        RegisteredOrganization = $RegisteredOrganization
        TimeZone = $TimeZone
        LocalAdministratorPassword = $LocalAdministratorPassword
        InterfaceName = $InterfaceName
        DisableDHCP = $DisableDHCP
        DisableRouterDiscovery = $DisableRouterDiscovery
        IPAddress = $IPAddress
        SubnetLength = $SubnetLength
        DefaultGateway = $DefaultGateway
        DNSServers = $DNSServers
        DNSDomainName = $DNSDomainName
        InterfaceMetric = $InterfaceMetric
        ReadyRegistryKeyName = $ReadyRegistryKeyName
        ReadyRegistryKeyValue = $ReadyRegistryKeyValue
    }

    cVHDFileSystem VHDFileSystem {
        VHDPath = $VHDPath
        ItemList = @(
            ($UnattendXMLPath), 'unattend.xml'
        )
        DependsOn = @('[cDifferencingVHD]VirtualMachineDisk', '[cUnattendXml]UnattendXml')
    }

    xVMHyperV VirtualMachine {
        Ensure        = 'Present'
        Name          = $VMName
        VhdPath       = $VHDPath
        Generation    = 2
        StartupMemory = 1GB
        MinimumMemory = 512MB
        MaximumMemory = 4GB
        ProcessorCount = 2
        State = 'Running'
        SecureBoot = $true
        DependsOn     = @('[cVHDFileSystem]VHDFileSystem')
    }

    cGuestRegistryKey StatusReadyKey {
        VMName = $VMName
        KeyName = 'SystemStatus'
        KeyValue = 'Ready'
        DependsOn = @('[xVMHyperV]VirtualMachine')
    }
}
