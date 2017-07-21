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


$sourceText = `
    (Get-Content -raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\MOFUtilities\parseMOF.ps1')) + "`n" +
@"
Get-DSCResourceDependenciesFromMOF -MOFPath (Join-Path -Path $PSScriptRoot -ChildPath 'TestData\localhost.mof')
"@

#Set-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'TestData\hmm.ps1') -Value $sourceText

$result = Invoke-Expression -Command $sourceText
