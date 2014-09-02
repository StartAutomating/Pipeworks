function Get-Email
{
    <#
    .Synopsis
        Gets email from exchange    
    .Description
        Gets email from an exchange server
    .Link
        Invoke-Office365
    .Example
        Get-Email
    #>
    [OutputType([PSObject])]
    [CmdletBinding(DefaultParameterSetName='UserNameAndPasswordSetting')]
    param(    
    # The account
    [Parameter(Mandatory=$true,ParameterSetName='SpecificAccount')]
    [Management.Automation.PSCredential]
    $Account,

    # The setting containing the username
    [Parameter(ParameterSetName='UserNameAndPasswordSetting')]
    [string]
    $UserNameSetting = 'Office365Username',

    # The setting containing the password
    [Parameter(ParameterSetName='UserNameAndPasswordSetting')]
    [string]
    $PasswordSetting = 'Office365Password',

    # The email account to connect to retreive data from.  If not specified, email will be retreived for the account used to connect.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $Email,

    # If set, will only return unread messages
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $Unread,

    # The name of the contact the email was sent to.  This the displayed name, not a full email address
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $To,
    
    # The email that sent the message
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $From,

    # If set, will download the email content, not just the headers
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $Download
    )

    begin {
$wsPath = $MyInvocation.MyCommand.ScriptBlock.File |
    Split-Path | 
    Get-ChildItem -Filter bin |
    Get-ChildItem -Filter Microsoft.Exchange.WebServices.dll 
     
$ra = Add-Type -Path $wspath.FullName -PassThru | Select-Object -ExpandProperty Assembly -Unique | Select-Object -ExpandProperty Location

Add-Type -ReferencedAssemblies $ra -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.Exchange.WebServices.Data;
using System.Net.Security;
using System.Net;
using Microsoft.Exchange.WebServices.Autodiscover;
using System.Configuration;

public class Office365EWSHelper2
{
    /// <summary>
    /// Bind to Mailbox via AutoDiscovery
    /// </summary>
    /// <returns>Exchange Service object</returns>
    public static ExchangeService GetBinding(WebCredentials credentials, string lookupEmail)
    {
        // Create the binding.
        ExchangeService service = new ExchangeService(ExchangeVersion.Exchange2010_SP1);

        // Define credentials.
        service.Credentials = credentials; 

        // Use the AutodiscoverUrl method to locate the service endpoint.
        service.AutodiscoverUrl(lookupEmail, RedirectionUrlValidationCallback);                                
        return service;
    }


    // Create the callback to validate the redirection URL.
    static bool RedirectionUrlValidationCallback(String redirectionUrl)
    {
        // Perform validation.
        return true; // (redirectionUrl == "https://autodiscover-s.outlook.com/autodiscover/autodiscover.xml");
    }

}

'@



    }
    process {
        if ($Account) {
            $Cred = $Account
        } elseif ($UserNameSetting -and $PasswordSetting) {
            $cred = New-Object Management.Automation.PSCredential (Get-SecureSetting $UserNameSetting -ValueOnly), 
                (ConvertTo-SecureString -AsPlainText -Force (Get-SecureSetting $PasswordSetting -ValueOnly))
        }

        if (-not $script:ewsForUser) { 
            $script:ewsForUser = @{}
        }
        $ForEmail = if ($Email) {
            $Email
        } else {
            $cred.UserName
        }
        if (-not $ewsForUser["${ForEmail}_AS_$($Cred.UserName)"]) {
            
            $ews = [Office365EwsHelper2]::GetBinding($cred.GetNetworkCredential(), $ForEmail)
            $script:ewsForUser["${ForEmail}_AS_$($Cred.UserName)"] = $ews
        } else {
            $ews = $script:ewsForUser["${ForEmail}_AS_$($Cred.UserName)"]
        }
        
        $coll =New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+SearchFilterCollection

        if ($Unread) {
            $unreadFilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo -Property @{PropertyDefinition=[Microsoft.Exchange.WebServices.Data.EmailMessageSchema]::IsRead;Value='false'} 
            $coll.add($unreadFilter)
        }

        if ($To) {
            if ($to -notlike "*@.*") {
                $toEmail = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+ContainsSubstring -Property @{PropertyDefinition=[Microsoft.Exchange.WebServices.Data.EmailMessageSchema]::DisplayTo;Value=$To} 
                $coll.add($toEmail)

                
            } else {
                $toEmail = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+ContainsSubstring -Property @{PropertyDefinition=[Microsoft.Exchange.WebServices.Data.EmailMessageSchema]::DisplayTo;Value=$To} 
                $coll.add($toEmail)
            }
            
        }

        if ($From) {
            $fromEmail = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo -Property @{PropertyDefinition=[Microsoft.Exchange.WebServices.Data.EmailMessageSchema]::From;Value=$From} 
            $coll.add($fromEmail )
            
        }
        


        $fid = New-Object Microsoft.Exchange.WebServices.Data.FolderId "Inbox", $ForEmail
        $iv = New-Object Microsoft.Exchange.WebServices.Data.ItemView 1000
        $fiItems  = $null
        do{
            
            if ($coll.Count) {
	            $fiItems = $ews.FindItems($fid , $coll, $iv)
            } else {
                $fiItems = $ews.FindItems($fid , "", $iv)
            }

	        foreach ($Item in $fiItems) {
                if ($Download) {
                    $item.load()
                }

                if ($item.From.RoutingType -eq 'EX') {
                    $_ = $_
                    $emails = $ews.ResolveName($item.From.Name, "DirectoryOnly", $true) | ForEach-Object { $_.Mailbox }   | ForEach-Object{ $_.GetSearchString() } 
                    $emails = $emails -join ','
                    $item |
                        Add-Member NoteProperty FromEmail $emails
                } else {
                    $item |
                        Add-Member NoteProperty FromEmail $item.From.Address
                }
                $Item
	        }
	        $iv.offset += $fiItems.Items.Count
        }while($fiItems.MoreAvailable -eq $true)

    }
}