function Write-WalkthruHTML
{
    <#
    .Synopsis
        Writes a walkthru HTML file
    .Description
        Writes a section of HTML to walk thru a set of code.
    .Example
        Write-WalkthruHTML -Text @"
#a simple demo
Get-Help about_walkthruFiles
"@
    .Link
        Get-Walkthru
        Write-ScriptHTML    
    #>
    [CmdletBinding(DefaultParameterSetName='Text')]  
    [OutputType([string])]  
    param(    
    # The text used to generate walkthrus
    [Parameter(Position=0,Mandatory=$true,
        ParameterSetName="Text",
        ValueFromPipeline=$true)]    
    [ScriptBlock]$ScriptBlock,    
    
    # A walkthru object, containing a source file and a property named
    # walkthru with several walkthru steps
    [Parameter(Position=0,Mandatory=$true,        
        ParameterSetName="Walkthru",
        ValueFromPipeline=$true)]    
    [PSObject]$WalkThru,
    
    # with a different step on each layer
    [Parameter(Position=1)]
    [Switch]$StepByStep,

    # If set, will run each demo step
    [Parameter(Position=2)]
    [Switch]$RunDemo,

    # If set, output will be treated as HTML.  Otherwise, output will be piped to Out-String and embedded in <pre> tags.
    [Parameter(Position=3)]
    [Switch]$OutputAsHtml,

    # If set, will start with walkthru with a <h3></h3> tag, or include the walkthru name on each step
    [Parameter(Position=4)]
    [string]$WalkthruName,
    
    # If set, will embed the explanation as text, instead of converting it to markdown.
    [Parameter(Position=5)]
    [switch]$DirectlyEmbedExplanation,
    
    # If provided, will only include certain steps
    [Parameter(Position=6)]
    [Uint32[]]$OnlyStep    
    )
    
    process {
        if ($psCmdlet.ParameterSetName -eq 'Text') {                        
            Write-WalkthruHTML -Walkthru (Get-Walkthru -Text "$ScriptBlock") -StepByStep:$stepByStep
        } elseif ($psCmdlet.ParameterSetName -eq 'Walkthru') {            
            $NewRegionParameters = @{
                Layer = @{}
                Order = @()
                HorizontalRuleUnderTitle = $true                                
            }                                   
                        
            $walkThruHTML = New-Object Text.StringBuilder
            
            
            $count = 1
            $total = @($walkThru).Count
            foreach ($step in $walkThru) {
                
                # if it's provided, skip stuff that's not in OnlyStep 
                if ($OnlySteps) {                    
                    if ($OnlySteps -notcontains $count){
                        continue
                    }
                }

                # If we're going step by step, then we need to reset the string builder each time 
                if ($stepByStep) {                      
                    $walkThruHTML = New-Object Text.StringBuilder 
                }     
                
                if ($DirectlyEmbedExplanation -or $step.Explanation -like "*<*") {
                
                $null = $walkThruHtml.Append("

                <div class='ModuleWalkthruExplanation'>
                $($step.Explanation.Replace([Environment]::newline, '<BR/>'))
                </div>")
                } else {
                    $null = $walkThruHtml.Append("

                <div class='ModuleWalkthruExplanation'>
                $(ConvertFrom-Markdown -Markdown "$($step.Explanation) ")
                </div>")
                }
                if ($step.VideoFile -and $step.VideoFile -like "http*") {
                    if ($step.VideoFile -like "http://www.youtube.com/watch?v=*") {
                        $uri = $step.VideoFile -as [uri]
                        $type, $youTubeId = $uri.Query -split '='
                        $type = $type.Trim("?")
                        $null = 
                            $walkThruHtml.Append(@"                                    
<br/>
<embed type="application/x-shockwave-flash" width="425" height="344" src="http://www.youtube.com/${type}/${youTubeId}?hl=en&amp;fs=1&amp;modestbranding=true" allowscriptaccess="always" allowfullscreen="true">
"@)
                    } elseif ($step.VideoFile -like "http://player.vimeo.com/video/*") {
                        $vimeoId = ([uri]$step.VideoFile).Segments[-1]
                        $null = 
                            $walkThruHtml.Append(@"
<br/>
<iframe src="http://player.vimeo.com/video/${vimeoId}?title=0&amp;byline=0&amp;portrait=0" width="400" height="245" frameborder="0">
</iframe><p><a href="http://vimeo.com/{$vimeoId}">$($walkThru.Explanation)</a></p>

"@)
                    } else {
                        $null = 
                            $walkThruHtml.Append("
                            <br/>
                            <a class='ModuleWalkthruVideoLink' href='$($step.VideoFile)'>Watch Video</a>")
                    }   
                }
                $null = $walkThruHtml.Append("<br/></p>")  
                
                if (("$($step.Script)".Trim())-and ("$($step.Script)".Trim() -ne '$null')) {
                    $scriptHtml = Write-ScriptHTML -Text $step.Script 
                    $null = $walkThruHtml.Append(@"
<p class='ModuleWalkthruStep'>
$scriptHtml
</p>
"@)                            
                }

                if ($RunDemo) {
                    $outText = . $step.Script
                    if (-not $OutputAsHtml) {
                    $null = $walkThruHtml.Append("<pre class='ModuleWalkthruOutput' foreground='white' background='#012456'>$([Security.SecurityElement]::Escape(($outText | Out-String)))</pre>")                        
                    } else {
                        if ($outText -is [Hashtable]) {
                            $null = $walkThruHtml.Append("$(Write-PowerShellHashtable -inputObject $OutText) ")
                        } elseif ($outText -is [ScriptBlock]) {
                            $null = $walkThruHtml.Append("$(Write-ScriptHtml -Text $OutText) ")
                        } else {
                            $null = $walkThruHtml.Append("$OutText")
                        }
                        
                    }
                }
                if ($stepByStep) {
                    $NewRegionParameters.Layer."$Count of $Total" = "<div style='margin-left:15px;margin-top:15px;'>$walkThruHTML</div>"
                    $NewRegionParameters.Order+= "$Count of $Total" 
                    
                }                
                $Count++                                    
            }
            
            if (-not $stepByStep) { 
                "$walkThruHTML"
            } else {
                if ($WalkthruName) {
                    New-Region @newRegionParameters -AsFeaturette -ShowLayerTitle -LayerId "Walkthru_$WalkthruName"
                } else {
                    New-Region @newRegionParameters -AsFeaturette -ShowLayerTitle -LayerUrl "RandomWalkthru_$(Get-random)"
                }
                
            }
            
            
                
            }
        
    }
}
