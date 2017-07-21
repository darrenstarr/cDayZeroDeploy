# MOFUtilities
## Introduction
MOFUtilities contains a few components of interest.

### parseMOF.ps1
This file contains a basic MOF file parser which I use for extracting module dependencies from MOFs generated from running DSC Configurations. The code is based on a PEG parser I wrote because I didn't like the idea of using a regular expression to attempt to extract module dependencies as there could be dependencies nested in strings or comments. As a result, this code is a full, hand-coded recursive descent parser. I did not use the [MOF specification](https://www.dmtf.org/sites/default/files/standards/documents/DSP0221_3.0.0.pdf) as it would have been too much work to implement in the timeframe I was working on. I will make an attempt at a later point if it is necessary to do so. As I did not have a PEG generator for PowerShell, I hand coded the full parser. If I extend the parser, I'll implement a PEG generator instead as it would likely be too much work to hand code 56 pages worth of a language grammar by hand.

### cOfflineMOFDependencyInstaller
This is a class which, when passed a MOF file and the root directory of a Windows VHD file for a virtual machine will copy all the files required for the dependencies the MOF needs. So, it uses parseMOF.ps1 to list the dependencies and then finds the modules and files required to use the MOF, then it copies the files. This is very useful for performing an offline installation of DSC resources to a VHD. 