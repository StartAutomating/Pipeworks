#requires -Module PSSVG

$psChevron = Invoke-RestMethod https://pssvg.start-automating.com/Examples/PowerShellChevron.svg

$fontName = "Inter"

$TextSplat = [Ordered]@{
    Style="font-family:`"$fontName`", sans-serif"
    Class='foreground-fill'
    Fill="#4488ff"
    AlignmentBaseline='middle'
    FontSize=9
}

$PathFill = [Ordered]@{
    Fill = '#4488ff'
    Class = 'foreground-fill'
}
SVG -viewbox 100, 100 @(
    SVG.defs @(
        SVG.GoogleFont -FontName $fontName
    )

    $psChevron.svg.symbol.OuterXml
    # Top "pipe", top wall
    SVG.LinedPath -Start 0, 5 -End 90,5 |
        SVG.LinedPath -End 92.5, 7.5 |
        SVG.LinedPath -End 92.5, 82 |
        SVG.LinedPath -End 90, 82 |
        SVG.LinedPath -End 90, 7.5 |
        SVG.LinedPath -End 0, 7.5 @PathFill

    # Top "pipe", bottom wall
    SVG.LinedPath -Start 0, 15 -End 80,15 |
        SVG.LinedPath -End 82.5, 17.5 |        
        SVG.LinedPath -End 82.5, 82 |
        SVG.LinedPath -End 80, 82 |
        SVG.LinedPath -End 80, 17.5 |
        SVG.LinedPath -End 0, 17.5 @PathFill

    # Top "pipe", bottom jut
    SVG.rect -X 90% -Width 2.5% -Y 95.5% -Height 110% @PathFill
    SVG.rect -X 80% -Width 2.5% -Y 95.5% -Height 110% @PathFill

    # "Bottom" pipe, left jut
    SVG.rect -X -190% -Y 5% -Height 2.5% -Width 200% @PathFill
    SVG.rect -X -190% -Y 15% -Height 2.5% -Width 200% @PathFill

    # "Bottom" pipe, top wall
    SVG.LinedPath -Start 100, 85 -End 22.5,85 |
        SVG.LinedPath -End 20, 82.5 |                
        SVG.LinedPath -End 20, 18 |
        SVG.LinedPath -End 22.5, 18 |
        SVG.LinedPath -End 22.5, 82.5 |
        SVG.LinedPath -End 100, 82.5 @PathFill

    # "Bottom" pipe, bottom wall
    SVG.LinedPath -Start 100, 95 -End 12.5,95 |
        SVG.LinedPath -End 10, 92.5 |
        SVG.LinedPath -End 10, 18 |
        SVG.LinedPath -End 12.5, 18 |
        SVG.LinedPath -End 12.5, 92.5 |
        SVG.LinedPath -End 100, 92.5 @PathFill

    # "Bottom" pipe, top jut
    SVG.rect -X 20% -Width 2.5% -Y -195.5% -Height 200% @PathFill
    SVG.rect -X 10% -Width 2.5% -Y -195.5% -Height 200% @PathFill

    # "Bottom" pipe, right jut
    SVG.rect -X 90% -Y 82.5% -Height 2.5% -Width 200% @PathFill
    SVG.rect -X 90% -Y 92.5% -Height 2.5% -Width 200% @PathFill

    # SVG.text -X 49%  -Y 33.3% -TextAnchor 'middle' -Content "PowerShell" @textSplat

    SVG.text -X 48%  -Y 50% -TextAnchor 'middle' -Content "Pipeworks" @TextSplat
    
    SVG.use -Href '#psChevron' -Height 9% @PathFill -Y 45.5% -X 25% -Opacity .8
) -OutputPath (Join-Path $PSScriptRoot Assets | Join-Path -ChildPath "Pipeworks.svg")

