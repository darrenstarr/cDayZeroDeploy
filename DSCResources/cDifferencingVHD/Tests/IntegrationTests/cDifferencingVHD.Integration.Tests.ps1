#requires -Version 5.0 -Modules Pester

$script:DSCModuleName = 'cDifferencingVHD'
$script:DSCResourceName = 'cDifferencingVHD'

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

#endregion

# Begin Testing
try
{
    #region Integration Tests

    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).Config.ps1"
    . $ConfigFile

    Describe "$($script:DSCResourceName)_Integration - Ensure is set to Enabled" {
        BeforeAll {

            $configData = @{
                AllNodes = @(
                    @{
                        NodeName                    = 'localhost'
                        PsDscAllowDomainUser        = $true
                        PsDscAllowPlainTextPassword = $true
                        VHDPath                     = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd2.vhdx')
                        ParentVHDPath               = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd.vhdx')
                    }
                )
            }

            If (Test-Path -Path $configData.AllNodes[0].VHDPath) {
                Remove-Item -Path $configData.AllNodes[0].VHDPath -Force
            }
        }

        Context 'InitialTest' {
            #region DEFAULT TESTS
            It 'Should compile and apply the MOF without throwing' {
                {
                    Write-Host "$configData"
                    Write-Host "$($script:DSCResourceName)_Config"
                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData `
                        -ComputerName localhost

                    Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
                } | Should Not Throw
            }

            It 'Should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not Throw
            }
            #endregion
        }

        AfterAll {
            If (Test-Path -Path $configData.AllNodes[0].VHDPath) {
                Remove-Item -Path $configData.AllNodes[0].VHDPath -Force
            }
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
