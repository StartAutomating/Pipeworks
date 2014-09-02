function Write-Link
{
    <#
    .Synopsis
        Writes links to other web content
    .Description
        Writes links to other web content, and makes linking to rich web content easy.
    .Example
        Write-Link -Url "start-automating.com"
    .Example
        Write-Link -Url "Start-Automating.com" -Caption "Save Time, Save Money, Start Automating"
    .Example
        # Write links to several subpages
        Write-Link -Url "a","b","c"
    .Example
        # A link to a twitter page
        Write-Link "@jamesbru"    
    .Example
        # A link to social sites
        Write-Link "google:+1", "twitter:tweet"    
    .Example
         Write-Link -Button -Url "Url" -Caption "<span class='ui-icon ui-icon-extlink'>
                </span>
                <br/>
                <span style='text-align:center'>
                Visit Website
                </span>"     
    .Link 
        Out-HTML
    #>
    
    [CmdletBinding(DefaultParameterSetName='ToUrl')]
    [OutputType([string])]
    param(
    # If set, will output a simple <a href='$url'>$caption</a>.
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=5)]
    [Switch]$Simple,    
    
    # The caption of the link    
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=1,ParameterSetName='ToUrl')]
    [Alias('Name')]
    [string[]]$Caption,
    
    
    # The ID to use for the link
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=2,ParameterSetName='ToUrl')]
    [string[]]$Id,

    # The url of the link.   
    [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0,Mandatory=$true,ParameterSetName='ToUrl')]
    [Alias('Href', 'Src', 'Source')]
    [uri[]]$Url,
        
    # A table of links
    [Parameter(ValueFromPipelineByPropertyName=$true,Mandatory=$true,ParameterSetName='LinkTable')]
    [Alias('Links', 'LinkTable')]
    [Hashtable]
    $SortedLinkTable,
       
    # If set, will lay out multiple links horizontally.
    # By default, multiple links will be displayed line by line
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=2)]
    [Switch]
    $Horizontal,
    
    # Will put a horizontalSeparator in between each horizontal link
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=3)]
    [string]$HorizontalSeparator = ' | ',
    
    # If set, will lay out multiple links in a list
    # By default, multiple links will be displayed line by line
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=4)]
    [Alias('AsList')]
    [Switch]
    $List,
    
    # If set, will lay out multiple links in a numbered list
    # By default, multiple links will be displayed line by line
    [Alias('AsNumberedList')]
    [Switch]
    $NumberedList,
    
    # IF set, will make each item a jQueryUI button
    [Alias('AsButton')]
    [switch]
    $Button,

    # If provided, will fire a javascript notify event when the link is actived.  Notify events are used to communicate out of the browser.
    [Alias('Notification')]
    [string]
    $Notify,

    
    # The CSS class to use for the link
    [string[]]
    $CssClass,
    
    # A style attribute table
    [Hashtable]    
    $Style,
    
    # If not set, captions taken from the URL will be stripped of any extension
    [Switch]
    $KeepExtension,
    
    # The Microdata item property
    [Alias('ItemProperty')]
    [string]   
    $ItemProp,
    
    # The Microdata item ID
    [string]
    $ItemId,
    
    # The name of the item
    [Parameter(Mandatory=$true,ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$ItemName,
    # The price of the item
    [Parameter(Mandatory=$true,ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [Double]$ItemPrice,
    
    # If set, will make a subscription button
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [Switch]$Subscribe,

    # The billing frequency of a subscription.  By default, monthly.
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [ValidateSet("Daily", "Weekly", "Monthly", "Yearly")]
    [string]
    $BillingFrequency = "Monthly",

    # The billing periods in a subscription.  By default, one.
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]    
    [Alias('BillingPeriod')]
    [Uint32]
    $BillingPeriodCount = 1,

    # If set, will make a donation button
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [Switch]$Donate,

    # A Description of the item
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$ItemDescription,
    
    # The currency used to purchase the item
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$Currency = "USD",    
    
    # The MerchantId for GoogleCheckout.  By using this parameter, a buy button for Google Checkout will be outputted.
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$GoogleCheckoutMerchantId,
    
    # The Email Address for a paypal account.  By using this parameter, a buy button for Paypal will be outputted
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$PaypalEmail,

    # The Publishable Key for Stripe
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$StripePublishableKey,

    # The URL for a buy code handler.  By using this parameter, payment can be accepted via buy codes
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [Uri]$BuyCodeHandler,

    # The IPN url for a paypal transcation.  By using this parameter, a buy button for Paypal will be outputted
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$ToPayPal,
    
    # The IPN url for a paypal transcation.  By using this parameter, a buy button for Paypal will be outputted
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$PaypalIPN,
    
    # The custom property for a paypal transcation.  By using this parameter, a buy button for Paypal will be outputted
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$PaypalCustom,

    # An amazon payments account id       
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonPaymentsAccountId,
    
    # An amazon payments access key
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonAccessKey,   
    
    # An amazon payments secret key
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonSecretKey,   
    
    # The amazon return url
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonReturnUrl,   
    
    # The Amazon IPN url
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonIpnUrl,   
    
    # The Amazon transaction abandoned URL
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$AmazonAbandonUrl,   
    
    # If provided, will collect the shipping address for a purchase on Amazon
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [switch]$CollectShippingAddress,
    
    # The digital key used to unlock the purchased item
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$DigitalKey,
    
    # The digital url the purchased item can be found at
    [Parameter(ParameterSetName='ToBuyButton',ValueFromPipelineByPropertyName=$true)]
    [string]$DigtialUrl,
    
    
    # If set, will create a link to a login button on facebook
    [Parameter(ParameterSetName='ToFacebookLogin',Mandatory=$true)]
    [Switch]$ToFacebookLogin,

    # If set, will create a link to a login button with Live Connect
    [Parameter(ParameterSetName='ToLiveConnectLogin',Mandatory=$true)]
    [Switch]$ToLiveConnectLogin,

    # The live connect client ID.  This is used to generate a login link to a Microsoft Live Connect web app.
    [Parameter(ParameterSetName='ToLiveConnectLogin',Mandatory=$true)]
    [string]$LiveConnectClientId,
    
    # The Module Service URL that will handle the facebook login.  This URL must be relative.
    [Parameter(ParameterSetName='ToFacebookLogin')]
    [Parameter(ParameterSetName='ToLiveConnectLogin')]
    [string]$ModuleServiceUrl = "/Module.ashx",
    
    # The facebook app ID.  This is used to generate a facebook login link.
    [Parameter(ParameterSetName='ToFacebookLogin',Mandatory=$true)]
    [string]$FacebookAppId,
    
    # The login scope requested from Facebook users.  By default, only email is requested
    [Parameter(ParameterSetName='ToFacebookLogin')]
    [string[]]$FacebookLoginScope = @("Email", "user_birthday"),
    
    # The login scope requested.  By default, email, basic information, and the right to sign in automatically are included.
    [Parameter(ParameterSetName='ToLiveConnectLogin')]
    [string[]]$LiveConnectScope = @("wl.email", "wl.basic", "wl.signin"),

    # If provided, will user facebook OAuth, instead of the javascript API, for the actual like button
    [Parameter(ParameterSetName='ToFacebookLogin')]
    [Parameter(ParameterSetName='ToLiveConnectLogin')]
    [Switch]
    $UseOAuth
    )
    begin {
        $allCaptions = New-Object Collections.ArrayList
        $allUrls = New-Object Collections.ArrayList
        $allIds = New-Object Collections.ArrayList
    }
    
    process {
        #region Accumulate Parameters in certain parameter sets
        if ($psCmdlet.ParameterSetName -eq 'ToUrl') {
            if ($psBoundParameters['caption']) {
                $null = $allCaptions.AddRange($caption)
            } 
            
            if ($psBoundParameters['id']) {
                $null = $allIds.AddRange($Id)
            }
            
            if ($url) {
                $null = $allUrls.AddRange($url)                 
            }                        
        } elseif ($psCmdlet.ParameterSetName -eq 'LinkTable') {
            foreach ($kv in ($SortedlinkTable.GetEnumerator() | Sort-Object Key))  {
                $null = $allCaptions.Add($kv.Key)
                $null = $allUrls.Add($kv.Value)
            }
            $psBoundParameters['Caption'] = $allCaptions
        } elseif ($psCmdlet.ParameterSetName -eq 'ToBuyButton') {
        
        } elseif ($psCmdlet.ParameterSetName -eq 'ToFacebookLogin') {
            
        }
        #endregion Accumulate Parameters in certain parameter sets
    }
    end {    
        $styleChunk = ""
        if ($button) {
            # If it's a button, add the appropriate CSS classes
            $cssClass += 'fg-button', 'ui-state-default', 'ui-corner-all', 'jQueryUIButton', 'btn', 'btn-primary'
            # If no horizontal separator was explicitly set, use a blank instead of a middot
            if (-not $psBoundParameters.HorizontalSeparator) {
                $horizontalSeparator = " "
            }
            $jQueryButton = "cssClass='jQueryUIButton'"
        }
        if ($Notify) {
            $cssClass += 'fg-button', 'ui-state-default', 'ui-corner-all'
        }
        $classChunk = if ($cssClass) {            
            " class='$($cssClass -join ' ')'"        
        } else { 
            ""
        
        }     

        $styleChunk  = if ($psBoundParameters.Style) {
            " style=`"$(Write-CSS -Style $style -OutputAttribute)`""
        } else {
            '' 
        }
        $c= 0                
        
        $links = foreach ($u in $allUrls) {
            if (-not $u) { continue } 
            if (-not $psBoundParameters.Caption) { 
                if ($KeepExtension) {
                    $caption = $u 
                } else {
                    if ($u.ToString().Contains(".")) {
                        $slashCount = $u.ToString().ToCharArray() | Where-Object { $_ -eq '/' } | Measure-Object                         
                        if (($slashCount.Count -gt 3) -or ($slashCount.Count -eq 0)) {
                            $caption = "$($u.ToString().Substring(0, $u.ToString().LastIndexOf('.')))"                        
                        } else {
                            $caption = $u 
                        }
                    } else {
                        $caption = $u
                    }
                }
                $allCaptions = @($caption)
            }             
            
            if ($allCaptions.Count -gt 1) {
                $cap = $allCaptions[$c]
            } else {
                $cap = $allCaptions
            }
            
            $hrefId = if ($allIds.Count -eq $allUrls.Count) {
                $allIds[$c]
            } else {
                $null
            }
            $idChunk = if ($hrefId) {' id="' + $hrefId + '"'} else { "" }
            if ($ItemProp) {
                $idChunk  += ' itemprop="' + $itemprop + '"'
            } 
            
            if ($itemId) {
                $idChunk  += ' itemid="' + $itemid+ '"'
            }                       
                        
            if ($Simple) {
                # Simple links are always just <a> </a>
                "<a href='$u'${idChunk}${classChunk}${styleChunk} $(if ($notify) {'onclick="try { windows.external.notify(''' + $notify.Replace("'", "''") + "'')} catch {}"})>$cap</a>"
            } else {
                # If the link is to a plusone, or the link is google:+1 or google:PlusOne, write a Google Plus link
                if ($u -like "http://google/plusone*" -or ($u.scheme -eq "google" -and ($u.PathAndQuery -eq '+1' -or $U.PathAndQuery -eq 'PlusOne'))) {
@"
<!-- Place this tag in your head or just before your close body tag -->
<script type="text/javascript" src="https://apis.google.com/js/plusone.js"></script>

<!-- Place this tag where you want the +1 button to render -->
<div class="g-plusone" data-size="medium"></div>
"@                    
                } elseif ($u -like "http://facebook/share" -or ($u.Scheme -eq 'Facebook' -and $u.PathAndQuery -eq 'share')) {
                    # If the url is like http://facebook/share, or facebook:share, write a share link
@"

<script>
    u = encodeURIComponent(location.href);
    t = encodeURIComponent(document.title);
    document.write('<a $(if ($button) {'class="jQueryUIButton"'}) style="vertical-align:text-top" href="http://www.facebook.com/sharer.php?u=' + u + '&t=' + t + '"><img border="0" src="http://facebook.com/favicon.ico" /></a>');   
</script>
"@                
                } elseif ($u -like "http://facebook/like" -or ($u.Scheme -eq 'Facebook' -and $u.PathAndQuery -eq 'Like')) {
                    # If the url is like http://facebook/like or is facebook:like, write a Facebook like link
"<div class='fb-like' data-send='true' data-width='250' data-show-faces='false' data-layout='button_count' ></div>"                
                } elseif ($u -like "http://twitter/tweet" -or ($u.Scheme -eq 'Twitter' -and $u.PathAndQuery -eq 'tweet')) {
                    # If the url is like http://twitter/tweet, or twitter:tweet, write a Tweet this link
                    @"
<a href="http://twitter.com/share" data-count="none" class="twitter-share-button $(if ($button) {'jQueryUIButton'})">Tweet</a><script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>
"@
                } elseif ($u.Scheme -eq 'YouTube') {               
                    #Youtube channel link                
                    "<a $jQueryButton href='http://youtube.com/$($u.PathAndQuery)'><img src='http://www.youtube.com/favicon.ico' border='0' /></a>"
                } elseif ($u.Scheme -eq 'Twitter' -and $u.PathAndQuery -like "@*") {
                    #Twitter Profile Link
                    if ($cap -eq $u)  { $cap = $u.PathAndQuery } 
                    "<a $jQueryButton href='http://twitter.com/$($u.PathAndQuery.Trim('@'))'>$cap</a>"
                } elseif ($u.Scheme -eq 'Twitter' -and $u.PathAndQuery -like "follow@*") {
                    #if the url is twitter:follow@*, then create a follow button for the user
                    $handle = $u.PathAndQuery.Replace('follow@', '')
@"
<a href="https://twitter.com/${handle}" class="twitter-follow-button $(if ($button) {'jQueryUIButton'})" data-show-count="false" data-size="none" data-show-screen-name="false">Follow @${handle}</a>
<script src="//platform.twitter.com/widgets.js" type="text/javascript"></script>
"@
                } elseif ('OnClick', 'Click', 'On_Click' -contains $u.Scheme) {
                    # OnClick event
                    
                    if (-not $idChunk) { 
                        $idChunk= "id ='OnClickButton$(Get-Random)'" 
                        
                    } 
                    
                    $scriptContent = $u.OriginalString -ireplace "$($u.Scheme):"
                    
                    $RealId = (($idChunk -split "[=']") -ne "")[-1]
                    "<a href='javascript:void(0)' $idChunk>$cap</a>
                    <script>
                    `$('#$realId').click(function() {
                        $scriptContent
                    })$(if ($Button) { '.button()' })                    
                    </script>"
                } elseif ($u.Scheme -eq 'Disqus') {
                    # If the scheme is like disqus, then create a link to disqus
@"
<div id="disqus_thread"></div>
<script type="text/javascript">
    /* * * CONFIGURATION VARIABLES: EDIT BEFORE PASTING INTO YOUR WEBPAGE * * */
    var disqus_shortname = '$($u.PathAndQuery)'; // required: replace example with your forum shortname

    /* * * DON'T EDIT BELOW THIS LINE * * */
    (function() {
        var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
        dsq.src = 'http://' + disqus_shortname + '.disqus.com/embed.js';
        (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
    })();
</script>
<noscript>Please enable JavaScript to view the <a href="http://disqus.com/?ref_noscript">comments powered by Disqus.</a></noscript>
<a href="http://disqus.com" class="dsq-brlink">blog comments powered by <span class="logo-disqus">Disqus</span></a>
"@                    
                } elseif ($u.Scheme -ieq 'Play') {
#Play media in <embed>
$newUrl = "http" + $u.Tostring().Substring($u.Scheme.Length)
@"                
<embed src="$newUrl" autostart="true" loop="FALSE" ${idChunk}> </embed>                    
"@                
                } elseif ($u.Scheme -ieq 'Loop') {
#Play media in hidden embed
$newUrl = "http" + $u.Tostring().Substring($u.Scheme.Length)
@"                
<embed src="$newUrl" autostart="true" loop="TRUE" hidden='true' ${idChunk}> </embed>                    
"@                
                } elseif ($u.Scheme -ieq 'PlayHidden') {
#Play media in hidden embed
$newUrl = "http" + $u.Tostring().Substring($u.Scheme.Length)
@"                
<embed src="$newUrl" autostart="true" loop="FALSE" hidden='true' ${idChunk}> </embed>                    
"@                
                } elseif ($u.Scheme -ieq 'Pause') {
#Play media in <embed>
$newUrl = "http" + $u.Tostring().Substring($u.Scheme.Length)
@"                
<embed src="$newUrl" autostart="false" loop="FALSE" ${idChunk}> </embed>                    
"@                
                } elseif ($u.Scheme -ieq 'Loop') {
$newUrl = "http" + $u.Tostring().Substring($u.Scheme.Length)
@"                
<embed src="$newUrl" autostart="true" loop="true" ${idChunk}> </embed>                                       
"@                
                } elseif ($u.Scheme -ieq 'LoopHidden') {
$newUrl = "http" + $u.Tostring().Substring($u.Scheme.Length)
@"                
<embed src="$newUrl" autostart="true" loop="true" hidden='true' ${idChunk}> </embed>                                       
"@                
                } elseif ($u  -like "*.jpeg" -or $u -like "*.jpg" -or $u -like "*.gif" -or $u -like "*.tiff" -or $u -like "*.png") {

@"
<a href='$u'><img ${idChunk} border='0' src='$u' /></a>
"@                    
                } elseif ($u  -like "*.mp3") {
@"

<script language="JavaScript" src="http://ourmedia.org/players/1pixelout/audio-player.js">
</script>
<object type="application/x-shockwave-flash" data="http://channels.ourmedia.org/players/1pixelout/player.swf" id="audioplayer1" height="24" width="290">
    <param name="movie" value="http://channels.ourmedia.org/players/1pixelout/player.swf">
    <param name="FlashVars" value="playerID=1&amp;soundFile=$u">
    <param name="quality" value="high">
    <param name="menu" value="false">
    <param name="wmode" value="transparent">
</object>
<a href='$u'${idChunk}>$Cap</a>
"@                    
                } elseif ($u -like "http*://www.youtube.com/watch*=*") {                    
                    # YouTube Link
                    $type, $youTubeId = $u.Query -split '='
                    $type = $type.Trim("?")
@"
<object style="height: $(if ($style.Height) {$style.Height } else {"360px"}); width: $(if ($style.Width) {$style.Width } else {"640px"})" >
    <param name="movie" value="http://www.youtube.com/${type}/${youTubeId}?version=3&feature=player_detailpage" />
    <param name="allowFullScreen" value="true" />
    <param name="allowScriptAccess" value="always" />
    <embed src="http://www.youtube.com/${type}/${youTubeId}?version=3&feature=player_detailpage" type="application/x-shockwave-flash" allowfullscreen="true" allowScriptAccess="always" width="$(if ($style.Width) {$style.Width.ToString().TrimEnd("px") } else {"640"})" height="$(if ($style.Height) {$style.Height.ToString().TrimEnd("px") } else {"360"})" />
</object>

"@

                } elseif ($u -like "http://player.vimeo.com/video/*") {
                    # Vimeo link
                    $vimeoId = ([uri]$u).Segments[-1]
@"                        
<iframe src="http://player.vimeo.com/video/${vimeoId}?title=0&amp;byline=0&amp;portrait=0" width="400" height="245" frameborder="0">
</iframe><p><a href="http://vimeo.com/{$vimeoId}">$($cap)</a></p>
"@
                } elseif ($u -like "http://stackoverflow.com/users/*") {
                    $userId = ([uri]$u).Segments[-2]
                    $userName = ([uri]$u).Segments[-1]
@"
<a href="http://stackoverflow.com/users/${userId}/${UserName}">
<img src="http://stackoverflow.com/users/flair/${UserId}.png" width="208" height="58" alt="profile for ${UserName} at Stack Overflow, Q&amp;A for professional and enthusiast programmers" title="profile for Start-Automating at Stack Overflow, Q&amp;A for professional and enthusiast programmers">
</a>
"@                    
                } elseif ($u -like "*.jp?g" -or $u -like "*.png") {
                    "<a href='$u'>
                    <img src='$u' ${idChunk}/>
                    $cap
                    </a>"
                } else {
                    # Just a simple link
                    "<a href='$u'${idChunk}${classChunk}${styleChunk} $(if ($notify) {'onclick="try { windows.external.notify(''' + $notify.Replace("'", "''") + ''')} catch {}"'})>$("$cap".Replace('&', '&amp;'))</a>"
                }
            }        
            
            $c++
        }
        
        $textOutput = if ($links.Count -or $List -or $NumberedList) {
            if ($List) {
                '<ul><li>' + ($links -join '</li><li>') + '</li></ul>'
            } elseif ($NumberedList) {
                '<ol><li>' + ($links -join '</li><li>') + '</li></ol>'
            } elseif ($horizontal) {
                $links -join "$HorizontalSeparator" 
            } else {
                $links -join "<br/>"
            }
            

        } elseif ($psCmdlet.ParameterSetName -eq 'ToBuyButton') {
            
            if ($GoogleCheckoutMerchantId) { 
@"
<form action="https://checkout.google.com/api/checkout/v2/checkoutForm/Merchant/$GoogleCheckoutMerchantId" id="BB_BuyButtonForm" method="post" name="BB_BuyButtonForm" target="_top">
    <input name="item_name_1" type="hidden" value="$([Web.httputility]::HtmlAttributeEncode($ItemName))"/>
    <input name="item_description_1" type="hidden" value="$([Web.httputility]::HtmlAttributeEncode($ItemDescription))"/>
    <input name="item_quantity_1" type="hidden" value="1"/>
    <input name="item_price_1" type="hidden" value="$([Math]::Round($ItemPrice, 2))"/>
    <input name="item_currency_1" type="hidden" value="$Currency"/>
    $(if ($digitalKey) { "<input name='shopping-cart.items.item-1.digital-content.key' type='hidden' value='$DigitalKey'/> " })
    $(if ($DigtialUrl) { "<input name='shopping-cart.items.item-1.digital-content.url' type='hidden' value='$DigtialUrl'/> " })    
    <input name="_charset_" type="hidden" value="utf-8"/>
    <input alt="" src="https://checkout.google.com/buttons/buy.gif?merchant_id=${GoogleCheckoutMerchantId}&amp;w=117&amp;h=48&amp;style=white&amp;variant=text&amp;loc=en_US" type="image"/>
</form>
"@
            }
            
            if ($PaypalEmail) {
$payPalIpnChunk = if ($payPalIpn) {
    "<input type=`"hidden`" name=`"notify_url`" value=`"$payPalIpn`">"
} else {
    ""
}
$payPalCmd = if ($Subscribe) {
    "_xclick-subscriptions"
} elseif ($Donate) {
    "_donations"
} else {
    "_xclick"
}

$payPalButtonImage = if ($subscribe) {
    "https://www.paypalobjects.com/en_AU/i/btn/btn_subscribeCC_LG.gif"
} elseif ($Donate) {
    "https://www.paypalobjects.com/en_AU/i/btn/btn_donateCC_LG.gif"
} else {
    "http://www.paypal.com/en_US/i/btn/btn_buynow_LG.gif"
}

$amountChunk = if ($Subscribe) {
    "<input type='hidden' name='a3' value='$([Math]::Round($ItemPrice, 2))'>
    <input type='hidden' name='p3' value='$($BillingPeriodCount)'>
    <input type='hidden' name='src' value='1'>
    <input type='hidden' name='t3' value='$($BillingFrequency.ToUpper().ToString()[0])1'>
    "
} elseif ($Donate) {
    "<input type='hidden' name='amount' value='$([Math]::Round($ItemPrice, 2))'>"
} else {
    "<input type='hidden' name='amount' value='$([Math]::Round($ItemPrice, 2))'>"
}

$payPalCustomChunk = if ($payPalCustom) {
    "<input type=`"hidden`" name=`"custom`" value=`"$([Web.httputility]::HtmlAttributeEncode($payPalCustom))`">"
} else {
    ""
}
@"
<form name="_xclick" action="https://www.paypal.com/cgi-bin/webscr" method="post">
<input type="hidden" name="cmd" value="$payPalCmd">
<input type="hidden" name="business" value="$payPalEmail">
<input type="hidden" name="currency_code" value="$Currency">
<input type="hidden" name="item_name" value="$([Web.httputility]::HtmlAttributeEncode($ItemName))">
<input type="hidden" name="item_number" value="$([Web.httputility]::HtmlAttributeEncode($ItemId))">
$amountChunk
$payPalIpnChunk 
$payPalCustomChunk 
<input type="image" src="$payPalButtonImage" border="0" name="submit" alt="Make payments with PayPal - it's fast, free and secure!">
</form>
"@            
            }


            if ($StripePublishableKey) {
@"
<form>
    <script
      src="https://checkout.stripe.com/v2/checkout.js" class="stripe-button"
      data-key="$StripePublishableKey"
      data-amount="$ItemPrice"
      data-name="Demo Site"
      data-description="$ItemDescription ($ItemPrice)"
      data-currency="$Currency"
      data-image="/128x128.png">
    </script>
</form>
"@
            }

            if ($BuyCodeHandler) {
@"
<form name="_buyCode" action="$buyCodeHandler" method="post">

<div style='margin-top:2%;margin-bottom:2%;'>
    <div style='width:37%;float:left;'>        
    <label for='PotentialBuyCode' style='text-align:left;font-size:1.3em'>
    Enter Code
    </label>
    <br style='line-height:150%' /></div>
    <div style='float:right;width:60%;'>                
    <input style='width:100%' name='PotentialBuyCode' value='' />
    </div>
    <div style='clear:both'>
    </div>
    </div>
    <input type='submit' class='buyCode_SubmitButton btn btn-primary' value='Enter Code' style='border:1px solid black;padding:5;font-size:large'/>
</form>
"@          
            }
            
            if ($amazonaccessKey -and $amazonSecretKey) {
                if (-not ('SimplePay1.ButtonGenerator' -as [Type])) {
# It may seem strange that one compiles C# in order to spit out strings, but, blame it on the HMAC
$simplePaybuttonGenerator = @'
/******************************************************************************* 
 *  Copyright 2008-2010 Amazon Technologies, Inc.
 *  Licensed under the Apache License, Version 2.0 (the "License"); 
 *  
 *  You may not use this file except in compliance with the License. 
 *  You may obtain a copy of the License at: http://aws.amazon.com/apache2.0
 *  This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR 
 *  CONDITIONS OF ANY KIND, either express or implied. See the License for the 
 *  specific language governing permissions and limitations under the License.
 * ***************************************************************************** 
 */

namespace SimplePay1
{
    using System;
    using System.IO;
    using System.Collections.Generic;
    using System.Security.Cryptography;    
    using System.Text;

    /// <summary>
    /// Amazon FPS  Exception provides details of errors 
    /// returned by Amazon FPS  service
    /// </summary>
    public class AmazonFPSException : Exception
    {

        private String message = null;

        /// <summary>
        /// Constructs AmazonFPSException with message
        /// </summary>
        /// <param name="message">Overview of error</param>
        public AmazonFPSException(String message)
        {
            this.message = message;
        }

        /// <summary>
        /// Gets error message
        /// </summary>
        public override String Message
        {
            get { return this.message; }
        }
    }
    
    public class ButtonGenerator
    {
        public static readonly String SIGNATURE_KEYNAME = "signature";
        public static readonly String SIGNATURE_METHOD_KEYNAME = "signatureMethod";
        public static readonly String SIGNATURE_VERSION_KEYNAME = "signatureVersion";
        public static readonly String SIGNATURE_VERSION_2 = "2";
        public static readonly String HMAC_SHA1_ALGORITHM = "HmacSHA1";
        public static readonly String HMAC_SHA256_ALGORITHM = "HmacSHA256";
        public static readonly String COBRANDING_STYLE = "logo";
        public static readonly String AppName = "ASP";
        public static readonly String HttpPostMethod = "POST";
        public static readonly String SANDBOX_END_POINT = "https://authorize.payments-sandbox.amazon.com/pba/paypipeline";
        public static readonly String SANDBOX_IMAGE_LOCATION = "https://authorize.payments-sandbox.amazon.com/pba/images/payNowButton.png";
        public static readonly String PROD_END_POINT = "https://authorize.payments.amazon.com/pba/paypipeline";
        public static readonly String PROD_IMAGE_LOCATION = "https://authorize.payments.amazon.com/pba/images/payNowButton.png";

            /**
            * Function creates a Map of key-value pairs for all valid values passed to the function 
            * @param accessKey - Put your Access Key here  
            * @param amount - Enter the amount you want to collect for the item
            * @param description - description - Enter a description of the item
            * @param referenceId - Optionally enter an ID that uniquely identifies this transaction for your records
            * @param abandonUrl - Optionally, enter the URL where senders should be redirected if they cancel their transaction
            * @param returnUrl - Optionally enter the URL where buyers should be redirected after they complete the transaction
            * @param immediateReturn - Optionally, enter "1" if you want to skip the final status page in Amazon Payments, 
            * @param processImmediate - Optionally, enter "1" if you want to settle the transaction immediately else "0". Default value is "1"
            * @param ipnUrl - Optionally, type the URL of your host page to which Amazon Payments should send the IPN transaction information.
            * @param collectShippingAddress - Optionally, enter "1" if you want Amazon Payments to return the buyer's shipping address as part of the transaction information.
            * @param signatureMethod -Valid values are  HmacSHA256 and HmacSHA1
            * @return - A map of key of key-value pair for all non null parameters
            * @throws SignatureException
            */
             public static IDictionary<String, String> getSimplePayStandardParams(String accessKey,String amount, String description, String referenceId, String immediateReturn,
                    String returnUrl, String abandonUrl, String processImmediate, String ipnUrl, String collectShippingAddress,
                    String signatureMethod, String amazonPaymentsAccountId)
            {
                String cobrandingStyle = COBRANDING_STYLE;
          
                IDictionary<String, String> formHiddenInputs = new SortedDictionary<String, String>(StringComparer.Ordinal);

                if (accessKey != null) formHiddenInputs.Add("accessKey", accessKey);
                else throw new System.ArgumentException("AccessKey is required");
                if (amount != null) formHiddenInputs.Add("amount", amount);
                else throw new System.ArgumentException("Amount is required");
                if (description!= null)formHiddenInputs.Add("description", description);
                 else throw new System.ArgumentException("Description is required");
                if (signatureMethod != null) formHiddenInputs.Add(SIGNATURE_METHOD_KEYNAME, signatureMethod);
                 else throw new System.ArgumentException("Signature method is required");
                if (referenceId != null) formHiddenInputs.Add("referenceId", referenceId);
                if (immediateReturn != null) formHiddenInputs.Add("immediateReturn", immediateReturn);
                if (returnUrl != null) formHiddenInputs.Add("returnUrl", returnUrl);
                if (abandonUrl != null) formHiddenInputs.Add("abandonUrl", abandonUrl);
                if (processImmediate != null) formHiddenInputs.Add("processImmediate", processImmediate);
                if (ipnUrl != null) formHiddenInputs.Add("ipnUrl", ipnUrl);
                if (cobrandingStyle != null) formHiddenInputs.Add("cobrandingStyle", cobrandingStyle);
                if (collectShippingAddress != null) formHiddenInputs.Add("collectShippingAddress", collectShippingAddress);
                if (amazonPaymentsAccountId != null) formHiddenInputs.Add("amazonPaymentsAccountId", amazonPaymentsAccountId);
                formHiddenInputs.Add(SIGNATURE_VERSION_KEYNAME, SIGNATURE_VERSION_2);
                return formHiddenInputs;
            }
            /**
             * Creates a form from the provided key-value pairs 
             * @param formHiddenInputs - A map of key of key-value pair for all non null parameters
             * @param serviceEndPoint - The Endpoint to be used based on environment selected
             * @param imageLocation - The imagelocation based on environment
             * @return - An html form created using the key-value pairs
             */

           public static String getSimplePayStandardForm(IDictionary<String, String> formHiddenInputs,String ServiceEndPoint,String imageLocation)
            {
                StringBuilder form = new StringBuilder("<form action=\"" + ServiceEndPoint + "\" method=\"" + HttpPostMethod + "\">\n");
                form.Append("<input type=\"image\" src=\""+ imageLocation + "\" border=\"0\">\n");
                foreach (KeyValuePair<String, String> pair in formHiddenInputs)
                {
                    form.Append("<input type=\"hidden\" name=\"" + pair.Key + "\" value=\"" + pair.Value + "\" >\n");
                }
                form.Append("</form>\n");
                return form.ToString();
            }
           /**
          * Function Generates the html form  
          * @param accessKey - Put your Access Key here  
          * @param secretKey - Put your secret Key here
          * @param amount - Enter the amount you want to collect for the item
          * @param description - description - Enter a description of the item
          * @param referenceId - Optionally enter an ID that uniquely identifies this transaction for your records
          * @param abandonUrl - Optionally, enter the URL where senders should be redirected if they cancel their transaction
          * @param returnUrl - Optionally enter the URL where buyers should be redirected after they complete the transaction
          * @param immediateReturn - Optionally, enter "1" if you want to skip the final status page in Amazon Payments, 
          * @param processImmediate - Optionally, enter "1" if you want to settle the transaction immediately else "0". Default value is "1"
          * @param ipnUrl - Optionally, type the URL of your host page to which Amazon Payments should send the IPN transaction information.
          * @param collectShippingAddress - Optionally, enter "1" if you want Amazon Payments to return the buyer's shipping address as part of the transaction information.
          * @param signatureMethod -Valid values are  HmacSHA256 and HmacSHA1
          * @param environment - Sets the environment where your form will point to can be "sandbox" or "prod"
          * @throws SignatureException
          */

           public static string GenerateForm(String accessKey, String secretKey, String amount, String description, String referenceId, String immediateReturn,
                                      String returnUrl, String abandonUrl, String processImmediate, String ipnUrl, String collectShippingAddress, String signatureMethod, String environment, String amazonPaymentsAccountId)
            {
               
                    String endPoint, imageLocation;
                    if (environment.Equals("prod"))
                    {

                        endPoint = PROD_END_POINT;
                        imageLocation = PROD_IMAGE_LOCATION;
                    }
                     else
                    {
                        endPoint = SANDBOX_END_POINT;
                        imageLocation = SANDBOX_IMAGE_LOCATION;

                    }

                    Uri serviceEndPoint = new Uri(endPoint);
                    IDictionary<String, String> parameters = getSimplePayStandardParams(accessKey, amount, description, referenceId, immediateReturn,
                                                 returnUrl, abandonUrl, processImmediate, ipnUrl, collectShippingAddress, signatureMethod, amazonPaymentsAccountId);
                    String signature = SignatureUtils.signParameters(parameters, secretKey, HttpPostMethod, serviceEndPoint.Host, serviceEndPoint.AbsolutePath,signatureMethod);
                    parameters.Add(SIGNATURE_KEYNAME, signature);
                    String simplePayStandardForm = getSimplePayStandardForm(parameters,endPoint,imageLocation);
                    return simplePayStandardForm;
                   
                     
            }
        
    }



    public class SignatureUtils
    {
        public static readonly String SIGNATURE_KEYNAME = "signature";
        // Constants used when constructing the string to sign for v2
        public static readonly String AppName = "ASP";
        public static readonly String NewLine = "\n";
        public static readonly String EmptyUriPath = "/";
        public static String equals = "=";
        public static readonly String And = "&";
        public static readonly String UTF_8_Encoding = "UTF-8";

        /**
	 * Computes RFC 2104-compliant HMAC signature for request parameters This
	 * involves 2 steps - Calculate string-to-sign and then compute signature
	 * 
	 * Step 1: Calculate string-to-sign
	 *  In Signature Version 2, string to sign is based on following:
	 * 
	 * 1. The HTTP Request Method (POST or GET) followed by an ASCII newline
	 * (%0A) 2. The HTTP Host header in the form of lowercase host, followed by
	 * an ASCII newline. 3. The URL encoded HTTP absolute path component of the
	 * URI (up to but not including the query string parameters); if this is
	 * empty use a forward '/'. This parameter is followed by an ASCII newline.
	 * 4. The concatenation of all query string components (names and values) as
	 * UTF-8 characters which are URL encoded as per RFC 3986 (hex characters
	 * MUST be uppercase), sorted using lexicographic byte ordering. Parameter
	 * names are separated from their values by the '=' character (ASCII
	 * character 61), even if the value is empty. Pairs of parameter and values
	 * are separated by the '&' character (ASCII code 38).
	 * 
	 * Step 2: Compute RFC 2104-compliant HMAC signature
	 */

        public static String signParameters(IDictionary<String, String> parameters, String key, String HttpMethod, String Host, String RequestURI,String algorithm) 
        {
            String stringToSign = null;
            stringToSign = calculateStringToSignV2(parameters, HttpMethod, Host, RequestURI);
            return sign(stringToSign, key, algorithm);
        }


        /**
    	 * Calculate String to Sign for SignatureVersion 2
	     * @param parameters
    	 * @param httpMethod - POST or GET
	     * @param hostHeader - Service end point
    	 * @param requestURI - Path
	     * @return
    	 */
        private static String calculateStringToSignV2(IDictionary<String, String> parameters, String httpMethod, String hostHeader, String requestURI)// throws SignatureException
        {
            StringBuilder stringToSign = new StringBuilder();
            if (httpMethod == null) throw new Exception("HttpMethod cannot be null");
            stringToSign.Append(httpMethod);
            stringToSign.Append(NewLine);

            // The host header - must eventually convert to lower case
            // Host header should not be null, but in Http 1.0, it can be, in that
            // case just append empty string ""
            if (hostHeader == null)
                stringToSign.Append("");
            else
                stringToSign.Append(hostHeader.ToLower());
            stringToSign.Append(NewLine);

            if (requestURI == null || requestURI.Length == 0)
                stringToSign.Append(EmptyUriPath);
            else
                stringToSign.Append(UrlEncode(requestURI, true));
            stringToSign.Append(NewLine);

            IDictionary<String, String> sortedParamMap = new SortedDictionary<String, String>(parameters, StringComparer.Ordinal);
            foreach (String key in sortedParamMap.Keys)
            {
                if (String.Compare(key, SIGNATURE_KEYNAME, true) == 0) continue;
                stringToSign.Append(UrlEncode(key, false));
                stringToSign.Append(equals);
                stringToSign.Append(UrlEncode(sortedParamMap[key], false));
                stringToSign.Append(And);
            }

            String result = stringToSign.ToString();
            return result.Remove(result.Length - 1);
        }

        public static String UrlEncode(String data, bool path)
        {
            StringBuilder encoded = new StringBuilder();
            String unreservedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.~" + (path ? "/" : "");

            foreach (char symbol in System.Text.Encoding.UTF8.GetBytes(data))
            {
                if (unreservedChars.IndexOf(symbol) != -1)
                {
                    encoded.Append(symbol);
                }
                else
                {
                    encoded.Append("%" + String.Format("{0:X2}", (int)symbol));
                }
            }

            return encoded.ToString();

        }

        /**
         * Computes RFC 2104-compliant HMAC signature.
         */
        public static String sign(String data, String key, String signatureMethod)// throws SignatureException
        {
            try
            {
                ASCIIEncoding encoding = new ASCIIEncoding();
                HMAC Hmac = HMAC.Create(signatureMethod);
                Hmac.Key = encoding.GetBytes(key);
                Hmac.Initialize();
                CryptoStream cs = new CryptoStream(Stream.Null, Hmac, CryptoStreamMode.Write);
                cs.Write(encoding.GetBytes(data), 0, encoding.GetBytes(data).Length);
                cs.Close();
                byte[] rawResult = Hmac.Hash;
                String sig = Convert.ToBase64String(rawResult, 0, rawResult.Length);
                return sig;
            }
            catch (Exception e)
            {
                throw new AmazonFPSException("Failed to generate signature: " + e.Message);
            }
        }

    }
}
'@
    Add-Type -TypeDefinition $simplePaybuttonGenerator 
}


$buttonGenerator = 'SimplePay1.ButtonGenerator' -as [Type]
$buttonGenerator::GenerateForm($AmazonAccessKey, 
    $AmazonSecretKey, 
    "$Currency $([Math]::Round($ItemPrice, 2))", #Price
    $ItemName, #Description,
    $ItemId,
    1,
    $AmazonReturnUrl,  
    $AmazonAbandonUrl,
    1,
    $AmazonIPNUrl,
    "$(if ($CollectShippingAddress) { '1' } else { '0'})",
    "HmacSHA256",
    "Prod",
    $AmazonPaymentsAccountId)



<#
@"
<form action="https://authorize.payments.amazon.com/pba/paypipeline" method="post">
  <input type="hidden" name="immediateReturn" value="1" >
  <input type="hidden" name="amount" value="$Currency $([Math]::Round($ItemPrice, 2))" >
  <input type="hidden" name="collectShippingAddress" value="$(if ($CollectShippingAddress) { '1' } else { '0'})" >
  <input type="hidden" name="isDonationWidget" value="0" >
  <input type="hidden" name="description" value="$([Web.httputility]::HtmlAttributeEncode($ItemName))" >
  <input type="hidden" name="amazonPaymentsAccountId" value="$amazonPaymentsAccountId" >
  <input type="hidden" name="accessKey" value="$amazonaccessKey" >
  <input type="hidden" name="cobrandingStyle" value="logo" >
  <input type="hidden" name="processImmediate" value="1" >
  <input type="image" src="http://g-ecx.images-amazon.com/images/G/01/asp/beige_small_paynow_withmsg_whitebg.gif" border="0">
</form>            
"@
#>
            }             
        } elseif ($psCmdlet.ParameterSetName -eq 'ToLiveConnectLogin') {

$scope = $LiveConnectScope -join " "
$session["LiveIDRedirectURL"] = "${ModuleServiceUrl}?LiveIdConfirmed=true"
$loginLink = "https://login.live.com/oauth20_authorize.srf?client_id=$LiveConnectClientId&amp;redirect_uri=$([Web.HttpUtility]::UrlEncode($session["LiveIDRedirectURL"]))&amp;scope=$([Web.HttpUtility]::UrlEncode($scope).Replace("+", "%20"))&amp;response_type=code"
@"
<a class='LiveLoginButton btn btn-primary login' href='$loginLink' style='font-size:small'>Login</a>
$(if ($pipeworksManifest.UseJQueryUI -or $pipeworksManifest.UseBootstrap) { "<script>
`$('.LiveLoginButton').button()
</script>" 
})
"@
            
        } elseif ($psCmdlet.ParameterSetName -eq 'ToFacebookLogin') {
$scope = $facebookLoginScope -join ","


$overrideClick = if ($UseOAuth) {
    @"
`$('.fb-login-button').click(function(event) {

window.location = 'https://www.facebook.com/dialog/oauth?client_id=$FacebookAppId&redirect_uri=$([Web.HttpUtility]::UrlEncode("${ModuleServiceUrl}?FacebookConfirmed=true"))&scope=$scope&display=popup';
    event.preventDefault();
    })
"@
} else {
    ""
}

$activateAfterLogin = if (-not $UseOAuth) {
    'onlogin="javascript:CallAfterLogin();"'
} else {
    "

    
    "
}



@"
<div class="resultsContainer">
</div>
<div class="fbLoginButtonHolder">            
<div class="fb-login-button" $activateAfterLogin style='margin-top:1%;margin-bottom:1%' size="medium" scope="$scope">Connect With Facebook</div>
<script type="text/javascript"> 
    window.fbAsyncInit = function() {     
        FB.init({appId: $FacebookAppId,
            cookie: true,
            xfbml: true,
            oauth: true}
        );
    }; 
    (function() {
        var e = document.createElement('script'); 
        e.async = true;e.src = document.location.protocol +'//connect.facebook.net/en_US/all.js'; 
        document.getElementById('fb-root').appendChild(e);}()); 


    $overrideclick

   
    function CallAfterLogin(){ 
        FB.login(function(response) {
            if (response.authResponse) { 
            
                
                `$("#LoginButton").hide(); //hide login button once user authorize the application 
                var accessToken = FB.getAuthResponse()['accessToken'];
                `$(".resultsContainer").html('Please Wait | Connecting to Facebook'); //show loading image while we process user 
                
                FB.api('/me', function(response) {                                  
                    window.location.href = "${ModuleServiceUrl}?FacebookConfirmed=true&email=" + response.email + "&AccessToken=" + accessToken + "&ReturnTo=" + escape(window.location.href);
                });                                                                    
        } 
    }); 
} 

</script> 
</div>            
"@            
        } else {
            "$links"
        }
        
        if ($button) {
"
$textOutput
"        
        } else {
            $textOutput
        }
    }
}
