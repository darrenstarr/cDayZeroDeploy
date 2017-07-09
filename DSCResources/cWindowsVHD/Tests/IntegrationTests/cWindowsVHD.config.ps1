Configuration cWindowsVHD_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cWindowsVHD

    node $ComputerName {
        cWindowsVHD BasicTest {
            VHDPath = $Node.VHDPath
            ISOPath = $Node.ISOPath
#            Edition = 'SERVERDATACENTERCORE'
#            MaximumSizeBytes = 100GB
        }
    }
}
