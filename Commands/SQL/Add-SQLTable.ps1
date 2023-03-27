function Add-SqlTable {
    <#
    .Synopsis
        Adds a SQL Table
    .Description
        Creates a new Table in SQL
    .Example
         Add-SqlTable -TableName PatchyComputers -KeyType Sequential -Column MachineName, GroupName, PatchStatus, PatchWindowStart, PatchStartedAt, LastPatchedAt -DataType 'varchar(100)', 'varchar(100)', 'varchar(20)', 'datetime', 'datetime', 'datetime' -OutputSql -ConnectionStringOrSetting SqlAzureConnectionString
    .Link
        Select-SQL
    .Link
        Update-SQL
    #>
    [CmdletBinding(DefaultParameterSetName='SqlServer')]
    [OutputType([Nullable])]
    param(
    # The name of the SQL table
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$TableName,

    # The columns to create within the table
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string[]]$Column,

    # The keytype to use
    [ValidateSet('Guid', 'Hex', 'SmallHex', 'Sequential', 'Named', 'Parameter')]
    [string]$KeyType  = 'Guid',

    # The name of the column to use as a key.
    [string]
    $RowKey = "RowKey",

    # The data types of each column
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]$DataType,
    
    # A connection string or a setting containing a connection string.    
    [Alias('ConnectionString', 'ConnectionSetting')]
    [string]$ConnectionStringOrSetting,
    
    # If set, outputs the SQL, and doesn't execute it
    [Switch]
    $OutputSQL,
    
    # If set, will use SQL server compact edition
    [Parameter(Mandatory=$true,ParameterSetName='SqlCompact')]
    [Switch]
    $UseSQLCompact,


    # If set, will use MySql to connect to the database    
    [Parameter(Mandatory=$true,ParameterSetName='MySql')]
    [Switch]
    $UseMySql,
    
    # The path to MySql's .NET connector.  If not provided, MySql will be loaded from Program Files        
    [Parameter(ParameterSetName='MySql')]
    [string]    
    $MySqlPath,


    # The path to SQL Compact.  If not provided, SQL compact will be loaded from the GAC
    [Parameter(ParameterSetName='SqlCompact')]
    [string]
    $SqlCompactPath,

    # If set, will use SQL lite
    [Parameter(Mandatory=$true,ParameterSetName='Sqlite')]
    [Alias('UseSqlLite')]
    [switch]
    $UseSQLite,
    
    # The path to SQL Lite.  If not provided, SQL compact will be loaded from Program Files
    [Parameter(ParameterSetName='Sqlite')]
    [string]
    $SqlitePath,
    
    # The path to a SQL compact or SQL lite database
    [Parameter(Mandatory=$true,ParameterSetName='SqlCompact')]
    [Parameter(Mandatory=$true,ParameterSetName='Sqlite')]
    [Alias('DBPath')]
    [string]
    $DatabasePath,

    # A hashtable of default values used for the SQL table
    [Hashtable]
    $Default = @{},
    
    # Foreign keys in the table.
    [Parameter(ParameterSetName='SqlServer')]
    [Parameter(ParameterSetName='MySql')]
    [Hashtable]
    $ForeignKey = @{},
    
    # The size of a string key.  By default, 100 characters
    [Uint32]
    $StringKeyLength = 100,

    # If set, will try altering a table that already exists
    [Switch]
    $Force
    )

    begin {
        #region Resolve Connection String
        if ($PSBoundParameters.ConnectionStringOrSetting) {
            if ($ConnectionStringOrSetting -notlike "*;*") {
                $ConnectionString = Get-Secret -Name $ConnectionStringOrSetting -AsPlainText
            } else {
                $ConnectionString =  $ConnectionStringOrSetting
            }
            $script:CachedConnectionString = $ConnectionString
        } elseif ($psBoundParameters.Server -and $psBoundParameters.Database) {
            $ConnectionString = "Server=$Server;Database=$Database;Integrated Security=True;"
            $script:CachedConnectionString = $ConnectionString
        } elseif ($script:CachedConnectionString){
            $ConnectionString = $script:CachedConnectionString
        } else {
            $ConnectionString = ""
        }
        #endregion Resolve Connection String
        
         # Exit if we don't have a connection string, 
        # and are not using SQLite or SQLCompact (which don't need one)
        if (-not $ConnectionString -and -not ($UseSQLite -or $UseSQLCompact)) {
            throw "No Connection String"
            return
        }

        #region If we're not just going to output SQL, we might as well connect
        if (-not $OutputSQL) {
            if ($UseSQLCompact) {
                # If we're using SQL compact, make sure it's loaded
                if (-not ('Data.SqlServerCE.SqlCeConnection' -as [type])) {
                    if ($SqlCompactPath) {
                        $resolvedCompactPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($SqlCompactPath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedCompactPath)
                    } else {
                        $asm = [reflection.assembly]::LoadWithPartialName("System.Data.SqlServerCe")
                    }
                }
                # Find the absolute path
                $resolvedDatabasePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                # Craft a connection string
                $sqlConnection = New-Object Data.SqlServerCE.SqlCeConnection "Data Source=$resolvedDatabasePath"
                # Open the DB
                $sqlConnection.Open()
            } elseif ($UseSqlite) {
                # If we're using SQLite, make sure it's loaded
                if (-not ('Data.Sqlite.SqliteConnection' -as [type])) {
                    if ($sqlitePath) {
                        $resolvedLitePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($sqlitePath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedLitePath)
                    } else {
                        $asm = [Reflection.Assembly]::LoadFrom("$env:ProgramFiles\System.Data.SQLite\2010\bin\System.Data.SQLite.dll")
                    }
                }
                
                # Find the absolute path
                $resolvedDatabasePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                # Craft a connection string
                $sqlConnection = New-Object Data.Sqlite.SqliteConnection "Data Source=$resolvedDatabasePath"
                # Open the DB
                $sqlConnection.Open()
                
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
                # We're using SQL server (or SQL Azure), just use the connection string we've got
                $sqlConnection = New-Object Data.SqlClient.SqlConnection "$connectionString"
                # Open the DB
                $sqlConnection.Open()
            }
            

        }
        #endregion If we're not just going to output SQL, we might as well connect
        
        
        #region Determine the "real" type of foreign keys  
        $ForeignDataTypes = @{}
        if ($ForeignKey.Count) {
            foreach ($kv in $ForeignKey.GetEnumerator()) {
                $v = $kv.Value 
                $chunks = @($v -split "[\(\)]")
                $foreignTable = $chunks[0]
                $foreignRef = $chunks[1]
                $foreignColumn = Select-SQL "select * from information_schema.columns where column_Name = '$ForeignRef' and table_name = '$foreignTable'"
                
                if ($foreignColumn.Data_Type -ne 'char') {
                    $ForeignDataTypes[$kv.Key] = $foreignColumn.Data_Type
                } else {
                    $ForeignDataTypes[$kv.Key] = "char($($foreignColumn.CHARACTER_MAXIMUM_LENGTH))"
                }

                
                $null = $null
            }
        }
        #endregion Determine the "real" type of foreign keys  
    }

    process {
        $sqlParams = @{} + $psboundparameters
        foreach ($k in @($sqlParams.Keys)) {
            if ('SqlCompactPath', 'UseSqlCompact', 'SqlitePath', 'UseSqlite', 'UseMySql', 'MySqlPath', 'DatabasePath', 'ConnectionStringOrSetting' -notcontains $k) {
                $sqlParams.Remove($k)
            }
        }                

        $columnsAndTypes = New-Object Collections.ArrayList
        $rowKeySqlType = if ($KeyType -ne 'Sequential') {
            if ($useSqlLite) {
                "nchar($StringKeyLength)"
            } elseif ($useSqlCompact) {
                "nchar($StringKeyLength)"
            } else {
                "char($StringKeyLength)"
            }
        } else {
            if ($UseSQLite) {
                "integer"
            } else {
                "bigint"
            }
            
        }
        $autoIncrement = $(if ($KeyType -eq 'Sequential') { 
            if ($UseSQLite) {
                "PRIMARY KEY" 
            } else {
                "PRIMARY KEY IDENTITY"  
            }
            
        } else {
            ""
        })
        if ($UseMySql) {            
            $null = $columnsAndTypes.Add("$RowKey $rowKeySqlType NOT NULL $(if ($KeyType -eq 'Sequential') { 'AUTO_INCREMENT' })")
        } else {            
            $null = $columnsAndTypes.Add("$RowKey $rowKeySqlType NOT NULL $autoIncrement $(if (-not $autoIncrement) { "PRIMARY KEY"})")
        }
        
        $null = $columnsAndTypes.AddRange(@(
            for($i =0; $i -lt $Column.Count; $i++) {
                $columnName = $Column[$i]
                $columnDataType = 
                    if ($dataType -and $DataType[$i]) {
                        $datatype[$i]
                    } else {
                        if ($UseSQLite) {
                            "text"
                        } elseif ($useSqlCompact) {
                            "ntext"
                        } elseif ($useMySql) {
                            "longtext"
                        } else {
                            "varchar(max)"
                        }
                    }

                if ($ForeignKey[$column[$i]]) {
                    "$columnName $($ForeignDataTypes[$Column[$i]]) FOREIGN KEY References $($ForeignKey[$Column[$i]])"    
                    $null = $null
                } elseif ($Default[$column[$i]]) {
                    $defaultVal = 
                        if ($Default[$column[$i]] -is [string]) {
                            "'$($Default[$column[$i]].Replace("'","''"))'"
                        } else {
                            "$($Default[$column[$i]])"
                        }
                    "$columnName $columnDataType DEFAULT $defaultVal"
                } else {
                    "$columnName $columnDataType"
                }
                
                
                
            }))

        if ($UseMySql) {
            $null = $columnsAndTypes.Add("PRIMARY KEY($RowKey)")
        }

        $createstatement = "CREATE TABLE $tableName (
    $($ColumnsAndTypes -join (',' + [Environment]::NewLine + "   "))
)"                
        
        $sqlStatement = $createstatement
        if ($outputSql) {
            # If we're outputting SQL, just output it and be done
            $sqlStatement
        } elseif (-not $outputSql -and $psCmdlet.ShouldProcess($sqlStatement)) {
            # If we're not, be so nice as to use ShouldProcess first to confirm
            Write-Verbose "$sqlStatement"
            #region Execute SQL Statement

            $shouldTryAlterInstead = $false


            do {
                if ($shouldTryAlterInstead) {
                    $shouldTryAlterInstead = $false
                } 
                if ($UseSQLCompact) {
                    $sqlAdapter = New-Object "Data.SqlServerCE.SqlCeDataAdapter" $sqlStatement, $sqlConnection
                    $dataSet = New-Object Data.DataSet
                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)                        
                    } catch  {
                        $ex = $_
                    
                        if ($ex.Exception.InnerException.HResult -eq 0x80040e3f) {
                            # Table already exists.   If  they've provided -Force, alter it
                            $shouldTryAlterInstead = $true
                           
                        } else {
                            Write-Error $ex
                            $shouldTryAlterInstead = $false
                        }
                    
                    }
                
                } elseif ($UseSQLite) {
                    $sqlAdapter = New-Object Data.Sqlite.SqliteDataAdapter $sqlStatement, $sqlConnection
                    $dataSet = New-Object Data.DataSet
                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    } catch  {
                        $ex = $_
                    
                        if ($ex.Exception.InnerException.ErrorCode -eq 1) {
                            # Table already exists.   If  they've provided -Force, alter it
                            $shouldTryAlterInstead = $true
                        } else {
                            Write-Error $ex
                            $shouldTryAlterInstead = $false
                        }
                    
                    }
                } elseif ($usemySql) {
                    $sqlAdapter= New-Object "MySql.Data.MySqlClient.MySqlDataAdapter" ($sqlStatement, $sqlConnection)
                    $sqlAdapter.SelectCommand.CommandTimeout = 0
                    $dataSet = New-Object Data.DataSet
                        

                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    } catch  {
                        $ex = $_
                    
                        if ($ex.Exception.InnerException.Number -eq 0x41a) {
                            # Table already exists.   If  they've provided -Force, alter it
                            $shouldTryAlterInstead = $true                               
                        } else {
                            Write-Error $ex
                            $shouldTryAlterInstead = $false
                        }
                    
                    }
                } else {
                    $sqlAdapter= New-Object "Data.SqlClient.SqlDataAdapter" ($sqlStatement, $sqlConnection)
                    $sqlAdapter.SelectCommand.CommandTimeout = 0
                    $dataSet = New-Object Data.DataSet

                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    } catch  {
                        $ex = $_
                    
                        if (@($ex.Exception.InnerException.Errors)[0].number -eq 2714) {
                            # Object already exists.                               
                            $shouldTryAlterInstead = $true                               
                        } else {
                            Write-Error $ex
                            $shouldTryAlterInstead = $false
                        }
                        $null = $null                    
                    }

                }
                

                


                if ($shouldTryAlterInstead) {
                    if (-not $Force) {
                        $shouldTryAlterInstead = $false
                    }

                    $existingTable = Get-SQLTable -TableName $TableName @sqlParams
                    $missingColumns = foreach ($c in $Column) {
                        if ($existingTable.Columns -notcontains $c) {
                            $c
                        }
                    }


                    if (-not $missingColumns) {
                        $shouldTryAlterInstead = $false
                    }

                    $sqlStatement = 
                        @(foreach ($mc in $missingColumns) {                            
                            $i = $Column.IndexOf($mc)
                            $columnName = $Column[$i]
                            $columnDataType = if ($dataType -and $DataType[$i]) {
                                $datatype[$i]
                            } else {
                                if ($UseSQLite) {
                                    "text"
                                } elseif ($useSqlCompact) {
                                    "ntext"
                                } elseif ($useMySql) {
                                    "longtext"
                                } else {
                                    "varchar(max)"
                                }
                            }
                            $AlterExtra = if ($ForeignKey[$column[$i]]) {
                                "$columnName $($ForeignDataTypes[$Column[$i]]) FOREIGN KEY References $($ForeignKey[$Column[$i]])"    
                                $null = $null
                            } elseif ($Default[$column[$i]] -ne $null) {
                                $defaultVal = 
                                    if ($Default[$column[$i]] -is [string]) {
                                        "'$($Default[$column[$i]].Replace("'","''"))'"
                                    } else {
                                        "$($Default[$column[$i]])"
                                    }
                                "$columnName $columnDataType DEFAULT $defaultVal"
                            } else {
                                "$columnName $columnDataType"
                            }


                            "ALTER TABLE $TableName ADD $AlterExtra"
                        }) -join ([Environment]::NewLine)           
                        
                    if ($sqlStatement) {                        
                        Write-Verbose "Trying ALTER: $sqlStatement"
                    }
                }
                Write-Verbose "$rowCount results from last SQL statement"
            } while ($shouldTryAlterInstead)

            
            #endregion Execute SQL Statement                                            
        }
    }

    end {
         
        #region If a SQL connection exists, close it and Dispose of it
        if ($sqlConnection) {
            $sqlConnection.Close()
            $sqlConnection.Dispose()
        }
        #endregion If a SQL connection exists, close it and Dispose of it
        
    }
}
