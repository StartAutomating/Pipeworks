﻿function Remove-SQL
{
    <#
    .Synopsis
        Removes SQL data
    .Description
        Removes SQL data or databases
    .Example
        Remove-Sql -TableName ATable -ConnectionSetting SqlAzureConnectionString
    .Example
        Remove-Sql -TableName ATable -Where 'RowKey = 1' -ConnectionSetting SqlAzureConnectionString        
    .Example
        Remove-Sql -TableName ATable -Clear -ConnectionSetting SqlAzureConnectionString        
    .Link
        Add-SqlTable
    .Link
        Update-SQL
    #>
    [CmdletBinding(DefaultParameterSetName='DropTable',SupportsShouldProcess=$true,ConfirmImpact='High')]
    [OutputType([nullable])]
    param(
    # The table containing SQL results
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true)]
    [Alias('Table','From', 'Table_Name', 'FromTable')]
    [string]$TableName,


    # The where clause.  Beware:  different SQL engines treat this differently.  For instance, SQL server Compact requires the format:
    # ([RowName] = 'Value')
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='DeleteRows')]
    [string]$Where,

    # The set of specific rows to be deleted
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='DeleteRowBatch')]
    [string[]]$WhereIn,

    # The name of the properties 
    [Parameter(Mandatory=$true,Position=2,ValueFromPipelineByPropertyName=$true,ParameterSetName='DeleteRowBatch')]
    [string]$PropertyName,

    # A column name that will be dropped from the table.
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='DeleteColumns')]
    [Alias('Columns')]
    [string[]]$Column,

    # If set, will clear the table's contents, but will not remove the table.
    [Parameter(Mandatory=$true,Position=1,ValueFromPipelineByPropertyName=$true,ParameterSetName='ClearTable')]
    [Switch]$Clear,

    # A connection string or setting.    
    [Alias('ConnectionString', 'ConnectionSetting')]
    [string]$ConnectionStringOrSetting,

    # The name of the SQL server.  This is used with a database name to craft a connection string to SQL server
    [string]
    $Server,

    # The database on a SQL server.  This is used with the server name to craft a connection string to SQL server
    [string]
    $Database,

    # If set, will output the SQL, instead of executing the remove.
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
    
    # The path to SQL Lite.  If not provided, SQL compact will be loaded from Program Files    
    [string]
    $SqlitePath,
    
    # The path to a SQL compact or SQL lite database    
    [Alias('DBPath')]
    [string]
    $DatabasePath,

    # If set, will use MySql to connect to the database        
    [Switch]
    $UseMySql,
    
    # The path to MySql's .NET connector.  If not provided, MySql will be loaded from Program Files            
    [string]    
    $MySqlPath
    )

    begin {
        #region Resolve Connection String
        if ($PSBoundParameters.ConnectionStringOrSetting) {
            if ($ConnectionStringOrSetting -notlike "*;*") {
                $ConnectionString = Get-SecureSetting -Name $ConnectionStringOrSetting -ValueOnly
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
                
            }elseif ($useMySql) {
                if (-not ('MySql.Data.MySqlClient.MySqlConnection' -as [type])) {
                    $asm = 
                        if (-not $mySqlPath) {
                            [Reflection.Assembly]::LoadWithPartialName('MySql.Data')
                        } else {
                            [Reflection.Assembly]::LoadFrom($MySqlPath)
                        }    
                    $null = $asm
                    
                }
                $sqlConnection = New-Object MySql.Data.MySqlClient.MySqlConnection "$ConnectionString"
                $sqlConnection.Open()
            }  else {
                # We're using SQL server (or SQL Azure), just use the connection string we've got
                $sqlConnection = New-Object Data.SqlClient.SqlConnection "$connectionString"
                # Open the DB
                $sqlConnection.Open()
            }
            

        }
        #endregion If we're not just going to output SQL, we might as well connect
    }

    process {
        if ($TableName -and $where) {
            # If we know a table and a where clause, craft the SQL
            $sqlStatement = "DELETE FROM $tableName WHERE $where".TrimEnd("\").TrimEnd("/")
        } elseif ($clear) {
            # If we're going to clear the table..
            $sqlStatement = if ($UseSQLCompact -or $UseSQLite) {
                # Use DELETE FROM on SqlCompact or SqLite                                            
                "DELETE FROM $tableName"
            } else { 
                # Use Truncate Table on SQL Server
                "TRUNCATE TABLE $tableName"
            }
                                    
        } elseif ($tableName -and $wherein -and $PropertyName) {
            
            # We're deleting a batch of items, use WHERE ... IN                         
            $sqlStatement = 
                "DELETE FROM $TableName WHERE $PropertyName IN ('$(($WhereIn | 
                    Foreach-Object { 
                        $_.Replace("'", "''") 
                    })-join "','")')"
            
        } elseif ($column) {
            # We're dropping a column
            $sqlStatement = @(foreach ($c in $column) {
                "ALTER TABLE $TableName DROP COLUMN $c"
            }) -join ([Environment]::NewLine)

        } else {
            
            # We're removing the whole table, use DROP TABLE
            $sqlStatement = "DROP TABLE $tableName"
        }

        if ($outputSql) {
            # If we're outputting SQL, just output it and be done
            $sqlStatement
        } elseif (-not $outputSql -and $psCmdlet.ShouldProcess($sqlStatement)) {
            # If we're not, be so nice as to use ShouldProcess first to confirm
            Write-Verbose "$sqlStatement"
            #region Execute SQL Statement
            if ($UseSQLCompact) {
                $sqlAdapter = New-Object "Data.SqlServerCE.SqlCeDataAdapter" $sqlStatement, $sqlConnection
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            } elseif ($UseSQLite) {
                $sqliteCmd = New-Object Data.Sqlite.SqliteCommand $sqlStatement, $sqlConnection
                $rowCount = $sqliteCmd.ExecuteNonQuery()
            } elseif ($useMySql) {
                $sqlAdapter= New-Object "MySql.Data.MySqlClient.MySqlDataAdapter" ($sqlStatement, $sqlConnection)
                $sqlAdapter.SelectCommand.CommandTimeout = 0
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            } else {
                $sqlAdapter= New-Object "Data.SqlClient.SqlDataAdapter" ($sqlStatement, $sqlConnection)
                $sqlAdapter.SelectCommand.CommandTimeout = 0
                $dataSet = New-Object Data.DataSet
                $rowCount = $sqlAdapter.Fill($dataSet)
            }
            Write-Verbose "$rowCount rows dropped or altered"
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
 
