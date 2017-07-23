Configuration cDeployWindowsDataCenter_Config {
    param(
        [string[]]$ComputerName="localhost",
        [string]$MOFPath
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy
    Import-DscResource -ModuleName xAdcsDeployment
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xComputerManagement
    Import-DscResource -ModuleName xHyper-V
    Import-DscResource -ModuleName xNetworking

    Node $ComputerName
    {
        LocalConfigurationManager
        {
            DebugMode = 'ForceModuleImport'
        }

        xVMSwitch TestSwitch
        {
            Ensure              = 'Present'
            Name                = $ConfigurationData.DomainInformation.SwitchName
            Type                = 'Internal'
            AllowManagementOS   = $true
        }

        xDHCPClient TestSwitchDisableDHCPv4 
        {
            State           = 'Disabled'
            InterfaceAlias  = 'vEthernet (' + $ConfigurationData.DomainInformation.SwitchName + ')'
            AddressFamily   = 'IPv4'
            DependsOn       = @('[xVMSwitch]TestSwitch') 
        }

        xIPAddress TestSwitchGatewayIPv4Address
        {
            IPAddress       = $ConfigurationData.DomainInformation.DefaultGateway 
            PrefixLength    = $ConfigurationData.DomainInformation.SubnetLength
            InterfaceAlias  = 'vEthernet (' + $ConfigurationData.DomainInformation.SwitchName + ')'
            AddressFamily   = 'IPv4'
            DependsOn       = @('[xDHCPClient]TestSwitchDisableDHCPv4')
        }

        cNATRule TestSwitchIPv4NAT
        {
            Name                                = 'DemoLabSwitch'
            InternalIPInterfaceAddressPrefix    = '10.1.0.0/24'
            DependsOn                           = @('[xIPAddress]TestSwitchGatewayIPv4Address')
        }

        foreach($vmNode in ($AllNodes.Where{ $_.Roles.Contains('WindowsServer') })) {
            cDeployWindowsVM "InstallWindows_$($vmNode.VMName)" {
                VHDPath                     = $vmNode.VHDPath
                ParentVHDPath               = $ConfigurationData.DomainInformation.BaseWindowsVHD
                UnattendXMLPath             = $vmNode.UnattendXMLPath

                VMName                      = $vmNode.VMName
                StartupMemory               = 2GB
                SwitchName                  = $ConfigurationData.DomainInformation.SwitchName

                ReadyRegistryKeyName        = 'SystemStatus'
                ReadyRegistryKeyValue       = 'Ready'

                ComputerName                = $vmNode.NodeName
                LocalAdministratorPassword  = $ConfigurationData.DomainInformation.LocalAdministratorPassword
                RegisteredOwner             = $ConfigurationData.DomainInformation.RegisteredOwner
                RegisteredOrganization      = $ConfigurationData.DomainInformation.RegisteredOrganization

                InterfaceName               = 'Ethernet'
                IPAddress                   = $vmNode.IPAddress
                SubnetLength                = $ConfigurationData.DomainInformation.SubnetLength
                DefaultGateway              = $ConfigurationData.DomainInformation.DefaultGateway
                DisableDHCP                 = $true
                DisableRouterDiscovery      = $true
                DNSServers                  = $vmNode.DNSServers
                DNSDomainName               = $ConfigurationData.DomainInformation.ADDomain

                TimeZone                    = 'W. Europe Standard Time'      

                InitialMOF                  = (Join-Path -Path $MOFPath -ChildPath ('{0}.mof' -f $vmNode.NodeName))
                MOFPath                     = '\Windows\Panther\MOF'
                DependsOn                   = @('[xIPAddress]TestSwitchGatewayIPv4Address')
            }
        }
    }

    Node ($AllNodes.Where{$_.Roles.Contains('PrimaryAD')}.NodeName) {
        WindowsFeature ActiveDirectoryServices
        {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }

        xADDomain InstallActiveDirectoryFeature {
            DomainName = $ConfigurationData.DomainInformation.ADDomain
            DomainAdministratorCredential = $ConfigurationData.DomainInformation.DomainAdministratorCredential
            SafeModeAdministratorPassword = $ConfigurationData.DomainInformation.SafeModeAdministratorPassword
            DomainNetBIOSName = $ConfigurationData.DomainInformation.DomainNetBIOSName
            DependsOn = @('[WindowsFeature]ActiveDirectoryServices')
        }
    }

    Node ($AllNodes.Where{$_.Roles.Contains('RootCA')}.NodeName) {
        xWaitForADDomain WaitForAD {
            DomainName = $ConfigurationData.DomainInformation.ADDomain            
        }

        xComputer ComputerSettings {
            Name = $Node.NodeName
            DomainName = $ConfigurationData.DomainInformation.ADDomain
            Credential = $ConfigurationData.DomainInformation.DomainAdministratorCredential
            DependsOn = @('[xWaitForADDomain]WaitForAD')
        }

        WindowsFeature ADCS-Cert-Authority
        {
            Ensure = 'Present'
            Name = 'ADCS-Cert-Authority'
            DependsOn = @('[xComputer]ComputerSettings')
        }

        xADCSCertificationAuthority InstallRootCA
        {
            Ensure = 'Present'
            Credential = $ConfigurationData.DomainInformation.DomainAdministratorCredential
            CAType = 'EnterpriseRootCA'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'
        }

        WindowsFeature ADCS-Web-Enrollment
        {
            Ensure = 'Present'
            Name = 'ADCS-Web-Enrollment'
            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'
        }
    }
}
