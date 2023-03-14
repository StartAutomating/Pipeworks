foreach ($file in (Get-ChildItem -Path "$psScriptRoot" -Filter "*-*.ps1" -Recurse)) {
    if ($file.Extension -ne '.ps1')      { continue }  # Skip if the extension is not .ps1
    if ($file.Name -match '\.[^\.]+\.ps1$') { continue }  # Skip if the file is an unrelated file.
    . $file.FullName
}

#region Initialize Shared Data
$script:FunctionsInEveryRunspace = 
    'Get-Web', 'Get-PipeworksManifest', 'Get-WebInput', 'Invoke-WebCommand', 'Request-CommandInput', 'New-Region', 'New-WebPage', 
    'Out-Html',  'Write-Css', 'Write-Host', 'Write-Link', 'Write-ScriptHTML', 'Write-PowerShellHashtable', 'Compress-Data', 
    'Expand-Data', 'Import-PSData', 'Export-PSData', 'Get-SecureSetting', 'Get-Hash'

#endregion
Add-Type -AssemblyName System.Web, System.Xml.Linq

#region Initialize Parts if not running in Web context
if (-not ($request -and $response)) {
    $allParts = Get-ChildItem -Path $psScriptRoot\Parts -Filter *.ps1 

    foreach ($part in $allParts) {
        $nameWithoutExtension = $part.Name.Substring(0, $part.Name.Length - $part.Extension.Length)
        $ExecutionContext.SessionState.PSVariable.Set($nameWithoutExtension, $ExecutionContext.InvokeCommand.GetCommand($part.Fullname, 'ExternalScript'))
    }

    $allHandlers = Get-ChildItem -Path $psScriptRoot\Parts -Filter *.ps1 
    foreach ($part in $allHandlers) {
        $nameWithoutExtension = $part.Name.Substring(0, $part.Name.Length - $part.Extension.Length)
        $ExecutionContext.SessionState.PSVariable.Set($nameWithoutExtension, $ExecutionContext.InvokeCommand.GetCommand($part.Fullname, 'ExternalScript'))
    }
}
#endRegion Initialize Parts if not running in Web

Set-Alias cms ConvertTo-ModuleService
Set-Alias Publish-WebService Publish-WebSite
Set-Alias pws Publish-WebSite
Set-Alias psnode Start-PSNode
Set-Alias ohtml Out-HTML
Set-Alias markdown ConvertFrom-Markdown
Set-Alias gweb Get-Web
Set-Alias sql Select-SQL
Set-Alias iwc Invoke-WebCommand
Set-Alias impsd1 Import-PSData
Set-Alias expsd1 Export-PSData
Set-Alias imblob Import-Blob
Set-Alias exblob Export-Blob

Set-Alias gblob Get-Blob
Set-Alias rmblob Remove-Blob

Set-Alias Remove-Service -Value Remove-Daemon

Export-ModuleMember -Function * -Alias * -Cmdlet *

return
