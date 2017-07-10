# Powershell Verification
## A place for where I document problems with Powershell DSC

### tSample1
There are currently 3 verification tests in the tSample1 directory.

##### Update
I have submitted this sample as an issue at the [Powershell Github issue tracker](https://github.com/PowerShell/PowerShell/issues/4206) and [Michael Klement](https://github.com/mklement0) and he's been assisting me in learning that my use of $null for default parameters is actually considered abuse in Powershell. This means I'll have to rewrite chunks of my code to make this work. Let's see where I get to with this.

#### First test (control)
The first test which is 'tSample1.Integration.Tests.ps1' proves that the $Name property is properly passed from normal configuration data to the resource and that the $null value for $OptionalParameter is passed as a $null value.

#### Second test
The second test which is tSample1Composite.Integration.Tests.ps1' proves that a composite resources are used, optional parameters (even when pulled to $null which is not necessary) do not set themselves to $null. When passed through, the parameter $OptionalParameter if it is a string value becomes a zero-length string. If $OtherOptionalProperty is an integer, it becomes an integer with a zero value

Another oddity displayed by this test is that $using:Name in a 'Script' resource from resource module PSDesiredStateConfiguration has a namespace conflict. As $Name is an important value to use when creating a composite DSC resource, this conflict is a real problem. 

#### Third test
The third test is tSample1CompositeConfigData.Integration.Tests.ps1. This displays more or less the same behavior as the second test but makes use of a config data hash table.

#### Fourth test
The fourth test is tSample1DifferentComposite.Integration.Tests.ps1, This displays that even when we use the composite resource as a configuration itself, it still has the same problems as a DSC composite resource when handling optional parameters.
