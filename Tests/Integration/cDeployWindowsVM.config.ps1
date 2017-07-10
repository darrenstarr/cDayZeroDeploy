Configuration cDeployWindowsVM_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {

        cDeployWindowsVM BasicTest {
            VMName = $node.VMName
            VHDPath = $node.VHDPath
            ParentVHDPath = $node.ParentVHDPath
            UnattendXMLPath = $node.UnattendXMLPath
            
            LocalAdministratorPassword = 'Minions8675309'
            RegisteredOwner = 'Bob'
            RegisteredOrganization = 'Minions will take over Inc.'
            ReadyRegistryKeyName = 'SystemStatus'
            ReadyRegistryKeyValue = 'Ready'
        }
    }
}
