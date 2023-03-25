function Get-Blob
{
    <#
    .Synopsis
        Gets blob of cloud data 
    .Description
        Gets blob of cloud data in Azure 
    .Example
        # Get all containers
        Get-Blob -StorageAccount MyAzureStorageAccount -StorageKey MyAzureStorageKey
    .Example
        # Get all items in mycontainer
        Get-Blob -StorageAccount MyAzureStorageAccount -StorageKey MyAzureStorageKey -Container MyContainer
    .Example
        # Get the content of the first blob in MyContainer
        Get-Blob -StorageAccount MyAzureStorageAccount -StorageKey MyAzureStorageKey -Container MyContainer | Select-Object -First 1 | Get-Blob
    .Link
        Remove-Blob
    .Link
        Import-Blob
    .Link 
        Export-Blob
    #>    
    [CmdletBinding(DefaultParameterSetName='GetAllBlobs')]
    [OutputType([PSObject])]
    param(    
    # The name of the container
    [Parameter(Mandatory=$true,Position=0, ValueFromPipelineByPropertyName=$true,ParameterSetName='GetSpecificBlob')]
    [Parameter(Mandatory=$true,Position=0, ValueFromPipelineByPropertyName=$true,ParameterSetName='GetSpecificContainer')]
    [Alias('Bucket')]
    [string]$Container,

    # The name of the blob
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='GetSpecificBlob')]
    [string]$Name,

    # The blob prefix
    [string]$Prefix,

    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey,

    # A shared access signature.  If this is a partial URL, the storage account is still required.
    [Alias('SAS')]
    [string]$SharedAccessSignature)


    begin {
        if (-not ('Web.HttpUtility' -as [type])) {
            Add-type -AssemblyName System.Web
        }

        if (-not $script:cachedContentTypes -and $PSVersionTable.Platform -ne 'Unix') {
            $script:cachedContentTypes = @{}
            $ctKey = [Microsoft.Win32.Registry]::ClassesRoot.OpenSubKey("MIME\Database\Content Type")
            $ctKey.GetSubKeyNames() |
                ForEach-Object {
                    $extension= $ctKey.OpenSubKey($_).GetValue("Extension") 
                    if ($extension) {
                        $script:cachedContentTypes["${extension}"] = $_
                    }
                }

        }

$getSignature = {
    param(
    [Collections.IDictionary]$Header,
    [Uri]$Url,
    [Uint32]$ContentLength,
    [string]$IfMatch  ="",
    [string]$Md5OrContentType = "",
    [string]$NowString = [DateTime]::now.ToString("R", [Globalization.CultureInfo]::InvariantCulture),
    [string]$method = "GET"
    )
    
    
    [String]::Format("{0}`n`n`n{1}`n`n{5}`n`n`n{2}`n`n`n`n{3}{4}", @(
        $method.ToUpper(),
        $(if ($method -eq "GET" -or $method -eq "HEAD") {[String]::Empty} else { $ContentLength }),
        $IfMatch,
        $(& $GetCanonicalizedHeader $Header),
        $( & $GetCanonicalizedResource $Url $StorageAccount),
        $Md5OrContentType
    ))
}

$GetCanonicalizedHeader = {param([Hashtable]$Header)
    $headerNameList = [Collections.ArrayList]::new(@($header.Keys -like 'x-ms-*'))
    $headerNameList.Sort()
    $headers = [Collections.Specialized.NameValueCollection]::new()
    $null = foreach ($h in $headerNameList) { $headers.Add($h, $header[$h]) }
    return @(foreach ($headerName in $headerNameList) {
        $headerName
        $values = $headers.GetValues($headerName)
        if ($values) {
            $headerValues = @(foreach ($str in $values) { 
                $str.TrimStart($null).Replace("`r`n", [String]::Empty)
            }) -join ','
            ":$headerValues"
        }
        "`n"
    }) -join ''
}

$GetCanonicalizedResource = {param([uri]$Address, [string]$AccountName)
    $str = [Text.StringBuilder]::new("/${accountName}$($address.AbsolutePath)")    
    $values2 = [Collections.Specialized.NameValueCollection]::new()

    $values = [Web.HttpUtility]::ParseQueryString($address.Query)
    foreach ($str2 in $values.Keys) {
        $list = [Collections.ArrayList]::new($values.GetValues($str2))            
        $values2.Add($str2.ToLowerInvariant(), $list -join ',')
    }
    
    $list2 = [Collections.ArrayList]::new($values2.AllKeys)
    $null = $list2.Sort()
    $null = foreach ($str3 in $list2) { $str.Append("`n${str3}:$($values2[$str3])"); }    
    return $str.ToString();
}
        
    }


    process {
        #region Handled Shared Access Signatures
        if (-not $SharedAccessSignature -and -not $StorageKey) {
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
        
        # Cache whatever account information we have, so that the next calls don't require it
        $script:CachedStorageAccount = $StorageAccount
        $script:CachedStorageKey = $StorageKey
        #endregion check for and cache the storage account

        # Azure Blob storage containers have to be lowercase, so just make the input lowercase for them
        if ($Container) {
            $Container = $Container.ToLower()
        }

        # Common header fields required by Azure
        $header = @{
            "x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
            "x-ms-version" = "2018-03-28"
            "DataServiceVersion" = "2.0;NetFx"
            "MaxDataServiceVersion" = "2.0;NetFx"
        }
        $nowString = $header.'x-ms-date'
        $getWebSplat = @{
            Method = 'GET'
            Header = $header            
            SignaturePrefix = "SharedKey " + $StorageAccount + ":"
            SignatureKey = $storageKey
            HideProgress = $true
            AsXml = $true
        }
        if ($PSCmdlet.ParameterSetName -eq 'GetAllBlobs') {
            $method = 'GET'
            
            $uri = "https://$StorageAccount.blob.core.windows.net/?comp=list&include=metadata$(if ($prefix) {$prefix= $prefix.ToLower(); "&prefix=$prefix"})"
            if ($SharedAccessSignature) {
                $uri += '&' + $SharedAccessSignature.TrimStart('?')
            } else {
                $getWebSplat += @{
                    Signature = & $getSignature -header $header -Url $uri -nowstring $nowstring -contentLength 0 -method GET                    
                }                                                      
            # Azure will return back an XML document containing a list of containers
            }
            $containerList = Get-Web -Url $Uri @getWebsplat
            # Each //Container node gets converted into a Property Bag
            $containerList | 
                Select-Xml //Container | 
                Select-object -ExpandProperty Node |
                ForEach-Object {
                    $item = $_
                    New-Object PSObject -property @{ 
                        Container = $_.Name                        
                        Url = $_.Url
                        LastModified = $_.Properties.'Last-Modified' -as [Datetime]    # Convert to a Strong Type (for convenience)
                    } 
                }
        } elseif ($PSCmdlet.ParameterSetName -eq 'GetSpecificContainer') {
            $method = 'GET'
            $uri = "https://$StorageAccount.blob.core.windows.net/${Container}?restype=container&comp=list&include=metadata$(if ($prefix) {$prefix= $prefix; "&prefix=$prefix"})"
            if ($SharedAccessSignature) {
                $uri += '&' + $SharedAccessSignature.TrimStart('?')
            } else {
                $getWebSplat += 
                    @{Signature = & $getSignature -header $header -Url $uri -nowstring $nowstring -contentLength 0}           
            }            
            # Blob general metadata comes back in an XML document
            $blobList = Get-Web -Url $Uri @GetWebParams 
            
            # Convert each Blob node into a property bag
            $blobList |
                Select-Xml //Blob | 
                Select-Object -ExpandProperty Node |
                & { process  {
                    [PSCustomObject][Ordered]@{
                        Container = $Container
                        Name = $_.Name
                        Url = $_.Url
                        LastModified = $_.Properties.'Last-Modified' -as [Datetime]    # Make XML dates friendly dates
                        Length = $_.Properties.'Content-Length' -as [BigInt] # Case the length string to a bigint (because blob files could be huge)
                        ContentType = $_.Properties.'Content-Type'
                    } 
                } }
        } elseif ($PSCmdlet.ParameterSetName -eq 'GetSpecificBlob') {
            # Rather than reinvent the wheel, we just call Import-Blob
            $blobData=  
                Import-Blob -Name $Name -Container $Container -StorageAccount $StorageAccount -StorageKey $StorageKey -SharedAccessSignature $SharedAccessSignature

            # Then we enumerate the blobs in this container, using the name as a prefix
            $blobs = Get-Blob -Container $Container -Prefix $Name -StorageAccount $StorageAccount -StorageKey $StorageKey -SharedAccessSignature $SharedAccessSignature

            foreach ($b in $blobs) {
                # Just in case there were many items with the same prefix, check for the specific name
                if ($b.Name -eq $name) {
                    
                    # If the name matches, add the blob data
                    Add-Member NoteProperty BlobData $blobData -Force -PassThru -InputObject $b 
                }
            }
        }
    }    
}