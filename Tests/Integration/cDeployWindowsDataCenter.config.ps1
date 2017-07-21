Configuration cDeployWindowsDataCenter_Config {
    param(
        [string[]]$ComputerName="localhost",
        [string]$MOFPath
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy
    Import-DscResource -ModuleName xAdcsDeployment
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $ComputerName
    {
        foreach($vmNode in ($AllNodes.Where{ $_.Roles.Contains('WindowsServer') })) {
            cDeployWindowsVM "InstallWindows_$($vmNode.VMName)" {
                VHDPath                     = $vmNode.VHDPath
                ParentVHDPath               = $ConfigurationData.DomainInformation.BaseWindowsVHD
                UnattendXMLPath             = $vmNode.UnattendXMLPath

                VMName                      = $vmNode.VMName
                StartupMemory               = 512MB
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

                InitialMOF                  = (Join-Path -Path $MOFPath -ChildPath ('{0}.mof' -f $vmNode.NodeName))
                MOFPath                     = '\Windows\Panther\MOF'
            }
        }
    }

    Node ($AllNodes.Where{$_.Roles.Contains('PrimaryAD')}.NodeName) {
        WindowsFeature ActiveDirectoryServices
        {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
        }

        xADDomain InstalActiveDirectoryFeature {
            DomainName = $ConfigurationData.DomainInformation.ADDomain
            DomainAdministratorCredential = $ConfigurationData.DomainInformation.DomainAdministratorCredential
            SafeModeAdministratorPassword = $ConfigurationData.DomainInformation.SafeModeAdministratorPassword
            DomainNetBIOSName = $ConfigurationData.DomainInformation.DomainNetBIOSName
            DependsOn = @('[WindowsFeature]ActiveDirectoryServices')
        }
    }

    Node ($AllNodes.Where{$_.Roles.Contains('RootCA')}.NodeName) {
#        windowsfeature adcs-cert-authority
#        {
#            ensure = 'present'
#            name = 'adcs-cert-authority'
#        }
#
        xADCSCertificationAuthority InstallRootCA
        {
            Ensure = 'Present'
            Credential = $ConfigurationData.DomainInformation.DomainAdministratorCredential
            CAType = 'EnterpriseRootCA'
#            DependsOn = '[WindowsFeature]ADCS-Cert-Authority'
        }

        # WindowsFeature ADCS-Web-Enrollment
        # {
        #     Ensure = 'Present'
        #     Name = 'ADCS-Web-Enrollment'
        #     DependsOn = '[WindowsFeature]ADCS-Cert-Authority'
        # }
    }
}
