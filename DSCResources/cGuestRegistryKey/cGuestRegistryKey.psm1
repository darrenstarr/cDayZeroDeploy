<#
This code is written and maintained by Darren R. Starr from Conscia Norway AS.

License :

Copyright (c) 2017 Conscia Norway AS

Permission is hereby granted, free of charge, to any person obtaining a 
copy of this software and associated documentation files (the "Software"), 
to deal in the Software without restriction, including without limitation 
the rights to use, copy, modify, merge, publish, distribute, sublicense, 
and/or sell copies of the Software, and to permit persons to whom the Software 
is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in 
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

<# 
    .SYNOPSIS
        A resource for monitoring guest virtual machines in Hyper-V to wait for registry values to change
#>
[DscResource()]
class cGuestRegistryKey 
{
    [DscProperty(Key)]
    [string] $VMName

    [DSCProperty(Mandatory)]
    [string] $KeyName

    [DSCProperty(Mandatory)]
    [string] $KeyValue

    [DSCProperty()]
    [int] $TimeOutSeconds = 180

    [DSCProperty()]
    [int] $PollIntervalSeconds = 1
    
    <#
        .SYNOPSIS
            Resource Get
    #>
    [cGuestRegistryKey] Get()
    {
        $result = [cGuestRegistryKey]::new()
        $result.VMName = $this.VMName
        $result.KeyName = $this.KeyName
        $result.KeyValue = $this.KeyValue
        $result.TimeOutSeconds = $this.TimeOutSeconds
        $result.PollIntervalSeconds = $this.PollIntervalSeconds

        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        Write-Verbose -Message ('VMName = ' + $this.VMName)
        Write-Verbose -Message ('KeyName = ' + $this.KeyName)
        Write-Verbose -Message ('KeyValue = ' + $this.KeyValue)
        Write-Verbose -Message ('TimeOutSeconds = ' + $this.TimeOutSeconds.ToString())
        Write-Verbose -Message ('PollIntervalSeconds = ' + $this.PollIntervalSeconds.ToString())

        $startTime = [DateTime]::Now
        $timeDifference = (([DateTime]::Now).Subtract($startTime)).TotalSeconds
        $vm = $null

        # TODO: Hackish workaround because I can't seem to pass $this to Get-WMIObject -Filter
        $virtualMachineName = $this.VMName

        Write-Verbose -Message ('Getting handle to virtual machine [' + $this.VMName + ']')
        while(($null -eq $vm) -and ($timeDifference -lt $this.TimeOutSeconds))
        {
            try {
                Write-Debug -Message ('Poll')
                $vm = Get-WmiObject -Namespace root\virtualization\v2 -Class Msvm_ComputerSystem -Filter "ElementName = '$virtualMachineName'"
            } catch {
                Start-Sleep -Seconds $this.PollIntervalSeconds
                $timeDifference = (([DateTime]::Now).Subtract($startTime)).TotalSeconds
            }

            if ($null -ne $vm) {
                break
            }
        }

        if ($null -eq $vm) {
            return $false
        }
 
        # TODO: Hackish workaround because I can't seem to pass $this to Get-WMIObject -Filter
        $registryKeyName = $this.KeyName

        $timeDifference = (([DateTime]::Now).Subtract($startTime)).TotalSeconds
        Write-Verbose -Message ('Obtained handle to virtual machine, waiting for value (timeout in ' + ($this.TimeOutSeconds - $timeDifference) + ' seconds)')
        $guestKeyValue = $null   
        while(($guestKeyValue -ne $this.KeyValue) -and ($timeDifference -lt $this.TimeOutSeconds)) {
            $exchangeItems = $vm.GetRelated("Msvm_KvpExchangeComponent").GuestExchangeItems 
            if ($null -ne $exchangeItems) {
                Write-Debug -Message ('Found ' + $exchangeItems.Count + ' items')
                foreach($exchangeItem in $exchangeItems) {
                    $GuestExchangeItemXml = ([XML]$exchangeItem).SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Name']/VALUE[child::text() = '$registryKeyName']")
            
                    if ($GuestExchangeItemXml -ne $null) { 
                        $guestKeyValue = ($GuestExchangeItemXml.SelectSingleNode("/INSTANCE/PROPERTY[@NAME='Data']/VALUE/child::text()").Value)
                        if ($guestKeyValue -eq $this.KeyValue) {
                            break
                        }
                    } 
                }
            } 

            if ($guestKeyValue -ne $this.KeyValue) {
                Write-Debug -Message ('Sleep')
                Start-Sleep -Seconds $this.PollIntervalSeconds
                $timeDifference = (([DateTime]::Now).Subtract($startTime)).TotalSeconds
            }
        }

        if ($guestKeyValue -ne $this.KeyValue) {
            return $false
        }

        Write-Verbose -Message ('Registry key ' + $this.KeyName + ' = ' + $guestKeyValue)

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        throw [System.Exception]::new(
            'cGuestRegistryKey is a monitoring (test only) resource and should not be used for setting state'
        )
    }
}
