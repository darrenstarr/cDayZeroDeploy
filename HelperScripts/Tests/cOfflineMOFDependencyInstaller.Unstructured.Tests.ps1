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

Clear-Host

$oldPSModulePath = $env:PSModulePath

$rootModulePath = Join-Path -Path $PSScriptRoot -ChildPath '../../..' -Resolve
$env:PSModulePath = $rootModulePath + ';' + $env:PSModulePath

try {

    Configuration Bob {
        Import-DscResource -ModuleName 'cDayZeroDeploy'
        Import-DscResource -ModuleName 'PSDesiredStateConfiguration'
        Import-DscResource -ModuleName 'xActiveDirectory'

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

            xADDomain InstalActiveDirectoryFeature {
                DomainName = 'minions.org'
                DomainAdministratorCredential = New-Object System.Management.Automation.PSCredential ('teddybear', (ConvertTo-SecureString 'Pookie' -AsPlainText -Force))
                SafeModeAdministratorPassword = New-Object System.Management.Automation.PSCredential ('dog', (ConvertTo-SecureString 'Odie' -AsPlainText -Force))
                DomainNetBIOSName = 'MINIONS'
            }

            Script Bob {
                GetScript = {
                    return $null
                }

                SetScript = {
                }

                TestScript = {
                    Get-ChildItem -Path (Join-Path -Path $Env:WINDIR -ChildPath 'system32\drivers\etc')
                    $im = @"
a little
teapot short
and stout
"@
                    return $false
                }
            }
        }
    }

    $configData = @{
        AllNodes = @(
            @{
                NodeName                    = 'localhost'
                PsDscAllowPlainTextPassword = $true            
                PSDscAllowDomainUser        = $true
            }
        )
    }

    Bob -OutputPath (Join-Path -Path $PSScriptRoot -ChildPath 'TestData') -ConfigurationData $configData

} catch {
    Write-Verbose -Message 'Oops : ' + $_.Exception.Message
} finally {
    $env:PSModulePath = $oldPSModulePath
}

$TestDataPath = Join-Path -Path $PSScriptRoot -ChildPath 'TestData'

$MOFPath = Join-Path -Path $TestDataPath -ChildPath 'localhost.mof'
$VHDRootFile = Join-Path -Path $TestDataPath -ChildPath 'VHDWhatever.vhdx'

$vhd = New-VHD -Path $VHDRootFile -Differencing -ParentPath (Join-Path -Path $env:Temp -ChildPath 'testwindowsvhd.vhdx')
$mountResult = $vhd | Mount-VHD -Passthru

$VerbosePreference = 'Continue'
try {
    $disk = $mountResult | Get-Disk 
    $partition = $disk | Get-Partition | Where-Object { [Char]::IsLetter($_.DriveLetter) }
    New-PSDrive -Root ('{0}:\' -f $partition.DriveLetter) -Name $partition.DriveLetter -PSProvider FileSystem 

    $VHDRoot = ('{0}:\' -f $partition.DriveLetter)

    $sourceText = `
        (Get-Content -raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\MOFUtilities\parseMOF.ps1')) + "`n" +
        (Get-Content -raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\MOFUtilities\cDSCResourceManifestItem.ps1')) + "`n"  +
        (Get-Content -raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\MOFUtilities\cDSCResourceInformation.ps1')) + "`n"  +
        (Get-Content -raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\MOFUtilities\cOfflineMOFDependencyInstaller.ps1')) + "`n"  + 
@"
`$VerbosePreference = 'Continue'
[cOfflineMOFDependencyInstaller]::CopyMOFDependencies('$MOFPath', '$VHDRoot')
"@

    Set-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath 'TestData\hmm.ps1') -Value $sourceText

    Invoke-Expression -Command $sourceText -Verbose
} catch {
    Write-Host $_.Exception.Message
} finally {
    $vhd | Dismount-VHD
    Remove-Item -Path $VHDRootFile -Force
}
