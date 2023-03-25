function Get-AzureTable
{
    <#
    .Synopsis
        Gets data from Azure Table Storage
    .Description
        Gets or searches data in Azure Table Storage
    .Example
        # Get all tables
        Get-AzureTable       
    .Example
        # Get a specific item in a table
        Get-AzureTable -TableName ZTestTable -PartitionKey part -RowKey row
    .Example
        # Get all items in a table
        Get-AzureTable -TableName ZTestTable -PartitionKey part -RowKey row            
    .Example
        # Search a table with PowerShell syntax.  The Where clause is converted into an Azure filter and run in the cloud.
        Get-AzureTable -TableName ZTestTable -Where { $_.PartitionKey -eq 'part' -and $_.RowKey -eq 'row' } 
    .Example
        # Search a table with Powershell syntax, using a numeric value.  The Where clause is converted into an Azure filter and run in the cloud.
        Get-AzureTable -TableName ZTestTable -Where { $_.PartitionKey -eq 'part' -and $_.Count -gt 5 } 
    .Example
        # Search a table with OData filter syntax.  For more information on supported filters, see [MSDN](https://msdn.microsoft.com/en-us/library/azure/dd894031.aspx)
        Get-AzureTable -TableName ZTestTable -Filter "PartitionKey eq 'part' and Count gt 5"
    .Example
        # Find the first 10 items that match a given condition
        Get-AzureTable -TableName ZTestTable -First 10 -Where { $_.PartitionKey -eq 'part' } 
    .Example
        # Get items that match a condition in pages of 10
        $Page = @(Get-AzureTable -TableName ZTestTable -First 10 -Where { $_.PartitionKey -eq 'part' })
        do {
            $Page
            if ($page[-1].NextRowKey -and $page[-1].NextPartitionKey) {
                $page = $page[-1] |
                    Get-AzureTable -First 10 -Where { $_.PartitionKey -eq 'part' }
            } else {
                $page = $null
            }
        } while ($Page)
    .Example
        # Get everything in a table.
        Get-AzureTable -TableName ZTestTable -All 
    .Example
        # Get everything in a table, in batches of 5 (note, smaller batch sizes mean long queries will take even longer)
        Get-AzureTable -TableName ZTestTable -All -BatchSize 5
    .Link
        Add-AzureTable
    .Link
        Remove-AzureTable
    .Link 
        Set-AzureTable
    .Notes
        Get-AzureTable is also aliased with Search-AzureTable.  For backwards compatbility, it uses an interesting trick.  
        
        
        Calling Get-AzureTable with the alias Search-AzureTable will search a table instead of get it's metadata (if provided only a TableName).  
        This is the same as passing the -All parameter.
    #>    
    [CmdletBinding(DefaultParameterSetName='AllTables')]
    [OutputType([PSObject])]
    param(    
    # The name of the queue
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='SpecificTableItem')]
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [string]$TableName,

    # The blob prefix
    [string]$Prefix,

    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey,

    # A shared access signature.  If this is a partial URL, the storage account is still required.
    [Alias('SAS')]
    [string]$SharedAccessSignature,

    # If set, will peek at the messages in the queue, instead of retreiving them 
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='SpecificTableItem')]
    [Alias('Partition')]
    [string]
    $PartitionKey,

    # The number of messages to retreive from a queue
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='SpecificTableItem')]
    [Alias('Row')]
    [string]
    $RowKey,

    # A search filter for Azure Table Storage.  For more information on filter syntax, see [MSDN](https://msdn.microsoft.com/en-us/library/azure/dd894031.aspx)
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [string]
    $Filter,

    # A PowerShell filter for Azure Table Storage.  Filters are converted to OData syntax, and only a limited number of operators are supported.  Additionally, expect case-sensitivity and type-sensitivty.
    [Parameter(Mandatory=$true,ParameterSetName='SearchTableWithWhere',ValueFromPipelineByPropertyName=$true)]
    [ScriptBlock[]]
    $Where,

    # A list of properties to select from the item.  This will omit built-in properties (.Timestamp, .RowKey, .PartitionKey, and .TableName) if they are not included in the Select statement
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SpecificTableItem')]
    [string[]]
    $Select,

    # If provided, will only get the first N items from a filter.  
    # If there are more items, the last item will have an additional property containing continuation information.
    # Passing this information back into Get-AzureTable allows you to paginate results
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [Uint32]
    [Alias('Top')]
    $First,
    
    # If set, will omit table properties (.RowKey, .PartitonKey, .TableName, and .Timestamp) from the returned objects
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SpecificTableItem')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [Switch]
    $ExcludeTableInfo,

    # If provided, will resume an existing search filter using this NextRowKey
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [string]
    $NextRowKey,

    # If provided, will resume an existing search filter using this NextPartitionKey
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [string]
    $NextPartitionKey,

    # Optionally sets the batch size.  If -First is set, it will override this setting.  BatchSize should be left to it's default if your objects are small, but smaller batch sizes may be useful for throttling large objects.
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithWhere')]
    [ValidateRange(0, 999)]
    [Uint32]
    $BatchSize,
    
    # If set, will return all objects from a table.  Calling Get-AzureTable with the alias Search-AzureTable achieves the same effect.
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='SearchTableWithFilter')]
    [Switch]
    $All
    )


    begin {
        $myInv = $MyInvocation        
        Add-type -AssemblyName System.Web       
        
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
        $ConvertTableMetadata = {
            param([Parameter(ValueFromPipeline=$true,Position=0)]$Entity)            
            process {
                $newObject = New-Object PSObject
                $newObject.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty 'TableID',$entity.id))
                $newObject.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty 'Updated',($entity.updated -as [DateTime])))
                $newObject.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty 'TableName',$entity.content.properties.TableName))

                if ($TableName -and ($TableName.Contains('*') -or $TableName.Contains('?'))) {
                    if ($newObject.TableName -like $TableName) {
                        $newObject
                    } 
                } elseif ($TableName) {
                    if ($newObject.TableName -eq $TableName) {
                        $newObject
                    }
                } else {
                    $newObject
                }
                
            }
        }
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
            $storageKey = Get-Secret -Name $storageKey -AsPlainText
        }

        if (-not $StorageKey -and -not $SharedAccessSignature) {
            Write-Error "No storage key provided"
            return
        }

        if ($Container) {
            $Container = $Container.ToLower()
        }

        $script:CachedStorageAccount = $StorageAccount
        $script:CachedStorageKey = $StorageKey
        #endregion check for and cache the storage account

        if ($PSCmdlet.ParameterSetName -eq 'SearchTableWithWhere') {
            
            $FilterParts = 
                foreach ($whereClause in $where) {
                    $whereTokens = [Management.Automation.PSParser]::Tokenize($whereClause, [Ref]$null)
                    $LastDollarUnderbar = $null
                    $NewFilter = ""
                    for ($whereTokenCounter =0 ; $whereTokenCounter -lt $whereTokens.count; $whereTokenCounter++) {
                        if ($whereTokens[$whereTokenCounter].Type -eq 'Variable' -and 
                            $whereTokens[$whereTokenCounter].Content -eq '_' -and
                            $whereTokens[$whereTokenCounter + 1].Type -eq 'Operator' -and 
                            $whereTokens[$whereTokenCounter + 1].Content -eq '.') {
                            $LastDollarUnderbar = $whereTokens[$whereTokenCounter]
                            $whereTokenCounter++
                            continue
                        }

                        if ($whereTokens[$whereTokenCounter].Type -eq 'Member') {
                            if (-not $LastDollarUnderbar) {
                                Write-Error "Can only access members of `$_"
                                return                                    
                            } else {
                                $NewFilter += "$($whereTokens[$whereTokenCounter].Content)"
                            }
                            continue
                        }


                        if ($whereTokens[$whereTokenCounter].Type -eq 'Operator') {
                            if ($LastDollarUnderbar) {
                                if ("-gt", "-lt", "-ge", "-le", "-ne", "-eq" -contains $whereTokens[$whereTokenCounter].Content) {
                                    $newFilter += " $($whereTokens[$whereTokenCounter].Content.TrimStart('-')) " 
                                    continue
                                } else {
                                    
                                    
                                    Write-Error "Comparison operator $($whereTokens[$whereTokenCounter].Content) is not supported.  Use one of the following supported operators: -gt, -lt, -ge, -le,-ne,-eq"
                                    return
                                    
                                    
                                }
                            } else {
                                if ("-and", "-or" -contains $whereTokens[$whereTokenCounter].content) {
                                    $newFilter += " $($whereTokens[$whereTokenCounter].Content.TrimStart('-')) " 
                                } else {
                                    
                                    Write-Error "Only the -and and -or operator can be used between clauses"
                                    return
                                    
                                    
                                }
                            }
                        }

                        if ($whereTokens[$whereTokenCounter].Type -eq 'String') {
                            $NewFilter += "'$($whereTokens[$whereTokenCounter].Content.Replace("'", "''"))'"
                            $LastDollarUnderbar = $false
                        } elseif ($whereTokens[$whereTokenCounter].Type -eq 'Number') {
                            $NewFilter += "$($whereTokens[$whereTokenCounter].Content)"
                            $LastDollarUnderbar = $false
                        } elseif ($whereTokens[$whereTokenCounter].Type -eq 'Variable') {
                            $varValue = $ExecutionContext.SessionState.PSVariable.Get($whereTokens[$whereTokenCounter].Content).Value
                            if ($varValue -as [Double] -ne $null) {
                                $NewFilter += "$($whereTokens[$whereTokenCounter].Content)"
                                $LastDollarUnderbar = $false
                            } elseif ($varValue -is [bool]) {
                                $NewFilter += "$($varValue.ToLower())"
                                $LastDollarUnderbar = $false
                            } elseif ($varValue) {
                                $NewFilter += "'$($varValue.ToString().Replace("'","''"))'"
                                $LastDollarUnderbar = $false
                            }
                        }                                                                                                
                    }                   
                    $NewFilter                     
                }
            $filter = $FilterParts -join ' and '             
            #endregion            
        }

        $params = @{} + $PSBoundParameters

        # Store this here, so we can act like it has changed later
        $parameterSetName = $PSCmdlet.ParameterSetName

        # MyInvocaiton (cached to $MyInv in begin) will actually tell me the invocation name, which, if it was called with an alias, will be the alias
        if ('SearchTableWithFilter', 'SearchTableWithWhere' -contains $parameterSetName -and 
            $myInv.InvocationName -eq 'Get-AzureTable' -and              
            -not ($All -or $Filter -or $Where)) {
            $parameterSetName = 'AllTables'
        }
        
        $header = @{
            "x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
            "x-ms-version" = "2011-08-18"
            "DataServiceVersion" = "2.0;NetFx"
            "MaxDataServiceVersion" = "2.0;NetFx"
        }
        $GetWebParams = @{
            Method = 'GET'
            HideProgress = $true
            AsXml = $true
            ContentType = 'application/atom+xml' 
            Header = $header
            SignatureKey = $storageKey
            SignaturePrefix = "SharedKey " + $StorageAccount + ":"
            UseWebRequest = $true
        }

        if ($parameterSetName -eq 'AllTables') {
            if ($SharedAccessSignature -and -not $StorageKey) {
                Write-Error "Cannot list all tables with a shared access signature"
                return
            }
                                    
            $uri = "https://$StorageAccount.table.core.windows.net/Tables/" 
            $GetWebParams += @{
                Url = $uri
                Signature = [String]::Format(
                    "{0}`n`n{1}`n{2}`n{3}",
                    @($GetWebParams.method,"application/atom+xml",$header.'x-ms-date',"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                )                
            }                                                                        
            $containerList = Get-Web @GetWebParams #-UseWebRequest -Header $header -Url $Uri -Method GET -HideProgress -AsXml -ContentType 'application/atom+xml'            
            $containerList.feed.entry |
                & $ConvertTableMetadata
        } elseif ($parameterSetName -eq 'SpecificTableItem') {
            

            $uri = "https://$StorageAccount.table.core.windows.net/${TableName}(PartitionKey='$PartitionKey',RowKey='$RowKey')?" 
            

            $header += @{
                'If-Match' = '*'                
            }
            
            if ($SharedAccessSignature -and -not $StorageKey) {
                $getWebParams += @{
                    Uri = $uri.TrimEnd('?') + $SharedAccessSignature
                }
            } else {
                $GetWebParams += @{
                    Url = $uri
                    Signature = [String]::Format(
                        "{0}`n`n{1}`n{2}`n{3}",
                        @($GetWebParams.method,"application/atom+xml",$header.'x-ms-date',"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                    )                
                }
            }
            
            $containerList = Get-Web @getWebParams 
             
            $containerList.entry |                
                & $ConvertEntityToPSObject
        } elseif ($parameterSetName -eq 'SearchTableWithFilter' -or 
            $parameterSetName -eq 'SearchTableWithWhere') {
            $uri = "http://$StorageAccount.table.core.windows.net/${TableName}()?" 
            $uriParts = New-Object Collections.ArrayList
            if ($Filter) {
                $null =$UriParts.Add("`$filter=$([Uri]::EscapeDataString($Filter))")
            }

            if ($Select) {
                $null =$UriParts.Add("`$select=$([Web.HttpUtility]::UrlEncode(($Select -join ',')))")
            }

            if ($First) {
                $null =$UriParts.Add("`$top=$First")
            } elseif ($BatchSize) {
                $null =$UriParts.Add("`$top=$BatchSize")
            }

            if ($NextRowKey) {
                $null =$UriParts.Add("NextRowKey=$([Web.HttpUtility]::UrlEncode($NextRowKey))")
            }

            if ($NextPartitionKey) {
                $null =$UriParts.Add("NextPartitionKey=$([Web.HttpUtility]::UrlEncode($NextPartitionKey))")
            }
                        
            $header +=@{ 'Accept' = 'application/atom+xml,application/xml'}
            if ($SharedAccessSignature -and -not $StorageKey) {
                $GetWebParams += @{
                    Url = "$uri".TrimEnd('?') + $SharedAccessSignature + '&' + ($uriParts -join '&')
                    OutputResponseHeader = $true
                }
            } else {
                $GetWebParams += @{
                    Url = "$uri$($uriParts -join '&')"
                    Signature = [String]::Format(
                        "{0}`n`n{1}`n{2}`n{3}",
                        @($GetWebParams.method,"application/atom+xml",$header.'x-ms-date',"/$StorageAccount$(([uri]$uri).AbsolutePath)")
                    )
                    OutputResponseHeader = $true                
                }
            }
                        
            $containerList = Get-Web @getWebParams # -UseWebRequest -Header $header -Url $Uri -Method GET -HideProgress -AsXml -ContentType 'application/atom+xml' -OutputResponseHeader -UserAgent ' '
            $entryList = @($containerList.feed.entry)  
            for ($entryCounter =0 ; $entryCounter -lt $entryList.Count; $entryCounter++) {
                $entry = $entryList[$entryCounter]                
                $convertedEntry = . $ConvertEntityToPSObject $entry
                if ($entryCounter -eq ($entryList.Count - 1)) {
                    if ($containerList.Headers.'x-ms-continuation-NextRowKey' -and $containerList.Headers.'x-ms-continuation-NextPartitionKey') {
                        if ($First) {
                            # Output the continuation data, but don't continue   
                            if (-not $ExcludeTableInfo) {
                                $convertedEntry.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty 'NextRowKey',$containerList.Headers.'x-ms-continuation-NextRowKey'))
                                $convertedEntry.PSObject.Properties.Add((New-Object Management.Automation.PSNoteProperty 'NextPartitionKey',$containerList.Headers.'x-ms-continuation-NextPartitionKey'))
                            }
                            $convertedEntry
                        } else {
                            $ConvertedEntry
                            $ToSplat = @{} + $params
                            $toSplat.Remove('Where')
                            $ToSplat.Filter = $Filter
                            $ToSplat.NextRowKey = $containerList.Headers.'x-ms-continuation-NextRowKey'
                            $ToSplat.NextPartitionKey = $containerList.Headers.'x-ms-continuation-NextPartitionKey'
                            Get-AzureTable @toSplat
                        }
                    } else {
                        $convertedEntry
                    }
                } else {
                    $convertedEntry
                }
            }
        }
    } 
}