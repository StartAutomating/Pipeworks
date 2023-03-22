function Get-PipeworksManifest
{
    <#
    .Synopsis
        Gets the Pipeworks manifest for a module
    .Description
        Gets the Pipeworks manifest for a PowerShell module.  
                
        The pipeworks manifest is a .psd1 file that describes how the module can be published.
    .Example
        Get-PipeworksManifest -Module Pipeworks
    .Example
        Get-Module Pipeworks | Get-PipeworksManifest
    .Example
        Get-Module | Get-PipeworksManifest
    #>
    [CmdletBinding(DefaultParameterSetName='ModuleName')]
    [OutputType('Pipeworks.Manifest')]
    param(
    # The name of the module.
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='ModuleName')]
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='ModuleRoot')]
    [Alias('Name','DirectoryName')]
    [string]
    $ModuleName,

    # The root directory of the module
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='ModuleRoot')]    
    [string]
    $ModuleRoot,

    # The direct path to the Pipeworks Manifest
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='ManifestPath')]    
    [string]
    $PipeworksManifestPath
    )

    begin {
        $LoadManifest = {
            param($pipeworksManifestPath)
            $fileText = [IO.File]::ReadAllText($pipeworksManifestPath)
            if (-not $fileText) { return }
            $fileScriptBlock = [scriptblock]::Create($fileText)
            if (-not $fileScriptBlock) { return }

            $safeLoad = & ([ScriptBlock]::Create(
            "data -SupportedCommand Add-Member, New-WebPage, New-Region, Write-CSS, Out-Html, Write-Link { $(
                $fileScriptBlock            
            )}"))

            if ($safeLoad) {
                & ([ScriptBlock]::Create(($fileText -replace '\@\{', '[Ordered]@{')))
            }
        }
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ModuleRoot') {
            $moduleDirName = $ModuleRoot | Split-Path -Leaf
            $pipeworksManifestPath = Join-Path $moduleRoot ("$moduleDirName"  + '.pipeworks.psd1')
        } elseif ($PSCmdlet.ParameterSetName -eq 'ModuleName') {
            $mi = $MyInvocation        
            if ("$($mi.ScriptName)".ToLower().EndsWith(".psm1")) {
                # This is here in the event that Get-PipeworksManifest is dot-sourced within a .PSM1.
                # Setting the result of this to $global:PipeworksManifest
                $moduleRoot = Split-Path $mi.ScriptName
                $moduleName = "$(Split-Path $mi.ScriptName -Leaf)"
                $moduleName = $moduleName.Substring(0, $ModuleName.Length - 5)
                $pipeworksManifestPath = Join-Path $moduleRoot ($moduleName  + '.pipeworks.psd1')
            } else {
                $realModule = Get-Module $moduleName
                if (-not $realModule) { 
                    Write-Error "$moduleName not found"
                    return 
                }

                if (-not $realModule.Path) { return }
                $moduleRoot = Split-Path $realModule.Path                     
                $pipeworksManifestPath = Join-Path $moduleRoot "$($realmodule.Name).Pipeworks.psd1"
            }
        }
        # Import pipeworks manifest
        
        
        #region Initialize Pipeworks Manifest        

        $lastDot = $pipeWorksManifestPath.LastIndexOf(".")
        if ($lastDot -eq -1) { return }
        $dotBeforeThat = $pipeworksManifestPath.LastIndexOf(".", $lastDot - 1)
        if ($dotBeforeThat -eq -1) { return } 

        $lastSlash = $pipeworksManifestPath.LastIndexOf([IO.Path]::DirectorySeparatorChar, $dotBeforeThat)
        if ($lastSlash -eq -1) { return } 
        $pipeworksManifestName  = $pipeworksManifestPath.Substring($lastSlash + 1, $dotBeforeThat - $lastSlash -1 )

        $computerName = 
        if ($env:COMPUTERNAME) {

        } elseif ($env:NAME) {

        }

        $machineSpecificPipeworksManifest = $pipeworksManifestPath.Substring(0, $dotBeforeThat + 1) + $computerName + ".pipeworks.psd1"

        if ($computerName -and [IO.File]::Exists($machineSpecificPipeworksManifest)) {
            try {                     
                
                $ManifestResult = . $LoadManifest $machineSpecificPipeworksManifest
                                                               
            } catch {
                Write-Error "Could not read pipeworks manifest for $ModuleName $($_ | Out-String)" 
                return
            }
        } elseif ([IO.File]::Exists($pipeworksManifestPath)) {
            try {                     
                
                $ManifestResult = . $LoadManifest $PipeworksManifestPath
                                                               
            } catch {
                Write-Error "Could not read pipeworks manifest for $ModuleName $($_ | Out-String)" 
                return
            }                                                
        }


        if ($ManifestResult) {
            if ($PSCmdlet.ParameterSetName -eq 'ModuleName') {    
                $ManifestResult.Name = $moduleName                                         
                $ManifestResult.Module = $realModule
                $ManifestResult |
                    Add-Member NoteProperty Name $ModuleName -Force -PassThru |                  
                    Add-Member NoteProperty Module $RealModule -Force -PassThru
            } elseif ($PSCmdlet.ParameterSetName -eq 'ModuleRoot') {
                
                $ManifestResult

            }  elseif ($PSCmdlet.ParameterSetName -eq 'ManifestPath') {
                # The is the branch used when loading the module within Pipeworks (while in a site)                                               

                $ManifestResult.Name = $pipeworksManifestName 

                $ManifestResult
            }
        }

    }
}
