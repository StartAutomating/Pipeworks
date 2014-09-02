function Find-Factual {
    <#
    .Synopsis
        Finds content on Factual
    .Description
        Finds content on Factual's global places API
    .Example
        Find-Factual Starbucks in Seattle        
    .Example
        $l = Resolve-Location -Address 'Redmond, WA'
        Find-Factual -GeoPulse -TypeOfFilter Point -Filter "$($l.longitude),$($l.Latitude)" -Verbose
    .Example
        Find-Factual -InTable vYrq7F -Filter 'Washington' -TypeOfFilter State -Limit 50
    .Example
        # Wineries
        Find-Factual -InTable cQUvfi  
    .Link
        Get-Web
    #>
    [OutputType([PSObject])]
    param(
    # The factual query
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [string]
    $Query,

    # The type of the filter
    [Parameter(Position=1)]
    [ValidateSet("In","Near","Category","Country", "UPC", "EAN", "Brand", "Point", "Name", "Brewery", "Beer", "Style", "State", "PostCode")]
    [string[]]    
    $TypeOfFilter,

    # The filter 
    [Parameter(Position=2,ValueFromPipelineByPropertyName=$true)]    
    [string[]]
    $Filter,

    # Within.  This is only used when 'near' is used
    [Parameter(Position=3,ValueFromPipelineByPropertyName=$true)]
    [Uint32]
    $Within = 1000,

    # Your Factual API Key
    [Parameter(Position=4,ValueFromPipelineByPropertyName=$true)]
    [string]
    $FactualKey,

    # A secure setting containing your factual key
    [Parameter(Position=5)]
    [string]
    $FactualKeySetting = "FactualKey",

    # If set, will only find US resturaunts
    [Switch]
    $Restaurants,

    # If set, will only find health care providers
    [Switch]
    $HeathCare, 

    # If set, will only find products
    [Switch]
    $Product,

    # If set, searches the places data set
    [switch]
    $Place,

    # If set, gets the GeoPulse of an area
    [Switch]
    $GeoPulse,

    # If set, will get data from a table
    [string]
    $InTable,
    
    # If set, will limit the number of responses returned
    [ValidateRange(1,50)]
    [Uint32]
    $Limit,

    # If set, will start returning results at a point
    [Uint32]
    $Offset,

    # If set, will query all records that match a filter.  This will result in multiple queries.
    [Switch]
    $All


    )

    process {
        $filters = ""

        if ($TypeOfFilter.Count -ne $Filter.Count) {
            throw "Must be an equal number of filters and types of filters"
        }


        $geoString = ""

        
        $filterString = 
        for ($i = 0; $i -lt $TypeOfFilter.Count; $i++) {
            if ($TypeOfFilter[$i] -eq 'Category') {
                "{`"category`":{`"`$bw`":$('"' + ($Filter[$i] -join '","') + '"')}}"
            } elseif ($TypeOfFilter[$i] -eq 'In') {

                "{`"locality`":{`"`$in`":[$('"' + ($Filter[$i] -join '","') + '"')]}}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Upc') {

                "{`"upc`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Ean13') {

                "{`"ean13`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'ProductName') {

                "{`"product_name`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Name') {

                "{`"name`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Brewery') {

                "{`"brewery`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Beer') {

                "{`"beer`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'State') {

                "{`"state`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Country') {

                "{`"country`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Style') {

                "{`"style`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Brand') {

                "{`"brand`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'PostCode') {

                "{`"postcode`":`"$($Filter[$i])`"}"
             
                
            } elseif ($TypeOfFilter[$i] -eq 'Near') {
                
                ""
                $geoString = "&geo={`"`$circle`":{`"`$center`":[$(($Filter[$i] -split ",")[0]),$(($Filter[$i] -split ",")[1])],`"`$meters`":$Within }}"
            } elseif ($TypeOfFilter[$i] -eq 'Point') {
                ""
                $lat = [Math]::Round((($Filter[$i] -split ",")[0]), 5)
                $long = [Math]::Round((($Filter[$i] -split ",")[1]), 5)
                $geoString = "&geo={`"`$point`":[$lat,$long], `"`$meters`":$within}"
            }
        }


        

        
        
        $factualUrl = "http://api.v3.factual.com/t/global?"
        if ($Restaurants) {
            $factualUrl = "http://api.v3.factual.com/t/restaurants-us?"
        } elseif ($HeathCare) {
            $factualUrl = "http://api.v3.factual.com/t/health-care-providers-us?"
        } elseif ($Place) {
            $factualUrl = "http://api.v3.factual.com/t/world-geographies?"
        } elseif ($product) {
            $factualUrl = "http://api.v3.factual.com/t/products-cpg?"
        } elseif ($GeoPulse) {
            $factualUrl = "http://api.v3.factual.com/places/geopulse?"
        } elseif ($InTable) {
            $factualUrl = "http://api.v3.factual.com/t/${InTable}?"
            
        }
        
        if ($Query) {
            $factualUrl += "q=$Query&"
        } else {
        }

        if ($filterString) {

        $factualUrl +=
            if ($filterstring -is [Array]) {
                # ands
                "filters={`"`$and`":[$($filterString -join ',')]}"            
            } else {
                # simple $filter
                "filters=$($filterString)"
            } 
        } else {
            $geoString= $geoString.TrimStart("&")    
        }
        if ($geoString) {
            $factualUrl += $geostring
        }

        if (-not $GeoPulse) {
            $factualUrl +="&include_count=true"
        
            if ($limit) {
                $factualUrl +="&limit=$limit"
            }

            if ($Offset) {
                $factualUrl +="&offset=$offset"
            }
        }
        


        
        Write-Verbose "Querying From Factual $factualUrl&Key=******"
        
        if (-not $FactualKey) {
            $FactualKey = Get-SecureSetting -Name $FactualKeySetting -ValueOnly
        }
        

        $factualUrl += 
            if($FactualKey ){
                "&KEY=$FACTUALKey"
            }
        
        $factualResult = Get-Web -Url $factualUrl -AsJson -UseWebRequest

        while ($factualResult) {
            
            $rowCount = $factualResult.response.total_row_count
            if ($rowCount) {
                Write-Verbose "$RowCount total records to return"
            }


            



            $factualResult= $factualResult.response.data  
            if (-not $factualResult) { break }

            $factualResult = foreach ($f in $factualResult) {
                if (-not $f){ continue } 
                    
                if ($geoPulse) {
                    $null = Update-List -InputObject $f -remove "System.Management.Automation.PSCustomObject", "System.Object" -add "Factual.GeoPulse" -Property pstypenames 
                } elseif ($f.Beer) {
                    $null = Update-List -InputObject $f -remove "System.Management.Automation.PSCustomObject", "System.Object" -add "Factual.Beer" -Property pstypenames 
                } elseif ($f.Operating_Name -and $f.permit_number) {
                    $null = Update-List -InputObject $f -remove "System.Management.Automation.PSCustomObject", "System.Object" -add "Factual.Winery" -Property pstypenames 
                } elseif (-not $Product) {
                    $f = $f | 
                        Add-Member AliasProperty telephone tel -Force -PassThru |
                        Add-Member AliasProperty url website -Force -PassThru 
                    $null = Update-List -InputObject $f -remove "System.Management.Automation.PSCustomObject", "System.Object" -add "http://schema.org/Place" -Property pstypenames 
                } else {
                    
                    $null = Update-List -InputObject $f -remove "System.Management.Automation.PSCustomObject", "System.Object" -add "http://schema.org/Product" -Property pstypenames 
                }
                $f
            }
            $factualResult 

            if ($all) {
                if ($factualUrl -like "*offset=*") {
                    $factualUrl = $factualUrl -replace '\&offset=\d{1,}', ''
                    $Offset += 20
                } else {
                    $Offset = 20
                }
                $factualUrl+="&offset=$Offset"
                $factualResult = Get-Web -Url $factualUrl -AsJson   -UseWebRequest
            } else {
                $factualResult  = $null

            }
        }
#        
    }
}



