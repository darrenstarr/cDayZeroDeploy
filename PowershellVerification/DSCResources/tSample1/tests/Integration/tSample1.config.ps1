Configuration tSample1_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName tSample1

    node $ComputerName {
        tSample1 BasicTest {
            Name = 'Bob'
        }
    }
}
