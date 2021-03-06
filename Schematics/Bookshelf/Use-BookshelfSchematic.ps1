function Use-BookshelfSchematic
{
    <#
    .Synopsis
        Builds a web application according to a schematic
    .Description
        Use-Schematic builds a web application according to a schematic.
        
        Web applications should not be incredibly unique: they should be built according to simple schematics.        
    .Notes
    
        When ConvertTo-ModuleService is run with -UseSchematic, if a directory is found beneath either Pipeworks 
        or the published module's Schematics directory with the name Use-Schematic.ps1 and containing a function 
        Use-Schematic, then that function will be called in order to generate any pages found in the schematic.
        
        The schematic function should accept a hashtable of parameters, which will come from the appropriately named 
        section of the pipeworks manifest
        (for instance, if -UseSchematic Blog was passed, the Blog section of the Pipeworks manifest would be used for the parameters).
        
        It should return a hashtable containing the content of the pages.  Content can either be static HTML or .PSPAGE                
    #>
    [OutputType([Hashtable])]
    param(
    # Any parameters for the schematic
    [Parameter(Mandatory=$true)][Hashtable]$Parameter,
    
    # The pipeworks manifest, which is used to validate common parameters
    [Parameter(Mandatory=$true)][Hashtable]$Manifest,
    
    # The directory the schemtic is being deployed to
    [Parameter(Mandatory=$true)][string]$DeploymentDirectory,
    
    # The directory the schematic is being deployed from
    [Parameter(Mandatory=$true)][string]$InputDirectory  
    )
    
    begin {
        $pages = @{}
    }
    
    process {           
        if (-not $parameter.Books) {
            Write-Error "No books found on bookshelf"
            return
        }
        
        
        
        $needsTableAccess = $parameter.Books | 
            Where-Object { 
                $_.Chapters | 
                    Where-Object { 
                        $_.Pages | 
                            Where-Object { $_.Id }
                    } 
            }
                 
        if ($needsTableAccess) { 
            if (-not $Manifest.Table.Name) {
                Write-Error "No table found in manifest"
                return
            }
            
            if (-not $Manifest.Table.StorageAccountSetting) {
                Write-Error "No storage account name setting found in manifest"
                return
            }
            
            if (-not $manifest.Table.StorageKeySetting) {
                Write-Error "No storage account key setting found in manifest"
                return
            }
            
        }

        $NewPages = @{}                                
        $chapterNumber = 1
        foreach ($bookInfo in @($parameter.Books)) {
            $book = New-Object PSOBject -Property $bookInfo
            $safeBookName = $book.Name.Replace(" ", "_").Replace("&", "_and_").Replace("?", "").Replace(":", "-").Replace(";", "-").Replace("!", "")
            foreach ($chapterInfo in @($book.Chapters)) {
                $chapter = New-Object PSObject -Property $chapterInfo
                
                $PageNumber = 1
                foreach ($pageInfo in @($chapter.Pages)) {
                    $page = New-Object PSOBject -Property $pageInfo                
                    $webPage = 
                        if ($page.Id) {
@"
`$storageAccount  = Get-WebConfigurationSetting -Setting `$pipeworksManifest.Table.StorageAccountSetting 
`$storageKey= Get-WebConfigurationSetting -Setting `$pipeworksManifest.Table.StorageKeySetting 
`$part, `$row  = '$($page.Id)' -split '\:'
`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$chapterNumber = '$chapterNumber'
`$chapterName = @'
$(if ($chapter.Name) { $chapter.Name })
'@.Trim()
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber"
`$PageNumber = '$PageNumber'
`$bookName = '$($book.Name)'
`$safeBookName  = '$safeBookName'
`$chapterPageCount = $(@($chapter.pages).Count)
`$pageName = @'
$(if ($page.Title) { $page.Title} else { "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber" })
'@.Trim()
if (-not `$session["StoryPage`$(`$pageName)Content"]) {
    `$session["StoryPage`$(`$pageName)Content"] = 
        Show-WebObject -StorageAccount $storageAccount -StorageKey $storageKey -Table $pipeworksManifest.Table.Name -Part $part -Row $row
} 
"@
                    } elseif ($page.Content) {
                        $htmlContent = if ($page.Content -like "*<*") {
                            $page.Content
                        } else {
                            ConvertFrom-Markdown $page.Content
                        }
@"

`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$pageName = @'
$(if ($page.Title) { $page.Title} else { "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber" })
'@.Trim()
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber"
`$chapterNumber = '$chapterNumber'
`$chapterName = @'
$(if ($chapter.Name) { $chapter.Name })
'@.Trim()

`$PageNumber = '$PageNumber'
`$bookName = '$($book.Name)'
`$safeBookName  = '$safeBookName'
`$chapterPageCount = $(@($chapter.pages).Count)
if (-not `$session["StoryPage`$(`$pageName)Content"]) {
    `$session["StoryPage`$(`$pageName)Content"] = @'
$htmlContent 
'@    
}        

"@                            
                    } elseif ($page.File) {
                        $htmlContent = if ($page.File -like "*.htm?") {
                            (Get-Content "$moduleRoot\$($page.File)" -ReadCount 0) -join ([Environment]::NewLine)
                        } elseif ($page.File -like "*.md") {
                            ConvertFrom-Markdown "$((Get-Content "$moduleRoot\$($page.File)" -ReadCount 0) -join ([Environment]::NewLine))"
                        } elseif ($page.File -like "*.walkthru.help.txt") {
                            Write-WalkthruHTML -WalkThru (Get-Walkthru -File "$moduleRoot\$($page.File)") -StepByStep 
                        }
                        
                        
@"

`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber"
`$pageName = @'
$(if ($page.Title) { $page.Title} else { "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name }) | Page $pageNumber" })
'@.Trim()

`$chapterNumber = '$chapterNumber'
`$chapterName = @'
$(if ($chapter.Name) { $chapter.Name })
'@.Trim()

`$PageNumber = '$PageNumber'
`$bookName = '$($book.Name)'
`$safeBookName  = '$safeBookName'
`$chapterPageCount = $(@($chapter.pages).Count)
if (-not `$session["StoryPage`$(`$pageName)Content"]) {
    `$session["StoryPage`$(`$pageName)Content"] = @'
$htmlContent 
'@    
}        

"@                     
                    }
                    
                    $webPage += {
$pageContent = $session["StoryPage$($pageName)Content"]
$browserSpecificStyle =
    if ($Request.UserAgent -clike "*IE*") {
        @{'height'='60%';"margin-top"="-5px"}
    } else {
        @{'min-height'='60%'}
    }  

$coreStyle = @{
}


$bn, $cn, $pn = $LongPageName -split "\|"
$centerWidth  = 100 - ([Double]$lMargin.Replace("%", "") + [Double]$lMargin.Replace("%", ""))

$titleSection = "
<div style='margin-left:auto;margin-right:auto' id='TitleArea'>
<p>
<a href='$SafeBookName.aspx'>$bn</a>
<p/>
<p style='text-indent:5px;font-size:medium'>
<a href='$SafeBookName.$ChapterNumber.aspx'>$cn</a> $(if ($pageName -ne $longPageName) { 
    "| <a href='$SafeBookName.$ChapterNumber.$pageNumber.aspx'>$pageName</a>"
} else {
})
</p>
<p style='font-size:small;text-align:right'>
$pn
</p>
<hr/>
</div>
$pageContent" | New-Region -LayerID Page -Style @{
        'Margin-Left' = $lMargin
        'Margin-Right' = $rMargin
        'Position' = 'absolute'
        'Margin-Top' = '1%'                
        'Width' = "${centerWidth}%"
    }

$lastPageButton = 
    if ($pageNumber -gt 1) {
        Write-Link -Style @{"Font-Size" ="xx-large"} -Url "$safeBookName.$($chapterNumber).$([int]$pageNumber - 1).aspx" -Caption "<span class='ui-icon ui-icon-arrowthickstop-1-w' style='font-size:x-large'>&nbsp;</span>" -Button |
            New-Region -LayerID LastPageButtonContainer -Style @{
                'Margin-Left' = '3px'
                'Top' = '45%'
                'Height' = '130px'
                'Width' = '130px'                                
                'Position' = 'Absolute'
            }
    } else {
        ""
    }

$nextPageButton = 
    if ($pageNumber -lt ($chapterPageCount)) {
        Write-Link -Style @{"Font-Size" ="3em"} -Url "$safeBookName.$($chapterNumber).$([int]$pageNumber + 1).aspx" -Caption "<span class='ui-icon ui-icon-arrowthickstop-1-e' style='font-size:x-large'>&nbsp;</span>" -Button |
            New-Region -LayerID NextPageButtonContainer -Style @{
                'Margin-Left' = '3px'
                'Top' = '45%'
                'Height' = '130px'
                'Width' = '130px'
                'Right' = '0px'
                'Position' = 'Absolute'
            }
    } else {
        ""
    }
                                     
                                     
$pageNumberSection =
    $pageNumber | 
    New-Region -Style @{
        'Right' = '10px'
        'Bottom' = '10px'
        'font-size' = 'medium'
        'position' = 'absolute'
    }
                                         
                        
$titleSection, $lastpageButton, $pageContentSection, $nextPageButton,$pageNumberSection |
    New-WebPage  -Title $pageName
                
                    }
                    $NewPages["$SafeBookName.${ChapterNumber}.${PageNumber}.pspage"] = "<| $webPage |>"
                    $pageNumber++
                
                }            
                
                # Make chapter page
                $chapterPage = @"
`$chapterNumber = '$chapterNumber'
`$safeBookName = '$safeBookName'


`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$longPageName = "$($Book.Name) | Chapter $chapterNumber $(if ($chapter.Name) { "- " + $chapter.Name })"
`$chapterPageCount = $(@($chapter.pages).Count)

"@ + {
    $centerWidth  = 100 - ([Double]$lMargin.Replace("%", "") + [Double]$lMargin.Replace("%", ""))
$bn, $cn = $longPageName -split "\|"
$chapterPageContent = @"
<div style='margin-left:auto;margin-right:auto' id='TitleArea'>
<p>
<a href='$SafeBookName.aspx'>$bn</a>
<p/>
<p style='text-indent:5px;font-size:medium'>
<a href='$SafeBookName.$ChapterNumber.aspx'>$cn</a>
</p>
<hr/>
</div>
"@
$chapterPageContent += "<div style='text-align:center;margin-left:$($centerWidth/4)%;margin-right:$($centerWidth/4)%'>"
$chapterPageContent += @"
    <style>
	#feedback { font-size: 1.4em; }
	#pages .ui-selecting { background: #FECA40; }
	#pages .ui-selected { background: #F39814; color: white; }
	#pages { list-style-type: none; margin: 0; padding: 0; }
	#pages li { margin: 3px; padding: 1px; float: left; width: 50px; height: 50px; font-size: 2em; text-align: center; }
	</style>
	<script>
	`$(function() {
		`$( "#pages" ).selectable({
            selected: function(event, ui) { 
                window.location = ("$SafeBookName.$ChapterNumber." + ui.selected.innerText.replace(' ','') + ".aspx") 
            } 
        });
	});
	</script>
"@
$chapterPageContent += "<ol id='pages'>"
$chapterPageContent += 
    foreach ($n in 1..$ChapterPageCount) {
    "
	<li class=`"ui-state-default`">$n</li>
    "
}
$chapterPageContent += "</ol>"
$chapterPageContent += "</div>"
$chapterPageContent | 
    New-Region -LayerID Page -Style @{
        'Margin-Left' = $lMargin
        'Margin-Right' = $rMargin
        'Position' = 'absolute'
        'Margin-Top' = '1%'
        'font-size' = 'large'        
        'Width' = "${centerWidth}%"
    } |
    New-WebPage -Title $longPageNAme 

}
            
                $newPages["$safeBookName.${ChapterNumber}.pspage"]= "<| $chapterPage |>"
                $chapterNumber++
            }            
            
            
            $bookPage = @"
`$safeBookName = '$safeBookName'

`$lMargin = '$marginPercentLeftString'
`$rMargin = '$marginPercentRightString'
`$bookName = '$($Book.Name)'
`$longPageName = "$($Book.Name)"
`$chapterCount = $(@($book.Chapters).Count)

"@ + {
    $centerWidth  = 100 - ([Double]$lMargin.Replace("%", "") + [Double]$lMargin.Replace("%", ""))
$bn  = $longPageName
$PageContent = @"
<div style='margin-left:auto;margin-right:auto' id='TitleArea'>
<p>
<a href='$SafeBookName.aspx'>$bn</a>
<p/>
<hr/>
</div>
"@
$PageContent  += "<div style='text-align:center;margin-left:$($centerWidth/4)%;margin-right:$($centerWidth/4)%'>"

$book = $pipeworksManifest.Bookshelf.Books | Where-Object { $_.Name -eq $bookName } 

$chapterNum = 1
$PageContent  += 
    foreach ($chapter in $book.Chapters) {
        $h  = "<br/>"
        $h += Write-Link -Caption $chapter.Name -Url "$SafeBookName.$chapterNum.1.aspx" -Style @{"Width"="100%"} -button    
        $h += "<br/>"
        $h
        $chapteRNum++
    }

$PageContent  += "</div>"
$PageContent  | 
    New-Region -LayerID Page -Style @{
        'Margin-Left' = $lMargin
        'Margin-Right' = $rMargin
        'Position' = 'absolute'
        'Margin-Top' = '1%'
        'font-size' = 'large'        
        'Width' = "${centerWidth}%"
    } |
    New-WebPage -Title $longPageNAme 

}
            # Make book page
            if (-not ($newPages["Default.pspage"])) {
                $newPages["Default.pspage"] = "<| $bookPage |>"
            }
            $NewPages["$SafeBookName.pspage"] = "<| $bookPage |>"
        }                
                
    }
    end {
        $NewPages
    }
} 

 
 
