function Add-AzureRole
{
    <#
    .Synopsis
        Adds and azure role to a service definition
    .Description
        Adds an azure role to a service definition        
    .Example
        New-AzureServiceDefinition -ServiceName AService |
            Add-AzureRole -RoleName MyWebRole -VMSize Large -RoleType Web -AsString
    .Link
        New-AzureServiceDefinition
    #>
    [OutputType([xml],[string])]
    param(
    # The Service Definition
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
    
    # The name of the role
    [Parameter(Mandatory=$true,        
        ValueFromPipelineByPropertyName=$true)]
    [string]
    $RoleName,
    
    # The VMSize
    [ValidateSet('ExtraSmall','Small','Medium', 'Large', 'Extra-Large', 'XS', 'XL', 'S', 'M', 'L')]
    [string]
    $VMSize,
    
    # If set, will disable native code execution on the role.  This will prevent PHP or other CGI from working
    [Switch]
    $DisableNativeCodeExecution,
    
    # If set, will output as a string
    [switch]
    $AsString,
    
    # The type of the role.
    [ValidateSet('Web','Worker','VirtualMachine', 'VM')]
    [string]
    $RoleType = 'Web'
    )
    
    process {
        #region Correct Parameters
        $enableNativeCodeExecution = (-not $DisableNativeCodeExecution).ToString().ToLower()
        $vmSize = if ('XS' -eq $VmSize) {
            "ExtraSmall"
        } elseif ('XL' -eq $VmSize) {
            "ExtraLarge"
        } elseif ('M' -eq $VmSize) {
            "Medium"
        } elseif ('S' -eq $VmSize) {
            "Small"
        } elseif ('L' -eq $VmSize) {
            "Large"
        } elseif ($vmSize)  {            
            $vmSize 
        } else {
            $null
        }
        
        if ($vmSize) {
            # Force every instance of a subword into camel case
            foreach ($subWord in 'Extra','Small', 'Medium', 'Large') {
                $vmSize=  $vmSize -ireplace $subWord, $subWord
            }
        }
        #endregion Correct Parameters

        $roleElement = if ($roleType -eq 'Web') {
            "WebRole" 
        } elseif ($roleType -eq 'Worker') {
            "WorkerRole" 
        } elseif ('VirtualMachine', 'VM' -contains $roleType) {
            "VirtualMachineRole"
        }
        
        if ($vmSize) {
            @($serviceDefinition.ChildNodes)[-1].InnerXml += "<$roleElement name='$RoleName' vmsize='$VMSize' enableNativeCodeExecution='$enableNativeCodeExecution' />"
        } else {
            @($serviceDefinition.ChildNodes)[-1].InnerXml += "<$roleElement name='$RoleName' enableNativeCodeExecution='$enableNativeCodeExecution' />"
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
