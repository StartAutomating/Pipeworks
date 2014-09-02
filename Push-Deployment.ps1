function Push-Deployment
{
    <#
    .Synopsis
        Pushes a deployment to Azure        
    .Description
        Pushes an existing deployment to an Azure service
    .Example
        Push-Deployment "StartAutomating" ".\startautomating.cspkg" ".\startautomating.cscfg" -FirstLabel Start-Scripting -Second Update-Web
    .Link
        Get-Deployment
    .Link
        Import-Deployment
    .Link
        Remove-Deployment    
    #>
    [CmdletBinding(DefaultParameterSetName='PushAzureDeployment')]
    [OutputType([Nullable])]
    param(
    # The name of the service
    [Parameter(Mandatory=$true,ParameterSetName='PushAzureDeployment',ValueFromPipelineByPropertyName=$true)]
    [string]
    $ServiceName,

    # The path to the CSPackage (.cspkg) file
    [Parameter(Mandatory=$true,ParameterSetName='PushAzureDeployment',ValueFromPipelineByPropertyName=$true)]
    [string]
    $PackagePath,

    # The path to the CSConfigurationFile (.cscfg) file
    [Parameter(Mandatory=$true,ParameterSetName='PushAzureDeployment',ValueFromPipelineByPropertyName=$true)]
    [string]
    $ConfigurationPath,

    # The label of the first deployment slot
    [Parameter(ParameterSetName='PushAzureDeployment',ValueFromPipelineByPropertyName=$true)]
    [string]
    $FirstLabel = "Primary",
    
    # The label of the second deployment slot
    [Parameter(ParameterSetName='PushAzureDeployment',ValueFromPipelineByPropertyName=$true)]
    [string]
    $SecondLabel = "Secondary",

    # The name of the storage account that will contain the bits
    [Parameter(Mandatory=$true,ParameterSetName='PushToAzureVMs')]
    [string]
    $StorageAccount,

    # The storage key of the storage account that will contain the bits
    [Parameter(Mandatory=$true,ParameterSetName='PushToAzureVMs')]
    [string]
    $StorageKey,

    # If set, will push the deployment to Azure VMs
    [Parameter(Mandatory=$true,ParameterSetName='PushToAzureVMs')]
    [Switch]
    $ToAzureVM,

    # The name of the computers that will receive the deployment
    [Parameter(ParameterSetName='PushToAzureVMs')]    
    [string[]]
    $ComputerName,

    
    # The name of the computers that will receive the deployment
    [Parameter(Mandatory=$true,ParameterSetName='PushToAzureVMs')]
    [Management.Automation.PSCredential]
    $Credential

    
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'PushAzureDeployment') {
            #region Push a deployment package to Azure
            $azureModuleInstalled = Import-Module Azure -Global -PassThru
            if (-not $azureModuleInstalled) {
                Write-Error "Must install Azure module"
                return
            }
            $currentDeployment = Get-AzureDeployment -ServiceName $ServiceName

            $newlabel = if ($currentDeployment.label -ne $FirstLabel) {
                $FirstLabel
            } else {
                $SecondLabel
            }

            $resolvedPackagePath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($PackagePath)
            if (-not $resolvedPackagePath) { return } 
            $resolvedConfigPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($ConfigurationPath)
            if (-not $resolvedConfigPath) { return } 

            Remove-AzureDeployment -ServiceName $ServiceName -Slot Staging -Force -ErrorAction SilentlyContinue

            $deploymentParameters = @{
                Package=  "$resolvedPackagePath"
                Configuration =  "$resolvedConfigPath"
                Label = $newLabel
            }

        
            New-AzureDeployment @deploymentParameters -ServiceName $ServiceName -Slot Staging 
            #endregion Push a deployment package to Azure
        } elseif ($pscmdlet.ParameterSetName -eq 'PushToAzureVMs') {
            #region Push a deployment stored in blob storage into Azure VMs

            $params = @{} + $PSBoundParameters
$sb = {
    Add-Type -AssemblyName System.Web

}.ToString() + @"
function Expand-Zip {
    $((Get-Command Expand-Zip).Definition)
}

function Get-Web {
    $((Get-Command Get-Web).Definition)
}

function Import-Blob {
    $((Get-Command Import-Blob).Definition)
}

function Get-Blob {
    $((Get-Command Get-Blob).Definition)
}
"@


$sb = [ScriptBlock]::Create($sb)


$syncScript = "
`$null = New-module -Name Pipeworks -ScriptBlock {$sb} 
`$storageAccount = '$storageAccount'
`$storageKey = '$storageKey'
"
$syncScript += {
# Move modules to old modules


Get-Blob -StorageAccount $StorageAccount -StorageKey $StorageKey | 
    Where-Object {$_.Container -like "*-source" } |
    ForEach-Object {
        
        $innerData = $_ | 
            Get-Blob | 
            Sort-Object { $_.LastModified } -Descending | 
            Select-Object -First 1 | 
            Get-Blob         
            
            
            
        $tempDir = [IO.Path]::GetTempPath()    
        $theFile = Join-Path $tempDir ($innerData.Container + $innerData.Name) 
        $theTempDir = Join-Path $tempDir $innerData.Container

        [IO.FILE]::WriteAllBytes("$theFile", $innerData.BlobData)


        

        Expand-Zip -ZipPath "$theFile" -OutputPath $theTempDir 

        $moduleDir = 
            dir $theTempDir -Recurse -Filter "$($innerData.Container.Replace("-source", '')).psm1" | 
            Split-Path | 
            Get-Item            

       

        if (-not $moduleDir) { return } 
        $destModuleDir = "$env:UserProfile\Documents\WindowsPowerShell\Modules\$($moduleDir.Name.Replace('-source', ''))"


        if (Test-Path $destModuleDir) {
            $destModuleDir | Remove-Item -Recurse -Force
        }        

        $null = New-Item -ItemType Directory -path $destModuleDir -ErrorAction SilentlyContinue

        
        
        $moduleName = $moduleDir | Split-Path -Leaf
            
        $dir = Get-Item $destModuleDir
        $filesExist = dir $moduleDir -Recurse -Force |
            Where-Object { -not $_.psIsContainer }
                
        if ($filesExist) {
            Move-Item "$env:UserProfile\Documents\WindowsPowerShell\Modules\$moduleName" "$env:UserProfile\Documents\WindowsPowerShell\Modules.Old.$((Get-Date).ToShortDateString().Replace('/','-'))" -ErrorAction SilentlyContinue  -Force

            $filesExist |
                ForEach-Object {
                    $_ | 
                        Copy-Item -Destination {                                                
                            $newPath = $_.FullName.Replace("$($moduleDir.Fullname)", "$($dir.FullName)")
                            
                            $newDir = $newPAth  |Split-Path
                            if (-not (Test-Path $newDir)) {
                                $null = New-Item -ItemType Directory -Path "$newDir" -Force
                            }
                            
                            
                            Write-Progress "Copying $($req.name)" "$newPath"
                            $newPath             
                            
                        } -Force
                }
        } 
                

            
        Remove-Item -LiteralPath $theTempDir -Force -Recurse

        
 
        






    } 


    
    #Move-Item "$home\Documents\WindowsPowerShell\SyncedModules" "$home\Documents\WindowsPowerShell\SyncedModules"

}

    
$syncScript = [ScriptBlock]::Create($syncScript)
Get-AzureVM |
    Where-Object {
        $comp = $_
        if ($params.ComputerName) {
            foreach ($cn in $ComputerName) {
                if ($comp.Name -like $cn) {
                    return $true 
                }
            }
        } else {
            return $true 
        }
    } |
    ForEach-Object {
        Invoke-Command -ComputerName "$($_.Name).cloudapp.net" -Credential $Credential -Authentication Credssp -ScriptBlock $syncScript -AsJob -JobName $_.Name
    }
            #endregion Push a deployment stored in blob storage into Azure VMs            
        } elseif ($PSCmdlet.ParameterSetName -eq 'PushToLan') {
            



        }
        
        
    }
}

