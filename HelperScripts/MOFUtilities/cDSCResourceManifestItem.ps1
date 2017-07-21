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
        Container for storing information about files to be copied from a host system to a VHD

    .DESCRIPTION
        This component is part of the MOFUtilities which can be used to copy DSC Resources in an offline
        fashion from a host computer to a .VHDX file for the purpose of making a MOF file able to run
        before network connectivity is established for a VM.
#>
class cDSCResourceManifestItem
{
    <#
        .SYNOPSIS
            A file system reference to the source file or directory item to be copied
    #>
    [System.IO.FileSystemInfo]$Item

    <#
        .SYNOPSIS
            A path to the item relative to the root of the DSC resource it belongs to
    #>
    [string]$RelativePath

    <#
        .SYNOPSIS
            The recommendation of where to copy the file relative to the root of the VHDX file
    #>
    [string]$RecommendedDestinationPath
}
