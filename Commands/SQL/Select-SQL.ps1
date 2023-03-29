function Select-SQL
{
    <#
    .Synopsis
        Select SQL data
    .Description
        Select data from a SQL databsae
    .Example
        Select-Sql -FromTable ATable -Property Name, Day, Month, Year -Where "Year = 2005" -ConnectionSetting SqlAzureConnectionString
    .Example
        Select-Sql -FromTable INFORMATION_SCHEMA.TABLES -ConnectionSetting SqlAzureConnectionString -Property Table_Name -verbose
    .Example
        Select-Sql -FromTable INFORMATION_SCHEMA.TABLES -ConnectionSetting "Data Source=$env:ComputerName;Initial Catalog=Master;Integrated Security=SSPI;" -Property Table_Name -verbose
    .Example
        Select-Sql "
    SELECT  sys.objects.name,
            SUM(row_count) AS 'Row Count',
            SUM(reserved_page_count) * 8.0 / 1024 AS 'Table Size (MB)'
    FROM sys.dm_db_partition_stats, sys.objects
    WHERE sys.dm_db_partition_stats.object_id = sys.objects.object_id
    GROUP BY sys.objects.name
    ORDER BY [Table Size (MB)] DESC
"
    .Link
        Add-SqlTable
    .Link
        Update-SQL

    #>
    [CmdletBinding(DefaultParameterSetName='SQLQuery')]
    [OutputType([PSObject], [Hashtable], [Data.DataRow])]
    param(
    # The table containing SQL results
    [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName,ParameterSetName='SQLQuery')]    
    [Alias('SQL')]
    [string]$Query,

    # A dictionary of parameters.  If provided, these parameters can be used in the SQL statement
    [Parameter(ValueFromPipelineByPropertyName)]
    [Collections.IDictionary]
    $Parameter = @{},

    # The path to a SQL file
    [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='SQLFile')]    
    [Alias('Fullname')]
    [string]$SqlFile,

    # The table containing SQL results
    [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [Alias('Table','From', 'TableName')]
    [string]$FromTable,

        # If set, will only return unique values.  This corresponds to the DISTINCT SQL qualifier.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [Alias('Unique')]
    [Switch]$Distinct,

    # The properties to pull from SQL. If not set, all properties (*) will be returned
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [string[]]$Property,

    # The number of items to return
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [Alias('First')]
    [Uint32]$Top,

    # The offset for the items (only supported in SQL server)
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [Alias('Skip')]
    [Uint32]$Offset,

    # The sort order of the returned objects
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [Alias('Sort')]
    [string[]]$OrderBy,

    # If set, sorted items will be returned in descending order.  By default, if items are sorted, they will be in ascending order.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [Switch]$Descending,

    # The where clause.
    [Parameter(ValueFromPipelineByPropertyName,ParameterSetName='SimpleSQL')]
    [string]$Where,

    # A connection string or setting.    
    [Alias('ConnectionString', 'ConnectionSetting')]
    [string]$ConnectionStringOrSetting,

    # The name of the SQL server.  This is used with a database name to craft a connection string to SQL server
    [string]
    $Server,

    # The database on a SQL server.  This is used with the server name to craft a connection string to SQL server
    [string]
    $Database,

    # If set, will output the SQL
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

    # The way the data will be outputted.  
    [ValidateSet("Hashtable", "Datatable", "DataSet", "PSObject" , "PropertyBag","Transform")]
    [string]
    $AsA = "PSObject",

    # If set, the select statement will be run as a dirty read.  
    # In SQL Server, this will be With (nolock).  
    # In MYSql, this will change the session options for the transaction to enable a dirty read.
    [Switch]
    $Dirty)

    begin {
        
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
        if (-not $ConnectionString -and -not ($UseSQLite -or $UseSQLCompact) -and $OutputSql) {
            throw "No Connection String"
            return
        }

        if (-not $OutputSQL) {
            if ($UseSQLCompact) {
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
            } elseif ($UseSqlite) {
                if (-not ('Data.Sqlite.SqliteConnection' -as [type])) {
                    if ($sqlitePath) {
                        $resolvedLitePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($sqlitePath)
                        $asm = [reflection.assembly]::LoadFrom($resolvedLitePath)
                    } else {
                        $asm = [Reflection.Assembly]::LoadFrom("$env:ProgramFiles\System.Data.SQLite\2010\bin\System.Data.SQLite.dll")
                    }
                    $null = $asm
                }
                
                
                $resolvedDbPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($DatabasePath)
                $sqlConnection = New-Object Data.Sqlite.SqliteConnection "Data Source=$resolvedDbPath"
                $sqlConnection.Open()
                
            } elseif ($useMySql) {
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
            }
            

        }
    }

    process {
        $dataSet = $null

        if ($PSCmdlet.ParameterSetName -eq 'SimpleSQL') {
            #region SimpleSQL - PowerShell friendly parameters that obscure some SQL complexity
            if (-not $Property) {
                $property = "*"
            }

            if ($property.Count -eq 1 -and $Property -eq '*') {
                $propString = '*' 
            } else {
                $propString = @(foreach ($p in $Property) {
                    if ($p -eq '*' -or $p -like "*(*)*" -or $p -match "['`"]\s{1,}AS") {
                        $p
                    } else {
                        "`"$p`""
                    }
                }) -join ','
            }
        
            # Very minor SQL injection prevention.  If this is your last line of defense, you're in trouble, but using this will keep you out of some trouble.
            if ($where.IndexOfAny(";$([Environment]::NewLine)`0`b`t".ToCharArray()) -ne -1) {
                Write-Error "The Where Statement doesn't look safe"
                return
            }


            $sqlStatement = "SELECT $(if ($Top -and -not $Offset) { "TOP $Top" } ) $(if ($Distinct) { 'DISTINCT ' }) $propString FROM $FromTable $(if ($Dirty) { 'with(noLock) '}) $(if ($Where) { "WHERE $where"}) $(if ($OrderBy) { "ORDER BY $($orderBy -join ',') $(if ($Descending) { 'DESC'})"}) $(if ($Offset) { " OFFSET $offset ROWS"; if ($Top) { " FETCH NEXT $top ROWS ONLY" } } )".TrimEnd("\").TrimEnd("/")
            Write-Verbose "$sqlStatement"
         
            #endregion SimpleSQL - PowerShell friendly parameters that obscure some SQL complexity
        } elseif ($PSCmdlet.ParameterSetName -eq 'SQLQuery') {
            $sqlStatement = $Query    
        } elseif ($PSCmdlet.ParameterSetName -eq 'SQLFile') {
            $resolvedPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($SqlFile)
            if (-not $resolvedPath) { return }
            $sqlStatement = [IO.File]::ReadAllText("$resolvedPath")
        }

        $sqlLines = $sqlStatement -split '(?>\r\n|\n)'
        $sqlStatements = @(
            $sqlBuffer = [Collections.Queue]::new()
            foreach ($sqlLine in $sqlLines) {
                if ($sqlLine -match '^\s{0,}GO\s{0,}$') {
                    $sqlBuffer.ToArray() -join [Environment]::Newline
                    $sqlBuffer.Clear()
                } else {
                    $sqlBuffer.Enqueue($sqlLine)
                }
            }
            if ($sqlBuffer.Count) {
                $sqlBuffer.ToArray() -join [Environment]::Newline
            }
        )

        foreach ($sqlStatement in $sqlStatements) {
            if ($Dirty) {
                if ($UseMySql) {
                    $sqlStatement = 
    "
    SET SESSION TRANSACTION ISOLATION LEVEL READ UNCOMMITTED ;
    $sqlStatement ;
    SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ ;
    "
                } 
            }
            $dataset = $null
            if ($OutputSql) {
                $sqlStatement
            } else {            
                if ($UseSQLCompact) {
                    $sqlAdapter= New-Object "Data.SqlServerCE.SqlCeDataAdapter" ($sqlStatement, $sqlConnection)
                    $sqlAdapter.SelectCommand.CommandTimeout = 0
                    foreach ($p in $Parameter.GetEnumerator()) {
                        $null = $sqlAdapter.SelectCommand.Parameters.Add($p.Key, $p.Value)
                    }
                    $dataSet = New-Object Data.DataSet
                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    }catch {
                        Write-Error $_
                        
                    }
                } elseif ($UseSQLite) {
                    $sqlAdapter= New-Object "Data.SQLite.SQLiteDataAdapter" ($sqlStatement, $sqlConnection)
                    $sqlAdapter.SelectCommand.CommandTimeout = 0
                    foreach ($p in $Parameter.GetEnumerator()) {
                        $null = $sqlAdapter.SelectCommand.Parameters.Add($p.Key, $p.Value)
                    }
                    $dataSet = New-Object Data.DataSet
                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    }catch {
                        Write-Error $_
                        
                    }
                } elseif ($UseMySql) {
                    $sqlAdapter= New-Object "MySql.Data.MySqlClient.MySqlDataAdapter" ($sqlStatement, $sqlConnection)
                    $sqlAdapter.SelectCommand.CommandTimeout = 0
                    foreach ($p in $Parameter.GetEnumerator()) {
                        $null = $sqlAdapter.SelectCommand.Parameters.Add($p.Key, $p.Value)
                    }
                    $dataSet = New-Object Data.DataSet
                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    }catch {
                        Write-Error $_
                        
                    }
                } else {
                    $sqlAdapter= New-Object "Data.SqlClient.SqlDataAdapter" ($sqlStatement, $sqlConnection)
                    $sqlAdapter.SelectCommand.CommandTimeout = 0
                    foreach ($p in $Parameter.GetEnumerator()) {
                        $null = $sqlAdapter.SelectCommand.Parameters.Add($p.Key, $p.Value)
                    }
                    $dataSet = New-Object Data.DataSet
                    try {
                        $rowCount = $sqlAdapter.Fill($dataSet)
                    }catch {
                        Write-Error $_
                        
                    }
                }
                
            }
    
            Write-Verbose "$rowCount Rows returned"
    
    
            if ($dataSet) {  
                $isUnix = $PSVersionTable.Platform -eq 'Unix'
                if ($AsA -eq 'DataSet') {
                    $dataSet
                } elseif ($AsA -eq 'DataTable') {
                    foreach ($t in $dataSet.Tables) {
                        ,$t
                    }
                } elseif ($AsA -eq 'PSObject') {                        
                    foreach ($t in $dataSet.Tables) {
                
                        foreach ($r in $t.Rows) {
                            $typename = "$($r.pstypename)"
                            if ($typename) {                    
                                $r.pstypenames.clear()
                                foreach ($tn in ($typename.Split("|", [stringsplitoptions]::RemoveEmptyEntries))) {
                                    if ($tn) {
                                        $r.pstypenames.add($tn)
                                    }
                                }
                            
                            }
                                                        
                            $null = $r.psobject.properties.Remove("pstypename")
    
                            $r
                    
                        }
                    }
                } elseif ($AsA -eq 'PropertyBag') {
                    foreach ($t in $dataSet.Tables) {
                        <#$avoidProperties = @{}
                        foreach ($pName in 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors', 'Count', 'Length', 'LongLength', 'Rank', 'SyncRoot', 'IsFixedSize', 'IsSynchronized', 'IsReadOnly', 'PSTypeName') {
                            $avoidProperties[$pName] = $true 
                        }#>
                        foreach ($r in $t.Rows) {
                            $typename = "$($r.pstypename)"
    
                            
                            
    
                           
    
                            $out = [ordered]@{}
                            
                            foreach ($prop in $r.psobject.Properties) {
                                
                                $out[$prop.Name] = $prop.Value
                            }                        
                            
                            foreach ($propName in 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors', 'Count', 'Length', 'LongLength', 'Rank', 'SyncRoot', 'IsFixedSize', 'IsSynchronized', 'IsReadOnly', 'PSTypeName') {
                                $out.Remove($propName)
                            }
                            $o = New-Object PSObject -Property $out
                            if ($typename) {                    
                                $o.pstypenames.clear()
                                foreach ($tn in ($typename.Split("|", [stringsplitoptions]::RemoveEmptyEntries))) {
                                    if ($tn) {
                                        $o.pstypenames.add($tn)
                                    }
                                }                        
                            }
    
                            
    
                            $o
                    
                        }
                    }
                } elseif ($AsA -eq 'Hashtable') {
                    $avoidProperties = @{}
                    foreach ($pName in 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors') {
                        $avoidProperties[$pName] = $true 
                    }
                    foreach ($t in $dataSet.Tables) {
                
                        foreach ($r in $t.Rows) {
                        
                            $out = @{}
                            
                            foreach ($prop in $r.psobject.Properties) {
                                if ($avoidProperties[$prop.Name]) {
                                    continue
                                }
                                $out[$prop.Name] = $prop.Value
                            }                        
                            
    
                            $out
                    
                        }
                    }
                } elseif ($AsA -eq 'Transform') {
                    #-AsA Transform is both interesting and potentially dangerous.
                    #-AsA transform will take a SQL object with a string column named name (or label) and a string column named expression
                    # They will then be returned as a Hashtable with the expression converted into a Powershell script block
                    # This can be used to store transforms for Select-Object within SQL (which is cool)
                    # It can also be used to directly inject PowerShell code stored in a SQL database (which is risky)
                    # Bottom line - Don't use -AsA Transform on user-generated tables
                    $avoidProperties = @{}
                    foreach ($pName in 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors') {
                        $avoidProperties[$pName] = $true 
                    }
                    foreach ($t in $dataSet.Tables) {            
                        foreach ($r in $t.Rows) {                    
                            $out = @{}
                            $out.Name = 
                                if ($r.Name) {
                                    $r.Name
                                } elseif ($r.Label) {
                                    $r.Label
                                }
                            $out.Expression = [ScriptBlock]::Create("$($r.Expression)")                                             
                            $out
                        }
                    }
                }
            }
        }
        
        

        
    }

    end {
        # Close the connection and dispose of it         
        if ($sqlConnection) {
            $sqlConnection.Close()
            $sqlConnection.Dispose()
        }        
    }
}
 
