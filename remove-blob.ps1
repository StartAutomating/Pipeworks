function Remove-Blob
{
    <#
    .Synopsis
        Removes blobs of cloud data
    .Description
        Removes blobs of cloud data in Azure 
    .Link
        Import-Blob
    .Link
        Export-Blob
    .Example
        Remove-Blob -Container MyContainer -Name MyItem.txt
    .Example
        Remove-Blob -Container MyContainer    
    #>
    [CmdletBinding(DefaultParameterSetName='RemoveContainer',ConfirmImpact='High', SupportsShouldProcess=$true)]    
    [OutputType([Nullable])]
    param(
    # The name of the container
    [Parameter(Mandatory=$true,Position=0, ValueFromPipelineByPropertyName=$true,ParameterSetName='RemoveContainer')]
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='RemoveBlob')]
    [string]$Container,

    # The name of the blob
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='RemoveBlob')]
    [string]$Name,


    # The storage account
    [string]$StorageAccount,

    # The storage key
    [string]$StorageKey

    )


    begin {
        
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

    }


    process {
        $in = $_
        if ($in.Name) {
            $name = $in.Name
        }

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

        if (-not $StorageKey) {
            Write-Error "No storage key provided"
            return
        }

        $script:CachedStorageAccount = $StorageAccount
        $script:CachedStorageKey = $StorageKey
        #endregion check for and cache the storage account

        if ($PSCmdlet.ParameterSetName -eq 'RemoveContainer' -and -not $in.Name) {
            $method = 'DELETE'
            $Container = "$Container".ToLower()
            $uri = "http://$StorageAccount.blob.core.windows.net/${Container}?restype=container"
            $header = @{
                "x-ms-date" = $nowString 
                "x-ms-version" = "2011-08-18"
                "DataServiceVersion" = "2.0;NetFx"
                "MaxDataServiceVersion" = "2.0;NetFx"

            }
            $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
            $nowString = $header.'x-ms-date'
            $header.authorization = . $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength 0 -method DELETE
                
            if ($PSCmdlet.ShouldProcess("/$Container")) {
                $containerBlobList = Get-Web -UseWebRequest -Header $header -Url $Uri -Method $method -HideProgress
            }
            
            
        } elseif ($PSCmdlet.ParameterSetName -eq 'RemoveBlob' -or $in.Name) {
            
            $method = 'DELETE'
            $uri = "http://$StorageAccount.blob.core.windows.net/$Container/$Name"
            $header = @{
                "x-ms-date" = $nowString 
                "x-ms-version" = "2011-08-18"
                "DataServiceVersion" = "2.0;NetFx"
                "MaxDataServiceVersion" = "2.0;NetFx"

            }
            $header."x-ms-date" = [DateTime]::Now.ToUniversalTime().ToString("R", [Globalization.CultureInfo]::InvariantCulture)
            $nowString = $header.'x-ms-date'
            $header.authorization = . $signMessage -header $Header -url $Uri -nowstring $nowString -storageaccount $StorageAccount -storagekey $StorageKey -contentLength 0 -method DELETE
                
            if ($PSCmdlet.ShouldProcess("/$Container/$Name")) {
                $containerBlobList = Get-Web -UseWebRequest -Header $header -Url $Uri -Method $method -HideProgress
            }
            
        }
    }

    end {
        
        foreach ($inputInfo in $inputData) {
            if ($inputInfo.Name) {
                $Name = $inputInfo.Name
            }

            if ($inputInfo.Container) {
                $Container = $inputInfo.Container
            }

            $InputObject = $inputInfo.InputObject
        
            $containerBlobList = $null
            
            
            
            
                    
                    


            


            
        
            
        }
    }
}