Configuration cNATRule_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        LocalConfigurationManager
        {
            DebugMode = 'ForceModuleImport'
        }

        cNATRule BasicTest {
            Name = $Node.RuleName
            Ensure = 'Present'
            Active = $true
            InternalIPInterfaceAddressPrefix = $node.InternalIPInterfaceAddressPrefix
        }
    }
}
