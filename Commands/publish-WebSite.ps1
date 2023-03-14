function Publish-Website
{
    <#
    .Synopsis
        Publishes one or more modules as websites
    .Description
        Publishes one or more modules as websites, according to the DomainSchematic found in the Pipeworks manifest
    .Example
        Get-Module Pipeworks | 
            Publish-WebSite
    .Link
        ConvertTo-ModuleService
    #>
    [OutputType([IO.FileInfo])]
    param(
    # The name of the module
    [ValidateScript({
        if ($psVersionTable.psVersion -lt '3.0') {
            if (-not (Get-Module $_)) {
                throw "Module $_ must be loaded"            
            }
        }        
        return $true
    })]        
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='LoadedModule',ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [Alias('Module')]
    [string[]]
    $Name,    

    # If set, will publish items in a background job
    [Switch]
    $AsJob,

    # If set, will wait for all jobs to complete
    [Switch]
    $Wait,

    # The throttle for background jobs.  By default, 10
    [Uint32]
    $Throttle,

    # The buffer between jobs.  By default, 3 seconds
    [Timespan]
    $Buffer = $([Timespan]::FromSeconds(3)),

    # If set, will change the authorization mechanism used for the web site.
    [ValidateSet("Anonymous", "Windows")]
    [string]
    $Authorization = "Anonymous"
    )
    
    begin {
        $progId = Get-Random
        $serviceDirectories = @()
        
        $moduleNAmes = @()

        $jobs = @()
    }
    
    process {
        $moduleNAmes  += $name                        
    }
    
    end {
        $publishData = @{}
        $modulesByLocation = @{}



        $c = 0 
        foreach ($moduleName in $moduleNames) {
            
            if ($psVersionTable.PSVersion -ge '3.0') {
                $myModulePath = $env:PSModulePath -split ";" | Select-Object -First 1
                $moduleRoot = Join-Path $myModulePath $moduleName
            } else {
                $RealModule = Get-Module $moduleName
                $moduleList = @($RealModule.RequiredModules | 
                        Select-Object -ExpandProperty Name) + $realModule.Name

                $perc  =($c / $moduleNames.Count) * 100
                $c++
                Write-Progress "Publishing Modules" "$moduleName" -PercentComplete $perc -Id $progId 
                $module = Get-Module $moduleName
                if ($module.Path -like "*.ps1") {
                    continue
                }
                $moduleRoot = $module | Split-Path | Select-Object -First 1 
                
            }
            $manifestPath = "$moduleRoot\$($modulename).pipeworks.psd1"
            $pipeworksManifestPath = Join-Path $moduleRoot "$($moduleName).Pipeworks.psd1"
            
            
            $pipeworksManifest = 
                if (Test-Path $pipeworksManifestPath) {
                    try {                     
                        & ([ScriptBlock]::Create(
                            "data -SupportedCommand Add-Member, New-WebPage, New-Region, Write-CSS, Write-Ajax, Out-Html, Write-Link { $(
                                [ScriptBlock]::Create([IO.File]::ReadAllText($pipeworksManifestPath))                    
                            )}"))            
                    } catch {
                        Write-Error "Could not read pipeworks manifest for $moduleName" 
                    }                                                
                }


            if (-not $pipeworksManifest) {
                Write-Error "No Pipeworks manifest found for $moduleName"
                continue
            }
            
            
            
            if (-not $pipeworksManifest.DomainSchematics) {
                Write-Error "Domain Schematics not found for $moduleName"
                continue
            }

            $moduleServiceParameters = @{
                Name = $moduleName
            }

            
            if ($pipeworksManifest.PublishDirectory) {
                $baseName = $pipeworksManifest.PublishDirectory
            } else {
                $baseName = "${env:SystemDrive}\inetpub\wwwroot\$moduleName" 
            }
            
            
            
            
            foreach ($domainSchematic in $pipeworksManifest.DomainSchematics.GetEnumerator()) {
                if ($pipeworksManifest.AllowDownload) {
                    $moduleServiceParameters.AllowDownload = $true
                }                                
                $domains = $domainSchematic.Key -split "\|" | ForEach-Object { $_.Trim() }
                $schematics = $domainSchematic.Value
                
                if ($schematics -ne "Default") {
                    $moduleServiceParameters.OutputDirectory = "$baseName.$($schematics -join '.')"
                    $moduleServiceParameters.UseSchematic = $schematics                
                } else {
                    $moduleServiceParameters.OutputDirectory = "$baseName"
                    $moduleServiceParameters.Remove('UseSchematic')
                }                

                $publishData[$moduleServiceParameters.OutputDirectory] = @($domains)
                $modulesByLocation[$moduleServiceParameters.OutputDirectory] = $moduleName
                                              
                if ($AsJob) {
                    if ($psVersionTable.PSVersion -ge '3.0') {
                        $convertScript = "
Import-Module Pipeworks
Import-Module $ModuleName
"
                    } else {
                        $convertScript = "
Import-Module Pipeworks
Import-Module '$($moduleList -join "','")';"
                    }
                    
                $convertScript  += "
`$ModuleServiceParameters = "
                $convertScript  += $moduleServiceParameters | Write-PowerShellHashtable
                $convertScript  += "
ConvertTo-ModuleService @moduleServiceParameters -Force"
                
                    $convertScript = [ScriptBlock]::Create($convertScript)
                    Write-Progress "Launching Jobs" "$modulename"


                    if ($throttle) {
                        $runningJobs = @($jobs | 
                            Where-Object { $_.State -eq "Running" })
        
                        while ($runningJobs.Count -ge $throttle) {
                            $runningJobs = @($jobs | 
                                Where-Object { $_.State -eq "Running" })
                            $jobs | Wait-Job -Timeout 1 | Out-Null
                            $jobs | 
                                Receive-Job             

                            $percent = 100 - ($runningJobs.Count * 100 / $jobs.Count)
            
                            Write-Progress "Waiting for $Activity to Complete" "$($Jobs.COunt - $runningJobs.Count) out of $($Jobs.Count) Completed" -PercentComplete $percent
            
                    
                        }                    
                    }
                    $jobs += Start-Job -Name $moduleName -ScriptBlock $convertScript

                    if ($buffer) {
                        Start-Sleep -Milliseconds $buffer.TotalMilliseconds
                    }
                } else {
                    
                    ConvertTo-ModuleService @moduleServiceParameters -Force
                }
                
                

                $serviceDirectories += $moduleServiceParameters.OutputDirectory 
                

                
            }   
            
            
        }
        
                
        if ((-not $asJob) -or ($AsJob -and $Wait)) {

            $Activity = "Build $DeploymentName"
            $runningJobs = $jobs | 
                Where-Object { $_.State -eq "Running" }
        
            while ($runningJobs) {
                $runningJobs = @($jobs | 
                    Where-Object { $_.State -eq "Running" })
                $jobs | Wait-Job -Timeout 1 | Out-Null
                $jobs | 
                    Receive-Job             

                $percent = 100 - ($runningJobs.Count * 100 / $jobs.Count)
            
                Write-Progress "Waiting for $Activity to Complete" "$($Jobs.COunt - $runningJobs.Count) out of $($Jobs.Count) Completed" -PercentComplete $percent
            
                    
            }
            Import-Module WebAdministration -Global -Force
            foreach ($p in $publishData.GetEnumerator()) {
                
                $allSites = Get-Website
                 
                $AlreadyExists = $allSites |
                    Where-Object {$p.key.Trim("\") -ieq ([Environment]::ExpandEnvironmentVariables($_.physicalPath).Trim("\")) } 

                $ds = @($p.Value)
                $ds = foreach ($d in $ds) {
                    if ($d -like "*.*") {
                        $d, "$d".Replace(".", "_")
                    } else {
                        $d
                    }

                }
                $d = $ds | Select-Object -First 1
                $chunks = @($p.Key -split '\\' -ne '')
                if (-not $AlreadyExists) {                                                            
                    $newWeb = New-Website -Name $chunks[-1] -PhysicalPath $p.Key -HostHeader $d 
                    
                }


                foreach ($d in $ds) {
                    $binding = Get-WebBinding -Name $chunks[-1] -HostHeader $d -ErrorAction SilentlyContinue
                    if (-not $binding) {
                        New-WebBinding -Name $chunks[-1] -HostHeader $d 
                    }



                    if ($d -notlike "*.*") {
                        # Put it in etc/hosts if not present

                        $hostLines = @(Get-content "$env:Windir\System32\Drivers\etc\hosts")

                        $usefulHostLines=  $hostLines -notlike "#*"


                        if (-not ($usefulHostLines -like "*$d*")) {
                            $hostLines += "     127.0.0.1       $d"
                            $hostLines |Set-Content "$env:Windir\System32\Drivers\etc\hosts"
                        }

                        

                    }



                    
                            
                }

                if ($Authorization -eq 'Anonymous') {
                    Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value true -PSPath "IIS:\" -Location "$($chunks[-1])"                    
                    Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value false -PSPath "IIS:\" -Location "$($chunks[-1])"
                } elseif ($Authorization -eq 'Windows') {                    
                    Set-WebConfigurationProperty -filter /system.webServer/security/authentication/anonymousAuthentication -name enabled -value false -PSPath "IIS:\" -Location "$($chunks[-1])"                    
                    Set-WebConfigurationProperty -filter /system.webServer/security/authentication/windowsAuthentication -name enabled -value true -PSPath "IIS:\" -Location "$($chunks[-1])"                
                }                

                
                
            }

        }
                
        
        
        
    }
} 
