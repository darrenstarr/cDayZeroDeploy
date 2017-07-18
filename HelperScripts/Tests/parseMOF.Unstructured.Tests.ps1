
$oldPSModulePath = $env:PSModulePath

$rootModulePath = Join-Path -Path $PSScriptRoot -ChildPath '../../..' -Resolve
$env:PSModulePath = $rootModulePath + ';' + $env:PSModulePath

try {

    Configuration Bob {
        Import-DscResource -ModuleName 'cDayZeroDeploy'
        Import-DscResource -ModuleName 'PSDesiredStateConfiguration'

        Node localhost {
            WindowsFeature Stuart {
                Name = 'Kevin'
                Ensure = 'Present'
            }

            cDeployWindowsVM Minions {
                VHDPath                     = 'dave.vhdx'
                ParentVHDPath               = 'davedaddy.vhdx'
                UnattendXMLPath             = 'dave.unattend.xml'
                VMName                      = 'Dave'
                StartupMemory               = 512MB
                SwitchName                  = 'MinionsVSwitch'

                DNSServers                  = ('8.8.8.8', '8.8.4.4')            

                ReadyRegistryKeyName        = 'SystemStatus'
                ReadyRegistryKeyValue       = 'Ready'                
            }
        }
    }

    Bob -OutputPath '.\TestData' 

} catch {

} finally {
    $env:PSModulePath = $oldPSModulePath
}

. (Join-Path -Path $PSScriptRoot -ChildPath '..\parseMOF.ps1') 

Get-DSCResourceDependenciesFromMOF -MOFPath (Join-Path -Path $PSScriptRoot -ChildPath 'TestData\localhost.mof')




