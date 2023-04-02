function Import-StoredProcedure
{
    <#
    .Synopsis
        Imports a Stored Procedure as a PowerShell function
    .Description
        Imports SQL Stored Procedure as a PowerShell functions
    .Notes
        At present, only stored procedures on SQL Server or in SQL Azure are supported.    
    .Link
        Select-SQL
    .Example
        # Generates functions for all stored procedures in SQLAzure who have a name like *WmiSpy*
        Import-StoredProcedure -Name "*WmiSpy*" -ConnectionStringOrSetting SQLAzureConnectionString -EmbedConnectionString
    #>
    [OutputType([scriptblock], [string])]
    [Alias('Import-Sproxy')]
    param(
    # The names of specific stored procedures
    [Parameter(Position=0,ValueFromPipelineByPropertyName=$true)]
    [string[]]$Name,
    
    # A dictionary of renames.
    # Stored procedures whose name or generated name match the key will be replaced with the value.
    [Collections.IDictionary]
    $Rename,

    # A connection string or setting.    
    [Alias('ConnectionString', 'ConnectionSetting')]
    [string]$ConnectionStringOrSetting,
    
    # If set, the connection string will be embedded in the generated functions.  
    # If you are using integrated security, this is perfectly safe.
    # If you are not using integrated security, this is not safe.
    [switch]$EmbedConnectionString
    )

    process {
        #region Get Stored Procedures from SQL
        $SqlParams = @{ConnectionString=$ConnectionStringOrSetting}
        if ($Name) {
            $sqlParams.Where = 
                @(foreach ($n in $name) {
                    "Specific_Name LIKE '$($n.Replace('*','%').Replace("'", "''"))'"
                }) -join " OR " 
        }


        $allSprocs = Select-Sql @SqlParams -FromTable "INFORMATION_SCHEMA.ROUTINES" 
        $sprocsParameters = Select-Sql @SqlParams -FromTable "INFORMATION_SCHEMA.PARAMETERS" 

        if ($EmbedConnectionString -and 
            $script:ConnectionString -and 
            -not $PSBoundParameters.ConnectionStringOrSetting) {
            $ConnectionStringOrSetting = $script:ConnectionString
        }

        $sprocParametersByProc = $sprocsParameters | 
            Group-Object { $_.Specific_Schema + "." + $_.Specific_Name } 

        $procedures = $allSprocs | 
            Group-Object {$_.Specific_Schema + "." + $_.Specific_Name } 

        if ($Name) {
            # Filter procedures by name
            $procedures = $procedures | 
                Where-Object {
                    $procName = @($_.Name -split "\.")[1]
                    foreach ($n in $name) { 
                        $procName -like $n
                    } 
                }
        }
        #endregion Get Stored Procedures from SQL


        $verbs = Get-verb | Select-Object -ExpandProperty Verb
        
        foreach ($sproc in $procedures) {
            $parametersByPosition = $sprocParametersByProc |
                Where-Object{ $_.Name -eq $sproc.Name } |
                Select-Object -ExpandProperty Group | 
                Where-Object {$_.Parameter_Mode -like 'IN*' } | 
                Sort-Object ORDINAL_POSITION 
            $sprocName = @($sproc.Name -split "\.")[1]
            $parametersWithDefaults = @{}
            $ParameterHelp = @{}

            $Definition = $sproc.Group|
                Select-Object -First 1 -ExpandProperty Routine_Definition

            $usesDataTable = $false
            # Skip procedures that declare functions
            if ($Definition -match "CREATE(\s{1,})FUNCTION") {
                continue
            }                

            $definitionLines = @($Definition -split "[$([Environment]::NewLine)]" -ne '')
            
            $procedureStartLine = -1
            $procedureParamEnd = -1
            $paranethesisDepth = 0
            for ($dln =0; $dln -lt $definitionLines.count; $dln++) {
                if ($definitionLines[$dln] -like "CREATE*PROCEDURE*"){
                    $procedureStartLine = $dln 

                    if ($dln -ne 0) {
                        $docLines = $definitionLines[0..($dln-1)] -like "--*" | 
                            ForEach-Object -Begin { $firstLine = $true } -Process { 
                                $l = $_.Trim().TrimStart("--").TrimEnd(":")
                                $headerLine = $false
                                if ($l.Trim()  -like "Synopsis*") {
                                    $l = $l -ireplace "Synopsis", ".Synopsis"
                                    $headerLine  = $true
                                }
                                if ($l.Trim()  -like "Description*") {
                                    $l = $l -ireplace "Description", ".Description"
                                    $headerLine  = $true
                                }
                                if ($l.Trim()  -like "Example*") {
                                    $l = $l -ireplace "Example", ".Example"
                                    $headerLine  = $true
                                }
                                if ($l.Trim()  -like "Link*") {
                                    $l = $l -ireplace "Link", ".Link"
                                    $headerLine  = $true
                                }
                                if ($l.Trim()  -like "Notes*") {
                                    $l = $l -ireplace "Notes", ".Notes"
                                    $headerLine  = $true
                                }
                                if ($firstLine) {
                                    if ($headerLine) {
                                        "#" + $l                                   
                                    } else {
                                        "# " + $l                                
                                    }                                    
                                    $firstLine = $false
                                } else {
                                    if ($headerLine) {
                                        "    #" + $l                                
                                    } else {
                                        "    #    " + $l                                
                                    }
                                    
                                }
                                
                            } 
                    } else {
                        $docLines = ""
                    }
                }
                if ($procedureStartLine -ne -1) {
                    foreach ($char in $definitionLines[$dln].ToCharArray()) {
                        if ($char -eq '(') {
                            $paranethesisDepth++
                        } elseif ($char -eq ')') {
                            $paranethesisDepth--
                        }                
                    }
                }
                

                if ($procedureStartLine -ne -1 -and -not $paranethesisDepth) {
                    $trimmedLine = $definitionLines[$dln].Trim()
                    if ($definitionLines[$dln] -like "*AS*" -and $trimmedLine -notlike "@*" -and $trimmedLine -notlike ",*") {
                        $procedureParamEnd = $dln        
                        break
                    }
                }


            }
            
            $procedureStartLine = $procedureStartLine + 1
            $procedureParamEnd = $procedureParamEnd -1 
            $ParamStatement = 
                if ($procedureStartLine -le $procedureParamEnd) {
                    @($definitionLines[$procedureStartLine..$procedureParamEnd]  | ? { $_.Trim() -ne ''})
                } else {
                    @($definitionLines[$procedureParamEnd..$procedureStartLine]  | ? { $_.Trim() -ne ''})
                }
            
            $paramParts = $ParamStatement 
            foreach ($paramStatementItem in $paramParts) {
                $chunks = @($paramStatementItem -split "[\s\t]+" -ne '')
                if (-not $chunks -or $chunks.Length -lt 2) { continue } 
                $parameterName = $chunks[0].Trim().Trim(',').Trim('@').Trim(',')
                $parameterType = $chunks[1].Trim('[]')
                if ($chunks -eq '=') {
                    # Default value present    
                    $parametersWithDefaults[$parameterName] = $true
                }

                $comments = ""
                $comments = for ($i = 2; $i -lt $chunks.Count; $i++) {
                    if ($chunks[$i] -eq '--') {
                        $chunks[($i + 1)..($chunks.Count -1)]
                    }
                }


                $ParameterHelp[$parameterName] = $comments -join ' '
                

            }
            $ThisCommandsVerb = ""
            $ThisCommandsNoun = ""
            
            foreach ($v in $verbs) {
                if ($sprocName -match "$v") {
                    $ThisCommandsVerb = $v
                    $ThisCommandsNoun = $sprocName -replace $v
                    break     
                }
            }


            if (-not $ThisCommandsVerb) { $ThisCommandsVerb = "Invoke" } 
            if (-not $ThisCommandsNoun) { $ThisCommandsNoun = $sprocName } 
            $thisCommandName = $ThisCommandsVerb+'-'+$ThisCommandsNoun
            if ($Rename.Count -and 
                ($Rename[$thisCommandName] -or $rename[$sprocName])
            ) {
                $thisCommandName = 
                    if ($Rename[$thisCommandName]) {
                        $Rename[$thisCommandName]
                    } else {
                        $Rename[$sprocName]
                    }
            }

            $paramNamesList = [Collections.ArrayList]::new()
            $ParameterChunk = 
                foreach ($param in $parametersByPosition) {
                    $paramName = $param.Parameter_Name.TrimStart("@")
                    $null = $paramNamesList.Add($paramName)
                    $parameterType = 
                        if ($param.Data_Type -like "*varchar*") {
                            'string'
                        } elseif ($param.Data_Type -eq 'bigint') {
                            'bigint'
                        } elseif ($param.Data_Type -eq 'int') {
                            'int'
                        } elseif ($param.Data_Type -eq 'datetime' -or $param.Data_Type -eq 'smalldatetime') {
                            'datetime'
                        } elseif ($param.Data_Type -eq 'bit') { 
                            'switch'
                        } elseif ($param.Data_Type -eq 'tinyint') {
                            'byte' 
                        } elseif ($param.Data_Type -eq 'char') {
                            'char'
                        } elseif ($param.Data_Type -eq 'table type') {
                            'psobject[]'
                            $usesDataTable = $true
                        } else {
                            'psobject'
                        } 
                    
                    $ParameterHelpText = if($ParameterHelp.$paramName) {
                        $lines = $ParameterHelp.$paramName -split "[$([Environment]::newline)]" -ne ''
                        $firstLine = $true 
                        "$(@(foreach ($l in $lines) {
                        if ($firstLine) {
                            "# $l"
                        } else {
                            "    # $l"
                        }
                        
                        }) -join ([Environment]::NewLine))
    "
                    } else {
                    }

                    "$parameterHelpText[Parameter($(if (-not $parametersWithDefaults.$paramName) { "Mandatory=`$true,"} else {})Position=$($param.ordinal_Position - 1),ValueFromPipelineByPropertyName=`$true)]
    [$parameterType]
    `$$paramName"
                }


    $paramBlock = @"
$($ParameterChunk -join ',
    '),
    $(if (-not $EmbedConnectionString) {
    "[Parameter(Mandatory=`$true)]
    [string]
    `$ConnectionString,"
    })
    # The way the data will be outputted.  
    [ValidateSet("Hashtable", "Dictionary","Datatable", "DataSet", "PSObject")]
    [string]
    `$AsA = "PSObject"
"@

    $paramBlock = $paramBlock.Trim("$([Environment]::Newline)").Trim().TrimStart(",")
            $functionDefinition = @"
function $ThisCommandsVerb-$ThisCommandsNoun {
    $($docLines -join ([Environment]::NewLine))
    param(
    $paramBlock
    )
    begin {
        `$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
        `$SqlConnection.ConnectionString = "$(if ($EmbedConnectionString -and $ConnectionStringOrSetting) { "$ConnectionStringOrSetting".Replace('"', '`"')} else { '$connectionString' })"        
        `$SQLConnection.Open()


        $(if ($usesDataTable) {
"
        function ConvertTo-DataTable {
            $((Get-Command -ErrorAction SilentlyContinue ConvertTo-DataTable).Definition)
        }
"            
        })
    }

    process {
        `$SQLCmd = New-Object System.Data.SqlClient.SqlCommand -Property @{
            CommandText = "$($sproc.Name)"
            Connection  = `$sqlConnection
            CommandType = 'StoredProcedure'
        }

        $(if ($paramNamesList) {
        "
        foreach (`$k in '$($paramNamesList -join "','")') {
            if (-not `$k) { continue } 
            if (`$psBoundParameters.`$k) {
                `$v = `$psBoundParameters.`$k
                if (`$v -is [DateTime]) {
                    `$p= `$SqlCmd.Parameters.AddWithValue(`"@`$k`", [Data.SqlDbType]::DateTime)
                    `$p.Value = `$v
                } elseif (`$v -is [Object[]]) {
                    `$p = `$SqlCmd.Parameters.Add(`"@`$k`", [Data.SqlDbType]::Structured)                    
                    if (`$v -is [Data.DataRow]) {
                        `$p.value = `$v          
                    } else {
                        `$p.value = ConvertTo-DataTable `$v          
                    }
                } elseif (`$v -is [switch]) {
                    if (`$v) {
                        `$null = `$SqlCmd.Parameters.AddWithValue(`"@`$k`", '1')
                    } else {
                        `$null = `$SqlCmd.Parameters.AddWithValue(`"@`$k`", '0')
                    }
                } else {
                    `$null = `$SqlCmd.Parameters.AddWithValue(`"@`$k`", `"`$(`$v)`")
                }
            }
            
        }
        "
        })
        

        `$sqlAdapter= New-Object "Data.SqlClient.SqlDataAdapter" `$sqlCmd
        `$dataSet = New-Object Data.DataSet
        `$rowCount = `$sqlAdapter.Fill(`$dataSet)


        if (`$dataSet) {        
            if (`$AsA -eq 'DataSet') {
                `$dataSet
            } elseif (`$AsA -eq 'DataTable') {
                foreach (`$t in `$dataSet.Tables) {
                    ,`$t
                }
            } elseif (`$AsA -eq 'PSObject') {                        
                foreach (`$t in `$dataSet.Tables) {
            
                    foreach (`$r in `$t.Rows) {
                    
                        if (`$r.pstypename) {                    
                            `$r.pstypenames.clear()
                            foreach (`$tn in (`$r.pstypename -split "\|")) {
                                if (`$tn) {
                                    `$r.pstypenames.add(`$tn)
                                }
                            }
                        
                        }
                        `$null = `$r.psobject.properties.Remove("pstypename")
                
                        `$r
                
                    }
                }
            } elseif (`$AsA -in 'Hashtable', 'Dictionary') {
                `$avoidProperties = @{}
                foreach (`$pName in 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors') {
                    `$avoidProperties[`$pName] = `$true 
                }
                foreach (`$t in `$dataSet.Tables) {
            
                    foreach (`$r in `$t.Rows) {
                    
                        `$out = if (`$AsA -eq 'Hashtable') { else @{} } else { [Ordered]@{} }
                        
                        foreach (`$prop in `$r.psobject.Properties) {
                            if (`$avoidProperties[`$prop.Name]) {
                                continue
                            }
                            `$out[`$prop.Name] = `$prop.Value
                        }                        
                        

                        `$out                
                    }
                }
            }
        }
    }

    end {
        `$SqlConnection.Close()
    }
}
"@

            [ScriptBlock]::Create($functionDefinition)
        }
    }
}
