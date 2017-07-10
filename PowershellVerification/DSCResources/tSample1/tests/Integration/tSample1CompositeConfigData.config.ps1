Configuration tSample1CompositeConfigData_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName 'tSample1'

    node $ComputerName {
        Script ProveConfigDataOk {
            GetScript = {
                return @{}
            }
            SetScript = {

            }
            TestScript = {
                if ($null -eq $using:Node.Name) {
                    throw [System.ArgumentException]::new(
                        '$Node.Name is null in tSample1CompositeConfigData_Config',
                        'Name'
                    )
                }

                Write-Verbose -Message ('$Node.Name is [' + $using:Node.Name + '] in tSample1CompositeConfigData_Config')

                if ($null -ne $using:Node.OptionalProperty) {
                    throw [System.ArgumentException]::new(
                        '$Node.OptionalProperty is not null [' +$using:Node.OptionalProperty + '] in tSample1CompositeConfigData_Config',
                        'OptionalProperty'
                    )
                }

                Write-Verbose -Message ('$Node.OptionalProperty is null in tSample1CompositeConfigData_Config')

                return $true
            }
        }


        tSample1Composite BasicTest {
            Name = $Node.Name
            OptionalProperty = $Node.OptionalProperty
            DependsOn = @('[Script]ProveConfigDataOk')
        }
    }
}
