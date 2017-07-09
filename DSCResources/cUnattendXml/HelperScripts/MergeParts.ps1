Clear-Host

$VerbosePreference = 'Continue'

class ClassFileScript {
    [string] $ScriptFile
    [string[]] $DependencyScriptFiles
    [string] $SourceText
}

class ClassFileScripts {
    [ClassFileScript[]] $Children = @()

    [string] $ModuleRoot

    [string] $CompiledText
    [string[]] $IncludedScripts

    ClassFileScripts([string]$moduleRoot)
    {
        $this.ModuleRoot = $moduleRoot
    }

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

    hidden [string] GetRootModuleFromManifest([string]$psdFile)
    {
        [string] $content = Get-Content -Path $psdFile -raw
        $expressionResult = Invoke-Expression -Command $content
        return [ClassFileScripts]::JoinPath($this.ModuleRoot, $expressionResult.RootModule)
    }

    hidden [string] GetModuleName()
    {
        return Split-Path -Path $this.ModuleRoot -Leaf
    }

    hidden [void] CompileFiles()
    {
        $this.PopulateChildren()
        $this.VerifyDependencies()

        foreach($classFile in $this.Children) {
            $this.CompileFile($classFile)
        }
    }

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

    hidden [void]PopulateChildren()
    {
        $classRoot = Join-Path -Path $this.ModuleRoot -ChildPath 'Classes'
        Write-Verbose -Message ('classRoot = ' + $classRoot)

        $classFileInfo = Get-ChildItem -Path $classRoot | Where-Object {
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

