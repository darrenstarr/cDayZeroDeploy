# cVHDFileSystem
[cVHDFileSystem](https://github.com/darrenstarr/cDayZeroDeploy/tree/master/DSCResources/cVHDFileSystem) is similar to [xVhdFileDirectory](https://github.com/PowerShell/xHyper-V/tree/dev/DSCResources/MSFT_xVhdFileDirectory) from [xHyper-V](https://github.com/PowerShell/xHyper-V). It mounts a VHD image and copies files or directories to a destination within the VHD and then unmounts it.

Since this is meant to be used for a special case which is to perform an initial file transfer to a new differencing image, there are some built-in "outs" in the sense that the test function doesn't simply reopen the file and compare the VHD file system to the list of files to copy. It can also check to see if the VHD file is already mounted or if the VHD file is over a certain size. This means that in the case of transferring things like unattend.xml to the image which will be deleted in the end, the test will still pass and therefore artificially be idempotent.

## Parameters
### [string] VHDPath (mandatory/key)
The path to VHD file to be modified. The file extension must be '.vhdx'
### [bool] OkIfMounted(optional, default value = $true)
If the file is already mounted, then the test will simply pass and therefore not try editing the image again
### [UInt64] OkIfOverBytes(optional, default value = 4MB)
If the size of the file is more than this value, then the test will immediately pass. The default value of 4MB was chosen because the initial size of a VHDX differencing file is precisely 4MB. Immediately after mounting and closing the image, the size of the image will grow. The risk with this is that if there was a failure copying files during the first use, this test will automatically pass and the problem will remain. Additional verification may be needed. A value of zero bytes means this option would be disabled.
### [string[]] ItemList(mandatory)
This is a list of string pairs formatted as SourcePath, DestinationRelativePath, SourcePath, DestinationRelativePath, etc... A source path can be a file or a directory. This resource DOES NOT create directories, so the parent directory of any file or directory must be present beforehand or the function will fail. At this time, there are no permissions set on files or directories within the image.

## Exceptions (Throws)
* System.Exception for when there are cases for which there are no standard .NET exceptions
* System.IO.FileNotFoundException for when files (the parent VHD) is missing
* System.ArgumentException when arguments/parameters are incorrect
* System.ArgumentNullException when arguments which should be null aren't
* System.IO.DirectoryNotFoundException when the parent folder objects to be copied are not present

## Example

```
Configuration cVHDFileSystem_Example {
    param(
        [string[]]$ComputerName="localhost"
    )
    
    Import-DscResource -ModuleName cDayZeroDeploy

    node $ComputerName {
        cVHDFileSystem BasicTest {
            VHDPath = $Node.VHDPath
            ItemList = @(
                ($Node.TestFile), '\teapot.txt'
            )
        }
    }
}

$configData = @{
    AllNodes = @(
        @{
            NodeName       = 'localhost'
            VHDPath        = (Join-Path -Path $Env:TEMP -ChildPath 'testwindowsvhd2.vhdx')
            TestFile = (Join-Path -Path $Env:TEMP -ChildPath 'testfile.txt')
       }
    )
}

Set-Content -Path $configData.AllNodes[0].TestFile -Value 'I''m a little teapot short and stout'
```
