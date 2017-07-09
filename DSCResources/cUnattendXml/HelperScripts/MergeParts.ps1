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
        A container to hold information about source files while they're being compiled by ClassFileScripts
#>
class ClassFileScript {
    [string] $ScriptFile
    [string[]] $DependencyScriptFiles
    [string] $SourceText
}

<#
    .SYNOPSIS
        A compiler which reads the contents of a module directory and compiles them into a single script

    .DESCRIPTION
        When included in a class file module beneath the directory 'HelperScripts' it can be called from
        within the PSD file of the module to traverse the contents of the 'Classes' subdirectory to produce
        a PSM file as specified within the PSD file of the project. Dependencies are noted within the source
        class files as comments formatted as follows :
            &lt;# DependsOn '.\filename.ps1' #&gt;
#>
class ClassFileScripts {
    [ClassFileScript[]] $Children = @()

    [string] $ModuleRoot

    [string] $CompiledText
    [string[]] $IncludedScripts

    <#
        .SYNOPSIS
            Constructure

        .PARAMETER moduleRoot
            The root path of the module.
    #>
    ClassFileScripts([string]$moduleRoot)
    {
        $this.ModuleRoot = $moduleRoot
    }

    <#
        .SYNOPSIS
            The script compiler. It traverses the Classes subdirectory within the project, identifies dependencies and compiles a new PSM

        .DESCRIPTION
            Given a valid module, the compiler will scan all the ps1 files within the Classes subdirectory, extract references to
            dependencies in specially formatted comments, test each file for vertical constraints that can result in cyclic redundancies,
            then generates a 'compiled text' containing the contents of all the files in the correct order
    #>
    [void]Compile() {
        $this.CompiledText = ''
        $this.IncludedScripts = @()

        $moduleName = $this.GetModuleName()
        Write-Verbose -Message ('Module name = ' + $moduleName)

        $psdFile = Join-Path -Path $this.ModuleRoot -ChildPath ($moduleName + '.psd1')
        Write-Verbose -Message ('Module manifest file = ' + $psdFile)

        $psmFile = $this.GetRootModuleFromManifest($psdFile)
        Write-Verbose -Message ('Root module file path = ' + $psmFile)

        $this.CompileFiles()

        [System.IO.File]::WriteAllText($psmFile, $this.CompiledText)
    }

    <#
        .SYNOPSIS
            Read the contents of a PSD file and return the PSM file specified as the root module PSM within the configuration

        .NOTES
            This is by far the worst code in the compiler as it blindly runs the PSD1 using Invoke-Expression and assumes that
            either the RootModule clause is present or that throwing a meaningless exception will be good enough.
    #>
    hidden [string] GetRootModuleFromManifest([string]$psdFile)
    {
        [string] $content = Get-Content -Path $psdFile -raw
        $expressionResult = Invoke-Expression -Command $content
        return [ClassFileScripts]::JoinPath($this.ModuleRoot, $expressionResult.RootModule)
    }

    <#
        .SYNOPSIS
            Returns the name of the module

        .NOTES
            This function works by simply extracting the name of the module directory. It would be better to traverse
            the module root, find a PSD1 file and read the module name from the PSD. Although, this function wouldn't be
            needed if simply finding the PSD1 within the root of the module were satisfactory 
    #>
    hidden [string] GetModuleName()
    {
        return Split-Path -Path $this.ModuleRoot -Leaf
    }

    <#
        .SYNOPSIS
            Generate the finished text
    #>
    hidden [void] CompileFiles()
    {
        $this.PopulateChildren()
        $this.VerifyDependencies()

        foreach($classFile in $this.Children) {
            $this.CompileFile($classFile)
        }
    }

    <#
        .SYNOPSIS
            Compile a single file

        .NOTES
            This function is idempotent with regards of itself. It scans to see if all dependencies have been
            added and then checks to see if it also has been added. The result being that if any files are
            already in the output, they are not places there again.
    #>
    hidden [void] CompileFile([ClassFileScript]$file)
    {
        foreach($dependency in $file.DependencyScriptFiles) {
            $dependencyFile = $this.Children | Where-Object { $_.ScriptFile -eq $dependency }
            $this.CompileFile($dependencyFile)
        }

        $included = $this.IncludedScripts | Where-Object { $_ -eq $file.ScriptFile }
        if ($null -ne $included) {
            return
        }

        Write-Verbose -Message ('Including ' + $file.ScriptFile)
        $this.CompiledText += $file.SourceText.TrimEnd() + "`n"
        $this.IncludedScripts += $file.ScriptFile
    }

    <#
        .SYNOPSIS
            Run dependency tests on each file to ensure their dependencies are present, part of the module and have no cyclic dependencies
    #>
    hidden [void] VerifyDependencies() 
    {
        foreach($classFile in $this.Children) {
            $result = $this.GetDependencies($classFile)

            Write-Verbose -Message ($classFile.ScriptFile + ' depends on ')
            foreach($dependency in $result) {
                Write-Verbose -Message ('    [' + $dependency + ']')
            }
        }

        Write-Verbose -Message 'Dependencies appear to be ok'
    }

    <#
        .SYNOPSIS
            Run dependency tests on a file to ensure its dependencies are present, part of the module and have no cyclic dependencies
    #>
    hidden [string[]] GetDependencies([ClassFileScript]$classFile)
    {
        [string[]] $dependsOn = @()
        foreach($dependency in $classFile.DependencyScriptFiles) {
            $dependsOn += $dependency

            $parent = $this.Children | Where-Object { $_.ScriptFile -eq $dependency }

            if ($null -eq $parent) {
                throw [Exception]::new(
                    'Script [' + $classFile.ScriptFile + '] depends on [' + $dependency + '] which is not part of this module'
                )
            }

            $parentDependencies = $this.GetDependencies($parent)

            if(($null -ne $parentDependencies) -and ($parentDependencies.Count -gt 0)) {
                $constraint = $parentDependencies | Where-Object { $_ -eq $classFile.ScriptFile }
                if ($null -ne $constraint) {
                    throw [Exception]::new(
                        'Script [' + $classFile.ScriptFile + '] depends on [' + $constraint + '] which causes a cyclic redundancy on itself'
                    )
                }

                $dependsOn += $parentDependencies
            }
        }

        if($dependsOn.Count -eq 0) {
            return $null
        }

        return $dependsOn
    }

    <#
        .SYNOPSIS
            Recursively scan the '/Classes' directory, find all source files and extract dependencies 
    #>
    hidden [void]PopulateChildren()
    {
        $classRoot = Join-Path -Path $this.ModuleRoot -ChildPath 'Classes'
        Write-Verbose -Message ('classRoot = ' + $classRoot)

        $classFileInfo = Get-ChildItem -Path $classRoot -Recurse | Where-Object {
            ($_.GetType().Name -eq 'FileInfo') -and ($_.Extension.ToLower() -eq '.ps1')
        }

        foreach($item in $classFileInfo) {
            Write-Verbose -Message ('Class file [' + $item.FullName + ']')

            $newClass = [ClassFileScript]::new()
            $newClass.ScriptFile = $item.FullName

            $newClass.SourceText = Get-Content -Path $item.FullName -Raw

            $matches = [RegEx]::Matches($newClass.SourceText, '<#\s*DependsOn\s+''(?<dependsOn>[^'']+)''\s*#>')

            if(($null -ne $matches) -and ($matches.Count -gt 0)) {
                foreach($match in $matches) {
                    if($match.Groups.Count -ne 2) {
                        throw [Exception]::new(
                            'Unexpected condition, the current version supports a single dependency per dependson statement'
                        )
                    }

                    $dependsOnGroup = $match.Groups['dependsOn']
                    if($null -eq $dependsOnGroup) {
                        throw [Exception]::new(
                            'Unexpected condition, the regular expression did not return a ''dependsOn'' match'
                        )
                    }

                    $dependencyScriptFile = [ClassFileScripts]::JoinPath($item.Directory.FullName, $dependsOnGroup.Value)

                    if (-not (Test-Path -Path $dependencyScriptFile)) {
                        throw [System.IO.FileNotFoundException]::new(
                            'Source file [' + $item.FullName + '] refers to a dependency that is not present',
                            $dependencyScriptFile
                        )
                    }

                    $newClass.DependencyScriptFiles += $dependencyScriptFile
                }
            }

            $this.AddChild($newClass)
        }
    }

    hidden [void]AddChild([ClassFileScript]$child) {
        $this.Children += $child
    }

    <#
        .SYNOPSIS
            Dirty nasty hack to get the same functionality of Join-Path without the actual file system dependencies
    #>
    hidden static [string]JoinPath([string]$path, [string]$childPath)
    {
        return [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($path, $childPath))
    }
}

$scriptRoot = $PSScriptRoot
Write-Verbose -Message ('scriptRoot = ' + $scriptRoot)

$moduleRoot = Split-Path -Path $scriptRoot -Parent
Write-Verbose -Message ('moduleRoot = ' + $moduleRoot)

$classScripts = [ClassFileScripts]::new($moduleRoot)
$classScripts.Compile()

