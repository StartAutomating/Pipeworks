function Get-FTP
{
    <#
    .Synopsis
        Gets files from FTP
    .Description
        Lists files on an FTP server, or downloads files
    .Example
        Get-FTP -FTP "ftp://edgar.sec.gov/edgar/full-index/1999/" -Download -Filter "*.idx", "*.xml"
    .Example
        Get-FTP -FTP "ftp://edgar.sec.gov/edgar/full-index/1999/" -Download -Filter "*.idx", "*.xml"  -DownloadAsJob
    .Link
        Push-FTP
    #>
    [OutputType([IO.FileInfo])]
    [CmdletBinding(DefaultParameterSetName='FTPSite')]
    param(
    # The root url of an FTP server
    [Parameter(Mandatory=$true,Position=0,ValueFromPipelineByPropertyName=$true,ParameterSetName='FTPSite')]
    [Alias('FTP')]
    [Uri]$FtpRoot,

    # A list of specific files on an FTP server.  Useful for when dealing with FTP servers that do not allow listing.
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true,ParameterSetName='FTPFile')]
    [Uri[]]
    $FtpFile,

    # The credential used to connect to FTP.  If not provided, will connect anonymously.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Management.Automation.PSCredential]
    $Credential,

    # If set, will download files instead of discover them
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='FTPSite')]
    [Switch]$Download,

    # The download path (by default, the downloads directory)
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]$DownloadPath = "$env:UserProfile\Downloads",

    # If provided, will only download files that match the filter
    [Parameter(ValueFromPipelineByPropertyName=$true,Position=1,ParameterSetName='FTPSite')]
    [string[]]$Filter,

    # If set, will download files that already have been downloaded and have the exact same file size.
    [Parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName='FTPSite')]
    [Switch]$Force,

    # If set, downloads will run as a background job
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $DownloadAsJob,

    # If set, downloads will be run in parallel in a PowerShell workflow
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $UseWorkflow,

    # If set, download progress will not be displayed
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [Switch]
    $HideProgress,

    # The size of the copy buffer.  By default, this is 50kb
    [Uint32]
    $BufferSize = 50kb


    )

    begin {
       
        $folders = New-Object "system.collections.generic.queue[string]"
        $files= New-Object "system.collections.generic.queue[string]"
       
        $GetFtpStream = {
            param($url, $method, $Credential)
            try {
               
                $ftpRequest = [System.Net.FtpWebRequest]::Create($url)
                if ($Credential)  {
                    $ftpRequest.Credentials = $Credential.GetNetworkCredential()
                }
                $ftpRequest.Method = $method
                $ftpresponse = $ftpRequest.GetResponse()
                $reader = New-Object IO.StreamReader $ftpresponse.GetResponseStream()

                while (($line = $reader.ReadLine()) -ne $null) {
                    $line.Trim()
                }
                if ($reader) {
                    $reader.Dispose()
                }
               
                if ($ftpresponse.Close) {
                    $ftpresponse.Close()
                }
            } catch {
                $err = $_
                Write-Error -Exception $err.Exception -Message "Error in FTP $method Request on $url"
                return
            } finally {
            }
           
        }

        $GetFtpFile = {
           
            param($Source,$Target,$Credential, $HideProgress, $BufferSize)
            try {
           
            $FileSize =
                try {
                    $ftprequest = [Net.FtpWebRequest]::create($Source)
                    if ($Credential) {
                        $ftprequest.Credentials = $Credential.GetNetworkCredential()
                    }
                    $ftprequest.Method = [Net.WebRequestMethods+Ftp]::GetFileSize
                    $ftpresponse = $ftprequest.GetResponse()
                    $ftpresponse.ContentLength
                    if ($ftpresponse.Close) {
                        $ftpresponse.Close()
                    }
                } catch {

                }

           
 
            $ftprequest = [Net.FtpWebRequest]::create($Source)
            if ($Credential) {
                $ftprequest.Credentials = $Credential.GetNetworkCredential()
            }
            $ftprequest.Method = [Net.WebRequestMethods+Ftp]::DownloadFile
            $ftprequest.UseBinary = $true
            $ftprequest.KeepAlive = $false
      

            $ftpresponse = $ftprequest.GetResponse()

            $responsestream = $ftpresponse.GetResponseStream()
            if (-not $responsestream) { return  }
      
            $targetfile = New-Object IO.FileStream ($Target,[IO.FileMode]::Create)
            [byte[]]$readbuffer = New-Object byte[] $BufferSize
      
 
            $perc = 0
            $progressId = Get-Random
            do{
                $readlength = $responsestream.Read($readbuffer,0,$BufferSize)

               
                $targetfile.Write($readbuffer,0,$readlength)
                if ($FileSize) {
                    if (-not $HideProgress) {
                        $perc = $targetfile.Position * 100 / $FileSize
                        Write-Progress "Downloading $Source" "To $Target" -PercentComplete $perc -Id $progressId
                    }
                } else {
                    if (-not $HideProgress) {
                        $perc += 5
                        if ($perc -gt 100) { $perc = 0 }
                        Write-Progress "Downloading $Source" "To $Target" -PercentComplete $perc -Id $progressId
                    }
                }
            } while ($readlength -ne 0)

     
            $targetfile.close()

            if ($ftpresponse.Close) {
                $ftpresponse.Close()
            }
            Write-Progress "Downloading $Source" "To $Target" -Completed -Id $progressId

            Get-Item -Path $target

            } catch {
                $err = $_
                Write-Error -Exception $err.Exception -Message "FTP Error Downloading $source - $($err.Exception.Message)"
                return
            }           
        }                       
 
        $jobDefintion = [ScriptBlock]::Create(@"
param([Hashtable]`$Parameter)
`$getFtpFile = { $GetFtpFile }

& `$getFtpFile @parameter
"@)


        $workflowDefinition = @"
workflow getFtpFilesWorkflow(
    [Parameter(Position=0)]
    [Hashtable[]]`$ftpFileInput
    ) {
    foreach -parallel (`$ftpFile in `$ftpFileInput) {
        `$ftpFile | 
            inlineScript {
                `$parameter = `$(`$input)
                & { $GetFtpFile } @parameter 
            
            }
    }
}
"@

        . ([ScriptBlock]::create($workflowDefinition))

        $Ftpjobs = @()
       $AsyncDownloadPaths = @()
    }
    process {
       
        if ($PSCmdlet.ParameterSetName -eq 'FTPSite') {
            $null = $folders.Enqueue("$ftpRoot")
        } elseif ($PSCmdlet.ParameterSetName -eq 'FTPFile') {
            foreach ($f in $FtpFile) {
                $null = $files.Enqueue("$f")
            }
        }
       
        
    }

    end {
        $workFlowInputData = @()
        while($folders.Count -gt 0 -or
              $RunningFtpjobs.Count -gt 0 -or
              $files.Count -gt 0){

            if ($PSCmdlet.ParameterSetName -eq 'FTPSite' -and $folders.Count) {
               
                $fld = $folders.Dequeue()
       
                $newFiles = New-Object "system.collections.generic.list[string]"
                $newDirs = New-Object "system.collections.generic.list[string]"
                $operation = [System.Net.WebRequestMethods+Ftp]::ListDirectory
       
                foreach ($line in . $GetFtpStream $fld $operation $Credential 2>&1) {
                    if ($line -is [Management.Automation.ErrorRecord]) {
                        $line | Write-Error
                    } else {
                        [void]$newFiles.Add($line.Trim())
                    }
                }
                                                                   
                $operation = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
                foreach ($line in . $GetFtpStream $fld $operation $Credential 2>&1) {
                    if ($line -is [Management.Automation.ErrorRecord]) {
                        $line | Write-Error
                    } else {
                        [void]$newDirs.Add($line.Trim())
                    }
                   
                }
                   
                
                foreach ($d in $newDirs) {
                    $parts = @($d -split " " -ne '')




                    if ($parts.Count -eq 2) {
                        # First line, purely informational
                        continue
                    }


                    if ($parts.Count -eq 9) {
                        # 9 parts.  It's likely that this is a linux based FTP
                        # The last part should be the file name
                        # The preceeding 3 parts should be the modification time
                        # The preceeding 1 part should be the file size
                        if ($parts[-1] -eq '.' -or $parts[-1] -eq '..') {
                            continue
                        }
                        
                        $FileName = $parts[-1]
                        $FileSize = $parts[-5]
                        $FileDate = ((@($parts[-4..-3]) + (Get-Date).Year +  $parts[-2]) -join ' ') -as [datetime]
                                                


                        
                    } elseif ($parts.Count -eq 4) {
                        # First two parts should be date
                        # Third part should be file length
                        # Last part should be file name

                        $FileName= $parts[-1]
                        $FileSize = $parts[-2]
                        $FileDate = ($parts[0..1] -join ' ') -as [DateTime]
                    }


                    if (-not $FileName) {continue } 

                    if ($FileSize -eq 4096 -or -not $FileSize) {
                        $newName = $parts[-1]
                        Write-Verbose "Enqueing Folder $($fld + $FileName + "/")"
                        $null = $folders.Enqueue($fld + $FileName  + "/")
                    }


                    $out =
                        New-Object PSObject -Property @{
                            Ftp = $fld + "/" + $FileName
                            Size = $FileSize
                            UpdatedAt = $FileDate
                        }

                    if ($filter) {
                        $matched = $false
                        foreach ($f in $filter) {
                            if ($FileName -like "$f") {
                                $matched  = $true
                                break
                            }
                        }
                        if (-not $matched) {
                            continue
                        }
                    }
                    if ($download -or $psBoundParameters.DownloadPath) {
                       
                            $folderUri = [uri]("$fld".TrimEnd("/") + "/" + $FileName)
                       
                            $downloadTo = Join-Path $DownloadPath $folderUri.LocalPath
                            $downloadDir  = Split-Path $downloadTo
                            if (-not (Test-Path $downloadDir)) {
                                $null = New-Item -ItemType Directory $downloadDir
                            }

                            $item = Get-Item -Path $downloadTo -ErrorAction SilentlyContinue
                            if (($item.Length -ne $FileSize) -or $Force) {
                                if ($DownloadAsJob) {
                                   
                                
                                    $ftpJobs += Start-Job -ArgumentList @{
                                        Source =$folderUri
                                        Target = $downloadTo
                                        Credential = $Credential
                                        HideProgress = $HideProgress
                                        BufferSize = $BufferSize
                                    } -ScriptBlock $jobDefintion
                                } elseif ($UseWorkflow) {
                                    $workFlowInputData += @{
                                        Source =$folderUri
                                        Target = $downloadTo
                                        Credential = $Credential
                                        HideProgress = $HideProgress
                                        BufferSize = $BufferSize

                                    }
                                
                                } else {
                                    & $GetFtpFile -Source $folderUri -Target $downloadTo -Credential:$Credential -BufferSize $BufferSize -HideProgress:$HideProgress
                                }
                           
                            }
                           
                        
                        } else {

                        $out
                    }

                   
                                       
                                   
                }

               
            } elseif ($PSCmdlet.ParameterSetName  -eq 'FTPFile' -and $files.Count) {
                $file= $files.Dequeue()
                $folderUri  =[URI]$file
                $downloadTo = Join-Path $DownloadPath $folderUri.LocalPath
                $downloadDir  = Split-Path $downloadTo
                if (-not (Test-Path $downloadDir)) {
                    $null = New-Item -ItemType Directory $downloadDir
                }

 
                if ($DownloadAsJob) {                                                   
                    $ftpJobs += Start-Job -ArgumentList @{
                        Source =$folderUri
                        Target = $downloadTo
                        Credential = $Credential
                        HideProgress = $HideProgress
                        BufferSize = $BufferSize

                    } -ScriptBlock $jobDefintion
                } elseif ($UseWorkflow) {
                    $workFlowInputData += @{
                        Source =$folderUri
                        Target = $downloadTo
                        Credential = $Credential
                        HideProgress = $HideProgress
                        BufferSize = $BufferSize

                    }
                } else {
                   
                    $FileResults = & $GetFtpFile -Source $folderUri -Target $downloadTo -Credential:$Credential -BufferSize $BufferSize -HideProgress:$HideProgress 2>&1
                    if ($FileResults -is [Management.Automation.ErrorRecord]) {
                        $FileResults | Write-Error
                    } else {
                        $FileResults
                    }
                   
                }
             
            }
            
            if ($Ftpjobs) {
                $Ftpjobs | Receive-Job                               
                $RunningFtpjobs = @($Ftpjobs | Where-Object { $_.JobStateInfo.State -ne 'Completed' })               
            }
        }

        while ($workFlowInputData.Count -or $RunningFtpjobs) {
            if ($workFlowInputData) {
                $Ftpjobs += getFtpFilesWorkflow $workFlowInputData -asjob
            }
            $workFlowInputData = $null
            if ($Ftpjobs) {
                $Ftpjobs | Receive-Job                               
                $RunningFtpjobs = @($Ftpjobs | Where-Object { $_.JobStateInfo.State -ne 'Completed' })               
            }
        }

        if ($Ftpjobs) {
            $Ftpjobs | Receive-Job
            $Ftpjobs | Remove-Job
        }

 
    }
} 

