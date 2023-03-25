function Get-Web {
    <#
    .Synopsis
        Gets content from the web, or parses web content.
    .Description
        Gets content from the web.
        
        If -Tag is passed, extracts out tags from within the document.

        If -AsByte is passed, returns the response bytes
    .Example
       # Download the Microsoft front page and extract out links
       Get-Web -Url http://microsoft.com/ -Tag a
    .Example
       # Extract the rows from ConvertTo-HTML
       $text = Get-ChildItem | Select Name, LastWriteTime | ConvertTo-HTML | Out-String 
       Get-Web -Tag "tr" -Html $text
    .Example
        # Extract all PHP elements from a directory of .php scripts
        Get-ChildItem -Recurse -Filter *.php | 
            Get-Web -Tag .\?php, \?
    .Example
        # Extract all asp tags from .asp files
        Get-ChildItem -Recurse | 
            Where-Object { '.aspx', '.asp'. '.ashx' -contains $_.Extension } |
            Get-Web -Tag .\%
    .Example
        # Get a list of all schemas from schema.org
        $schemasList = Get-Web -Url http://schema.org/docs/full.html -Tag a | 
            Where-Object { $_.Xml.href -like '/*' } | 
            ForEach-Object { "http://schema.org" + $_.xml.Href } 
            
    .Example
        # Extract out the example of a schema from schema.org        
        
        $schema = 'http://schema.org/Event'
        Get-Web -Url $schema -Tag pre | 
            Where-Object { $_.Xml.Class -like '*prettyprint*' }  | 
            ForEach-Object {
                Get-Web -Html $_.Xml.InnerText -AsMicrodata -ItemType $schema 
            }  
    
    .Link
        http://schema.org
    #>
    
    [CmdletBinding(DefaultParameterSetName='HTML')]
    [OutputType([PSObject],[string])]
    param(
    # The Url
    [Parameter(Mandatory=$true,Position=0,ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Alias('Uri')]
    [string]$Url,

    # The tags to extract.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]$Tag,
    
    # If used with -Tag, -RequireAttribute will only match tags with a given keyword in the tag
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string[]]$TextInTag,
     
    # The source HTML.
    [Parameter(Mandatory=$true,ParameterSetName='HTML',ValueFromPipelineByPropertyName=$true)]
    [string]$Html,    
    
    # The root of the website.  
    # All images, css, javascript, related links, and pages beneath this root will be downloaded into a hashtable
    [Parameter(Mandatory=$true,ParameterSetName='WGet',ValueFromPipelineByPropertyName=$true)]
    [string]$Root,

    # Any parameters to the URL
    [Parameter(ParameterSetName='Url',Position=1,ValueFromPipelineByPropertyName=$true)]
    [Collections.IDictionary]$Parameter,
    
    # Filename
    [Parameter(Mandatory=$true,ParameterSetName='FileName',ValueFromPipelineByPropertyName=$true)]
    [Alias('Fullname')]
    [ValidateScript({$ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($_)})]
    [string]$FileName,    

    # The User Agent
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [string]$UserAgent = "PowerShellPipeworks/Get-Web (1.0 powershellpipeworks.com)",
    
    # If set, will not show progress for long-running operations
    [Switch]$HideProgress,

    # If set, returns results as bytes
    [Alias('Byte', 'Bytes')]
    [Switch]$AsByte,

    # If set, returns results as XML
    [Alias('Xml')]
    [Switch]$AsXml,
    
    # If set, returns results as json
    [Switch]$AsJson,

    # If set, will output the results of a web request to a file.
    # This is the best option for large content, as it avoids excessive memory consumption.
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Parameter(ParameterSetName='WGet',ValueFromPipelineByPropertyName=$true)]
    [string]
    $OutputPath,
    
    # An output stream.    
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [IO.Stream]
    $OutputStream,

    # If set, extracts Microdata out of a page
    [Alias('Microdata')]
    [Switch]$AsMicrodata,

    # If set, extracts data attributes.
    [switch]$DataAttribute,
    
    # If set, will get back microdata from the page that matches an itemtype
    [string[]]$ItemType,
    
    # If set, extracts OpenGraph information out of a page
    [Switch]$OpenGraph,
    
    # If set, will extract all meta tags from a page
    [Switch]$MetaData,

    # The MIME content type you're requesting from the web site
    [Alias('CT')]
    [string]$ContentType,
    
    # A list of acceptable content types.  These are used for the Accept header, and to compare the final content type to determine if it was unexpected
    [string[]]$Accept,
    
    # The credential used to connect to the web site
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Alias('Credential','C')]
    [Management.Automation.PSCredential]
    $WebCredential,

    # If set, will use the default user credential to connect to the web site
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [switch]
    $UseDefaultCredential,    
    
    # The HTTP method.
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]    
    [ValidateSet('GET','POST', 'PUT', 'DELETE', 'OPTIONS', 'HEAD', 'TRACE', 'CONNECT', 'MERGE')]
    [Alias('M')]
    [string]$Method = "GET",
    
    # a hashtable of headers to send with the request.
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Alias('Headers','H')]   
    [Collections.IDictionary]$Header,

    # The Request Body.  This can be either a string, or bytes
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [PSObject]
    $RequestBody,

    # If set, will request the web site asynchronously, and return the results
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $Async,

    # The Request String Encoding
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [ValidateScript({[Text.Encoding]::$_ -ne $null})]
    [string]
    $RequestStringEncoding = "UTF8",
    
    # The signature message.  This parameter is used with -SignatureKey, -SignaturePrefix, and -SignatureAlgorithmn to create an Authorization header.
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [string]
    $Signature,
    
    # The signature prefix.  This will be appended before the computed authorization header.  
    # This parameter is used with -Signature, -SignaturePrefix, and -SignatureAlgorithmn to create an Authorization header    
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [string]
    $SignaturePrefix,

    # The signature key.  This is used to compute the signature hash.  This can be either a byte array or a Base64 encoded string
    # This parameter is used with -Signature, -SignatureKey, and -SignatureAlgorithmn to create an Authorization header    
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [string]
    $SignatureKey,

    # The signature algorithmn is the hashing algirthmn that is used to compute a signature hash.  The default is HMACSHA256
    # This parameter is used with -Signature, -SignatureKey, and -SignaturePrefix to create an Authorization header    
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [ValidateSet('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'HMAC', 'HMACSHA1','HMACSHA256')]
    [string]
    $SignatureAlgorithmn = 'HMACSHA256',

    # If set, the signature will be URL encoded
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $EncodeSignature,

    # One or more thumbprints for certificates
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [string[]]
    $ThumbPrint,

    # Any request ascii data.  Data will be joined together with &, and will be sent in the request body.
    [Parameter(ParameterSetName='Url',ValueFromPipelineByPropertyName=$true)]
    [Alias('d')]
    [string[]]
    $Data,

    [Parameter(Mandatory=$true,ParameterSetName='AsyncResponse',ValueFromPipelineByPropertyName=$true)]
    [Alias('AsyncResult')]
    [IAsyncResult]
    $IASyncResult,

    [Parameter(Mandatory=$true,ParameterSetName='AsyncResponse',ValueFromPipelineByPropertyName=$true)]
    [PSObject]
    $WebRequest,    

    # A Progress Identifier.  This is used to show progress inside of an existing layer of progress bars.
    [int]$ProgressIdentifier,

    # If set, the server error will be turned into a result.  
    # This is useful for servers that provide complex error information inside of XML or JSON.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $UseErrorAsResult,

    # If set, then a note property will be added to the result containing the response headers
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $OutputResponseHeader,

    # The amount of time before a web request times out.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Timespan]
    $Timeout,

    # The size of the upload buffer.  
    # If you upload a file larger than this size, it will be uploaded in chunks and a progress bar will be displayed.
    # Each chunk will be the size of the upload buffer
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Alias('UploadBufferSize','DownloadBufferSize')]
    [Uint32]
    $BufferSize = 512kb,

    # The HTTP HOST 
    [string]
    $HostHeader,

    # If set, will preauthenticate the web request.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $PreAuthenticate,

    # If set, will run in a background job.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $AsJob,

    # If set, will use a the Net.WebRequest class to download.
    # Included for backwards compatibility.  Prior versions of Get-Web allowed use of xmlHttpRequest with COM.
    [Switch]
    $UseWebRequest
    )
    
    begin {
        #region Declarations
        $WGet = {
            # First, we make a copy of root.
            $currentRoot = "$Root"
            # If the current root looks like it is missing an end slash, 
            if ($currentRoot -like "http*//*" -and $currentRoot -notlike "http*//*/") {
                $currentRoot+= '/' # we'll add it.
            }
            # Next, find the host name of the current root.  
            # This is how we'll know if we should follow the link down.
            $hostname = ([uri]$currentRoot).DnsSafeHost
            # Speaking of which, we need to create a queue of links to follow,
            $followMeDown = [Collections.Queue]::new()
            # add the current root,
            $null = $followMeDown.Enqueue($currentRoot)
            # and create a hashtable to store the results.
            $pagedata = @{}


            while ($followMeDown.Count -gt 0) # While the queue isn't empty,
            {
                # Get the next link
                $pageRoot = $followMeDown.Dequeue()
                # and determine what host it came from.
                $pageHost = ([uri]$pageRoot).DnsSafeHost
                # If the link was to a different host, continue to the next.
                if ($pageHost -ne $hostname) { continue }
                # Now we determine the relative root,
                $relativeRoot = $pageRoot.Substring(0, $pageRoot.LastIndexOf("/"))
                # clear the page HTML,
                $pageHtml = ""
                # and get the content bytes and the headers
                $pageContent = Get-Web -Url $pageRoot -AsByte -OutputResponseHeader
                # If the returned content type was text, 
                if ($pageContent.Headers.'Content-Type' -like 'text/*') {
                    $ms = [IO.MemoryStream]::new($pageContent)
                    $reader = [IO.StreamReader]::new($ms, $true)
                    $pagedata[$relativeRoot] = $reader.ReadToEnd() # treat it as text.                    
                    $reader.Close();$reader.Dispose()
                    $ms.Close();$ms.Dispose()
                    # If it was HTML, save it to $PageHTML, so we can follow subsequent links
                    if ($pageContent.Headers.'Content-Type' -like '*html*') {
                        $pageHtml = $pagedata[$relativeRoot]
                    }
                } else {
                    # If the content wasn't text, save off the bytes.
                    $pagedata[$relativeRoot] = $pageContent
                }
    
                # If we don't have any HTML to parse, continue to the next link.
                if (-not $pageHtml) { continue }

                # Since we have an HTML response, parse out any tags that could contain a link:
                # <a>anchors,<link>links,<img>images, and <script>scripts
                $linksCssAndImagesAndScripts = Get-Web -Html $pageHtml -Tag a, link, img, script
    
                # First, we'll make on pass through the tags
                $relativeLinks = $linksCssAndImagesAndScripts | 
                    Where-Object {
                        $_.Xml.Name -eq 'a' # to find all of the <a> tags.
                    } |
                    Where-Object {
                        $x = $_.Xml
                        $startTag = $x.SelectSingleNode("/*")                        
                        $startTag.Href -and (
                            ($startTag.Href -like "/*" -or $startTag.Href -notlike "*://*") -or
                            (([uri]$startTag.Href).DnsSafeHost -eq "$hostname")
                        ) -and ($startTag.Href -notlike "javascript:*")
                    }

    
                $images = $linksCssAndImagesAndScripts |
                    Where-Object {
                        ($_.StartTag -like "*img*" -or $_.StartTag -like "*script*") -and
                        $_.StartTag -match "src=['`"]{0,1}([\w\:/\.-]{1,})"
                    } |ForEach-Object {            
                        $Matches.'1'
                    }

                $potentialHrefs = @(
                    foreach ($img in $images) { $img }
                    foreach ($r in $relativeLinks) { $r.Xml.Href }
                )
                

                foreach ($href in $potentialHrefs) {
                    if (-not $href) { continue } 
                    if ($href -like "$relativeRoot*") {
                        if (-not $followMeDown.Contains($href) -and -not $pagedata.Contains($href)) {
                            $null = $followMeDown.Enqueue($href)
                        }
                    } if (-not ([uri]$href).DnsSafeHost) {
                        if (-not $followMeDown.Contains($href) -and -not $pagedata.Contains($href)) {

                            if ($href -like "/*") {
                                $null = $followMeDown.Enqueue(([uri]$currentRoot).Scheme+ "://" + $hostname + $href)
                            } else {
                                $null = $followMeDown.Enqueue($relativeRoot + '/' + $href)
                            }                
                        }
                    } else {            
                        $null = $null
                    }
                }
            }


            if ($GetStory) {
                $story = @{}
                foreach ($pd in $pagedata.GetEnumerator()) {
                    if ($pd.value -is [string]) {        
                        $partsOfStory = @(
                            Get-Web -Tag 'div', 'p' -Html $pd.Value | 
                            ForEach-Object {
                                $firsttagEnd = $_.StartTag.IndexOfAny(' >')
                                $tagName = $_.StartTag.Substring(1, $firsttagEnd - 1)
                                $newTag=  $_.Tag.Substring($_.StartTag.Length)
                                $changeindex = $newTag.IndexOf("*</$tagName>", [stringcomparison]::OrdinalIgnoreCase)
                                if ($changeindex -ne -1) {
                                    $newTag = $newTag.Substring(0, $changeindex)
                                }
                                $strippedTags = [Regex]::Replace($newTag, "<[^>]*>", [Environment]::NewLine);
                                $strippedTags 
                            })

                        if ($partsOfStory -ne '') {
                            $segments = ([uri]$pd.Key).Segments
                            if ($segments.Count -le 1) {
                                $newPath  = '/'
                            } else {
                                $newPath  = (([uri]$pd.Key).Segments -join '' -replace '/', '_').Trim('_')
                            }
            
                            $story[$newPath] = $partsOfStory -ne '' -join ([Environment]::NewLine * 4)
                        }   
                    }
                }

                $pagedata += $story
            }
            return $pagedata
        }

        #endregion Declarations
        #region Initialization

        # In order to turn HTML into XML, we'll need to convert a lot of valid HTML entities into something XHTML can work with. 
        # To that end, create a lookup table now to use later.
        $replacements = @{                                                                                                                                
            "<BR>"="<BR />" ; "<HR>"="<HR />"  ;"&nbsp;" = " "  ;  '&macr;'='¯'
            '&ETH;'='Ð'     ; '&para;'='¶'     ;'&yen;'='¥'     ;  '&ordm;'='º'
            '&sup1;'='¹'    ; '&ordf;'='ª'     ;'&shy;'='­'      ;  '&sup2;'='²'
            '&Ccedil;'='Ç'  ; '&Icirc;'='Î'    ;'&curren;'='¤'  ;'&frac12;'='½'
            '&sect;'='§'    ; '&Acirc;'='â'    ;'&Ucirc;'='Û'   ;'&plusmn;'='±'
            '&reg;'='®'     ; '&acute;'='´'    ;'&Otilde;'='Õ'  ;'&brvbar;'='¦'
            '&pound;'='£'   ; '&Iacute;'='Í'   ;'&middot;'='·'  ; '&Ocirc;'='Ô'
            '&frac14;'='¼'  ; '&uml;'='¨'      ;'&Oacute;'='Ó'  ;   '&deg;'='°'
            '&Yacute;'='Ý'  ;'&Agrave;'='À'    ;'&Ouml;'='Ö'    ;  '&quot;'='"'
            '&Atilde;'='Ã'  ;'&THORN;'='Þ'     ;'&frac34;'='¾'  ;'&iquest;'='¿'
            '&times;'='×'   ;'&Oslash;'='Ø'    ;'&divide;'='÷'  ; '&iexcl;'='¡'
            '&sup3;'='³'    ;'&Iuml;'='Ï'      ;'&cent;'='¢'    ;  '&copy;'='©'
            '&Auml;'='Ä'    ;'&Ograve;'='Ò'    ;'&Aring;'='Å'   ;'&Egrave;'='È'
            '&Uuml;'='Ü'    ;'&Aacute;'='Á'    ;'&Igrave;'='Ì'  ;'&Ntilde;'='Ñ'
            '&Ecirc;'='Ê'   ;'&cedil;'='¸'     ;'&Ugrave;'='Ù'  ;'&szlig;'='ß'
            '&raquo;'='»'   ;'&euml;'='ë'      ;'&Eacute;'='É'  ;'&micro;'='µ'
            '&not;'='¬'     ;'&Uacute;'='Ú'    ;'&AElig;'='Æ'   ;'&euro;'= "€"        
            '&mdash;' = '—' ;'&amp;' = '&'            
        }

        $quotes = '"', "'"
        
        # In case it wasn't loaded, import System.Web.
        if (-not ('Web.HttpUtility' -as [type])) {
            Add-Type -AssemblyName System.Web        
        }

        # If a progress identifier was provided, cache it.
        if ($ProgressIdentifier) {
            $script:CachedProgressId  = $ProgressIdentifier
        }

        # If no cached progress identifier exists, create a random one.
        if (-not $script:CachedProgressId) {
            $script:CachedProgressId = Get-Random
        }
        # Set the progress ID to the cached value
        $progressId  = $script:CachedProgressId

        if ($AsMicrodata -or $DataAttribute) {
                $HTML_IDAttribute = [Regex]::new(@'

(?<=             # We only want to match an ID if it's in a tag
                 # but we don't want to match the tag itself, so we use a lookbehind
    <[\w-]+      # to find the tag
    [^>]+?(?=    # and anything but closing carets
        \z|id    # until the end of the string or 'id'
    )
)
id               # now we match the id itself
\s{0,}           # and optional whitespace
=                # and the equal
\s{0,}           # and more optional whitespace
(?>              # Then, there are 3 ways we can have an ID
    '            # Between single quotes
    (?<ID>       # The ID is...
        ((?:
            ''|  # any double paired quote OR
            \\'| # any slash-escaped single quote
            [^'] # any non-quote
        )*)
    )
    '            # followed by the closing quote
    |            # OR
    "            # double quotes
    (?<ID>       # The ID is...
    .*?          # anything until
    (?<!(\\))    # a not-escape
    )"           # double-quote
    |            # OR
    (?<ID>       # The ID is..
        [\w-]+   # any number of word characters or dashes.
    )
)
'@, 'IgnoreCase,IgnorePatternWhitespace', '00:00:05')        
        }
        #endregion Initialization


    }
    
    process {
        # First off, see if we're going to run -AsJob.
        if ($AsJob) {
            # If so, since Get-Web doesn't have dependencies, this is a piece of cake.
            # Start off by making a copy of the bound parameters, 
            $splat = @{} + $psBoundParameters
            $splat.Remove('AsJob') # and then removing -AsJob.            
            $JobSplat = @{
                # A bit of metaprogramming magic creates a script that embeds itself,
                ScriptBlock = [ScriptBlock]::Create("
param([Hashtable]`$parameter)
function $($MyInvocation.MyCommand.Name) {
$($myInvocation.MyCommand.Definition)
}
$($MyInvocation.MyCommand.Name) @parameter
")
                ArgumentList = $splat # and then runs with the arguments we provided.
            }
            Start-Job @JobSplat # Start the job 
            return # and return.
        }
        #region Recursive WGet

        # One of the ways you can use Get-Web is for scenarios like the linux utility wget.
        # In many cases, this is done through parameter aliasing, 
        # but the specific case of a recursive WGET is a little trickier.

        if ($psCmdlet.ParameterSetName -eq 'WGet') {
            return . $WGet
        } 

        #endregion Recursive WGet       
        if ($psCmdlet.ParameterSetName -eq 'URL') 
        {  
            #Region Prepare Web Request
            
            # First, we want to make a string copy of the URL. 
            $fullUrl = "$url"            
            
            # Then, we need to prepare the Request Body (which could have been provided any number of ways)
            
            # First up is the -Data parameter, 
            if ($Data -and -not $RequestBody) {
                # which is just a bunch of strings joined by an ampersand
                $RequestBody = $data -join '&'
                # ( it also implies the HTTP verb POST). 
                if (-not $psBoundParameters.Method) { $Method = 'POST' } 
            }


            # Next, we want to check to see if there's a signature and a corresponding key.
            if ($Signature -and $SignatureKey) {
                # The hasher can be any algorithmn the server wants (HMAC256 being the standard, and the default).
                $hasher = ("Security.Cryptography.$SignatureAlgorithmn" -as [Type])::new()
                # The key must be base-64 encoded string.
                $hasher.Key = [Convert]::FromBase64String($SignatureKey)                                 
                $AuthSignature = # The authorization signature is a base64 encoded     
                    [Convert]::ToBase64String(
                        $hasher.ComputeHash( # hash of 
                            [Text.Encoding]::UTF8.GetBytes( # the UTF8 value
                                $Signature))) # of the StringToSign (-Signature).
                if ($EncodeSignature) { # Some servers require the signature to be UrlEncoded,
                    $AuthSignature = [Web.HttpUtility]::UrlEncode($AuthSignature) # so do so if requested
                }

                # Now we need to set the header.
                if (-not $Header) { $header = @{} } # (so initialize the header collection if it hasn't been already).
   
                # The authorization header is a combination of any prefix and this signature
                $header.authorization = "$SignaturePrefix${AuthSignature}"
            }

            if ($Parameter -and ('PUT', 'POST' -notcontains $method)) {
                $fullUrl += "?"
                foreach ($param in $parameter.GetEnumerator()) {
                    $fullUrl += "$($param.key)=$([Web.HttpUtility]::UrlEncode($param.Value.ToString()))&"
                }
            }

            if (([uri]$Url).Scheme -eq 'HTTPS') {
                [Net.ServicePointManager]::Expect100Continue = $true
                [Net.ServicePointManager]::SecurityProtocol = 'TLS12'
            }

            $req = [Net.WebRequest]::Create("$fullUrl")                 
            $req.UserAgent = $UserAgent.Trim()                
            if ($HostHeader) {
                $req.host = $HostHeader
            }
            if ($PreAuthenticate) {
                $req.PreAuthenticate = $PreAuthenticate
            }
            $req.Method = $Method
            if ($psBoundParameters.ContentType) { 
                $req.ContentType = $ContentType
            }                                               
                
            if ($psBoundParameters.WebCredential) {
                $req.Credentials = $WebCredential.GetNetworkCredential()
            } elseif ($psBoundParameters.UseDefaultCredential) {
                $req.Credentials = [net.credentialcache]::DefaultNetworkCredentials
            }            

            if ($header) {
                foreach ($kv in $header.GetEnumerator()) {
                    if ($kv.Key -eq 'Accept') {
                        $req.Accept = $kv.Value
                    } elseif ($kv.Key -eq 'content-type') {
                        $req.ContentType = $kv.Value
                    } elseif ($kv.Key -eq 'user-agent') {
                        $req.UserAgent = $kv.Value
                    } else {
                        foreach ($v in $kv.Value) {
                            $null = $req.Headers.add("$($kv.Key)", "$($v)")
                        }
                    }                        
                }
            }

            if ($Accept) {
                $req.Accept = $Accept -join ','
            }

            if ($timeout) {
                $req.Timeout = $timeout.TotalMilliseconds                
            }


            if ($Thumbprint) {
                foreach ($tp in $Thumbprint) {
                    $findCert = Get-ChildItem cert: -Recurse | 
                        Where-Object  {$_.Thumbprint -eq "$tp" } |
                        Select-Object -Unique
                    if (-not $findCert) {
                        Write-Error "Certificate with thumbprint $tp was not found"
                        return
                    }
                    $null = $req.ClientCertificates.Add($findCert)
                }
            }
            
            $RequestTime  = [DateTime]::Now
            if (-not $HideProgress) {
                Write-Progress "$Method" $url -Id $progressId            
            }
            try {
                if ($Parameter -and ('PUT', 'POST' -contains $method)) {
                    if (-not $RequestBody) {
                        $RequestBody = ""
                    }                        
                    $RequestBody += 
                        (@(foreach ($param in $parameter.GetEnumerator()) {
                            "$($param.key)=$([Uri]::EscapeDataString($param.Value.ToString()))"
                        }) -join '&')
                    
                } else {
                    $paramStr = ""
                }
                if ($ContentType) { $req.ContentType  = $ContentType }
                
                if ($requestBody) {
                    if ($RequestBody -is [string]) {
                        if (-not $ContentType -and -not $Header.'content-type') {
                            $req.ContentType = 'application/x-www-form-urlencoded'
                        }
                            
                        $bytes = [Text.Encoding]::($RequestStringEncoding).GetBytes($RequestBody)                            
                        $postDataBytes = $bytes -as [Byte[]]
                        $req.ContentLength = $postDataBytes.Length                 
                        $requestStream = $req.GetRequestStream()                                                
                        $requestStream.Write($postDataBytes, 0, $postDataBytes.Count)                        
                        $requestStream.Close()                                    
                    } elseif ($RequestBody -as [byte[]]) {
                        if (-not $ContentType -and -not $Header.'content-type') {
                            $req.ContentType = 'application/x-www-form-urlencoded'
                        }
                        $postDataBytes = $RequestBody -as [Byte[]]
                        $req.ContentLength = $postDataBytes.Length                 
                            
                        $requestStream = $req.GetRequestStream()                                                
                        if ($req.ContentLength -gt $BufferSize) {
                            if (-not $HideProgress) {
                                Write-Progress "$METHOD" $url -Id $progressId 
                            }
                            $tLen = 0 
                            $chunkTotal = [Math]::Ceiling($postDataBytes.Length / $BufferSize)
                            for ($chunkCount = 0; $chunkCount -lt $chunkTotal; $chunkCount++) {
                                if ($chunkCount -ne ($chunkTotal -1 )) {

                                    $arr = $postDataBytes[($chunkCount * $BufferSize)..(([uint32]($chunkCount + 1) * $BufferSize) - 1) ]
                                    $tLen+=$arr.Length
                                } else {
                                    $arr = $postDataBytes[($chunkCount * $BufferSize)..($postDataBytes.Length - 1)]
                                    $tLen+=$arr.Length
                                }
                                $requestStream.Write($arr, 0 , $arr.Length)                        

                                if (-not $HideProgress) {
                                    $perc = $chunkCount * 100 / $chunkTotal
                                    Write-Progress "$METHOD [$tLen / $($postDataBytes.Length)]" $url -Id $progressId -PercentComplete $perc
                                }
                            }
                                
                            if (-not $HideProgress) {
                                Write-Progress "$METHOD [$tLen / $($arr.Length)]" $url -Id $progressId -Completed
                            }
                        } else {                                
                            $requestStream.Write($postDataBytes, 0, $postDataBytes.Count)                                                        
                        }
                        $requestStream.Close()                                    
                    }
                        
                } elseif ($paramStr) {
                    $postData = "$($paramStr -join '&')"
                    $postDataBytes = [Text.Encoding]::UTF8.GetBytes($postData)
                    $req.ContentLength = $postDataBytes.Length
                    $requestStream = $req.GetRequestStream()
                    $requestStream.Write($postDataBytes, 0, $postDataBytes.Count)                        
                    $requestStream.Close()
                } elseif ($method -ne 'GET' -and $method -ne 'HEAD') {
                    $req.ContentLength = 0
                } 
            } catch {
                if (-not ($_.Exception.HResult -eq -2146233087)) {
                    $_ | Write-Error
                    return    
                } 
            }

            if ($VerbosePreference -ne 'silentlycontinue') {
                Write-Verbose "[$([DateTime]::Now.ToString('o'))]${Method}:$fullUrl"
            }
            #endregion Prepare Web Request

            #region Make Web Request
            if ($Async) {                
                # Return the request, and begin to get a response.        
                return [PSCustomObject]@{
                    WebRequest = $req 
                    IAsyncResult = $req.BeginGetResponse($null, $req)
                }
            }

            $WebRequest = $req
        }

        $webResponse = $null # Initialize web response to null
        if ($WebRequest) 
        {
            $webResponse = 
                try {
                    if ($IASyncResult) {
                        $RequestTime = [DateTime]::Now
                        $WebRequest.EndGetResponse($IASyncResult)   
                    } else {
                        $WebRequest.GetResponse()
                    }                    
                } catch {
                    $ex = $_
                    if ($ex.Exception.InnerException.Response) {                            
                        $streamIn = [IO.StreamReader]::new($ex.Exception.InnerException.Response.GetResponseStream())
                        $strResponse = $streamIn.ReadToEnd()                            
                        $streamIn.Close()
                        $streamIn.Dispose()       
                        if (-not $UseErrorAsResult) {
                            Write-Error $strResponse 
                            return
                        }
                        $html = $strResponse                            
                    } else {
                        $ex | Write-Error
                        return
                    }                        
                }
            #endregion Make Web Request            
            $ResponseTime = [Datetime]::Now - $RequestTime            
        }

        if ($webResponse) # If we have a web response  
        {                                 
            $rs = $webresponse.GetResponseStream()
            $responseHeaders = $webresponse.Headers
            $responseHeaders  = if ($responseHeaders -and $responseHeaders.GetEnumerator()) {
                $reHead = @{}
                foreach ($r in $responseHeaders.GetEnumerator()) {
                    $reHead[$r] = $responseHeaders[$r]
                }
                $reHead
            } else {
                $null
            }
            $unexpectedResponseType = $false
                
            if ($psBoundParameters.ContentType -and 
                $webresponse.ContentType -and 
                $webResponse.ContentType -ne $ContentType -and 
                $Accept -notcontains $ContentType) {
                    
                if ($webresponse.ContentType -notlike "text/*" -and 
                    $webresponse.ContentType -notlike "*xml*" -and 
                    -not $Accept) {                    
                    $pageRoot = "$($WebResponse.ResponseUri)"
                    $relativeRoot = $pageRoot.Substring($pageRoot.LastIndexOf("/") + 1)

                    $unexpectedResponseType  = $true
                    $AsByte = $true
                }                    
            }

            if ($AsByte) {
                $OutputStream = [IO.MemoryStream]::new()
            }

            if ($OutputPath) {
                $fullOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
                $fullOutputDir = $fullOutputPath | Split-Path
                if (-not ([IO.Directory]::Exists("$fullOutputDir"))) {
                    $null = New-Item -ItemType directory -Path $fullOutputDir
                }
                
                $OutputStream = [IO.File]::Open($fullOutputPath, 'OpenOrCreate', 'Write')
                if (-not $OutputStream) { return } 
            }            

            
            if ($OutputStream) {                    
                
                $byteBuffer = [byte[]]::new($BufferSize)
                [int]$ToRead = $webresponse.ContentLength
                [int]$TotalRead = 0
                [Int]$bytesRead = 0
                do {
                    try {
                        $byteBuffer.Clear()
                        $amountToRead = $BufferSize                                                                    
                        $bytesRead = $rs.Read($byteBuffer, 0, $amountToRead)                            
                        if ($bytesRead -gt 0) {
                            $OutputStream.Write($byteBuffer, 0, $bytesRead)
                        }
                    } catch {
                        $global:LastStreamReadError = $_
                        break
                    }
                    $TotalRead += $bytesRead
                    if (($webResponse.ContentLength -gt $byteBuffer.Length) -and -not $hideProgress) {
                        $perc = ($totalRead / $webResponse.ContentLength) * 100
                        Write-Progress "Downloading" $url -Id $progressId -PercentComplete $perc
                    }
                } while ($bytesRead -gt 0 -and 
                    (($bytesRead -lt $webResponse.ContentLength) -or ($webResponse.ContentLength -lt 0))
                )
                    
                    
                if (-not $HideProgress) {
                    Write-Progress "Download Completed" $url -Id $progressId -Complete
                }

                if ($AsByte -and $OutputStream -is [IO.MemoryStream]) {
                    $outBytes = $OutputStream.ToArray()
                }

                $OutputStream.Close()
                $OutputStream.Dispose()

                if ($AsByte) {
                    if ($unexpectedResponseType) {       
                        if ($OutputResponseHeader) {
                            return @{$relativeRoot= $outBytes;Headers=$responseHeaders}
                        } else {
                            return @{$relativeRoot= $outBytes}
                        }                 
                    } else {
                        if ($OutputResponseHeader) {
                            Add-Member -InputObject $outBytes -MemberType NoteProperty Headers $responseHeaders -PassThru
                            return
                        } else {
                            return $outBytes
                        }
                    }
                }
            } else {
                $streamIn = New-Object IO.StreamReader $rs
                $strResponse = $streamIn.ReadToEnd()
                $html = $strResponse 
                $streamIn.Close()
            }
                
            $rs.close()
            $rs.Dispose()

            

            if ($unexpectedResponseType -and $Html) {
                return @{$relativeRoot= $Html}
            }
        }
        
        if ($psCmdlet.ParameterSetName -eq 'FileName')
        {
            if ($AsByte) {
                [IO.File]::ReadAllBytes($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($FileName))
                return 
            }             
            $html = [IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($FileName))            
        }
        
        if (-not $html) { 
            if ('HEAD', 'OPTIONS' -contains $Method) {
                return (New-Object PSObject -Property $responseHeaders)
            } else {
                return 
            }            
        } 

        if ($AsXml) {
            $xHtml = [xml]$html
            if ($OutputResponseHeader) {
                $xHtml | 
                    Add-Member NoteProperty Headers $responseHeaders -Force -PassThru
            } else {
                $xHtml
            }
            return 
        }
        
        if ($AsJson -and $PSVersionTable.PSVersion -ge '3.0') {
            $jsResult= ConvertFrom-Json -InputObject $Html
            if ($OutputResponseHeader) {
                $jsResult | 
                    Add-Member NoteProperty Headers $responseHeaders -Force -PassThru
            } else {
                $jsResult
            }
            return
        }

        if (-not $Tag -or $AsMicrodata) {
            if ($AsByte) { 
                return [Text.Encoding]::Unicode.GetBytes($html)
            }
        }
               
        foreach ($r in $replacements.GetEnumerator()) {
            $l = 0 
            do {
                $l = $html.IndexOf($r.Key, $l, [StringComparison]"CurrentCultureIgnoreCase")
                if ($l -ne -1) {
                    $html = $html.Remove($l, $r.Key.Length)
                    $html = $html.Insert($l, $r.Value)
                }
            } while ($l -ne -1)         
        }

        #$html = $html -replace '&(?!([\w\d]{1,};))', '&amp;'
        
        if ($tag -and -not ($AsMicrodata -or $OpenGraph -or $MetaData -or $ItemType)) {
            $tryToBalance = $true
            
            if ($openGraph -or $metaData) {
                $tryToBalance  = $false
            }
 
            foreach ($htmlTag in $tag) {
                if (-not $htmlTag) { continue } 
                $r = New-Object Text.RegularExpressions.Regex ('</' + $htmlTag + '>'), ("Singleline", "IgnoreCase")
                $endTags = @($r.Matches($html))
                if ($textInTag) {
                    
                    $r = New-Object Text.RegularExpressions.Regex ('<' + $htmlTag + '[^>]*' + ($textInTag -join '[^>]*') + '[^>]*>'), ("Singleline", "IgnoreCase")
                } else {
                    $r = New-Object Text.RegularExpressions.Regex ('<' + $htmlTag + '[^>]*>'), ("Singleline", "IgnoreCase")
                }
                
                $startTags = @($r.Matches($html))
                $tagText = New-Object Collections.ArrayList
                $tagStarts = New-Object Collections.ArrayList
                if ($tryToBalance -and ($startTags.Count -eq $endTags.Count)) {
                    $allTags = $startTags + $endTags | Sort-Object Index   
                    $startTags = New-Object Collections.Stack
                    
                    foreach($t in $allTags) {
                        if (-not $t) { continue } 
                        
                        if ($t.Value -like "<$htmlTag*") {
                            $startTags.Push($t)
                        } else {
                            $start = try { $startTags.Pop() } catch {}
                            $null = $tagStarts.Add($start.Index)
                            $null  = $tagText.Add($html.Substring($start.Index, $t.Index + $t.Length - $start.Index))
                        }
                    }
                } else {
                    # Unbalanced document, use start tags only and make sure that the tag is self-enclosed
                    foreach ($_ in $startTags) {
                        if (-not $_) { continue } 
                        $t = "$($_.Value)"
                        if ($t -notlike "*/>") {
                            $t = $t.Insert($t.Length - 1, "/")
                        }
                        $null = $tagStarts.Add($t.Index)
                        $null  = $tagText.Add($t)    
                
                    } 
                }
            
                $tagCount = 0 
                foreach ($t in $tagText) {
                    if (-not $t) {continue }
                    $tagStartIndex = $tagStarts[$tagCount]
                    $tagCount++
                    # Correct HTML which doesn't quote the attributes so it can be coerced into XML
                    $inTag = $false
                    $tagName = [Regex]::Match("$t", "<(\S[^ >]{1,})").Groups[1].Value

                    for ($i = 0; $i -lt $t.Length; $i++) {
                        
                        if ($t[$i] -eq "<") {
                            $inTag = $true
                        } else {
                            if ($t[$i] -eq ">") {
                                $inTag = $false
                            }
                        }
                        if ($inTag -and ($t[$i] -eq "=")) {
                            if ($quotes -notcontains $t[$i + 1]) {
                                $endQuoteSpot = $t.IndexOfAny(" >", $i + 1)
                                # Find the end of the attribute, then quote
                                $t = $t.Insert($i + 1, "'")
                                if ($endQuoteSpot -ne -1) {
                                    if ($t[$endQuoteSpot] -eq ' ') {
                                        $t = $t.Insert($endQuoteSpot + 2, "'")                    
                                    } else {
                                        $t = $t.Insert($endQuoteSpot + 1, "'")                    
                                    }
                                } 
                                
                                $i = $endQuoteSpot
                                if ($i -eq -1) {
                                    break
                                }
                            } else {
                                # Make sure the quotes are correctly formatted, otherwise,
                                # end the quotes manually
                                $whichQuote = $t[$i + 1]
                                $endQuoteSpot = $t.IndexOf($whichQuote, $i + 2)
                                $i = $endQuoteSpot
                                if ($i -eq -1) {
                                    break
                                } 
                            }
                        }
                    } 
                
                    $startTag = $t.Substring(0, $t.IndexOf(">") + 1)
                    if ($tagName -eq 'script') {
                        $null = $null                
                    }
                    if (($tagName -eq 'script') -and 
                        ($t -ne $startTag) -and 
                        -not ("$t".ToUpper().Contains("<![CDATA["))) {
                        $endTagIndex =  $t.LastIndexOf("</")
                        if ($endTagIndex -gt 0) {
                            $innerScript = $t.Substring($startTag.Length, $t.LastIndexOf("</") - $startTag.Length )
                            $t = "${startTag}/*<![CDATA[*/$InnerScript/*]]>*/</$TagName>"
                        }                        
                    }
                   
                   
                    if ($pscmdlet.ParameterSetName -eq 'Url') {
                        if ($OutputResponseHeader) {
                            New-Object PsObject -Property @{
                                Tag= $t
                                StartTag = $startTag
                                StartsAt = $tagStartIndex
                                Xml = ($t -replace '&(?!([\w\d]{1,};))', '&amp;' -as [xml]).$htmlTag      
                                Source = $url
                                Headers = $responseHeaders
                            }
                        } else {
                            New-Object PsObject -Property @{
                                Tag= $t
                                StartTag = $startTag
                                StartsAt = $tagStartIndex
                                Xml = ($t -replace '&(?!([\w\d]{1,};))', '&amp;' -as [xml]).$htmlTag      
                                Source = $url                                
                            }
                        }
                        
                    } else {
                        if ($OutputResponseHeader) {
                            New-Object PsObject -Property @{
                                Tag= $t
                                StartTag = $startTag
                                StartsAt = $tagStartIndex
                                Xml = ($t -as [xml]).$htmlTag      
                                Headers = $responseHeaders
                            }
                        } else {
                            New-Object PsObject -Property @{
                                Tag= $t
                                StartTag = $startTag
                                StartsAt = $tagStartIndex
                                Xml = ($t -as [xml]).$htmlTag      
                            }
                        }
                         
                    }
                                 
                }
            }
        } elseif ($OpenGraph) {
            $metaTags = Get-Web -Html $html -Tag 'meta' 
            $outputObject = New-Object PSObject
            foreach ($mt in $metaTags) {
                if ($mt.Xml.Property -like "og:*") {
                    $propName = $mt.Xml.Property.Substring(3)
                    $noteProperty = New-Object Management.Automation.PSNoteProperty $propName, $mt.Xml.Content
                    if ($outputObject.psobject.properties[$propName]) {
                        $outputObject.psobject.properties[$propName].Value = 
                            @($outputObject.psobject.properties[$propName].Value) + $noteProperty.Value | Select-Object -Unique
                    } else {
                        try {
                            $null = Add-Member -InputObject $outputObject NoteProperty $noteProperty.name $noteProperty.Value -Force
                        } catch {
                            
                            Write-Error $_
                        }
                    }
                }
                
            }
            $null = $OutputObject.pstypenames.add('OpenGraph')
            if ($OutputResponseHeader) {
                $outputObject | Add-Member NoteProperty Headers $responseHeaders -Force -PassThru
            } else {
                $outputObject
            }
            
        } elseif ($MetaData) {
            $titleTag= Get-Web -Html $html -Tag 'title'
            $titleText = $titleTag.xml.Trim()
            $metaTags = Get-Web -Html $html -Tag 'meta' 
            $outputObject = New-Object PSObject
            Add-Member NoteProperty Title $titleText -InputObject $outputObject
            foreach ($mt in $metaTags) {
                $propName = if ($mt.Xml.Property) {
                    $mt.Xml.Property
                } elseif ($mt.Xml.name -and $mt.Xml.Name -ne 'meta') {
                    $mt.Xml.name
                }
                
                if (-not $PropName) { continue } 
                $noteProperty = New-Object Management.Automation.PSNoteProperty $propName, $mt.Xml.Content
                if ($outputObject.psobject.properties[$propName]) {
                    $outputObject.psobject.properties[$propName].Value = 
                        @($outputObject.psobject.properties[$propName].Value) + $noteProperty.Value | Select-Object -Unique
                } else {
                    try {
                        $null = Add-Member -InputObject $outputObject NoteProperty $noteProperty.name $noteProperty.Value -Force
                    } catch {
                        
                        Write-Error $_
                    }
                }
            }               
            $null = $OutputObject.pstypenames.add('HTMLMetaData')
            if ($psBoundParameters.Url -and -not $outputObject.psobject.properties['Url']) {
                Add-Member -InputObject $outputObject NoteProperty Url $psboundParameters.Url
            }
            if ($OutputResponseHeader) {
                $outputObject | Add-Member NoteProperty Headers $responseHeaders -Force -PassThru
            } else {
                $outputObject
            }
        } 
        elseif ($AsMicrodata -or $ItemType) 
        {
            $getInnerScope = {
                if (-not $knownTags[$htmlTag]) {
                    $r = New-Object Text.RegularExpressions.Regex ('<[/]*' + $htmlTag + '[^>]*>'), ("Singleline", "IgnoreCase")                    
                    $Tags = @($r.Matches($html))
                    $knownTags[$htmlTag] = $tags
                }
                
                $i = 0
                $myTagIndex = foreach ($_ in $knownTags[$htmlTag]) {
                    if ($_.Value -eq $targetValue -and $_.Index -eq $targetIndex) { 
                        $i
                    }
                    $i++
                }
                
                # Once the tag index is known, we start there and wait until the tags are balanced again
                $balance = 1
                for ($i = $myTagIndex + 1; $i -lt $knownTags[$htmlTag].Count; $i++) {
                    if ($knownTags[$htmlTag][$i].Value -like "<$htmlTag*"){
                        $balance++
                    } else {
                        $balance--
                    }
                    if ($balance -eq 0) {                                               
                        break
                    }                                        
                }
                
                if ($balance -eq 0 -and ($i -ne $knownTags[$htmlTag].Count)) {
                    $start = $knownTags[$htmlTag][$MyTagIndex].Index
                    $end = $knownTags[$htmlTag][$i].Index + $knownTags[$htmlTag][$i].Length
                    $innerScope = $html.Substring($start, $end-$start)            
                } else {
                    $innerScope = ""
                }
                
                $myTagAsXml = $knownTags[$htmlTag][$MyTagIndex].Value
                if ($myTagASXml -notlike "*itemscope=*") {
                    $myTagASXml  = $myTagASXml -ireplace 'itemscope', 'itemscope=""'
                }  
                try {
                    $myTagAsXml = [xml]($myTagAsXml.TrimEnd("/>") + "/>")
                } catch {
                    
                }


            }
            
            
            #region Microdata Extractor     
            $itemScopeFinder = New-Object Text.RegularExpressions.Regex ('<(?<t>\w*)[^>]*itemscope[^>]*>'), ("Singleline", "IgnoreCase")
            $knownTags = @{}
            foreach ($matchInfo in $itemScopeFinder.Matches($html)) {
                if (-not $matchInfo)  { continue }                                
                $htmlTag = $matchInfo.Groups[1].Value        
                $targetValue = $matchInfo.Groups[0].Value        
                $targetIndex = $matchInfo.Groups[0].Index
                
                . $getInnerScope                                 

                
                $itemPropFinder = New-Object Text.RegularExpressions.Regex ('<(?<t>\w*)[^>]*itemprop[^>]*>'), ("Singleline", "IgnoreCase")
                $outputObject = New-Object PSObject 
                $outputObject.pstypenames.clear()
                foreach ($itemTypeName in $myTagAsXml.firstchild.itemtype -split " ") {                                    
                    if (-not $itemTypeName) { continue }                    
                    $null = $outputObject.pstypenames.add($itemTypeName)                    
                }
                
                # If we've asked for a specific item type, and this isn't it, continue
                if ($ItemType) {
                    $found = foreach ($tn in $outputObject.pstypenames) {
                        if ($ItemType -contains $tn) {
                            $true
                        }                        
                    }
                    if (-not $found) {                                         
                        continue
                    }
                }
                
                
                
                if ($myTagAsXml.firstChild.itemId) {
                    $itemID = New-Object Management.Automation.PSNoteProperty "ItemId", $myTagAsXml.firstChild.itemId
                    $null = $outputObject.psobject.properties.add($itemID)
                }
                
                $avoidRange = New-Object Collections.ArrayList
                
                foreach ($itemPropMatch in $itemPropFinder.Matches($innerScope)) {
                    $propName = ""
                    $propValue = ""
                    $htmlTag = $itemPropMatch.Groups[1].Value        
                    $targetValue = $itemPropMatch.Groups[0].Value   
                    if ($itemPropMatch.Groups[0].Value -eq $matchInfo.Groups[0].Value) {
                        # skip relf references so we don't infinitely recurse
                        continue
                    }
                    $targetIndex = $matchInfo.Groups[0].Index + $itemPropMatch.Groups[0].Index                                                                 
                    if ($avoidRange -contains $itemPropMatch.Groups[0].Index) {
                        continue
                    }
                    . $getInnerScope 
                    $propName = $myTagAsXml.firstchild.itemprop
                    if (-not $propName) { 
                        Write-Debug "No Property Name, Skipping"
                        continue
                    }

                    if (-not $innerScope) {                 
                        
                        # get the data from one of a few properties.  href, src, or content
                        $fixedXml = try { [xml]($itemPropMatch.Groups[0].Value.TrimEnd("/>") + "/>") } catch { }
                        $propName = $fixedxml.firstchild.itemprop
                        $propValue = if ($fixedXml.firstchild.href) {
                            $fixedXml.firstchild.href
                        } elseif ($fixedXml.firstchild.src) {
                            $fixedXml.firstchild.src
                        } elseif ($fixedXml.firstchild.content) {
                            $fixedXml.firstchild.content
                        } elseif ('p', 'span', 'h1','h2','h3','h4','h5','h6' -contains $htmlTag) {
                            $innerTextWithoutspaces = ([xml]$innerScope).innertext -replace "\s{1,}", " "
                            $innerTextWithoutSpaces.TrimStart()                                    
                        }
                        if ($propName) { 
                            try {
                            $noteProperty = New-Object Management.Automation.PSNoteProperty $propName, $propValue
                            } catch {
                                Write-Debug "Could not create note property"
                            }
                        }
                        
                    } else {
                        if ($innerScope -notlike '*itemscope*') {                            
                            $innerScopeXml = try { [xml]$innerScope } catch { } 
                            
                            if ($innerScopeXml.firstChild.InnerXml -like "*<*>") {
                                $propValue = if ($myTagAsXml.firstchild.href) {
                                     $myTagAsXml.firstchild.href
                                } elseif ($myTagAsXml.firstchild.src) {
                                    $myTagAsXml.firstchild.src
                                } elseif ($myTagAsXml.firstchild.content) {
                                    $myTagAsXml.firstchild.content
                                } elseif ('p', 'span', 'h1','h2','h3','h4','h5','h6' -contains $htmlTag) {
                                    $innerTextWithoutspaces = ([xml]$innerScope).innertext -replace "\s{1,}", " "
                                    $innerTextWithoutSpaces.TrimStart()                                    
                                } else {
                                    $innerScope
                                }
                                try {
                                    $noteProperty = New-Object Management.Automation.PSNoteProperty $propName, $propValue
                                } catch {
                                    Write-Debug "Could not create note property"
                                }
                            } else {
                                $innerText = $innerScope.Substring($itemPropMatch.Groups[0].Value.Length)
                                $innerText = $innerText.Substring(0, $innerText.Length - "</$htmlTag>".Length)
                                $innerTextWithoutspaces = $innertext -replace "\s{1,}", " "
                                $innerTextWithoutSpaces = $innerTextWithoutSpaces.TrimStart()
                                try {
                                    $noteProperty = New-Object Management.Automation.PSNoteProperty $propName, $innerTextWithoutSpaces
                                } catch {
                                    Write-Debug "Could not create note property"
                                }
                            }
                            
                        } else {
                            # Keep track of where this item was seen, so everything else can skip nested data
                            $avoidRange.AddRange($itemPropMatch.Groups[0].Index..($itemPropMatch.Groups[0].Index + $innerScope.Length))
                            
                            $propValue = Get-Web -Html $innerScope  -Microdata
                            $noteProperty = New-Object Management.Automation.PSNoteProperty $propName, $propValue
                        }                                                
                    }
                    if ($outputObject.psobject.properties[$propName]) {
                        if ($noteProperty.Value -is [string]) {
                            $outputObject.psobject.properties[$propName].Value = 
                                @($outputObject.psobject.properties[$propName].Value) + $noteProperty.Value | Select-Object -Unique
                        } else {
                            $outputObject.psobject.properties[$propName].Value = 
                                @($outputObject.psobject.properties[$propName].Value) + $noteProperty.Value 
                        }
                    } else {
                        try {
                            $null = Add-Member -InputObject $outputObject NoteProperty $noteProperty.name $noteProperty.Value -Force
                        } catch {
                            
                            Write-Error $_
                        }
                    }
                    
                    
                    #$propName, $propValue                                                           
                }
                    
                if ($psBoundParameters.Url -and -not $outputObject.psobject.properties['Url']) {
                    Add-Member -InputObject $outputObject NoteProperty Url $psboundParameters.Url
                }

                if ($OutputResponseHeader) {
                    $outputObject | Add-Member NoteProperty Headers $responseHeaders -Force -PassThru
                } else {
                    $outputObject
                }             
            }
            #endregion Microdata Extractor 
            # In this case, construct a regular expression that finds all itemscopes
            # Then create another regular expression to find all itemprops
            # Walk thru the combined list
        } 
        elseif ($DataAttribute) 
        {
            $HTML_DataSet = [Regex]::new(@'
<
(?<Tag>[\w-]*)
\s{0,}
(?<Attributes>
    [^>]*
    \s{0,}
    data-
    \s{0,}
    [^>]*
)
>
'@, 'IgnoreCase,IgnorePatternWhitespace', '00:00:05')

$HTML_DataAttribute = [Regex]::new(@'
\s{0,}
data-(?<Key>[a-z\-_:]*)
\s{0,}

=
\s{0,}

(?>
    '(?<Value>
        ((?:''|\\'|[^'])*)
    )'
    |
    "(?<Value>
    .*?(?<!(\\))
    )"
)
'@, 'IgnoreCase,IgnorePatternWhitespace', '00:00:05')



            foreach ($dataSetMatch in $HTML_DataSet.Matches($Html)) {
                $dataObject = [Ordered]@{}
                $HTMLID = $HTML_IDAttribute.Match($dataSetMatch)
                if ($htmlID.Success) {
                    $DataObject['id'] = $HTMLID.Groups['ID'].Value
                }
                $dataObject['tag'] = $dataSetMatch.ToString()
                foreach ($dataAttributeMatch in $HTML_DataAttribute.Matches($dataSetMatch.Value)) {
                    $Key = $dataAttributeMatch.Groups['Key'].Value
                    $key = [Regex]::Replace($key,'\-([a-z])', {$args[0].Groups[1].Value.ToUpper()})
                    $dataObject[$key] = $dataAttributeMatch.Groups['Value'].Value
                }
                $dataObject
            }
        }
        else 
        {
            if ($OutputResponseHeader) {
                $Html | 
                    Add-Member NoteProperty Headers $responseHeaders -Force -PassThru |
                    Add-Member NoteProperty ResponseTime $responseTime -PassThru |
                    Add-Member NoteProperty RequestTime $requestTime -PassThru
            } else {
                $Html | 
                    Add-Member NoteProperty ResponseTime $responseTime -PassThru |
                    Add-Member NoteProperty RequestTime $requestTime -PassThru
            }
            
        }        
    }
}