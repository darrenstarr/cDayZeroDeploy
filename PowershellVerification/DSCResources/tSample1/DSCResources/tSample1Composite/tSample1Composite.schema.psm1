Configuration tSample1Composite
{
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]        
        [string] $Name,

        [Parameter()]
        [string] $OptionalProperty
    )

    Import-DscResource -Name 'tSample1'
    Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

    Script ProveOptionalPropertyIsNull {
        GetScript = {
            return @{}
        }
        SetScript = {

        }
        TestScript = {
            if ($null -eq $using:OptionalProperty) {
                Write-Verbose -Message '$OptionalProperty is null in tSample1Composite'
                return $true
            } else {
                Write-Error -Message ('$OptionalProperty.length = ' + $using:OptionalProperty.Length)
                throw [System.ArgumentException]::new(
                    '$OptionalProperty is not null [' + $using:OptionalProperty + '] in tSample1Composite',
                    'OptionalProperty'
                )
            }
        }
    }

    tSample1 TestBoom {
        Name = $Name
        OptionalProperty = $OptionalProperty

        DependsOn = @('[Script]ProveOptionalPropertyIsNull')
    }
}

