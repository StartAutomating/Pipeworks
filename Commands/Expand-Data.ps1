function Expand-Data
{
    <#
    .Synopsis
        Expands Compressed Data
    .Description
        Expands Compressed Data using the .NET GZipStream class
    .Link
        Compress-Data
    .Link
        http://msdn.microsoft.com/en-us/library/system.io.compression.gzipstream.aspx    

    .Example
        Compress-Data -String ("abc" * 1kb) | 
            Expand-Data  
    #>
    [CmdletBinding(DefaultParameterSetName='BinaryData')]
    [OutputType([string],[byte])]
    param(
    # The compressed data, as a Base64 string
    [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0,ParameterSetName='CompressedData')]
    [string]
    $CompressedData,
    
    # The compressed data, as a byte array
    [Parameter(ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true,Position=0,ParameterSetName='BinaryData')]
    [Byte[]]
    $BinaryData,
    
    # The type of data the decompressed object will be (a string or a byte array)
    [ValidateSet('String', 'Byte')]
    [string]
    $As = 'String'
    )   
       
    process {
        #region Open Data
        if ($psCmdlet.ParameterSetName -eq 'CompressedData') {
            try {
                $binaryData = [Convert]::FromBase64String($CompressedData)
            } catch {
                Write-Verbose "Unable to uncompress base 64 string"
                return
            }
        }
        
        $ms = New-Object System.IO.MemoryStream
        $ms.Write($binaryData, 0, $binaryData.Length)
        $ms.Seek(0,0) | Out-Null
        $cs = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]"Decompress")
        #endregion Open Data

        #region Compress And Render
        if ($as -eq 'string') {
            
            $sr = New-Object System.IO.StreamReader($cs, [Text.Encoding]::Unicode)
            $strOut = $sr.ReadToEnd()

            
            if ($strOut[0] -as [int] -ge 255) {
                # Handle compressed strings
                $ms.Seek(0,0) | Out-Null
                $cs = New-Object System.IO.Compression.GZipStream($ms, [IO.Compression.CompressionMode]"Decompress")
                $sr = New-Object System.IO.StreamReader($cs)
                $strOut = $sr.ReadToEnd()
                $strOut = $strOut.Replace([char]0, [char]32)
            }
            $strOut
        } else {
            $BufferSize = 1kb
            $buffer = New-Object Byte[] $BufferSize 
            $bytes =                 
                do {                                        
                    $bytesRead= $cs.Read($buffer, 0, $BufferSize )
                    $buffer[0..($bytesRead - 1)]
                    if ($bytesRead -lt $BufferSize ) {
                        break
                    }    
                } while ($bytesRead -eq $BufferSize )
            $bytes -as [byte[]]            
        }
        #endregion Compress And Render
    }    
}

