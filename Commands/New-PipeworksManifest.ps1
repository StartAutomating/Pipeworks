function New-PipeworksManifest
{
    <#
    .Synopsis
        Creates a Pipeworks manifest for a module, so it can become a site.  
    .Description
        Creates a Pipeworks manifest for a module, so that it can become a pipeworks site.

        
        The Pipeworks manifest is at the heart of how you publish your PowerShell as a web site or software service.

        
        New-PipeworksManifest is designed to help you create Pipeworks manifests for most common cases.
    .Example
        # Creates a quick site to download the ScriptCoverage module
        New-PipeworksManifest -Name ScriptCoverage -Domain ScriptCoverage.Start-Automating.com, ScriptCoverasge.StartAutomating.com -AllowDownload
    .Link
        Get-PipeworksManifest        
    #>
    [OutputType([string])]
    param(
    # The name of the module
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)]
    [string]
    $Name,

    # A list of domains where the site will be published 
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=1)]
    [Uri[]]
    $Domain,

    # The names of secure settings that will be used within the website.  You should have already configured these settings locally with Add-SecureSetting.
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=2)]
    [string[]]
    $SecureSetting,


    # A list of Keywords that will be used for all pages in the website
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=2)]
    [string[]]
    $Keyword,

    <#
    
    Commands used within the site.  


    #>
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=3)]
    [Hashtable]
    $WebCommand,

    # The logo of the website.      
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=4)]
    [string]
    $Logo,

    # If set, the module will be downloadable.
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=5)]
    [Switch]
    $AllowDownload,
    
    
    # The table for the website.  
    # This is used to store public information
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=6)]
    [string]
    $Table,    

    # The usertable for the website.  
    # This is used to enable logging into the site, and to store private information
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=7)]
    [string]
    $UserTable,

    # The partition in the usertable where information will be stored.  By default, "Users".  
    # This is used to enable logging into the site, and to store private information
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=8)]
    [string]
    $UserPartition = "Users",


    # The name of the secure setting containing the table storage account name.  By default, AzureStorageAccountName
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $TableAccountNameSetting = "AzureStorageAccountName",

    # The name of the secure setting containing the table storage account key.  By default, AzureStorageAccountKey
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $TableAccountKeySetting = "AzureStorageAccountKey",

    <#
    The LiveConnect ID.
    
    
    This is used to enable Single Sign On using a Microsoft Account.  
    
    
    You must also provide a LiveConnectSecretSetting, and a SecureSetting containing the LiveConnect App Secret.
    #>
    [Parameter(ValueFromPipelineByPropertyName=$true, Position=9)]
    [string]
    $LiveConnectID,

    <# 
    
    The name of the SecureSetting that contains the LiveConnect client secret.


    This is used to enable Single Sign On using a Microsoft Account.  
    #>
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=10)]
    [string]
    $LiveConnectSecretSetting,

    # The LiveConnect Scopes to use.  If not provided, wl.basic, wl.signin, wl.birthday, and wl.emails will be requested
    [Parameter(ValueFromPipelineByPropertyName=$true, Position=11)]
    [string[]]
    $LiveConnectScope,

    # The facebook AppID to use.  If provided, then like buttons will be added to each page and users will be able to login with Facebook
    [string]
    $FacebookAppId,

    # The facebook login scope to use. 
    [string]
    $FacebookScope,
    
    # The schematics used to publish the website.          
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=12)]
    [string[]]
    $Schematic = "Default",


    # A group describes how commands and topics should be grouped together.  
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=13)]
    [Hashtable[]]
    $Group,

    # A paypal email to use for payment processing.
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=14)]
    [string]
    $PaypalEmail,

    # The in which the commands will be shown.  If not provided, commands are sorted alphabetically.  
    # If a Group is provided instead, the Group will be used
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $CommandOrder,

    # Settings related to the main region.  
    # If you need to change the default look and feel of the main region on a pipeworks site, supply a hashtable containing parameters you would use for New-Region.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    $MainRegion,


    # Settings related to the inner region.  
    # If you need to change the default look and feel of the inner regions in a pipeworks site, supply a hashtable containing parameters you would use for New-Region.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    $InnerRegion,

    # Any addtional settings
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable[]]
    $AdditionalSetting,

    # A Google Analytics ID.  This will be added to each page for tracking purposes
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $AnalyticsID,

    # A google site verification.  This will validate the site for Google Webmaster Tools
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $GoogleSiteVerification,
    
    # A Bing Validation Key.  This will validate the site for Bing Webmaster Tools
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $BingValidationKey,

    # A style sheet to use
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable]
    $Style,

    # If set, will use Bootstrap when creating the page
    [Switch]
    [Alias('Bootstrap')]
    $UseBootstrap,


    # The foreground color
    #|Color
    [string]
    $ForegroundColor,

    # The background color
    #|Color
    [string]
    $BackgroundColor,


    # The link color
    #|Color
    [string]
    $LinkColor,

    # A list of CSS files to use
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $Css,

    # A list slides in a slideshow.  Slides can either be a URL, or HTML content
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $SlideShow,

    # GitIt - Git projects to include
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Hashtable[]]
    $GitIt,


    # The JQueryUI Theme to use.  
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $JQueryUITheme,

    # Trusted walkthrus will run their sample code.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $TrustedWalkthru,

    # Web walkthrus will output HTML
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $WebWalkthru,   

    # An AdSense ID
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $AdSenseID,   

    # An AdSense AdSlot 
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $AdSlot,   

    # If set, will add a plusone to each page
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $AddPlusOne,

    # If set, will add a tweet button to each page
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $Tweet,


    # If set, will use the Raphael.js library in the site
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $UseRaphael,

    # If set, will use the g.Raphael.js library in the site
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $UseGraphael,

    # If set, will use the tablesorter JQuery plugin in the site
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $UseTablesorter,

    # If set, will change the default branding.  By default, pages will display "Powered By PowerShell Pipeworks"
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $Branding,

    # Provides the identity of a Win8 App
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $Win8Identity,

    # Provides the publisher of a Win8 App
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $Win8Publisher,

    # Provides the version of a Win8 App
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Version]
    $Win8Version = "1.0.0.0",

    # Provides logos for use in a Win8 App
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({
    $requiredKeys = "splash","small","wide","store","square"

    $missingKeys = @()
    $ht = $_
    foreach ($r in $requiredKeys) {
        if (-not $ht.Contains($r)) {
            $missingKeys +=$r
        }
    }
    if ($missingKeys) {
        throw "Missing $missingKeys"
    } else {
        return $true
    }    
    })]
    [Hashtable]
    $Win8Logo   
    )


    process {
        $params = @{} + $PSBoundParameters
        $params.Remove("AdditionalSetting")
        $params.Remove("Name")
        $params.Remove("CSS")
        $params.Remove("Domain")
        $params.Remove("Schematic")
        $params.Remove("AdditionalSetting")
        $params.Remove("UserTable")
        $params.Remove("Table")
        $params.Remove("LiveConnectId")
        $params.Remove("LiveConnectSecretSetting")
        $params.Remove("LiveConnectScope")
        $params.Remove("PayPalEmail")
        $params.Remove("Win8Logo")
        $params.Remove("Win8Version")
        $params.Remove("Win8Identity")
        $params.Remove("Win8Publisher")
        $params.Remove("ForegroundColor")
        $params.Remove("BackgroundColor")
        $params.Remove("LinkColor")
        $params.Remove("SlideShow")
        
        if ($Win8Logo -and $Win8Identity -and $Win8Publisher) {
            $params += @{
                Win8 = @{
                    Identity = @{
                        Name = $Win8Identity
                        Publisher = $Win8Publisher
                        Version = $Win8Version
                    }
                    Assets = @{
                        "splash.png" = $Win8Logo.Splash
                        "smallTile.png" = $Win8Logo.Small
                        "wideTile.png" = $Win8Logo.Wide
                        "storeLogo.png" = $Win8Logo.Store
                        "squareTile.png" = $Win8Logo.Square
                    }

                    ServiceUrl = "http://$Domain/"
                    Name  = $Name

                    
                }
            }       
        }


        if ($SlideShow) {
            $params += @{
                SlideShow = @{
                    Slides = $SlideShow
                }
            }
        }

        
        if ($PSBoundParameters.PayPalEmail) {
            $params+= @{
                PaymentProcessing = @{
                    "PayPalEmail" = $PaypalEmail
                }
            }
        }
        
        if ($PSBoundParameters.Domain) {
            $params+= @{
                DomainSchematics = @{
                    "$($domain -join ' | ')" = ($Schematic -join "','")
                }
            }
        }

        if ($PSBoundParameters.Css) {
            $c = 0
            $cssDict = @{}
            foreach ($cs in $css) {
                $cssDict["Css$c"] = $cs
                $c++
            }
            $params+= @{
                Css = $cssDict
            }
        }

        if ($PSBoundParameters.AdditionalSetting) {
            foreach ($a in $AdditionalSetting) {
                $params+= $a
            }
        }

        if ($PSBoundParameters.UserTable) {
            $params += @{
                UserTable = @{
                    Name = $UserTable
                    Partition = $UserPartition
                    StorageAccountSetting = $TableAccountNameSetting
                    StorageKeySetting = $TableAccountKeySetting
                }
            }
        }

        if ($PSBoundParameters.Table) {
            $params += @{
                Table = @{
                    Name = $Table                    
                    StorageAccountSetting = $TableAccountNameSetting
                    StorageKeySetting = $TableAccountKeySetting
                }
            }
        }

        if ($PSBoundParameters.LiveConnectID -and $psBoundParameters.LiveConnectSecretSetting) {            
            $params += @{
                LiveConnect = @{
                    ClientID = $LiveConnectID
                    ClientSecretSetting = $LiveConnectSecretSetting                    
                }
            }

            if ($liveconnectScope) {
                $params.LiveConnect.Scope = $LiveConnectScope
            }
        }

        if ($PSBoundParameters.FacebookAppId) {            
            $params += @{
                Facebook = @{
                    AppId = $FacebookAppId                    
                }
            }

            if ($FacebookScope) {
                $params.Facebook.Scope = $FacebookScope
            }
        }

        if ($ForegroundColor -or $BackgroundColor -or $LinkColor) {
            if (-not $params.Style) {
                $params.Style = @{}
            }

            if (-not $params.Style.Body) {
                $params.Style.Body = @{}
            }

            if (-not $params.Style.A) {
                $params.Style.A = @{}
            }

            $invert = {
                param($color)
                $color = '#' + $color.TrimStart('#')
                $redPart = [int]::Parse($color[1..2]-join'', 
                    [Globalization.NumberStyles]::HexNumber)
                $greenPart = [int]::Parse($color[3..4]-join '', 
                    [Globalization.NumberStyles]::HexNumber)
                $bluePart = [int]::Parse($color[5..6] -join'', 
                    [Globalization.NumberStyles]::HexNumber)
        
                $newr = $redPart
                $newB = $bluePart
                $newg = $greenPart

                $newr = (255 - $redPart)
                $newg = (255 - $greenPart)
                $newb = (255 - $bluePart)

                "#" + ("{0:x}" -f ([int]$newr)).PadLeft(2, "0") + ("{0:x}" -f ([int]$newg)).PadLeft(2, "0") + ("{0:x}" -f ([int]$newb)).PadLeft(2, "0") 
            }
             
    
                                                
        
            
            if ($foregroundColor -and -not $BackgroundColor) {
                $BackgroundColor = & $invert $ForegroundColor
            } elseif ($BackgroundColor -and -not $ForegroundColor) {
                $ForegroundColor = & $invert $BackgroundColor
            }

            if ($ForegroundColor) {
                $params.Style.Body.color = "#" + "$ForegroundColor".TrimStart('#') 
            }

            if ($BackgroundColor) {
                $params.Style.Body.'background-color' = "#" + "$BackgroundColor".TrimStart('#') 
            }


            if ($LinkColor) {
                $params.Style.a.color  = "#" + "$LinkColor".TrimStart('#') 
            } else {
                $params.Style.a.color  = "#" + "$foregroundColor".TrimStart('#') 
            }
            
        }



        Write-PowerShellHashtable $params
    }
}