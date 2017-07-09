Configuration cDifferencingVHD_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDifferencingVHD

    node $ComputerName {
        cDifferencingVHD BasicTest {
            VHDPath = $Node.VHDPath
            ParentVHDPath = $Node.ParentVHDPath
        }
    }
}
