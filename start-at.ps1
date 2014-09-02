function Start-At
{
    <#
    .Synopsis
        Starts scripts at a time or event
    .Description
        Starts scripts at a time, an event, or a change in a table
    .Example
        Start-At -Boot -RepeatEvery "0:30:0" -Name LogTime -ScriptBlock {         
            "$(Get-Date)" | Set-Content "$($env:Public)\$(Get-Random).txt"

        }
    .Link
        Use-Schematic
    #>
    [CmdletBinding(DefaultParameterSetName='StartAtTime')]
    [OutputType([Nullable])]
    param(
    # The scriptblock that will be run
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ScriptBlock[]]$ScriptBlock,    
    
    # The time the script will start
    [Parameter(Mandatory=$true, ParameterSetName='StartAtTime')]
    [DateTime]$Time,

    # The event ID of interest
    [Parameter(Mandatory=$true, ParameterSetName='StartAtSystemEvent')]
    [Uint32]$EventId,

    # The event log where the eventID is found
    [Parameter(Mandatory=$true, ParameterSetName='StartAtSystemEvent')]
    [string]$EventLog,

    # The table name that contains data to process
    [Parameter(Mandatory=$true, ParameterSetName='StartAtTableData')]
    [Parameter(Mandatory=$true, ParameterSetName='StartAtSqlData')]
    [string]$TableName,

    # The name of the user table.  If an OwnerID is found on an object, and user is found in the a usertable, then the task will be run as that user 
    [Parameter(ParameterSetName='StartAtTableData')]
    [Parameter(ParameterSetName='StartAtSqlData')]
    [string]$UserTableName,

    # The filter used to scope queries for table data
    [Parameter(Mandatory=$true, ParameterSetName='StartAtTableData')]
    [string]$Filter,
    
    # The filter used to scope queries for table data
    [Parameter(Mandatory=$true, ParameterSetName='StartAtSQLData')]
    [string]$Where,

    # The name of the  setting containing the storage account
    [Parameter(ParameterSetName='StartAtTableData')]    
    [Parameter(ParameterSetName='StartAtSqlData')]
    [Parameter(ParameterSetName='StartAtNewEmail')]
    [string]$StorageAccountSetting = "AzureStorageAccountName",

    # The name of the setting containing the storage key
    [Parameter(ParameterSetName='StartAtTableData')]    
    [Parameter(ParameterSetName='StartAtSqlData')]
    [Parameter(ParameterSetName='StartAtNewEmail')]
    [string]$StorageKeySetting = "AzureStorageAccountKey",

    # Clears a property on the object when the item has been handled
    [Parameter(ParameterSetName='StartAtTableData')]    
    [string]$ClearProperty,

    # The name of the setting containing the email username
    [Parameter(ParameterSetName='StartAtNewEmail',Mandatory=$true)]
    [string]$EmailUserNameSetting,

    # The name of the setting containing the email password
    [Parameter(ParameterSetName='StartAtNewEmail',Mandatory=$true)]
    [string]$EmailPasswordSetting,

    # The display name of the inbox receiving the mail.
    [Parameter(ParameterSetName='StartAtNewEmail',Mandatory=$true)]
    [string]$SentTo,

    # The name of the setting containing the storage key
    [Parameter(ParameterSetName='StartAtSQLData')]    
    [string]$ConnectionStringSetting = "SqlAzureConnectionString",

    # The partition containing user information.  If the items in the table have an owner, then the will be run in an isolated account.
    [Parameter(ParameterSetName='StartAtTableData')]    
    [string]$UserPartition = "Users",

    # The timespan in between queries
    [Parameter(ParameterSetName='StartAtTableData')]
    [Parameter(ParameterSetName='StartAtSQLData')]
    [Parameter(ParameterSetName='StartAtNewEmail')]
    [Timespan]$CheckEvery = "0:15:0",

    # The timespan in between queries
    [Parameter(ParameterSetName='StartAtTableData')]
    [Parameter(ParameterSetName='StartAtSQLData')]
    [Parameter(ParameterSetName='StartAtNewEmail')]
    [Switch]$SortDescending,
    
    # The randomized delay surrounding a task start time.  This can be used to load-balance expensive executions
    [Parameter(ParameterSetName='StartAtTime')]
    [Timespan]$Jitter,

    # If set, the task will be started every day at this time
    [Parameter(ParameterSetName='StartAtTime')]
    [Switch]$EveryDay,
    
    # The interval (in days) in between running the task
    [Parameter(ParameterSetName='StartAtTime')]
    [Switch]$DayInterval,        


    # If set, the task will be started whenever the machine is locked
    [Parameter(ParameterSetName='StartAtLock')]
    [Switch]$Lock,


    # If set, the task will be started whenever the machine is unlocked
    [Parameter(Mandatory=$true,ParameterSetName='StartAtBoot')]
    [Switch]$Boot,

    # If set, the task will be started whenever the machine is unlocked
    [Parameter(Mandatory=$true,ParameterSetName='StartAtAnyLogon')]
    [Switch]$Logon,
    
    # If set, the task will be started whenever the machine is unlocked
    [Parameter(Mandatory=$true,ParameterSetName='StartAtUnlock')]
    [Switch]$Unlock,

    # If set, the task will be started whenever a user logs onto the local machine
    [Parameter(Mandatory=$true,ParameterSetName='StartAtLocalLogon')]
    [Switch]$LocalLogon,

    # If set, the task will be started whenever a user logs off of a local machine
    [Parameter(Mandatory=$true,ParameterSetName='StartAtLocalLogoff')]
    [Switch]$LocalLogoff,

    # If set, the task will be started whenever a user disconnects via remote deskop
    [Parameter(Mandatory=$true,ParameterSetName='StartAtRemoteLogon')]
    [Switch]$RemoteLogon,

    # If set, the task will be started whenever a user disconnects from remote desktop
    [Parameter(Mandatory=$true,ParameterSetName='StartAtRemoteLogoff')]
    [Switch]$RemoteLogoff,

    # Starts the task as soon as possible
    [Parameter(Mandatory=$true,ParameterSetName='StartASAP')]
    [Alias('ASAP')]
    [Switch]$Now,

    # IF provided, will scope logons or connections to a specific user
    [Parameter(ParameterSetName='StartAtLock')]
    [Parameter(ParameterSetName='StartAtUnLock')]
    [Parameter(ParameterSetName='StartAtAnyLogon')]
    [Parameter(ParameterSetName='StartAtAnyLogoff')]
    [Parameter(ParameterSetName='StartAtLocalLogon')]
    [Parameter(ParameterSetName='StartAtLocalLogoff')]
    [Parameter(ParameterSetName='StartAtRemoteLogon')]
    [Parameter(ParameterSetName='StartAtRemoteLogoff')]
    [string]$ByUser,



    # The user running the script
    [Management.Automation.PSCredential]
    $As,


    # The name of the computer the task will be run on.  If not provided, the task will be run locally
    [Alias('On')]
    [string]
    $ComputerName,

    # If set, the task will repeat at this frequency.
    [Timespan]$RepeatEvery,

    # If set, the task will repeat for up to this timespan.  If not set, the task will repeat indefinately.
    [Timespan]$RepeatFor,

    # A name for the task.
    [string]
    $Name,

    # The name of the folder within Task Scheduler.    
    [string]
    $Folder,

    # If set, will not exist the started task.
    [Switch]
    $NoExit,

    # The priority of the scheduled task
    [Uint32]
    $TaskPriority = 4,

    # How multiple instances of a task should be treated.  By default, multiple instances are queued.
    [ValidateSet("StopExisting", "Queue", "Parallel", "IgnoreNew")]
    [string]
    $MultipleInstancePolicy = "Queue",

    # If set, the task will self destruct after it as run once.
    [Switch]
    $SelfDestruct,

    # If set, tasks registered with a credential will be registered with TASK_LOGON_PASSWORD, which will prevent the scheduled task from popping up a visible window.
    [Switch]
    $NotInteractive
    )

    process {
        #region Connect to the scheduler
        $sched = New-Object -ComObject Schedule.Service
        $sched.Connect()
        $task = $sched.NewTask(0)
        $task.Settings.Priority = $TaskPriority
        #endregion Connect to the scheduler


        $description = ""
        #region Add the actions to the task
        foreach ($sb in $ScriptBlock) {

            $action = $task.Actions.Create(0)
            $action.Path = Join-Path $psHome "PowerShell.exe" 
        
        
            $action.Arguments = " -WindowStyle Minimized -Sta"
        
        
            if ($NoExit) {
                $Action.Arguments += " -NoExit"
            }
            $encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($sb))
            $action.Arguments+= " -encodedCommand $encodedCommand"

        }
        #endregion Add the actions to the task

        if ($PSCmdlet.ParameterSetName -eq 'StartAtTime') {
        
                $days = (Get-Culture).DateTimeFormat.DayNames
                $months  = (Get-Culture).DateTimeFormat.MonthNames
                if ($PSBoundParameters.EveryDay -or $PSBoundParameters.DayInterval) {
                    $dailyTrigger = $task.Triggers.Create(2)

                    if ($psBoundParameters.DayInterval) {
                        $dailyTrigger.DaysInterval = $psBoundParameters.DayInterval
                    }
                } else {
                    # One time
                    $timeTrigger = $task.Triggers.Create(1)

                    
                }


        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtLogon') {
            $logonTrigger= $task.Triggers.Create(9)
            $description += " At Logon "
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtSystemEvent') {
            $evtTrigger= $task.Triggers.Create(0)
            $evtTrigger.Subscription = "
<QueryList>
    <Query Id='0' Path='$($EventLog)'>
        <Select Path='$($EventLog)'>
            *[System[EventID=$($EventId)]]
        </Select>
    </Query>
</QueryList>                
"                
            
            $description += " At Event $EventId"
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtLocalLogon') {
            $stateTrigger= $task.Triggers.Create(11)
            $stateTrigger.StateChange = 1 
            $description += " At Local Logon "
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtLocalLogoff') {
            $stateTrigger= $task.Triggers.Create(11)
            $stateTrigger.StateChange = 2 
            $description += " At Local Logoff "
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtRemoteLogoff') {
            $stateTrigger= $task.Triggers.Create(11)
            $stateTrigger.StateChange = 3 
            $description += " At Remote Logon "
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtRemoteLogoff') {
            $stateTrigger= $task.Triggers.Create(11)
            $stateTrigger.StateChange = 4 
            $description += " At Remote Logoff "
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtLock') {
            $stateTrigger= $task.Triggers.Create(11)
            $stateTrigger.StateChange = 7 
            $description += " At Lock"
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtUnlock') {
            $stateTrigger= $task.Triggers.Create(11)
            $stateTrigger.StateChange = 8 
            $description += " At Unlock "
                
            
        } elseif ($psCmdlet.ParameterSetName -eq 'StartASAP') {
            $regTrigger = $task.Triggers.Create(7)
            $description += " ASAP "
        } elseif ($psCmdlet.ParameterSetName -eq 'StartAtBoot') {
            $bootTrigger = $task.Triggers.Create(8)
            
            $description += " OnBoot "
        } elseif ('StartAtTableData', 'StartAtSqlData', 'StartAtNewEmail' -contains $PSCmdlet.ParameterSetName) {            
            if (-not $PSBoundParameters.As) {
                Write-Error "Must supply credential for table based tasks"
                return 
            }
            # Schedule it as the user that will check

            $description += " New SQL Data from $TableName "
            IF ($PSCmdlet.ParameterSetName -eq 'StartAtNewEmail') {
                $check= "
Get-Email -UserNameSetting '$EmailUserNameSetting' -PasswordSetting '$EmailPasswordSetting' -Unread -Download -To '$SentTo'"
            } elseif ($psCmdlet.ParameterSetName -eq 'StartAtSqlData') {
                $check= "
Select-Sql -ConnectionStringOrSetting '$ConnectionStringSetting' -FromTable '$tableName' -Where '$Where'"
            } elseif ($psCmdlet.ParameterSetName -eq 'StartAtTableData') {
                $check = "
Search-AzureTable -TableName '$TableName' -Filter `"$Filter`" -StorageAccount `$storageAccount -StorageKey `$storageKey"
                
                if ((-not $UserTableName) -and $TableName) {
                    $UserTableName = $TableName
                }

            } 
            
                


            $saveMyCred = "
Add-SecureSetting -Name '$StorageAccountSetting' -String '$(Get-SecureSetting $StorageAccountSetting -ValueOnly)'
Add-SecureSetting -Name '$StorageKeySetting' -String '$(Get-SecureSetting $StorageKeySetting -ValueOnly)'
                "

            $saveMyCred = [ScriptBlock]::Create($saveMyCred)
            # Start-At -ScriptBlock $saveMyCred -As $As -Now
            
            

            

            $checkTable = "
Import-Module Pipeworks 
`$storageAccount = Get-SecureSetting '$StorageAccountSetting' -ValueOnly
`$storageKey = Get-SecureSetting '$StorageKeySetting' -ValueOnly
`$verbosePreference='$VerbosePreference'
Write-Verbose 'Getting Data'
$check |
    Sort-Object { 
        if (`$_.Timestamp) {
            (`$_.Timestamp -as [Datetime])
        } elseif (`$_.DateTimeSent -as [DateTime]) {
            `$_.DateTimeSent -as [DateTime]
        } else {
            `"`"
        }
    } -Descending:`$$SortDescending |
    Foreach-Object -Begin { 
        
    }-Process { 
        `$item = `$_
        
        `$userTableName = '$UserTableName'
        
        if (-not `$userTableName) {
            `$error.Clear()
            
            Write-Verbose 'Script Started'
            `$scriptOutput = . {
                $ScriptBlock
            }
            Write-Verbose 'Script Complete'
            `$errorList = @(`$error)
            `$updatedItem  =`$item | 
                Add-Member NoteProperty ScriptResults `$scriptOutput -Force -PassThru 


            if (`$errorList) {
                `$updatedItem = `$updatedItem |
                    Add-Member NoteProperty ScriptErrors `$errorList -Force -PassThru 
            }

        } else {        
            if (`$item.From.Address) {                
                `$userFound = Search-AzureTable -TableName '$UserTableName' -Filter `"PartitionKey eq '$UserPartition' and UserEmail eq '`$(`$item.From.Address)'`" -StorageAccount `$storageAccount -StorageKey `$storageKey
            } elseif (`$item.OwnerID) {
                # Run it as the owner
                `$userFound = Search-AzureTable -TableName '$UserTableName' -Filter `"PartitionKey eq '$UserPartition' and RowKey eq '`$(`$item.OwnerID)'`" -StorageAccount `$storageAccount -StorageKey `$storageKey
            }
            if (-not `$userFound) { 
                Write-Error 'User Not Found'
                return 
            }
            
            if (-not `$item.OwnerID) {
                return
            } 


            `$id = `$item.OwnerID[0..7+-1..-12] -join ''
            `$userExistsOnSystem = net user `"`$id`" 2>&1
            
            if (`$userExistsOnSystem[0] -as [Management.Automation.ErrorRecord]) {
                # They don't exist, make them 
                # `$completed = net user `"`$id`" `"`$(`$userFound.PrimaryAPIKey)`" /add /y
                Write-Verbose 'Creating User'
                `$objOu = [ADSI]`"WinNT://`$env:ComputerName`"
                `$objUser = `$objOU.Create(`"User`", `$id)
                `$objUser.setpassword(`$userFound.PrimaryAPIKey)
                `$objUser.SetInfo()
                `$objUser.description = `$userFound.UserID
                `$objUser.SetInfo()
            }

            `$targetPath = Split-path `$home 
            `$targetPath = Join-Path `$targetPath `$id               

            `$innerScript = {
                `$in = `$args 
                    
                foreach (`$item in `$in) {                         
                    if (`$item -is [Array]) {
                        `$item = `$item[0]
                    }
                    . {
                        $ScriptBlock       
                    } 2>&1
                    
                    `$null = `$item
                }                                                                  
            }

            `$asCred = New-Object Management.Automation.PSCredential `"`$id`", (ConvertTo-SecureString -Force -AsPlainText `"`$(`$userFound.PrimaryAPIKey)`")
            `$scriptOutput = Start-Job -ScriptBlock `$innerScript -Credential `$asCred -ArgumentList `$item |
                Wait-Job |
                Receive-Job

            `$jobWorked = `$?

            `$compressedResults = (`$scriptOutput | Write-PowerShellHashtable) | Compress-Data -String {  `$_ } 

            `$updatedItem  =`$item | 
                Add-Member NoteProperty ScriptResults (`$compressedResults)  -Force -PassThru 


            if (`$jobWorked -and `$item.RowKey -and `$item.PartitionKey) {
                `$clearProperty = '$ClearProperty'
                if (`$clearProperty) {
                    `$null = `$updatedItem.psobject.properties.Remove(`$clearProperty)
                }
                `$updatedItem |
                    Update-AzureTable -TableName '$TableName' -Value { `$_ } 
            }
            
        }   
        
        
         
    }
"

            $checkTable = [ScriptBlock]::Create($checkTable)

            Start-At -Boot -As $as -ScriptBlock $checkTable -RepeatEvery $CheckEvery -NoExit:$NoExit -Name:"${Name}_AtBoot" -Folder:$Folder
            Start-At -Now -As $as -ScriptBlock $checkTable -RepeatEvery $CheckEvery -NoExit:$NoExit -Name:"${Name}_Now" -Folder:$Folder
        }


        
        

        if ($task.Triggers.Count) {
            $task.Settings.MultipleInstances = if ($MultipleInstancePolicy -eq 'StopExisting') {
                 3
            } elseif ($MultipleInstancePolicy -eq 'Queue') {
                1
            } elseif ($MultipleInstancePolicy -eq 'Parallel') {
                0
            } elseif ($MultipleInstancePolicy -eq 'IgnoreNew') {
                2
            }
            foreach ($trig in $task.Triggers) {
                if ($PSBoundParameters.Time) {
                    $trig.StartBoundary = $Time.ToString("s")
                } else {
                    $trig.StartBoundary = [DateTime]::Now.ToString("s")
                }
                if ($PSBoundParameters.RepeatEvery)  {
                    $trig.Repetition.Interval = "PT$($RepeatEvery.TotalMinutes -as [uint32])M"
                }
                if ($PSBoundParameters.RepeatFor) {
                    $trig.Repetition.Duration = "PT$($RepeatFor.TotalMinutes -as [uint32])M"
                }
                if ($PSBoundParameters.Jitter) {
                    $trig.RandomDelay = "PT$($Jitter.TotalMinutes -as [uint32])M"
                }
                if ($psBoundParameters.ByUser) {
                    $trig.UserID = $PSBoundParameters.ByUser
                    $description += " ByUser $($psBoundParameters.ByUser.Replace('\','_'))"
                }

            }

            $taskNAme = if ($Name) {
                $Name
            } else {
                if ($as) {
                    "Start-At $Description as $($As.GetNetworkCredential().UserName) "
                } else {
                    "Start-At $Description"
                }
            }


            
            

            $taskPath = 
                if ($Folder) {
                    Join-Path $folder $taskNAme 
                } else {
                    $taskNAme 
                }

            if ($selfDestruct) {
                $removeAction = $task.Actions.Create(0)
                $removeAction.Path = "schtasks"                                
                $removeAction.Arguments = "/delete /tn `"$TaskPath`" /f"
        
            }

            if ($as) {
                $task.Principal.RunLevel = 1                
                if ($NotInteractive) {
                    $registeredTask = $sched.GetFolder("").RegisterTask($taskPath, $task.XmlText, 6, $As.UserName, $As.GetNetworkCredential().Password, 1, $null)
                }  else {
                    $registeredTask = $sched.GetFolder("").RegisterTask($taskPath, $task.XmlText, 6, $As.UserName, $As.GetNetworkCredential().Password, 6, $null)
                }
                
            } else {
                $registeredTask = $sched.GetFolder("").RegisterTask($taskPath, $task.XmlText, 6, "", "", 3, $null)
            }
        }
        




        
    }
}