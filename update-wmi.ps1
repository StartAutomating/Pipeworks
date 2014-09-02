function Update-Wmi
{
    <#
    .Synopsis
        Stores data in WMI
    .Description
        Stores data in the WMI repository
    .Link
        Select-Wmi
    .Example
        Get-ChildItem | 
            Select-Object Name, LastWriteTime, LastAccessTime, CreationTime | 
            Update-Wmi
    #>
    [OutputType([Nullable])]
    param(
    # Any input object
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [PSObject]
    $InputObject,

    # The namespace the object will be stored in
    [string]
    $Namespace = "root\custom\data",

    # The name of the class.  If not provided, the ClassName will be taken from the object.  Illegal characters in WMI class names (like ., :, or /) will be converted into _dot_, _colon_, and _slash_ respectively.
    [string]
    $ClassName,

    # At least one property must be registered as a key
    [Parameter(Mandatory=$true,Position=0)]
    [string[]]
    $Key,

    # If set, will update existing instances.  If not set, only new data will be added.
    [Switch]
    $Force
    )


    begin {
        #region Translate column types into CIM column types
        $cimColumnType = {
            if ($columnType -and $columnType[$prop.Name]) {
                $columnType[$prop.Name]
            } elseif ($prop.Value) {
                if ($prop.Value -is [String]) {
                    [Management.CimType]::String                            
                } elseif ($prop.Value -is [Byte]) {
                    [Management.CimType]::Char16
                } elseif ($prop.Value -is [Int16]) {
                    [Management.CimType]::SInt16
                } elseif ($prop.Value -is [Int]) {
                    [Management.CimType]::SInt32
                } elseif ($Prop.Value -is [Double]) {
                    [Management.CimType]::Real32
                } elseif ($prop.Value -is [Long]) {
                    [Management.CimType]::SInt64
                } elseif ($prop.Value -is [DateTime]) {
                    [Management.CimType]::DateTime
                } elseif ($prop.Value -is [Switch] -or $prop.Value -is [Bool]) {
                    [Management.CimType]::Boolean
                } else {
                    [Management.CimType]::String
                }

            } else {
                [Management.CimType]::String
            }
        }
        #endregion Translate column types into CIM column types

        #region Escape unsafe class names
        $getSafeClassName = {
        
            $cn = $ClassName.Replace(" ", "_space_").Replace("." ,"_dot_").Replace(":", "_colon_").Replace("/", "_slash_").Replace("#", "_pound_")            


            if ($(try { [uint32]::Parse($cn[0]) } catch {})) {
                "Number" + $cn
            } else {
                $cn
            }
        }
        #endregion Escape unsafe class names


        #region Create the namespace if it doesn't yet exist
        $namespacesToMake = New-Object Collections.Stack
        $originalNamespace = $Namespace
        do {
            $temprootNamespace = $Namespace | Split-Path 
            $leafName = $Namespace | Split-Path -Leaf

            if (-not $temprootNamespace) {
                $temprootNamespace = "root"
            }
        
            $namespaceExists = Get-WmiObject -Query "Select * from __namespace Where Name ='$leafName'" -Namespace $temprootNamespace  -ErrorAction SilentlyContinue
            if (-not $namespaceExists) {
                $null = $namespacesToMake.Push($leafName)
            } else {
                break
            }
            
            $Namespace = $temprootNamespace 
            $rootNamespace = $temprootNamespace

            if ($Namespace -eq 'root') {
                break
            }
        } while (-not $namespaceExists)
        

        $namespace= $originalNamespace


        foreach ($namespace in $namespacesToMake) {
            if (-not $Namespace) {continue}
            $mp = New-Object Management.ManagementPath
            $mp.NamespacePath = "$rootNamespace"  
            $mp.ClassName = "__namespace"
            $namespaceClass = New-Object Management.ManagementClass $mp
            $newNamespace = $namespaceClass.CreateInstance()
            $newNamespace.Name = $Namespace
            $null = $newNamespace.put()
            $rootNamespace = $rootNamespace + "\" + $Namespace
        }
        #endregion Create the namespace if it doesn't yet exist
    }
    


    process {
        
        if (-not $PSBoundParameters.Classname) {
            $ClassName = $InputObject.pstypenames[0]
        }

        

        $classPath = New-Object Management.ManagementPath
        $classPath.NamespacePath = $originalNamespace
        $classPath.ClassName = . $getSafeClassName


        $classDef = New-Object Management.ManagementClass $classPath

        $classDefExists = $(try { $classDef | Get-Member -ErrorAction SilentlyContinue } catch {}) -ne $null

        if (-not $classDefExists) {
            $classDef = New-Object Management.ManagementClass $originalNamespace, "", $null
            $classDef["__Class"] = . $getSafeClassName

            
            if ($InputObject -is [string]) {
                
            } else {
                
                foreach ($prop in $InputObject.PSObject.Properties) {
                    if ($prop.Name -like "__*") { continue }
                    $cimType = . $cimColumnType 
                    $classDef.Properties.Add($prop.Name, $cimType, $false)

                    if ($key -contains $prop.Name) {
                        $classDef.Properties[$prop.Name].Qualifiers.Add("Key", $true)
                    }
                }
                $null = $classDef.Put()
            }
        } else {
            $instances = $null
            foreach ($prop in $InputObject.PSObject.Properties ) {
                if ($prop.Name -like "__*") { continue }
                if ($prop.MemberType -eq 'AliasProperty') { continue } 
                $automaticPropertiesToIgnore = 'Scope',
                    'Path','Options',
                    'ClassPath', 'Properties','SystemProperties','Qualifiers','Site','Container'
                if ($InputObject -is [wmi] -and $automaticPropertiesToIgnore -contains $prop.Name) {
                    continue    
                }

                if ('PSComputerName', 'PSShowComputerName', 'RunspaceID' -contains $prop.Name) {
                    continue
                } 
                
                $cimType = . $cimColumnType 
                $propExists = $classDef.Properties[$prop.Name]

                if (-not $propExists) {
                    if (-not $instances) {
                        $instances = Get-WmiObject -Namespace $originalNamespace -Class (. $getSafeClassName)    
                    }
                    $classDef.Properties.Add($prop.Name, $cimType, $false)
                }

                if ($key -contains $prop.Name) {
                    if (-not $classDef.Properties[$prop.Name].Qualifiers["Key"]) {
                        $classDef.Properties[$prop.Name].Qualifiers.Add("Key", $true)
                    }
                }
                
            }
            
            if ($instances) {
                # Class definition changed.  Rebuild objects.  Ugh.
                $instanceProperties = $instances  | 
                    Get-Member -MemberType Property |                     
                    Where-Object { $_.Name -notlike "__*" }   

                $instances | Remove-WmiObject 
                $classPath = New-Object Management.ManagementPath
                $classPath.NamespacePath = $originalNamespace
                $classPath.ClassName = . $getSafeClassName


                $cdef = New-Object Management.ManagementClass $classPath
                $null = $cdef.Delete()
                foreach ($ip in $instanceProperties) {
                    if (-not $classDef.Properties[$ip.Name]) {
                        
                        
                        $classDef.Properties.Add($ip.Name, [Management.CimType]::String, $false)
                    }
                }

                
                $null = $classDef.Put();
                $instances | Update-Wmi -Namespace $originalNamespace -ClassName (. $getSafeClassName) -Key $key                  
            }
        }


        $where = @(foreach ($k in $key) {
            "$k = '$("$($inputObject.$k)".Replace("'","''"))'"
        }) -join ' AND '

        $instanceExists = Get-WmiObject -Class $classDef["__Class"] -Namespace $originalNamespace -Filter $where


        if ($instanceExists -and -not $force) {
            return
        }
        
        if ($force -and $instanceExists) {
            foreach ($prop in $InputObject.PSObject.Properties) {
                $instanceExists.($prop.Name) = 
                    if ($prop.Value -is [DateTime]) {
                        [Management.ManagementDateTimeConverter]::ToDmtfDateTime($prop.Value)
                    } else {
                        $prop.Value
                    }
                    
            }
            $null = $instanceExists.Put()
            
        } else {
            $classInstance = $classDef.CreateInstance()
            foreach ($prop in $InputObject.PSObject.Properties) {
                if ($prop.Name -like "__*") { continue }
                if ($prop.MemberType -eq 'AliasProperty') { continue } 
                $automaticPropertiesToIgnore = 'Scope',
                    'Path','Options',
                    'ClassPath', 'Properties','SystemProperties','Qualifiers','Site','Container'
                if ($InputObject -is [wmi] -and $automaticPropertiesToIgnore -contains $prop.Name) {
                    continue    
                }
                if ('PSComputerName', 'PSShowComputerName', 'RunspaceID' -contains $prop.Name) {
                    continue
                }
                $classInstance.($prop.Name) = 
                    if ($prop.Value -is [DateTime]) {
                        [Management.ManagementDateTimeConverter]::ToDmtfDateTime($prop.Value)
                    } else {
                        $prop.Value
                    }
            }
            $null = $classInstance.Put()
        } 

        
    }
}