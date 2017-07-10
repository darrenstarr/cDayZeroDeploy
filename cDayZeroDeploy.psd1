@{

RootModule = '.\cDayZeroDeploy.psm1'

DscResourcesToExport = @('cDifferencingVHD', 'cGuestRegistryKey', 'cUnattendXml', 'cVHDFileSystem', 'cWindowsVHD')

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

} 
