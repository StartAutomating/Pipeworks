function Write-ScriptHTML 
{
     <#
    .Synopsis
        Writes Windows PowerShell as colorized HTML
    .Description
        Outputs a Windows PowerShell script as colorized HTML.
        The script is wrapped in HTML PRE  tags with SPAN tags defining color regions.
    .Example
        Write-ScriptHTML {Get-Process}    
    .Link
        ConvertFrom-Markdown  
    #>
    [CmdletBinding(DefaultParameterSetName="Text")]
    [OutputType([string])]
    param(   
    # The Text to colorize
    [Parameter(Mandatory=$true,
        ParameterSetName="Text",
        Position=0,
        ValueFromPipeline=$true)]
    [Alias('ScriptContents')]
    [ScriptBlock]$Text,
    
    
    # The script as a string.
    [Parameter(Mandatory=$true,
        ParameterSetName="ScriptString",
        Position=0,
        ValueFromPipelineByPropertyName=$true)]    
    [string]$Script,
    
    # The start within the string to colorize    
    [Int]$Start = -1,
    # the end within the string to colorize    
    [Int]$End = -1,        
        
    # The palette of colors to use.  
    # By default, the colors will be the current palette for the
    # Windows PowerShell Integrated Scripting Environment
    $Palette = $Psise.Options.TokenColors,

    # If set, will include the script within a span instead of a pre tag
    [Switch]$NoNewline,
    
    # If set, will treat help within the script as markdown
    [Switch]$HelpAsMarkdown, 

    # If set, will not put a white background and padding around the script
    [Switch]$NoBackground
    )
    
    begin {
        #region Color Palettes
        function New-ScriptPalette
        {
            param(
            $Attribute = "#FFADD8E6",
            $Command = "#FF0000FF",
            $CommandArgument = "#FF8A2BE2",   
            $CommandParameter = "#FF000080",
            $Comment = "#FF006400",
            $GroupEnd = "#FF000000",
            $GroupStart = "#FF000000",
            $Keyword = "#FF00008B",
            $LineContinuation = "#FF000000",
            $LoopLabel = "#FF00008B",
            $Member = "#FF000000",
            $NewLine = "#FF000000",
            $Number = "#FF800080",
            $Operator = "#FFA9A9A9",
            $Position = "#FF000000",
            $StatementSeparator = "#FF000000",
            $String = "#FF8B0000",
            $Type = "#FF008080",
            $Unknown = "#FF000000",
            $Variable = "#FFFF4500"        
            )
    
            process {
                $NewScriptPalette= @{}
                foreach ($parameterName in $myInvocation.MyCommand.Parameters.Keys) {
                    $var = Get-Variable -Name $parameterName -ErrorAction SilentlyContinue
                    if ($var -ne $null -and $var.Value) {
                        if ($var.Value -is [Collections.Generic.KeyValuePair[System.Management.Automation.PSTokenType,System.Windows.Media.Color]]) {
                            $NewScriptPalette[$parameterName] = $var.Value.Value
                        } elseif ($var.Value -as [Windows.Media.Color]) {
                            $NewScriptPalette[$parameterName] = $var.Value -as [Windows.Media.Color]
                        }
                    }
                }
                $NewScriptPalette    
            }
        }
        #endregion Color Palettes                                         
        Set-StrictMode -Off
        Add-Type -AssemblyName PresentationCore, PresentationFramework, System.Web
    }
        
    process {
        if (-not $Palette) {
            $palette = @{} 
        }
        
        if ($psCmdlet.ParameterSetName -eq 'ScriptString') {
            $text = [ScriptBLock]::Create($script)
        }
        

        if ($Text) {
            #
            # Now parse the text and report any errors...
            #
            $parse_errs = $null
            $tokens = [Management.Automation.PsParser]::Tokenize($text,
                [ref] $parse_errs)
         
            if ($parse_errs) {
                $parse_errs | Write-Error
                return
            }
            $stringBuilder = New-Object Text.StringBuilder
            $backgroundAndPadding = 
                if (-not $NoBackground) {
                    "background-color:#fefefe;padding:5px"
                } else {
                    ""
                }
                        
            $null = $stringBuilder.Append("<$(if (-not $NoNewline) {'pre'} else {'span'}) class='PowerShellColorizedScript' style='font-family:Consolas;$($backgroundAndPadding)'>")
            # iterate over the tokens an set the colors appropriately...
            $lastToken = $null
            $ColorPalette = New-ScriptPalette @Palette
            $scriptText = "$text" 
            $c = 0  
            $tc = $tokens.Count 
            foreach ($t in $tokens)
            {
                $C++
                if ($c -eq $tc) { break } 
                if ($lastToken) {
                    $spaces = "&nbsp;" * ($t.Start - ($lastToken.Start + $lastToken.Length))
                    $null = $stringBuilder.Append($spaces)
                }
                if ($t.Type -eq "NewLine") {
                    $null = $stringBuilder.Append("            
")
                } else {
                    $chunk = $scriptText.SubString($t.start, $t.length).Trim()                    
                    if ($t.Type -eq 'Comment' -and $HelpAsMarkdown) {
                        if ($chunk -like "#*") {
                            $chunk = $chunk.Substring(1)
                        }
                        $chunk =  "<p>" + (ConvertFrom-Markdown -Markdown $chunk) + "</p>"
                    }
                    
                    $color = $ColorPalette[$t.Type.ToString()]            
                    $redChunk = "{0:x2}" -f $color.R
                    $greenChunk = "{0:x2}" -f $color.G
                    $blueChunk = "{0:x2}" -f $color.B
                    $colorChunk = "#$redChunk$greenChunk$blueChunk"                    
                    $null = $stringBuilder.Append("<span style='color:$colorChunk'>$([Web.HttpUtility]::HtmlEncode($chunk).Replace('&amp;','&').Replace('&quot;','`"'))</span>")                    
                }                       
                $lastToken = $t
            }
            $null = $stringBuilder.Append("</$(if (-not $NoNewline) {'pre'} else {'span'})>")
            
            
            $stringBuilder.ToString()
        }
    }
}
