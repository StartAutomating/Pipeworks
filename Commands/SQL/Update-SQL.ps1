function Update-Sql
{
    <#
    .Synopsis
        Updates a SQL table
    .Description
        Inserts new content into a SQL table, or updates the existing contents of a SQL table
    .Example
        Get-Counter | 
            Select-Object -ExpandProperty CounterSamples  | 
            Update-Sql -TableName Perfcounters -Force -ConnectionStringOrSetting SqlAzureConnectionString
    .Link
        Select-Sql
    .Link
        Remove-Sql

    #>
    [OutputType([Nullable])]
    param(
    # The name of the SQL table
    [Parameter(Mandatory)]
    [string]$TableName,

    # The Input Object
    [Parameter(Mandatory, ValueFromPipeline)]
    [PSObject]
    $InputObject,

    # A List of Properties to add to the database.  If omitted, all properties will be added (except those excluded with -ExcludeProperty)    
    [string[]]
    $Property,

    # A List of Properties to exclude from the database.  If omitted, all properties (or the properties specified with the -Property parameter) will be added    
    [string[]]
    $ExcludeProperty,
    
    # The rowkey of the input object
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $RowKey,

    # The property of the input object to use as a row    
    [string]
    $RowProperty,

    # The type of key to use for the SQL table.
    [ValidateSet('Guid', 'Hex', 'SmallHex', 'Sequential', 'Named', 'Parameter')]
    [string]$KeyType  = 'Guid',

    # A lookup table containing SQL data types
    [Collections.IDictionary[]]
    $ColumnType,


    # A lookup table containing the real SQL column names for an object
    [Collections.IDictionary[]]
    $ColumnAlias,

    # If set, will force the creation of a table.
    # If omitted, an error will be thrown if the table does not exist.
    [Switch]
    $Force,

    # The connection string or a setting containing the connection string.
    [String]
    $ConnectionStringOrSetting,

    # If set, will output SQL.  Be aware that this will only output insert statements, not update statements
    [Switch]
    $OutputSql,

    # If set, will use SQL server compact edition    
    [Switch]
    $UseSQLCompact,

    # The path to SQL Compact.  If not provided, SQL compact will be loaded from the GAC    
    [string]
    $SqlCompactPath,    
    

    # If set, will use SQL lite    
    [Alias('UseSqlLite')]
    [switch]
    $UseSQLite,
    
    # The path to SQLite.  If not provided, SQLite will be loaded from Program Files
    [Alias('SqlLitePath')]
    [string]    
    $SqlitePath,

    # If set, will use MySql to connect to the database        
    [Switch]
    $UseMySql,
    
    # The path to MySql's .NET connector.  If not provided, MySql will be loaded from the GAC.            
    [string]    
    $MySqlPath,
    
    
    # The path to a SQL compact or SQL lite database    
    [Alias('DBPath')]
    [string]
    $DatabasePath,

    # If set, will skip table creation column checks
    [Switch]
    $DoNotCheckTable,

    # If set, will keep the connection open.
    [Switch]
    $KeepConnected,

    # Foreign keys in the table.    
    [Collections.IDictionary]
    $ForeignKey = @{},

    # The length of a string key.  By default, 100
    [Uint32]
    $StringKeyLength = 100,

    # If set, will hide the progress 
    [Switch]
    $HideProgress,
    
    # If set, will output the original object.  
    [switch]
    $Passthru,

    # If set, will ignore script properties on inputted objects.  
    # Script Properties are properties added by the PowerShell types engine.
    # If you ignore script properties (and the table includes the PSTypeName column), they will automatically be reconstructed in PowerShell.
    # This can reduce storage space, but will prevent non-PowerShell clients from seeing the properties 
    [Switch]
    $IgnoreScriptProperty,

    # If set, will not attempt to create or set a PSTypeName column.
    # The PSTypeName column is used to decorate data returned from Select-SQL, allowing it to act as PowerShell objects that can be formatted and extended.
    [Alias('NoDecoration','NoDecorate')]
    [switch]
    $NoPSTypeName
    )


    begin {
        #region Store SQL parameters for later
        $sqlParams = @{} + $psboundparameters
        foreach ($k in @($sqlParams.Keys)) {
            if ('SqlCompactPath', 'UseSqlCompact', 'SqlitePath', 'UseSqlite', 'UseMySql', 'MySqlPath', 'DatabasePath', 'ConnectionStringOrSetting' -notcontains $k) {
                $sqlParams.Remove($k)
            }
        }        
        #endregion Store SQL parameters for later
        $params = @{} + $psboundparameters
        
        #region Get Connection String
        if ($PSBoundParameters.ConnectionStringOrSetting) {
            if ($ConnectionStringOrSetting -notlike "*;*") {
                $ConnectionString = Get-Secret -Name $ConnectionStringOrSetting -AsPlainText
            } else {
                $ConnectionString =  $ConnectionStringOrSetting
            }
            $script:CachedConnectionString = $ConnectionString
        } elseif ($script:CachedConnectionString){
            $ConnectionString = $script:CachedConnectionString
        } else {
            $ConnectionString = ""
        }
        if (-not $ConnectionString -and -not ($UseSQLite -or $UseSQLCompact)) {
            throw "No Connection String"
            return
        }
        #endregion Get Connection String

        #region Connect to SQL
        if (-not $OutputSQL) {
            if ($script:CachedConnection -and $script:CachedConnection.State -eq 'Open') {
                $sqlConnection = $script:CachedConnection
            } elseif ($UseSQLCompact) {
                # Late load SQL Compact if we haven't already
                if (-not ('Data.SqlServerCE.SqlCeConnection' -as [type])) {
                    if ($SqlCompactPath) {
                        $resolvedCompactPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($SqlCompactPath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedCompactPath)
                    } else {
                        $asm = [reflection.assembly]::LoadWithPartialName("System.Data.SqlServerCe")
                    }
                    $null = $asm
                }
                $resolvedDatabasePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                $sqlConnection = New-Object Data.SqlServerCE.SqlCeConnection "Data Source=$resolvedDatabasePath"
                $sqlConnection.Open()

                $script:CachedConnection = $sqlConnection
            } elseif ($UseSqlite) {
                # Late load SQLite if we haven't already
                if (-not ('Data.Sqlite.SqliteConnection' -as [type])) {
                    if ($sqlitePath) {
                        $resolvedLitePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($sqlitePath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedLitePath)
                    } elseif ($env:ProgramFiles) {
                        $asm = [Reflection.Assembly]::LoadFrom("$env:ProgramFiles\System.Data.SQLite\2010\bin\System.Data.SQLite.dll")
                    }                    
                }
                
                
                $resolvedDbPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                $sqlConnection = New-Object Data.Sqlite.SqliteConnection "Data Source=$resolvedDbPath"
                $sqlConnection.Open()
                $script:CachedConnection = $sqlConnection
            }  elseif ($useMySql) {
                if (-not ('MySql.Data.MySqlClient.MySqlConnection' -as [type])) {
                    $asm = if (-not $mySqlPath) {
                        [Reflection.Assembly]::LoadWithPartialName('MySql.Data')
                    } else {
                        [Reflection.Assembly]::LoadFrom($MySqlPath)
                    }                    
                    $null = $asm
                    
                }
                $sqlConnection = New-Object MySql.Data.MySqlClient.MySqlConnection "$ConnectionString"
                $sqlConnection.Open()
            } else {
                $sqlConnection = New-Object Data.SqlClient.SqlConnection "$connectionString"
                $sqlConnection.Open()
                $script:CachedConnection = $sqlConnection
            }
            

        }
        #endregion Connect to SQL

        $dataSet = [Data.DataSet]::new()
        
        $propertyMatches = @{}
        foreach ($_ in $Property) {
            if ($_) {
                $propertyMatches.$_ =  $_
            }
        }

        $Exclusions = @{
            'RowError' = $true
            'RowState' = $true
            'Table' = $true
            'ItemArray' = $true 
            'HasErrors' = $true
        }
        
        foreach ($_ in $ExcludeProperty) {
            if ($_) {
                $exclusions.$_ =  $true
            }
        }


        $SqlTypeMap = @{
            [string] = 
                if ($UseSQLCompact) {
                    "ntext"
                } elseif ($UseSQLite) {
                    "text"
                } elseif ($useMySql) {
                    "longtext"
                } else {
                    "varchar(max)"                            
                }
            [bool] = 'bit'
            [switch] = 'bit'
            [double] = 'float'
            [Long] = 'bigint'
            [DateTime] = 'datetime'
            [byte] = 'tinyint'
            [int16] = 'smallint'
            [int] = 'int'
            [char] = 'char(1)'
            [BigInt] = 'bigint'
        }
        #region Common Parameters & Procedures
        
               
        
        $GetPropertyNamesAndTypes = {
            param($object, [string[]]$PropertyList)
            $haspstypename = $false            
            
            if ($PropertyList) {
                $propMatch = @{}
                foreach ($_ in $PropertyList) {
                    $propMatch[$_] = $true
                }
            }
            foreach ($_ in $object.psobject.properties) {
                if (-not $_) { continue } 
                if ($PropertyList -and -not $propMatch[$_.Name]) { continue } 
                if ($IgnoreScriptProperty -and $_.MemberType -eq 'ScriptProperty') { continue }
                if ($propertyMatches.Count -and -not $propertyMatches[$_.Name]) {
                    continue
                } 

                if ($exclusions.Count -and $exclusions.ContainsKey($_.name)) {
                    continue
                }
                

                if ($_.Name -like 'pstypename*') {
                    if (-not $Force) { continue } 
                    $haspstypename = $true                    
                }
                    
                $sqlType = if ($columnType -and $columnType[$_.Name]) {
                    $columnType[$_.Name]
                } elseif ($_.Value -ne $null) {
                    $SqlTypeMap[$_.Value.GetType()]                    
                }

                if (-not $sqlType) { $sqlType = $SqlTypeMap[[string]] }

                $columnName = if ($ColumnAlias -and $ColumnAlias[$_.Name]) {
                    $ColumnAlias[$_.Name]
                } else {
                    $_.Name
                }



                    
                [PSCustomObject]@{
                    Name=$columnName 
                    Value = if ($sqlType -eq 'bit') {
                        if ($_.Value) {
                            1 
                        } else {
                            0
                        }
                    } elseif ($sqlType -eq 'datetime') {
                        if ($useMySql) {
                            ($_.Value -as [datetime]).ToString([Globalization.CultureInfo]::InvariantCulture.DateTimeFormat.SortableDateTimePattern)
                        } else {
                            $_.Value
                        }
                    } else {
                        ($_.Value -as [string]).Replace("'", "''")
                    }
                    SqlType = $sqlType
                }
            }


            if ($Force -and -not $NoPSTypeName) {
                if ($haspstypename -or ($PropertyList -and $propertyList -notcontains 'pstypename') -or 
                    ($object.pstypenames[0] -like "*.PSCustomObject" -or 
                    $object.pstypenames[0] -like "*Selected.*")) {
                } else {
                    [PSCustomObject]@{
                        Name="pstypename"
                        Value = $object.pstypenames -join '|'
                        SqlType = if ($UseSQLCompact) {
                                    "ntext"
                                } elseif ($UseSQLite) {
                                    "text"
                                } elseif ($useMySql) {
                                    "longtext"
                                } else {
                                    "varchar(max)"
                                }
                    }
                }
            }
        }

        #endregion Common Parameters & Procedures
        $sqlAdapter = 
            if ($UseSQLCompact) {
                New-Object Data.SqlServerCE.SqlCeDataAdapter
            } elseif ($UseSQLite) { 
                New-Object Data.SQLite.SQLiteDataAdapter
            } elseif ($UseMySql) {
                New-Object MySql.Data.MySqlClient.MySqlDataAdapter
            } else {
                New-Object Data.SqlClient.SqlDataAdapter
            }

        if (-not $DoNotCheckTable) {
            
            $columnsInfo = 
                Get-SqlTable -TableName $TableName @sqlParams
        
            if (-not $columnsInfo) {
                # Table Doesn't Exist Yet, mark it for creation 
                if (-not $Force) {
                    Write-Error "$tableName does not exist"
                }    
                    
            }
            $Local:DoNotRetry = $false
        }

        $AccumulatedInput = New-Object Collections.ArrayList
    }


    process {                
        # If there are no columns, and -Force  is not set
        if (-not $columnsInfo -and (-not $force) -and (-not $DoNotCheckTable)) {
            
            return
        }

        
        
        $params = @{} + $psboundparameters
        $null = $AccumulatedInput.Add($params)
        
        #endregion Attempt SQL Insert 
    }

    end {         
        $total= $AccumulatedInput.Count
        $counter =0 
        $progressId = Get-Random        

        foreach ($in in $AccumulatedInput) {
            $counter++
            $perc = $counter * 100 / $total
            if (-not $HideProgress) {
                Write-Progress "Updating $TableName" "$counter of $total" -PercentComplete $perc -Id $progressId
            }
            foreach ($_ in $in.GetEnumerator()) {
                $ExecutionContext.SessionState.PSVariable.Set($_.Key, $_.Value)
            }

            

            $objectSqlInfo = . $GetPropertyNamesAndTypes $inputObject 

            # There are no columns, create the table
            if (-not $columnsInfo -and (-not $Local:DoNotRetry) -and -not $DoNotCheckTable) {
                $extraSqlParams = @{StringKeyLength = $StringKeyLength}

                if ($ForeignKey -and $ForeignKey.Count) {
                    $extraSqlParams["ForeignKey"] = $ForeignKey
                }
                
            
                if ($RowProperty) {
                    Add-SqlTable -KeyType $keyType -TableName $TableName -Column (
                        $objectSqlInfo | 
                            Where-Object { $_.Name -ne $RowProperty } | 
                            Select-Object -ExpandProperty Name
                    ) -DataType (
                        $objectSqlInfo | 
                            Where-Object { $_.Name -ne $RowProperty } | 
                            Select-Object -ExpandProperty SqlType
                    ) @sqlParams -RowKey $RowProperty @extraSqlParams
            
                } else {
                    Add-SqlTable -KeyType $keyType -TableName $TableName -Column (
                        $objectSqlInfo | 
                            Where-Object { $_.Name -ne 'RowKey' } | 
                            Select-Object -ExpandProperty Name
                    ) -DataType (
                        $objectSqlInfo | 
                            Where-Object { $_.Name -ne 'RowKey' } | 
                            Select-Object -ExpandProperty SqlType
                    ) @sqlParams @extraSqlParams
                }

            
            
                if (-not $DoNotCheckTable) {
                    $columnsInfo = Get-SQLTable -TableName $TableName @sqlParams
                }
        
            }

            # If there's still no columns info the table could not be created, and we should bounce
            if (-not $columnsInfo -and -not $DoNotCheckTable) {
                $Local:DoNotRetry = $true
                return

            }
            $updated = $false


            # It's quicker, and involves less simultaneous connections, to attempt an insert before attempting an update

            #region Attempt SQL Insert
            $row = 
                if ($psBoundParameters.RowKey -and -not $updated) {
                    $psBoundParameters.RowKey
                } elseif ($psBoundParameters.RowProperty -and $inputObject.$rowProperty) {
                    $inputObject.$rowProperty
                } elseif ($KeyType -eq 'GUID') {
                    [GUID]::NewGuid()
                } elseif ($KeyType -eq 'Hex') {
                    "{0:x}" -f (Get-Random)
                } elseif ($KeyType -eq 'SmallHex') {
                    "{0:x}" -f ([int](Get-Random -Maximum 512kb))
                } elseif ($KeyType -eq 'Sequential') {
                    # Seqential keys should be handled by SQL
                    #if ($row -ne $null -and $row -as [Uint32]) {
                    #    $row + 1  
                    #} else {                    
                        #Select-SQL -FromTable $TableName -Property "COUNT(*)" @sqlParams | 
                        #    Select-Object -ExpandProperty Column1                    
                    #}
                }
            $sqlInfo = @{}
            
            $insertColumns = @(foreach ($_ in $objectSqlInfo) {
                if ($RowProperty) {
                    if ($_.Name -eq $RowProperty) {
                        continue 
                    }
                } elseif ($_.Name -eq 'RowKey') {
                    continue
                } 
                $_.Name 
                $sqlInfo[$_.Name]  = $_.Value
            })

            
            

            

            

            $insertInfo=  @($sqlInfo[$insertColumns]) -join "', '"
            $isUpdate = $false
            $insertNames = if ($UseMySql) {
                $insertColumns  -join ", "
            } else {
                $insertColumns  -join "`", `""
            }
            
            
            if ($params.RowKey ) { 
                $sqlInsert = 
                    if ($UseMySql) {
                        "INSERT INTO $TABLEName (RowKey, $insertNames) VALUES ('$Row','$insertInfo')"
                    } else {
                        "INSERT INTO $TABLEName (`"RowKey`", `"$insertNames`") VALUES ('$Row','$insertInfo')"
                    }
                    
            } else {
                $rowKeyInfo = if ($KeyType -ne 'Sequential' -and $row) {
                    if ($UseMySql) {
                        if ($RowProperty) {
                            "$rowProperty,"
                        } else {
                            "RowKey,"
                        }
                    } else {
                        if ($RowProperty) {
                            "`"$rowProperty`","
                        } else {
                            "`"RowKey`","
                        }
                    }
                    
                }

                if ($keyType -eq 'Sequential') {
                    if ($inputObject.$rowProperty -or $psboundparameters.RowKey)  {
                        $isUpdate = $true
                    }
                
                }
                
                $rowKeyValue = if ($KeyType -ne 'Sequential' -and $row) {
                    "'$Row',"
                }
                
                $sqlInsert = 
                    if ($UseMySql) {
                        "INSERT INTO $TABLEName ($rowKeyInfo $insertNames) VALUES ($rowKeyValue '$($insertInfo)')"
                    } else {
                        "INSERT INTO $TABLEName ($rowKeyInfo `"$insertNames`") VALUES ($rowKeyValue '$($insertInfo)')"
                    }
                    
            }
            if (-not $isUpdate) {
                Write-Verbose $sqlInsert
            }

            $sqlStatement = $sqlInsert
            $shouldKeepTrying = $true
            do {
                try {
                    $sqlStatement = $sqlInsert
                    if ($outputSql) {
                        $sqlStatement
                    } elseif ($isupdate) {
                        throw "It's an update"
                    } else {
                        $sqlAdapter.SelectCommand = $sqlStatement
                        $sqlAdapter.SelectCommand.Connection = $sqlConnection
                        $dataSet.Clear()
                        $rowCount = $sqlAdapter.Fill($dataSet)                        
                    }
                    $null = $rowCount
                    $shouldKeepTrying = $false    
                } catch {
                    $insertError = $_ 
                    $null = $insertError

                    $badColumnName  = 
                        if ($_.Exception.InnerException.Message -like "*invalid*") {
                                ($_.Exception.InnerException.Message -split "'")[1]
                        } elseif ($_.Exception.InnerException.Message -like "*no column named*") {
                                ($_.Exception.InnerException.Message -split " ")[-1]
                        } elseif ($_.Exception.InnerException.Message -like "*column name is not valid*") {
                            ($_.Exception.InnerException.Message -split "[ =\]]" -ne '')[-1]
                        }  elseif ($_.Exception.InnerException.Message -like "Unknown column*") {
                            ($_.Exception.InnerException.Message -split "'" -ne '')[1]
                        }

                    if ($Force -and $badColumnName) {
                    
                        $columnName = $badColumnName

                        $columnInfo = . $GetPropertyNamesAndTypes $inputObject -propertyList $columnName
                    
                        $sqlAlter=  "ALTER TABLE $TableName ADD $ColumnName $($columnInfo.SqlType)"
                        $sqlStatement = $sqlAlter
                        try {
                            $sqlAdapter.SelectCommand = $sqlStatement
                            $sqlAdapter.SelectCommand.Connection = $sqlConnection
                            $dataSet.Clear()
                            $rowCount = $sqlAdapter.Fill($dataSet)                          
                        
                        } catch {
                            $shouldKeepTrying = $false
                            Write-Error $_
                            Write-Debug $_
                        } 
                                        
                    } elseif ($insertError.Exception.HResult -eq '-2146233087' -or $insertError.Exception.Hresult -eq '-2146233087' -or $isUpdate -and -not $badColumnName) {
                        # It's a duplicate, so update instead of create
                    
                        $sqlUpdate =  "UPDATE $TableName SET $(@(foreach ($_ in $objectSqlInfo) {
                                        if (-not $sqlInfo.ContainsKey($_.Name)) { continue }
                                        if ($UseMySql) {
                                            $_.Name + '=' + "'$($($_.Value))'" 
                                        } else {
                                            '[' + $_.Name + ']=' + "'$($($_.Value))'" 
                                        }
                                    }) -join ", 
") 
    $(
                                        if ($params.RowKey) { 
                                            "WHERE RowKey='$RowKey'" 
                                        } elseif (
                                            $InputObject.$RowProperty) {
                                                "WHERE $RowProperty ='$($inputObject.$RowProperty)'"
                                        })"
                        
                            
                        
                        Write-Verbose $SqlUpdate


                        $shouldKeepTrying = $true
                        do {
                            try {
                                $sqlStatement = $sqlUpdate
                                if ($outputSql) {
                                    $sqlStatement
                                } else {
                                    $sqlAdapter.SelectCommand = $sqlStatement
                                    $sqlAdapter.SelectCommand.Connection = $sqlConnection
                                    $dataSet.Clear()
                                    $rowCount = $sqlAdapter.Fill($dataSet)

                                }
                                $shouldKeepTrying = $false      
                            } catch {
                                if ($_.Exception.InnerException.Message -like "*invalid column name*" -or 
                                    $_.Exception.InnerException.Message -like "*no column named*" -or
                                    $_.Exception.InnerException.Message -like "*column name is not valid*") {
                    
                                    $columnName  = if ($_.Exception.InnerException.Message -like "*invalid*") {
                                         ($_.Exception.InnerException.Message -split "'")[1]
                                    } elseif ($_.Exception.InnerException.Message -like "*no column named*") {
                                         ($_.Exception.InnerException.Message -split " ")[-1]
                                    } elseif ($_.Exception.InnerException.Message -like "*column name is not valid*") {
                                        ($_.Exception.InnerException.Message -split "[ =\]]" -ne '')[-1]
                                    }

                                    $columnInfo = & $GetPropertyNamesAndTypes $inputObject -propertyList $columnName
                    
                                    $sqlAlter=  "ALTER TABLE $TableName ADD $ColumnName $($columnInfo.SqlType)"
                                    $sqlStatement = $sqlAlter
                                    try {
                                        $sqlAdapter.SelectCommand = $sqlStatement
                                        $sqlAdapter.SelectCommand.Connection = $sqlConnection
                                        $dataSet.Clear()
                                        $rowCount = $sqlAdapter.Fill($dataSet)   
                        
                                    } catch {
                                        $shouldKeepTrying = $false
                                        Write-Error $_
                                        Write-Debug $_
                                    }                                                                          
                                } else {
                                    $shouldKeepTrying = $false
                                    Write-Debug $_
                                    Write-Error $_
                                }
                            }
                        } while ($shouldKeepTrying)
                        
                    
                    } else {
                        $shouldKeepTrying = $false
                        Write-Debug $_
                        if ($badColumnName -and $Force -or -not $badColumnName) {
                            Write-Error $_
                        }                        
                    }


                
                }
            } while ($shouldKeepTrying)
            if ($Passthru) {
                $InputObject
            }
        }
        if (-not $HideProgress) {
            Write-Progress "Updating $TableName" "Completed" -Completed -Id $progressId

        }
        if ($sqlConnection -and -not $keepConnected) {
            $sqlConnection.Close()
            $sqlConnection.Dispose()
        }        
    }
} 



