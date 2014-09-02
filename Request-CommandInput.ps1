function Request-CommandInput
{
    <#
    .Synopsis
        Generates a form to collect input for a command
    .Description
        Generates a form to collect input for a PowerShell command.  
                
        
        Get-WebInput is designed to handle the information submitted by the user in a form created with Request-CommandInput.
    .Link
        Get-WebInput
    .Example
        Request-CommandInput -CommandMetaData (Get-Command Get-Command) -DenyParameter ArgumentList
    #>
    [CmdletBinding(DefaultParameterSetName='ScriptBlock')]
    [OutputType([string])]
    param(
    # The metadata of the command.
    [Parameter(Mandatory=$true,ParameterSetName='Command',ValueFromPipeline=$true)]
    [Management.Automation.CommandMetaData]
    $CommandMetaData,
    
    # A script block containing a PowerShell function.  Any code outside of the Powershell function will be ignored.
    [Parameter(Mandatory=$true,ParameterSetName='ScriptBlock')]
    [ScriptBlock]
    $ScriptBlock,
    
    # The name of the parameter set to request input
    [string]
    $ParameterSet,    
    
    # Explicitly allowed parameters (by default, all are allowed unless they are explictly denied)
    [string[]]
    $AllowedParameter,
    
    # Explicitly denied parameters.
    [Alias('HideParameter')]
    [string[]]
    $DenyParameter,
    
    # The text on the request button
    [string]
    $ButtonText,

    # The url to a button image button
    [string]
    $ButtonImage,

    # If set, does not display a button 
    [switch]
    $NoButton,
    
    # The order of items
    [string[]]
    $Order,
        
    # The web method the form will use
    [ValidateSet('POST','GET')]
    [string]
    $Method = "POST",

    # The css margin property to use for the form
    [string]
    $Margin = "1%",
    
    # The action of the form
    [string]
    $Action,
        
    # The platform the created input form will work.  
    # This is used to created an XML based layout for any device
    [ValidateSet('Web', 'Android', 'AndroidBackend', 'CSharpBackEnd', 'iOS', 'WindowsMobile', 'WindowsMetro', 'Win8', 'WPF', 'GoogleGadget', 'TwilML', 'PipeworksDirective')]
    [string]
    $Platform = 'Web',

    # If set, uses a Two column layout
    [Switch]
    $TwoColumn,

    # If provided, focuses a given parameter's input
    [string]
    $Focus,

    # If provided, uses the supplied values as parameter defaults
    [Alias('ParameterDefaultValues')]
    [Hashtable]
    $ParameterDefaultValue = @{},

    # If provided, uses the supplied values as potential options for a parameter 
    [Alias('ParameterOptions')]
    [Hashtable]
    $ParameterOption = @{},

    # If set, will load the inner control with ajax
    [Switch]
    $Ajax
    )
    
    begin {       
        $allPipeworksDirectives = @{}
        $firstcomboBox = $null          
        Add-Type -AssemblyName System.Web 
        function ConvertFrom-CamelCase
        {
            param([string]$text)
            
            $r = New-Object Text.RegularExpressions.Regex "[a-z][A-Z]", "Multiline"
            $matches = @($r.Matches($text))
            $offset = 0
            foreach ($m in $matches) {
                $text = $text.Insert($m.Index + $offset + 1," ")
                $offset++
            }
            $text
        }

       
             
        
        
        function New-TextInput($defaultNumberOfLines, [switch]$IsNumber, [string]$CssClass,[string]$type) {
            $linesForInput = if ($pipeworksDirectives.LinesForInput -as [Uint32]) {
                $pipeworksDirectives.LinesForInput -as [Uint32]
            } else {
                $defaultNumberOfLines
            }
            
            $columnsForInput = 
                if ($pipeworksDirectives.ColumnsForInput -as [Uint32]) {
                    $pipeworksDirectives.ColumnsForInput -as [Uint32]
                } else {
                    if ($Request -and $Request['Snug']) {
                        30
                    } else {
                        60
                    }
                    
                }
            
            
            if ($Platform -eq 'Web') {
                if ($pipeworksDirectives.ContentEditable) {
                    "<div id='${ParameterIdentifier}_Editable' style='width:90%;padding:10px;margin:3px;min-height:5%;border:1px solid' contenteditable='true' designMode='on'>$(if ($pipeworksDirectives.Default) { "<i>" + $pipeworksDirectives.Default + "</i>" })</div>
                    
                    
                    <input type='button' id='${inputFieldName}saveButton' value='Save' onclick='save${inputFieldName};' />
                    <input type='button' id='${inputFieldName}clearButton' value='Clear' onclick='clear${inputFieldName};' />
                    <input type='hidden' id='$parameterIdentifier' name='$inputFieldName' />
                    <script>                        
                        `$(function() {
                            `$( `"#$($inputFieldName)saveButton`" ).button().click(
                                function(event) { 
                                    document.getElementById(`"${ParameterIdentifier}`").value = document.getElementById(`"${ParameterIdentifier}_Editable`").innerHTML;        
                                });
                                
                            `$( `"#$($inputFieldName)clearButton`" ).button().click(
                                function(event) {
                                    document.getElementById(`"${ParameterIdentifier}`").value = '';
                                    document.getElementById(`"${ParameterIdentifier}_Editable`").innerHTML = '';
                                });                        
                        })
                    </script>
                    "

                } else {

                    if ($LinesForInput -ne 1) {
                        "<textarea style='width:100%;' $(if ($cssClass) { "class='$cssClass'"}) $(if($type) { "type='$type'" }) name='$inputFieldName' rows='$LinesForInput' cols='$ColumnsForInput'>$($pipeworksDirectives.Default -join ([Environment]::NewLine))</textarea>"
                    } else {
                        "<input type='text' style='width:100%' $(if ($cssClass) { "class='$cssClass'"}) $(if($type) { "type='$type'" }) name='$inputFieldName' $(if ($isnumber) {'type=''number'''}) $(if ([Double], [float] -contains $parameterType) {'step=''0.01'''}) value='$($pipeworksDirectives.Default)' />"
                    }
                
                    if ($cssClass -eq 'dateTimeField') {
                        "<script>
                        `$(function() {
                            `$( `".dateTimeField`" ).datepicker({
                			    showButtonPanel : true,
                                changeMonth: true,
                                changeYear: true,
                                showOtherMonths: true,
                                selectOtherMonths: true
                		    });
                        })
                        </script>"
                    }
                }
            } elseif ($Platform -eq 'Android') {
                @"
<EditText
    android:id="@+id/$parameterIdentifier"
    $theDefaultAttributesInAndroidLayout    
    android:minLines='${LinesForInput}'
    $(if ($isnumber) {'type=''number'''})
    $(if ($defaultValue) { "android:text='$defaultValue'" } )/>
                
"@                            
            } elseif ($Platform -eq 'AndroidBackEnd') {                
                $extractTextFromEditTextAndUseForQueryString 
            } elseif ($Platform -eq 'CSharpBackEnd') {
                $extractTextFromTextBoxAndUseForQueryString
            } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                if ($DefaultNumberOfLines -eq 1) { 
                        @"
<TextBox
    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
    Margin="7, 5, 7, 5"
    x:Name="$parameterIdentifier"    
    $(if ($defaultValue) { "Text='$defaultValue'" })    
    Tag='Type:$($parameterType.Fullname)' />
"@        
                } else {
                        @"
<TextBox
    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
    Margin="7, 5, 7, 5"
    x:Name="$parameterIdentifier"    
    $(if ($defaultValue) { "Text='$defaultValue'" })    
    Tag='Type:$($parameterType.Fullname)'
    AcceptsReturn='true'    
    MinLines='${DefaultNumberOfLines}' />
"@        
                     
                } 
            } elseif ('GoogleGadget' -eq $platform) {
@"
<UserPref name="$parameterIdentifier" display_name="$friendlyParameterName" default_value="$($pipeworksDirectives.Default)"/>            
"@
            } elseif ('TwilML' -eq $Platform) {
                if ($IsNumber) {
@"
<Gather finishOnKey="*" $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" })>
    <Say>$([Security.SecurityElement]::Escape($parameterHelp)).  Press * when you are done.</Say>
</Gather>
"@
                } elseif ($friendlyParameterName -like "Record*" -or $friendlyParameterName -like "*Recording") {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" })>
    
</Record>
"@            

                } elseif ($friendlyParameterName -like "Transcribe*" -or $friendlyParameterName -like "*Transcription") {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) transcribe='true' />
"@                        
                
                } elseif ($pipeworksDirectives.RecordInput -or $pipeworksDirectives.Record -or $pipeworksDirectives.Recording) {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) />
"@            

                } else {
@"
<Say>$([Security.SecurityElement]::Escape($parameterHelp))</Say>
<Record $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) transcribe='true' />
"@            
                
                }
            }
        } 

        # Some chunks of code are reused so often, they need to be variables
        $extractTextFromEditTextAndUseForQueryString = @"
    try {     
        // Cast the item to an EditText control
        EditText text = (EditText)foundView;
        		
        // Extract out the value
		String textValue = text.getText().toString();
        
        // If it is set...
		if (textValue != null && textValue.getLength() > 0) {
            // Append the & to separate parameters
    		if (! initializedQueryString) {
    			initializedQueryString = true;        			
    		} else {
    			queryString.append("&");
    		}
                		    		
    		queryString.append(textFieldID);
            queryString.append("=");
    		queryString.append(URLEncoder.encode(textValue));        			
		}   
    } catch (Exception e) {
        e.printStackTrace();
    }

"@   

        $extractTextFromTextBoxAndUseForQueryString = @"
    try {
        // Cast the item to an TextBox control
        TextBox text = (TextBox)foundView;
        		
        // Extract out the value
		String textValue = text.Text;
        
        // If it is set...
		if (! String.IsNullOrEmpty(textValue)) {
            // Append the & to separate parameters
    		if (! initializedQueryString) {
    			initializedQueryString = true;        			
    		} else {
    			queryString.Append("&");
    		}
                		    		
    		queryString.Append(textFieldID);
            queryString.Append("=");
    		queryString.Append(HttpUtility.UrlEncode(textValue));        			
		}   
    } catch (Exception ex) {
        throw ex;
    }

"@        

        # Most android UI requires these two lines
        $theDefaultAttributesInAndroidLayout = @"
            android:layout_width="match_parent"
            android:layout_height="wrap_content"
"@        
    }
    
    process { 
        $carrySnug = if ($Action -and $request -and $request["Snug"] -and $Platform -eq 'Web') {
            $true
            
        } else {
            $false
        }
        # The ScriptBlock parameter set will just take the first command declared within a scriptblock
        if ($psCmdlet.ParameterSetName -eq 'ScriptBlock') {
            $func = Get-FunctionFromScript -ScriptBlock $ScriptBlock | Select-Object -First 1 
            . ([ScriptBlock]::Create($func))
            $matched = $func -match "function ((\w+-\w+)|(\w+))"
            if ($matched -and $matches[1]) {
                $command=Get-Command $matches[1]
            }
            $CommandMetaData = [Management.Automation.CommandMetaData]$command                        
        }
               
        $inputForm =  New-Object Text.StringBuilder 
        $idSafeCommandName = $commandMetaData.Name.Replace('-','')
        
        # Extract out help
        if (-not $script:CachedHelp) {
            $script:CachedHelp = @{}
        }

        if (-not $script:CachedHelp[$CommandMetaData.Name]) {                        
            $script:CachedHelp[$CommandMetaData.Name] = Get-Help -Name $CommandMetaData.Name
        }


        $help = $script:CachedHelp[$CommandMetaData.Name]
        
        if ($help -isnot [string]) {

        }
        
        if (-not $buttonText) {
            $ButtonText = ConvertFrom-CamelCase $commandMetaData.Name.Replace('-', ' ')        
        }

        #region Start of Form
        if ($platform -eq 'Web') {
            $RandomSalt = Get-Random
            $Action =if ($carrySnug) {
                if ($Action.Contains("?")) {
                    $Action+="&snug=$true"
                    $Action
                } else {
                    $Action+="?snug=$true"
                    $Action
                }
                
            } else {
                $Action
            }
            $cssBaseName = "$($commandMetaData.Name)_Input"
            # If the platform is web, it's a <form> input        
            $null = $inputForm.Append("
<div class='$($commandMetadata.Name)_InlineOutputContainer' id='$($commandMetaData.Name)_InlineOutputContainer_$RandomSalt' style='margin-top:3%;margin-bottom:3%' >
</div>
<form method='$method' $(if ($action) {'action=`"' + $action + '`"' }) class='$cssBaseName' id='${cssBaseName}_$RandomSalt' enctype='multipart/form-data'>
    <div style='border:0px'>
    <style>
    textarea:focus, input:focus {
        border: 2px solid #009;
    }
    </style>")
        } elseif ($Platform -eq 'Android') {
            
            # If the platform is Android, it's a ViewSwitcher containing a ScrollView containing a LinearLayout
            $null = $inputForm.Append(@"
<ViewSwitcher xmlns:android="http://schemas.android.com/apk/res/android"
    android:id="@+id/$($idSafeCommandName + '_Switcher')"
    $theDefaultAttributesInAndroidLayout >
    <ScrollView 
        android:id="@+id/$($idSafeCommandName + '_ScrollView')"
        $theDefaultAttributesInAndroidLayout>
        <LinearLayout 
            $theDefaultAttributesInAndroidLayout
            android:orientation="vertical" >
    
"@)            
        } elseif ($Platform -eq 'AndroidBackEnd') {
            # In an android back end, create a class contain a static method to collect the parameters
            $null = $inputForm.Append(@"
    public String Get${IdSafeCommandName}QueryString() {
        // Save getResources() and getPackageName() so that each lookup is slightly quicker
        Resources allResources = getResources();
        String packageName = getPackageName();  
        StringBuilder queryString = new StringBuilder();                   
        Boolean initializedQueryString = false;
        Object foundView;
        String textFieldID;
"@)         
        } elseif ($Platform -eq 'CSharpBackEnd') {
            # In an android back end, create a class contain a static method to collect the parameters
            $null = $inputForm.Append(@"
    public String Get${IdSafeCommandName}QueryString() {
        // Save getResources() and getPackageName() so that each lookup is slightly quicker
        StringBuilder queryString = new StringBuilder();                   
        bool initializedQueryString = false;
        Object foundView;
        String textFieldID;
"@)         
        } elseif ('WPF', 'WindowsMobile', 'WindowsMetro', 'Win8' -contains $Platform) {
            # On WPF, WindowsMobile, or WindowsMetro it's a Grid containing a ScrollView and a StackPanel
            $null = $inputForm.Append(@"
<Grid xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <ScrollViewer>
        <StackPanel>    
"@)         
        } elseif ('GoogleGadget' -eq $platform) {
            $null = $inputForm.Append(@"        
<Module>
  <ModulePrefs title="$ButtonText" height="400"/> 
"@)        
        } elseif ('TwilML' -eq $platform) {
            $null = $inputForm.Append(@"        
<Response> 
"@)        
        }
        
        #endregion Start of Form
            
            
        #region Filter Parameters
        # Without an explicit whitelist, get all parameters    
   
        if (-not $AllowedParameter) {
            $allowedParameter  = $CommandMetaData.Parameters.Keys 
        }
   
        # If a parameter set was provided, filter out parameters from other parameter sets
        if ($parameterSet) {        
            $allParameters = $allowedParameter |
                Where-Object {
                    $commandMetaData.Parameters[$_].Attributes | 
                        Where-Object { $_.ParameterSetName -eq $parameterSet }
                }
        }
        
        # Remove the denied parameters    
        $allParameters = foreach ($param in $allowedParameter) {
            if ($DenyParameter -notcontains $param) {
                $param
            }
        }
        
        # Order parameters if they are not explicitly ordered
        if (-not $order) {
            $order = 
                 $allParameters | 
                    Select-Object @{
                        Name = "Name"
                        Expression = { $_ }
                    },@{
                        Name= "NaturalPosition"
                        Expression = { 
                            $p = @($commandMetaData.Parameters[$_].ParameterSets.Values)[0].Position
                            if ($p -ge 0) {
                                $p
                            } else { 1gb }                                              
                        }
                    } | 
                    Sort-Object NaturalPosition| 
                    Select-Object -ExpandProperty Name
        }
        #endregion Filter Parameters                
        $mandatoryFields = New-Object Collections.ArrayList
        $parameterIds= New-Object Collections.ArrayList
        $inputFields = New-Object Collections.ArrayList
        foreach ($parameter in $order) {
            if (-not $parameter) { continue }
            if (-not ($commandMetaData.Parameters[$parameter])) { continue }
            $parameterType = $commandMetaData.Parameters[$parameter].ParameterType
            $IsMandatory = foreach ($pset in $CommandMetaData.Parameters[$parameter].ParameterSets.Values) {
                if ($pset.IsMandatory) { $true; break} 
            }
            $friendlyParameterName = ConvertFrom-CamelCase $parameter
            $inputFieldName = "$($CommandMetaData.Name)_$parameter"                
            $null = $inputFields.Add($inputFieldName)
            $parameterIdentifier = "${idSafeCommandName}_${parameter}"
            $null = $parameterIds.Add($parameterIdentifier)
            if ($IsMandatory) {
                $null = $mandatoryFields.Add($parameterIdentifier)
            }
            
            $parameterHelp  = 
                foreach ($p in $help.Parameters.Parameter) {
                    if ($p.Name -eq $parameter) {
                        $p.Description | Select-Object -ExpandProperty Text
                    }
                }                
            
                
            $parameterVisibleHelp = $parameterHelp -split ("[`n`r]") |? { $_ -notlike "|*" } 
            
            $pipeworksDirectives  = @{}
            foreach ($line in $parameterHelp -split ("[`n`r]")) {
                if ($line -like "|*") {
                    $directiveEnd= $line.IndexofAny(": `n`r".ToCharArray())
                    if ($directiveEnd -ne -1) {
                        $name, $rest = $line.Substring(1, $directiveEnd -1).Trim(), $line.Substring($directiveEnd +1).Trim()
                        $pipeworksDirectives.$Name = $rest
                    } else {
                        $name = $line.Substring(1).Trim()
                        $pipeworksDirectives.$Name = $true
                    }
                    
                    
                }
            }


            if ($ParameterDefaultValue.$parameter) {
                $pipeworksDirectives.Default = $ParameterDefaultValue.$parameter
            }

            if ($ParameterOption.$parameter) {
                $pipeworksDirectives.Options = $ParameterOption.$parameter
            }

            # The Select directive uses a Select-COMMAND to produce input for a parameter.   
            # If the command contains a -Platform parameter, it will be passed the platform
            if ($pipeworksDirectives.Select) {
                $selectCmd = Get-Command -Name "Select-$($pipeworksDirectives.Select)"  -ErrorAction SilentlyContinue
                
                $selectParams = @{}
                if ($selectCmd.Parameters.Platform) {
                    $selectParams.Platform = $Platform
                }
                $inputForm.Append("$(& $selectCmd)")
                continue
            }

            if ($Platform -eq 'Web') { 
                
                $boldIfMandatory = if ($IsMandatory) { "<b>" } else { "" } 
                $unboldIfMandatory = if ($IsMandatory) { "</b>" } else { "" } 
                if (-not $TwoColumn) {
                    $null = $inputForm.Append("
        <div style='margin-top:2%;margin-bottom:2%;$(if ($pipeworksDirectives.Float) {'float:left'} else {'clear:both'})'>
        <div style='width:37%;float:left;'>        
        <label for='$inputFieldName' style='text-align:left;font-size:1.3em'>
        ${boldIfMandatory}${friendlyParameterName}${unboldIfMandatory}
        </label>
        ")
                    ""
                } else {
                    $null = $inputForm.Append("
    <tr>
        <td style='width:25%'><p>${boldIfMandatory}${friendlyParameterName}${unboldIfMandatory}</p></td>
        <td style='width:75%;text-align:center;margin-left:15px;padding:15px;font-size:medium'>")
                }
            } elseif ($platform -eq 'Android') {
            # Display parameter name, unless it's a checkbox (then the parameter name is inline)
                if ([Switch], [Bool] -notcontains $parameterType) {
                
                    $null = $inputForm.Append(@"
    <TextView
        $theDefaultAttributesInAndroidLayout
        android:text="$friendlyParameterName"        
        android:padding="5px"    
        android:textAppearance="?android:attr/textAppearanceMedium"    
        android:textStyle='bold' />

"@)
                }
            } elseif ($platform -eq 'AndroidBackend') {
                
                # If it's android backend, simply add a lookup for the values to the method
                $null = $inputForm.Append(@"

    String textFieldID = "$parameterIdentifier";
    View foundView = findViewById(
        allResources.
        getIdentifier(textFieldID,         
	       "id", 
		  packageName));

"@)                        
            } elseif ($platform -eq 'CSharpBackend') {
                
                # If it's android backend, simply add a lookup for the values to the method
                $null = $inputForm.Append(@"

    textFieldID = "$parameterIdentifier";
    foundView = this.FindName(textFieldID);

"@)                        
            } elseif ($platform -eq 'WindowsMobile' -or 
                $platform -eq 'WPF' -or
                $platform -eq 'Metro' -or 
                $Platform -eq 'Win8') {
            
                $MajorStyleChunk = if ($Platform -ne 'WindowsMobile') {
                    "FontSize='19'"
                } else {
                    "Style='{StaticResource PhoneTextExtraLargeStyle}'"
                }
                $includeHelp = if ([Switch], [Bool] -notcontains $parameterType) {
                    "
                    <TextBlock           
                        $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                        $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })         
                        $MajorStyleChunk 
                        Margin='28 2 0 3'
                        FontWeight='Bold'
                        Text='$FriendlyParameterName' />                    
                    "            
                    } else { 
                        "" 
                    }
            $null = $inputForm.Append(@"
                $includeHelp
"@)
            }
        
            $StyleChunk = if ($Platform -ne 'WindowsMobile') {
                "FontSize='14'"
            } else {
                "Style='{StaticResource PhoneTextSubtleStyle}'"
            }
            
            
                                         
            if ($pipeworksDirectives.FileName) {
                continue
            }
                
            $parameterHelp= $parameterVisibleHelp -join ([Environment]::NewLine)
            if ($parameterHelp) {
                if ($Platform -eq 'Web') {
                    $null = $inputForm.Append("<br style='line-height:150%' />$(
ConvertFrom-Markdown -md $parameterHelp)")            
                } elseif ($Platform -eq 'Android') {
                    if ([Switch], [Bool] -notcontains $parameterType) {
                        $null = $inputForm.Append("
                        <TextView
                            $theDefaultAttributesInAndroidLayout
                            android:text=`"$([Web.HttpUtility]::HtmlAttributeEncode($parameterHelp))`"       
                            android:padding='2px'    
                            android:textAppearance='?android:attr/textAppearanceSmall' />")
                    }
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                    if ([Switch], [Bool] -notcontains $parameterType) {
                        $null = $inputForm.Append("
                <TextBlock
                    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                    Name='${parameter}_Description_TextBlock'
                    $StyleChunk
                    Margin='7,0, 5,0'
                    TextWrapping='Wrap'>
                    $([Security.SecurityElement]::Escape($parameterHelp))
                </TextBlock>")
                    }
                }
            }
            
            if ($platform -eq 'Web') {
                $null = $inputForm.Append("</div>
                <div style='float:right;width:60%;'>
                
                ")
            
            }



            $validateSet = 
                foreach ($attribute in $commandMetaData.Parameters[$parameter].Attributes) {
                    if ($attribute.TypeId -eq [Management.Automation.ValidateSetAttribute]) {
                        $attribute
                        break
                    }
                }                
            
            $defaultValue = $pipeworksDirectives.Default
            if ($pipeworksDirectives.Options -or $validateSet -or $parameterType.IsSubClassOf([Enum])) {
                $optionList = 
                    if ($pipeworksDirectives.Options) {
                        Invoke-Expression -Command "$($pipeworksDirectives.Options)" -ErrorAction SilentlyContinue
                    } elseif ($ValidateSet) {
                        $ValidateSet.ValidValues
                    } elseif ($parameterType.IsSubClassOf([Enum])) {
                        [Enum]::GetValues($parameterType)
                    }            
            
                if ($Platform -eq 'Web') {
                        $options = foreach ($option in $optionList) {
                            $selected = if ($defaultValue -eq $option) {
                                " selected='selected'"
                            } else {
                                ""
                            }
                            "$(' ' * 20)<option $selected>$option</option>"
                        }
                        $options = $options -join ([Environment]::NewLine)
                        if (-not $firstcomboBox) {
                            $firstcomboBox = $optionList
                            
                        }      
                        $null = $inputForm.Append("<select class='comboboxfield' name='$inputFieldName' id='$($parameterIdentifier)' value='$($pipeworksDirectives.Default)'>                            
                            $(if (-not $IsMandatory) { "<option> </option>" })
                            $options
                        </select>
                        ")
                } elseif ($Platform -eq 'Android') {
                    # Android is a bit of a pita.  There are two nice controls for this: Spinner and AutoCompleteEditText, but both
                    # cannot specify the resources in the same XML file as the control.
                    
                    if ($optionList.Count -gt 10) {
                        # Text box
                        $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1)")                                        
                    } else {
                                                            
                        $null = $inputForm.Append(@"                        
    <RadioGroup
        android:id="@+id/$($idSafeCommandName + '_' + $parameter)"
        $theDefaultAttributesInAndroidLayout>
"@)        
                        foreach ($value in $optionList) { 
                            
                            $null = $inputForm.Append("
        <RadioButton                        
            $theDefaultAttributesInAndroidLayout
            android:text='$value' />")                                            
                            
                        } 
                        
                        $null = $inputForm.Append(@"                        
    </RadioGroup>
"@)                
                    }
                } elseif ('TwilML' -eq $platform) {                                               
                    # Twilio           
                    $friendlyParameterName = ConvertFrom-CamelCase $parameter

                    $optionNumber = 1
                    $phoneFriendlyHelp = 
                        foreach ($option in $optionList) {
                            "Press $OptionNumber for $Option"
                            $optionNumber++
                        } 
                    $phoneFriendlyHelp  = $phoneFriendlyHelp -join ".  $([Environment]::NewLine)"                    
                    
                    $null = $inputForm.Append(@"
    <Gather numDigits="$($optionNumber.ToString().Length)" $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" })>     
        <Say>
            $([Security.SecurityElement]::Escape($phoneFriendlyHelp ))
        </Say>        
    </Gather>
"@)                 
                
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                    # XAML does not have this limitation
                    if ($optionList.Count -lt 5) {
                        # Radio Box
                        # Combo Box                         
                        $null = $inputForm.Append("
<Border x:Name='$($idSafeCommandName + '_' + $parameter)'>
    <StackPanel>")                                            
                      

                        foreach ($value in $optionList) { 
                            
                            $null = $inputForm.Append("
    <RadioButton 
        $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
        $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
        GroupName='$($idSafeCommandName + '_' + $parameter)'>$([Security.SecurityElement]::Escape($value))</RadioButton>")                                            
                            
                        } 
                        $null = $inputForm.Append("
    </StackPanel>
</Border>")                                            
                            
                        
                    } else {
                        # Combo Box                         
                        $null = $inputForm.Append(@"                        
    <ComboBox         
        x:Name='$($idSafeCommandName + '_' + $parameter)'
        $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
        $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" }) >
"@)        
                        foreach ($value in $optionList) { 
                            
                            $null = $inputForm.Append("
        <ComboBoxItem>$([Security.SecurityElement]::Escape($value))</ComboBoxItem>")                                            
                            
                        } 
                        
                        $null = $inputForm.Append(@"                        
    </ComboBox>
"@)                
                    }
                } elseif ('GoogleGadget' -eq $platform ) {
                    $enumItems  = foreach ($option in $optionList) {
                        "<EnumValue value='$option'/>"
                    }
                    $null = $inputForm.Append( @"
<UserPref name="$parameterIdentifier" display_name="$FriendlyParameterName" datatype="enum" >
    $enumItems 
</UserPref> 
"@)                    
                }                                                    
            } elseif ([int[]], [uint32[]], [double[]], [int], [uint32], 
                [double], [Timespan], [Uri], [DateTime], [type], [version] -contains $parameterType) {
                # Numbers and similar primitive types become simple input boxes.  When possible, use one of the new
                # HTML5 input types to leverage browser support.        
                if ([int[]], [uint32[]], [double[]], [int], [uint32], [double] -contains $parameterType) {
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1 -IsNumber)")
                } elseif ($parameterType -eq [DateTime]) {
                    # Add A JQueryUI DatePicker
                    
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1 -CssClass 'dateTimeField' -type text)")
                } else {
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1)")                                        
                }
            } elseif ($parameterType -eq [byte[]]) {
                if ($platform -eq 'Web') {
                    if ($pipeworksDirectives.File) {
    $null = $inputForm.Append("<input type='file' name='$inputFieldName' chars='40' style='width:100%' $(if ($pipeworksDirectives.Accept) {"accept='$($pipeworksDirectives.Accept)'"}) />")                                        
                    } elseif ($pipeworksDirectives.FilePickerIO) {
    $null = $inputForm.Append("<input type='filepicker' data-fp-apikey='$($pipeworksManifest.FilePickerIOKey)' name='$InputFieldName' $(if ($pipeworksDirectives.Accept) {"data-fp-mimetype='$($pipeworksDirectives.Accept)"})' />")
                    }
                }
            } elseif ($parameterType -eq [Security.SecureString]) {
                if ($platform -eq 'Web') {
    $null = $inputForm.Append("<input type='password' name='$inputFieldName' style='width:100%'>")                                        
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
    $null = $inputForm.Append(@"
    <PasswordBox
    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
    Margin="7, 5, 7, 5"
    x:Name="$parameterIdentifier"    
    $(if ($defaultValue) { "Password='$defaultValue'" })    
    Tag='Type:$($parameterType.Fullname)' />
"@)                        
                }
            } elseif ($parameterType -eq [string]) {            
                if ($pipeworksDirectives.Contains("Color") -and $Platform -eq 'Web' -and $pipeworksManifest.UseJQueryUI) {
                    # Show a JQueryUI Color Picker

                    if ($pipeworksDirectives.Default) {
                        $dcolor = $pipeworksDirectives.Default.Trim('#').ToCharArray()
                        $red = "0x$($dcolor[0,1] -join '')" -as [uint32]
                        $green = "0x$($dcolor[2,3] -join '')" -as [uint32]
                        $blue = "0x$($dcolor[4,5] -join '')" -as [uint32]
                    } else {
                        $red = Get-Random -Maximum 255
                        $green  = Get-Random -Maximum 255
                        $blue = Get-Random -Maximum 255
                    }



$colorInput = @"
<style>
    #red_$parameterIdentifier, #green_$parameterIdentifier, #blue_$parameterIdentifier {
        float: left;
        clear: left;
        width: 300px;
        margin: 15px;
    }
    #swatch_$parameterIdentifier {
        width: 120px;
        height: 100px;
        margin-top: 18px;
        margin-left: 350px;
        background-image: none;
    }
    #red_$parameterIdentifier .ui-slider-range { background: #ef2929; }
    #red_$parameterIdentifier .ui-slider-handle { border-color: #ef2929; }
    #green_$parameterIdentifier .ui-slider-range { background: #8ae234; }
    #green_$parameterIdentifier .ui-slider-handle { border-color: #8ae234; }
    #blue_$parameterIdentifier .ui-slider-range { background: #729fcf; }
    #blue_$parameterIdentifier .ui-slider-handle { border-color: #729fcf; }
    </style>
    <script>
    function hexFromRGB(r, g, b) {
        var hex = [
            r.toString( 16 ),
            g.toString( 16 ),
            b.toString( 16 )
        ];
        `$.each( hex, function( nr, val ) {
            if ( val.length === 1 ) {
                hex[ nr ] = "0" + val;
            }
        });
        return hex.join( "" ).toUpperCase();
    }
    function refresh${ParameterIdentifier}Swatch() {
        var red = `$( "#red_$parameterIdentifier" ).slider( "value" ),
            green = `$( "#green_$parameterIdentifier " ).slider( "value" ),
            blue = `$( "#blue_$parameterIdentifier" ).slider( "value" ),
            hex = hexFromRGB( red, green, blue );
        `$( "#swatch_$parameterIdentifier" ).css( "background-color", "#" + hex );
        `$('#$parameterIdentifier').val(hex)
    }
    `$(function() {
        `$( "#red_$parameterIdentifier, #green_$parameterIdentifier, #blue_$parameterIdentifier " ).slider({
            orientation: "horizontal",
            range: "min",
            max: 255,
            value: 127,
            slide: refresh${ParameterIdentifier}Swatch,
            change: refresh${ParameterIdentifier}Swatch
        });
        `$( "#red_$parameterIdentifier" ).slider( "value", $red );
        `$( "#green_$parameterIdentifier " ).slider( "value", $green );
        `$( "#blue_$parameterIdentifier " ).slider( "value", $blue);
    });
</script>
<div id="red_$parameterIdentifier"></div>
<div id="green_$parameterIdentifier"></div>
<div id="blue_$parameterIdentifier"></div>
 
<div id="swatch_$parameterIdentifier" class="ui-widget-content ui-corner-all"></div>
<input name='$inputFieldName' id='$parameterIdentifier' type='text' value='' style='width:120px;margin-top:18px;margin-left: 350px;'>
"@
                    $null = $inputForm.Append($colorInput)                                                                                                                             
                } else {
                    $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 1)")                                                                                                                             
                }                                  
                
            } elseif ([string[]], [uri[]] -contains $parameterType) {                             
                $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 4)")                                                                
            } elseif ([ScriptBlock] -eq $parameterType -or 
                [PSObject] -eq $parameterType -or 
                [PSObject[]] -eq $parameterType -or
                [Hashtable[]] -eq $parameterType) {                             
                $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 6)")                                                                
            } elseif ([Hashtable] -eq $parameterType) {                             
                if ($pipeworksDirectives.Default -is [Hashtable]) {
                    $d = foreach ($kv in $pipeworksDirectives.Default.GetEnumerator()) {
                        "$($kv.Key) = $($kv.Value)"
                    }
                    $d = $d -join ([Environment]::NewLine)
                    $pipeworksDirectives.Default = $d
                }

                    
                $null = $inputForm.Append("$(. New-TextInput -defaultNumberOfLines 6)")                                                                
            } elseif ([switch], [bool] -contains $parameterType) {
                if ($platform -eq 'Web') {
                    $null = $inputForm.Append("<input name='$inputFieldName' type='checkbox' $(if ($pipeworksDirectives.Default -and $pipeworksDirectives.Default -like "*true*") { "checked='yes'"})/>")
                } elseif ($platform -eq 'Android') {
                    $null = $inputForm.Append(@"
            <CheckBox
                android:id="@+id/$($commandMetaData.Name.Replace("-", "") + "_" + $parameter)"
                $theDefaultAttributesInAndroidLayout        
                android:text="$friendlyParameterName"
                android:textAppearance="?android:attr/textAppearanceMedium"    
                android:textStyle='bold' />  
                                 
            <TextView
                $theDefaultAttributesInAndroidLayout        
                android:text="$([Web.HttpUtility]::HtmlAttributeEncode($parameterHelp))"        
                android:padding="2px"    
                android:textAppearance="?android:attr/textAppearanceSmall" />
"@)          
                } elseif ('WindowsMobile', 'WPF' ,'Metro', 'SilverLight', 'Win8' -contains $platform) {
                    $null = $inputForm.Append(@"
            <CheckBox
                Margin="5, 5, 2, 0"
                $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                x:Name='$($idSafeCommandName + '_' + $parameter)'>
                <StackPanel Margin="3,-5,0,0">
                <TextBlock
                    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                    Name='${parameter}_ParameterName_TextBlock'
                    $MajorStyleChunk 
                    FontWeight='Bold'
                    Text='$friendlyParameterName' />   
                    
                <TextBlock
                    $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
                    $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
                    Name='${parameter}_Description_TextBlock'
                    $StyleChunk    
                    TextWrapping='Wrap'>                            
                    $([Security.SecurityElement]::Escape($parameterHelp))
                </TextBlock>
                </StackPanel>
            </CheckBox>           
"@)        
                }  elseif ($platform -eq 'AndroidBackEnd') {
                    $null = $inputForm.Append(@"
        try {
            CheckBox checkbox = (CheckBox)foundView;
    		
    		if (! initializedQueryString) {
    			initializedQueryString = true;        			
    		} else {
    			queryString.append("&");
    		}

            queryString.append(textFieldID);
            queryString.append("=");
            
            
            if (checkbox.isChecked()) {
    			queryString.append("true");
    		} else {
    			queryString.append("false");
    		}				
        } catch (Exception e) {
            e.printStackTrace();
        }
"@)                                    
                }  elseif ($platform -eq 'CSharpBackEnd') {
                    $null = $inputForm.Append(@"
            try {
                CheckBox checkbox = (CheckBox)foundView;
        		
        		if (! initializedQueryString) {
        			initializedQueryString = true;        			
        		} else {
        			queryString.Append("&");
        		}
                
                queryString.Append(textFieldID);
                queryString.Append("=");
                
                if ((bool)(checkbox.IsChecked)) {
        			queryString.Append("true");
        		} else {
        			queryString.Append("false");
        		}	
            } catch (Exception ex){
                throw ex;
            }			
        
"@)                                    
                } elseif ($Platform -eq 'TwilML') {
                    # Twilio           
                    $friendlyParameterName = ConvertFrom-CamelCase $parameter
                    $phoneFriendlyHelp = "$(if ($parameterHelp) { "$ParameterHelp "} else { "Is $FriendlyParameterName" })   If so, press 1.  If not, press 0."  
                    
                    $null = $inputForm.Append(@"
    <Gather numDigits="1" $(if ($Action) { "action='$([Security.SecurityElement]::Escape($action))'" }) >     
        <Say>
        $([Security.SecurityElement]::Escape($phoneFriendlyHelp ))
        </Say>        
    </Gather>
"@)                 
                }
            }                                                    
         
            
        # Close the parameter input 
        if ($platform -eq 'Web') {
                
                $null = $inputForm.Append("
        </div>
        <div style='clear:both'>
        </div>
        </div>

        ")
        } elseif ('WindowsMobile', 'Metro', 'WPF', 'Win8' -contains $platform) {
                $null = $inputForm.Append("
")
                
        
                 
        } elseif ('PipeworksDirective' -eq $platform ) {
            if ($pipeworksDirectives.Count) {
                $allPipeworksDirectives.$parameter = $pipeworksDirectives
            }
            
        }
        
        $null =        $null
    }
    

    #region Button
    if (-not $NoButton) { 
        if ($Platform -eq 'Web') {

            $checkForMandatory = ""
            if( $mandatoryFields) {
                foreach ($check in $mandatoryFields) {

                    $checkForMandatory += "
if (`$(`".$check`").val() == `"`") {
    event.preventDefault();
    return false;
}
"
                }
            }
            $ajaxPart = if ($Ajax) {
                    
                    $ajaxAction = 
                        if ($action.Contains('?') -and $action -notlike "*snug=true*") {
                            $action + "&Snug=true"
                        } elseif ($Action -notlike "*snug=true*") {
                            if ($action.EndsWith('/')) {
                                $action + "?Snug=true"
                            } else {
                                $action + "/?Snug=true"
                            }
                        }
@"
                    `$('#${cssbaseName}_$RandomSalt').submit(function(event){
                        var data = `$(this).serialize();
                        if (Form_${RandomSalt}_Submitted == true) {
                            event.preventDefault();
                            return false;
                        }

                        $checkForMandatory
                           
                        `$('input[type=submit]', this).prop('disabled', true);
                        Form_${RandomSalt}_Submitted  =true;
                        setTimeout(
                            function() {
                            `$.ajax({
                                 url: '$ajaxAction',
                                 async: false,                                 
                                 data: data
                            }).done(function(data) {                                
                                    `$('#$($commandMetadata.Name)_InlineOutputContainer_$RandomSalt').html(data);
                                    `$('#${cssBaseName}_$RandomSalt').hide()
                                    `$('html, body').animate({scrollTop: `$(`"#$($commandMetadata.Name)_InlineOutputContainer_$RandomSalt`").offset().top}, 400); 
                                })                                
                            }, 125);
                        `$( `"#$($commandMetadata.Name)_Undo_$RandomSalt`" ).show();
                        `$( `"#$($commandMetadata.Name)_Undo_$RandomSalt`" ).button().click(
                            function(event) { 
                                `$('input[type=submit]').prop('disabled', false);                                
                                Form_${RandomSalt}_Submitted = false;
                                `$('#$($commandMetadata.Name)_Undo_$RandomSalt').hide()
                                `$('#${cssBaseName}_$RandomSalt').show()
                                `$('html, body').animate({scrollTop: `$(`"#${cssBaseName}_$RandomSalt`").offset().top}, 400);    
                                event.preventDefault();
                            });
                        //event.preventDefault();
                        return false;
                    });
"@
            } else {
                ""
            }
            if (-not $TwoColumn) {
                $null = $inputForm.Append("
    <br style='clear:both'/>
    <div style='width:50%;float:right'>
        ")
            } else {
                
                $null = $inputForm.Append("
    <tr>
        <td style='text-align:right;margin-right:15px;padding:15px'>            
        </td>")
            }
            if ($buttonImage) {
                $null = $inputForm.Append("
            <p style='text-align:center;margin-left:15px;padding:15px'>                    
                ")
            } else {
                $null = $inputForm.Append("
            <p style='text-align:center;margin-left:15px;padding:15px'>
                $(if ($Ajax) {
                    "<script>" + 
                        (Write-Ajax -InputId $parameterIds -InputQuery $inputFields -Name "submit$($commandMetadata.Name.Replace('-', ''))" -Url $Action -UpdateId "$($commandMetaData.Name)_InlineOutputContainer_$RandomSalt" -Method $Method) + 
                    "</script>"
                })
                <input type='submit' class='$($commandMetadata.Name)_SubmitButton btn btn-primary rounded' value='$buttonText' style='padding:5px;font-size:large' $(if ($ajax) { "onclick='submit$($commandMetadata.Name.Replace("-", ''))();event.preventDefault();'" }) />
                
                <script>
                    $(if ($pipeworksManifest.UseJQueryUI -or $pipeworksManifest.UseBootstrap -or $pipeworksManifest.UseJQuery) {
@"
                    `$(function() {
                        $(if ($pipeworksManifest.UseJQueryUI -or $pipeworksManifest.UseBootstrap) { @"
                        `$( `".$($commandMetadata.Name)_SubmitButton`" ).button();
"@})
                        `$( `".$($commandMetadata.Name)_Undo`" ).hide();
                        var Form_${RandomSalt}_Submitted = false;
                        /* 
                        $ajaxPart 
                        */
                    })
"@})                                        
                </script>
            </p>                
                "
                
                
                )
                
            }
            if (-not $twoColumn) {
                $null = $inputForm.Append("</div><br style='clear:both' />")
            } else {
                $null = $inputForm.Append("</tr>")
            }
        } elseif ($Platform -eq 'Android') {
            $null = $inputForm.Append(@"
    <TableLayout 
        $theDefaultAttributesInAndroidLayout>
	       
           <Button
    	        android:id="@+id/$($idSafeCommandName)_Invoke"
    	        $theDefaultAttributesInAndroidLayout
    	        android:text="$ButtonText" />
	</TableLayout>
"@)            
        } elseif ('WPF', 'WindowsMobile', 'WindowsMetro', 'Win8' -contains $Platform) {
            $null = $inputForm.Append(@"
    <Button HorizontalAlignment='Stretch' x:Name='$($idSafeCommandName)_Invoke' Margin='7'>
        <TextBlock
            $(if ($Platform -eq 'Win8') { "Foreground='{StaticResource TheForegroundColor}'" })
            $(if ($Platform -eq 'Win8') { "Background='{StaticResource TheBackgroundColor}'" })
            $MajorStyleChunk
            FontWeight='Bold'            
            Text='$ButtonText' />        
    </Button>
    
"@)         
        }
    }    
        
    
    #endregion
        if ($platform -eq 'Web') {
            $null = $inputForm.Append("
    </div>
    $(if ($Focus) {@"
<script>`$('input[name*=`"$($command.Name)_${focus}`"]').focus();</script>
"@
})
</form>
<div class='$($commandMetadata.Name)_ErrorContainer'>
</div>
<div class='$($commandMetadata.Name)_CenterButton' style='text-align:center'>
    <a href='javascript:void' class='$($CommandMetaData.Name)_Undo btn btn-primary' id='$($CommandMetaData.Name)_Undo_$RandomSalt' style='display:none;text-align:center;font-size:small'><div class='ui-icon ui-icon-pencil' style='margin-left:auto;margin-right:auto'> </div>Change Input</a>
</div>


")    
        } elseif ($platform -eq 'Android') {
            $null = $inputForm.Append("
    </LinearLayout>
</ScrollView>
</ViewSwitcher>
")    
        } elseif ('AndroidBackEnd' -eq $platform) {
            $null = $inputForm.Append("
        return queryString.toString();
    }
")    
        } elseif ('CSharpBackEnd' -eq $platform) {
            $null = $inputForm.Append("
        return queryString.ToString();
    }
")    
        } elseif ('WPF', 'WindowsMobile', 'WindowsMetro', 'Win8' -contains $Platform) {
            $null = $inputForm.Append(@"
    </StackPanel>
</ScrollViewer>
</Grid>
"@)         
        } elseif ('GoogleGadget' -eq $platform) {
            $null = $inputForm.Append(@"        
</Module>  
"@)        
        } elseif ('TwilML' -eq $platform) {
            $null = $inputForm.Append(@"        
</Response>  
"@)        
        }
        
        $output = "$inputForm"
        
        if ('Android', 'WPF','SilverLight', 'WindowsMobile', 'Metro', 'Win8', 'Web','GoogleGadget', 'TwilML' -contains $platform) {
            if ($output -as [xml]) {            
                # Nice XML Trick
                $strWrite = New-Object IO.StringWriter
                ([xml]$output).Save($strWrite)
                $strWrite = "$strWrite"
                $strWrite.Substring($strWrite.IndexOf('>') + 3)     
            } else {
                $output
            }
        } elseif ($Platform -eq 'PipeworksDirective') {
            $allPipeworksDirectives 
        } else {
            $output
        }
    }
}
