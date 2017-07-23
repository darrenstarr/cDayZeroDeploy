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

enum PresentState {
    Present
    Absent
}

<# 
    .SYNOPSIS
        A resource for managing NAT rules for IPv4 networking
#>
[DscResource()]
class cNATRule
{
    [DscProperty(Key)]    
    [string] $Name

    [DscProperty()]
    [PresentState] $Ensure = [PresentState]::Present

    [DscProperty()]
    [bool] $Active = $true

    [DscProperty()]
    [string] $InternalIPInterfaceAddressPrefix

    [cNATRule] Get()
    {
        $result = [cNATRule] @{
            Name = $this.Name
        }

        $natRule = Get-NetNat -Name $this.Name

        if($null -eq $natRule) {
            $result.Present = [PresentState]::Absent
        } else {
            $result.Present = [PresentState]::Present
            $result.Active = $natRule.Active
            $result.InternalIPInterfaceAddressPrefix = $natRule.InternalIPInterfaceAddressPrefix
        }

        return $result
    }

    [void] Set()
    {
        Write-Verbose -Message ('Getting existing NAT rule if present')
        $natRule = Get-NetNat -Name $this.Name
        
        if($this.Present -eq [PresentState]::Absent) {
            if($null -ne $natRule) {
                Write-Verbose -Message ('Removing NAT rule')
                $natRule | Remove-NetNat -Confirm:$false
            } else {
                Write-Verbose -Message ('Nothing to do')
            }
        } else {
            if($null -ne $natRule) {
                Write-Verbose -Message ('Creating new NAT rule')
                $parameters = @{
                    Name = $this.Name
                    InternalIPInterfaceAddressPrefix = $this.InternalIPInterfaceAddressPrefix
                    Active = $this.Active
                }

                New-NetNat @parameters
            } else {
                Write-Verbose -Message ('Updating existing NAT rule')
                $parameters = @{
                    InternalIPInterfaceAddressPrefix = $this.InternalIPInterfaceAddressPrefix
                    Active = $this.Active
                }

                Set-NetNat = @parameters
            }
        } 

        if(-not $this.Test()) {
            throw [Exception]::new(
                'Failed for unknown reason'
            )
        }
    }

    [bool] Test()
    {
        $currentState = $this.Get()

        if ($this.Present -ne $currentState.Present) {
            return $false
        }

        if($this.Present -eq [PresentState]::Present) {
            return (
                ($this.InternalIPInterfaceAddressPrefix -eq $currentState.InternalIPInterfaceAddressPrefix) -and
                ($this.Active -eq $currentState.Active)
            )
        }

        return $true 
    }
}
