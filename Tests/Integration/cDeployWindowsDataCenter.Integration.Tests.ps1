#requires -Version 5.0 -Modules Pester

$script:DSCModuleName = 'cDayZeroDeploy'
$script:DSCResourceName = 'cDeployWindowsDataCenter'

#region Header
Clear-Host
$ModuleRoot = Split-Path -Path $Script:MyInvocation.MyCommand.Path -Parent | Split-Path -Parent | Split-Path -Parent

if (
    (-not (Test-Path -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'DSCResource.Tests') -PathType Container)) -or
    (-not (Test-Path -Path (Join-Path -Path $script:ModuleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -PathType Leaf))
)
{
    (& git @('clone', 'https://github.com/PowerShell/DscResource.Tests.git', (Join-Path -Path $ModuleRoot -ChildPath 'DSCResource.Tests'))) 2> $null
}
else
{
    & git @('-C', (Join-Path -Path $ModuleRoot -ChildPath 'DSCResource.Tests'), 'pull')
}

Import-Module -Name (Join-Path -Path $ModuleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force

$TestEnvironment = Initialize-TestEnvironment -DSCModuleName $script:DSCModuleName -DSCResourceName $script:DSCResourceName -TestType Integration

Import-Module -Name 'cDayZeroDeploy' -Force

#endregion

# Begin Testing
try
{
    #region Integration Tests

    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).Config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Integration - Ensure is set to Enabled" {
        BeforeAll {

            $DomainNetBIOSName = 'MINIONS'
            $DomainAdminName = $DomainNetBIOSName + '\Administrator'
            $DomainAdminPassword = 'Minions8675309'

            $DomainAdminSecurePassword = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
            $DomainAdminCreds = New-Object System.Management.Automation.PSCredential ($DomainAdminName, $DomainAdminSecurePassword)

            $SafeModeAdminCreds = New-Object System.Management.Automation.PSCredential ('SafeMode', $DomainAdminSecurePassword)

            $configData = @{
                AllNodes = @(
                    @{
                        NodeName                    = 'AD1'
                        Roles                       = @('WindowsServer', 'ActiveDirectory', 'PrimaryAD')
                        VMName                      = 'MinionsAD1'
                        VHDPath                     = (Join-Path -Path $Env:TEMP -ChildPath 'minionsad1.vhdx')
                        UnattendXmlPath             = (Join-Path -Path $Env:TEMP -ChildPath 'minionsad1unattend.xml')
                        IPAddress                   = '10.1.0.220'
                        DNSServers                   = @('8.8.8.8')
                        PsDscAllowPlainTextPassword = $true            
                        PSDscAllowDomainUser        = $true
                    },

                    @{
                        NodeName                    = 'CARoot'
                        Roles                       = @('WindowsServer', 'CertificateServer', 'RootCA')
                        VMName                      = 'MinionsRootCA'
                        VHDPath                     = (Join-Path -Path $Env:TEMP -ChildPath 'minionsrootca.vhdx')
                        UnattendXmlPath             = (Join-Path -Path $Env:TEMP -ChildPath 'minionsrootcaunattend.xml')
                        IPAddress                   = '10.1.0.221'
                        DNSServers                  = '10.1.0.220'
                        PsDscAllowPlainTextPassword = $true            
                        PSDscAllowDomainUser        = $true
                    }
                )
                
                DomainInformation = @{
                    BaseWindowsVHD                  = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd.vhdx')
                    SubnetLength                    = 24
                    DefaultGateway                  = '10.1.0.1'
                    ADDomain                        = 'minions.org'
                    SwitchName                      = 'DemoLabSwitch'
                    LocalAdministratorPassword      = $DomainAdminPassword
                    RegisteredOwner                 = 'Bob'
                    RegisteredOrganization          = 'Minions will take over Inc.'
                    DomainAdministratorCredential   = $DomainAdminCreds
                    SafeModeAdministratorPassword   = $SafeModeAdminCreds
                    DomainNetBIOSName               = $DomainNetBIOSName
                }
            }

            foreach($node in $configData.AllNodes) {
                try {
                    $vm = Get-VM -Name ($node.VMName) -ErrorAction SilentlyContinue
                    if($null -ne $vm) {
                        Stop-VM -VM $vm -Force -TurnOff 
                        $vm.ConfigurationLocation
                        Remove-VM -VM $vm -Force -Confirm:$false 
                    }
                } catch {}

                If (Test-Path -Path $node.VHDPath) {
                    Remove-Item -Path $node.VHDPath -Force
                }

                If (Test-Path -Path $node.UnattendXmlPath) {
                    Remove-Item -Path $node.UnattendXmlPath -Force
                }
            }
        }

        Context 'InitialTest' {
            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    Write-Host $TestDrive
                    Write-Host "$configData"
                    Write-Host "$($script:DSCResourceName)_Config"
                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData `
                        -ComputerName localhost `
                        -MOFPath $TestDrive

                    Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
                } | Should Not Throw
            }

#            It 'Should be able to call Get-DscConfiguration without throwing' {
#                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not Throw
#            }
            #endregion
        }

        AfterAll {
#           try {
#               $vm = Get-VM -Name ($configData.AllNodes[0].VMName) 
#               if($null -ne $vm) {
#                   Stop-VM -VM $vm -Force -TurnOff 
#                   $vm.ConfigurationLocation
#                   Remove-VM -VM $vm -Force -Confirm:$false 
#               }
#           } catch {}
#            If (Test-Path -Path $configData.AllNodes[0].VHDPath) {
#                Remove-Item -Path $configData.AllNodes[0].VHDPath -Force
#            }
#            If (Test-Path -Path $configData.AllNodes[0].UnattendXmlPath) {
#                Remove-Item -Path $configData.AllNodes[0].UnattendXmlPath -Force
#            }
        }
    }
    #endregion
}
finally
{
    #region Footer

    Restore-TestEnvironment -TestEnvironment $TestEnvironment

    #endregion
}
