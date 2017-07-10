[DSCResource()]
class tSample1
{
    [DscProperty(Key)]
    [string] $Name

    [DscProperty()]
    [string] $OptionalProperty

    [tSample1] Get() {
        $result = [tSample1]::new()

        return $result
    }

    [bool] Test() {
        Write-Verbose -Message ('Testing Name... it should not be null')
        if ($null -eq $this.Name) {
            throw [System.ArgumentNullException]::new(
                'Argument is null and should not be',
                'Name'
            )
        }

        Write-Verbose -Message ('Name is not null, name = [' + $this.Name + '] - OK')

        Write-Verbose -Message ('Testing OptionalProperty... it should be $null')

        if ($null -eq $this.OptionalProperty) {
            Write-Verbose ('OptionalProperty is null as it should be!!!')
            return $true
        }

        Write-Error -Message ('$OptionalProperty.Length = ' + $this.OptionalProperty.Length)

        throw [System.ArgumentException]::new(
            'THIS SHOULD NOT HAPPEN, Value is not null',
            'OptionalProperty'
        )

        return $false
    }

    [void] Set() {

    }
}