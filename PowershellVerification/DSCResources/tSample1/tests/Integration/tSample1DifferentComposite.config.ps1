Configuration tSample1DifferentComposite_config
{
    Param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]        
        [string] $Name,

        [Parameter()]
        [string] $OptionalProperty = $null,

        [Parameter()]
        [int] $OtherOptionalProperty = $null
    )

    Import-DscResource -Name 'tSample1'
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Script ProveNameIsNotNull {
        GetScript = {
            return @{}
        }
        SetScript = {

        }
        TestScript = {
            if ($null -eq $using:Name) {
                Write-Verbose -Message ('$Name is null and should not be here')
                return $true
                # throw [System.ArgumentException]::new(
                #     '$Name is null and should not be here',
                #     'Name'
                # )
            }

            Write-Verbose -Message ('$Name is [' + $using:Name + ']')
            return $true
        }
    }

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
                Write-Verbose -Message ('$OptionalProperty.length = ' + $using:OptionalProperty.Length)
                Write-Verbose -Message ('$OptionalProperty is non-null here and should be null!!!!')
                return $true
                # throw [System.ArgumentException]::new(
                #     '$OptionalProperty is not null [' + $using:OptionalProperty + '] in tSample1Composite',
                #     'OptionalProperty'
                # )
            }
        }
        DependsOn = @('[Script]ProveNameIsNotNull')
    }

    Script ProveIntegerOptionalPropertyIsNull {
        GetScript = {
            return @{}
        }
        SetScript = {

        }
        TestScript = {            
            if ($null -eq $using:OtherOptionalProperty) {
                Write-Verbose -Message '$OtherOptionalProperty is null in tSample1Composite'
                return $true
            } else {
                Write-Verbose -Message ('$OtherOptionalProperty = ' + ($using:OtherOptionalProperty).ToString())
                Write-Verbose -Message ('$OtherOptionalProperty is non-null here and should be null!!!!')
                return $true
            }
        }
        DependsOn = @('[Script]ProveNameIsNotNull')
    }

    tSample1 TestBoom {
        Name = $Name
        OptionalProperty = $OptionalProperty

        DependsOn = @('[Script]ProveOptionalPropertyIsNull', '[Script]ProveIntegerOptionalPropertyIsNull')
    }
}

