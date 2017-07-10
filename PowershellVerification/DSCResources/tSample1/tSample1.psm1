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
        Write-Verbose -Message ('Testing OptionalProperty... it should be $null')

        if ($null -eq $this.OptionalProperty) {
            Write-Verbose ('OptionalProperty is null as it should be!!!')
            return $true
        }

        throw [System.ArgumentException]::new(
            'THIS SHOULD NOT HAPPEN, Value is not null',
            'OptionalProperty'
        )

        return $false
    }

    [void] Set() {

    }
}