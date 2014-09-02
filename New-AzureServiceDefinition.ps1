function New-AzureServiceDefinition
{
    <#
    .Synopsis
        Creates a new Azure Service Definition XML
    .Description
        Creates a new Azure Service Definition XML.  
        Additional commands are used to modify the XML's settings
    .Example
        New-AzureServiceDefinition -ServiceName TestService |
            Add-AzureWebSite -HostHeader www.testsite.com -PhysicalDirectory 'C:\inetpub\wwwroot\testsite'
    .Link
        Add-AzureRole
    .Link
        Add-AzureStartupTask
    .Link
        Add-AzureWebSite
    .Link        
        Add-AzureLocalResource
    #>
    [OutputType([xml],[string])]
    param(
    # Required. The name of the service. The name must be unique within the service account.    
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias('Name')]
    [String]
    $ServiceName,
    
    <#
    Optional. Specifies the number of upgrade domains across which roles in this service are allocated.
    Role instances are allocated to an upgrade domain when the service is deployed. For more information, 
    see "How to Perform In-Place Upgrades" on MSDN.
    
    You can specify up to 5 upgrade domains. If not specified, the default number of upgrade domains is 5.
    #>
    [int]
    $UpgradeDomainCount,
    
    # If set, will output the XML as text.  If this is not set, an XmlElement is returned.
    [switch]
    $AsString
    )
    
    process {
        #region Declare the root XML
        if ($psBoundParameters.ContainsKey('UpgradeDomainCount')) {
            $def = @"
<ServiceDefinition name="$ServiceName" xmlns="http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition" upgradeDomainCount="$UpgradeDomainCount" /> 
"@
        } else {
            $def = @"
<ServiceDefinition name="$ServiceName" xmlns="http://schemas.microsoft.com/ServiceHosting/2008/10/ServiceDefinition" />
"@
        }
        #endregion Declare the root XML
        
        #region Output the configuration
        $xml = [xml]$def
        if ($AsString) {
            $strWrite = New-Object IO.StringWriter
            $xml.Save($strWrite)
            return "$strWrite"
        } else {
            $Xml
        }           
        #endregion Output the configuration
    }
} 
