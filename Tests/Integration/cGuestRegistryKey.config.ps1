Configuration cGuestRegistryKey_Config {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy
    Import-DscResource -ModuleName xHyper-V

    node $ComputerName {
        cDifferencingVHD VMDisk {
            VHDPath = $Node.VHDPath
            ParentVHDPath = $Node.ParentVHDPath
        }

        cUnattendXml UnattendXml {
            Path = $Node.UnattendXmlPath
            LocalAdministratorPassword = 'Minions12345'
            RegisteredOwner = 'Bob'
            RegisteredOrganization = 'Minions will take over Inc.'
            ReadyRegistryKeyName = 'SystemStatus'
            ReadyRegistryKeyValue = 'Ready'
        }

        cVHDFileSystem VHDFileSystem {
            VHDPath = $Node.VHDPath
            ItemList = @(
                ($Node.UnattendXmlPath), 'unattend.xml'
            )
            DependsOn = @('[cDifferencingVHD]VMDisk', '[cUnattendXml]UnattendXml')
        }

        xVMHyperV ActiveDirectoryVM {
            Ensure        = 'Present'
            Name          = 'TestVM'
            VhdPath       = $Node.VHDPath
            Generation    = 2
            StartupMemory = 1GB
            MinimumMemory = 512MB
            MaximumMemory = 4GB
            ProcessorCount = 2
            State = 'Running'
            SecureBoot = $true
            DependsOn     = @('[cVHDFileSystem]VHDFileSystem')
        }

        cGuestRegistryKey BasicTest {
            VMName = 'TestVM'
            KeyName = 'SystemStatus'
            KeyValue = 'Ready'
            DependsOn = @('[xVMHyperV]ActiveDirectoryVM')
        }
    }
}
