function Write-CSS
{
    <#
    .Synopsis
        Writes CSS styles 
    .Description
        Writes CSS style tags, CSS attributes, and links to external stylesheets
    .Example
        # Create a new CSS Style named reallyimportant
        Write-CSS -Name '#ReallyImportant' -Style @{
            "font-size" = "x-large"
            "font-weight"="bold"
        }
    .Example
        Write-CSS -OutputAttribute -Style @{
            "font-size" = "x-large"
            "font-weight"="bold"
        }    
    .Example
        Write-CSS -ExternalStyleSheet MyStyleSheet.css 
    .Example
        Write-CSS -Css @{
            "a"=@{
                "font-size"="x-large"
            }
        }
    .Link
        New-WebPage
    .Link
        Out-HTML
    .Link
        Write-Link
    #>    
    [CmdletBinding(DefaultParameterSetName='StyleDefinition')]
    [OutputType([string])]
    param(
    # The name of the css style
    [Parameter(Mandatory=$true,
        Position=0,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="StyleDefinition")]
    [string]
    $Name,
    
    # The css values for a named style or a style attribute
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=0,
        ParameterSetName="StyleAttribute")]
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        Position=1,
        ParameterSetName="StyleDefinition")]
    [Hashtable]
    $Style,

    # A CSS table, containing nested tables of styles
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="Table")]
    [Hashtable]
    $Css,

    # If set, will not output a style tag when outputting a CSS table.
    [Parameter(
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="Table")]
    [switch]
    $NoStyleTag,

    
    # A path to an external syle sheet
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="StyleSheet")]
    [uri]
    $ExternalStyleSheet,
    
    # If set, will output the attributes of a style
    [Parameter(Mandatory=$true,
        ValueFromPipelineByPropertyName=$true,
        ParameterSetName="StyleAttribute")]
    [switch]
    $OutputAttribute
    ) 
    
    process {
        if ($pscmdlet.ParameterSetName -eq 'StyleSheet') {
            "<link rel='stylesheet' type='text/css' href='$ExternalStyleSheet' />"
        } elseif ($pscmdlet.ParameterSetName -eq 'Table') {
            $cssLines = foreach ($kv in $css.GetEnumerator()) {
                $name = $kv.Key 
                
                Write-CSS -Name $name -Style $kv.Value
            }
"$(if (-not $NoStyleTag) { '<style type=''text/css''>' })
$cssLines
$(if (-not $NoStyleTag) { '</style>'})"
        } elseif ($pscmdlet.ParameterSetName -eq 'StyleDefinition') {
            $cssText = foreach ($kv in $Style.GetEnumerator()) {
                "$($kv.Key):$($kv.Value)"
            }
            $cssText = $cssText -join ";$([Environment]::NewLine)    "
            "$name {
    $cssText
}"            
        } elseif ($pscmdlet.ParameterSetName -eq 'StyleAttribute') {
                            
            # Just in case they called the command with splatting, fall back on the keys 
            # (which will not preserve order)            
            
            @(foreach ($kv in $style.Keys) {
                if ($style[$kv]) {
                    "$($kv):$($style[$kv])"
                }
            }) -join ';'
            
        }
    }
}
