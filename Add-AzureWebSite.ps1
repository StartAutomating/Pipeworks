function Add-AzureWebSite
{
    <#
    .Synopsis
        Adds an Azure web site to a service definition.
    .Description
        Adds an Azure web site to a service definition.  
        
        The site can bind to multiple host
        
        Creates a web role if one does not exist.                
    .Example
        New-AzureServiceDefinition -ServiceName "AService" |
            Add-AzureWebSite -SiteName "ASite" -PhysicalDirectory "C:\inetpub\wwwroot\asite" -HostHeader a.subdomain.com, nakeddomain.com, www.fulldomain.com -asString
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
    [Parameter(ValueFromPipelineByPropertyName=$true)]        
    [string]
    $ToRole,
    
    # The name of the site to create. If Sitename is not set, sites will be named Web1, Web2, Web3, etc    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $SiteName,
    
    # The physical directory of the website.  This is where the web site files are located.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $PhysicalDirectory,            
    
    # One or more host headers to use for the site
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $HostHeader,
    
    # Additional bindings.  Each hashtable can contain an EndpointName, Name, and HostHeader
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable[]]
    [ValidateScript({
        Test-SafeDictionary -Dictionary $_ -ThrowOnUnsafe
    })]
    $Binding,
    
    # Additional virtual directories.  
    # The keys will be the name of the virtual directories, and the values will be the physical directory on
    # the local machine.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    [ValidateScript({
        Test-SafeDictionary -Dictionary $_ -ThrowOnUnsafe
    })]
    $VirtualDirectory,
    
    # Additional virtual applications.  
    # The keys will be the name of the virtual applications, and the values will be the physical directory on
    # the local machine.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    [ValidateScript({
        Test-SafeDictionary -Dictionary $_ -ThrowOnUnsafe
    })]    
    $VirtualApplication,   
    
    # The VMSize
    [ValidateSet('ExtraSmall','Small','Medium', 'Large', 'Extra-Large', 'XS', 'XL', 'S', 'M', 'L')]
    $VMSize,
    
    # If set, will return values as a string
    [switch]
    $AsString
    )
    
    begin {
        $xmlNamespace = @{'ServiceDefinition'='http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition'}                
        if (-not $script:siteCount) {$script:SiteCount  = 0}
    }
    
    process {        
     
        $script:siteCount++
        # Resolve the role if it set, create the role if it doesn't exist, and track it if they assume the last item.
        $roles = @($ServiceDefinition.ServiceDefinition.WebRole), @($ServiceDefinition.ServiceDefinition.WorkerRole) +  @($ServiceDefinition.ServiceDefinition.VirtualMachineRole)
        
        $selectXmlParams = @{
            XPath = '//ServiceDefinition:WebRole'
            Namespace = $xmlNamespace
        }        
        $roles = @(Select-Xml -Xml $ServiceDefinition @selectXmlParams | 
            Select-Object -ExpandProperty Node)
        if (-not $roles) {
            $params = @{}
            if ($vmSize) { $params['vmSize']= $vmSize}
            $ServiceDefinition = $ServiceDefinition | 
                Add-AzureRole -RoleName "WebRole1" @params
                
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
        
        $realSize = [Math]::Ceiling($size / 1mb)
        
        if (-not $role.Sites) {
            $role.InnerXml += "<Sites/>"
        }
        
        $sitesNode = Select-Xml -Xml $role -Namespace $xmlNamespace -XPath '//ServiceDefinition:Sites' |
            Select-Object -ExpandProperty Node
        if (-not $siteName) { 
            if ($physicalPath) {
                $SiteName = "WebSite${siteCount}"
            } else {
                $SiteName = "Web${siteCount}"
            }
            
        }
        
        if ($PhysicalDirectory) {   
            $translatedPhysicalPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PhysicalDirectory)
            $sitesNode.InnerXml += "<Site name='$SiteName' physicalDirectory='$translatedPhysicalPath' />"
        } else {
            $sitesNode.InnerXml += "<Site name='$SiteName' />"
        }
        
        $siteNode = Select-Xml -Xml $sitesNode -Namespace $xmlNamespace -XPath "//ServiceDefinition:Site"|
            Where-Object { $_.Node.Name -eq $siteName } | 
            Select-Object -ExpandProperty Node -Last 1
                
        
        if ($psBoundParameters.VirtualDirectory)
        {
            foreach ($kv in $psBoundParameters.VirtualDirectory.GetEnumerator()) {
                $siteNode.InnerXml += " <VirtualDirectory name='$($kv.Key)' physicalDirectory='$($kv.Value)' />"
                $role.Sites.InnerXml  = $sitesNode.InnerXml.Replace('xmlns=""', '')
            }
        }
        
        if ($psBoundParameters.VirtualApplication) {
            foreach ($kv in $psBoundParameters.VirtualApplication.GetEnumerator()) {
                $siteNode.InnerXml += " <VirtualApplication name='$($kv.Key)' physicalDirectory='$($kv.Value)' />"
                $role.Sites.InnerXml  = $sitesNode.InnerXml.Replace('xmlns=""', '')
            }
        }
        
        $usedDefaultEndPoint = $false
        if (-not $role.Endpoints) {
            $usedDefaultEndPoint = $true
            $role.InnerXml += "<Endpoints><InputEndpoint name='DefaultWebSiteEndPoint' protocol='http' port='80' />
            </Endpoints>"
        }
        
        $specifiesBindingEndPoint = $false
        
        if ((-not $psBoundParameters.Binding) -and (-not $psBoundParameters.HostHeader)) {
            $endpointsNode = Select-Xml -Xml $role -Namespace $xmlNamespace -XPath "//ServiceDefinition:Endpoints"|
                Select-Object -ExpandProperty Node
        
            $endPointName = @($endPointsNode.InputEndPoint)[-1].Name
            
            $siteNode.InnerXml += "<Bindings><Binding endpointName='$endPointName' name='Binding1' /></Bindings>"            
            $role.Sites.InnerXml  = $sitesNode.InnerXml.Replace('xmlns=""', '')
        }
        
        if ($psBoundParameters.Binding) {
            $bindings = foreach ($ht in $psBoundParameters.Binding) {
                $bindingXmlText = "<Binding"
                foreach ($kv in $ht.GetEnumerator()) {
                    if ($kv.Key -eq 'EndpointName') {
                        $attributeName = 'endpointName'
                        $specifiesBindingEndPoint = $true                        
                    } elseif ($kv.Key -eq 'Name') {
                        $attributeName = 'name'
                    } elseif ($key.Key -eq 'HostHeader') {
                        $attributeName = 'hostHeader'
                    }
                    if ($attributeName){
                        $bindingXmlText+= " $attributeName='$($kv.Value)'"
                    }
                }
                "$bindingXmlText />"      
            }
            
            $ofs = [Environment]::NewLine
            $siteNode.InnerXml += "<Bindings>$bindings</Bindings>"    
            $role.Sites.InnerXml  = $sitesNode.InnerXml.Replace('xmlns=""', '')
         
        }
        
        if ($psBoundParameters.HostHeader) {
            $endpointsNode = Select-Xml -Xml $role -Namespace $xmlNamespace -XPath "//ServiceDefinition:Endpoints"|
                Select-Object -ExpandProperty Node

            $endPointName = @($endPointsNode.InputEndPoint)[-1].Name
            
            $bindingCount = 1
            $bindings = foreach ($header in $psBoundParameters.HostHeader) {
                "<Binding endpointName='$endPointName' name='Binding${BindingCount}' hostHeader='$header'/>"
            }
            $ofs = [Environment]::NewLine
            if ($siteNode.InnerXml)  {
                 $siteNode.InnerXml += "<Bindings>$bindings</Bindings>" 
            } else {
                 $siteNode.InnerXml = "<Bindings>$bindings</Bindings>" 
            }
            $role.Sites.InnerXml  = $sitesNode.InnerXml.Replace('xmlns=""', '')         
            
        }                                               
    }
    
    end {
        $webRole= Select-Xml -Xml $role -Namespace $xmlNamespace -XPath '//ServiceDefinition:WebRole' |
            Select-Object -ExpandProperty Node
            

        if ($AsString) {
            $strWrite = New-Object IO.StringWriter
            $serviceDefinition.Save($strWrite)
            return "$strWrite"
        } else {
            $serviceDefinition
        }   
    
    }
} 
