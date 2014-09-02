function Get-Person
{
    <#
    .Synopsis
        Gets information about a person
    .Description
        Gets account information about a person.
        
        
        
        Get-Person contains the common tools to get user information from users on:
            - Active Directory
            - Azure Tables 
            - Facebook
            - Local Directory
    .Example
        Get-Person -UserTable SuppliUsUsers -Name "James Brundage" -UserPartition Users 
    .Example
        Get-Person -Local "James Brundage"
    .Link
        Confirm-Person
    #>
    [CmdletBinding(DefaultParameterSetName='Alias')]
    [OutputType('http://schema.org/Person')]
    param(
    # The account alias or UserID
    [Parameter(Mandatory=$true,
        ParameterSetName='Alias',
        ValueFromPipelineByPropertyName=$true)]
    [Alias('MailNickname', 'UserID', 'SamAccountName')]
    [string]$Alias,
    
    # If provided, will get a list of properties from the user
    [string[]]$Property,
    

    # If set, will look for local accounts
    [Switch]$IsLocalAccount,

    # The account name
    [Parameter(Mandatory=$true,
        ParameterSetName='Name',
        ValueFromPipelineByPropertyName=$true)]
    [string]$Name,

    # The name of the domain.  If provided, then Active Directory will not be queried for a list of domains.
    [string]$Domain,

    # The table in Azure that stores user information.  If provided, will search for accounts in Azure
    [string]$UserTable,
    
    # The parition within a table in Azure that should have user information.  Defaults to "Users"
    [string]$UserPartition = "Users",
    
    # The storage account.  If not provided, the StorageAccountSetting will be used
    [string]$StorageAccount,
    
    # The storage key.  If not provided, the StorageKeySetting will be used
    [string]$StorageKey,
    
    # The storage account setting.  This setting will be found with either Get-SecureSetting or Get-WebConfigurationSetting. Defaults to AzureStorageAccountName.
    [string]$StorageAccountSetting = "AzureStorageAccountName",
    
    # The storage key setting.  This setting will be found with either Get-SecureSetting or Get-WebConfigurationSetting.  Defaults to AzureStorageAccountKey
    [string]$StorageKeySetting = "AzureStorageAccountKey",
    
    # A facebook access token
    [Parameter(Mandatory=$true,ParameterSetName='FacebookAccessToken',ValueFromPipelineByPropertyName=$true)]

    [string]$FacebookAccessToken,


    # A Live ID Access Token
    [Parameter(Mandatory=$true,ParameterSetName='LiveIDAccessToken',ValueFromPipelineByPropertyName=$true)]
    [string]$LiveIDAccessToken,
    

    # A facebook user ID
    [Parameter(ParameterSetName='FacebookAccessToken',ValueFromPipelineByPropertyName=$true)]
    [Alias('ID')]
    [string]$FacebookUserID
    )

    begin {
        $beginProcessingEach = {
            $propertyMatch = @{}
            foreach ($prop in $property) {
                if (-not $prop) { continue } 
                $propertyMatch[$prop] = $prop
            }   
        }
        $processEach = {
            if ($OnlyBasicInfo) {
                $sortedKeys = "displayname", "Title,", "company", "department", "mail", "telephoneNumber", "physicaldeliveryofficename", "cn", "gn", "sn", "samaccountname", "thumbnailphoto" 
            } else {
                if ($in.Properties.Keys) {
                    $sortedKeys = $in.Properties.Keys | Sort-Object
                } elseif ($in.Properties.PropertyNames) {
                    $sortedKeys = $in.Properties.PropertyNames| Sort-Object                
                }
            }
            
            $personObject = New-Object PSObject
            $personObject.pstypenames.clear()
            $personObject.pstypenames.Add("http://schema.org/Person")           
            
            
            foreach ($s in $sortedKeys) {
                $unrolledValue = foreach($_ in $in.Properties.$s)  { $_} 
                $noteProperty = New-Object Management.Automation.PSNoteProperty $s, $unrolledValue
                if (-not $propertyMatch.Count) {
                    $null = $personObject.psObject.Properties.Add($noteProperty)                
                } elseif ($propertyMatch[$s]) {
                    $null = $personObject.psObject.Properties.Add($noteProperty)
                }
                
                #Add-Member -MemberType NoteProperty -InputObject $personObject -Name $s -Value $unrolledValue
            }
            
            $personObject
        }
    }

    process {
       
       if ($userTable -and $UserPartition) {
            $storageParameters = @{}
            if ($storageAccount) {
                $storageParameters['StorageAccount'] =$storageAccount
            } elseif ($storageAccountSetting) {
                if ((Get-SecureSetting "$storageAccountSetting" -ValueOnly)) {
                    $storageParameters['StorageAccount'] =(Get-SecureSetting "$storageAccountSetting" -ValueOnly)
                } elseif ((Get-WebConfigurationSetting -Setting "$storageAccountSetting")) {
                    $storageParameters['StorageAccount'] =(Get-WebConfigurationSetting -Setting "$storageAccountSetting")
                }
            }
            
            if ($storageKey) {
                $storageParameters['StorageKey'] =$storageKey
            } elseif ($StorageKeySetting) {
                if ((Get-SecureSetting "$storagekeySetting" -ValueOnly)) {
                    $storageParameters['Storagekey'] =(Get-SecureSetting "$storagekeySetting" -ValueOnly)
                } elseif ((Get-WebConfigurationSetting -Setting "$storagekeySetting")) {
                    $storageParameters['Storagekey'] =(Get-WebConfigurationSetting -Setting "$storagekeySetting")
                }
            }
        }
        
        
        
        $parameters= @{} + $psBoundParameters
        if ($pscmdlet.ParameterSetName -eq 'Alias') {
            
            if ($credential) {
                if (-not $exchangeserver) {
                    $exchangeServer = "http://ps.outlook.com/Exchange"
                }
            } elseif ($userTable -and $UserPartition) {                                                                
                Search-AzureTable @storageParameters -TableName $userTable -Filter "PartitionKey eq '$userPartition'" |
                    Where-Object { $_.UserEmail -eq $alias }            
            } elseif (((Get-WmiObject Win32_ComputerSystem).Domain -ne 'WORKGROUP') -and (-not $IsLocalAccount)) {
                if (-not $domain -and -not $script:DomainList) {
                    $script:DomainList= 
                        [DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Domains | 
                            Select-Object -ExpandProperty Name

                } elseif ($Domain) {
                    $script:DomainList = @($Domain)
                }         
                
                foreach ($d in $script:domainList) {
                    if (-not $d) { continue } 
                    $searcher = New-Object DirectoryServices.DirectorySearcher ([ADSI]"LDAP://$d")
                    
                    $searcher.Filter = "(&(objectCategory=person)(samaccountname=$alias))"
                    $searcher.SearchScope = "Subtree"
                    . $beginProcessingEach
                    foreach ($in in $searcher.FindAll()) {
                        . $processEach 
                    }
                }
                
            } else {                
                $all = 
                    ([ADSI]"WinNT://$env:computerName,computer").psbase.Children |
                        Where-Object {
                            $_.SchemaClassName -eq 'User'
                        }
                    
                $found= $all | 
                    Where-Object {                         
                        $_.Name -ieq $alias 
                    }
                    
                
                foreach ($in in $found) {
                    if ($in) {
                        $each = . $processEach

                        if ($each.Fullname) {
                            $each | 
                                Add-Member NoteProperty Name $each.FullName -Force
                        }

                        $each
                        
                            
                    }
                }                
            }            
        } elseif ($psCmdlet.ParameterSetName -eq 'Name') {
            if ($userTable -and $UserPartition) {
                Search-AzureTable @storageParameters -TableName $userTable -Filter "PartitionKey eq '$userPartition'" |
                    Where-Object { $_.Name -eq $name } 
                               
            
            } elseif (((Get-WmiObject Win32_ComputerSystem).Domain -ne 'WORKGROUP') -and (-not $IsLocalAccount)) {
                if (-not $script:DomainList) {
                    $script:DomainList= 
                        [DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Domains | 
                            Select-Object -ExpandProperty Name

                }         
                
                foreach ($d in $script:domainList) {
                    if (-not $d) { continue } 
                    $searcher = New-Object DirectoryServices.DirectorySearcher ([ADSI]"LDAP://$d")
                    $searcher.Filter = "(&(objectCategory=person)(cn=$Name))"
                    . $beginProcessingEach                    

                    foreach ($in in $searcher.Findall()) {
                        . $processEach
                    }
                }
            } else {
                $all = 
                    ([ADSI]"WinNT://$env:computerName,computer").psbase.Children | 
                    Where-Object { 
                        $_.SchemaClassName -eq 'User' -and 
                        $_.Name -eq $name
                    }
                    
                
                foreach ($in in $all) {
                    . $processEach 
                }
            }
        } elseif ($psCmdlet.ParameterSetName -eq 'FacebookAccessToken') {
            $facebookPerson =
                if ($faceboookUserId) {
                
                    Get-Web -Url "https://graph.facebook.com/$FacebookUserId" -AsJson -UseWebRequest   
                } else {

                    Get-Web -Url "https://graph.facebook.com/Me/?access_token=$FacebookAccessToken" -asjson -UseWebRequest
                }

            if (-not $facebookPerson) {
                # If at first you don't succeed, try, try again (because SOMETIMES on first boot, Get-Web barfs and then works)
                $facebookPerson =
                    if ($faceboookUserId) {
                
                        Get-Web -Url "https://graph.facebook.com/$FacebookUserId" -AsJson    
                    } else {

                        Get-Web -Url "https://graph.facebook.com/Me/?access_token=$FacebookAccessToken" -asjson 
                    }

            }
            
            if ($facebookPerson) {
                foreach ($property in @($facebookPerson.psobject.properties)) {
                    $value = $Property.Value
                    $changed = $false
                    if ($Value -is [string] -and $Value -like "*\u*") {
                        $value = [Regex]::Replace($property.Value, 
                            "\\u(\d{4,4})", { 
                            ("0x" + $args[0].Groups[1].Value) -as [Uint32] -as [Char]
                        })
                        $changed = $true
                    }
                    if ($Value -is [string] -and $Value -like "*\r\n*") {
                        $value = [Regex]::Replace($property.Value, 
                            "\\r\\n", [Environment]::NewLine)
                        $changed = $true
                    }


                    if ($changed) {
                        Add-Member -inputObject $facebookPerson NoteProperty $property.Name -Value $value -Force
                    }
                }
                

                $facebookPerson | Add-Member AliasProperty FacebookID ID 
                $facebookPerson.pstypenames.clear()
                $facebookPerson.pstypenames.add('http://schema.org/Person')
                $facebookPerson
            }
            
        } elseif ($psCmdlet.ParameterSetName -eq 'LiveIDAccessToken') {
            $liveIdPerson =                
                Get-Web -Url "https://apis.live.net/v5.0/me?access_token=$LiveIDAccessToken" -asjson -UseWebRequest
            
            if (-not $LiveIDPerson) {
                # If at first you don't succeed, try, try again (because SOMETIMES on first boot, Get-Web barfs and then works)
                $liveIdPerson =                
                    Get-Web -Url "https://apis.live.net/v5.0/me?access_token=$LiveIDAccessToken" -asjson 
            
            }    
            


            if ($liveIdPerson ) {
                foreach ($property in @($liveIdPerson.psobject.properties)) {
                    $value = $Property.Value
                    $changed = $false
                    if ($Value -is [string] -and $Value -like "*\u*") {
                        $value = [Regex]::Replace($property.Value, 
                            "\\u(\d{4,4})", { 
                            ("0x" + $args[0].Groups[1].Value) -as [Uint32] -as [Char]
                        })
                        $changed = $true
                    }
                    if ($Value -is [string] -and $Value -like "*\r\n*") {
                        $value = [Regex]::Replace($property.Value, 
                            "\\r\\n", [Environment]::NewLine)
                        $changed = $true
                    }


                    if ($changed) {
                        Add-Member -inputObject $liveIdPerson NoteProperty $property.Name -Value $value -Force
                    }
                }
                
                $liveIdPerson | Add-Member AliasProperty LiveID ID 
                $liveIdPerson.pstypenames.clear()
                $liveIdPerson.pstypenames.add('http://schema.org/Person')
                $liveIdPerson 
            }
            
        }
     
    }
}
