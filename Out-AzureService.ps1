function Out-AzureService
{
    <#
    .Synopsis
        Creates a an Azure Service Deployment pack, definition, and configuration file
    .Description
        Uses the Azure SDK tool CSPack to create a deployment package (cspkg) and associated deployment files.               
    .Link 
        New-AzureServiceDefinition
    .Link 
        Publish-AzureService
    #>
    [OutputType([IO.FileInfo])]
    param(    
    # The Service DefinitionXML
    [Parameter(Mandatory=$true,
        ValueFromPipeline=$true,
        ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
        $isServiceDefinition = $_.NameTable.Get("http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition")
        if (-not $IsServiceDefinition) {
            throw "Input must be a ServiceDefinition XML"
        }
        return $true
    })]    
    [Xml]
    $ServiceDefinition,

    # The output directory for the azure service.
    [Parameter(Mandatory=$true)]
    [string]
    $OutputPath,
       
    # If set, will look for a specific Azure SDK Version
    [Version]
    $SdkVersion,
    
    # The number of instances to create
    [Uint32]
    $InstanceCount = 2,

    # The operating system family
    [ValidateSet("2K8R2","2012")]
    [string]
    $Os = "2012"
    )
    
    begin {
        #region Find CSPack
        $programFiles = if ($env:ProgramW6432) {
            $env:ProgramW6432
        } else {
            $env:ProgramFiles
        }
        $azureSdkDir = Get-ChildItem "$programFiles\Windows Azure SDK", "$programFiles\Microsoft SDKs\Windows Azure\.NET SDK" -Force -ErrorAction SilentlyContinue 
        if ($azureSdkDir) {
            $latestcsPack = $azureSdkDir | 
                Sort-Object { $_.Name.Replace('v', '') -as [Version] }  |
                Where-Object {
                    if ($sdkVersion) {
                        $_.Name.Replace('v', '') -eq $SdkVersion
                    } else {
                        return $true
                    }                    
                } |
                Select-Object -Last 1 |
                Get-ChildItem -Filter 'bin' |
                Get-ChildItem -Filter 'cspack.exe'
                
            if ($latestCsPack) {
                $csPack  = Get-Command $latestCsPack.fullname
            }
        } else {
            $latestCSPack = $csPack = Get-Command $psScriptRoot\Tools\cspack.exe
        }        
        #endregion Find CSPAck
    }
    
    process {
        if (-not $latestCSPack) { 
            Write-Error "Azure SDK tool CSPack not found"
            return 
        } 

        $osFamily = if ($os -eq '2K8R2') {
            2
        } elseif ($os -eq '2012') {
            3
        }
        $temporaryServiceDirectory = New-Item -ItemType Directory -Path "$env:Temp\$(Get-Random).azureService" 
        
        $serviceName = $ServiceDefinition.ServiceDefinition.name
        try { $null = $ServiceDefinition.CreateXmlDeclaration("1.0", "utf8", $null) } catch  {} 
        $serviceDefinitionFile = Join-Path $temporaryServiceDirectory "$serviceName.csdef"
        $ServiceDefinition.Save($serviceDefinitionFile)
                            
        
        $workingDirectory = Split-Path $serviceDefinitionFile
        $leaf = Split-Path $serviceDefinitionFile -Leaf
        $configurationFile = "$serviceName.cscfg"
        
        $arguments = @("$leaf")
        
        
                
        
        $roles = @($ServiceDefinition.ServiceDefinition.WebRole), @($ServiceDefinition.ServiceDefinition.WorkerRole) +  @($ServiceDefinition.ServiceDefinition.VirtualMachineRole)
        $xmlNamespace = @{'ServiceDefinition'='http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition'}        
        $selectXmlParams = @{
            XPath = '//ServiceDefinition:WebRole|//ServiceDefinition:WorkerRole|//ServiceDefinition:VirtualMachineRole'
            Namespace = $xmlNamespace
        }        
        $roles = @(Select-Xml -Xml $ServiceDefinition @selectXmlParams | 
            Select-Object -ExpandProperty Node)
        
        #$roles[0]
        $startupBin = "$temporaryServiceDirectory\Startup\bin"
        New-Item $startupBin  -ErrorAction SilentlyContinue -Force -ItemType Directory | Out-Null
                      
        
        #region Create roles
        $firstSitePhysicalDirectory = $null
        foreach ($role in $roles) {
            $roleDir = Join-Path $temporaryServiceDirectory $role.Name
            $null = New-Item -ItemType Directory -Path $roleDir
            $roleBinDir = Join-Path $temporaryServiceDirectory "$($role.Name)_bin"            
            $null = New-Item -ItemType Directory -Path $roleBinDir
            $roleBin = Join-Path $roleBinDir "bin"
            $null = New-Item -ItemType Directory -Path $roleBin
            # The azure sdk requires a binary, so give them a binary
            Add-Type -OutputAssembly "$roleBin\Placeholder.dll" -TypeDefinition @"
namespace Namespace$(Get-Random) {
    public class Stuff 
    {
        public int StuffCount;
    }
}
"@            
            $configSettingsChunk = "<ConfigurationSettings />"
            $arguments+= "/role:$($role.Name);$($role.Name)_bin"
            if ($role.ConfigurationSettings) {
                $configSettingsChunk = "<ConfigurationSettings>"
                foreach ($configSetting in $role.ConfigurationSettings.Setting) {
                    $configSettingsChunk += $configSetting.innerXml
                    $null = $configSetting.RemoveAttribute('value')
                }
                $configSettingsChunk += "</ConfigurationSettings>"                
                $ServiceDefinition.Save($serviceDefinitionFile)
            }
            
            if ($role.Startup) {
                $c = 0
                foreach ($task in $role.Startup.Task) {
                    $c++
                    # Translate ScriptBlock start up tasks, which, alas, don't directly exist in Azure, into .cmd startup tasks
                    if ($task.ScriptBlock) {
                        $null = $task.SetAttribute('commandLine', "startupScript${c}.cmd")
                        # Create the cmd file
                        $scriptFile = "`$scriptBlockParameters = @{}
`$serviceName = '$($serviceDefinition.Name)'
"
                    
                        # If parameters were supplied, put them into a hashtable    
                        if ($task.Parameters) {
                            foreach ($parameter in $task.Parameters) {
                                $scriptFile += "

`$scriptBlockParameters.'$($Parameter.Name)' = '$($parameter.Value)'
                                
                                "
                            }
                        }

                        # Run the PowerShell script and exit
                        $scriptFile += "
                        
`$exitCode = 0
& {
    $($task.ScriptBlock.'#text')
} @scriptBlockParameters
exit `$exitCode 
                        " 

                        # Convert script into a base64 encoded file, then run it
                        $b64 = [Convert]::ToBase64String([Text.Encoding]::unicode.GetBytes($scriptFile))
                        $cmdFile = "powershell.exe -executionpolicy bypass -encodedCommand $b64"
                        
                        $cmdFile | Set-Content "$roleBin\startupScript${c}.cmd"
                        #$scriptFile > "$roleBin\startupScript${c}.ps1"
                    }
                    # Batch scripts are easier,  just add a .cmd file and away we go.
                    if ($task.Batch) {
                        $null = $task.SetAttribute('commandLine', "startupScript${c}.cmd")
                        $cmdFile = $task.Batch                        
                        $cmdFile | Set-Content "$roleBin\startupScript${c}.cmd"
                    }                    
                    foreach ($i in @($task.GetEnumerator())) { 
                        $null = try { $task.RemoveChild($i)  } catch { }
                    } 
                }
                $ServiceDefinition.Save($serviceDefinitionFile)
            }
            $roleConfigChunk += "<Role name='$($role.Name)'>
    $configSettingsChunk
    <Instances count='$InstanceCount' />
  </Role>"            
            $sites = $roles = @(Select-Xml -Xml $ServiceDefinition -Namespace $xmlNamespace -XPath //ServiceDefinition:Site | 
                Select-Object -ExpandProperty Node)
            if ($sites) {            
                foreach ($site in $sites ) {
                    if (-not $firstSitePhysicalDirectory) { $firstSitePhysicalDirectory= $site.PhysicalDirectory}                    
                    $webConfigFile = Join-Path $site.PhysicalDirectory "Web.Config"
                    if (-not (Test-Path $webConfigFile)) {
                        '
<configuration>
    <system.web>
        <customErrors mode="Off"/>
    </system.web>
</configuration>                        
                        ' | Set-Content -path $webConfigFile                                                
                    }
                    
                }
            }
        }
        #endregion Create roles
        
        $cscfgXml = [xml]@"
<ServiceConfiguration xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" serviceName="$serviceName" xmlns="http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceConfiguration" osFamily='$osFamily' osVersion='*'>
  $RoleConfigChunk
</ServiceConfiguration>        
"@             
        
        
        #region Push to the output directory, then run CSPack
        Push-Location $workingDirectory
        $results = & $csPack $arguments 
        Pop-Location
        #endregion Push to the output directory, then run CSPack

        $errs =$results -like "*Error*:*"
        if ($errs) {
            foreach ($err in $errs) {
                Write-Error $err.Substring($err.IndexOf(":") + 1)
            }
            return
        }
        
        
        $csdef = $serviceDefinitionFile
        $cspkg = Join-Path $workingDirectory "$serviceName.cspkg"
        
        if (-not $outputPath) {        
            $serviceDeploymentRoot = "$psScriptRoot\AzureServices"
            if (-not (Test-Path $serviceDeploymentRoot)) {
                $null = New-Item -ItemType Directory -Path $serviceDeploymentRoot
            }
            
            $serviceDropDirectory = "$serviceDeploymentRoot\$serviceName"
            if (-not (Test-Path $serviceDropDirectory)) {
                $null = New-Item -ItemType Directory -Path $serviceDropDirectory
            }        

            $nowString = (Get-Date | Out-String).Trim().Replace(":", "-")
            $thisDropDirectory  =Join-Path $serviceDropDirectory $nowString 
            if (-not (Test-Path $thisDropDirectory)) {
                $null = New-Item -ItemType Directory -Path $thisDropDirectory
            }           
        } else {
            $unResolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($outputPath)
            if (-not (Test-Path $unResolvedPath)) {
                $newPath = New-Item -ItemType Directory $unResolvedPath
                if ($newPath) { 
                    $thisDropDirectory = "$newPath"
                }
            } else {
                $thisDropDirectory = "$unResolvedPath"
            }
            
        }
        
        
        #Move-Item -LiteralPath $cscfg -Destination "$thisDropDirectory"
        $cscfg = Join-Path $thisDropDirectory $configurationFile
        if (Test-Path $cscfg) { Remove-Item -Force $cscfg }
        $cscfgXml.Save("$cscfg")
        Move-Item -LiteralPath $csdef -Destination "$thisDropDirectory" -Force
        Move-Item -LiteralPath $cspkg -Destination "$thisDropDirectory" -Force                
        
        Remove-Item -Recurse -Force $workingDirectory
        Get-ChildItem $thisDropDirectory -Force               
    }
} 
