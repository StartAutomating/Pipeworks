function Add-AzureLocalResource
{
    <#
    .Synopsis
        Adds an Azure local storage resource to a service definition
    .Description
        Adds an Azure local storage resource to a service definition.  
        
        Azure local storage can create well-known directories on the host machine
    .Example
        New-AzureServiceDefinition -ServiceName "foo" |
            Add-AzureLocalResource -ServiceDefinition
    .Link
        New-AzureServiceDefinition
    #>
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
      
    # If set, the local resource will only apply to the role named ToRole.  If ToRole is not found, or doesn't
    # exist, the last role will be used.  
    [string]
    $ToRole,
    
    # The name of the local storage.  This will be the path of the name storage element, relative to the root drive.
    [Parameter(Mandatory=$true)]
    [string]
    $Name,
    
    # The size of the storage.  Sizes will be rounded up to the nearest megabyte. 
    [Long]
    $Size = 1mb,
    
    # If set, a role will not be cleaned on recycle
    [switch]
    $DoNotcleanOnRoleRecycle,
    
    # If set, will output results as string rather than XML
    [switch]
    $AsString
    )
    
    process {        
        
        #region Resolve the role if it set, create the role if it doesn't exist, and track it if they assume the last item.
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
        #endregion Resolve the role if it set, create the role if it doesn't exist, and track it if they assume the last item.
        
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
        
        $realSize = [Math]::Ceiling($size / 1mb)
        
        if (-not $role.LocalResources) {
            $role.InnerXml += "<LocalResources/>"
        }
        
        $localResourcesNode = Select-Xml -Xml $role -Namespace $xmlNamespace -XPath '//ServiceDefinition:LocalResources' |
            Select-Object -ExpandProperty Node
        
        $localResourcesNode.InnerXml += "<LocalStorage name='$Name' sizeInMB='$realSize' cleanOnRoleRecycle='$($DoNotcleanOnRoleRecycle.ToString().ToLower())'/>"

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
