function Get-Walkthru {
    <#
    .Synopsis
        Gets information from a file as a walkthru
    .Description
        Parses walkthru steps from a walkthru file.  
        Walkthru files contain step-by-step examples for using PowerShell.        
    .Link
        Write-WalkthruHTML
    .Example
        Get-Walkthru -Text {
# Walkthrus are just scripts with comments that start at column 0.


# Step 1:
Get-Process        

#Step 2:
Get-Command
        }
    #>
    [CmdletBinding(DefaultParameterSetName="File")]
    [OutputType([PSObject])]
    param(
    # The command used to generate walkthrus
    [Parameter(Mandatory=$true,
        ParameterSetName="Command",
        ValueFromPipeline=$true)]
    [Management.Automation.CommandInfo]
    $Command,
    
    # The module containing walkthrus
    [Parameter(Mandatory=$true,
        ParameterSetName="Module",
        ValueFromPipeline=$true)]
    [Management.Automation.PSModuleInfo]
    $Module,
        
    # The file used to generate walkthrus
    [Parameter(Mandatory=$true,
        ParameterSetName="File",
        ValueFromPipelineByPropertyName=$true)]    
    [Alias('Fullname')]
    [string]$File,
    
    # The text used to generate walkthrus
    [Parameter(Mandatory=$true,
        ParameterSetName="Text")]    
    [String]$Text,
    
    # The script block used to generate a walkthru
    [Parameter(Mandatory=$true,
        ParameterSetName="ScriptBlock")]    
    [ScriptBlock]$ScriptBlock
    )
    
    begin {
        $err = $null
        #region Create walkthru type if it doesn't exist
        if (-not ('PSWalkthru.WalkthruData' -as [Type])) {
            Add-Type -UsingNamespace System.Management.Automation -Namespace PSWalkthru -Name WalkthruData -MemberDefinition '
public string SourceFile = String.Empty;','
public string Command = String.Empty;','
public string Explanation = String.Empty;','
public string AudioFile = String.Empty;','
public string VideoFile = String.Empty;','
public string Question = String.Empty;','
public string Answer = String.Empty;','
public string Link = String.Empty;','
public string Screenshot = String.Empty;','
public string[] Hint;','
public ScriptBlock Script;
public ScriptBlock Silent;','
public DateTime LastWriteTime;
'
        }
        #endregion Create walkthru type if it doesn't exist
    }
    process {
        if ($psCmdlet.ParameterSetName -eq "File") {
            # If the walkthru's in a file, open it and send it to Get-Walthru -Text
            $realItem = Get-Item $file -ErrorAction SilentlyContinue
            if (-not $realItem) { return } 
            $text = [IO.File]::ReadAllText($realItem.FullName)                        
            $Result = Get-Walkthru -Text $text
            if ($result) {
                # If there was in fact walkthru information, add on the file name and the last write time.
                foreach ($r in $result) {
                    $r.Sourcefile = $realItem.Fullname                    
                    $r.LastWriteTime = $realItem.LastWriteTime
                    $r
                }
            }
            return
        } elseif ($psCmdlet.ParameterSetName -eq "Command") {
            # If they want to see a command's examples a a walkthru, then pass each example to Get-Walkthru -Text
            $help = $command | Get-Help 
            
            $c= 1
            $help.Examples.Example | 
                ForEach-Object {
                    $text = $_.code + ($_.remarks | Out-String)                
                    Get-Walkthru -Text $text |
                        ForEach-Object {
                            $_.Command = "$command Walkthru $c"
                            $_
                        }
                    $c++
                }
            return
        } elseif ($psCmdlet.ParameterSetName -eq 'Module') {
            # For modules, enumerate all files for the current culture, then pass them down to Get-Walkthru -File
            $moduleRoot = Split-Path $module.Path
            Get-ChildItem -Path (Join-Path $moduleRoot "$(Get-Culture)") -Filter *.walkthru.help.txt | 
                Get-Walkthru   
            return         
        }
        
        if ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $text = "$ScriptBlock"
        }
            
        # Tokenize the script                           
        $tokens = [Management.Automation.PSParser]::Tokenize($text, [ref]$err)                
        if ($err.Count) { return } 

        $lastToken = $null
        $isInContent = $false
        $lastResult = New-Object PSWalkthru.WalkthruData

        foreach ($token in $tokens) { 
            if ($token.Type -eq "Newline") { continue }
            if ($token.Type -ne "Comment" -or $token.StartColumn -gt 1) {
                $isInContent = $true
                if (-not $lastToken) { $lastToken = $token } 
            } else {
                if ($lastToken.Type -ne "Comment" -and $lastToken.StartColumn -eq 1) {
                    $chunk = $text.Substring($lastToken.Start, 
                        $token.Start - 1 - $lastToken.Start)
                    $lastResult.Script = [ScriptBlock]::Create($chunk)
                    # mutliparagraph, split up the results if multiparagraph
                    
                    $paragraphs = @()                    
                    $lastResult                    
                    $null = $paragraphs
                    $lastToken = $null
                    $lastResult = New-Object PSWalkthru.WalkthruData
                    $isInContent = $false                
                }
            }

            if ($isInContent) {
                if ($token.Type -eq 'Comment' -and $token.StartColumn -eq 1) {
                    $chunk = $text.Substring($lastToken.Start, 
                        $token.Start - 1 - $lastToken.Start)
                    $lastResult.Script = [ScriptBlock]::Create($chunk)
                    # mutliparagraph, split up the results if multiparagraph
                    
                    $paragraphs = @()                    
                    $lastResult                    
                    $null = $paragraphs
                    $lastToken = $null
                    $lastResult = New-Object PSWalkthru.WalkthruData
                    $isInContent = $false                
                }
            }
            if (-not $isInContent) {
                $lines = $token.Content.Trim("<>#")
                $lines = $lines.Split([Environment]::NewLine, 
                    [StringSplitOptions]"RemoveEmptyEntries")
                # Handle specialized return data
                foreach ($_ in $lines) {
                    if ($_ -like ".Audio *" ) {
                        $lastResult.AudioFile = ($_ -ireplace "\.Audio","").Trim()
                    } elseif ($_ -like ".Video *" ) {
                        $lastResult.VideoFile = ($_ -ireplace "\.Video","").Trim()
                    } elseif ($_ -like ".Question *"){
                        $lastResult.Question = ($_ -ireplace "\.Question","").Trim()
                    } elseif ($_ -like ".Answer *" ) {
                        $lastResult.Answer = ($_ -ireplace "\.Answer","").Trim()
                    } elseif ($_ -like ".Hint *") {
                        $lastResult.Hint = $_.Substring(".Hint ".Length) -split ','
                    } elseif ($_ -like ".Link *") {
                        $lastResult.Link = ($_ -ireplace "\.link","").Trim()
                    } elseif ($_ -like ".Screenshot *") {
                        $lastResult.Screenshot = ($_ -ireplace "\.Screenshot","").Trim()
                    } elseif ($_ -like "*.Silent *") {
                        $lastResult.Silent = [ScriptBlock]::Create(($_ -ireplace "\.Silent","").Trim())
                    } else {
                        if ($_.TrimEnd().EndsWith(".")) {
                            $lastResult.Explanation += ($_ + [Environment]::NewLine + [Environment]::NewLine + [Environment]::NewLine  )                        
                        } else {
                            $lastResult.Explanation += ($_ + [Environment]::NewLine)                        
                        }
                            
                    }
                    
                }
            }           
        }
        
        
        if ($lastToken -and $lastResult) {
            $chunk = $text.Substring($lastToken.Start)
            $lastResult.Script = [ScriptBlock]::Create($chunk)
            $lastResult
        } elseif ($lastResult) {
            $lastResult
        }        
    }
}
