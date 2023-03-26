function Select-Datatable
{
    <#
    .Synopsis
        Selects data from an in-memory database
    .Description
        Selects data from System.Data.Datatable, which is an in-memory database
    .Example
        $dt = dir | Select Name, LastWriteTime, LastAccessTime, CreationTime |  ConvertTo-DataTable 
        Select-DataTable -DataTable $dt -Sort LastWriteTime -SortOrder Descending
    .Link
        Update-DataTable
    .Link
        New-DataTable
    .Link
        ConvertTo-DataTable
    .Link
        Export-DataTable
    .Link
        Import-DataTable
    #>
    [OutputType([Data.DataRow])]
    param(
    # The datatable object
    [Parameter(Mandatory=$true,Position=0)]
    [Data.DataTable]
    $DataTable,

    # The condition.  This can contain any normal SQL operators
    [Parameter(Position=1,ValueFromPipelineByPropertyName=$true)]
    [string]
    $Where,

    # The sort order
    [Parameter(Position=2,ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $Sort,

    # The type of sort, either ascending or descding
    [Parameter(Position=3,ValueFromPipelineByPropertyName=$true)]
    [ValidateSet("A", "Asc", "Ascending", "D", "Desc","Descending")]
    [string[]]
    $SortOrder,

    # The typename to attach to output of the datatable.  This allows you to customize how the objects will be displayed in PowerShell.
    [Parameter(Position=4, ValueFromPipelineByPropertyName=$true)]
    [string[]]$TypeName
    )

    process {
        $realSort = if ($Sort) {

            @(for ($i =0; $i -lt $sort.count; $i++) {
                $s = $sort[$i]
                if ($i -lt $SortOrder.Count) {
                    if ($SortOrder[$i].StartsWith("A")) {
                        "$s ASC"
                    } elseif ($SortOrder[$i].StartsWith("D")) {
                        "$s DESC"
                    }
                } else {
                    "$s"
                }
            }) -join ' ' 
        }
        
        if ($realSort) {
            if ($TypeName) {
                foreach ($o in $DataTable.Select($Where, $realSort)) {
                    $o.pstypenames.clear()
                    foreach ($tn in $TypeName) {
                        $o.pstypenames.add($tn)
                    }
                    $o
                }
            } else {
                $DataTable.Select($Where, $realSort)
            }
            
            
        } else {
            if ($TypeName) {
                foreach ($o in $DataTable.Select($Where)) {
                    $o.pstypenames.clear()
                    foreach ($tn in $TypeName) {
                        $o.pstypenames.add($tn)
                    }
                    $o
                }
            } else {
                $DataTable.Select($Where)
            }
            
            
        }
    }
}  
