function Add-AzureStartupTask
{
    <#
    .Synopsis
        Adds a startup task to Azure
    .Description
        Adds a startup task to an azure service configuration, and packs some extra information into the XML to allow 
        using ScriptBlock as startup tasks
    .Example
        New-AzureServiceDefinition -ServiceName "MyService" |
            Add-AzureStartupTask -ScriptBlock { "Hello World" } -Elevated -asString
            
    .Link
        Out-AzureService
    #>
    [OutputType([xml],[string])]
    [CmdletBinding(DefaultParameterSetName='CommandLine')]
    param(    
    # The Service Definition XML
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
        
    # The role
    [string]
    $ToRole,
    
    # The command line to run    
    [Parameter(Mandatory=$true,ParameterSetName='CommandLine')]    
    [string]
    $CommandLine,


    # The batch script to run    
    [Parameter(Mandatory=$true,ParameterSetName='BatchScript')]    
    [string]
    $BatchScript,
    
    # The ScriptBlock to run. 
    [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock')]    
    [ScriptBlock]
    $ScriptBlock,
    
    # The parameter to be passed to the script block
    [Parameter(ParameterSetName='ScriptBlock')]    
    [Hashtable]
    $Parameter,       
    
    # The task type.  
    [ValidateSet('Simple', 'Background', 'Foreground')]
    [string]
    $TaskType = 'Simple',
    
    # If set, the task will be run elevated
    [switch]
    $Elevated,
    
    # If set, returns the service definition XML up to this point as a string
    [switch]
    $AsString
    )
    
    process {        
        $taskType = $taskType.ToLower()
        
        # Resolve the role if it set, create the role if it doesn't exist, and track it if they assume the last item.
        $roles = @($ServiceDefinition.ServiceDefinition.WebRole), @($ServiceDefinition.ServiceDefinition.WorkerRole) +  @($ServiceDefinition.ServiceDefinition.VirtualMachineRole)
        $xmlNamespace = @{'ServiceDefinition'='http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition'}        
        $selectXmlParams = @{
            XPath = '//ServiceDefinition:WebRole|//ServiceDefinition:WorkerRole|//ServiceDefinition:VirtualMachineRole'
            Namespace = $xmlNamespace
        }        
        $roles = @(Select-Xml -Xml $ServiceDefinition @selectXmlParams | 
            Select-Object -ExpandProperty Node)
        if (-not $roles) {
            $ServiceDefinition = $ServiceDefinition | 
                Add-AzureRole -RoleName "WebRole1"
                
            $roles = @(Select-Xml -Xml $ServiceDefinition @selectXmlParams | 
                Select-Object -ExpandProperty Node)
        }
        
        if ($roles.Count -gt 1) {
            if ($ToRole) {
            } else {
                $role = $roles[-1]                
            }
        } else {
            if ($ToRole) {
                if ($roles[0].Name -eq $ToRole) {
                    $role = $roles[0]
                } else { 
                    $role = $null 
                }
            } else {            
                $role = $roles[0]
            }           
        }
        
        if (-not $role) { return }
                
        if (-not $role.Startup) {
            $role.InnerXml += "<Startup/>"
        }
        
        $startupNode = Select-Xml -Xml $role -Namespace $xmlNamespace -XPath '//ServiceDefinition:Startup' |
            Select-Object -ExpandProperty Node -First 1
        
        $execContext= if ($elevated) { 'elevated'  } else { 'limited' }    
        if ($psCmdlet.ParameterSetName -eq 'CommandLine') {
            $startupNode.InnerXml += "<Task commandLine='$CommandLine' executionContext='$execContext' taskType='$taskType'/>"
        } elseif ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $parameterChunk = if ($parameter) { 
                $parameterChunk = "<Parameters>"
                foreach ($kv in $parameter.GetEnumerator()) {
                    if ($kv.Value) {
                        $parameterChunk  += "<Parameter name='$($kv.Key)' value='$([Security.SecurityElement]::Escape($kv.Value))' />"
                    } else {
                        $parameterChunk  += "<Parameter name='$($kv.Key)' />"
                    }
                }
                $parameterChunk += "</Parameters>"
            } else { ""}            
            $startupNode.InnerXml += "<Task commandLine='' executionContext='$execContext' taskType='$taskType'>
                <ScriptBlock>
                    $([Security.SecurityElement]::Escape($ScriptBlock))                    
                </ScriptBlock>
                $parameterChunk
            </Task>"
        } elseif ($psCmdlet.ParameterSetName -eq 'BatchScript') {
            $startupNode.InnerXml += "<Task commandLine='' executionContext='$execContext' taskType='$taskType'>
                <Batch>
                    $([Security.SecurityElement]::Escape($BatchScript))                    
                </Batch>                
            </Task>"
        }

    }
    
    end {
        if ($AsString) {
            $strWrite = New-Object IO.StringWriter
            $serviceDefinition.Save($strWrite)
            return "$strWrite"
        } else {
            $serviceDefinition
        }   

    }
} 
