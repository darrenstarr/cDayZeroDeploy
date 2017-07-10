
[string]$content = ''

$content += (Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\DSCResources\cUnattendXml\Classes\UnattendXml.ps1')).TrimEnd() + "`n"
$content += (Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\DSCResources\cUnattendXml\Classes\cUnattendXml.ps1')).TrimEnd() + "`n"

$content += (Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\DSCResources\cDifferencingVHD\cDifferencingVHD.psm1')).TrimEnd() + "`n"
$content += (Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\DSCResources\cGuestRegistryKey\cGuestRegistryKey.psm1')).TrimEnd() + "`n"
$content += (Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\DSCResources\cVHDFileSystem\cVHDFileSystem.psm1')).TrimEnd() + "`n"
$content += (Get-Content -Raw -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\DSCResources\cWindowsVHD\cWindowsVHD.psm1')).TrimEnd() + "`n"

Set-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\cDayZeroDeploy.psm1') -Value $content