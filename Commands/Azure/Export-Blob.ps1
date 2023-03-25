function Export-Blob
{
    <#
    .Synopsis
        Exports data to a cloud blob
    .Description
        Exports data to a blob in Azure 
    .Example
        Get-ChildItem -Filter *.ps1 |
            Export-Blob -Container scripts -StorageAccount astorageAccount -StorageKey (Get-Secret aStorageKey -AsPlainText)
    .Link
        Get-Blob
    .Link
        Import-Blob
    .Link
        Remove-Blob
    #>
    [OutputType([Nullable])]    
    param(
    # The input object for the blob.  
    [Parameter(ValueFromPipeline=$true)]
    [PSObject]
    $InputObject,

    # The name of the container
    [Parameter(Mandatory=$true,Position=0, ValueFromPipelineByPropertyName=$true)]
    [string]$Container,

    # The name of the blob
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true)]
    [string]$Name,

    # The content type.  If a file is provided as input, this will be provided automatically.  If not, it will be text/plain
    [string]$ContentType = "text/plain",

    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey,

    # A shared access signature.  If this is a partial URL, the storage account is still required.
    [Alias('SAS')]
    [string]$SharedAccessSignature,

    # If set, the container the blob is put into will be made public
    [Switch]
    $Public)


    begin {

        #region Create a lookup table of mime types
        if (-not $script:cachedContentTypes) {
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
        #endregion Create a lookup table of mime types

        # Create a lambda to sign messages
$signMessage = {
    param(
    [Hashtable]$Header,
    [Uri]$Url,
    [Uint32]$ContentLength,
    [string]$IfMatch  ="",
    [string]$Md5OrContentType = "",
    [string]$NowString = [DateTime]::now.ToString("R", [Globalization.CultureInfo]::InvariantCulture),
    [Switch]$IsTableStorage,    
    [string]$method = "GET",
    [string]$Storageaccount,
    [string]$StorageKey
    )

    $method = $method.ToUpper()
    $MessageSignature = 
    if ($IsTableStorage) {
        [String]::Format("{0}`n`n{1}`n{2}`n{3}",@(
            $method,
            "application/atom+xml",
            $NowString,
            ( & $GetCanonicalizedResource $Url $StorageAccount)))

    } else {
        if ($md5OrCOntentType) {
            [String]::Format("{0}`n`n`n{1}`n`n{5}`n`n`n{2}`n`n`n`n{3}{4}", @(
                $method,
                $(if ($method -eq "GET" -or $method -eq "HEAD") {[String]::Empty} else { $ContentLength }),
                $IfMatch,
                "$(& $GetCanonicalizedHeader $Header)",
                "$( & $GetCanonicalizedResource $Url $StorageAccount)",
                $Md5OrContentType
                ));
        } else {
            [String]::Format("{0}`n`n`n{1}`n{5}`n`n`n`n{2}`n`n`n`n{3}{4}", @(
                $method,
                $(if ($method -eq "GET" -or $method -eq "HEAD") {[String]::Empty} else { $ContentLength }),
                $IfMatch,
                "$(& $GetCanonicalizedHeader $Header)",
                "$( & $GetCanonicalizedResource $Url $StorageAccount)",
                $Md5OrContentType
                ));
        }        
    }    

    $SignatureBytes = [Text.Encoding]::UTF8.GetBytes($MessageSignature)

    [byte[]]$b64Arr = [Convert]::FromBase64String($StorageKey)
    $SHA256 = new-object Security.Cryptography.HMACSHA256 
    $sha256.Key = $b64Arr
    $AuthorizationHeader = "SharedKey " + $StorageAccount + ":" + [Convert]::ToBase64String($SHA256.ComputeHash($SignatureBytes))
    $AuthorizationHeader 
}

$GetCanonicalizedHeader = {
    param(
    [Hashtable]$Header
    )

    $headerNameList = new-OBject  Collections.ArrayList;
    $sb = new-object Text.StringBuilder;
    foreach ($headerName in $Header.Keys) {
        if ($headerName.ToLowerInvariant().StartsWith("x-ms-", [StringComparison]::Ordinal)) {
                $null = $headerNameList.Add($headerName.ToLowerInvariant());
        }
    }
    $null = $headerNameList.Sort();
    [Collections.Specialized.NameValueCollection]$headers =NEw-OBject Collections.Specialized.NameValueCollection    
    foreach ($h in $header.Keys) {
        $null = $headers.Add($h, $header[$h])
    }

    
    foreach ($headerName in $headerNameList)
    {
        $builder = new-Object Text.StringBuilder $headerName
        $separator = ":";
        foreach ($headerValue in (& $GetHeaderValues $headers $headerName))
        {
            $trimmedValue = $headerValue.Replace("`r`n", [String]::Empty)
            $null =  $builder.Append($separator)
            $null = $builder.Append($trimmedValue)
            $separator = ","
        }
        $null = $sb.Append($builder.ToString())
        $null = $sb.Append("`n")
    }
    return $sb.ToString()    
}


$GetHeaderValues  = {
    param([Collections.Specialized.NameValueCollection]$headers, $headerName)
    $list = new-OBject  Collections.ArrayList
    
    $values = $headers.GetValues($headerName)
    if ($values -ne $null)
    {
        foreach ($str in $values) {
            $null = $list.Add($str.TrimStart($null))
        }
    }
    return $list;
}

$GetCanonicalizedResource = {
    param([uri]$address, [string]$accountName)

    $str = New-object Text.StringBuilder
    $builder = New-object Text.StringBuilder "/" 
    $null = $builder.Append($accountName)
    $null = $builder.Append($address.AbsolutePath)
    $null = $str.Append($builder.ToString())
    $values2 = New-Object Collections.Specialized.NameValueCollection
    if (!$IsTableStorage) {
        $values = [Web.HttpUtility]::ParseQueryString($address.Query)
        foreach ($str2 in $values.Keys) {
            $list = New-Object Collections.ArrayList 
            foreach ($v in $values.GetValues($str2)) {
                $null = $list.add($v)
            }
            $null = $list.Sort();
            $builder2 = New-Object Text.StringBuilder
            foreach ($obj2 in $list)
            {
                if ($builder2.Length -gt 0)
                {
                    $null = $builder2.Append(",");
                }
                $null = $builder2.Append($obj2.ToString());
            }
            $valueName = if ($str2 -eq $null) {
                $str2 
            } else {
                $str2.ToLowerInvariant()
            }
            $values2.Add($valueName , $builder2.ToString())
        }
    }
    $list2 = New-Object Collections.ArrayList 
    foreach ($k in $values2.AllKeys) {
        $null = $list2.Add($k)
    }
    $null = $list2.Sort()
    foreach ($str3 in $list2)
    {
        $builder3 = New-Object Text.StringBuilder([string]::Empty);
        $null = $builder3.Append($str3);
        $null = $builder3.Append(":");
        $null = $builder3.Append($values2[$str3]);
        $null = $str.Append("`n");
        $null = $str.Append($builder3.ToString());
    }
    return $str.ToString();

}

        #$inputList = New-Object Collections.ArrayList
        $inputData = New-Object Collections.ArrayList

        if (-not $script:alreadyPublicContainers) {
            $script:alreadyPublicContainers = @{}
        }

        if (-not $script:knownContainers) {
            $script:knownContainers= @{}
        }
    }


    process {
        #$null = $inputList.Add($inputObject)
        $null = $inputData.Add((@{} + $psBoundParameters)) 
    }

    end {
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

        $b64StorageKey = try { [Convert]::FromBase64String("$storageKey") } catch { }

        if (-not $b64StorageKey -and $storageKey) {
            $storageKey = Get-Secret -Name $storageKey -AsPlainText
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
        foreach ($inputInfo in $inputData) {
            if ($inputInfo.Name) {
                $Name = $inputInfo.Name
            }

            if ($inputInfo.Container) {
                $Container = $inputInfo.Container
            }

            $InputObject = $inputInfo.InputObject
        
            $containerBlobList = $null
            $Container = "$Container".ToLower()
            
            if (-not $knownContainers[$Container]) {
                $method = 'GET'
                
                $uri = "https://$StorageAccount.blob.core.windows.net/${Container}?restype=container&comp=list&include=metadata"
                if ($SharedAccessSignature) {
                    $uri += '&' + $SharedAccessSignature.TrimStart('?')
                }
                $header = @{
                    "x-ms-date" = $nowString 
                    "x-ms-version" = "2011-08-18"
                    "DataServiceVersion" = "2.0;NetFx"
                    "MaxDataServiceVersion" = "2.0;NetFx"
                }
                $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                $nowString = $header.'x-ms-date'
                if (-not $SharedAccessSignature) {
                    $header.authorization = . $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength 0 -method GET
                }
            
                $containerBlobList = Get-Web -UseWebRequest -Header $header -Url $Uri -Method GET -ErrorAction SilentlyContinue -ErrorVariable err -HideProgress

                if ($containerBlobList) {
                    $knownContainers[$Container] = $knownContainers[$Container]
                }
            }
        
            if (-not $containerBlobList) {
                # Tries to create the container if it's not found
                $method = 'PUT'
                $uri = "https://$StorageAccount.blob.core.windows.net/${Container}?restype=container"

                $header = @{
                    "x-ms-date" = $nowString 
                    "x-ms-version" = "2011-08-18"
                    "DataServiceVersion" = "2.0;NetFx"
                    "MaxDataServiceVersion" = "2.0;NetFx"

                }
                $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                $nowString = $header.'x-ms-date'
                $header.authorization = . $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength 0 -method PUT
                $Putresult = 
                    try {
                        Get-Web -UseWebRequest -Header $header -Url $Uri -Method PUT -HideProgress                 
                    } catch {
                        $_
                    }
                $null = $Putresult
            
            }
        

            if ($Public -and -not $script:alreadyPublicContainers[$Container]){
                
                # Enables public access to the container
                $acl =@"
<?xml version="1.0" encoding="utf-8"?>
  <SignedIdentifiers>
    <SignedIdentifier>
        <Id>Policy1</Id>
        <AccessPolicy>
        <Start>$([DateTime]::UTCNow.ToString('s'))Z</Start>
        <Expiry>$([DateTime]::UTCNow.AddYears(20).ToString('s'))Z</Expiry>
        <Permission>r</Permission>
    </AccessPolicy>
   </SignedIdentifier>   
</SignedIdentifiers>
"@
        
                $aclBytes= [Text.Encoding]::UTF8.GetBytes("$acl")    
                $method = 'PUT'
                $uri = "https://$StorageAccount.blob.core.windows.net/${Container}?restype=container&comp=acl"
                $header = @{
                    "x-ms-date" = $nowString 
                    "x-ms-version" = "2011-08-18"
                    "x-ms-blob-public-access" = "container"
                    "DataServiceVersion" = "2.0;NetFx"
                    "MaxDataServiceVersion" = "2.0;NetFx"
                    'content-type' = $ct 
                }
                $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                $nowString = $header.'x-ms-date'
                $ct ='application/x-www-form-urlencoded'
                if ($SharedAccessSignature) {
                    $uri += '&' + $SharedAccessSignature.TrimStart('?')
                } else {
                    $header.authorization = 
                        & $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength $aclBytes.Length -method PUT -Md5OrContentType $ct
                }
                $Created = Get-Web -UseWebRequest -Header $header -Url $Uri -Method PUT -RequestBody $aclBytes -UseErrorAsResult
                $null = $Created
                $script:alreadyPublicContainers[$Container] = $Container

            
            }


            $uri = "https://$StorageAccount.blob.core.windows.net/$Container/$Name"


            # Turn our input into bytes
            if ($InputObject -is [IO.FileInfo]) {
                $bytes = [io.fIle]::ReadAllBytes($InputObject.Fullname)
                $extension = [IO.Path]::GetExtension($InputObject.Fullname)
                $mimeType = $script:CachedContentTypes[$extension]
                if (-not $mimeType) {
                    $mimetype = "unknown/unknown"
                }
            } elseif ($InputObject -as [byte[]]) {
                $bytes = $InputObject -as [byte[]]
            } else {
                $bytes = [Text.Encoding]::UTF8.GetBytes("$InputObject")
            }

            if (-not $mimetype -or $psBoundParameters.ContentType) {
                $mimeType = $ContentType
            }

            if ($bytes.Length -ge 64mb) {
                $BaseURI = $uri
                $blockProgressId = Get-Random
                $blockCount= [Math]::Ceiling($bytes.Length / 4mb)
                
                $blockNames = New-Object Collections.ArrayList
                Write-Progress "Uploading Blocks" " " -Id $blockProgressId
                $blockParts = for ($i =0; $i -lt $blockCount; $i++) {
                    $p  = $i * 100 / $blockCount
                    Write-Progress "Uploading Blocks" "[$i / $BlockCount]" -Id $blockProgressId -PercentComplete $p 
                    $blockData = 
                        if ($i -lt ($blockCount -1 )) {
                            $bytes[($i * 4mb)..((($i + 1) * 4mb) - 1)]
                        } else {
                            $bytes[($i * 4mb)..$bytes.Length]
                        }
                    

                    
                    $blockName = [Convert]::ToBase64String([string]$i)
                    $BlockUri = "${uri}?comp=block&blockid=$([Web.HttpUtility]::UrlEncode($blockName))" 

                    New-Object PSObject -Property @{
                        BlockName = $blockName
                        BlockURI = $blockUri 
                        BlockData= $bytes
                    }
                    $null = $blockNames.Add($blockName)

                    
                    $method = 'PUT'
                    $header = @{
                        'x-ms-blob-type' = 'BlockBlob'
                        "x-ms-date" = $nowString 
                        "x-ms-version" = "2011-08-18"
                        "DataServiceVersion" = "2.0;NetFx"
                        "MaxDataServiceVersion" = "2.0;NetFx"                        
                    }
                    $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                    $nowString = $header.'x-ms-date'
                    if ($SharedAccessSignature) {
                        $blockUri += '&' + $SharedAccessSignature.TrimStart('?')
                    } else {
                        $header.authorization = . $signMessage -header $Header -url $BlockUri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength $blockData.Length -method PUT -md5OrContentType "application/x-www-form-urlencoded" 
                    }
        
                    $blobData= Get-Web -UseWebRequest -Header $header -Url $blockUri -Method PUT -RequestBody $blockData 
                    
                    $null = $blobData
                }
                <#
                $blockParts | Invoke-Parallel -Variable @{
                    "GetWeb" = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Get-Web', 'Function')
                    "SignMessage"  = $signMessage
                    "GetCanonicalizedHeader" = $GetCanonicalizedHeader
                    "GetCanonicalizedResource" = $GetCanonicalizedResource
                    "GetHeaderValues" = $GetHeaderValues
                } -Command {
                    foreach ($block in $args) {
                        $blockUri = $block.BlockUri
                        $blockData = $block.blockData
                        $blockName = $block.BlockName
                        $method = 'PUT'
                        $header = @{
                            'x-ms-blob-type' = 'BlockBlob'                   
                            "x-ms-version" = "2011-08-18"
                            "DataServiceVersion" = "2.0;NetFx"
                            "MaxDataServiceVersion" = "2.0;NetFx"                        
                        }
                        $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                        $nowString = $header.'x-ms-date'
                        $header.authorization = . $signMessage -header $Header -url $BlockUri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength $blockData.Length -method PUT -md5OrContentType "application/x-www-form-urlencoded" 
        
        
                        $blobData= & $getWeb -UseWebRequest -Header $header -Url $blockUri -Method PUT -RequestBody $blockData
                    }
                } #> 
                Write-Progress "Uploading Blocks" "Committing Block List" -Id $blockProgressId -PercentComplete $p 
                $putBlockList = @"
<?xml version="1.0" encoding="utf-8"?>
<BlockList>
    $(foreach ($_ in $blockNames) { "<Latest>$_</Latest>"})
</BlockList>
"@
                
                $putBlockListBytes= [Text.Encoding]::UTF8.GetBytes("$putBlockList")    
                $method = 'PUT'
                $uri = "${baseUri}?comp=blocklist"
                $header = @{
                    "x-ms-date" = $nowString 
                    "x-ms-version" = "2011-08-18"
                    "x-ms-blob-public-access" = "container"
                    "x-ms-blob-content-type" = $ContentType
                    "DataServiceVersion" = "2.0;NetFx"
                    "MaxDataServiceVersion" = "2.0;NetFx"
                    'content-type' = $ct 
                }
                $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                $nowString = $header.'x-ms-date'
                $ct ='text/plain'
                if ($SharedAccessSignature) {
                    $uri += '&' + $SharedAccessSignature.TrimStart('?')
                } else {
                    $header.authorization = & $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength $putBlockListBytes.Length -method PUT -md5orcontentType $ct 
                }
                Write-Progress "Uploading Blocks" "Committing Block List" -Id $blockProgressId -Completed
                $Created = Get-Web -UseWebRequest -Header $header -Url $Uri -Method PUT -RequestBody $putBlockListBytes -ContentType 'text/plain'
                
            } else {

                $method = 'PUT'
                $header = @{
                    'x-ms-blob-type' = 'BlockBlob'
                    "x-ms-date" = $nowString 
                    "x-ms-version" = "2011-08-18"
                    "DataServiceVersion" = "2.0;NetFx"
                    "MaxDataServiceVersion" = "2.0;NetFx"
                    'content-type' = $mimeType 
                }
                $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
                $nowString = $header.'x-ms-date'
                if ($SharedAccessSignature) {
                    $uri += $SharedAccessSignature
                } else {
                    $header.authorization = . $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength $bytes.Length -method PUT -md5OrContentType $mimeType
                }
        
                $blobData= Get-Web -UseWebRequest -Header $header -Url $Uri -Method PUT -RequestBody $bytes -ContentType $mimeType 
                $null = $blobData
            }
        }
    }
}