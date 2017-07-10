Configuration cWindowsVHD_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cWindowsVHD BasicTest {
            VHDPath = $Node.VHDPath
            ISOPath = $Node.ISOPath
#            Edition = 'SERVERDATACENTERCORE'
#            MaximumSizeBytes = 100GB
        }
    }
}
