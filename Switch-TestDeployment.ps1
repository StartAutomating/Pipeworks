function Switch-TestDeployment
{
    <#
    .Synopsis
        Switches host entries to test a deployment
    .Description
        Toggles the local name resolution for a test domain to and from test host.  
        
        This lets you preview a deployment before making it live, and allows you to perform automated tests against the deployment.
    .Example
        Switch-TestDeployment -HostName "Start-LearningPowerShell.com" -TestHost 03ad2d078dd348cb9eaddfb50a6d8141.cloudapp.net
    .Link
        Publish-AzureService
    #>
    [OutputType([PSObject])]
    param(
    # The public DNS name for the website    
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$HostName,
    
    # The DNS name for the test deployment
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]$TestHost
    )
    
    
    process {
        
        $resolvedTestHost = [Net.Dns]::Resolve("$TestHost").AddressList
        if (-not $resolvedTestHost) { return }
        #region Load hosts file and find the change
        $lines = 
            [IO.fILE]::ReadAllLines("$env:windir\System32\drivers\etc\hosts")
            
        $found = $lines |
            Where-Object {
                $_ -like "* $hostName*"
            }
        #endregion Load hosts file and find the change    
        
        #region Toggle host file presence
        if (-not $found) {
            $newLines = New-Object Collections.ArrayList
            $null = $newLines.AddRange(@($Lines))
            $null = $newLines.Add(@("$resolvedTestHost $hostName"))            
            $output = New-Object PSObject -Property @{
                Operation= "Using"
            }
                        
        } else {
            $newLines = $lines |
                Where-Object {
                    $_ -notlike "* $hostName*"
                }
            $output = New-Object PSObject -Property @{
                Operation = "No Longer Using"
            }
        }
        #endregion Toggle host file presence
        
        #region Rewrite host file
        $newLines = [string[]]@($newLines)
        
        [Io.File]::WriteAllLines("$env:windir\System32\drivers\etc\hosts", $newLines)                        
        #endregion Rewrite host file
        
        $output |
            Add-Member NoteProperty TestHostUrl $testHost -PassThru |
            Add-Member NoteProperty ForHostName $hostName -PassThru 
            
            
    }
    
}