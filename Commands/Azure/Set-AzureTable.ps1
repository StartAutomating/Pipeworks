function Set-AzureTable
{
    <#
    .Synopsis
        Sets data in Azure Table Storage
    .Description
        Sets or updates data in Azure Table Storage
    .Example
        New-Object PSObject -Property @{number=1;word='words'} | Set-AzureTable -TableName ZTestTable3 
    .Example
        New-Object PSObject -Property @{letter='l'} | Set-AzureTable -TableName ZTestTable3  -Merge
    .Example
        New-Object PSObject -Property @{number=2} | Set-AzureTable -TableName ZTestTable3  -force             
    .Example
        Set-AzureTable @{number=1;letter='l';word='words'} ZTestTable3 Part Row -Force
    .Link
        Add-AzureTable
    .Link
        Get-AzureTable
    .Link
        Remove-AzureTable
    .Notes
        For backwards compatiblity, Update-AzureTable is aliased to Set-AzureTable with a few changes in parameter defaults.  
        
        If you use the alias Update-AzureTable, it's the same as calling Set-AzureTable with -TryUpdateFirst.
        
    #>
    [OutputType([nullable], [PSObject])]
    param(
    # The input object.  This is the data that will be stored in Azure Table Storage.
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [Alias('Value')]
    [PSObject]
    $InputObject,

    # The name of the table
    [Parameter(Mandatory = $true, Position=1,ValueFromPipelineByPropertyName = $true)]    
    [Alias("Name")]    
    [string]$TableName,

    # The PartitionKey
    [Parameter(ValueFromPipelineByPropertyName = $true, Position=2)]
    [Alias("TablePart", "TablePartition", "Partition")]
    [string]$PartitionKey,


    # The RowKey
    [Parameter(ValueFromPipelineByPropertyName = $true, Position=3)]
    [Alias("TableRow", "Row")]
    [string]$RowKey,

    
    # If set, will output the object that was inserted into Table Storage.  
    # Note - if the object was updated or merged, instead of set, this will involve an additional call to Get-AzureTable.
    [Switch]$PassThru,

    # If set, will Force an update of an object that already exists
    [Switch]$Force,

    # If set, will Merge the input data into an existing item in table storage, instead of overwriting it.  
    [Switch]$Merge,

    # If set, will try to overwrite an existing object first, and will set a new object if -Force is provided
    [Switch]$TryUpdateFirst,
    
    # If set, will try to merge an existing object first, and will set a new object if -Force is provided 
    [Switch]$TryMergeFirst,

    # If set, will exclude table info from any outputted object.  Unless -Passthru is used, this parameter has no effect.
    [Switch]$ExcludeTableInfo,
    
    # The author name.  Used for table storage metadata.
    [Parameter(ValueFromPipelineByPropertyName = $true)]    
    [string]$Author,
    
    # The author email.  Used for table storage metadata.
    [Parameter(ValueFromPipelineByPropertyName = $true)]    
    [string]$Email,

    # If a series of objects are piped in without any Row information, numeric rows will be used.  -StartAtRow indicates which row Set-AzureTable should start at under these circumstances.  It defaults to 0.
    [uint32]
    $StartAtRow = 0,

    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey,

    # A shared access signature.  If this is a partial URL, the storage account is still required.
    [Alias('SAS')]
    [string]$SharedAccessSignature
    )

    begin {
        $myInv = $MyInvocation
        
        #region Azure Common Code
        $InsertEntity = {
    param($tableName, $partitionKey, $rowKey, $inputObject, $author, $email, $storageAccount, $storageKey, [switch]$Update, [switch]$Merge, [Switch]$ExcludeTableInfo)

    $propertiesString = new-object Text.StringBuilder
    $null= $propertiesString.Append([string]::Format("<d:{0}>{1}</d:{0}>
", "PartitionKey", $partitionKey))
    $null= $propertiesString.Append([string]::Format("<d:{0}>{1}</d:{0}>
", "RowKey", $rowKey))
    $typenames =$inputObject.PSTypenames
    if ($typenames[-1] -ne "System.Object" -and $typenames[-1] -ne "System.Management.Automation.PSObject") {
        $typenames = $typenames -join ','
        $null = $propertiesString.Append([string]::Format("<d:psTypeName>{0}</d:psTypeName>", [Security.SecurityElement]::Escape($typenames)));
    }
    
    
    foreach ($p in $inputObject.PSObject.Properties)
    {
        try
        {
                            
            $valueToInsert = [Management.Automation.LanguagePrimitives]::ConvertTo($p.Value, [string]);
                            
            $TypeString = [String]::Empty

            $valueType = if ($p.Value) {
                $p.Value.GetType()
            } else {
                $null
            }
            if ($valueType -eq [int]) {
                $TypeString = " m:type='Edm.Int32'"
                $valueString   = $valueToInsert.ToString()
            } elseif ($valueType -eq [bool]) {
                $TypeString = " m:type='Edm.Boolean'"
                $valueString   = $valueToInsert.ToString()
            } elseif ($valueType -eq [Double] -or $valueType -eq [Float]) {
                $TypeString = " m:type='Edm.Double'"
                $valueString   = $valueToInsert.ToString()
            } elseif ($valueType -eq [DateTime]) {
                $TypeString = " m:type='Edm.DateTime'"
                $valueString   = $valueToInsert.ToString('o')
            } elseif ($valueType -eq [long]) {
                $TypeString = " m:type='Edm.Long'"
                $valueString   = $valueToInsert.ToString()
            } else {
                $valueString  = [Security.SecurityElement]::Escape($valueToInsert)
            }
            $null = $propertiesString.Append([string]::Format("<d:{0}$TypeString>{1}</d:{0}>
", $p.Name, $valueString ))
        }
        catch
        {
            $null = $null
        }
    }        

    $IdString = if ($Merge -or $Update) {
        "http://$storageAccount.table.core.windows.net/$tableName(PartitionKey='$PartitionKey',RowKey='$RowKey')"
    } else {
        [String]::Empty
    }

    $requestBody = "<?xml version='1.0' encoding='utf-8' standalone='yes'?>
<entry xmlns:d='http://schemas.microsoft.com/ado/2007/08/dataservices'
    xmlns:m='http://schemas.microsoft.com/ado/2007/08/dataservices/metadata'
    xmlns='http://www.w3.org/2005/Atom'>
        <title />
        <updated>$([datetime]::UtcNow.ToString('o'))</updated>
        <author>
            $(if ($Author) {
                "<name>$([Security.SecurityElement]::Escape($author))</name>"
            } else {
                "<name/>"
            })
            $(if ($email) { "<email>$([Security.SecurityElement]::Escape($email))</email>"})            
        </author>
        <id>$IdString</id> 
        <content type='application/xml'>
            <m:properties> 
                $propertiesString
            </m:properties> 
        </content>
</entry>"
    
    $uri = "https://$StorageAccount.table.core.windows.net/$tableName(PartitionKey='$partitionKey',RowKey='$rowKey')"
    $nowString = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
    $GetWebParams = @{
        Header = @{
            "x-ms-date" = $nowString 
            "x-ms-version" = "2011-08-18"
            "DataServiceVersion" = "2.0;NetFx"
            "MaxDataServiceVersion" = "2.0;NetFx"
            'content-type' = "application/atom+xml"
            'Accept-Charset' = 'UTF-8'
        }
        AsXml = $true                    
        HideProgress = $true                
        UseWebRequest = $true            
        RequestBody = $requestBody
        SignatureKey = $storageKey
        SignaturePrefix = "SharedKey " + $StorageAccount + ":"
        ContentType = "application/atom+xml"
    }
    
    if ($merge -or $Update) {
        
        $getWebParams.Header.'If-Match' = '*'
    }
        
    if ($Merge) {
        if ($SharedAccessSignature -and -not $storageKey) {
            $getWebParams += @{
                Method = 'MERGE'
                Uri = $uri + $SharedAccessSignature
            }
        } 
        else {
            $getWebParams += @{
                Method = 'MERGE'
                Uri = $uri
                Signature = [String]::Format(
                    "{0}`n`n{1}`n{2}`n{3}",
                    @('MERGE',"application/atom+xml",$NowString,"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                )
            }
        }
        Get-Web @GetWebParams 
    } elseif ($Update) {
        if ($SharedAccessSignature) {
            $getWebParams += @{
                Method = 'PUT'
                Uri = $uri + $SharedAccessSignature
            }
        } 
        else {
            $getWebParams += @{
                Method = 'PUT'
                Uri = $uri
                Signature = [String]::Format(
                    "{0}`n`n{1}`n{2}`n{3}",
                    @('PUT',"application/atom+xml",$NowString,"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                )
            }
        }
        
        Get-Web @GetWebParams 
    } else {
        $uri = "https://$StorageAccount.table.core.windows.net/$tableName"
        
        if ($SharedAccessSignature) 
        {
            $getWebParams += @{
                Method = 'POST'
                Uri = $uri + $SharedAccessSignature                
            }
        } else 
        {
            $getWebParams += @{
                Method = 'POST'
                Uri = $uri
                Signature = [String]::Format(
                    "{0}`n`n{1}`n{2}`n{3}",
                    @('POST',"application/atom+xml",$NowString,"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                )
            }
        }
        
        
        Get-Web @getWebParams 
    }
}

        $ConvertEntityToPSObject = {
            param([Parameter(ValueFromPipeline=$true,Position=0)]$Entity)            
            process {
                $newObject = New-Object PSObject 

                foreach ($prop in $entity.content.properties.childnodes) {
                    if ($prop.LocalName -eq 'pstypename') {
                        $newObject.pstypenames.clear()
                        foreach ($tn in @($prop.'#Text' -split ',')) {
                            $newObject.pstypenames.add($tn)    
                        }
                        continue
                    }
                
                    $notePropType = 
                        if ($prop.type -eq 'Edm.Boolean') {
                            [bool]
                        } elseif ($prop.Type -eq 'Edm.Datetime') {
                            [datetime]
                        } elseif ($prop.Type -eq 'Edm.Double') {
                            [double]
                        } elseif ($prop.Type -eq 'Edm.Int32') {
                            [int]
                        } elseif ($prop.Type -eq 'Edm.Int64') {
                            [long]
                        } else {
                            [string]
                        }

                

                    if ($ExcludeTableInfo -and 'PartitionKey', 'RowKey', 'Timestamp' -contains $prop.LocalName) {                    
                        continue                    
                    }
                
                    $notePropValue = [Management.Automation.LanguagePrimitives]::ConvertTo($prop.'#text', $notePropType);
                    $newObject.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty $prop.LocalName,$notePropValue))
                }

                if ((-not $ExcludeTableInfo) -and 
                    ((-not $Select) -or ($Select -contains 'TableName')) -and 
                    -not $newObject.TableName -and 
                    $newObject.PSObject.Properties.Count -gt 0) {
                    $newObject.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty 'TableName',$TableName))
                }

                if ($newObject.PSObject.Properties.Count -gt 0) {
                    $newObject
                }
                
            }
        }
#endregion Azure Common Code

        
    }

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
        if (-not $currentRow) {
            $currentRow = $StartAtRow
        }

        if (-not $StorageAccount) {
            $storageAccount = $script:CachedStorageAccount
        }

        if (-not $StorageKey) {
            $StorageKey = $script:CachedStorageKey
        }

        $b64StorageKey = try { [Convert]::FromBase64String("$storageKey") } catch { }

        if (-not $b64StorageKey -and $storageKey) {
            $storageKey =Get-SecureSetting -Name $storageKey -ValueOnly
        }

        if (-not $StorageAccount) {
            Write-Error "No storage account provided"
            return
        }

        if (-not $StorageKey -and -not $SharedAccessSignature) {
            Write-Error "No storage key provided"
            return
        }
        $script:CachedStorageAccount = $StorageAccount
        $script:CachedStorageKey = $StorageKey
        #endregion check for and cache the storage account

        
        $isReallyUpdate = $myInv.InvocationName -eq 'Update-AzureTable' -or $myInv.InvocationName -eq 'uat'

        if ($isReallyUpdate) {            
            if ($Merge) {
                $TryMergeFirst = $true
            } else {
                $TryUpdateFirst = $true
            }
        }
        if (-not $psBoundParameters.RowKey) {            
            $RowKey = $currentRow
            $currentRow++
        }

        if (-not $PartitionKey) {
            $PartitionKey = "Default"
        }
        
        $WasMergeOrUpdate = $false
        

        if ($inputObject -is [Hashtable]) {
            $inputObject = New-Object PSObject -Property $inputObject
        }

        
        $OperationResult = 
            if ($TryUpdateFirst) {             
                $tryToSet = & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey -Update 2>&1
                if ($tryToSet -is [Management.Automation.ErrorRecord]) {
                    $errorCode = ($tryToSet.Exception.Message -as [xml]).error.code
                    if ($errorCode -eq 'ResourceNotFound' -and $Force) {
                        & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey
                    }
                } else {
                    $WasMergeOrUpdate = $true
                    $tryToSet
                    
                }
            } elseif ($TryMergeFirst) {
                $tryToSet = & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey -Merge 2>&1
                if ($tryToSet -is [Management.Automation.ErrorRecord]) {
                    $errorCode = ($tryToSet.Exception.Message -as [xml]).error.code
                    if ($errorCode -eq 'ResourceNotFound' -and ($Force -or $Merge)) {
                        & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey
                    } else {
                        Write-Error -ErrorRecord $tryToSet
                    }
                } else {
                    $WasMergeOrUpdate = $true
                    $tryToSet
                }
            } else {
                $tryToSet = & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey 2>&1            
                if ($tryToSet -is [Management.Automation.ErrorRecord]) {
                    $errorCode = ($tryToSet.Exception.Message -as [xml]).error.code
                    if ($errorCode -eq 'EntityAlreadyExists') {
                        if ($Force -or $Merge) {
                            if ($Force) {
                                $WasMergeOrUpdate = $true
                                & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey -Update
                            } elseif ($Merge) {
                                $WasMergeOrUpdate = $true
                                & $InsertEntity $TableName $PartitionKey $RowKey $InputObject $Author $Email -ExcludeTableInfo:$ExcludeTableInfo -storageAccount $StorageAccount -storageKey $StorageKey -Merge        
                            } 
                        } else {
                            Write-Error -ErrorRecord $tryToSet
                            return
                        }
                    } else {
                        Write-Error -ErrorRecord $tryToSet
                        return
                    }               
                } else {
                    $tryToSet
                }
            }
        
        if ($OperationResult -and $PassThru) {
            $OperationResult.entry |                
                ForEach-Object $ConvertEntityToPSObject
        } elseif ($PassThru -and $WasMergeOrUpdate) {
            # Updates and Merges don't actually return a result, so we have to do a Get
            Get-AzureTable -TableName $tableName -Partition $partitionKey -Row $rowKey 
        }
    }
}
