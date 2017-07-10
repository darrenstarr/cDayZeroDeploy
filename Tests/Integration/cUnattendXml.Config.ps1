Configuration cUnattendXml_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cUnattendXml BasicTest {
            Path = $Node.TestFilePath
            LocalAdministratorPassword = 'Minions12345'
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