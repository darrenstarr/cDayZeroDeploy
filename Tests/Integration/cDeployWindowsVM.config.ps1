Configuration cDeployWindowsVM_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

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
