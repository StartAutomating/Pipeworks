function Invoke-Office365
{
    <#
    .Synopsis
        Invokes commands within Office365
    .Description
        Invokes PowerShell commands within Office365
    .Example
        Invoke-Office365 -ScriptBlock { Get-Mailbox -Identity james.brundage@start-automating.com } 
    .LINK
        http://help.outlook.com/en-us/140/cc952755.aspx
    #>
    [CmdletBinding(DefaultParameterSetName='Office365')]
    [OutputType([PSObject])]
    param(        
    # The credential for the Office365 account
    [Parameter(Position=1,ParameterSetName='ExchangeServer', ValueFromPipelineByPropertyName=$true)]
    [Parameter(Position=1,ParameterSetName='Office365', ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.PSCredential]
    $Account,  
    
    # A list of account settings to use.  
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $AccountSetting  =  @("Office365UserName", "Office365Password"),
    
    # The exchange server name.  Only required if you're not invoking against Office365
    [Parameter(Mandatory=$true,Position=2,ParameterSetName='ExchangeServer', ValueFromPipelineByPropertyName=$true)]    
    [string]
    $ServerName,        
   
    # The script block to run in Office365
    [Parameter(Position=0)]
    [string[]]
    $ScriptBlock,
    
    # Any arguments to the script
    [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true)]
    [PSObject[]]
    $ArgumentList,
    
    # The name of the session.  If omitted, the name will contain the email used to connect to Office365.    
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$Name,
    

    # If set, will run the command in a background job
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $AsJob,

    # If set, will create a fresh connection and destroy the connection when the command is complete.  
    # This is slower, but less likely to make the exchange server experience a session bottleneck.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $FreshConnection
    )
    
    begin {
        if (-not $script:JobCounter) {
            $script:JobCounter = 1 
        }
    }

    process {
        #region Copy Credential for Office365
        if (-not $Account) {
            if ($AccountSetting -and $accountSetting.Count -eq 2) {
                $username = Get-SecureSetting $accountSetting[0] -ValueOnly 
                $password = Get-SecureSetting $accountSetting[1] -ValueOnly 
                if ($username -and $password) {
                    $account = New-Object Management.Automation.PSCredential $username,(ConvertTo-SecureString -AsPlainText -Force $password )
                    $psBoundParameters.Account = $account
                }
            }
        }

        if (-not $account) {
            Write-Error "Must provide an Account or AccountSetting to connect to Office365"
            return
        }
        #endregion Copy Credential for Office365

        

        #region Launch Background Job if Needed 
        if ($AsJob) {
            $myDefinition = [ScriptBLock]::Create("function Invoke-Office365 {
$(Get-Command Invoke-Office365 | Select-Object -ExpandProperty Definition)
}
")
            $null = $psBoundParameters.Remove('AsJob')            
            
            $myJob= [ScriptBLock]::Create("" + {
                param([Hashtable]$parameter) 
                
            } + $myDefinition + {
                
                Invoke-Office365 @parameter
            }) 
            if (-not $name) { 
                $name = "Office365Job${script:JobCounter}"
                $script:JobCounter++ 
            } 
            Start-Job -Name "$name " -ScriptBlock $myJob -ArgumentList $psBoundParameters 
            return
        }
        #endregion Launch Background Job if Needed 

        
                
        #region Prepare Session Parameters
        if ($psCmdlet.ParameterSetName -eq 'Office365') {
            if ($script:ExchangeWebService -and $script:CachedCredential.Username -eq $script:CachedCredential) {
                return
            }    
            $ExchangeServer = "https://ps.outlook.com/"
            Write-Progress "Connecting to Office365" "$exchangeServer"
            $script:CachedCredential = $Account
        
            $newSessionParameters = @{
                ConnectionUri='https://ps.outlook.com/powershell'
                ConfigurationName='Microsoft.Exchange'
                Authentication='Basic'           
                Credential=$Account
                AllowRedirection=$true
                WarningAction = "silentlycontinue"
                SessionOption=(New-Object Management.Automation.Remoting.PSSessionOption -Property @{OpenTimeout="00:30:00"})
                Name = "https://$($Account.UserName)@ps.outlook.com/powershell"
                
            }
            
            $ExchangeServer = "https://ps.outlook.com/"            
        } else { 
            $ExchangeServer = $ServerName
            $newSessionParameters = @{
                ConnectionUri="https://$ServerName/powershell"
                ConfigurationName='Microsoft.Exchange'
                Authentication='Basic'           
                Credential=$Account
                AllowRedirection=$true
                WarningAction = "silentlycontinue"
                Name = "https://$ServerName/powershell"
                SessionOption=(New-Object Management.Automation.Remoting.PSSessionOption -Property @{OpenTimeout="00:30:00"})
                
            }
        }

        if ($psBoundParameters.Name) {
            $newSessionParameters.Name = $psBoundParameters.Name
        }
        #endregion Prepare Session Parameters


        #region Find or Create Session
        $existingSession = (Get-PSSession -Name $newSessionParameters.Name -ErrorAction SilentlyContinue)
        if ($FreshConnection -or (-not $existingSession ) -or ($existingSession.State -ne 'Opened')) {
            if ($existingSession) {
                $existingSession | Remove-PSSession
            }
            if (-not $FreshConnection) {
                $Session = New-PSSession @newSessionParameters -WarningVariable warning 
            }
        } else {
            $Session = $existingSession
        }
        #endregion Find or Create Session
        
        
        #region Invoke on Office365
        if (-not $Session -and -not $FreshConnection) { return } 
                
        foreach ($s in $scriptBlock) {
            $realScriptBlock  =[ScriptBlock]::Create($s)
            if (-not $realScriptBlock) { continue } 
            
            if (-not $FreshConnection) {
                Invoke-Command -Session $session -ArgumentList $Arguments -ScriptBlock $realScriptBlock  
            } else {
                $null = $newSessionParameters.Remove("Name")
                Start-Job -ArgumentList $Account, $realScriptBlock,$Arguments -ScriptBlock {
                    param([Management.Automation.PSCredential]$account, $realScriptBlock, $Arguments) 

                    $realScriptBlock = [ScriptBlock]::Create($realScriptBlock)
                    $newSessionParameters = @{
                        ConnectionUri='https://ps.outlook.com/powershell'
                        ConfigurationName='Microsoft.Exchange'
                        Authentication='Basic'           
                        Credential=$Account
                        AllowRedirection=$true
                        WarningAction = "silentlycontinue"
                        SessionOption=(New-Object Management.Automation.Remoting.PSSessionOption -Property @{OpenTimeout="00:30:00"})
                        
                
                    }

                    Invoke-Command @newsessionParameters -ArgumentList $Arguments -ScriptBlock $realScriptBlock 
                } | Wait-Job | Receive-Job
                
            }
            
        }

        if ($session -and $FreshConnection) {
            Remove-PSSession -Session $session
        }   
        #endregion Invoke on Office365
    }
}                       
 

