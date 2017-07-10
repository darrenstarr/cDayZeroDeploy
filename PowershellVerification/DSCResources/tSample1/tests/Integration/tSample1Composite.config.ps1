Configuration tSample1Composite_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName 'tSample1'

    node $ComputerName {
        tSample1Composite BasicTest {
            Name = 'Bob'
        }
    }
}
