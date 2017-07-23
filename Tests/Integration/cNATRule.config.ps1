Configuration cNATRule_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cNATRule BasicTest {
            Name = $Node.RuleName
            Ensure = 'Present'
            Active = $true
            InternalIPInterfaceAddressPrefix = $node.InternalIPInterfaceAddressPrefix
        }
    }
}
