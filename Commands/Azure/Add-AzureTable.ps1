function Add-AzureTable
{
    <#
    .Synopsis
        Adds an Azure Table
    .Description
        Adds a table in Azure Table Storage
    .Example
        Add-AzureTable ATestTable
    .Link
        Get-AzureTable
    .Link
        Remove-AzureTable
    .Link
        Set-AzureTable
    #>
    [OutputType([PSObject])]
    param(
    # The name of the table
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName=$true, Position=0)]
    [Alias("Name")]    
    [string]$TableName,

    # The author name.  This is used in table metadata.
    [Parameter(ValueFromPipelineByPropertyName = $true, Position=1)]    
    [string]$Author,
    
    # The author email.  This is used in table metadata.
    [Parameter(ValueFromPipelineByPropertyName = $true, Position=2)]    
    [string]$Email,

    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey
    )
 
    process {
        #region check for and cache the storage account
        if (-not $StorageAccount) {
            $storageAccount = $script:CachedStorageAccount
        }

        if (-not $StorageKey) {
            $StorageKey = $script:CachedStorageKey
        }

        if (-not $StorageAccount) {
            Write-Error "No storage account provided"
            return
        }

        $b64StorageKey = try { [Convert]::FromBase64String("$storageKey") } catch { }

        if (-not $b64StorageKey -and $storageKey) {
            $storageKey =Get-SecureSetting -Name $storageKey -ValueOnly
        }

        if (-not $StorageKey) {
            Write-Error "No storage key provided"
            return
        }
        $script:CachedStorageAccount = $StorageAccount
        $script:CachedStorageKey = $StorageKey
        #endregion check for and cache the storage account
        
        #region Construct the Request Body
        $requestBody = @"
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
    <entry xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices"
        xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata"
        xmlns="http://www.w3.org/2005/Atom">
    <title />
    <updated>$([datetime]::UtcNow.ToString('o'))</updated>
    <author>
        <name/>
    </author>
    <id/>
    <content type="application/xml">
        <m:properties>
            <d:TableName>$TableName</d:TableName>
        </m:properties>
    </content>
</entry>
"@
        #endregion Construct the Request Body
        $uri = "https://$StorageAccount.table.core.windows.net/Tables" 
        $method = 'POST'
        $NowString = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)

        #region Set up Get-Web
        $GetWebParams = @{
            Url = $uri
            Header = @{
                "x-ms-version" = "2011-08-18"
                "DataServiceVersion" = "2.0;NetFx"
                "MaxDataServiceVersion" = "2.0;NetFx"
                'content-type' = "application/atom+xml"
                'Accept-Charset' = 'UTF-8'
                "x-ms-date" = $NowString
            }
            RequestBody = $RequestBody
            AsXml = $true
            ContentType = "application/atom+xml"
            HideProgress = $true
            Method = 'POST'
            SignatureKey = $storageKey
            SignaturePrefix = "SharedKey " + $StorageAccount + ":"
            UseWebRequest = $true            
        }
        #endregion Set up Get-Web

        # Add the message signature (composed from other parts of the message) 
        $GetWebParams += @{
            Signature = [String]::Format(
                    "{0}`n`n{1}`n{2}`n{3}",
                    @($method,"application/atom+xml",$NowString,"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                )
        }
        
        $tableList = Get-Web @GetWebParams 
        foreach ($e in $tableList.entry) {
            # Create an output object from the result
            $azureTable = New-Object PSObject -Property @{
                "TableName" = $e.content.properties.TableName
                "TableID" =  $e.Id
            }                        
            $azureTable
        }
    }
}

