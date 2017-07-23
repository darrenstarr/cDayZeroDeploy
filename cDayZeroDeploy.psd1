@{

RootModule = '.\cDayZeroDeploy.psm1'

DscResourcesToExport = @(
        'cNATRule',
        'cDifferencingVHD', 
        'cGuestRegistryKey', 
        'cUnattendXml', 
        'cVHDFileSystem', 
        'cWindowsVHD',
        'cDeployWindowsVM'
    )

# Version number of this module.
ModuleVersion = '1.0.0'

# ID used to uniquely identify this module
GUID = 'c6782bd1-33b3-4f05-87a6-79e3759ef0c6'

# Author of this module
Author = 'Darren R. Starr'

# Company or vendor of this module
CompanyName = 'Conscia Norway AS'

# Copyright statement for this module
Copyright = '(c) 2017 Conscia Norway AS. All rights reserved.'

# Description of the functionality provided by this module
Description = 'DSC Resources to facilitate day zero deployment of a Windows datacenter'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = 'https://github.com/darrenstarr/cDayZeroDeploy/blob/master/LICENSE'

        # A URL to the main website for this project.
        # ProjectUri = 'https://github.com/darrenstarr/cDayZeroDeploy'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

} 
