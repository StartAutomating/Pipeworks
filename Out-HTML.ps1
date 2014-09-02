function Out-HTML {
    <#
    .Synopsis
        Produces HTML output from the PowerShell pipeline.
    .Description
        Produces HTML output from the PowerShell pipeline, doing the best possible to obey the formatting rules in PowerShell.
    .Example
        Get-Process | Out-HTML
    .Link
        New-Webpage
    .Link
        Write-Link
    .Link
        New-Region
    #>
    [OutputType([string])]
    [CmdletBinding(DefaultParameterSetName='DefaultFormatter')]
    param(
    # The input object
    [Parameter(ValueFromPipeline=$true)]
    [PSObject]
    $InputObject,
    
    # If set, writes the response directly
    [switch]
    $WriteResponse,
    
    # If set, escapes the output    
    [switch]
    $Escape,
    
    # The id of the table that will be created
    [string]
    $Id,

    # The vertical alignment of rows within the generated table.  By default, aligns to top
    [ValidateSet('Baseline', 'Top', 'Bottom', 'Middle')]
    $VerticalAlignment = 'Top',

    # The table width, as a percentage
    [ValidateRange(1,100)]
    [Uint32]
    $TableWidth = 100,
    
    # The CSS class to apply to the table.
    [string]
    $CssClass,        
    
    # A CSS Style 
    [Hashtable]
    $Style,        
    
    # If set, will enclose the output in a div with an itemscope and itemtype attribute
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]$ItemType,
    
    # If more than one view is available, this view will be used
    [string]$ViewName,

    # If set, will use the table sorter plugin
    [Switch]
    $UseTableSorter,

    # If set, will use the datatable plugin
    [Switch]
    $UseDataTable,

    # If set, will show the output as a pie graph
    [Parameter(Mandatory=$true,ParameterSetName='AsPieGraph')]
    [Switch]
    $AsPieGraph,

    # If set, will show the output as a bar graph
    [Parameter(Mandatory=$true,ParameterSetName='AsBarGraph')]
    [Switch]
    $AsBarGraph,

    # If set, the bar graph will be horizontal, not vertical
    [Parameter(ParameterSetName='AsBarGraph')]
    [Switch]
    $Horizontal,

    # The list of colors in the graph
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [string[]]
    $ColorList = @("#468966", "#FFF0A5", "#FF870C", "#CA0016", "#B0A5CF", "#2B85BA", "#11147D", "#EE56A9", "#ADDC6C", "#108F34"),
   
    # The width of the canvas for a graph
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [Double]
    $GraphWidth = 400,

    # The height of the canvas for a graph
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [Double]
    $GraphHeight = 400,

    # The header of a graph
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [string]
    $Header,

    # The text alignment of the header.  By default, center
    [ValidateSet("Left", "Center", "Right")]
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [string]
    $HeaderAlignment = "Center",

    # The size of the header
    [ValidateRange(1,6)]
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [Uint32]
    $HeaderSize = 3,

    # If set, no legend will be displayed
    [Parameter(ParameterSetName='AsPieGraph')]
    [Parameter(ParameterSetName='AsBarGraph')]
    [Switch]
    $HideLegend
    )
        
    begin {
        
        
        $tablesForTypeNames = @{}
        $tableCalculatedProperties = @{}
        if (-not $Script:CachedformatData) {
            $Script:CachedformatData = @{}
        }
        $stopLookingFor = @{}
        $CachedControls = @{}
        $loadedViewFiles= @{}
        $htmlOut = New-Object Text.StringBuilder
        $typeNamesEncountered = @()
        if (-not $script:LoadedFormatFiles) {
            $script:loadedFormatFiles = @(dir $psHome -Filter *.format.ps1xml | 
                Select-Object -ExpandProperty Fullname) + 
                @(Get-Module | Select-Object -ExpandProperty ExportedformatFiles)
            
            $script:loadedViews = $loadedFormatFiles | Select-Xml -Path {$_ } "//View"
        }
        if ($useTableSorter) {
            if ($CssClass) {
                $CssClass+="tableSorterTable"
            } else {
                $CssClass ="tableSorterTable"
            }
        }

        if ($useDataTable) {
            if ($CssClass) {
                $CssClass+="aDataTable"
            } else {
                $CssClass ="aDataTable"
            }
        }

        $userandomSalt = $false

        $graphData = $null
        $graphItemOrder = @()
        if ($AsPieGraph) {
            $userandomSalt = $true
            
            $graphData= @{}
        }

        if ($AsBarGraph) {
            $userandomSalt = $true
            
            $graphData = @{}
        }

        
    }
    
    process {   
        # In case nulls come in, exit politely 
        if (-not $InputObject ) {  return }       
        $randomSalt = if ($userandomSalt) {
            "_$(Get-Random)"
        } else {
            ""
        }
        $classChunk = if ($cssClass) {            
            "class='$($cssClass -join ' ')'"        
        } else { 
            ""
        
        } 
        $cssStyleChunk = if ($psBoundParameters.Style) { 
            if ($AsPieGraph -or $AsBarGraph) {
                if (-not $style['width']) {
                    $style['width'] = "${GraphWidth}px"
                } else {
                    $GraphWidth = $style['Width']
                }
                if (-not $style['height']) {
                    $style['height'] = "$($GraphHeight + 100)px"
                } else {
                    $GraphHeight = $style['Height']
                }                                
            }
            "style='" +(Write-CSS -Style $style -OutputAttribute) + "'"                                    
        } else {
            if ($AsPieGraph -or $AsBarGraph) {
                "style='" +(Write-CSS -Style @{"width"="${GraphWidth}px";"height"="$($GraphHeight + 50)px"} -OutputAttribute) + "'"                                    
            } else {
                "style='width:100%'"
            }
        }
        
        if ($inputObject -is [string]) {
            # Strings are often simply passed thru, but could potentially be escaped.
            $trimmedString = $inputObject.TrimStart([Environment]::NewLine).TrimEnd([Environment]::NewLine).TrimStart().TrimEnd()            
            # If the string looks @ all like markup or HTML, pass it thru
            if ($graphData) {
                if (-not $graphData.$trimmedString) {
                    $graphData.$trimmedString = 0
                }
                $graphData.$trimmedString++
                if ($graphItemOrder -notcontains $trimmedString) {
                    $graphItemOrder += $trimmedString
                }
                
            } else {
                if (($trimmedString -like "*<*") -and 
                    ($trimmedString -like "*>*") -and
                    ($trimmedString -notlike "*<?xml*")) {                
                    if ($escape) { 
                        $null = $htmlOut.Append("
$([Web.HttpUtility]::HtmlEncode($inputObject).Replace([Environment]::NewLine, '<BR/>').Replace('`n', '<BR/>').Replace(' ', '&nbsp;'))
")
                    } else {
                        $null = $htmlOut.Append("
$inputObject
")
                    } 
                    
                    
                } else {
                    # Otherwise, include it within a <pre> tag
                    $null= $htmlOut.Append("
$([Web.HttpUtility]::HtmlEncode($inputObject))
")
                }
            }
        } elseif ([Double], [int], [uint32], [long], [byte] -contains $inputObject.GetType()) {
            if ($graphData) {
                if (-not $graphData.$inputObject) {
                    $graphData.$inputObject = 0
                }
                $graphData.$inputObject += $graphData.$inputObject
                if ($graphItemOrder -notcontains $inputObject) {
                    $graphItemOrder += $inputObject
                }
            } else {
                # If it's a number, simply print it out
                $null= $htmlOut.Append("
<span class='Number' style='font-size:2em'>
$inputObject
</span>
")
            }
        } elseif ([DateTime] -eq $inputObject.GetType()) {
            # If it's a date, out Out-String to print the long format
            if ($graphData) {
                if (-not $graphData.$inputObject) {
                    $graphData.$inputObject = 0
                }
                $graphData.$inputObject++
                if ($graphItemOrder -notcontains $inputObject) {
                    $graphItemOrder += $inputObject
                }
            } else {
                $null= $htmlOut.Append("
<span class='DateTime'>
$($inputObject | Out-String)
</span>
")
            }
            
        } elseif (($inputObject -is [Hashtable]) -or ($inputObject -is [Collections.IDictionary])) {
            $null = $psBoundParameters.Remove('InputObject')            
            $inputObjecttypeName = ""
            $inputObjectcopy = @{} + $inputObject
            if ($inputObjectcopy.PSTypeName) {
                $inputObjecttypeName = $inputObject.PSTypeName
                $inputObjectcopy.Remove('PSTypeName')
            }
            
            foreach ($kv in @($inputObjectcopy.GetEnumerator())) {
                if ($kv.Value -is [Hashtable]) {                    
                    $inputObjectcopy[$kv.Key] = Out-HTML -InputObject $kv.Value
                }
            }
            
            if ($inputObjectCopy) {
            
            
                New-Object PSObject -Property $inputObjectcopy | 
                    ForEach-Object {                
                        $_.pstypenames.clear()
                        foreach ($inTypeName in $inputObjectTypeName) {
                            if (-not $inTypeName) {continue }
                            
                            $null = $_.pstypenames.add($inTypeName)
                        }
                        if (-not $_.pstypenames) {
                            $_.pstypenames.add('PropertyBag')
                        }
                        $psBoundparameters.ItemType = $inputObjectTypeName
                        $_
                    } | Out-HTML @psboundParameters
            }
        } else {
            $matchingTypeName = $null
            #region Match TypeName to Formatter
            foreach ($typeName in $inputObject.psObject.typenames) {             
                # Skip out of 
                $typeName = $typename.TrimStart("Deserialized.")
                if ($stopLookingFor[$typeName]) { continue }                 
                if ($Script:CachedformatData[$typeName] ) { 
                    $matchingTypeName = $typename
                    break
                }                
                
                if (-not $Script:CachedformatData[$typeName] -and -not $stopLookingFor[$TypeName]) {
                    
                    
                    $Script:CachedformatData[$typeName] =  
                        if ([IO.File]::Exists("$pwd\Presenters\$typeName")) {
                            if ($loadedViewFiles[$typeName]) {                            
                                $loadedViewFiles[$typeName] = [IO.File]::ReadAllText(
                                    $ExecutionContext.SessionState.Path.GetResolvedProviderPathFromPSPath(".\Presenters\$typeName"))
                                 
                            } else {
                                $loadedViewFiles[$typeName]
                            }
                        } else {
                            Get-FormatData -TypeName $typeName -ErrorAction SilentlyContinue
                        }
                    
                    if (-not $Script:CachedformatData[$TypeName]) {                
                        # This covers custom action
                        $Script:CachedformatData[$typeName] = 
                            foreach ($view in $loadedViews) {
                                 
                                if ($view.Node.ViewselectedBy.TypeName -eq $typeNAme) { 
                                    if ($ViewName -and $view.Node.Name -eq $viewNAme) {
                                        $view.Node
                                        break

                                    } else {
                                        $view.Node
                                        break

                                    }
                                }
                            }
                                
                        if ($Script:CachedformatData[$typeName]) {
                            # Custom Formatting or SelectionSet
                            if ($Script:CachedformatData[$typeName]) {
                            
                            }                           
                            $matchingTypeName = $typeName
                        } else {                           
                        
                            # At this point, we're reasonably certain that no formatter exists, so
                            # Make sure we stop looking for the typename, or else this expensive check is repeated for each item                                                        
                            if (-not $Script:CachedformatData[$typeName]) {                            
                                $stopLookingFor[$typeName]  = $true
                            }
                        }
                    } else {
                        $matchingTypeName = $typeName
                        break
                    }                                        
                }
            }

            $TypeName = $MatchingtypeName
            
            
            
            #endregion Match TypeName to Formatter
            if ($GraphData) {
                # Formatted type doesn't really matter when we're graphing, so skip all the logic related to it
                foreach ($pr in $InputObject.PSObject.Properties) {
                    if (-not $graphData.($pr.Name)) {
                        $graphData.($pr.Name) = 0
                    }
                    if ($pr.Value) {
                        if ([Double], [int], [uint32], [long], [byte] -contains $pr.Value.GetType()) {
                            $graphData.($pr.Name)+=$pr.Value
                        } else {
                            $graphData.($pr.Name)++
                        }                        
                    }
                    if ($graphItemOrder -notcontains $pr.Name) {
                        $graphItemOrder += $pr.Name
                    }
                }
            } elseif ($matchingTypeName) {
                $formatData = $Script:CachedformatData[$typeName]
                $cssSafeTypeName =$typename.Replace('.','').Replace('#','')
                if ($Script:CachedformatData[$typeName] -is [string]) {
                    # If it's a string, just set $_ and expand the string, which allows subexpressions inside of HTML
                    $_ = $inputObject
                    foreach ($prop in $inputObject.psobject.properties) {
                        Set-Variable $prop.Name -Value $prop.Value -ErrorAction SilentlyContinue
                    }
                    $ExecutionContext.SessionState.InvokeCommand.ExpandString($Script:CachedformatData[$typeName])
                } elseif ($Script:CachedformatData[$typeName] -is [Xml.XmlElement]) {
                    # SelectionSet or Custom Formatting Action
                                        

                    $frame = $Script:CachedformatData[$typeName].CustomControl.customentries.customentry.customitem.frame
                    foreach ($frameItem in $frame) {
                        $item  =$frameItem.customItem
                        foreach ($expressionItem in $item) {
                            if (-not $expressionItem) { continue } 
                            $expressionItem | 
                                Select-Xml "ExpressionBinding|NewLine" |
                                ForEach-Object -Begin {
                                    if ($itemType) {
                                        #$null = $htmlOut.Append("<div itemscope='' itemtype='$($itemType -join "','")' class='ui-widget-content'>")
                                    }
                                } {
                                    if ($_.Node.Name -eq 'ExpressionBinding') {
                                        $finalExpr =($_.Node.SelectNodes("ScriptBlock") | 
                                            ForEach-Object {
                                                $_."#text"
                                            }) -ireplace "Write-Host", "Write-Host -AsHtml" -ireplace 
                                                "Microsoft.PowerShell.Utility\Write-Host", "Write-Host"
                                        $_ = $inputObject
                                        $null = $htmlOut.Append("$(Invoke-Expression $finalExpr)")
                                    } elseif ($_.Node.Name -eq 'Newline') {
                                        $null = $htmlOut.Append("<br/>")
                                    }
                                } -End {
                                    if ($itemType) {
                                        #$null = $htmlOut.Append("</div>")
                                    }
                                }|                                 
                                Where-Object { $_.Node.Name -eq 'ExpressionBinding' }
                            if (-not $expressionBinding.firstChild.ItemSelectionCondition) {
                                
                                
                                
                            }
                            
                        }
                    }
                    
                    $null = $null
                    # Lets see what to do here
                } else {                                
                    if (-not $CachedControls[$typeName]) {
                        $control = foreach ($_ in $formatData.FormatViewDefinition) {
                            if (-not $_) { continue }
                            $result = foreach ($ctrl in $_.Control) {
                                if ($ctrl.Headers) { 
                                    $ctrl
                                    break
                                }
                            }
                            if ($result) { 
                                $result
                                break 
                            }
                        }
                        $CachedControls[$typeName]= $control
                        if (-not $cachedControls[$TypeName]) {
                            $control = foreach ($_ in $formatData.CustomControl) {
                                if (-not $_) { continue }
                                
                                
                            }
                            $CachedControls[$typeName]= $control
                        }
                    }
                    $control = $CachedControls[$typeName]
                             
                    if (-not ($tablesForTypeNames[$typeName])) {
                        $tableCalculatedProperties[$typeName] = @{}
                        if (-not $psBoundParameters.id) { 
                            $id = "TableFor$($TypeName.Replace('/', '_Slash_').Replace('.', "_").Replace(" ", '_'))$(Get-Random)" 
                        } else {
                            $id = $psBoundParameters.id
                        }

                        
                        $tableHeader = New-Object Text.StringBuilder                    
                        $null = $tableHeader.Append("
$(if ($useTableSorter) { 
    '<script>
        $(function() {
            $(".tableSorterTable").tablesorter(); 
        })
    </script>'   
})

$(if ($useDataTable) { 
    '<script>
        $(function() {
            $(".aDataTable").dataTable(); 
        })
    </script>'   
})

<table id='${id}${randomSalt}' $classChunk $cssstyleChunk>
    <thead>
    <tr>")
                        $labels = @()
                        $headerCount = $control.Headers.Count
                        $columns = @($control.Rows[0].Columns)
                        for ($i=0; $i-lt$headerCount;$i++) {                                            
                            $header = $control.Headers[$i]
                            $label = $header.Label
                            if (-not $label) {
                                $label = $columns[$i].DisplayEntry.Value
                            }
                            
                            if ($label) {
                                if ($columns[$i].DisplayEntry.ValueType -eq 'Property') {
                                    $prop = $columns[$i].DisplayEntry.Value
                                    $tableCalculatedProperties[$label] = [ScriptBlock]::Create("`$inputObject.'$prop'")
                                } elseif ($columns[$i].DisplayEntry.ValueType -eq 'ScriptBlock') {
                                    $tableCalculatedProperties[$label] = [ScriptBlock]::Create($columns[$i].DisplayEntry.Value)
                                } 
                                $labels+=$label
                            }
                            
                            $null = $tableHeader.Append("
        <th style='font-size:1.1em;text-align:left;line-height:133%'>$([Security.SecurityElement]::Escape($label))<hr/></th>")
                        
                        }
                        $null = $tableHeader.Append("
    </tr>
    </thead>
    <tbody>
    ")
                        $tablesForTypeNames[$typeName] = $tableHeader
                        $typeNamesEncountered += $typeName
                    }
                
                $currentTable = $tablesForTypeNames[$typeName]
            
                # Add a row
                $null = $currentTable.Append("
    <tr itemscope='' itemtype='$($typeName)'>") 

                    foreach ($label in $labels) {                
                        $value = "&nsbp;"
                        if ($tableCalculatedProperties[$label]) {
                            $_ = $inputObject
                            $value = . $tableCalculatedProperties[$label]                      
                        }
                        $value = "$($value -join ([Environment]::NewLine))".Replace([Environment]::NewLine, '<BR/> ')                    
                        if ($value -match '^http[s]*://') {
                            $value = Write-Link -Url $value -Caption $value
                        }
                        $null = $currentTable.Append("
        <td style='vertical-align:$verticalAlignment' itemprop='$([Security.SecurityElement]::Escape($label))'>$($value.Replace('&', '&amp;'))</td>")                
                    }
                    $null = $currentTable.Append("
    </tr>")     
                }                    
            } else {

                # Default Formatting rules
                $labels = @(foreach ($pr in $inputObject.psObject.properties)  { $pr.Name })
                if (-not $labels) { return } 
                [int]$percentPerColumn = 100 / $labels.Count            
                if ($inputObject.PSObject.Properties.Count -gt 4) {
                
                    $null = $htmlOut.Append("
<div class='${cssSafeTypeName}Item'>
")
                    foreach ($prop in $inputObject.psObject.properties) {
                        $null = $htmlOut.Append("
    <p class='${cssSafeTypeName}PropertyName'>$($prop.Name)</p>
    <blockquote>
        <pre class='${cssSafeTypeName}PropertyValue'>$($prop.Value)</pre>
    </blockquote>
")
                        
                    }
                    $null = $htmlOut.Append("
</div>
<hr class='${cssSafeTypeName}Separator' />
")              
                }  else {
                    $widthPercentage = 100 / $labels.Count
                    $typeName = $inputObject.pstypenames[0]
                    if (-not ($tablesForTypeNames[$typeName])) {
                        $tableCalculatedProperties[$typeName] = @{}
                        if (-not $psBoundParameters.id) { 
                            $id = "TableFor$($TypeName.Replace('/', '_Slash_').Replace('.', "_").Replace(" ", '_'))$(Get-Random)" 
                        } else {
                            $id = $psBoundParameters.id
                        }
                        $tableHeader = New-Object Text.StringBuilder
                        
                        $null = $tableHeader.Append("
$(if ($useTableSorter) { 
    '<script>
        $(function() {
            $(".tableSorterTable").tablesorter(); 
        })
    </script>'   
})

$(if ($useDataTable) { 
    '<script>
        $(function() {
            $(".aDataTable").dataTable(); 
        })
    </script>'   
})


<table id='${id}${randomSalt}' $cssStyleChunk $classChunk >
    <thead>
    <tr>")   


                        foreach ($label in $labels) {
                            $null = $tableHeader.Append("
        <th style='font-size:1.1em;text-align:left;line-height:133%;width:${widthPercentage}%'>$([Security.SecurityElement]::Escape($label))<hr/></th>")
                    
                            
                        }
                        $null = $tableHeader.Append("
    </tr>
    </thead>
    <tbody>")
                        $tablesForTypeNames[$typeName] = $tableHeader
                        $typeNamesEncountered += $typeName
                    }
                    
                    $currentTable = $tablesForTypeNames[$typeName]
            
                    # Add a row
                    $null = $currentTable.Append("
    <tr itemscope='' itemtype='$($typeName)'>") 

                    foreach ($label in $labels) {                
                        $value = "&nsbp;"
                        $value = $inputObject.$label
                        $value = "$($value -join ([Environment]::NewLine))".Replace([Environment]::NewLine, '<BR/> ')
                        if ($value -match '^http[s]*://') {
                            $value = Write-Link $value
                        }
                        $null = $currentTable.Append("
        <td style='vertical-align:$verticalAlignment' itemprop='$([Security.SecurityElement]::Escape($label))'>$($value.Replace('&', '&amp;'))</td>")                
                    }
                    $null = $currentTable.Append("
    </tr>")      
                    
                }         
            }      
        }
     
    }
    
    end {
            $htmlOut = "$htmlOut" 
            $htmlOut += if ($tablesForTypeNames.Count) {
                foreach ($table in $typeNamesEncountered) {
                    if ($AsBarGraph) {
    $null = $tablesForTypeNames[$table].Append(@"
</tbody></table>
<div id='${id}_Holder_${RandomSalt}'>
</div>
<div style='clear:both'> </div>
<script>

`$(function () {
    // Grab the data
    colors = ["$($ColorList -join '","')"]
    var data = [],
        labels = [];
    `$("#${Id}${RandomSalt} thead tr th").each(
        function () {        
            labels.push(`$(this).text());
            
            
            
    });

    `$("#${Id}${RandomSalt} tbody tr td").each(
        function () {        
            data.push(
                parseInt(
                    `$(this).text(), 10)
                );            
                                    
    });
    `$("#${Id}${RandomSalt}").hide();
    
    chartHtml = '<table valign="bottom"><tr><td valign="bottom">'
    valueTotal = 0 
    for (i =0; i< labels.length;i++) {
        chartHtml += ("<div id='${RandomSalt}_" + i + "' style='min-width:50px;float:left;ver' > <div id='${RandomSalt}_" + i + "_Rect' style='height:1px;background-color:" + colors[i] + "'> </div><br/><div class='chartLabel'>"+ labels[i] + '<br/>(' + data[i] + ")</div></div>");
        valueTotal += data[i];

        chartHtml+= '</td>'

        if (i < (labels.length - 1)) {
            chartHtml+= '<td valign="bottom">'
        }
    }
    chartHtml += '</tr></table>'

    
    `$(${id}_Holder_${RandomSalt}).html(chartHtml);
    

    for (i =0; i< labels.length;i++) {
        newRelativeHeight =  (data[i] / valueTotal) * 200;
        `$(("#${RandomSalt}_" + i + "_Rect")).animate({
                        height:newRelativeHeight
                        }, 500);
        
    }
    
});
 
</script>
"@)
                    } else {
                        $null = $tablesForTypeNames[$table].Append("
</tbody></table>")
                    }
                    
                    if ($escape) {
                        [Web.HttpUtility]::HtmlEncode($tablesForTypeNames[$table].ToString())
                    } else {
                        $tablesForTypeNames[$table].ToString()
                                                
                    }                    
                    
                }
            }
            
            if ($itemType) {
                $htmlout = "<div itemscope='' itemtype='$($itemType -join ' ')'>
$htmlOut
</div>"
            }

            if ($graphData) {
                $legendHtml = ""
                if (-not $HideLegend) {
                    $c =0 
                    $legendHtml = 
                        foreach ($graphItem in $graphItemOrder) {
                            $val = $graphData[$graphItem]
                            $lang = Get-Culture
                            
                            if ($request -and $request["Accept-Language"]) {
                                
                                $matchingLang = [Globalization.CultureInfo]::GetCultures("All")  | Where-Object {$_.Name -eq $request["Accept-Language"]}
                                if ($matchingLang) {
                                    $lang = $matchingLang
                                }
                            }
                            
                            $formattedVal = if ($AsCurrency) {
                                $v = $val.ToString("c", $lang)
                                if ($v -like "*$($lang.NumberFormat.CurrencyDecimalSeparator)00") {
                                    $v.Substring(0, $v.Length - 3)  
                                } else {
                                    $v
                                }
                            } else {
                                $v = $val.ToString("n", $lang)
                                if ($v -like "*$($lang.NumberFormat.NumberDecimalSeparator)00") {
                                    $v.Substring(0, $v.Length - 3)  
                                } else {
                                    $v
                                }
                            }


                            

                            
"
<div style='margin-top:5px'>
    <div style='background-color:$($colorList[$c]);width:20px;height:20px;content:"";'> 
        <div style='font-weight:bold;height:20px;vertical-align:middle;display:inline;margin-left:25px;position:absolute'>
            $graphItem $(if (-not $HideValue) { "($formattedVal)" })
        </div>
    </div>    
</div>
"
                        $C++
                        }
                    
                }
                if ($AsPieGraph) {
$pieStyle = "
    #Graph$RandomSalt .pie {
		position:absolute;
		width:$($GraphWidth / 2)px;
		height:$($GraphHeight)px;
		overflow:hidden;
		left:$($graphWidth * .75)px;
		-moz-transform-origin:left center;
		-ms-transform-origin:left center;
		-o-transform-origin:left center;
		-webkit-transform-origin:left center;
		transform-origin:left center;
	}

    #Graph$RandomSalt .pie.big {
        position:absolute;
		width:${GraphWidth}px;
		height:${GraphHeight}px;
		left:$($GraphWidth * .25)px;
		-moz-transform-origin:center center;
		-ms-transform-origin:center center;
		-o-transform-origin:center center;
		-webkit-transform-origin:center center;
		transform-origin:center center;
	}


    #Graph$RandomSalt .pie:BEFORE {
		content:'';
		position:absolute;
		width:$($GraphWidth / 2)px;
		height:$($GraphHeight)px;
		left:-$($GraphWidth / 2)px;
		border-radius:$($GraphWidth / 2)px 0 0 $($GraphWidth / 2)px;
		-moz-transform-origin:right center;
		-ms-transform-origin:right center;
		-o-transform-origin:right center;
		-webkit-transform-origin:right center;
		transform-origin:right center;
		
	}

    #Graph$RandomSalt .pie.big:BEFORE {
		left:0px;
	}

    #Graph$RandomSalt .pie.big:AFTER {
		content:'';
		position:absolute;
		width:$($GraphWidth / 2)px;
		height:${GraphHeight}px;
		left:$($GraphWidth / 2)px;
		border-radius:0 $($GraphWidth / 2)px $($GraphWidth / 2)px 0;
	}

$(
    $c = 0 
    foreach ($color in $ColorList) {
        $c++
@"

    #Graph$RandomSalt .pie:nth-of-type($c):BEFORE,
	#Graph$RandomSalt .pie:nth-of-type($c):AFTER {
		background-color:$color;	
	}    	
"@            
    })


$(
    $dataStart = 0 
    $totalSliced = 0
    $totalSliced = $graphData.Values | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    $dc = 0 
    $pieHtml = ''
    foreach ($graphItem in $graphItemOrder) {
        $val = $graphData[$graphItem]
        $percentOfTotal = $val / $totalSliced
        $percentInDegrees = 360 * $percentOfTotal
        $dataEnd = $dataStart + [int]$percentInDegrees     
        $pieHtml += 
        if ($percentInDegrees -lt 180) {
        "
<div class='pie' data-start='$DataStart' data-value='$([int]$percentInDegrees)'></div>
"
        } else {
        "
<div class='pie big' data-start='$DataStart' data-value='$([int]$percentInDegrees)'></div>
"
        }
        
@"
    #Graph$RandomSalt .pie[data-start="$dataStart"] {
		-moz-transform: rotate(${DataStart}deg); /* Firefox */
		-ms-transform: rotate(${DataStart}deg); /* IE */
		-webkit-transform: rotate(${DataStart}deg); /* Safari and Chrome */
		-o-transform: rotate(${DataStart}deg); /* Opera */
		transform:rotate(${DataStart}deg);
        filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=${DataStart});
	}    
"@ 
        if ($dc -lt ($graphData.Count - 1)) {
@"

    #Graph$RandomSalt .pie[data-value="$([int]$percentInDegrees)"]:BEFORE {
		-moz-transform: rotate($([int]($percentInDegrees + 1))deg); /* Firefox */
		-ms-transform: rotate($([int]($percentInDegrees + 1))deg); /* IE */
		-webkit-transform: rotate($([int]($percentInDegrees + 1))deg); /* Safari and Chrome */
		-o-transform: rotate($([int]($percentInDegrees + 1))deg); /* Opera */
		transform:rotate($([int]($percentInDegrees + 1))deg);
        filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=$([int]($percentInDegrees + 1)));
	}
	
"@            
        } else {
@"

    #Graph$RandomSalt .pie[data-value="$([int]$percentInDegrees)"]:BEFORE {
		-moz-transform: rotate($([int]($percentInDegrees))deg); /* Firefox */
		-ms-transform: rotate($([int]($percentInDegrees))deg); /* IE */
		-webkit-transform: rotate($([int]($percentInDegrees))deg); /* Safari and Chrome */
		-o-transform: rotate($([int]($percentInDegrees))deg); /* Opera */
		transform:rotate($([int]($percentInDegrees))deg);
        filter:progid:DXImageTransform.Microsoft.BasicImage(rotation=$([int]($percentInDegrees)));
	}

"@
        }
        $dc++
        $dataStart = $dataEnd
    }
)
"
                
                } elseif ($asBarGraph) {
$pieStyle = @"
$(
    $dataStart = 0 
    $totalSliced = 0
    $totalSliced = $graphData.Values | Measure-Object -Maximum
    $totalMax = $totalSliced | Select-Object -ExpandProperty Maximum
    $totalSliced = $totalSliced | Select-Object -ExpandProperty Sum
    $dc = 0 
    $pieHtml = ''
    foreach ($graphItem in $graphItemOrder) {
        $val = $graphData[$graphItem]
        $percentOfTotal = $val / ($totalMax * 1.1)
        if (-not $Horizontal) {
        $percentHeight = $GraphHeight * $percentOfTotal
        
        $pieHtml += 
        
        "
<div style='float:left;position:relative;vertical-align:bottom;bottom:0;width:$($graphWidth * .66 / $graphData.Count)px;height:$([Math]::round($percentHeight))px;margin-left:$($graphWidth * .33/ $graphData.Count)px'>
    <div class='barItemTop' style='height:$($graphHeight * (1-$percentOfTotal))px;'>

    </div>
    <div class='barChartItem' data-value='$val' data-percent='$percentOfTotal' style='width:$([Math]::Round($graphWidth * .66 / $graphData.Count))px;height:$($percentHeight)px;background-color:$($colorList[$dc])'>
    </div>

</div>
"
        
        } else {
            $percentWidth = $GraphWidth * $percentOfTotal
            $pieHtml += "
<div style='width:$($percentWidth)px;height:$($GraphHeight * .66 / $graphData.Count)px;margin-bottom:$($graphHeight * .33/ $graphData.Count)px;background-color:$($colorList[$dc])'>
</div>
"

        }
        $dc++
        $dataStart = $dataEnd
    }
)

"@                    
                }
                $htmlOut = if ($graphData.Count) {
$cssStyleChunk = if ($psBoundParameters.Style) { 
    if ($AsPieGraph -or $AsBarGraph) {
        
        $style['width'] = "${GraphWidth}px"
        
        
        $style['height'] = "$($GraphHeight + $graphData.Count * 55)px"
                                        
    }
    "style='" +(Write-CSS -Style $style -OutputAttribute) + "'"                                    
} else {
    if ($AsPieGraph -or $AsBarGraph) {
        
        
        
        
                                        
        "style='" +(Write-CSS -Style @{"width"="${GraphWidth}px";"height"="$($GraphHeight + $graphData.Count * 55)px"} -OutputAttribute) + "'"                                    
    } else {
        "style='width:100%'"
    }
}


"


<div id='Graph$RandomSalt' $cssStyleChunk>
$(if ($Header) {
    "<h$HeaderSize style='text-align:$($headerAlignment.ToLower());width:${graphWidth}px'>$($header)</h$HeaderSize>"
})

<div style='width:$GraphWidth;height;$GraphHeight;position:relative'>
$(if ($pieStyle) {
"<style>
    $PieStyle
</style>
"})
$pieHtml
</div>
<div class='GraphLegend' style='clear:both;$(if ($AsPieGraph) { "position:relative;top:$($GraphHeight)px" })'>
    $legendHtml
</div>

</div>


"        
                }
                
                $null = $null
            }
            if ($WriteResponse -and $Response.Write)  {
                $Response.Write("$htmlOut")
            } else {                
                $htmlOut                                 
            }
        
    }
}
