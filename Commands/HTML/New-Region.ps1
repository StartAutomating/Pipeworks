function New-Region
{
    <#
    .Synopsis
        Creates a new web region.
    .Description             
        Creates a new web region.  Web regions are lightweight HTML controls that help you create web pages.
    .Link
        New-Webpage        
        
    .Example
        # Makes a JQueryUI tab
        New-Region -Layer @{
            "Tab1" = "Content In Tab One"
            "Tab2" = "Content in Tab Two"
        } -AsTab
    .Example
        # Makes a JQueryUI accordian
        New-Region -Layer @{
            "Accordian1" = "Content In The first Accordian"
            "Accordian1" = "Content in the second Accordian"
        } -AsAccordian
    .Example
        # Makes an empty region
        New-Region -Style @{} -Content "My Layer" -LayerID MyId
    .Example
        # A Centered Region containing Microdata
        New-Region -ItemType http://schema.org/Event -Style @{
            'margin-left' = '7.5%'
            'margin-right' = '7.5%'
        } -Content '
<a itemprop="url" href="nba-miami-philidelphia-game3.html">
NBA Eastern Conference First Round Playoff Tickets:
<span itemprop="name"> Miami Heat at Philadelphia 76ers - Game 3 (Home Game 1) </span>  </a> 
<meta itemprop="startDate" content="2016-04-21T20:00">    Thu, 04/21/16    8:00 p.m.  
<div itemprop="location" itemscope itemtype="http://schema.org/Place">    
    <a itemprop="url" href="wells-fargo-center.html">    Wells Fargo Center    </a>    
    <div itemprop="address" itemscope itemtype="http://schema.org/PostalAddress">      
        <span itemprop="addressLocality">Philadelphia</span>,      <span itemprop="addressRegion">PA</span>    
    </div>  
</div>  
<div itemprop="offers" itemscope itemtype="http://schema.org/AggregateOffer">
    Priced from: <span itemprop="lowPrice">$35</span>    <span itemprop="offerCount">1938</span> tickets left  
</div>'        
    .Notes
        The Parameter set design on New-Region is a little complex.  
        
        There are two base parameter sets, raw layer content (-Content) and structured layer content (-Layer)

        In each case, parameters named -As* determine how the actual layer will be rendered.

        To make matters more complex, different -As* parameters require different JavaScript frameworks        
    #>
    [CmdletBinding(DefaultParameterSetName='Content')]
    [OutputType([string])]
    param(
    # The content within the region.  This content will be placed on an unnamed layer.
    [Parameter(ParameterSetName='Content',Position=0,ValueFromPipeline=$true)]
    [string[]]$Content,
    # A set of layer names and layer content 
    [Parameter(ParameterSetName='Layer',Position=0)]
    [Alias('Item')]
    [Hashtable]$Layer,
    # A set of layer names and layer URLs.  Any time the layer is brought up, the content will be loaded via AJAX
    [Parameter(ParameterSetName='Layer')]
    [Hashtable]$LayerUrl = @{},

    # A set of layer direct links
    [Parameter(ParameterSetName='Layer')]
    [Hashtable]$LayerLink = @{},

   
    
    # The order the layers should appear.  If this is not set, the order will
    # be the alphabetized list of layer names.
    [Parameter(ParameterSetName='Layer')]
    [Alias('LayerOrder')]
    [string[]]$Order,
    # The default layer.  If this is not set and if -DefaultToFirst is not set, a layer 
    # will be randomly chosen.
    [Parameter(ParameterSetName='Layer')]
    [string]$Default,
    # The default layer.  If this is not set and if -DefaultToFirst is not set, a layer 
    # will be randomly chosen.
    [Parameter(ParameterSetName='Layer')]
    [switch]$DefaultToFirst,
    # The Name of the the container.  The names becomes the HTML element ID of the root container.
    [Alias('Container')]
    [Alias('Id')]
    [string]$LayerID = 'Layer',
    # The percentage margin on the left.  The region will appear this % distance from the side of the screen, regardless of resolution
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=1)]
    [ValidateRange(0,100)]
    [Double]$LeftMargin = 2.5,
    # The percentage margin on the right.  The region will appear this % distance from the side of the screen, regardless of resolution
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=2)]
    [ValidateRange(0,100)]
    [Double]$RightMargin = 2.5,        
    # The percentage margin on the top.  The region will appear this % distance from the top of the screen, regardless of resolution
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=3)]
    [ValidateRange(0,100)]
    [Double]$TopMargin = 10,
    # The percentage margin on the bottom.  The region will appear this % distance from the bottom of the screen, regardless of resolution
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=4)]
    [ValidateRange(0,100)]
    [Double]$BottomMargin = 10,
    # The border for the region.  Becomes the CSS border attribute of the main container
    [string]$Border = "1px solid black",
    
    # If set, hides the forward and back buttons
    [switch]$HideDirectionButton,
    # If set, hides the more button
    [switch]$HideMoreButton,
    # If set, hides the title area
    [switch]$HideTitleArea,
    # If set, shows a horizontal rule under the title
    [switch]$HorizontalRuleUnderTitle,
    
    # If set, places the toolbar above
    [switch]$ToolbarAbove,
    # The margin of the toolbar
    [int]$ToolbarMargin,
    # URL for a logo to go on the title of each page
    [uri]$Logo,    
    
    # If set, the control will not be aware of the web request string.
    # Otherwise, a URL can provide which layer of a region to show.
    [switch]$NotRequestAware,
    
    # If set, the region will have any commands to change its content, 
    # and will only have one layer
    [switch]$IsStaticRegion,        
    
    # If set, turns off fade effects
    [switch]$NotCool,
    
    # The transition time for all fade effects.  Defaults to 200ms
    [Timespan]$TransitionTime = "0:0:0.2",

    # The layer heading size
    [ValidateRange(1, 6)]
    [Uint32]$LayerHeadingSize = 2,

    
    # The number of keyframes in all transitions
    [ValidateRange(10, 100)]
    [Uint32]$KeyFrameCount = 10,
    
    # If set, enables a pan effect within the layers
    [Switch]$CanPan,
    
    # If set, the entire container can be dragged
    [Switch]$CanDrag,        
  
    # The scroll speed (when on iOs or webkit)
    [int]$ScrollSpeed = 25,
    
    # The CSS class to use 
    [string[]]$CssClass,
    
    # A custom CSS style.
    [Hashtable]$Style,
    
    # If set, the layer will not be automatically resized, and percentage based margins will be ignored
    [switch]$FixedSize,
    
    # If set, will not allow the contents of the layer to be switched
    [switch]$DisableLayerSwitcher,
    
    # If set, will automatically switch the contents on an interval
    [Parameter(ParameterSetName='Layer')]
    [Timespan]$AutoSwitch = "0:0:4",
    
    # If set, will create the region as an JQueryUI Accordion.
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsAccordian,
    
    # If set, will create the region as an JQueryUI Tab.
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsTab,
    
    # If set, the JQueryUI tab will appear below the content, instead of above
    [Parameter(ParameterSetName='Layer')]
    [Switch]$TabBelow,
    
    # If set, will open the tabs on a mouseover event
    [Switch]$OpenOnMouseOver,
    
    # If set, will create a set of popout regions.  When the tile of each layer is clicked, the layer will be shown.
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsPopout,
    
    # If set, will create a set of popdown regions.  As region is clicked, the underlying content will be shown below.
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsPopdown,

    # If set, will create a set of popdown regions.  As region is clicked, the underlying content will be shown below.
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsPopIn,
    
    # If set, will create a slide of the layers.  If a layer title is clicked, the slideshow will stop
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsSlideShow,
    
    # If set, the layer will be created as a portlet
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsPortlet,

    # If set, the layer will be created as a newspaper
    [Parameter(ParameterSetName='Layer')]
    [Switch]$AsNewspaper,

    # If set, the newspaper headline buttons will be underlined
    [Switch]$UnderlineNewspaperHeadline,

    # If set, newspaper headlines will be displayed as buttons
    [Switch]$UseButtonForNewspaperHeadline,

    # The alignment used for the heading in a newspaper
    [ValidateSet("left", "center", "right")]
    [string]$NewspaperHeadingAlignment = "left",

    # The size of the headings in a newspaper
    [ValidateRange(1,6)]
    [Uint32] 
    $NewspaperHeadingSize = 2,

    # The width of the columns in the newspaper
    [Float[]]$NewspaperColumn = @(.67, .33, .5, .5, 1),

    # The columns that will be expanded
    [string[]]$ExpandNewspaperColumn = @(0, 1, 2, 3),
    
    # The number of columns in a Portlet
    [Uint32]$ColumnCount = 2,
    
    # The width of a column within a Portlet
    [string]$ColumnWidth,
        
    # If set, will create a set of JQueryUI buttons which popup JQueryUI dialogs
    [Switch]$AsPopup,
    
    
    # If set, will create a set of JQueryUI simple widgets
    [Switch]$AsWidget,
    
    # If set, will create the layer as a series of resizable items
    [Switch]$AsResizable,

    # If set, will create the layer as a series of draggable items
    [Switch]$AsDraggable,
    
    # If set, the layer will be created as a left sidebar menu
    [switch]$AsLeftSidebarMenu,
    
    # If set, the layer will be created as a right sidebar menu
    [Switch]$AsRightSidebarMenu,

    # If set, the layer will be created as a grid
    [Switch]$AsGrid,

    # If set, the layer will be created as a menu
    [Switch]$AsMenu,   

    # If set, the layer will be created as a Bootstrap navbar menu
    [Switch]$AsNavbar,

    # If set, the layer will be created as a Bootstrap carousel
    [Switch]$AsCarousel,

    # If set, the layer will be created as set of Bootstrap headlines
    [Switch]$AsHeadline,

    # If set, the layer will be created as set of Bootstrap buttons
    [Switch]$AsButton,

    # If set, the content will be displayed as a tree
    [Switch]$AsTree,

    # If set, the content will be displayed as a series of columns
    [Switch]$AsColumn,

    # The color of the branch in a tree
    [string]$BranchColor = '#000000',


    # If set, will show large item titles for items in the carousel
    [switch]$ShowLayerTitle,    

    # If set, the layer will be created as a Bootstrap featurette
    [Switch]$AsFeaturette,

    # If set, the layer will be created as a Bootstrap row
    [Switch]$AsRow,    

    # If set, the layer will be created as pair of Bootstrap rows, with content expanding down in the right half of the grid.
    [Switch]$AsHangingSpan,
    
    # The size (in Bootstrap spans) of the buttons used in -AsHangingSpan.  
    # The size of the hanging area will be the remainder of the 12 span grid, with one span reserved for offset
    [Uint32]$SpanButtonSize = 2,    

    # The Bootstrap RowSpan
    [string[]]$RowSpan = 'span4',

    # The width of items within a grid
    [Uint32]$GridItemWidth = 175,

    # The height of items within a grid
    [Uint32]$GridItemHeight = 112,
    
    # The width of a sidebar in a left or right sidebar menu
    [ValidateRange(1,100)]
    [Uint32]$SidebarWidth = 20,
    
    # One or more item types to apply to the region.  If set, an itemscope and itemtype will be added to the region
    [string[]]
    $ItemType,
    
    # If set, will use a vector (%percentage based layout) for the region.
    [Switch]
    $AsVectorLayout,
    
    # If set, will hide the slide name buttons (effectively creating an endless slideshow)
    [switch]
    $HideSlideNameButton,

    # If set, will use a middot instead of a slide name for a slideshow button.
    [switch]
    $UseDotInsteadOfName,
    
    # The background color in a popin
    [string]
    $MenuBackgroundColor,
    
    # The inner order within a 
    [Hashtable]
    $LayerInnerOrder
    )
    
    begin {
        # Creates an ID out of any input string
        $getSafeLayerName = {
            param($layerName) 
            
            $layerName.Replace(" ", "_space_").Replace("-", "").Replace("+", "").Replace("!", "_bang_").Replace(",", "").Replace("<", "").Replace(">","").Replace("'", "").Replace('"','').Replace('=', '').Replace('&', '').Replace('?', '').Replace("/", "").Replace(",", "_").Replace("|", "_").Replace(":","_").Replace(".", "_").Replace("@", "_at_").Replace("(", "-__").Replace(")","__-").Replace("#", "_Pound_").Replace('%', '_Percent_')
        }
        
        
        # Gets ajax script for a url
        $getAjaxAndPutIntoContainer = {
            param($url, $container, $UrlType)


if ($url -like "*.zip" -or 
    $url -like "*.exe" -or
    $UrlType -eq 'Button') {
@"
window.location = '$url';
"@

} else {
$xmlHttpVar = "xmlRequest${Container}"
@"
    var $xmlHttpVar;
    if (window.XMLHttpRequest) 
    {        
        $xmlHttpVar = new XMLHttpRequest(); // code for IE7+, FireFox, Chrome, Opera, Safari
    } else 
    {       
       $xmlHttpVar = new ActiveXObject("Microsoft.XMLHTTP"); // code for IE5, IE6
    }

    $xmlHttpVar.onreadystatechange = function() {
        
        if (${xmlHttpVar}.readyState == 4) {
            if (${xmlHttpVar}.status == 200) {               
                document.getElementById("${Container}").innerHTML = $xmlHttpVar.responseText;             
                var innerScripts = document.getElementById("${Container}").getElementsByTagName("script");   
                for(var i=0;i<innerScripts.length;i++)  
                {  
                    try {
                        eval(innerScripts[i].text);  
                    } catch (e) {
                    }
                }                   
                window.${Container}_Response = $xmlHttpVar.responseText;
            } else {
                document.getElementById("${Container}").innerHTML = $xmlHttpVar.Status;
            }
            
            
        } else {
            window.show${Container}loading = function () {
                var ih = document.getElementById("${Container}").innerHTML;
                if (ih.length < 40) {
                    ih += "&middot;"                    
                } else {
                    ih = "&middot;"
                }
                if (window.${Container}_Response == null) {
                    document.getElementById("${Container}").innerHTML=  ih;                                                       

                    setTimeout('show${Container}loading()', 75);
                }
            }
            setTimeout('show${Container}loading()', 75);
        }
    }

    if (window.${Container}_Response == null) {
        $xmlHttpVar.open('POST', "$Url", true);    
        
        $xmlHttpVar.send();
        
        document.getElementById("${Container}").innerHTML = "&middot;"
    }
"@
}    

            
        }

        $ShowLayerContent = {
            param($showButtonId, 
                $popoutLayerId, 
                [string[]]$AdditionalElements,
                [Switch]$Exclusive,
                [Switch]$StopSlideShow, 
                [Switch]$IsCurrentSlide,
                [string]$ShownState = 'inline')
        
@"
    <script>
        var ${LayerId}_currentSlide = $(if ($isCurrentSlide) { "'$popoutLayerId'"} else {'null'});
        window.${ShowButtonId}_click = function () {
            $(
            if ($layerUrl -and $layerUrl[$layerName]) {
                . $getAjaxAndPutIntoContainer $layerUrl[$layerName] $popoutLayerId
            } elseif ($LayerLink -and $LayerLink[$layerName]) {
                . $getAjaxAndPutIntoContainer $LayerLink[$layerName] $popoutLayerId "Button"
            } else {
                ""
            })
            $(if ($Exclusive) {
                "
                
                if (${LayerId}_currentSlide != null) {                    
                    var documentElement = document.getElementById(${LayerId}_currentSlide);
                    documentElement.style.display = 'none';    
                    
                }
                "
            })
            $(
                $AdditionalElements = @($popoutLayerId) + $AdditionalElements
                foreach ($el in $AdditionalElements) {
                    if (-not $el) { continue } 
"
            var documentElement = document.getElementById('$el');
            if (documentElement != null && documentElement.style.display == 'none') {
                documentElement.style.display = '$ShownState';
            } else {
                if (documentElement != null) {
                    documentElement.style.display = 'none';    
                }
            }
"                    
                }
            )            
            
            ${LayerId}_currentSlide = '$popoutLayerId';
            $(if ($StopSlideShow) {
                "clearInterval(${LayerId}_SlideshowTimer);
            for (i =0; i < ${LayerId}_SlideNames.length; i++) {
                if (${LayerId}_SlideNames[i] != '$popoutLayerId') {
                    document.getElementById(${LayerId}_SlideNames[i]).style.display = 'none';
                }
            }
            "
            })
        }
    </script>
"@
        }

        $GetLayerContent = {
            param($originalParameters)

@"
$(
if ($layer[$layerName] -is [Hashtable]) {
    $parameterCopy = @{} + $originalParameters
    
    
    $parameterCopy.Layer = $layer[$layerName]
    $parameterCopy.Order = if ($layer[$layerName].InnerOrder) {
        $layer[$layerName].InnerOrder
    } else {
        $layer[$layerName].Keys | Sort-Object
    }
    $parameterCopy.LayerId  = $LayerID + "_" + $layerName + "_items" 
    
    $innerLayerOrder = $layer[$layerName].Keys | Sort-Object
    
    New-Region @parameterCopy
} elseif ($layer[$layername] -is [string]) {
    $layer[$layerName]
} elseif ($layer[$layerName]) {
    $layer[$layerName] | Out-HTML
})
"@            
        
        }



        
        $layerCount = 0 
        $originalLayerId = $layerId
    }
    
    process {
        
        if ($layerCount -gt 0) {
            $layerId = $originalLayerId + $layerCount     
        }
        $layerCount++
        #region Internal changing of parameters of parameter set overlaps
        if ($psCmdlet.ParameterSetName -eq 'Content') {
            if (-not $Layer) {
                $Layer = @{}
            }
            $Layer.'Default' = $Content                        
            
            $hideTitleArea = $true
            $hideDirectionButton = $true
            $hideMoreButton = $true
            
            if (-not $asVectorLayout) {
                $DisableLayerSwitcher = $true
            } 
        }
        
        
        $layerId= . $getSafeLayerName $layerId
        if ($psBoundParameters.AutoSwitch -and (-not $AsSlideshow)) {
            $DisableLayerSwitcher = $false
            $NotRequestAware = $true            
        }
                
        
        if ($AsAccordian -or $AsTab -or $AsPopout -or $asPopin -or $AsPopdown -or $asPopup -or 
            $asSlideshow -or $AsWidget -or $AsPortlet -or $AsLeftSidebarMEnu -or $ASRightSidebarMenu -or 
            $AsResizable -or $AsDraggable -or $AsGrid -or $AsNavbar -or $AsCarousel -or $asHeadline -or 
            $Asbutton -or $asTree -or $AsFeaturette -or $AsRow -or $AsColumn -or $AsHangingSpan -or $AsMenu -or $AsNewspaper) {
            $NotRequestAware = $true            
            $IsStaticRegion = $true       
            $DisableLayerSwitcher = $true     
            $FixedSize = $true            
            
        } elseif (-not $AsVectorLayout -and -not $psboundParameters.Style -and -not $psBoundParameters.Keys -like "*as*") {            
            $NotRequestAware = $true            
            $IsStaticRegion = $true       
            $DisableLayerSwitcher = $true     
            $FixedSize = $true       
            
            if ($layer.Count -eq 1) {
                $AsWidget = $true                
                $AsResizable = $true
            } elseif ($layer.Count -le 5) {
                $AsTab = $true
            } else {
                $AsAccordian = $true
            }
        }
                                       
        if ($Style) {
            $FixedSize = $true            
        }
        
        

        if ($FixedSize) {
            $HideDirectionButton = $true
            $HideMoreButton = $true
            # DCR  : Make -*Margin turn into styles
            if (-not $style) {
                $style=  @{}
            }
            if ($psBoundParameters.LeftMargin) {
                $style["margin-left"] = "${LeftMargin}%"                
            }
            if ($psBoundParameters.RightMargin) {
                $style["margin-right"] = "${RightMargin}%"
            }
            if ($psBoundParameters.TopMargin) {
                $style["margin-top"] = "${TopMargin}%"
            }

            if ($psBoundParameters.BottomMargin) {
                $style["margin-bottom"] = "${BottomMargin}%"
            }
            if ($psBoundParameters.Border) {                
                $style["border"] = "$border"            
            }
        }
        
        if ($isStaticRegion) {
            $hideTitleArea = $true
            $HideMoreButton = $true
            $hideDirectionButton = $true
        }
        #endregion Internal changing of parameters of parameter set overlaps
        
        

        if (-not $psBoundParameters.Default) {
            $randomOnLoad = ""

        }
        
        
        if (-not $psBoundParameters.Order) {
            $order = $layer.Keys  |Sort-Object
        }
                
         
        
        
        $layerTitleAreaText =if (-not $HideTitleArea) { " 
            <div style='margin-top:5px;margin-right:5px;z-index:-1' id='${LayerID}_TitleArea' NotALayer='true'>
            </div>
            "
            
        } else {
            ""
        }
        
        $fadeJavaScriptFunctions = if (-not $NotCool) {
@"
function set${LayerID}LayerOpacity(id, opacityLevel) 
{
    var eStyle = document.getElementById(id).style;
    eStyle.opacity = opacityLevel / 100;
    eStyle.filter = 'alpha(opacity='+opacityLevel+')';
    if (eStyle.filter != 'alpha(opacity=0)') {
        eStyle.visibility = 'visible'
    }
    if (opacityLevel > 0) {
        eStyle.visibility = 'visible'
    } else {
        eStyle.visibility = 'hidden'
    }
}


function fade${LayerID}Layer(eID, startOpacity, stopOpacity, duration, steps) {
    
    if (steps == null) { steps = duration } 
    var opacityStep = (stopOpacity - startOpacity) / steps;
    var timerStep = duration / steps;
    var timeStamp = 10
    var opacity = startOpacity
    for (var i=0; i < steps;i++) {
        opacity += opacityStep
        timeStamp += timerStep
        setTimeout("set${LayerID}LayerOpacity('"+eID+"',"+opacity+")", timeStamp);        
    }
    
    return        
}

"@            
        } else { ""} 
        
        $dragChunk= if ($CanDrag) { @"
    if (document.getElementById('$LayerID').addEventListener) {
        document.getElementById('$LayerID').addEventListener('touchmove', function(e) {
            e.preventDefault(); 
            curX = e.targetTouches[0].pageX; 
            curY = e.targetTouches[0].pageY;      
            document.getElementById('$LayerID').style.webkitTransform = 'translate(' + curX + 'px, ' + curY + 'px)'                    
        })
    }
"@      } else { ""} 

        $enablePanChunk = if ($CanPan) { @"
    var last${LayerID}touchX = null;
    var last${LayerID}touchY = null;
    var last${LayerID}scrollX = 0;
    var last${LayerID}scrollY = 0;
    var eventHandler = function(e) {
            e.preventDefault();
            container = document.getElementById('$LayerID')
            layer = getCurrent${LayerID}Layer()
            if (last${LayerID}touchX  && last${LayerID}touchX > e.targetTouches[0].pageX) {
                // Moving right
            }
            if (last${LayerID}touchX  && last${LayerID}touchX < e.targetTouches[0].pageX) {
                // Moving left
            }
            if (last${LayerID}touchY  && last${LayerID}touchY < e.targetTouches[0].pageY) {
                // Moving up
                last${LayerID}scrollY+= $ScrollSpeed   
                                
                if (last${LayerID}scrollY > 0) {
                    last${LayerID}scrollY = 0
                }

            }
            if (last${LayerID}touchY  && last${LayerID}touchY > e.targetTouches[0].pageY) {
                // Moving down
                last${LayerID}scrollY-= $ScrollSpeed
                
                // if less than zero, set a timeout to bounce the content back                
                if (last${LayerID}scrollY < -layer.scrollHeight) {
                    last${LayerID}scrollY = -layer.scrollHeight
                        
                }

            }
            last${LayerID}touchX = e.targetTouches[0].pageX
            last${LayerID}touchY = e.targetTouches[0].pageY
            
            layer.style.webkitTransform = 'translate(' + last${LayerID}scrollX +"px," + last${LayerID}scrollY +"px)";
            
            
            
        }
    if (document.getElementById('$LayerID').addEventListener) {
        document.getElementById('$LayerID').addEventListener('touchmove', eventHandler)
    }
    
    var layers = get${LayerID}Layer();
    while (layers[layerCount]) {
        if (layers[layerCount].addEventListener) {
            layers[layerCount].addEventListener('touchmove', eventHandler)
        }
        
        layerCount++;
    }

    
"@      } else { ""} 
        $layerSwitcherScripts = if (-not $DisableLayerSwitcher) {
            

            $moreButtonText = if (-not $HideMoreButton) {
                "
                <span style='padding:5px;'>
                <input type='button' id='${$LayerID}_MoreButton' onclick='show${LayerID}Morebar();' style='border:1px solid black;padding:5;font-size:medium' value='...' />
                </span>
                "
            } else {
                ""
            }

            $directionButtonText = if (-not $HideDirectionButton) {
                "
                <span style='padding:5px;'>            
                <input type='button' id='${LayerID}_LastButton' onclick='moveToLast${LayerID}Item();' style='border:1px solid black;padding:5;font-size:medium' value='&lt;' /> 
                <input type='button' id='${LayerID}_NextButton' onclick='moveToNext${LayerID}Item();' style='border:1px solid black;padding:5;font-size:medium' value='&gt;' />
                </span>
                "
            
            } else {
                ""
            }                



@"

    $fadeJavaScriptFunctions
    
    function moveToNext${LayerID}Item() {
        var layers = get${LayerID}Layer();        
        var layerCount = 0;
        var lastLayerWasVisible = false;
        while (layers[layerCount]) {
            if (lastLayerWasVisible == true) { 
                select${LayerID}Layer(layers[layerCount].id);               
                lastLayerWasVisible = false;
                break
            }
                
            
            if (layers[layerCount].style.opacity == 1) {
                // This layer is visible.  Hide it, and make sure we know to show the next one.
                lastLayerWasVisible = true;
            }                         
            layerCount++;
        }
        
        if (lastLayerWasVisible == true) {
            select${LayerID}Layer(layers[0].id);                           
        }
    }
    
    function moveToLast${LayerID}Item() {
        var layers = get${LayerID}Layer();
        
        var layerCount = 0;
        var lastLayer = null;
        var lastLayerWasVisible = false;
        var showLastLayer =false;
        while (layers[layerCount]) {
            if (layers[layerCount].style.visibility == 'visible') {
                if (lastLayer == null) {
                    showLastLayer = true;
                } else {
                    select${LayerID}Layer(lastLayer.id);                           
                }
            }
            
            lastLayer = layers[layerCount];                                      
            layerCount++;
        }

        if (showLastLayer == true) {
            select${LayerID}Layer(lastLayer.id);                           
        }
    }             
    
    function select${LayerID}Layer(name, hideMoreBar) {
        var layers = get${LayerID}Layer();
        var layerCount = 0;
        var found = false;
        while (layers[layerCount]) {
      
            containerName = '${LayerID}_' + name
            if (layers[layerCount].id == name || 
                layers[layerCount].id == containerName || 
                layers[layerCount].id == containerName.replace("-", "_").replace(" ", "")) {                
                if (typeof fade${LayerID}Layer == "function") {
                    layers[layerCount].style.zIndex = 1
                    fade${LayerID}Layer(layers[layerCount].id, 0, 100, $($TransitionTime.TotalMilliseconds), $KeyFrameCount)
                } else {
                    layers[layerCount].style.visibility = 'visible';
                    layers[layerCount].style.opacity = 1;
                }                
                if (document.getElementById('${LayerID}_TitleArea') != null) {
                    document.getElementById('${LayerID}_TitleArea').innerHTML = get${LayerID}LayerTitleHTML(layers[layerCount]);
                }
            } else {
                if (typeof fade${LayerID}Layer == "function") {
                    if (layers[layerCount].style.opacity != 0) {
                        fade${LayerID}Layer(layers[layerCount].id, 100, 0, $($TransitionTime.TotalMilliseconds), $KeyFrameCount)
                    }
                } else {
                    layers[layerCount].style.visibility = 'hidden';
                }                
            }
            layerCount++;
        }
                       
        if (hideMoreBar == true) {
            hide${LayerID}Morebar();    
        }
    } 
    
    function add${LayerID}Layer(name, content, layerUrl, refreshInterval) 
    {
        var layers = get${LayerID}Layer();
        var safeLayerName = name.replace(' ', '').replace('-', '_');
        newHtml = "<div id='${LayerID}_" + safeLayerName +"' style='$(if ($AsTab -or -not $DisableLayerSwitcher) {'visibility:hidden;'})position:absolute;margin-top:0px;margin-left:0px;opacity:0;overflow:auto;-webkit-overflow-scrolling: touch;'>"
        newHtml += content
        newHtml += "</div><script>"
        newHtml += ("document.getElementById('${LayerID}_" + safeLayerName + "').setAttribute('friendlyName', '" + name + "');")
        if (layerUrl) {
            
            newHtml += ("document.getElementById('${LayerID}_" + safeLayerName + "').setAttribute('layerUrl', '" + layerUrl + "');")
        }
        newHtml += ("<" + "/script>")
        
        document.getElementById("${LayerID}").innerHTML += newHtml;         
        layers = get${LayerID}Layer()
        layerCount =0 
        while (layers[layerCount]) {
            if (layers[layerCount].id == "${LayerID}_" + safeLayerName) {
                layers[layerCount].setAttribute('friendlyName', name);
                if (layerUrl) {
                    layers[layerCount].setAttribute('layerUrl', layerUrl);
                }
                if (refreshInterval) {
                    layers[layerCount].setAttribute('refreshInterval', refreshInterval);
                }
                if (layerCount == 0) {
                    // first layer, show it
                    select${LayerID}Layer(layers[layerCount].id, true);
                }
            }
            layerCount++
        }                
    }    
    
    function set${LayerID}Layer(name, newHTML) 
    {
        var safeLayerName = name.replace(' ', '').replace('-', '_');
        layerId ="${LayerID}_" + safeLayerName 
        
        document.getElementById(layerId).innerHTML = newHtml;
        select${LayerID}Layer(layerId);
    }

        
    function new${LayerID}CrossLink(containerName, sectionName, displayName)
    {
        if (! displayName) {
            displayName = sectionName
        }
        "<a href='javascript:void(0)' onclick='" + "select" +containerName + "layer(\"" + sectionName+ "\")'>" + displayName + "</a>'"        
    }                    
    
    function show${LayerID}Morebar() {        
        var morebar = document.getElementById('${LayerID}_Toolbar')                        
        var layers = get${LayerID}Layer();   
        var layerCount = layers.length;
        
            newHtml = "<span><select id='${LayerID}_ToolbarJumplist' style='font-size:large;padding:5'>"
            
            for (i =0 ;i < layerCount;i++) {
                newHtml += "<option style='font-size:large;' value='";
                newHtml += layers[i].id;
                newHtml += "'>";
                newHtml += layers[i].attributes['friendlyName'].value; 
                newHtml += "</option>"                       
            }
            newHtml += "</select> \
            <input type='button' style='border:1px solid black;padding:5;font-size:medium' value='Go' onclick='select${LayerID}Layer(document.getElementById(\"${LayerID}_ToolbarJumplist\").value, true);'>\
            </span>"
            morebar.innerHTML = newHtml;
                       
        // morebar.style.visibility = 'visible';                
    }
    
    function hide${LayerID}Morebar() {                
        document.getElementById('${LayerID}_Toolbar').innerHTML = "$($directionButtonText -split ([Environment]::NewLine) -join ('\' + [Environment]::NewLine)
            $moreButtonText -split ([Environment]::NewLine) -join ('\' + [Environment]::NewLine))";                    
    }   
"@            
        } else {
            ""
        }

        $cssStyleAttr  = if ($psBoundParameters.Style) { 
            . Write-CSS -Style $style -OutputAttribute
        } else {
            ""
        }
        $cssFontAttr = if ($psBoundParameters.Style.Keys -like "font*"){
            $2ndStyle = @{}
            foreach ($k in $psBoundParameters.sTyle.keys) {
                if ($k -like "font*"){
                    $2ndStyle[$k] = $style[$k]
                }
            }
            . Write-CSS -Style $2ndStyle -outputAttribute
        } else {
            ""
        }
        $cssStyleChunk = if ($psBoundParameters.Style) { 
            "style='" +$cssStyleAttr   + "'"
        } else {
            ""
        }
        
        
        if ($AsCarousel) {
            if (-not $CssClass) {
                $CssClass = @()
                
            }
            if ($CssClass -notcontains "carousel") {
                $CssClass += "carousel"
            }
            if ($CssClass -notcontains "slide") {
                $CssClass += "slide"
            }
            
        }

        if ($AsRow) {
            if (-not $CssClass) {
                $CssClass = @()
                
            }
            if ($CssClass -notcontains "container") {
                $CssClass += "container"
            }
            
        }

        if ($Asnavbar) {
            if (-not $CssClass) {
                $CssClass = @()
                
            }
            if ($CssClass -notcontains "navbar-wrapper") {
                $CssClass += "navbar-wrapper"
            }            
        }

        if ($AsFeaturette) {
            if (-not $CssClass) {
                $CssClass = @()
                
            }
            if ($CssClass -notcontains "navbar-wrapper") {
                $CssClass += "navbar-wrapper"
            }
            if ($CssClass -notcontains "featurette") {
                $CssClass += "featurette"
            }            
        }
                
        
        $classChunk =  if ($CssClass) {
            "class='$($cssClass -join ' ')'"
        } else {
            ""
        }
        
        $itemTypeChunk = if ($itemType) {
            "itemscope='' $(if ($itemId) {'itemid="' + $itemId + '"' }) itemtype='$($itemType -join ' ')'"
        } else {
            ""
        }

        $outSb = New-Object Text.StringBuilder
        if (-not $DisableLayerSwitcher) {
            $null = $outSb.Append(@"
<div id='$LayerID' $classChunk $cssStyleChunk $itemTypeChunk>
$layerTitleAreaText      
<script type='text/javascript'>   
    function get${LayerID}LayerTitleHTML(layer) {
        var logoUrl = '$Logo'
        var fullTitle = ""
        if (logoUrl != '') {
            fullTitle = "<img style='align:left' src='" + logoUrl + "' border='0'/><span style='font-size:x-large'>" + layer.attributes['friendlyName'].value +'</span>' $(if ($HorizontalRuleUnderTitle) { '+ "<HR/>"'});
        } else {
            fullTitle= "<span style='font-size:x-large'>" + layer.attributes['friendlyName'].value +'</span>' $(if ($HorizontalRuleUnderTitle) { '+ "<HR/>"'});
        }           
                
        if (layer.attributes['layerUrl']) {
            fullTitle = "<a href='" + layer.attributes['layerUrl'].value + "'>" + fullTitle + "</a>"
        }
        
        $socialChunk
        
        return fullTitle
    }    
    
    function get${LayerID}Layer() {
        var element = document.getElementById('$LayerID');
        var layers = element.getElementsByTagName('div');
        var layersOut = new Array();
        var layerCount = 0;
        var layersOutCount = 0;
        while (layers[layerCount]) {            
            
            if (layers[layerCount].parentNode == element && layers[layerCount].attributes["NotALayer"] == null) {
                layersOut[layersOutCount] = layers[layerCount];
                layersOutCount++
            }
            layerCount++;
        }
        return layersOut;
    }    
    
    function getCurrent${LayerID}Layer() {
        var element = document.getElementById('$LayerID');
        var layers = element.getElementsByTagName('div');
        var layersOut = new Array();
        var layerCount = 0;
        var layersOutCount = 0;
        while (layers[layerCount]) {            
            
            if (layers[layerCount].parentNode == element && layers[layerCount].attributes["NotALayer"] == null) {
                if (layers[layerCount].style.visibility == 'visible') {
                    return layers[layerCount]
                }
                layersOutCount++
            }
            layerCount++;
        }        
    }
    

             
    $layerSwitcherScripts                  
</script>
"@)
        } elseif ($AsResizable -or $AsWidget -or $AsDraggable) {
            $null = $outSb.Append(@"
"@)            
        } else {
            $null = $outSb.Append(@"
<div id='$LayerID' $classChunk $cssStyleChunk $itemTypeChunk>
$layerTitleAreaText      
"@)
        }     
        
        if ($psCmdlet.ParameterSetName -eq 'Content' -and 
            -not ($AsDraggable -or $AsWidget -or $AsResizable)) {
            $null = $outSb.Append("$content")
            $null = $outSb.Append("</div>")
        }  else {        
        if ($AsTab) {
            $null = $outSb.Append("<ul>")
            

            $content= 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }                      
                    $safeLayerName = . $getSafeLayerName $layerName
                    $n = $layerName.Replace(" ", "").Replace("-", "").Replace(",", "").Replace("<", "").Replace(">","").Replace("'", "").Replace('"','').Replace('=', '').Replace('&', '').Replace('?', '').Replace("/", "")
                
                    # If there's a layer URL, make use of the nifty ajax loading 
                    if ($LayerUrl[$LayerName]) {
                        "<li><a $cssStyleChunk href='ajax/$($LayerUrl[$LayerName])'>${LayerName}</a></li>"
                    } else {
                        "<li><a $cssStyleChunk href='#${LayerID}_$safeLayerName'>${LayerName}</a></li>"                                
                    }
                
                }
            $null = $outSb.Append("$content")
            $null = $outSb.Append("</ul>")
                
            
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }                      
                    if ($layerUrl[$layerName]) { continue }
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    "<div id='${LayerID}_$safeLayerName' $cssStyleChunk>
                        $($(if ($putInParagraph) {'<p>'}) + $layer[$layerName] + $(if ($putInParagraph) {'</p>'}) )                
                    </div>"
                }
            $null = $outSb.Append("$content")
        } elseif ($AsMenu) {
            $null = $outSb.Append("
            <div class='menu' $cssStyleChunk>
                <ul class='nav' id='${LayerId}_Menu'>                                
            ")
            $underContent = ""
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }                      
                    $safeLayerName = . $getSafeLayerName $layerName
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                
                    # If there's a layer URL, make use of the nifty ajax loading 
                    if ($LayerUrl[$LayerName]) {
                        "<li><a $cssStyleChunk id='$showButtonId ' href='$($LayerUrl[$LayerName])'>${LayerName}</a></li>"
                    } elseif ($layer[$layerName] -as [hashtable[]]) {
                        "<li><a $cssStyleChunk id='$showButtonId' href='javascript:void(0)'>${LayerName}</a>"
                    
                        "<ul>"
                        $innerLayers = @($Layer[$layerName])

                                            
                        foreach ($ht in $Layer[$layerName]) {
                        
                            
                            $innerOrder= $ht.Keys | Sort-Object                            
                            $innerOrder = if ($LayerInnerOrder -and $layerInnerOrder[$layerName]) {
                                $layerInnerOrder[$layerName]
                            } else {
                                $innerOrder
                            }
                            foreach ($k in $innerOrder) {
                                if (-not $k) { continue} 
                                "<li><a href='$($ht[$k])'>$k</a></li>"
                            }                                                            
                        }
                        "</ul></li>"

                    } else {
                        "
                        <script type='text/javascript'>
                            function ${ShowButtonId}_click() {
                                $ajaxLoad
                                var popout = document.getElementById('$popoutLayerId');                                
                                if (popout.style.display == 'none') {
                                    popout.style.display = 'inline';
                                    separator.style.display = 'inline';
                                    bottomseparator.style.display = 'inline';
                                } else {
                                    popout.style.display = 'none'
                                    separator.style.display = 'none';
                                    bottomseparator.style.display = 'none';
                                }            
                            }
                        </script>
                        <li><a $cssStyleChunk id='$showButtonId' href='#${LayerID}_$safeLayerName' onclick='${ShowButtonId}_click();'>${LayerName}</a></li>                        
                        "                                
                        $underContent += "<div id='$popoutLayerId' style='display:none'>$($layer[$layerName])</div>"
                    }
                
                }
            $null = $outSb.Append(@"
$content
</ul>
$underContent
<script>
var csssubmenuoffset=-1 //Offset of submenus from main menu. Default is 0 pixels.
var ultags=document.getElementById('${LayerId}_Menu').getElementsByTagName("ul")
for (var t=0; t<ultags.length; t++){
	ultags[t].style.top=ultags[t].parentNode.offsetHeight+csssubmenuoffset+"px"    
    ultags[t].parentNode.onmouseover=
        function(){
				this.style.zIndex=100
                this.getElementsByTagName("ul")[0].style.visibility="visible"
				this.getElementsByTagName("ul")[0].style.zIndex=0
        }
    ultags[t].parentNode.onmouseout=
        function(){
		    this.style.zIndex=0
			this.getElementsByTagName("ul")[0].style.visibility="hidden"
			this.getElementsByTagName("ul")[0].style.zIndex=100
        }    
}



        </script> 
</div>
"@) 
                        
        } elseif ($AsNavbar) {
            $null = $outSb.Append("
<script>
var ${LayerId}_CurrentSlide = '$defaultSlide'
</script>            
            <div class='container' $cssStyleChunk><div class='navbar$(if ($AsFeaturette) { ' featurette' })' $cssStyleChunk><div class='nav-collapse collapse' $cssStyleChunk><ul class='nav'>") 
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }                      
                    $safeLayerName = . $getSafeLayerName $layerName
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $n = $layerName.Replace(" ", "").Replace("-", "").Replace(",", "").Replace("<", "").Replace(">","").Replace("'", "").Replace('"','').Replace('=', '').Replace('&', '').Replace('?', '').Replace("/", "")
                
                    # If there's a layer URL, make use of the nifty ajax loading 
                    if ($LayerUrl[$LayerName]) {
                        "<li><a $cssStyleChunk id='$showButtonId ' href='$($LayerUrl[$LayerName])'>${LayerName}</a></li>"
                    } elseif ($layer[$layerName] -as [hashtable[]]) {
                        "<li class='dropdown'><a $cssStyleChunk id='$showButtonId' href='javascript:void(0)' data-toggle='dropdown'>${LayerName} <b class='caret'></b></a>"
                    
                        "<ul class='dropdown-menu'>"
                        $innerLayers = @($Layer[$layerName])

                    
                        $c = 0
                        foreach ($ht in $Layer[$layerName]) {
                        
                            
                            
                            
                            $innerOrder = if ($LayerInnerOrder -and $layerInnerOrder[$layerName]) {
                                $layerInnerOrder[$layerName]
                            } else {
                                $innerOrder= $ht.Keys | Sort-Object
                            }
                            foreach ($k in $innerOrder) {
                                if (-not $k) { continue} 
                                "<li><a href='$($ht[$k])'>$k</a></li>"
                            }
                            if ($c -lt ($innerLayers.Count - 1)) {
                                "<li class='divider'></li>"
                            }
                            $c++
                        
                        }
                        "</ul></li>"

                    } else {
                        "
                        <li><a $cssStyleChunk id='$showButtonId' href='#${LayerID}_$safeLayerName'>${LayerName}</a></li>
                        <script>
                        `$( '#$ShowButtonId' ).click(function(){        
                            if (${LayerId}_CurrentSlide != null && ${LayerId}_CurrentSlide != '$popOutLayerId') {
                                if (document.getElementById(${LayerId}_CurrentSlide)) {
                                    `$( (`"#`" + ${LayerId}_CurrentSlide) ).hide(200);            
                                    document.getElementById(${LayerId}_CurrentSlide).style.visibility = 'hidden';
                                    document.getElementById(${LayerId}_CurrentSlide).style.display = 'none';	               

                                }

                            }
                
                        
                            `$( `"#$popoutLayerId`" ).show(200);
                            document.getElementById(`"$popoutLayerId`").style.visibility = 'visible';          
                            document.getElementById(`"$popoutLayerId`").style.display = 'inline'       
                            ${LayerId}_CurrentSlide = '$popoutLayerId';
                        
        
                        
                         });
                        </script>
                    
                        "                                
                    }
                
                }
            $null = $outSb.Append("$content") 
            
            $null = $outSb.Append("</ul></div></div></div>")
            
            $Content = foreach ($layerName in $Order) {      
                if (-not $layerName) {continue }                      
                if ($layerUrl[$layerName]) { continue }
                if ($layer[$layerName] -as [hashtable[]]) { continue }
                
                $safeLayerName = . $getSafeLayerName $layerName
                $popoutLayerId = "${LayerID}_$safeLayerName"
                
                "
                
                <div id='${LayerID}_$safeLayerName' $cssStyleChunk style='display:none:visibility:hidden'>
                    $($(if ($AsFeaturette) {'<h1>'}) + $layerName + $(if ($AsFeaturette) {'</h1><hr/>'}) )                
                    $($layer[$layerName])
                </div>
                
                "
            }
            $null = $outSb.Append("$content")
            
        } elseif ($AsAccordian) { 
            
            $content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    "<h3><a href='javascript:void(0)'>${LayerName}</a></h3>
                    <div>
                        $($(if ($putInParagraph) {'<p>'}) + $layer[$layerName] + $(if ($putInParagraph) {'</p>'}) )                
                    </div>
                    "
                }
            $null = $outSb.Append("$content")
        } elseif ($AsCarousel) {
            $isFirst = $true
            if (-not $psBoundParameters.LayerHeadingSize) {
                $LayerHeadingSize = 2
            }
            $null = $outSb.Append("<div class='carousel-inner' style='margin-left:10%;margin-right:10%'>")
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    if ($isFirst) {
                        $isFirst = $false
                        $itemActive = 'active'
                    } else {
                        $itemActive = ''
                    }
                    "
                    <div class='item $itemActive'>
                        <a name='${LayerName}'> </a>$(if ($ShowLayerTitle) { "<h$LayerHeadingSize>$layerName</h$LayerHeadingSize>"})
                        $($(if ($putInParagraph) {'<p>'}) + $layer[$layerName] + $(if ($putInParagraph) {'</p>'}) )                
                    </div>
                    "
                }
            $null = $outSb.Append("$Content")
        } elseif ($AsFeaturette) {
            $null = $outSb.Append("
<style>
.featurette-divider {
    margin: 80px 0; 
}
.featurette {
    overflow: hidden; 
    line-height: 1.3;
}
.featurette-image {
    margin-top: -120px; 
}


.featurette-image.pull-left {
    margin-right: 40px;
}
.featurette-image.pull-right {
    margin-left: 40px;
}

 .featurette-heading {
    font-size: 3em;
}

.featurette {
    font-size: 1.15em;
    
}

.featurette li {
    font-size: 1.2em;
    line-height: 1.3;
}


/* Thin out the marketing headings */
.featurette h1 {
    font-size: 2.1em;
    font-weight: 300;
    line-height: 2.2;
    letter-spacing: -1px;
}

.featurette h2 {
    font-size: 1.7em;
    font-weight: 200;
    line-height: 1.8;
    letter-spacing: -1px;
}


.featurette h3 {
    font-size: 1.5em;
    font-weight: 100;
    line-height: 1.6;
    letter-spacing: -1px;
}


.featurette h4 {
    font-size: 1.4em;
    font-weight: 100;
    line-height: 1.45;
    letter-spacing: -1px;
}
</style>
<div class='container'><div class='featurette'> 
")    
            $c = 0
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    $span = if ($c -lt $RowSpan.Length) {
                        $RowSpan[$c] 
                    } else {
                        $RowSpan[$RowSpan.Length - 1] 
                    }
                    $c++
                    "
                    <div class='lead'>
                        <a name='${LayerName}'> </a>$(if ($ShowLayerTitle) { "<h$LayerHeadingSize>$layerName</h$LayerHeadingSize>"})
                        $($(if ($putInParagraph) {'<p>'}) + $layer[$layerName] + $(if ($putInParagraph) {'</p>'}) )                
                    </div>
                    "
                }
            $null = $outSb.Append("$Content")
            $null = $outSb.Append("</div></div>")
            
        } elseif ($Asrow) {
            
            $null = $outSb.Append("
<div class='container'>
<div class='row'>        
            ")
            $c = 0
            $rowContent =
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    $span = if ($c -lt $RowSpan.Length) {
                        $RowSpan[$c] 
                    } else {
                        $RowSpan[$RowSpan.Length - 1] 
                    }
                    $c++
                    "
                    <div class='$span'>
                        <a name='${LayerName}'> </a>$(if ($ShowLayerTitle) { "<h$LayerHeadingSize>$layerName</h$LayerHeadingSize>"})
                        $($(if ($putInParagraph) {'<p>'}) + $layer[$layerName] + $(if ($putInParagraph) {'</p>'}) )                
                    </div>
                    "
                }
            $null = $outSb.Append("$rowContent</div></div>")
            
        } elseif ($AsWidget -or $AsResizable -or $AsDraggable) { 
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    "
                    <div id='${LayerID}_$safeLayerName' class='ui-widget-content' $cssStyleChunk $itemTypeChunk>
                        $(if ($LayerName -ne 'Default') { "<h3 class='ui-widget-header'>${LayerName}</h3>" })
                        $($(if ($putInParagraph) {'<p>'}) + $layer[$layerName] + $(if ($putInParagraph) {'</p>'}) )                
                    </div>                
                    "
                
                    if ($AsResizable) {
@"
                    <script type='text/javascript'>
                    `$(function() {
		                  `$('#${LayerID}_$safeLayerName').resizable();
	               });                    
                    </script>
"@                
                    }
                    if ($AsDraggable) {
@"
                    <script type='text/javascript'>
                    `$(function() {
		                  `$('#${LayerID}_$safeLayerName').draggable();
	               });                    
                    </script>
"@                  
                    }
                }
            $null = $outSb.Append("$Content")
        }  elseif ($AsPopUp) {
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    $ajaxLoad = 
                        if ($layerUrl -and $layerUrl[$layerName]) {
                            . $getAjaxAndPutIntoContainer $layerUrl[$layerName] $popoutLayerId
                        } elseif ($LayerLink -and $LayerLink[$layerName]) {
                            . $getAjaxAndPutIntoContainer $LayerLink[$layerName] $popoutLayerId "Button"
                        } else {
                            ""
                        }
                    # Carefully intermixed JQuery and PowerShell Variable Embedding.  Do Not Touch
@"
<div>
<script>
	`$(function() {
    `$( "#${ShowButtonId}").button()   
    `$( "#$ShowButtonId" ).click(function(){
        var options = {}; 
        $ajaxLoad            
        `$( "#$popoutLayerId" ).dialog({modal:true, title:"$($layerName -replace '"','\"')"});        
     });
    		
	});
</script>
<a id='$ShowButtonId' $cssStyleChunk class='ui-widget-header ui-corner-all' href='javascript:void(0)'>${LayerName}</a>
<div id='$popoutLayerId' class='ui-widget-content ui-corner-all' style="display:none;">    
    $($layer[$layerName])
</div>
</div>
"@                
                                                
                }

            $null = $outSb.Append("$Content")
        } elseif ($AsPopout) {
            $Content =            
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    $ajaxLoad = 
                        if ($layerUrl -and $layerUrl[$layerName]) {
                            . $getAjaxAndPutIntoContainer $layerUrl[$layerName] $popoutLayerId
                        } elseif ($LayerLink -and $LayerLink[$layerName]) {
                            . $getAjaxAndPutIntoContainer $LayerLink[$layerName] $popoutLayerId "Button"
                        } else {
                            ""
                        }

                    # Carefully intermixed JQuery and PowerShell Variable Embedding.  Do Not Touch
@"
<div>
<script>
	`$(function() {
    `$( "#${ShowButtonId}").button();  
    `$( "#$ShowButtonId" ).click(function(){                        
        `$( "#$popoutLayerId" ).toggle( "fold", {}, 200);			                       
     });    		
	});
</script>
<a id='$ShowButtonId'  class='ui-widget-header ui-corner-all btn btn-primary btn-large' href='javascript:void(0)' style='min-width:100%;$cssStyleAttr'>${LayerName}</a>
<div id='$popoutLayerId' class='ui-widget-content ui-corner-all' style="display:none;visibility:hidden;$cssStyleAttr">    
    $($layer[$layerName])
</div>
</div>
"@                
                                                
                }

            $null = $outSb.Append("$Content")
        } elseif ($ascolumn) {            
            $columnSize = 100 / $layer.Count 
            $null = $outsb.Append("<div style='clear:both'></div>")
            $Content = 
                foreach ($LayerName in $Order) {
"
<div style='float:left;width:${ColumnSize}%'>
    <h$LayerHeadingSize>
        $($layerName)
    </h$LayerHeadingSize>
    $($layer[$LayerName])
</div>
"    
                }
            $null = $outSb.Append("$Content")
            $null = $outsb.Append("<div style='clear:both'></div>")
        } elseif ($AsTree) {
            $null = $outSb.Append("<table style='border:none;margin:0;padding:0;border-collapse:collapse'>")


            if (-not $psBoundParameters.BranchColor -and
                $pipeworksManifest.Style.Body.color) {
                $BranchColor = $pipeworksManifest.Style.Body.color
            }
        
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    
                
@"
<tr>
    <td style='text-indent: -21px;padding-left: 21px;$cssStyleAttr' colspan='4'>        
        $(. $ShowLayerContent $showButtonId $popoutLayerId)    
        <a id='$ShowButtonId' class='btn-primary' href='javascript:void(0)' style='$cssStyleAttr' onclick='${ShowButtonId}_click();'>${LayerName}</a>
        <br style='line-height:200%' />

    </td>
</tr>
<tr id='$popoutLayerId' class='' style="display:none;visibility:hidden;$cssStyleAttr">
    <td style="width:20px"></td>
    <td style="background-color:$('#' + $BranchColor.TrimStart('#'));width: 1px"></td>
    <td style="width:10px"></td>
    <td>
        $(

        if ($layer[$layerName] -as [Hashtable]) {
            $innerLayerId = $LayerID + "_ " + $layerNAme
            $innerLayerOrder = ($layer[$layerName] -as [Hashtable]).Keys | Sort-Object
            New-Region -AsTree -Layer $layer[$layerName] -LayerId $innerLayerId  -Order $innerLayerOrder -Style @{
                "font-size" = ".99em"
                "padding" = '20px'                
                'margin-top' = '25px'
                'margin-bottom' = '25px'
            } -BranchColor $BranchColor
        } elseif ($layer[$layername] -is [string]) {
            $layer[$layerName]
        } elseif ($layer[$layerName]) {
            $layer[$layerName] | Out-HTML
        }
        
        
        
        )        
    </td>
</tr>
"@            
            }
                $null =$outSb.Append("$Content")
                $null =$outSb.Append("</table>")
        } elseif ($AsButton) {
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    $ajaxLoad = 
                        if ($layerUrl -and $layerUrl[$layerName]) {
                            . $getAjaxAndPutIntoContainer $layerUrl[$layerName] $popoutLayerId
                        } elseif ($LayerLink -and $LayerLink[$layerName]) {
                            . $getAjaxAndPutIntoContainer $LayerLink[$layerName] $popoutLayerId "Button"
                        } else {
                            ""
                        }

                    # Carefully intermixed JQuery and PowerShell Variable Embedding.  Do Not Touch
@"

<script>
	`$(function() {
    
    `$( "#$ShowButtonId" ).click( 
        function(){                            
            if (`$( "#$popoutLayerId" )[0].style.visibility == 'hidden') {
                `$( "#$popoutLayerId" )[0].style.visibility = 'visible'
                $ajaxLoad
            } else {
                `$( "#$popoutLayerId" )[0].style.visibility = 'hidden'
            }
            `$( "#$popoutLayerId" ).toggle(200);			                       
        })    		
	});
</script>
<a id='$ShowButtonId'  href='javascript:void(0)' style='padding:15px;$cssStyleAttr' class='btn-primary'>${LayerName}</a>
<br style='line-height:175%' />
<div id='$popoutLayerId' class='' style="display:none;visibility:hidden;$cssStyleAttr">    
    $($layer[$layerName])
</div>
<br style='line-height:175%' />
"@                
                                                
                }

            $null = $outSb.Append("$Content")
        } elseif ($AsNewspaper) {
            $counter = 0 
            $runningWidthTracker = 0 
            $content = 
                foreach ($layerName in $order) {
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $columnContainer = "${LayerID}_${safeLayerName}_Column"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $showScript  = . $showLayerContent $showButtonId $popoutLayerId 
                                        
                    $newspapercolumnWidth = 
                        if ($counter -ge $NewspaperColumn.Count) {
                            $NewspaperColumn[$NewspaperColumn.Count - 1]
                        } else {
                            $NewspaperColumn[$counter]
                        }
                    $runningWidthTracker+= $newspapercolumnWidth

                    $lineBreaks = $false
                    if ($runningWidthTracker -ge 1) {
                        $runningWidthTracker = 0
                        $lineBreaks = $true
                    }
                    $isexpanded = 
                        $ExpandNewspaperColumn -contains $layerName -or
                        $ExpandNewspaperColumn -contains "$counter"


                    $counter++
@"
    $showScript
    
    <div id='$ColumnContainer' style='float:left;width:$($newspapercolumnWidth * 100)%;margin-left:auto;margin-right:auto;'>
        <div style='padding-left:.5%;padding-right:.5%'>
            <h$NewsPaperHeadingSize style='text-align:$NewspaperHeadingAlignment'>
                <a id='$ShowButtonId'  href='javascript:void(0)' style='$cssStyleAttr;text-align:$NewspaperHeadingAlignment;' $(if ($UseButtonForNewspaperHeadline) { "class='btn-primary rounded' "}) onclick='${ShowButtonId}_click();'>
                    ${LayerName}
                </a>
            </h$NewsPaperHeadingSize>
            $(if ($UnderlineNewspaperHeadline) { "<hr style='width:100%;height:2px;' class='solidForeground' />" })
            <div id='$popoutLayerId' style="display:none;$cssStyleAttr;">            
                <div style='margin:3%'>
                    $(. $GetLayerContent $psBoundParameters)
                </div>        
            </div>
        </div>
    </div>
    $(if ($lineBreaks) { "<br style='clear:both' />" })
    $(if ($isexpanded) { "<script>${ShowButtonId}_click();</script>" })
    

"@

            
                }
            $null = $outSb.Append("$Content")

        } elseif ($AsHangingSpan) {
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    $showScript  = . $showLayerContent $showButtonId $popoutLayerId "${PopOutLayerId}_separator","${PopOutLayerId}_bottomseparator"
                    
                    
                    
@"
    $showScript
    <br style='clear:both;display:none' id='${popOutLayerId}_separator' />
    
    <a id='$ShowButtonId' href='javascript:void(0)' style='padding-left:15px;padding-right:15px;padding-top:4%;padding-bottom:4%;margin-top:5px;margin-bottom:5px;$cssStyleAttr;text-align:center;display:block;float:left;' class='btn-primary span$SpanButtonSize' onclick='${ShowButtonId}_click();'>
        ${LayerName}
    </a>
    

    <div id='$popoutLayerId' style="display:none;$cssStyleAttr;" class='span$(12 -([Math]::Floor($SpanButtonSize /2))) offset$([Math]::Floor($SpanButtonSize / 2))'>    
        $(
        if ($layer[$layerName] -as [Hashtable]) {
            $innerLayerId = $LayerID + "_ " + $layerNAme
            $innerLayerOrder = ($layer[$layerName] -as [Hashtable]).Keys | Sort-Object
            "<div class='row'>" + (
            New-Region -AsHangingSpan -Layer $layer[$layerName] -LayerId $innerLayerId  -Order $innerLayerOrder -Style @{
                "font-size" = ".99em"                
            }) + "</div>"
        } elseif ($layer[$layername] -is [string]) {
            $layer[$layerName]
        } elseif ($layer[$layerName]) {
            $layer[$layerName] | Out-HTML
        })
    </div>

    <br style='clear:both;display:none' id='${popOutLayerId}_bottomseparator' />
"@                
                                                
                }

            $null = $outSb.Append("$Content")
        } elseif ($AsHeadline) {
            
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    $showScript  = . $showLayerContent $showButtonId $popoutLayerId

                # Carefully intermixed JQuery and PowerShell Variable Embedding.  Do Not Touch
@"
<div class='hero-unit'>
    $showScript
    <a id='$ShowButtonId'  href='javascript:void(0)' style='min-width:100%;text-decoration:underline;font-family:inherit;' onclick='${ShowButtonId}_click();'><h1 style='$cssStyleAttr;'>${LayerName}</h1></a>
    <div id='$popoutLayerId' class='' style="display:none;$cssStyleAttr">    
        $(. $GetLayerContent $psBoundParameters)
    </div>
</div>
"@                
                                                
                }
            $null = $outSb.Append("$Content")
        } elseif ($AsPopdown) {
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    


@"
$(. $ShowLayerContent $showButtonId $popoutLayerId -exclusive -shownstate 'block')
<a id='$ShowButtonId'  class='ui-widget-header ui-corner-all' $cssStyleChunk href='javascript:void(0)' onclick='${ShowButtonId}_click();'>${LayerName}</a> 
"@                
                                                
                }
            
            $null = $outSb.Append("$Content")
            $nlc = 0
            $Content = 
                foreach ($layerName in $Order) {      
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    if (-not $layerName) {continue }      
                    
                    $nlc++
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    
@"
<div id='$popoutLayerId' class='ui-widget-content ui-corner-all' style="display:none;$cssStyleAttr">    
    $(. $getlayerContent $psBoundParameters)
</div>
"@            
                }

                $null = $outSb.Append("$Content")
        } elseif ($AsGrid) {
            

            $Content =  
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                
                    # Carefully intermixed JQuery and PowerShell Variable Embedding.  Do Not Touch
                    $ajaxLoad = 
                        if ($layerUrl -and $layerUrl[$layerName]) {
                            . $getAjaxAndPutIntoContainer $layerUrl[$layerName] $popoutLayerId
                        } elseif ($LayerLink -and $LayerLink[$layerName]) {
                            . $getAjaxAndPutIntoContainer $LayerLink[$layerName] $popoutLayerId "Button"
                        } else {
                            ""
                        }


                    if (-not $cssFontAttr -and $Request.UserAgent -like "*MSIE 7.0*") {
                        # compatibility view
                        $cssFontAttr = 'font-size:medium'
                    }
@"
$(. $ShowLayerContent $showButtonId $popoutLayerId -shownstate 'block' -exclusive)
<a id='$ShowButtonId'  class='ui-state-default ui-corner-all btn-primary' href='javascript:void(0)' style='text-align:center;vertical-align:middle;float:left;width:${GridItemWidth}px;height:${GridItemHeight}px;padding:2px;margin:5px;$cssFontAttr' onclick='${ShowButtonId}_click();'>${LayerName}</a> 
"@                
                           
                }

            $null = $outSb.Append("$Content")
            $nlc = 0
            $null = $outSb.Append("<div style='clear:both'></div>")
            $content =
                foreach ($layerName in $Order) {      
                    
                    $nlc++
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
            
@"
<div id='$popoutLayerId' style="display:none;$cssStyleAttr">    
    $(. $getlayerContent $psBoundParameters)
</div>

"@            
                }
            $null=  $outsb.Append("$Content")            
        } elseif ($AsLeftSidebarMenu -or $AsRightSidebarMenu) {
            $null =$outSb.Append("
<div id='$layerId' style='margin-left:0px;margin-right:0px;border:blank'>
")
            $n = 0
            $layerCount = 0
            
            
            $counter = 0 
            $allButtonContent =
                foreach ($layerName in $order) {
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $slideNames += $popoutLayerId
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    
                    $layerCount++
                    $counter++
                    @"

$(. $ShowLayerContent $showButtonId $popoutLayerId -exclusive -shownstate block)    
<a id='$ShowButtonId' style='width:100%;display:block;padding-top:2%;padding-bottom:2%;$cssStyleAttr' class='ui-widget-header ui-corner-all btn-primary' href='javascript:void(0)' onclick='${ShowButtonId}_click();'>${LayerName}</a>
"@
                    
            }
            
                
            if ($AsLeftSidebarMenu) {
                # Sidebar first
                $null = $outSb.Append("<div style='width:${sidebarWidth}%;text-align:center;float:left' class='inverted' valign='top'>$allbuttonContent</div>")
                $floatDirection = "right"                    
            } else {
                $floatDirection = "left"
            }
                
                # Make sure we put int the content column
                $null = $outSb.Append("<div style='width:$(99 - $sidebarWidth)%;border:0px;float:$floatDirection;$cssStyleAttr' >")
                
                $nlc = 0

                $lc = 
                    foreach ($layerName in $Order) {      
                    
                        if (-not $layerName) {continue }                              
                        $safeLayerName = . $getSafeLayerName $layerName 
                        $popoutLayerId = "${LayerID}_$safeLayerName"                    
                        $setIfDefault = if (($defaultToFirst -or (-not $Default)) -and ($nlc -eq 0)) {                        
                            $defaultSlideId = $popoutLayerId 
                            "display:block;"
                        } elseif ($default -eq $layerName) {                        
                            $defaultSlideId = $popoutLayerId 
                            "display:block;"
                        } else {
                            "display:none;"                
                        }
                        $nlc++    
                    
@"
    <div id='$popoutLayerId' style="${setIfDefault}text-align:left">    
        $(. $getlayerContent $psBoundParameters)
    </div>
"@            
                    }
                
                $null = $outsb.Append("$lc</div>")                
                if ($AsRightSidebarMenu) {
                    # Sidebar second
                    $null = $outsb.Append("<div style='width:${sidebarWidth}%;text-align:center;float:right' class='inverted'>$allbuttonContent</div>")                                     
                }
                                            
                $null = $outSb.Append(@"
</div>
<script>
    var ${LayerId}_currentSlide = '$defaultSlideId';
</script>
"@)
        } elseif ($AsPortlet) {
            if (-not $ColumnWidth) { $ColumnWidth = (100 / $ColumnCount).ToString() + "%" } 
            $null = $outsb.Append("
            <style>
                .column { width: ${ColumnWidth}; float:left; padding-bottom:100px } 
                .portlet-header { margin: 0.3em; padding-bottom: 4px; padding-left: 0.2em; }
            	.portlet-header .ui-icon { float: right; }
            	.portlet-content { padding: 0.4em; }
            	.ui-sortable-placeholder { border: 1px dotted black; visibility: visible !important; height: 50px !important; }
            	.ui-sortable-placeholder * { visibility: hidden; }

            </style>
            ")
            $itemsPerColumn = @($order).Count / $ColumnCount
                $portlets = foreach ($layerName in $Order) { 
                         
                    if (-not $layerName) {continue }      
                    $putInParagraph =  $layer[$layerName] -notlike "*<*>*"
                    $safeLayerName = . $getSafeLayerName $layerName
                    "
                    <div class='portlet' $cssStyleChunk>
                        <div class='portlet-header'>${LayerName}</div>
                        <div class='portlet-content'>$($layer[$layerName])</div>
                    </div>                
                    "
                                        
                }            
                
            $content= for ($i =0;$i-lt@($order).Count;$i+=$itemsPerColumn) {
                "<div class='column'>" + ($portlets[$i..($I + ($itemsPerColumn -1))]) + "</div>"
            }
            
            $null = $outSb.Append("$content")
            $null = $outSb.Append(@'
<script>
	$(function() {
		$( ".column" ).sortable({
			connectWith: ".column"
		});

		$( ".portlet" ).addClass( "ui-widget ui-widget-content ui-helper-clearfix ui-corner-all" )
			.find( ".portlet-header" )
				.addClass( "ui-widget-header ui-corner-all" )
				.prepend( '<span class="ui-icon ui-icon-minusthick"></span>')
				.end()
			.find( ".portlet-content" );

		$( ".portlet-header .ui-icon" ).click(function() {
			$( this ).toggleClass( "ui-icon-minusthick" ).toggleClass( "ui-icon-plusthick" );
			$( this ).parents( ".portlet:first" ).find( ".portlet-content" ).toggle();
		});

		$( ".column" ).disableSelection();
	});
</script>
'@)            
            
        } elseif ($AsPopIn -or $AsSlideShow) {
            $slideNames  = @()
            $layerCount = 0 
            $slideButtons = ""
            if (-not ($AsSlideShow -and $HideSlideNameButton)) {
                $slideButtons += "
<div id='${LayerId}_MenuContainer' style='$(if ($MenuBackgroundColor) {"background-color:$MenuBackgroundColor" });text-align:center;margin-left:0%;margin-right:0%;padding-top:0%;padding-bottom:0%' >
                    "
            }            
            $slideButtons += 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    $safeLayerName = . $getSafeLayerName $layerName
                
                    $popoutLayerId = "${LayerID}_$safeLayerName"
                    $slideNames += $popoutLayerId
                    $showButtonId = "${LayerID}_${safeLayerName}_ShowButton"
                    $hideButtonId = "${LayerID}_${safeLayerName}_HideButton"
                    $setIfDefault = if (($defaultToFirst -or ((-not $Default)) -and ($layerCount -eq 0))) {
                        $defaultSlide = $popOutLayerId
                        "${LayerId}_CurrentSlide = '$popOutLayerId'"                     
                    } elseif ($default -eq $layerName.Trim()) {
                        $defaultSlide = $popOutLayerId
                        "${LayerId}_CurrentSlide = '$popOutLayerId'"
                    } else {
                        ""                
                    }
                    $stopSlideShowIfNeeded = if ($ASSlideshow) {
                        "clearInterval(${LayerId}_SlideshowTimer);"
                    } else {
                        ""
                    }
                    $layerCount++
                    # Carefully intermixed JQuery and PowerShell Variable Embedding.  Do Not Touch
                    if (-not ($AsSlideShow -and $HideSlideNameButton)) {
                
                                    
                    if ($layerUrl[$layerName]) {

$SlidebuttonText = if ($UseDotInsteadOfName) {
    "<a style='$cssFontAttr;text-decoration:none' id='$ShowButtonId' href='$($layerUrl[$layerName])'><span style='font-size:6em'>&middot;</span></a>"
} else {
    "<a style='padding:5px;$cssFontAttr' id='$ShowButtonId' class='ui-widget-header ui-corner-all' href='$($layerUrl[$layerName])'>${LayerName}</a>"
}

@"
$SlidebuttonText
"@                    
                    } else {

$SlidebuttonText= 
    if ($UseDotInsteadOfName) {
        "<a style='$cssFontAttr;text-decoration:none' id='$ShowButtonId' href='javascript:void(0)' onclick='${ShowButtonId}_click();'><span style='font-size:6em'>&middot;</span></a>"
    } else {
        "<a style='padding:5px;$cssFontAttr' id='$ShowButtonId' href='javascript:void(0)' onclick='${ShowButtonId}_click();'>${LayerName}</a>"
    }
                
@"
$(. $ShowLayerContent $showButtonId $popoutlayerId -Exclusive -shownstate block -StopSlideShow:$AsSlideShow -IsCurrentSlide:$($defaultSlide -eq $popoutLayerId) )
$SlidebuttonText
$(if ($pipeworksManifest.UseJQueryUI) { "<script>`$('#$showButtonId').button()</script> "} )
"@                
                    }
                }
                                                          
            }

            if (-not $AsSlideShow) {
                $slideButtons += "</div>"
                $null = $outSb.Append("$slideButtons")
            }

            $LayerContent = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                    
                    $safeLayerName = . $getSafeLayerName $layerName
                    $popoutLayerId = "${LayerID}_$safeLayerName"
            
@"
<div id='$popoutLayerId' class='ui-widget-content clickable' style="display:none;border:0px">    
    $(. $GetLayerContent $psBoundParameters)
</div>
"@            
                }


                if ($AsSlideShow) {
$null = $outSb.Append(@"
    <div style='float:right'>
        $slideButtons
    </div>    
"@)                
            }

            $null = $outSb.Append(@"
<div id='${LayerId}_InnerContainer' style='margin-left:auto;margin-right:auto;border:0px;$(if ($AsSlideShow) {'margin-top:1%;'})'>
    $LayerContent
</div>

<script>
    var ${LayerId}_currentSlide = '$defaultSlide';
$(if ($ASSlideShow) { @"
    var ${LayerId}_SlideNames = new Array('$($slidenames -join "','")');
    
    function showNext${LayerId}Slide() {            
        c = 0 
        do {
            if (${LayerId}_SlideNames[c] == ${LayerId}_currentSlide) {
                break;
            }
            c++
        } while (${LayerId}_SlideNames[c])
        if (c == ${LayerId}_SlideNames.length) {
            return;
        }
            
        slideIndex = c;        
        document.getElementById(${LayerId}_currentSlide).style.display = 'none';
        if ((slideIndex + 1) == ${LayerId}_SlideNames.length) {
            nextSlideHtml = document.getElementById(${LayerId}_SlideNames[0]).innerHTML;                
            ${LayerId}_currentSlide = ${LayerId}_SlideNames[0]
        } else {
            nextSlideHtml = document.getElementById(${LayerId}_SlideNames[slideIndex + 1]).innerHTML
            ${LayerId}_currentSlide = ${LayerId}_SlideNames[slideIndex + 1]
        }        
        document.getElementById(${LayerId}_currentSlide).style.display = 'inline';			                               
    }
    var ${LayerId}_SlideshowTimer = setInterval('showNext${LayerId}Slide()', $($autoSwitch.TotalMilliseconds));
"@})    
    
    
    document.getElementById(${LayerId}_currentSlide).style.display = 'inline';			                   
    
</script>

"@)          
            if ($default) {
                $defaultSlide = $LayerID + "_" + (. $getSafeLayerName $default)
                $null = $outSb.Append(@"
<script>
if (document.getElementById('$defaultSlide')) {
    document.getElementById('$defaultSlide').style.display = 'inline'
}
var ${LayerId}_CurrentSlide = '$defaultSlide'
</script>
"@)
            }
        } else {
            $Content = 
                foreach ($layerName in $Order) {      
                    if (-not $layerName) {continue }      
                
                    $safeLayerName = . $getSafeLayerName $layerName
@"
            $(if (-not $DisableLayerSwitcher) {"<script type='text/javascript'>
            
            function switchTo${LayerID}${safeLayerName}() {
                select${LayerID}Layer('${LayerID}_$safeLayerName', true);                                
            }
            
            </script>
            "})
            <div id='${LayerID}_$safeLayerName' style='visibility:hidden;opacity=0;position:absolute;margin-top:0px;margin-left:0px;margin-bottom:0px;margin-right:0px;'>                
                $($layer[$layerName])                
            </div>
            $(if (-not $FixedSize) { "
            <script>
                document.getElementById('${LayerID}_${safeLayerName}').setAttribute('friendlyName', '$layerName');
                $(if ($layerUrl -and $layerUrl[$layerName]) { "document.getElementById('${LayerID}_${safeLayerName}').setAttribute('layerUrl', '$($layerUrl[$layerName])')" })
                layer = document.getElementById('${LayerID}_${safeLayerName}')
                if (layer.addEventListener) {
                    layer.addEventListener('onscroll', function(e) {
                        reset${LayerID}Size();
                    });
                } else {
                    if (layer.attachEvent) {
                        layer.attachEvent('onscroll', function(e) {
                            reset${LayerID}Size();
                        });
                    }
                }
                
            </script>
            "})
"@            
            }

            $null = $outSb.Append("$Content")
        }
              
        
        $requestHandler = if (-not $NotRequestAware) {
            "
            var queryParameters = new Array();
            var query = window.location.search.substring(1);
            var parms = query.split('&');
            for (var i=0; i<parms.length; i++) {
                var pos = parms[i].indexOf('=');
                if (pos > 0) {
                    var key = parms[i].substring(0,pos);
                    var val = parms[i].substring(pos+1);
                    queryParameters[key] = val;
                }
            }
            
            if (queryParameters['$LayerID'] != null) {
                var realLayerName = '${LayerID}_' + queryParameters['$LayerID'];
                if (document.getElementById(realLayerName)) {
                    select${LayerID}Layer(realLayerName, false);
                }
            }
            "
        } else {
            ""
        }
        
        $resizeChunk =if (-not $FixedSize) {
@"
            function isIPad() {  
                return !!(navigator.userAgent.match(/iPad/));  
            }  

            function isIPhone() {  
                return !!(navigator.userAgent.match(/iPhone/));  
            }  

            function reset${LayerID}Size() {
                var element = document.getElementById('$LayerID');            
                // Late bound centering by absolute position.                  
                 
                leftMargin = document.body.clientWidth * $($LeftMargin / 100);
                rightMargin = document.body.clientWidth * $((100 -$RightMargin) / 100);
                topMargin = document.body.clientHeight  * $($TopMargin / 100);            
                bottomMargin = document.body.clientHeight * $($BottomMargin / 100);
                layerwidth = Math.abs(rightMargin - leftMargin);
                layerheight = Math.abs(bottomMargin - topMargin);
                element.style.position = 'absolute';
                element.style.marginLeft = leftMargin + 'px';
                element.style.marginRight = rightMargin + 'px';
                element.style.width = layerwidth + 'px';
                element.style.marginTop = topMargin + 'px';
                element.style.marginBottom = bottomMargin + 'px';                                                
                element.style.height = (document.body.clientHeight -(topMargin + bottomMargin)) + 'px';
                element.style.border = '$Border';
                element.style.borderRadius = '1em';
                element.style.MozBorderRadius = '1em';
                element.style.WebkitBorderRadius = '1em;'
                //element.style.borderRadius = 1em;
                //element.style.borderTopLeftRadius = 1em;
                //element.style.borderTopRightRadius = 1em;
                //element.style.borderBottomLeftRadius = 1em;
                //element.style.borderBottomRightRadius = 1em;
                element.style.clip = 'rect(auto, auto, ' + (element.style.height - 10) + 'px, ' + (element.style.width - 10) + 'px)'
                if (isIPhone() || isIPad()) {
                    element.style.overflow = 'scroll'          
                } else {
                    element.style.overflow = 'auto'                                  
                }
                element.style.webkitoverflowscrolling = 'touch'
                    
                var toolbar = document.getElementById('${LayerID}_Toolbar')
                if (toolbar != null) {
                    toolbar.style.position = 'absolute'
                    toolbar.style.zIndex= '5'                    
                    toolbar.style.width = (layerwidth - 15) + 'px';
                    $(if (-not $ToolbarAbove) {
                        "toolbar.style.bottom =  0  +'px';"
                        "toolbar.style.marginBottom =  0  +'px';"
                    } else {
                        'toolbar.style.marginTop = ${ToolbarMargin} + "px";'
                    })
                    toolbar.style.textAlign = 'right';
                    toolbar.style.marginLeft = '${ToolbarMargin}px';
                    toolbar.style.marginRight = '${ToolbarMargin}5px';
                    toolbar.style.marginBottom = '${ToolbarMargin}5px';
                }                
            }
            
            if (window.addEventListener) {
                window.addEventListener("onresize", function() {
                    reset${LayerID}Size();
                });
                
                window.addEventListener("onorientationchange", function() {
                    reset${LayerID}Size();
                });   
            } else {
                if (window.attachEvent) {
                    window.attachEvent("onresize", function(e) {                        
                        reset${LayerID}Size();
                    });
                }
            }
            
            $enablePanChunk 
            $dragChunk
            
            var original${LayerID}ClientWidth = document.body.clientWidth;
            var original${LayerID}Orientation = window.orientation;
            function checkAndReset${LayerID}Size() {
                if (original${LayerID}ClientWidth != document.body.clientWidth) { 
                    original${LayerID}ClientWidth = document.body.clientWidth
                    reset${LayerID}Size(); 
                }
                if (original${LayerID}Orientation != window.orientation) {
                    original${LayerID}Orientation = window.orientation
                    reset${LayerID}Size(); 
                }
            }
            setInterval("checkAndReset${LayerID}Size();", 100);
            reset${LayerID}Size();
"@            
        } else {
""
        }
        
        $autoSwitcherChunk = if ($psBoundParameters.AutoSwitch -and (-not $asslideshow)) {
            "
            setInterval('moveToNext${LayerID}Item()', $([int]$autoSwitch.TotalMilliseconds)); 
"
        } else {
            ""
        }
        
        $selectDefaultChunk = if (-not $disableLayerSwitcher) {
@"
            var layers = get${LayerID}Layer();
            var layerCount = 0;
            while (layers[layerCount]) {
                layerCount++;
            }

            var defaultValue = '${LayerID}_$("$default".Replace(' ','_').Replace('-', '_'))'
            if (defaultValue != '${LayerID}_') {
                select${LayerID}Layer(defaultValue);
            } else {
                $(if ($DefaultToFirst) { 
                    "var whichLayer = 0" 
                } else {"var whichLayer=Math.round(Math.random()*(layerCount - 1));"})                	                
                if (layers[whichLayer] != null) {
                    if (typeof select${LayerID}Layer == "function") {
                        select${LayerID}Layer(layers[whichLayer].id);
                    } else {
                        layers[whichLayer].style.visibility = 'visible'
                        layers[whichLayer].style.opacity = '1'
                    }
                }                
            }
"@        
        } else {
            ""
        }
        $MouseOverEvent = if ($OpenOnMouseOver) {
            "event: `"mouseover`""
        } else {
            $null
        }
        


        $AccordianChunk = if ($AsAccordian) {
            # Join all settings that exists with newlines.  
            # Powershell list operator magic filters out settings that are null.
            $settings = 
                $MouseOverEvent, 'autoHeight: false', 'navigation: true' -ne $null
            $settingString = $settings -join ",$([Environment]::NewLine)"
            "`$(function() {
		`$( `"#${LayerID}`" ).accordion({
            $settingString             
        });
	})"
        } else { "" }


        $carouselChunk = if ($AsCarousel) {
            # Join all settings that exists with newlines.  
            # Powershell list operator magic filters out settings that are null.                        
            "`$(function() {
		`$( `"#${LayerID}`" ).carousel();
	})"
        } else { "" }
        
        
        $TabChunk = if ($AsTab) {
            $settings = 
                $MouseOverEvent, 'autoHeight: false', 'navigation: true' -ne $null
                
            $tabsBelowChunk = if ($tabBelow) {
                "                
                `$( `".tabs-bottom .ui-tabs-nav, .tabs-bottom .ui-tabs-nav > *`" )
			.removeClass( `"ui-corner-all ui-corner-top`" )
			.addClass( `"ui-corner-bottom`" );
                "
            } else {
                ""
            }
            $settingString = $settings -join ",$([Environment]::NewLine)"
            "`$(function() {
		`$( `"#${LayerID}`" ).tabs({
            $mouseOverEvent
            
        });
        $tabsBelowChunk

	})"

        } else { "" }

        $javaScriptChunk = if ($SelectDefaultChunk -or 
            $ResizeChunk -or 
            $AutoSwitcherChunk -or             
            $Requesthandler -or 
            $tabChunk -or $carouselChunk -or
            $AccordianChunk) { @"
        <script type='text/javascript'>
            $selectDefaultChunk                           
            $resizeChunk                         
            $autoSwitcherChunk            
            $requestHandler                                                       
            $TabChunk
            $carouselChunk
            $AccordianChunk
        </script> 
"@ 
        } else {
            ""
        }       
        
        if ($tabBelow) {
            $null = $outSb.Append(@"
<style>
    .tabs-bottom { position: relative; } 
	.tabs-bottom .ui-tabs-panel { height: 140px; overflow: auto; } 
	.tabs-bottom .ui-tabs-nav { position: absolute !important; left: 0; bottom: 0; right:0; padding: 0 0.2em 0.2em 0; } 
	.tabs-bottom .ui-tabs-nav li { margin-top: -2px !important; margin-bottom: 1px !important; border-top: none; border-bottom-width: 1px; }
	.ui-tabs-selected { margin-top: -3px !important; }
</style>            
"@)            
        }                
        $null = $outSb.Append(@"
        $(if (-not $IsStaticRegion) {
        "
        <div id='${LayerID}_Toolbar' style='margin-top:${ToolbarMargin}px;margin-right:${ToolbarMargin}px;margin-bottom:${ToolbarMargin}px;z-index:-1' NotALayer='true'>            
            $directionButtonText 
            $moreButtonText                   
        </div>"
        })       


        $(if ($AsCarousel) { @"
    </div>
<a class="left carousel-control" href="#$LayerId" data-slide="prev">&lsaquo;</a>
<a class="right carousel-control" href="#$LayerId" data-slide="next">&rsaquo;</a>

"@
})               
        $(if (-not ($AsResizable -or $AsDraggable -or $asWidget)) {'
        
        </div>
        
'})
        $javaScriptChunk


"@)
        }
    $pageAsXml = $outSb.ToString()         -as [xml]
    
    if ($pageAsXml -and 
        $out -notlike "*<pre*") {
        $strWrite = New-Object IO.StringWriter
        $pageAsXml.Save($strWrite)
        $strOut = "$strWrite"
        $strOut.Substring($strOut.IndexOf(">") + 3)
    } else {
        "$outSb"
    }
        
        
        
    }
}
