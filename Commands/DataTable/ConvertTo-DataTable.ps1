function ConvertTo-DataTable
{
    <# 
    .Synopsis
        Creates a DataTable from an object 
    .Description
        Creates a DataTable from an object, containing all properties (except built-in properties from a database)
    .Example
        Get-ChildItem| Select Name, LastWriteTime | ConvertTo-DataTable 
    .Link
        Select-DataTable
    .Link
        Import-DataTable
    .Link
        Export-Datatable
    #> 
    [OutputType([Data.DataTable])]
    param(
    # The input objects
    [Parameter(Position=0, Mandatory=$true, ValueFromPipeline = $true)]
    [PSObject[]]
    $InputObject
    ) 
 
    begin {
        #region Initialization 
        $outputDataTable = [Data.datatable]::new()
        $simpleTypes = ('System.Boolean', 'System.Byte[]', 'System.Byte', 'System.Char', 'System.Datetime', 'System.Decimal', 'System.Double', 'System.Guid', 'System.Int16', 'System.Int32', 'System.Int64', 'System.Single', 'System.UInt16', 'System.UInt32', 'System.UInt64')

        $SimpletypeLookup = @{}
        foreach ($s in $simpleTypes) {
            $SimpletypeLookup[$s] = $s
        }
        $DataRowProperties = 'RowError', 'RowState', 'Table', 'ItemArray', 'HasErrors'
        #endregion Initialization
    } 

    process {                        
        foreach ($In in $InputObject) { 
            $DataRow = $outputDataTable.NewRow()   
            $isDataRow = $in.psobject.TypeNames -contains 'System.Data.DataRow'
            
            foreach($property in $In.PsObject.properties) {   
                if ($isDataRow -and $DataRowProperties -contains $property.Name) {
                    continue     
                }
                $propName = $property.Name
                $propValue = $property.Value
                $IsSimpleType = $SimpletypeLookup.ContainsKey($property.TypeNameOfValue)

                if (-not $outputDataTable.Columns.Contains($propName)) {   
                    $outputDataTable.Columns.Add((
                        New-Object Data.DataColumn -Property @{
                            ColumnName = $propName
                            DataType = if ($issimpleType) {
                                $property.TypeNameOfValue
                            } else {
                                'System.Object'
                            }
                        }
                    ))
                }                   
                
                $DataRow.Item($propName) = 
                    if ($isSimpleType -and $propValue) {
                        $propValue
                    } elseif ($propValue) {
                        [PSObject]$propValue
                    } else {
                        [DBNull]::Value
                    }
                
            }   
            $outputDataTable.Rows.Add($DataRow)   
        }         
    }  
      
    end { 
        ,$outputDataTable
    }  
}
