function Invoke-EC2 {    
    <#
    .Synopsis
        Invokes commands on EC2 instances
    .Description
        Invokes PowerShell commands on EC2 instances
    .Example    
        Get-EC2 |
            Invoke-EC2 -ScriptBlock { Get-Process }
    .Link
        Get-EC2
    #>
    [CmdletBinding(DefaultParameterSetName='InProcess')]
    param(    
    # The EC2 instance ID
    [Parameter(ParameterSetName='ComputerName',Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
    [string]
    $InstanceId,
    
    # An existing PS Session
    [Parameter(ParameterSetName='Session', Position=0, ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.Runspaces.PSSession[]]
    ${Session},

    # The port used to invoke the command
    [Parameter(ParameterSetName='ComputerName')]
    [ValidateRange(1, 65535)]
    [System.Int32]
    ${Port},

    # If set, will use SSL
    [Parameter(ParameterSetName='ComputerName')]
    [Switch]
    ${UseSSL},

    # The configuration name
    [Parameter(ParameterSetName='ComputerName', ValueFromPipelineByPropertyName=$true)]
    [System.String]
    ${ConfigurationName},

    # The application name
    [Parameter(ParameterSetName='ComputerName', ValueFromPipelineByPropertyName=$true)]
    [System.String]
    ${ApplicationName},

    # The throttle limit   
    [Parameter(ParameterSetName='ComputerName')]    
    [System.Int32]
    ${ThrottleLimit},
    
    # If set, will run the command as a job
    [Parameter(ParameterSetName='ComputerName')]
    [Parameter(ParameterSetName='Session')]
    [Switch]
    ${AsJob},

    # If set, will hide the computername property from returned objects
    [Parameter(ParameterSetName='ComputerName')]
    [Parameter(ParameterSetName='Session')]
    [Alias('HCN')]
    [Switch]
    ${HideComputerName},
    
    # The name of the job
    [Parameter(ParameterSetName='Session')]
    [Parameter(ParameterSetName='ComputerName')]
    [System.String]
    ${JobName},

    # The command to run on the EC2 instance
    [Parameter(ParameterSetName='ComputerName', Mandatory=$true, Position=1)]
    [Parameter(ParameterSetName='Session', Mandatory=$true, Position=1)]
    [Alias('Command')]
    [ValidateNotNull()]
    [System.Management.Automation.ScriptBlock]
    ${ScriptBlock},

    # Remoting session options
    [Parameter(ParameterSetName='ComputerName')]
    [System.Management.Automation.Remoting.PSSessionOption]
    ${SessionOption},

    # Remoting authentication options
    [Parameter(ParameterSetName='ComputerName')]
    [System.Management.Automation.Runspaces.AuthenticationMechanism]
    ${Authentication},

    # An input object
    [Parameter(ValueFromPipeline=$true)]
    [System.Management.Automation.PSObject]
    ${InputObject},

    # Any arguments to the remote script
    [Alias('Args')]
    [System.Object[]]
    ${ArgumentList},

    # The certificate thumbprint
    [Parameter(ParameterSetName='ComputerName')]
    [System.String]
    ${CertificateThumbprint}
    )
    
    begin {
        
    }
    process {
        $ec2 = Get-EC2 -InstanceId $InstanceID         
        
        if ($psCmdlet.ParameterSetNAme -eq 'ComputerName') {
            $ec2Cred = $ec2 | Get-EC2InstancePassword -AsCredential
            $ec2 | Enable-EC2Remoting -PowerShell -ErrorAction SilentlyContinue
            $icmParams = @{} + $psBoundParameters
            $icmParams.Remove('InstanceId')
            
            Invoke-Command -ComputerName $ec2.PublicDnsName -Credential $ec2Cred @icmParams
        } else {
            Invoke-Command @psboundParameters
        }
        
        
    }
    end {
        
    }
}
