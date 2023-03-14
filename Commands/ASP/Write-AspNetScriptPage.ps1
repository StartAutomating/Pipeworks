function Write-AspDotNetScriptPage
{
    <#
    .Synopsis
        Writes an ASP.NET page that executes PowerShell script
    .Description
        Runs a PowerShell script inside of an ASP.net page.  
        
        The runspace used in the ASP.NET script page will be reused for as long as the session is active.
        
        Variables set while running your script will be available throughout the session.                       
        
        PowerShellV2 must be installed on the server, but no other special binaries are required.
    .Example
        Write-AspDotNetScriptPage -PrependBootstrapper -ScriptBlock {
            $response.Write("<pre>
$(Get-Help Get-Command -full | Out-String -width 1024)
</pre>")            
        } | 
            Set-Content
    .Link
        about_ServerSidePowerShell
    #>
    [CmdletBinding(DefaultParameterSetName='BootStrapper')]
    [OutputType([string])]
    param(
    # The script block to embed in the page.  This will use the runScript function declared in the bootstrapper.
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='ScriptBlock',ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
    [ScriptBlock]$ScriptBlock,
    
    # The direct ASP.NET text to embed in the page.  To run scripts inside of this text, use <% runScript(); %>
    #|LinesForInput 6
    [Parameter(Mandatory=$true,Position=1,ParameterSetName='Text',ValueFromPipelineByPropertyName=$true)]
    [string]$Text,
    
    # If set, prepends the bootstrapper code to the ASP.NET page.  
    # This is required the first time you want to run PowerShell inside of your ASP.NET page.
    # It declares a function, runScript, which you can use to run PowerShell
    [Parameter(Position=6,ParameterSetName='ScriptBlock',ValueFromPipelineByPropertyName=$true)]
    [Parameter(Position=6,ParameterSetName='Text',ValueFromPipelineByPropertyName=$true)]
    [switch]$NoBootstrapper,
    
    # If set, the page generated will include this page as the ASP.NET master page
    [Parameter(Position=2,ValueFromPipelineByPropertyName=$true)]
    [string]$MasterPage,

    # If set, the page generated will be a master page
    [Parameter(Position=3,ValueFromPipelineByPropertyName=$true)]
    [Switch]$IsMasterPage,

    # If set, uses a codefile page
    [Parameter(Position=4,ValueFromPipelineByPropertyName=$true)]
    [string]$CodeFile,

    # If set, inherits from another codefile page
    [Parameter(Position=5,ValueFromPipelineByPropertyName=$true)]
    [string]$Inherit
    )
    
    begin {
        function issEmbed($cmd) {
        
        if ($cmd.Definition -like "*<script*") {
@"
        string $($cmd.Name.Replace('-',''))Base64 = "$([Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd.Definition)))";
        string $($cmd.Name.Replace('-',''))Definition = System.Text.Encoding.Unicode.GetString(System.Convert.FromBase64String($($cmd.Name.Replace('-',''))Base64));
        SessionStateFunctionEntry $($cmd.Name.Replace('-',''))Command = new SessionStateFunctionEntry(
            "$($cmd.Name)", $($cmd.Name.Replace('-',''))Definition
        );
        iss.Commands.Add($($cmd.Name.Replace('-',''))Command);
"@        
        } else {
@"
        SessionStateFunctionEntry $($cmd.Name.Replace('-',''))Command = new SessionStateFunctionEntry(
            "$($cmd.Name)", @"
            $($cmd.Definition.ToString().Replace('"','""'))
            "
        );
        iss.Commands.Add($($cmd.Name.Replace('-',''))Command);
"@
        }
        }
        $functionBlackList = 65..90 | ForEach-Object -Begin {
            "ImportSystemModules", "Disable-PSRemoting", "Restart-Computer", "Clear-Host", "cd..", "cd\\", "more"
        } -Process { 
            [string][char]$_ + ":" 
        }
                
                
        $masterPageDirective = if ($MasterPage) {
            "MasterPageFile='$MasterPage'"
        } else {
            ""
        }
        
        
        # These core functions must exist in all runspaces
        if (-not $script:FunctionsInEveryRunspace) {
            $script:FunctionsInEveryRunspace = 'ConvertFrom-Markdown', 'Get-Web', 'Get-WebConfigurationSetting', 'Get-FunctionFromScript', 'Get-Walkthru', 
                'Get-WebInput', 'Request-CommandInput', 'New-Region', 'New-RssItem', 'New-WebPage', 'Out-Html', 'Out-RssFeed', 'Send-Email',
                'Write-Ajax', 'Write-Css', 'Write-Host', 'Write-Link', 'Write-ScriptHTML', 'Write-WalkthruHTML', 
                'Write-PowerShellHashtable', 'Compress-Data', 'Expand-Data', 'Import-PSData', 'Export-PSData', 'ConvertTo-ServiceUrl', 'Get-SecureSetting', 'Search-Engine'



        }
 
        # The embed section contains them
        $embedSection = foreach ($func in Get-Command -Module Pipeworks -Name $FunctionsInEveryRunspace -CommandType Function) {
            issEmbed $func
        }


        $bootStrapperServerSideCode = @"
<%@ Assembly Name="System.Management.Automation, Version=1.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" %>

<%@ Import Namespace="System.Collections.ObjectModel" %>
<%@ Import Namespace="System.Management.Automation" %>
<%@ Import namespace="System.Management.Automation.Runspaces" %>
<script language="C#" runat="server">        
    public void runScript(string script) {
        PowerShell powerShellCommand = PowerShell.Create();
        bool justLoaded = false;
        Runspace runspace;
        if (Session["UserRunspace"] == null) {
            InitialSessionState iss = InitialSessionState.CreateDefault();
            $embedSection
            string[] commandsToRemove = new String[] { "$($functionBlacklist -join '","')"};
            foreach (string cmdName in commandsToRemove) {
                iss.Commands.Remove(cmdName, null);
            }
            
            Runspace rs = RunspaceFactory.CreateRunspace(iss);
            rs.ApartmentState = System.Threading.ApartmentState.STA;            
            rs.ThreadOptions = PSThreadOptions.ReuseThread;
            rs.Open();
            Session.Add("UserRunspace",rs);
            justLoaded = true;
        }

        runspace = Session["UserRunspace"] as Runspace;

        if (Application["Runspaces"] == null) {
            Application["Runspaces"] = new Hashtable();
        }
        if (Application["RunspaceAccessTimes"] == null) {
            Application["RunspaceAccessTimes"] = new Hashtable();
        }
        if (Application["RunspaceAccessCount"] == null) {
            Application["RunspaceAccessCount"] = new Hashtable();
        }

        Hashtable runspaceTable = Application["Runspaces"] as Hashtable;
        Hashtable runspaceAccesses = Application["RunspaceAccessTimes"] as Hashtable;
        Hashtable runspaceAccessCounter = Application["RunspaceAccessCount"] as Hashtable;
                
        if (! runspaceTable.Contains(runspace.InstanceId.ToString())) {
            runspaceTable[runspace.InstanceId.ToString()] = runspace;
        }

        if (! runspaceAccessCounter.Contains(runspace.InstanceId.ToString())) {
            runspaceAccessCounter[runspace.InstanceId.ToString()] = 0;
        }
        runspaceAccessCounter[runspace.InstanceId.ToString()] = ((int)runspaceAccessCounter[runspace.InstanceId.ToString()]) + 1;
        runspaceAccesses[runspace.InstanceId.ToString()] = DateTime.Now;

        
        runspace.SessionStateProxy.SetVariable("Request", Request);
        runspace.SessionStateProxy.SetVariable("Response", Response);
        runspace.SessionStateProxy.SetVariable("Session", Session);
        runspace.SessionStateProxy.SetVariable("Server", Server);
        runspace.SessionStateProxy.SetVariable("Cache", Cache);
        runspace.SessionStateProxy.SetVariable("Context", Context);
        runspace.SessionStateProxy.SetVariable("Application", Application);
        runspace.SessionStateProxy.SetVariable("JustLoaded", justLoaded);
        powerShellCommand.Runspace = runspace;

        PSInvocationSettings invokeWithHistory = new PSInvocationSettings();
        invokeWithHistory.AddToHistory = true;
        PSInvocationSettings invokeWithoutHistory = new PSInvocationSettings();
        invokeWithHistory.AddToHistory = false;



        if (justLoaded) {        
            powerShellCommand.AddCommand("Set-ExecutionPolicy", false).AddParameter("Scope", "Process").AddParameter("ExecutionPolicy", "Bypass").AddParameter("Force", true).Invoke(null, invokeWithoutHistory);
            powerShellCommand.Commands.Clear();
        }
        
        powerShellCommand.AddScript(@"
`$timeout = (Get-Date).AddMinutes(-20)
`$oneTimeTimeout = (Get-Date).AddMinutes(-1)
foreach (`$key in @(`$application['Runspaces'].Keys)) {
    if ('Closed', 'Broken' -contains `$application['Runspaces'][`$key].RunspaceStateInfo.State) {
        `$application['Runspaces'][`$key].Dispose()
        `$application['Runspaces'].Remove(`$key)
        continue
    }
    
    if (`$application['RunspaceAccessTimes'][`$key] -lt `$Timeout) {
        
        `$application['Runspaces'][`$key].CloseAsync()
        continue
    }    
}
").Invoke();

        powerShellCommand.Commands.Clear();

        powerShellCommand.AddCommand("Split-Path", false).AddParameter("Path", Request.ServerVariables["PATH_TRANSLATED"]).AddCommand("Set-Location").Invoke(null, invokeWithoutHistory);
        powerShellCommand.Commands.Clear();        


        try {
            Collection<PSObject> results = powerShellCommand.AddScript(script, false).Invoke();        
            foreach (Object obj in results) {
                if (obj != null) {
                    if (obj is IEnumerable && ! (obj is String)) {
                        foreach (Object innerObject in results) {
                            Response.Write(innerObject);
                        }
                    } else {
                        Response.Write(obj);
                    }
                    
                }
            }
            foreach (ErrorRecord err in powerShellCommand.Streams.Error) {
                Response.Write("<span class='ErrorStyle' style='color:red'>" + err + "<br/>" + err.InvocationInfo.PositionMessage + "</span>");
            }

        } catch (Exception exception) {
            Response.Write("<span class='ErrorStyle' style='color:red'>" + exception.Message + "</span>");
        } finally {
            powerShellCommand.Dispose();
        }
    }
</script>
"@        
    }
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'BootStrapper') {
            $bootStrapperServerSideCode
        } elseif ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
                        
            if (-not $NoBootstrapper) {
            @"
<%@ $(if ($IsMasterPage) {'Master'} else {'Page'}) Language="C#" AutoEventWireup="True" $masterPageDirective $(if ($CodeFile) { "CodeFile='$CodeFile'" } $(if ($inherit) { "Inherits='$Inherit'" }))%>
$bootStrapperServerSideCode 
$(if ($MasterPage) { '<asp:Content runat="server">' } else {'<%' })
runScript(@"$($scriptBlock.ToString().Replace('"','""'))"); 
$(if ($MasterPage) { '</asp:Content>' } else {'%>'})

"@            
            } else {
                        @"
<%@ $(if ($IsMasterPage) {'Master'} else {'Page'}) Language="C#" AutoEventWireup="True" $masterPageDirective $(if ($CodeFile) { "CodeFile='$CodeFile'" } $(if ($inherit) { "Inherits='$Inherit'" }))%>
<% runScript(@"$($scriptBlock.ToString().Replace('"','""'))"); %>
"@            

            }
            
        } elseif ($psCmdlet.ParameterSetName -eq 'Text') {
            if (-not $NoBootstrapper) {
            @"
<%@ $(if ($IsMasterPage) {'Master'} else {'Page AutoEventWireup="True" '}) Language="C#" $masterPageDirective $(if ($CodeFile) { "CodeFile='$CodeFile'" } $(if ($inherit) { "Inherits='$Inherit'" }))%>

$bootStrapperServerSideCode 
$Text
"@            
            } else {
                        @"
<%@ $(if ($IsMasterPage) {'Master'} else {'Page AutoEventWireup="True"'}) Language="C#" $masterPageDirective $(if ($CodeFile) { "CodeFile='$CodeFile'" } $(if ($inherit) { "Inherits='$Inherit'" }))%>
<%@ Assembly Name="System.Management.Automation, Version=1.0.0.0, Culture=neutral, PublicKeyToken=31bf3856ad364e35" %>

$Text
"@            

            }
            
        }
    }
}



