Configuration cVHDFileSystem_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDifferencingVHD
    Import-DscResource -ModuleName cVHDFileSystem

    node $ComputerName {
        cDifferencingVHD BasicTest {
            VHDPath = $Node.VHDPath
            ParentVHDPath = $Node.ParentVHDPath
        }

        cVHDFileSystem BasicTest {
            VHDPath = $Node.VHDPath
            ItemList = @(
                ($Node.TestFile), '\teapot.txt'
            )
            DependsOn = @('[cDifferencingVHD]BasicTest')
        }
    }
}
