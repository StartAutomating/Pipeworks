function Remove-AzureTable
{
    <#
    .Synopsis
        Removes a table from Azure Storage
    .Description
        Removes a table or an item in a table from Azure Table Storage
    .Example
        # Remove the table ZTestTable2, avoiding a prompt for confirmation
        Remove-AzureTable -TableName ZTestTable2
    .Example
        Remove-AzureTable -TableName ZTestTable2 -PartitionKey Default -RowKey Row
    .Link
        Add-AzureTable
    .Link
        Get-AzureTable
    .Link
        Set-AzureTable
        
    #>
    [CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true)]
    [OutputType([nullable])]
    param(
    # The name of the table
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true,  Position=0)]
    [Alias('Name')]        
    [string]$TableName,

    # The PartitionKey
    [Parameter(ValueFromPipelineByPropertyName = $true, Position=1)]
    [Alias('Partition', 'Part')]    
    [string]$PartitionKey,

    # The RowKey
    [Parameter(ValueFromPipelineByPropertyName = $true, Position=2)]    
    [Alias('Row')]
    [string]$RowKey,

    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey,

    # A shared access signature.  If this is a partial URL, the storage account is still required.
    [Alias('SAS')]
    [string]$SharedAccessSignature
    )

    process {
        #region Handled Shared Access Signatures
        if (-not $SharedAccessSignature) {
            $SharedAccessSignature = $script:CachedSharedAccessSignature
        }
        if ($SharedAccessSignature) {
            $script:CachedSharedAccessSignature = $SharedAccessSignature
            if ($SharedAccessSignature.StartsWith('https',[StringComparison]::OrdinalIgnoreCase)) {
                $StorageAccount = ([uri]$SharedAccessSignature).Host.Split('.')[0]
                $SharedAccessSignature = $SharedAccessSignature.Substring($SharedAccessSignature.IndexOf('?'))               
            }
            
            if (-not $SharedAccessSignature.StartsWith('?')) {
                Write-Error "Shared access signature is an invalid format"
                return                
            }
        }
        #endregion
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

        if (-not $StorageKey -and -not $SharedAccessSignature) {
            Write-Error "No storage key provided"
            return
        }
        $script:CachedStorageAccount = $StorageAccount
        $script:CachedStorageKey = $StorageKey

        $nowString = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
        $method = 'DELETE'
        $GetWebParams = @{
            Header = @{
                "x-ms-date" = $nowString 
                "x-ms-version" = "2011-08-18"
                "DataServiceVersion" = "2.0;NetFx"
                "MaxDataServiceVersion" = "2.0;NetFx"
                'content-type' = "application/atom+xml"                
            }
            AsXml = $true                    
            HideProgress = $true
            Method = $method
            SignatureKey = $storageKey
            SignaturePrefix = "SharedKey " + $StorageAccount + ":"
            UseWebRequest = $true            
        }

        if ($PSBoundParameters.TableName -and $PSBoundParameters.PartitionKey -and $PSBoundParameters.RowKey) {
            if ($PSCmdlet.ShouldProcess("DELETE $tablename/$PartitionKey/$RowKey")) {
                $uri = "https://$StorageAccount.table.core.windows.net/${TableName}(PartitionKey='$partitionKey',RowKey='$rowKey')"
                $GetWebParams.Header.'If-Match' = '*'
                if ($SharedAccessSignature -and -not $StorageKey) {
                    $GetWebParams += @{
                        Uri = $uri + $SharedAccessSignature                        
                    }
                } else {
                    $GetWebParams += @{
                        Uri = $uri
                        Signature = [String]::Format(
                            "{0}`n`n{1}`n{2}`n{3}",
                            @($method,"application/atom+xml",$NowString,"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                        )
                    }
                }
                                                                                
                Get-Web @GetWebParams 
            }
        } else {
            # Deleting a table
            if (-not $StorageAccount -and $SharedAccessSignature) {
                Write-Error 'Cannot delete a table with a shared access signature'
                return
            }
            if ($PSCmdlet.ShouldProcess("DELETE $tablename")) {
                $uri = "https://$StorageAccount.table.core.windows.net/Tables('$TableName')"
                $GetWebParams += @{
                    Uri = $uri
                    Signature = [String]::Format(
                        "{0}`n`n{1}`n{2}`n{3}",
                        @($method,"application/atom+xml",$NowString,"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                    )
                }                                
                Get-Web @GetWebParams 
            }            
        }       
    }
}