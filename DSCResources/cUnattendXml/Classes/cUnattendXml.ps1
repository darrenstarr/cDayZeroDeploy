<#
This code is written and maintained by Darren R. Starr from Nocturnal Holdings AS Norway.

License :

Copyright (c) 2016 Nocturnal Holdings AS Norway

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

<# DependsOn './UnattendXml.ps1' #>

[DscResource()]
class cUnattendXml 
{
    [DscProperty(Key)]
    [string] $Path

    [DscProperty()]
    [string] $ComputerName

    [DscProperty()]
    [string] $RegisteredOwner

    [DscProperty()]
    [string] $RegisteredOrganization

    [DscProperty()]
    [string] $TimeZone

    [DscProperty()]
    [string] $LocalAdministratorPassword

    [DscProperty()]
	[string] $InterfaceName = 'Ethernet'

    [DscProperty()]
	[bool] $DisableDHCP = $false

    [DscProperty()]
	[bool] $DisableRouterDiscovery = $false

    [DscProperty()]
	[string] $IPAddress

    [DscProperty()]
	[string] $SubnetLength

    [DscProperty()]
	[string] $DefaultGateway

    [DscProperty()]
	[string[]] $DNSServers

    [DscProperty()]
	[string] $DNSDomainName

    [DscProperty()]
	[int] $InterfaceMetric = 10

    [DscProperty()]
	[string] $ReadyRegistryKeyName = 'Status'

    [DscProperty()]
	[string] $ReadyRegistryKeyValue = 'Ready'

    [cUnattendXml]Get() {
        return $this
    }

    [void]Set() {
        [string]$unattendText = $this.CreateUnattendXml()

        try {
            [IO.File]::WriteAllText($this.Path, $unattendText)
            #Set-Content -Path $unattendXmlFilePath -Value $text -Force
        } catch {
            Write-Error -Message ('Failed to set content of ' + $this.Path + ' - message - ' + $_.Exception.Message)
        }
    }

    [bool]Test() {
        if (-not (Test-Path -Path $this.Path)) {
            Write-Verbose -Message ('Unattend file "' + $this.Path + '" does not exist')
            return $false
        }

        [string]$unattendText = $this.CreateUnattendXml()

        $currentUnattendXml = Get-Content -Path $this.Path -Raw

        return $unattendText -eq $currentUnattendXml
    }

    hidden [string] CreateUnattendXml() {

        $unattend = [UnattendXml]::new()

        if($null -ne $this.ComputerName) {
            $unattend.SetComputerName($this.ComputerName)
        }

        if($null -ne $this.RegisteredOwner) {
            $unattend.SetRegisteredOwner($this.RegisteredOwner)
        }

        if($null -ne $this.RegisteredOrganization) {
            $unattend.SetRegisteredOrganization($this.RegisteredOrganization)
        }

        if($null -ne $this.TimeZone) {
            $unattend.SetTimeZone($this.TimeZone)
        }

        if($null -ne $this.LocalAdministratorPassword) {
            $unattend.SetAdministratorPassword($this.LocalAdministratorPassword)
            $unattend.SetSkipMachineOOBE($true)
            $unattend.SetHideEULA($true)
        }

        if($this.DisableDHCP) {
            if($null -eq $this.InterfaceName) {
                throw [System.ArgumentNullException]::new(
                    'If configuring DHCP settings, the interface name must be provided',
                    'InterfaceName'
                )
            }

            if($this.DisableRouterDiscovery -eq $false) {
                throw [System.ArgumentException]::new(
                    'You should disable router discovery on interfaces where DHCP is disabled',
                    'IPAddress'
                )
            }

            $unattend.SetDHCPEnabled($this.InterfaceName, $false)
        }

        if($this.DisableRouterDiscovery) {
            if($null -eq $this.InterfaceName) {
                throw [System.ArgumentNullException]::new(
                    'If configuring DHCP settings, the interface name must be provided',
                    'InterfaceName'
                )
            }
            
            $unattend.SetRouterDiscoveryEnabled($this.InterfaceName, $false)
        }

        if(
            ($null -ne $this.IPAddress) -or
            ($null -ne $this.SubnetLength) -or
            ($null -ne $this.DefaultGateway)
          ) {
            if(
                ($null -eq $this.IPAddress) -or
                ($null -eq $this.SubnetLength) -or
                ($null -eq $this.DefaultGateway)
            ) {
                throw [System.ArgumentNullException]::new(
                    'If IP Address, Subnet length or Default Gateway are set, then all three must be set',
                    'IPAddress'
                )
            }

            if($null -eq $this.InterfaceName) {
                throw [System.ArgumentNullException]::new(
                    'If configuring IP settings, the interface name must be provided',
                    'InterfaceName'
                )
            }

            if($this.DisableDHCP -eq $false) {
                throw [System.ArgumentException]::new(
                    'You should disable DHCP on interfaces where static addresses are being set',
                    'IPAddress'
                )
            }

            $unattend.SetInterfaceIPAddress(
                    $this.InterfaceName, 
                    $this.IPAddress,
                    $this.SubnetLength, 
                    $this.DefaultGateway
                )
        }

        if(($null -ne $this.DNSServers) -or ($null -ne $this.DNSDomainName)) {
            if(($null -eq $this.DNSServers) -or ($null -eq $this.DNSDomainName)) {
                # TODO : Consider allowing DNS servers to be set without a domain name
                throw [System.ArgumentNullException]::new(
                    'If configuring DNS settings, both the server and the domain name should be set',
                    'InterfaceName'
                )
            }
            if($null -eq $this.InterfaceName) {
                throw [System.ArgumentNullException]::new(
                    'If configuring DNS settings, the interface name must be provided',
                    'InterfaceName'
                )
            }

            $unattend.SetDNSInterfaceSettings($this.InterfaceName, $this.DNSServers, $this.DNSDomainName)
        }

        if($null -ne $this.InterfaceMetric) {
            if($null -eq $this.InterfaceName) {
                throw [System.ArgumentNullException]::new(
                    'If configuring interface metric settings, the interface name must be provided',
                    'InterfaceName'
                )
            }
            $unattend.SetInterfaceIPv4Metric($this.InterfaceName, 10)
        }

        if(($null -ne $this.ReadyRegistryKeyName) -or ($null -ne $this.ReadyRegistryKeyValue)) {
            if(($null -eq $this.ReadyRegistryKeyName) -or ($null -eq $this.ReadyRegistryKeyValue)) {
                throw [System.ArgumentNullException]::new(
                    'If configuring a registry key name and value to be set once unattend.xml is mostly done, then both must be defined',
                    'ReadyRegistryKeyName'
                )
            }

            if ($null -eq $this.LocalAdministratorPassword) {
                throw [System.ArgumentNullException]::new(
                    'If configuring a registry key name and value, the local adminsitrator password must be set to allow an autologon session',
                    'LocalAdministratorPassword'
                )
            }

            $unattend.SetAutoLogon('Administrator', $this.LocalAdministratorPassword, 1)
            $unattend.AddFirstLogonCommand(
                    'Inform Host Of Ready State', 
                    '%windir%\system32\reg.exe add "HKLM\Software\Microsoft\Virtual Machine\Guest" /V ' + 
                    $this.ReadyRegistryKeyName + 
                    ' /T REG_SZ /D ' +
                    $this.ReadyRegistryKeyValue
                )
        }

        return $unattend.ToXml().Trim()
    }
}
