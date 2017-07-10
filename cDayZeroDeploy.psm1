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

<# 
    .SYNOPSIS
        Values of WillReboot for the section RunSynchronousCommand within unattend.xml

    .LINK
        https://technet.microsoft.com/en-us/library/cc722061(v=ws.10).aspx
#>
enum EnumWillReboot {
    Always
    OnRequest 
    Never
}

<#
    .SYNOPSIS
        Valid values for authentication types for remote desktop login

    .LINK
        https://technet.microsoft.com/en-us/library/cc722192(v=ws.10).aspx
#>
enum EnumRdpAuthentication {
    NetworkLevel = 0
    UserLevel = 1
}

<#
    .SYNOPSIS 
        An API for generating Unattend.xml files for Windows Server 2016

    .DESCRIPTION
        UnattendXML is a class designed for generating "properly formatted" XML
        that meets the schema requirements of Microsoft's Windows Server 2016 unattend.xml
        format.

        The code is written as a flat class instead of a serialized data structure as the 
        excessive additional complexity one would expect from serialization would be 
        overwhelming to implement.

        Given the current state of the class, it is only implemented as much as necessary
        to perform the operations the author of the class needed. As comments, needs and 
        suggestions as well as patches increase, the functionality of the class will increase.

        The current design risks a namespace clutter and possibily even constraints due to its
        flat but easy to use nature.

    .EXAMPLE
        using module UnattendXML.psm1

        $unattend = [UnattendXml]::new()
        $unattend.SetComputerName('BobsPC')
        $unattend.SetRegisteredOwner('Bob Minion')
        $unattend.SetRegisteredOrganization('Minions Evil Empire')
        $unattend.SetTimeZone('W. Europe Standard Time')
        $unattend.SetAdministratorPassword('C1sco12345')
        $unattend.SetInterfaceIPAddress('Ethernet', '10.1.1.5', 24, '10.1.1.1')
        $unattend.SetDHCPEnabled('Ethernet', $false)
        $unattend.SetRouterDiscoveryEnabled('Ethernet', $false)
        $unattend.SetInterfaceIPv4Metric('Ethernet', 10)
        $outputXML = $unattend.ToXml()
#>
class UnattendXml 
{
    hidden [Xml]$document = (New-Object -TypeName Xml)
    hidden [System.Xml.XmlElement]$XmlUnattended

    hidden static [string] $XmlNs = 'urn:schemas-microsoft-com:unattend'
    hidden static [string] $ProcessorArchitecture='amd64'
    hidden static [string] $VersionScope='nonSxS'
    hidden static [string] $LanguageNeutral='neutral'
    hidden static [string] $WCM = 'http://schemas.microsoft.com/WMIConfig/2002/State'
    hidden static [string] $XmlSchemaInstance = 'http://www.w3.org/2001/XMLSchema-instance'

    static hidden [string] WillRebootToString([EnumWillReboot]$Value)
    {
        if($Value -eq [EnumWillReboot]::Always) { return 'Always' }
        if($Value -eq [EnumWillReboot]::Never) { return 'Never' }
        if($Value -eq [EnumWillReboot]::OnRequest) { return 'OnRequest' }
        throw 'Invalid value for WillReboot'
    }

    static hidden [string] RdpAuthenticationModeToString([EnumRdpAuthentication]$Value)
    {
        if($Value -eq [EnumRdpAuthentication]::NetworkLevel) { return 0 }
        if($Value -eq [EnumRdpAuthentication]::UserLevel) { return 1 }
        throw 'Invalid value for RDP authentication mode'
    }

    hidden [System.Xml.XmlElement] GetSettingsNode([string]$Pass)
    {
        # TODO : Should this be -eq $Pass?
        $result = $this.XmlUnattended.ChildNodes | Where-Object { $_.Name -eq 'Settings' -and $_.Attributes['pass'].'#text' -like $Pass }
        If ($result -eq $null) {
            $result = $this.document.CreateElement('settings', $this.document.DocumentElement.NamespaceURI)
            $result.SetAttribute('pass', $Pass)
            $this.XmlUnattended.AppendChild($result) | Out-Null
        } 

        return $result
    }

    hidden [System.Xml.XmlElement] GetOfflineServicingSettings()
    {
        return $this.GetSettingsNode('offlineServicing')
    }

    hidden [System.Xml.XmlElement] GetSpecializeSettings()
    {
        return $this.GetSettingsNode('specialize')
    }    

    hidden [System.Xml.XmlElement] GetOobeSystemSettings()
    {
        return $this.GetSettingsNode('oobeSystem')
    }

    hidden [System.Xml.XmlElement] GetSectionFromSettings([System.Xml.XmlElement]$XmlSettings, [string]$Name)
    {
        $result = $XmlSettings.ChildNodes | Where-Object { $_.LocalName -eq 'component' -and $_.Attributes['name'].'#text' -eq $Name }
        if ($result -eq $null)
        {
            $result = $this.document.CreateElement('component', $this.document.DocumentElement.NamespaceURI)
            $result.SetAttribute('name', $Name)
            $result.SetAttribute('processorArchitecture', [UnattendXml]::ProcessorArchitecture)
            $result.SetAttribute('publicKeyToken', '31bf3856ad364e35')
            $result.SetAttribute('language', [UnattendXml]::LanguageNeutral)
            $result.SetAttribute('versionScope', [UnattendXml]::VersionScope)
            $result.SetAttribute('xmlns:wcm', [UnattendXml]::WCM)
            $result.SetAttribute('xmlns:xsi', [UnattendXml]::XmlSchemaInstance)

            $XmlSettings.AppendChild($result) | Out-Null
        }

        return $result
    }

    hidden [System.Xml.XmlElement] GetWindowsShellSetupSection([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-Shell-Setup')
    }

    hidden [System.Xml.XmlElement] GetTerminalServicesLocalSessionManager([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-TerminalServices-LocalSessionManager')
    }

    hidden [System.Xml.XmlElement] GetTerminalServicesRdpWinStationExtensions([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-TerminalServices-RDP-WinStationExtensions')
    }

    hidden [System.Xml.XmlElement] GetWindowsTCPIPSection([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-TCPIP')
    }

    hidden [System.Xml.XmlElement] GetWindowsDNSClientSection([System.Xml.XmlElement]$XmlSettings)
    {
        return $this.GetSectionFromSettings($XmlSettings, 'Microsoft-Windows-DNS-Client')
    }

    hidden [System.Xml.XmlElement] GetTCPIPInterfaces([System.Xml.XmlElement]$XmlSettings)
    {
        $XmlComponent = $this.GetWindowsTCPIPSection($XmlSettings)
        $result = $XmlComponent.ChildNodes | Where-Object { $_.Name -eq 'Interfaces' }
        if ($result -eq $null) {
            $result = $this.document.CreateElement('Interfaces', $this.document.DocumentElement.NamespaceURI)
            $XmlComponent.AppendChild($result) | Out-Null
        }
    
        return $result
    }

    hidden [System.Xml.XmlElement] GetTCPIPInterfaceFromInterfaces([System.Xml.XmlElement]$Interfaces, [string]$Identifier)
    {
        $interfaceNodes = $Interfaces.ChildNodes | Where-Object { $_.LocalName -eq 'Interface' }
        foreach($interfaceNode in $interfaceNodes) {
            $identifierNode = $interfaceNode.ChildNodes | Where-Object { $_.LocalName -eq $Identifier }
            if ($identifierNode.InnerText -eq $IdentifierNode) {
                return $interfaceNode
            }
        }   
        
        $interfaceNode = $this.document.CreateElement('Interface', $this.document.DocumentElement.NamespaceURI)
        $interfaceNode.SetAttribute('action', [UnattendXML]::WCM, 'add')
        $Interfaces.AppendChild($interfaceNode)

        $identifierNode = $this.document.CreateElement('Identifier', $this.document.DocumentElement.NamespaceURI)
        $identifierNodeText = $this.document.CreateTextNode($Identifier)
        $identifierNode.AppendChild($identifierNodeText)
        $interfaceNode.AppendChild($identifierNode)

        return $interfaceNode
    }

    hidden [System.Xml.XmlElement] GetTCPIPInterface([System.Xml.XmlElement]$XmlSettings, [string]$Identifier)
    {
        $interfaces =$this.GetTCPIPInterfaces($XmlSettings)
        return $this.GetTCPIPInterfaceFromInterfaces($interfaces, $Identifier)
    }

    hidden [System.Xml.XmlElement] GetOrCreateChildNode([System.Xml.XmlElement]$ParentNode, [string]$LocalName)
    {
        $result = $ParentNode.ChildNodes | Where-Object { $_.LocalName -eq $LocalName }
        if ($result -eq $null) {
            $result = $this.document.CreateElement($LocalName, $this.document.DocumentElement.NamespaceURI)
            $ParentNode.AppendChild($result)
        }

        return $result
    }

    hidden [System.Xml.XmlElement] GetTCPIPv4Settings([System.Xml.XmlElement]$Interface)
    {
        return $this.GetOrCreateChildNode($Interface, 'IPv4Settings')
    }

    hidden [System.Xml.XmlElement] GetTCPIPv4Setting([System.Xml.XmlElement]$Interface, [string]$SettingName)
    {
        $settings = $this.GetTCPIPv4Settings($Interface)
        return $this.GetOrCreateChildNode($settings, $SettingName)
    }

    hidden [System.Xml.XmlElement] GetTCPIPUnicastIPAddresses([System.Xml.XmlElement]$Interface)
    {
        return $this.GetOrCreateChildNode($Interface, 'UnicastIPAddresses')
    }

    hidden [System.Xml.XmlElement] GetTCPIPUnicastIPAddress([System.Xml.XmlElement]$Interface, [string]$KeyValue)
    {
        $unicastIPAddresses = $this.GetTCPIPUnicastIPAddresses($Interface)
        $result = $unicastIPAddresses.ChildNodes | Where-Object { $_.LocalName -eq 'IpAddress' -and $_.Attributes['keyValue'].'#text' -eq $KeyValue }
        if ($result -eq $null) {
            $result = $this.document.CreateElement('IpAddress', $this.document.DocumentElement.NamespaceURI)
            $result.SetAttribute('action', [UnattendXML]::WCM, 'add')
            $result.SetAttribute('keyValue',[UnattendXML]::WCM, $KeyValue)
            $unicastIPAddresses.AppendChild($result)
        }

        return $result
    }

    hidden [System.Xml.XmlElement] GetTCPIPRoutes([System.Xml.XmlElement]$Interface)
    {
        return $this.GetOrCreateChildNode($Interface, 'Routes')
    }

    hidden [System.Xml.XmlElement] GetTCPIPRoute([System.Xml.XmlElement]$Interface, [string]$Prefix)
    {
        $routes = $this.GetTCPIPRoutes($Interface)
        
        $routeNodes = ($routes.ChildNodes | Where-Object { $_.LocalName -eq 'Route' })
        $routeIdentifier = '0'

        # TODO : Better handling of when there's a missing identifier or prefix node
        foreach($routeNode in $routeNodes) {
            $prefixNode = ($routeNode.ChildNodes | Where-Object { $_.LocalName -eq 'Prefix' })
            if ($prefixNode.InnerText -eq $Prefix) {
                return $routeNode
            }

            $identifierNode = $routeNode.ChildNodes | Where-Object { $_.LocalName -eq 'Identifier' }
            
            if(([Convert]::ToInt32($identifierNode.InnerText)) -gt ([Convert]::ToInt32($routeIdentifier))) {
                $routeIdentifier = $identifierNode.InnerText
            }
        }        

        $routeIdentifier = ([Convert]::ToInt32($routeIdentifier)) + 1

        $routeNode = $this.document.CreateElement('Route', $this.document.DocumentElement.NamespaceURI)
        $routeNode.SetAttribute('action', [UnattendXML]::WCM, 'add')
        $routes.AppendChild($routeNode)

        $identifierNode = $this.document.CreateElement('Identifier', $this.document.DocumentElement.NamespaceURI)
        $identifierNodeText = $this.document.CreateTextNode($routeIdentifier.ToString())
        $identifierNode.AppendChild($identifierNodeText)
        $routeNode.AppendChild($identifierNode)

        $prefixNode = $this.document.CreateElement('Prefix', $this.document.DocumentElement.NamespaceURI)
        $prefixNodeText = $this.document.CreateTextNode($Prefix)
        $prefixNode.AppendChild($prefixNodeText)
        $routeNode.AppendChild($prefixNode)

        return $routeNode
    }

    hidden [System.Xml.XmlElement]GetFirstLogonCommandSection()
    {
        $xmlSettings = $this.GetOobeSystemSettings()
        $xmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)
        $firstLogonCommands = $this.GetOrCreateChildNode($xmlComponent, 'FirstLogonCommands')
        return $firstLogonCommands
    }

    hidden [System.Xml.XmlElement]GetRunSynchronousSection()
    {
        $xmlSettings = $this.GetSpecializeSettings()
        $xmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)
        return $this.GetOrCreateChildNode($xmlComponent, 'RunSynchronous')
    }

    hidden [string]ConvertToString([SecureString]$SecureString)
    {
        if (-not $SecureString)
        {
            return $null
        }

        $ManagedPasswordString = $null
        $PointerToPasswordString = $null
        try
        {
            $PointerToPasswordString = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($SecureString)
            $ManagedPasswordString = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($PointerToPasswordString)
        }
        finally
        {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeCoTaskMemUnicode($PointerToPasswordString)
        }
    
        return $ManagedPasswordString
    }

    hidden [void]SetAdministratorPassword([SecureString]$AdministratorPassword)
    {
        $xmlSettings = $this.GetOobeSystemSettings()
        $XmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)

        $XmlUserAccounts = $this.document.CreateElement('UserAccounts', $this.document.DocumentElement.NamespaceURI)
        $XmlComponent.AppendChild($XmlUserAccounts)
        
        $XmlAdministratorPassword = $this.document.CreateElement('AdministratorPassword', $this.document.DocumentElement.NamespaceURI)
        $XmlUserAccounts.AppendChild($XmlAdministratorPassword) 

        $XmlValue = $this.document.CreateElement('Value', $this.document.DocumentElement.NamespaceURI)
        $XmlText = $this.document.CreateTextNode([Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(($this.ConvertToString($AdministratorPassword)) + 'AdministratorPassword')))
        $XmlValue.AppendChild($XmlText)
        $XmlAdministratorPassword.AppendChild($XmlValue)

        $XmlPlainText = $this.document.CreateElement('PlainText', $this.document.DocumentElement.NamespaceURI)
        $XmlPassword = $this.document.CreateTextNode('false')
        $XmlPlainText.AppendChild($XmlPassword)
        $XmlAdministratorPassword.AppendChild($XmlPlainText) 
    }

    <#
        .SYNOPSIS
            Disables the EULA Page
        .LINK
            https://technet.microsoft.com/en-us/library/cc749231(v=ws.10).aspx
    #>
    [void] SetHideEula([bool]$hideEula) {
        $xmlSettings = $this.GetOobeSystemSettings()
        $XmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)
        $oobeSettings = $this.GetOrCreateChildNode($XmlComponent, 'OOBE')

        $this.SetBoolNodeValue($oobeSettings, 'HideEULAPage', $hideEula)
    }

    <#
        .SYNOPSIS
            Skips the machine OOBE screens
        .LINK
            https://technet.microsoft.com/en-us/library/cc765947(v=ws.10).aspx
    #>
    [void] SetSkipMachineOOBE([bool]$skipMachineOOBE) {
        $xmlSettings = $this.GetOobeSystemSettings()
        $XmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)
        $oobeSettings = $this.GetOrCreateChildNode($XmlComponent, 'OOBE')

        $this.SetBoolNodeValue($oobeSettings, 'SkipMachineOOBE', $skipMachineOOBE)
    }

    [void] SetAutoLogon([string]$Username, [string]$password, [int]$Count)
    {
        [SecureString]$securePassword = ConvertTo-SecureString -AsPlainText -Force -String $password
        $this.SetAutoLogon($username, $securePassword, $count)
    }

    [void] SetAutoLogon([string]$Username, [SecureString]$password, [int]$Count)
    {
        $xmlSettings = $this.GetOobeSystemSettings()
        $XmlComponent = $this.GetWindowsShellSetupSection($xmlSettings)
        $autoLogonNode = $this.GetOrCreateChildNode($XmlComponent, 'AutoLogon')
        
        $passwordNode = $this.GetOrCreateChildNode($autoLogonNode, 'Password')
        $this.SetTextNodeValue($passwordNode, 'Value', [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes(($this.ConvertToString($password)) + 'Password')))
        $this.SetBoolNodeValue($passwordNode, 'PlainText', $false)

        $this.SetBoolNodeValue($autoLogonNode, 'Enabled', $true)

        $this.SetInt32NodeValue($autoLogonNode, 'LogonCount', $Count)

        $this.SetTextNodeValue($autoLogonNode, 'Username', $Username)
    }

    hidden [void]SetTextNodeValue([System.Xml.XmlElement]$Parent, [string]$NodeName, [string]$Value)
    {
        $namedNode = $this.GetOrCreateChildNode($Parent, $NodeName)
        $textValueNode = $this.document.CreateTextNode($Value)
        $namedNode.AppendChild($textValueNode) 
    }

    hidden [void]SetBoolNodeValue([System.Xml.XmlElement]$Parent, [string]$NodeName, [bool]$Value)
    {
        $this.SetTextNodeValue($Parent, $NodeName, ($Value.ToString().ToLower()))
    }

    hidden [void]SetInt32NodeValue([System.Xml.XmlElement]$Parent, [string]$NodeName, [Int32]$Value)
    {
        $this.SetTextNodeValue($Parent, $NodeName, ($Value.ToString()))
    }

    UnattendXml() 
    {
        $XmlDecl = $this.document.CreateXmlDeclaration('1.0', 'utf-8', $Null)
        $XmlRoot = $this.document.DocumentElement
        $this.document.InsertBefore($XmlDecl, $XmlRoot)

        $this.XmlUnattended = $this.document.CreateElement('unattend', [UnattendXml]::XmlNs)
        $this.XmlUnattended.SetAttribute('xmlns:wcm', [UnattendXML]::WCM)
        $this.XmlUnattended.SetAttribute('xmlns:xsi', [UnattendXML]::XmlSchemaInstance)
        $this.document.AppendChild($this.XmlUnattended) 
    }

    <#
        .SYNOPSIS
            Configures the registered owner of the Windows installation
    #>
    [void]SetRegisteredOwner([string]$RegisteredOwner)
    {
        $offlineServiceSettings = $this.GetSpecializeSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'RegisteredOwner', $RegisteredOwner)
    }

    <#
        .SYNOPSIS
            Configures the registered organization of the Windows installation
    #>
    [void]SetRegisteredOrganization([string]$RegisteredOrganization)
    {
        $offlineServiceSettings = $this.GetSpecializeSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'RegisteredOrganization', $RegisteredOrganization)        
    }

    <#
        .SYNOPSIS
            Configures the name of the computer
    #>
    [void]SetComputerName([string]$ComputerName)
    {
        $offlineServiceSettings = $this.GetSpecializeSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'ComputerName', $ComputerName)        
    }

    <#
        .SYNOPSIS
            Configures the time zone for the computer
        .NOTES
            The configured time zone must be a valid value as defined by Microsoft
        .LINK
            https://technet.microsoft.com/en-us/library/cc749073(v=ws.10).aspx
    #>
    [void]SetTimeZone([string]$TimeZone)
    {
        $offlineServiceSettings = $this.GetSpecializeSettings()
        $windowsShellSetupNode = $this.GetWindowsShellSetupSection($offlineServiceSettings)
        $this.SetTextNodeValue($windowsShellSetupNode, 'TimeZone', $TimeZone)                
    }

    <#
        .SYNOPSIS
            Sets the state of whether DHCPv4 is enabled for a given interface
        .LINK
            https://technet.microsoft.com/en-us/library/cc748924(v=ws.10).aspx
    #>
    [void]SetDHCPEnabled([string]$InterfaceIdentifier, [bool]$Enabled)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $interfaceTCPIPSettings = $this.GetTCPIPv4Settings($interfaceNode)
        $this.SetBoolNodeValue($interfaceTCPIPSettings, 'DhcpEnabled', $Enabled)
    }

    <#
        .SYNOPSIS
            Sets the state of whether IPv4 Router Discovery is enabled for a given interface
        .LINK
            https://technet.microsoft.com/en-us/library/cc749578(v=ws.10).aspx
            https://www.ietf.org/rfc/rfc1256.txt
            https://en.wikipedia.org/wiki/ICMP_Router_Discovery_Protocol
    #>
    [void]SetRouterDiscoveryEnabled([string]$InterfaceIdentifier, [bool]$Enabled)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $interfaceTCPIPSettings = $this.GetTCPIPv4Settings($interfaceNode)
        $this.SetBoolNodeValue($interfaceTCPIPSettings, 'RouterDiscoveryEnabled', $Enabled)
    }

    <#
        .SYNOPSIS
            Sets the IPv4 routing metric value for the interface itself.
        .NOTES
            If you don't understand this value, set it to 10. 
        .LINK
            https://technet.microsoft.com/en-us/library/cc766415(v=ws.10).aspx
    #>
    [void]SetInterfaceIPv4Metric([string]$InterfaceIdentifier, [Int32]$Metric)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $interfaceTCPIPSettings = $this.GetTCPIPv4Settings($interfaceNode)
        $this.SetInt32NodeValue($interfaceTCPIPSettings, 'Metric', $Metric)
    }

    <#
        .SYNOPSIS
            Sets the IPv4 address, subnet mask, ad default gateway for the given interface.
        .NOTES
            While multiple addresses are allowed on an interface, this function 
            assumes you'll have only one.

            It is recommended that when configuring a static IP address, you :
              * Disable DHCPv4 for the interface
              * Disable IPv4 ICMP Router Discovery for the interface
              * Configure a proper routing metric for the interface
        .LINK
            https://technet.microsoft.com/en-us/library/cc749412(v=ws.10).aspx
            https://technet.microsoft.com/en-us/library/cc749535(v=ws.10).aspx
    #>
    [void]SetInterfaceIPAddress([string]$InterfaceIdentifier, [string]$IPAddress, [Int32]$PrefixLength, [string]$DefaultGateway)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $interfaceNode = $this.GetTCPIPInterface($XmlSettings, $InterfaceIdentifier)
        $ipAddressNode = $this.GetTCPIPUnicastIPAddress($interfaceNode, '1')

        # TODO : Handle pre-existing inner text node.
        $ipAddressTextNode = $this.document.CreateTextNode(("{0}/{1}" -f $IPAddress,$PrefixLength))
        $ipAddressNode.AppendChild($ipAddressTextNode)

        # TODO : Create 'SetRoute' member function which modifies the value if it's already set
        $routeNode = $this.GetTCPIPRoute($interfaceNode, '0.0.0.0/0')
        
        $metricNode = $this.document.CreateElement('Metric', $this.document.DocumentElement.NamespaceURI)
        $metricNodeText = $this.document.CreateTextNode('10')
        $metricNode.AppendChild($metricNodeText)
        $routeNode.AppendChild($metricNode)

        $nextHopNode = $this.document.CreateElement('NextHopAddress', $this.document.DocumentElement.NamespaceURI)
        $nextHopNodeText = $this.document.CreateTextNode($DefaultGateway)
        $nextHopNode.AppendChild($nextHopNodeText)
        $routeNode.AppendChild($nextHopNode)
    }    

    <#
        .SYNOPSIS
            Sets DNS configuration for an interface 
        .NOTES
            This function is VERY "alpha version" and should not be used heavily until it's been completed
        .LINK
            https://technet.microsoft.com/en-us/library/ff716008(v=ws.10).aspx
    #>
    [void]SetDNSInterfaceSettings([string]$InterfaceIdentifier, [string[]]$DNSServerAddresses, [string]$DNSDomain)
    {
        $XmlSettings = $this.GetSpecializeSettings()
        $dnsSection = $this.GetWindowsDNSClientSection($XmlSettings)
        $interfacesSection = $this.GetOrCreateChildNode($dnsSection, 'Interfaces')
        
        # Verify we're not overwriting the interface settings
        $interfaceList = $interfacesSection.ChildNodes | Where-Object { $_.LocalName -eq 'Interface' }
        foreach($interface in $interfaceList) {
            $identifierNode = $interface.ChildNodes | Where-Object { $_.LocalName -eq 'Identifier' }
            if ($null -eq $identifierNode) {
                continue
            }

            if ($identifierNode.'#text' -eq $InterfaceIdentifier) {
                throw 'Editing DNS interface settings not implemented yet'
            }
        }

        $interface = $this.document.CreateElement('Interface', $this.document.DocumentElement.NamespaceURI)
        $interface.SetAttribute('action', [UnattendXML]::WCM, 'add')
        $interfacesSection.AppendChild($interface)

        $this.SetTextNodeValue($interface, 'Identifier', $InterfaceIdentifier)
        $this.SetBoolNodeValue($interface, 'EnableAdapterDomainNameRegistration', $false)
        $this.SetBoolNodeValue($interface, 'DisableDynamicUpdate', $false)
        $this.SetTextNodeValue($interface, 'DNSDomain', $DNSDomain)

        $dnsSearchOrder = $this.GetOrCreateChildNode($interface, 'DNSServerSearchOrder')
        for($i=0; $i -lt $DNSServerAddresses.Count; $i++) {
            $ipAddress = $this.document.CreateElement('IpAddress', $this.document.DocumentElement.NamespaceURI)
            $ipAddress.SetAttribute('action', [UnattendXML]::WCM, 'add')
            $ipAddress.SetAttribute('keyValue',[UnattendXML]::WCM, ($i + 1))
            $textValueNode = $this.document.CreateTextNode($DNSServerAddresses[$i])
            $ipAddress.AppendChild($textValueNode)

            $dnsSearchOrder.AppendChild($ipAddress)            
        }

        $this.SetBoolNodeValue($dnsSection, 'UseDomainNameDevolution', $true)
        $this.SetTextNodeValue($dnsSection, 'DNSDomain', $DNSDomain)
    }

    <#
        .SYNOPSIS
            Configures the administrator password for the new System
        .NOTES
            This command uses a plain text password.
        .LINK
            https://msdn.microsoft.com/en-us/library/windows/hardware/dn986490(v=vs.85).aspx
    #>
    [void] SetAdministratorPassword([string]$AdministratorPassword) {
        $this.SetAdministratorPassword((ConvertTo-SecureString $AdministratorPassword -AsPlainText -Force))
    }

    <#
        .SYNOPSIS
            Add's a command to the FirstLogonCommand list
        
        .PARAMETER Description
            A description of what the command is to do

        .PARAMETER command
            The command to run

        .LINK
            https://technet.microsoft.com/en-us/library/cc722150(v=ws.10).aspx
    #>
    [void] AddFirstLogonCommand([string]$Description, [string]$Command)
    {
        $firstLogonCommands = $this.GetFirstLogonCommandSection()
        $highestOrderNumber = 0
        $syncCommands = $firstLogonCommands.ChildNodes | Where-Object { $_.LocalName -eq 'SynchronousCommand' }
        foreach($syncCommand in $syncCommands) {
            $orderNumber = $syncCommand.ChildNodes | Where-Object { $_.LocalName -eq 'order' }
            $highestOrderNumber = [Math]::Max($highestOrderNumber, [Convert]::ToInt32($orderNumber.InnerText))
        }

        $orderValueNode = $this.document.CreateTextNode(($highestOrderNumber + 1).ToString())
        $orderNode = $this.document.CreateElement('Order', $this.document.DocumentElement.NamespaceURI)
        $orderNode.AppendChild($orderValueNode)

        $descriptionTextNode = $this.document.CreateTextNode($Description)
        $descriptionNode = $this.document.CreateElement('Description', $this.document.DocumentElement.NamespaceURI)
        $descriptionNode.AppendChild($descriptionTextNode)

        $commandTextNode = $this.document.CreateTextNode($Command)
        $commandNode = $this.document.CreateElement('CommandLine', $this.document.DocumentElement.NamespaceURI)
        $commandNode.AppendChild($commandTextNode)

        $syncCommandNode = $this.document.CreateElement('SynchronousCommand', $this.document.DocumentElement.NamespaceURI)
        $syncCommandNode.SetAttribute('action', [UnattendXML]::WCM, 'add')
        $syncCommandNode.AppendChild($orderNode)
        $syncCommandNode.AppendChild($descriptionNode)
        $syncCommandNode.AppendChild($commandNode)

        $firstLogonCommands.AppendChild($syncCommandNode)
    }

    <#
        .SYNOPSIS
            Adds a run synchronous command to the specialize section

        .DESCRIPTION
            Adds a command to the ordered list of synchronous commands to be executed as part of the startup process for post installation
            steps through sysprep.exe.

        .PARAMETER Description
            A description of the command to run on startup

        .PARAMETER Command
            The command to execute including Path and arguments

        .PARAMETER WillReboot
            Whether the command will reboot the system after running

        .LINK
            https://technet.microsoft.com/en-us/library/cc722359(v=ws.10).aspx
    #>
    [System.Xml.XmlElement] AddRunSynchronousCommand([string]$Description, [string]$Command, [EnumWillReboot]$WillReboot=[EnumWillReboot]::Never)
    {
        $runSynchronousSection = $this.GetRunSynchronousSection()
        $highestOrderNumber = 0
        $synchronousCommands = $runSynchronousSection.ChildNodes | Where-Object { $_.LocalName -eq 'RunSynchronousCommand' }
        foreach($synchronousCommand in $synchronousCommands) {
            $orderNumber = $synchronousCommand.ChildNodes | Where-Object { $_.LocalName -eq 'order' }
            $highestOrderNumber = [Math]::Max($highestOrderNumber, [Convert]::ToInt32($orderNumber.InnerText))
        }

        $orderValueNode = $this.document.CreateTextNode(($highestOrderNumber + 1).ToString())
        $orderNode = $this.document.CreateElement('Order', $this.document.DocumentElement.NamespaceURI)
        $orderNode.AppendChild($orderValueNode)

        $descriptionTextNode = $this.document.CreateTextNode($Description)
        $descriptionNode = $this.document.CreateElement('Description', $this.document.DocumentElement.NamespaceURI)
        $descriptionNode.AppendChild($descriptionTextNode)

        $pathTextNode = $this.document.CreateTextNode($Command)
        $pathNode = $this.document.CreateElement('Path', $this.document.DocumentElement.NamespaceURI)
        $pathNode.AppendChild($pathTextNode)

        $willRebootTextNode = $this.document.CreateTextNode([UnattendXml]::WillRebootToString($WillReboot))    
        $willRebootNode = $this.document.CreateElement('WillReboot', $this.document.DocumentElement.NamespaceURI)
        $willRebootNode.AppendChild($willRebootTextNode)

        $synchronousCommandNode = $this.document.CreateElement('RunSynchronousCommand', $this.document.DocumentElement.NamespaceURI)
        $synchronousCommandNode.SetAttribute('action', [UnattendXml]::WCM, 'add')
        $synchronousCommandNode.AppendChild($orderNode)
        $synchronousCommandNode.AppendChild($descriptionNode)
        $synchronousCommandNode.AppendChild($pathNode)
        $synchronousCommandNode.AppendChild($willRebootNode)
    
        $runSynchronousSection.AppendChild($synchronousCommandNode)
        return $synchronousCommandNode
    }

    <#
        .SYNOPSIS
            Adds a run synchronous command to the specialize section

        .DESCRIPTION
            Adds a command to the ordered list of synchronous commands to be executed as part of the startup process for post installation
            steps through sysprep.exe.

        .PARAMETER Description
            A description of the command to run on startup

        .PARAMETER Command
            The command to execute including Path and arguments

        .NOTES
            This function is an overload which defaults the 'WillReboot' value to never

        .LINK
            https://technet.microsoft.com/en-us/library/cc722359(v=ws.10).aspx
    #>
    [System.Xml.XmlElement] AddRunSynchronousCommand([string]$Description, [string]$Command)
    {
        return $this.AddRunSynchronousCommand($Description, $Command, [EnumWillReboot]::Never)
    }

    <#
        .SYNOPSIS
            Adds a run synchronous command to the specialize section

        .DESCRIPTION
            Adds a command to the ordered list of synchronous commands to be executed as part of the startup process for post installation
            steps through sysprep.exe.

        .PARAMETER Description
            A description of the command to run on startup

        .PARAMETER Domain
            The login domain to use for "Run As" for the command

        .PARAMETER Username
            The login username to use for "Run As" for the command

        .PARAMETER Password
            The login password to use for the "Run As" for the command

        .PARAMETER Command
            The command to execute including Path and arguments

        .PARAMETER WillReboot
            Whether the command will reboot the system after running

        .NOTES
            Warning, when providing login information in the unattend.xml, a copy of the unattend file may end up stored within
            the \Windows\Panther directory with the passwords in tact. The file should be explicitly removed upon completion

        .LINK
            https://technet.microsoft.com/en-us/library/cc722359(v=ws.10).aspx
    #>
    [System.Xml.XmlElement] AddRunSynchronousCommand([string]$Description, [string]$Domain, [string]$Username, [string]$Password, [string]$Command, [EnumWillReboot]$WillReboot=[EnumWillReboot]::Never)
    {
        $synchronousCommandNode = $this.AddRunSynchronousCommand($Description, $Command, $WillReboot)

        $domainTextNode = $this.document.CreateTextNode($domain)
        $domainNode = $this.document.CreateElement('Domain', $this.document.DocumentElement.NamespaceURI)
        $domainNode.AppendChild($domainTextNode)

        $usernameTextNode = $this.document.CreateTextNode($Username)
        $usernameNode = $this.document.CreateElement('Username', $this.document.DocumentElement.NamespaceURI)
        $usernameNode.AppendChild($usernameTextNode)

        $passwordTextNode = $this.document.CreateTextNode($Password)
        $passwordNode = $this.document.CreateElement('Password', $this.document.DocumentElement.NamespaceURI)
        $passwordNode.AppendChild($passwordTextNode)

        $credentialsNode = $this.document.CreateElement('Credentials', $this.document.DocumentElement.NamespaceURI)
        $credentialsNode.AppendChild($domainNode)
        $credentialsNode.AppendChild($usernameNode)
        $credentialsNode.AppendChild($passwordNode)
        $synchronousCommandNode.AppendChild($credentialsNode)

        return $synchronousCommandNode
    }

    <#
        .SYNOPSIS
            Adds a run synchronous command to the specialize section

        .DESCRIPTION
            Adds a command to the ordered list of synchronous commands to be executed as part of the startup process for post installation
            steps through sysprep.exe.

        .PARAMETER Description
            A description of the command to run on startup

        .PARAMETER Domain
            The login domain to use for "Run As" for the command

        .PARAMETER Username
            The login username to use for "Run As" for the command

        .PARAMETER Password
            The login password to use for the "Run As" for the command

        .PARAMETER Command
            The command to execute including Path and arguments

        .NOTES
            This is an overloaded function which sets the default value of WillReboot to never

            Warning, when providing login information in the unattend.xml, a copy of the unattend file may end up stored within
            the \Windows\Panther directory with the passwords in tact. The file should be explicitly removed upon completion

        .LINK
            https://technet.microsoft.com/en-us/library/cc722359(v=ws.10).aspx
    #>
    [System.Xml.XmlElement] AddRunSynchronousCommand([string]$Description, [string]$Domain, [string]$Username, [string]$Password, [string]$Command)
    {
        return $this.AddRunSynchronousCommand($Description, $Domain, $Username, $Password, $Command, [EnumWillReboot]::Never)
    }

    <#
        .SYNOPSIS
            Enables Windows Terminal Services to connect
        
        .LINK
            https://technet.microsoft.com/en-us/library/cc722017%28v=ws.10%29.aspx?f=255&MSPPError=-2147217396
    #>
    [void]SetRemoteDesktopEnabled()
    {
        $xmlSettings = $this.GetSpecializeSettings()
        $terminalServicesLocalSessionManager = $this.GetTerminalServicesLocalSessionManager($xmlSettings)
        $this.SetBoolNodeValue($terminalServicesLocalSessionManager, 'fDenyTSConnections', $false)
    }

    <#
        .SYNOPSIS
            Configures whether to support user or network level authentication for RDP sessions

        .LINK
            https://technet.microsoft.com/en-us/library/cc722192(v=ws.10).aspx
    #>
    [void]SetRemoteDesktopAuthenticationMode([EnumRdpAuthentication]$AuthenticationMode)
    {
        $xmlSettings = $this.GetSpecializeSettings()
        $terminalServicesRdpWinStationExtensions = $this.GetTerminalServicesRdpWinStationExtensions($xmlSettings)
        $this.SetTextNodeValue($terminalServicesRdpWinStationExtensions, 'UserAuthentication', [UnattendXml]::RdpAuthenticationModeToString($AuthenticationMode))
    }

    <#
        .SYNOPSIS
            Generates XML text that can be saved to a file 
    #>
    [string]ToXml()
    {
        $xmlWriterSettings = New-Object System.Xml.XmlWriterSettings
        $xmlWriterSettings.Indent = $true;
        $xmlWriterSettings.Encoding = [System.Text.Encoding]::Utf8

        $stringWriter = New-Object System.IO.StringWriter
        $xmlWriter = [System.Xml.XmlWriter]::Create($stringWriter, $xmlWriterSettings)

        $this.document.WriteContentTo($xmlWriter)

        $xmlWriter.Flush()
        $stringWriter.Flush()

        return $stringWriter.ToString() 
    }
}
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
	[int] $SubnetLength

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

            if($null -ne $this.IPAddress) {
                Write-Verbose -Message 'IP is not null'
            }
            if($null -ne $this.SubnetLength){
                Write-Verbose -Message 'subenet length is not null'
            }
            if($null -ne $this.DefaultGateway){
                Write-Verbose -Message 'dg is not null'
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
        A resource for creating a differencing VHD disk image relative to a parent image
#>
[DscResource()]
class cDifferencingVHD 
{
    [DscProperty(Key)]
    [string] $VHDPath

    [DSCProperty(Mandatory)]
    [string] $ParentVHDPath

    <#
        .SYNOPSIS
            Resource Get
    #>
    [cDifferencingVHD] Get()
    {
        $result = [cDifferencingVHD]::new()
        $result.ParentVHDPath = $this.ParentVHDPath
        $result.VHDPath = $this.VHDPath
        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.ParentVHDPath +'])')
        if (-not (Test-Path -Path $this.PArentVHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.ParentVHDPath + '] not present')
            return $false
        }

        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (-not (Test-Path -Path $this.VHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.VHDPath + '] not present')
            return $false
        }

        Write-Verbose -Message ('Attempt to get handle to the VHD file')
        $vhd = $null
        try {
            $vhd = Get-VHD -Path $this.VHDPath
            
            if($null -eq $vhd) {
                # TODO: throw here?
                Write-Error -Message ('Unknown error getting handle to [' + $this.VHDPath + ']')
                return $false
            }
        } catch {
            # TDOD : throw here?
            Write-Error -Message ('Failed to get handle to VHD file [' + $this.VHDPath + ']')
            return $false
        }

        Write-Verbose -Message ('Handle obtained')

        if($null -eq $vhd.ParentPath) {
            throw [Exception]::new(
                'Existing VHD [' + $this.VHDPath + '] is not a differencing image'
            )
        }

        Write-Verbose -Message ('Parent path of VHD (as seen within the VHD) is [' + $vhd.ParentPath + ']')

        $resolvedParentVhdPath = Resolve-Path -Path $this.ParentVHDPath -Relative:$false
        if(-not ($resolvedParentVhdPath -like $vhd.ParentPath)) {
            throw [Exception]::new(
                'Path specified as option [' + $this.ParentVHDPath + '] is not equal to the path within the VHD [' + $resolvedParentVhdPath + ']'
            )
        }

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.ParentVHDPath +'])')
        if (-not (Test-Path -Path $this.PArentVHDPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'Parent VHD file not found',
                $this.ParentVHDPath ,
                [System.ArgumentException]::new(
                    'VHD file specified not present',
                    'ParentVHDPath'
                )
            )
        }

        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (Test-Path -Path $this.VHDPath) {
            throw [System.ArgumentException]::new(
                'VHD File [' + $this.VHDPath + '] already exists and should not be overwritten',
                'VHDPath'
            )
        }

        $parentVHD = $null
        Write-Verbose -Message ('Getting handle to parent VHD')
        try {
            $parentVHD = Get-VHD -Path $this.ParentVHDPath
        } catch {
            throw [Exception]::new(
                'Failed to get handle to parent VHD [' + $this.ParentVHDPath + ']',
                $_.Exception
            )
        }

        Write-Verbose -Message ('Getting mounted position of parent VHD')
        try {
            $MountedDiskImage = Get-WmiObject -Namespace 'root\virtualization\v2' -query "SELECT * FROM MSVM_MountedStorageImage WHERE Name ='$($this.ParentVHDPath.Replace("\", "\\"))'"

            if($null -ne $MountedDiskImage) {
                throw [System.ArgumentException]::new(
                    '[' + $this.ParentVHDPath + '], ParentVHD is already mounted and can''t be used as a differencing disk',
                    'ParentVHDPath'
                )
            }
        } catch {
            if($_.Exception.Message.StartsWith('[')) {
                throw $_.Exception
            }

            throw [System.Exception]::new(
                'Failed to get information from virtualization root regarding mounted images',
                $_.Exception
            )
        }

        $vhdFolderInfo = [System.IO.FileInfo]::new($this.VHDPath)
        if(($null -eq $vhdFolderInfo) -or ($null -eq $vhdFolderInfo.Directory)) {
            throw [Exception]::new(
                '[' + $this.VHDPath + '] does not appear to contain a valid parent directory within its path'
            )
        }
        
        Write-Verbose -Message ('Testing for presence of folder of new VHD file [' + $vhdFolderInfo.Directory.FullName + ']')
        if(-not (Test-Path -Path $vhdFolderInfo.Directory.FullName)) {
            throw [System.IO.DirectoryNotFoundException]::new(
                'Containing directory for new VHD file does not exist',
                $vhdFolderInfo.Directory.FullName
            )
        }

        Write-Verbose -Message ('Attempting to create new differencing VHD file [' + $this.VHDPath + '] using [' + $this.ParentVHDPath + '] as its parent')
        $vhd = $null
        try {
            $vhd = New-VHD -Path $this.VHDPath -ParentPath $this.ParentVHDPath -Differencing 

            if ($null -eq $vhd) {
                throw [Exception]::new(
                    'Unknown error calling New-VHD, aborting'
                )
            }
        } catch {
            throw [Exception]::new(
                'Failed to create differencing VHD file with source  VHD file [' + $this.VHDPath + '] using [' + $this.ParentVHDPath + '] as its parent',
                $_.Exception
            )
        }

        Write-Verbose -Message ('New VHD file [' + $this.VHDPath + '] created')
    }
}
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
        throw [Exception]::new(
            'cGuestRegistryKey is a monitoring (test only) resource and should not be used for setting state'
        )
    }
}
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
        A resource for copying files into the contents of a VHD file
#>
[DscResource()]
class cVHDFileSystem 
{
    [DscProperty(Key)]
    [string] $VHDPath

    [DSCProperty()]
    [bool] $OkIfMounted = $true

    [DSCProperty()]
    [UInt64] $OkIfOverBytes = 4MB

    [DSCProperty(Mandatory)]
    [string[]] $ItemList

    <#
        .SYNOPSIS
            Resource Get
    #>
    [cVHDFileSystem] Get()
    {
        [cVHDFileSystem]$result = [cVHDFileSystem]::new()

        $result.VHDPath = $this.VHDPath

        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (-not (Test-Path -Path $this.VHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.VHDPath + '] not present')
            return $false
        }

        if($this.OkIfOverBytes -gt 0) {
            Write-Verbose -Message ('OkIfOverBytes is ' + $this.OkIfOverBytes + ' bytes. Testing file size')
            $fileItem = Get-Item -Path $this.VHDPath

            if($null -eq $fileItem) {
                throw [Exception]::new(
                    'Failed to call Get-Item on ' + $this.VHDPath
                )
            }

            Write-Verbose ('File size is ' + $fileItem.Length.ToString() + ' bytes')
            if($fileItem.Length -gt $this.OkIfOverBytes) {
                Write-Verbose -Message 'Test condition met'
                return $true
            }

            return $false
        }

        Write-Verbose -Message ('Getting mounted information about VHD')
        try {
            $MountedDiskImage = Get-WmiObject -Namespace 'root\virtualization\v2' -query "SELECT * FROM MSVM_MountedStorageImage WHERE Name ='$($this.VHDPath.Replace("\", "\\"))'"

            if($null -ne $MountedDiskImage) {
                If($this.OkIfMounted) {
                    Write-Verbose -Message ('[' + $this.VHDPath + '], VHD is already mounted and OkIfMounted is $true, test is ok')
                    return $true
                }

                throw [Exception]::new(
                    '[' + $this.VHDPath + '], VHD is already mounted and cannot be altered in its current state'
                )
            }
        } catch {
            if($_.Exception.Message.StartsWith('[')) {
                throw $_.Exception
            }

            throw [System.Exception]::new(
                'Failed to get information from virtualization root regarding mounted images',
                $_.Exception
            )
        }

        # TODO : Add code to test contents of VHD against file list

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        Write-Verbose -Message ('Testing for presence of [' + $this.VHDPath +'])')
        if (-not (Test-Path -Path $this.VHDPath)) {
            throw [System.IO.FileNotFoundException]::new(
                'VHD File not present',
                $this.VHDPath
            )
        }

        Write-Verbose -Message ('Checking initial validity of item list')
        if($null -eq $this.ItemList) {
            throw [System.ArgumentNullException]::new(
                'No item list was passed',
                'ItemList'
            )
        }

        if((($this.ItemList.Count % 2) -eq 1) -or ($this.ItemList.Count -eq 0)) {
            throw [System.ArgumentException]::new(
                'ItemList must be formatted as a list of strings of source path and destination path.',
                'ItemList'
            )
        }

        Write-Verbose -Message ('ItemList meets preliminary checks')

        $this.MountVHDImage()

        try {
            $this.CopyItems()
        } catch {
            throw [Exception]::new(
                'File copy operation failed',
                $_.Exception                
            )
        } finally {
            $this.DismountVHDImage()
        }
    }

    hidden static [string]$GptTypeUEFISystem = '{c12a7328-f81f-11d2-ba4b-00a0c93ec93b}'
    hidden static [string]$GptTypeMicrosoftReserved = '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
    hidden static [string]$GptTypeMicrosoftBasic = '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'

    hidden [string] $WindowsPartitionRoot

    [void] CopyItems()
    {
        Write-Verbose -Message ('Refreshing PS Drive list')
        Get-PSDrive

        $itemCount = $this.ItemList.Count

        for($i = 0; $i -lt $itemCount; $i += 2) {
            $sourceItem = $this.ItemList[$i]
            $destinationItem = $this.ItemList[$i + 1]

            Write-Verbose -Message ('SourcePath = [' + $sourceItem + '], DestinationPath = [' + $destinationItem + ']')
            
            Write-Verbose -Message ('Verifying presence of source file [' + $sourceItem + ']')
            if(-not (Test-Path -Path $sourceItem)) {
                throw [System.IO.FileNotFoundException]::new(
                    'Source item not found',
                    $sourceItem
                )
            }

            $destinationPath = Join-Path -Path $this.WindowsPartitionRoot -ChildPath $destinationItem
            Write-Verbose -Message ('Checking for presence of destination file [' + $destinationPath + ']')
            if(Test-Path -Path $destinationItem) {
                throw [Exception]::new(
                    'Overwriting existing files is not currently supported [' + $destinationItem + ']'
                )
            }

            Write-Verbose -Message ('Constructing parent path name for [' + $destinationPath + ']')
            $destinationFileInfo = [System.IO.FileInfo]::new($destinationPath)
            $destinationParent = $destinationFileInfo.Directory.FullName

            Write-Verbose -Message ('Checking for parent directory of destination file [' + $destinationParent + ']')
            if (-not (Test-Path -Path $destinationParent)) {
                throw [System.IO.DirectoryNotFoundException]::new(
                    'Parent directory of destination item does not exist and force creation is not supported yet',
                    $destinationParent
                )
            }

            Write-Verbose -Message 'Parent directory exists, preparing to copy'

            $sourceFileItem = Get-Item -Path $sourceItem
            if ($sourceFileItem.GetType().Name -eq 'DirectoryInfo') {
                Write-Verbose -Message 'Source item is a directory'
                Copy-Item -Path $sourceItem -Destination $destinationPath -Recurse -Confirm:$false -Force
            } elseif ($sourceFileItem.GetType().Name -eq 'FileInfo') {
                Write-Verbose -Message 'Source item is a normal file'
                Copy-Item -Path $sourceItem -Destination $destinationPath -Confirm:$false -Force
            } else {
                Write-Verbose -Message 'WTF'
                throw [Exception]::new(
                    '[' + $sourceItem + '] is an unsupported type [' + $sourceFileItem.GetType() + ']'
                )
            }
        }
    }

    [void] MountVHDImage()
    {
        $vhd = $null
        try {
            Write-Verbose -Message ('Getting handle to the VHD file')
            $vhd = Get-Vhd -Path $this.VHDPath 
            if($null -eq $vhd) {
                throw [Exception]::new(
                    'Unknown error getting handle to the vhd'
                )
            }
        } catch {
            if($_.Exception.Message.BeginsWith('Unknown')) {
                throw $_.Exception
            }

            throw [Exception]::new(
                'Error obtaining VHD handle to ' + $this.VHDPath,
                $_.Exception
            )
        }

        $mountResult = $null
        try {
            Write-Verbose -Message ('Obtained VHD Handle, mounting VHD image')
            $mountResult = $vhd | Mount-VHD -Passthru
            if ($null -eq $mountResult) {
                throw [Exception]::new(
                    'Unknown error mounting VHD [' + $this.VHDPath + ']'
                )
            }
        } catch {
            if($_.Exception.Message.BeginsWith('Unknown')) {
                throw $_.Exception
            }

            throw [Exception]::new(
                'Error mounting VHD ' + $this.VHDPath,
                $_.Exception
            )            
        }

        try {
            Write-Verbose -Message 'Mounted VHD, getting windows disk handle'

            $disk = $mountResult | Get-Disk
            if ($null -eq $disk) {
                throw [Exception]::new(
                    'Failed to get disk handle'
                )
            }

            Write-Verbose -Message 'Obtained windows disk handle, getting partition table'

            $partitions = $disk | Get-Partition
            if ($null -eq $partitions) {
                throw [Exception]::new(
                    'Failed to get partition table'
                )
            }

            # TODO : Consider calling BCDBOOT to read the boot information for the drive.
            # TODO : Consider simply getting an NTFS partition with a drive letter assigned

            $windowsPartition = $null
            try {
                Write-Verbose -Message 'Obtained partition table, searching for first non-system and non-UEFI partition which has an assigned drive letter'
                $windowsPartition = $partitions | Where-Object { 
                    ($_.GptType -ne [cVhdFileSystem]::GptTypeUEFISystem) -and 
                    ($_.GptType -ne [cVhdFileSystem]::GptTypeMicrosoftReserved) -and 
                    ([char]::IsLetter($_.DriveLetter[0])) 
                }
            } catch {
                throw [Exception]::new(
                    'Failed to get a partition meeting the criteria of a Windows boot drive',
                    $_.Exception
                )
            }

            if ($null -eq $windowsPartition) {
                #TODO : Generate error if there is more than one item returned.
                throw [Exception]::new(
                    'Failed to find a non-UEFI or Reserved partition'
                )
            }

            Write-Verbose -Message ('Windows partition found, resolving drive letter')
            $this.WindowsPartitionRoot = $windowsPartition.DriveLetter + ':\'
            Write-Verbose -Message ('Windows drive root is ' + $this.WindowsPartitionRoot)

            try {
                Write-Verbose -Message ('Making drive root accessible to other commandlets')
                $psDrive = New-PSDrive -Name $windowsPartition.DriveLetter -PSProvider FileSystem -Root $this.WindowsPartitionRoot 
                if ($null -eq $psDrive) {
                    throw [Exception]::new(
                        'Unknown error when trying to make drive accessible to other commandlets'
                    )
                }
            } catch {
                if ($_.Exception.Message.BeginsWith('Unknown')) {
                    throw $_.Exception
                }

                throw [Exception]::new(
                    'Failed to make drive accessible to other commandlets',
                    $_.Exception
                )
            }

            Write-Verbose -Message ('Drive root now accessible to other commandlets')
        } catch {
            Write-Error -Message ('Failed to complete mounting system drive of [' + $this.VHDPath + '] dismounting image')

            try {
                $vhd | Dismount-VHD 
            } catch {
                Write-Error -Message ('Failed to unmount VHD')
            }

            $this.WindowsPartitionRoot = $null

            throw [Exception]::new(
                'Failed to complete mounting and making [' + $this.VHDPath + '] accessible to other commandslet',
                $_.Exception
            )
        } 
    }

    [void] DismountVHDImage()
    {
        $vhd = $null
        try {
            Write-Verbose -Message ('Getting handle to the VHD file')
            $vhd = Get-Vhd -Path $this.VHDPath 
            if($null -eq $vhd) {
                throw [Exception]::new(
                    'Unknown error getting handle to the vhd'
                )
            }
        } catch {
            if($_.Exception.Message.BeginsWith('Unknown')) {
                throw $_.Exception
            }

            throw [Exception]::new(
                'Error obtaining VHD handle to ' + $this.VHDPath,
                $_.Exception
            )
        }

        try {
            Write-Verbose -Message 'Dismounting VHD'
            $vhd | Dismount-VHD
        } catch {
            throw [Exception]::new(
                'Failed to dismount [' + $this.VHDPath + ']',
                $_.Exception
            )
        }
    }
}
<#
This code is written and maintained by Darren R. Starr from Conscia Norway AS.

License :

Copyright (c) 2017 Conscia Norway AS AS Norway

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
        Powershell DSC Resource to convert Windows Server 2016 ISO images to VHD files

    .DESCRIPTION
        While it would not be difficult to extend this class to support more than simply deploying 
        Windows Server 2016 as a virtual machine image for use with Hyper-V, it would take little
        effort to extend this resource to support all the features of Convert-WindowsImage.ps1 as
        found on the ISO itself.

        This intention of this resource is to create a base VHD image that can be used by differencing
        images for rapid deployment of data center resources using other resources within this series
        of resources.

    .NOTES
        There are some issue I'm less than happy with in this code.
            <li>This code is non-reentrant</li>
            While this is generally an issue, due to a limitation with Mount-DiskImage, when an ISO
            is mounted, it is not really possible to mount the same image twice and not lose track of
            its mount points.
            <li>New-PSDrive isn't cleaned up</li>
            The New-PSDrive mounted in this code does not have any cleanup code associated with it and 
            it should.
            <li>Error handling on image dismount in case of error</li>
            There is a case where Dismount-DiskImage is called during a catch and is not properly handled.
#>
[DscResource()]
class cWindowsVHD 
{
    [DscProperty(Key)]
    [string] $VHDPath

    [DSCProperty(Mandatory)]
    [string] $ISOPath

    [DSCProperty()]
    [string] $Edition = 'SERVERDATACENTERCORE'

    [DscProperty()]
    [UInt64] $MaximumSizeBytes = 100GB

    hidden [string] $ISORoot

    <#
        .SYNOPSIS
            Resource Get
    #>
    [cWindowsVHD] Get()
    {
        [cWindowsVHD]$result = [cWindowsVHD]::new()

        $vhd = Get-VHD -Path $this.VHDPath
        $result.MaximumSizeBytes = $vhd.Size

        return $result
    }

    <#
        .SYNOPSIS
            Resource Test
    #>
    [bool] Test()
    {
        If (-not (Test-Path -Path $this.ISOPath)) {
            throw [System.ArgumentException]::new(
                ('ISO file [' + $this.ISOPath + '] is not present'),
                '$ISOPath'
            )
        }

        If (-not (Test-Path -Path $this.VHDPath)) {
            Write-Verbose -Message('VHD File [' + $this.VHDPath + '] not present')
            return $false
        }

        return $true
    }

    <#
        .SYNOPSIS
            Resource Set
    #>
    [void] Set()
    {
        Write-Verbose -Message ('Checking for a preexisting VHD [' + $this.VHDPath + '] file')
        If (Test-Path -Path $this.VHDPath) {
            throw ('VHD File [' + $this.VHDPath + '] is already present')
        }

        Write-Verbose -Message ('VHD does not exist, mounting ISO')
        $this.MountISO()

        try {
            Write-Verbose -Message ('Start conversion of Windows image to VHD')
            $this.ConvertWindowsImage()
        } catch {
            throw ('Windows image conversion failed', $_.Exception)
        } finally {
            $this.DismountISO()
        }
    }

    hidden [void] MountISO()
    {
        Write-Verbose -Message ('Testing for the presence of the ISO image [' + $this.ISOPath + ']')

        If (-not (Test-Path -Path $this.ISOPath)) {
            throw [System.ArgumentException]::new(
                ('ISO file [' + $this.ISOPath + '] is not present'),
                '$ISOPath'
            )
        }

        $mountIsoResult = $null
        try {
            Write-Verbose -Message ('Attempting to mount the ISO image [' + $this.ISOPath + ']')
            $mountIsoResult = Mount-DiskImage -ImagePath $this.ISOPath -PassThru
        } catch {
            throw [Exception]::New(
                'Failed to mount Windows ISO [' + $this.ISOPath + ']',
                $_.Exception
                )
        }

        try {
            Write-Verbose -Message ('ISO mounted, getting mount information (compensate for possible powershell bug in Mount-DiskImage)')
            # TODO : Refresh variable... might be a bug... see Convert-WindowsImage.
            $mountIsoResult = Get-DiskImage -ImagePath $this.ISOPath

            Write-Verbose -Message ('Attempting to get drive letter of where the ISO was mounted')
            $driveLetter = ($mountIsoResult | Get-Volume).DriveLetter

            $this.ISORoot = "$($driveLetter):\"
            Write-Verbose -Message ('The drive where the ISO is mounted is -> ' + $this.ISORoot)

            Write-Verbose -Message ('Attempting to register ' + $this.ISORoot + ' so that it may be accessible to Powershell')
            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $this.ISORoot
        } Catch {
            Write-Verbose -Message ('Failed to complete making ISO accessible. Dismounting ISO')
            # TODO : Should I add an exception to the dismount operation?
            Dismount-DiskImage -ImagePath $this.ISOPath

            $this.ISORoot = $null

            throw [Exception]::new(
                'The Windows ISO Image [' + $this.ISOPath + '] mounted successfully but a drive letter could not be obtained',
                $_.Exception
            )
        }

        Write-Verbose -Message ('ISO mounted and accessible at [' + $this.ISORoot + ']')

        $this.ISORoot = 'C:\Temp\Windows Server 2016'

        Write-Verbose -Message ('ISO mounted and accessible at [' + $this.ISORoot + '] (test code)')
    }

    hidden [void] DismountISO()
    {
        try {
            Write-Verbose -Message ('Getting mount information as to where ISO [' + $this.ISOPath + '] is mounted')
            # TODO : Refresh variable... might be a bug... see Convert-WindowsImage.
            $mountIsoResult = Get-DiskImage -ImagePath $this.ISOPath

            Write-Verbose -Message ('Attempting to get drive letter of where the ISO was mounted')
            $driveLetter = ($mountIsoResult | Get-Volume).DriveLetter

            $this.ISORoot = "$($driveLetter):\"
            Write-Verbose -Message ('The drive where the ISO is mounted is -> ' + $this.ISORoot)

#            Write-Verbose -Message ('Attempting to register ' + $this.ISORoot + ' so that it may be accessible to Powershell')
#            New-PSDrive -Name $driveLetter -PSProvider FileSystem -Root $this.ISORoot

            # TODO : Delete PS drive?

            Write-Verbose -Message ('Attempting to dismount ISO image')
            Dismount-DiskImage -ImagePath $this.ISOPath

            $this.ISORoot = $null
        } Catch {
            throw [Exception]::new(
                'The Windows ISO Image [' + $this.ISOPath + '] failed to dismount',
                $_.Exception
            )
        }        
    }

    hidden [void] ConvertWindowsImage()
    {
        $convertWindowsImageScriptPath = Join-Path -Path $this.ISORoot -ChildPath 'NanoServer\NanoServerImageGenerator\Convert-WindowsImage.ps1'
        $installWimPath = Join-Path -Path $this.ISORoot -ChildPath 'sources\install.wim'
        $temporaryConversionPath = Join-Path -Path $env:TEMP -ChildPath 'ConvertWindowsImage'

        if(-not (Test-Path -Path $convertWindowsImageScriptPath)) {
            throw [System.IO.FileNotFoundException]::new('Is this not a Windows Server 2016 ISO?', $convertWindowsImageScriptPath)
        }

        if(-not (Test-Path -Path $installWimPath)) {
            throw [System.IO.FileNotFoundException]::new('The Windows ISO may be invalid', $installWimPath)
        }

        if(Test-Path -Path $temporaryConversionPath) {
            Write-Verbose -Message ('The path [' + $temporaryConversionPath + '] is already present, attempting to remove it first')
            try {
                Remove-Item -Path $temporaryConversionPath -Recurse -Force -Confirm:$false
            } catch {
                throw [System.IO.IOException]::new('Failed to delete [' + $temporaryConversionPath + ']. This directory should not be present before using this function', $_.Exception)
            }
        }

        # TODO : The following should not be necessary, but I'm not convinced that Remove-Item will throw an exception properly
        if(Test-Path -Path $temporaryConversionPath) {
            throw ('Failed to delete [' + $temporaryConversionPath + ']. This directory should not be present before using this function')
        }

        try {
            Write-Verbose -Message ('Creating temporary path [' + $temporaryConversionPath + '] to use for image conversion operations')
            New-Item -Path $temporaryConversionPath -Confirm:$false -ItemType Directory -Force
        } catch {
            throw [Exception]::new('Failed to create path [' + $temporaryConversionPath + ']. Cannot continue', $_.Exception)
        }

        . $convertWindowsImageScriptPath

        $Params = @{
                SourcePath = $installWimPath
                Edition = $this.Edition 
                VHDPath = $this.VHDPath
                TempDirectory = $temporaryConversionPath 
                SizeBytes = $this.MaximumSizeBytes 
                VHDFormat = 'VHDX'
                DiskLayout = 'UEFI'
            }

        # Write-Verbose -Message ('-SourcePath ''' + $installWimPath + ''' -Edition ''' + $this.Edition + ''' -VHDPath ''' + $this.VHDPath + ''' -TempDirectory ''' + $temporaryConversionPath + ''' -VHDFormat VHDX -DiskLayout UEFI' )

        Write-Verbose -Message ('Initiating ISO to VHD conversion')
        Convert-WindowsImage @Params -Passthru 

        Write-Verbose -Message ('Conversion complete, removing temporary directory')
        try {
            Remove-Item -Path $temporaryConversionPath -Recurse -Force -Confirm:$false
        } catch {
            throw [System.IO.IOException]::new('Failed to delete [' + $temporaryConversionPath + ']. This directory should be removed before continuing', $_.Exception)
        }
    }
}

