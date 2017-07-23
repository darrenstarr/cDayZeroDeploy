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
	[int] $SubnetLength = 0

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

    [DSCProperty()]
    [bool] $ConfigurePushLCM = $false

    [DscProperty()]
    [bool] $EnableLocalWindowsRemoteManagement = $false

    [DscProperty()]
    [string] $MOFPath

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

    hidden static [string]$PushLCMConfig = 
@'
[DSCLocalConfigurationManager()]
Configuration LCMConfig
{
    Node localhost { 
        Settings {
            RefreshMode='Push'
            RebootNodeIfNeeded=$true
            ActionAfterReboot='ContinueConfiguration'
        }
    }
}
LCMConfig -OutputPath 'c:\Windows\Panther\lcmmof'
Set-DscLocalConfigurationManager -Path 'c:\Windows\Panther\lcmmof' -ComputerName 'localhost'
'@ 

    hidden [string] CreateUnattendXml() {

        $unattend = [UnattendXml]::new()
        
        if(-not [String]::IsNullOrEmpty($this.ComputerName)) {
            $unattend.SetComputerName($this.ComputerName)
        }

        if(-not [String]::IsNullOrEmpty($this.RegisteredOwner)) {
            $unattend.SetRegisteredOwner($this.RegisteredOwner)
        }

        if(-not [String]::IsNullOrEmpty($this.RegisteredOrganization)) {
            $unattend.SetRegisteredOrganization($this.RegisteredOrganization)
        }

        if(-not [String]::IsNullOrEmpty($this.TimeZone)) {
            $unattend.SetTimeZone($this.TimeZone)
        }

        if(-not [String]::IsNullOrEmpty($this.LocalAdministratorPassword)) {
            $unattend.SetAdministratorPassword($this.LocalAdministratorPassword)
            $unattend.SetSkipMachineOOBE($true)
            $unattend.SetHideEULA($true)
        }

        if($this.DisableDHCP) {
            if([String]::IsNullOrEmpty($this.InterfaceName)) {
                throw [System.ArgumentException]::new(
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
            if([String]::IsNullOrEmpty($this.InterfaceName)) {
                throw [System.ArgumentException]::new(
                    'If configuring DHCP settings, the interface name must be provided',
                    'InterfaceName'
                )
            }
            
            $unattend.SetRouterDiscoveryEnabled($this.InterfaceName, $false)
        }

        if(
            (-not [String]::IsNullOrEmpty($this.IPAddress)) -or
            ($this.SubnetLength -ne 0) -or
            (-not [String]::IsNullOrEmpty($this.DefaultGateway))
          ) {
            if(
                [String]::IsNullOrEmpty($this.IPAddress) -or
                ($this.SubnetLength -eq 0) -or
                [String]::IsNullOrEmpty($this.DefaultGateway)
            ) {
                #Write-Verbose -Message ('IPAddress null? = ' + [String]::IsNullOrEmpty($this.IPAddress).ToString())
                #Write-Verbose -Message ('IPAddress = ' + $this.IPAddress)
                #Write-Verbose -Message ('Default gateway null? = ' + [String]::IsNullOrEmpty($this.DefaultGateway).ToString())
                #Write-Verbose -Message ('Default gateway = ' + $this.DefaultGateway)
                #Write-Verbose -Message ('SubnetLength = ' + $this.SubnetLength)

                throw [System.ArgumentException]::new(
                    'If IP Address, Subnet length or Default Gateway are set, then all three must be set',
                    'IPAddress'
                )
            }

            if([String]::IsNullOrEmpty($this.InterfaceName)) {
                throw [System.ArgumentException]::new(
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

        if((-not [String]::IsNullOrEmpty($this.DNSServers)) -or (-not [String]::IsNullOrEmpty($this.DNSDomainName))) {
            if([String]::IsNullOrEmpty($this.DNSServers) -or [String]::IsNullOrEmpty($this.DNSDomainName)) {
                # TODO : Consider allowing DNS servers to be set without a domain name
                throw [System.ArgumentException]::new(
                    'If configuring DNS settings, both the server and the domain name should be set',
                    'InterfaceName'
                )
            }
            if([String]::IsNullOrEmpty($this.InterfaceName)) {
                throw [System.ArgumentException]::new(
                    'If configuring DNS settings, the interface name must be provided',
                    'InterfaceName'
                )
            }

            $unattend.SetDNSInterfaceSettings($this.InterfaceName, $this.DNSServers, $this.DNSDomainName)
        }

        if($this.InterfaceMetric -ne -1) {
            if([String]::IsNullOrEmpty($this.InterfaceName)) {
                throw [System.ArgumentException]::new(
                    'If configuring interface metric settings, the interface name must be provided',
                    'InterfaceName'
                )
            }
            $unattend.SetInterfaceIPv4Metric($this.InterfaceName, 10)
        }

        [bool]$SetAutoLogon = $false

        if($this.EnableLocalWindowsRemoteManagement) {
            $unattend.AddFirstLogonCommand(
                'Enable local Windows Remote Management',
                '%windir%\system32\winrm.cmd quickconfig /quiet'
            )
            $SetAutoLogon = $true
        }

        if($this.ConfigurePushLCM) {
            if(-not $this.EnableLocalWindowsRemoteManagement) {
                throw [System.ArgumentException]::new(
                    'EnableLocalWindowsRemoteManagement is required to use ConfigurePushLCM',
                    'ConfigurePushLCM'
                )
            }            
            $unattend.AddFirstLogonCommand(
                'Configure DSC Push Mode',
                ("%windir%\System32\WindowsPowerShell\v1.0\powershell.exe " +
                    'C:\Windows\Panther\Scripts\LCMSetPushLocal.ps1')
                    # "-nologo -encodedCommand "+ 
                    # [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes([cUnattendXml]::PushLCMConfig)))
            )

            $SetAutoLogon = $true
        }

        if(-not [string]::IsNullOrEmpty($this.MOFPath)) {
            if(-not $this.EnableLocalWindowsRemoteManagement) {
                throw [System.ArgumentException]::new(
                    'EnableLocalWindowsRemoteManagement is required to use MOFPath',
                    'MOFPath'
                )
            }

            $unattend.AddFirstLogonCommand(
                'Start DSC Configuration',
                ("%windir%\System32\WindowsPowerShell\v1.0\powershell.exe -nologo -command `"Start-DSCConfiguration -Path 'C:" + $this.MOFPath + "' -verbose -wait -force `"")
            )

            $SetAutoLogon = $true
        }

        if((-not [String]::IsNullOrEmpty($this.ReadyRegistryKeyName)) -or (-not [String]::IsNullOrEmpty($this.ReadyRegistryKeyValue))) {
            if([String]::IsNullOrEmpty($this.ReadyRegistryKeyName) -or [String]::IsNullOrEmpty($this.ReadyRegistryKeyValue)) {
                throw [System.ArgumentException]::new(
                    'If configuring a registry key name and value to be set once unattend.xml is mostly done, then both must be defined',
                    'ReadyRegistryKeyName'
                )
            }

            $unattend.AddFirstLogonCommand(
                'Inform Host Of Ready State', 
                '%windir%\system32\reg.exe add "HKLM\Software\Microsoft\Virtual Machine\Guest" /V ' + 
                $this.ReadyRegistryKeyName + 
                ' /T REG_SZ /D ' +
                $this.ReadyRegistryKeyValue
            )
        }

        if($SetAutoLogon) {
            if ([String]::IsNullOrEmpty($this.LocalAdministratorPassword)) {
                throw [System.ArgumentException]::new(
                    'When configuring features (MOFPath, EnableLocalWindowsRemoteManagement, RegistryKeys), it is necessary to supply a local administrator password',
                    'LocalAdministratorPassword'
                )
            }

            $unattend.SetAutoLogon('Administrator', $this.LocalAdministratorPassword, 1)
        }

        return $unattend.ToXml().Trim()
    }
}
