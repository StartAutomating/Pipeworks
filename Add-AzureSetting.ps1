function Add-AzureSetting
{
    <#
    .Synopsis
        Adds an Azure local storage resource to a service definition
    .Description
        Adds an Azure local storage resource to a service definition.  
        
        Azure local storage can create well-known directories on the host machine    
    .Link
        New-AzureServiceDefinition
    .Example
        New-AzureServiceDefinition -ServiceName MyService | 
            Add-AzureSetting -Name MySetting -Value MyValue -AsString
    #>
    [CmdletBinding(DefaultParameterSetName='NameAndValue')]
    [OutputType([xml],[string])]
    param(    
    # The ServiceDefinition XML.  This should be created with New-AzureServiceDefinition or retreived with Import-AzureServiceDefinition
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

    # The name of the setting to configure          
    [Parameter(Mandatory=$true, ParameterSetName='NameAndValue')]
    [string]
    $Name,
    
    # The value to us for the setting
    [Parameter(Mandatory=$true, ParameterSetName='NameAndValue')]
    [string]    
    $Value,
    
    # A table of names and values for Azure settings 
    [Parameter(Mandatory=$true, ParameterSetName='SettingTable')]
    [Hashtable]
    $Setting,
    
    # If set, will output results as string rather than XML
    [switch]
    $AsString
    )
    
    process {        
        if ($psCmdlet.ParameterSetName -eq 'NameAndValue') {
            # Resolve the role if it set, create the role if it doesn't exist, and track it if they assume the last item.
            $roles = @($ServiceDefinition.ServiceDefinition.WebRole), 
                @($ServiceDefinition.ServiceDefinition.WorkerRole) +  
                @($ServiceDefinition.ServiceDefinition.VirtualMachineRole)
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
                    
            if (-not $role.ConfigurationSettings) {
                $role.InnerXml += "<ConfigurationSettings/>"
            }
            $ConfigurationSettingsNode = 
                $(Select-Xml -Xml $role -Namespace $xmlNamespace -XPath '//ServiceDefinition:ConfigurationSettings' |
                Select-Object -ExpandProperty Node -First 1)
            
            $ConfigurationSettingsNode.InnerXml += "<Setting name='$Name' value='$([Security.SecurityElement]::Escape($value))'/>"
        } elseif ($psCmdlet.ParameterSetName -eq 'SettingTable') {
            $null = $psboundParameters.Remove('asString')
            $null = $psboundParameters.Remove('setting')
            foreach ($kv in $setting.GetEnumerator()) {
                $psboundParameters.Name =  $kv.Key
                $psboundParameters.Value =  $kv.Value
                $psboundParameters.ServiceDefinition =  $ServiceDefinition
                $ServiceDefinition = & $myInvocation.MyCommand @psBoundParameters
            }                        
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
