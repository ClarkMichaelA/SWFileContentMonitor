function Search-FileContentForSolarWinds {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 0)]
        [string]
        $FolderPath,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 1)]
        [string]
        $FileNameRegularExpression,

        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true,
            Position = 2)]
        [string]
        $ContentRegularExpression,

        [Parameter(Mandatory = $false,
            ValueFromPipelineByPropertyName = $true,
            Position = 3)]
        [string]
        $StatisticsFileDirectory = (Join-Path $env:temp "SolarWindsFileContentMonitor")
    )    

    process {
        Write-Verbose "Statistics files will be written to $StatisticsFileDirectory";

        # Make sure the TempFileDirectory exists
        if ((Test-Path $StatisticsFileDirectory) -eq $false) {
            New-Item -Path $StatisticsFileDirectory -ItemType Directory -ErrorAction Stop | Out-Null;
        }

        $StatisticsExtension = ".stats";

        # Find all files that match the filename pattern
        $MatchingFiles = Get-ChildItem -Path $FolderPath -ErrorAction SilentlyContinue | Where-Object -FilterScript {$_.Name -match $FileNameRegularExpression} -ErrorAction Stop;        

        # Sort based on last date - makes the output later in the script reflect the name of the newest file (which is usually what is wanted)
        $MatchingFiles = $MatchingFiles | Sort-Object LastWriteTime; 

        # If no matching files, just end
        Write-Host "Statistic.MatchingFiles: $(@($MatchingFiles).Count)";
        Write-Host "Message.MatchingFiles: $(@($MatchingFiles).Count) matching files found in $FolderPath"; 

        if ((@($MatchingFiles).Count -gt 0) -eq $false) {
            return 0;
        }

        # Setup variables for looping through monitored files and collecting totals
        $TotalNewRows = 0;
        $LastOccurenceFileName = "";
        $LastOccurenceLineNumber = 0;
        $LastOccurenceLine = "";

        # For each monitored file
        foreach ($MonitoredFile in $MatchingFiles) {
            # Find a matching ScriptRun file in the temp directory
            $StatsFile = Join-Path $StatisticsFileDirectory ($MonitoredFile.Name + $StatisticsExtension);

            # Stats variable
            $Stats = @{
                FileSize = $null;
                LastModifiedDateUtcTicks = $null;
                RowCount = 0;
            }

            # If not present create one; otherwise attempt to read it
            if ((Test-Path $StatsFile) -eq $false) {
                Write-Verbose "Creating $StatsFile";
                $Stats | ConvertTo-Json | Out-File $StatsFile -ErrorAction Stop;
            } else {
                Write-Verbose "Reading $StatsFile";
                $Stats = Get-Content $StatsFile -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop;
            }

            # With file present, determine if you need to exhaust resources searching
            $ShouldSearch = $false;

            # Convert to UTC and get the ticks.  Had a lot of trouble with JSON conversion to/from DateTime simplifying the time.
            if ($MonitoredFile.LastWriteTimeUtc.Ticks -ne $Stats.LastModifiedDateUtcTicks) {
                $ShouldSearch = $true;
            } elseif ($MonitoredFile.Length -ne $Stats.FileSize) {
                $ShouldSearch = $true;
            }

            if ($ShouldSearch) {
                Write-Verbose "$($MonitoredFile.Name) has changed and will be searched.";

                # File has changed, so search it
                $MatchingRows = $MonitoredFile | Select-String -Pattern $ContentRegularExpression;
                $RowCount = $MatchingRows.Count;

                # See if the RowCount matches what is recorded in the Stats file
                if ($RowCount -ne $Stats.RowCount) {
                    $NewRows = $RowCount - $Stats.RowCount;
                    $MatchingRow = $MatchingRows | Select-Object -Last 1;
                    
                    Write-Verbose "$($MonitoredFile.Name) has $NewRows occurrences";
                    
                    $TotalNewRows = $TotalNewRows + $NewRows;
                    $LastOccurenceFileName = $MonitoredFile.Name;
                    $LastOccurenceLineNumber = $MatchingRow.LineNumber;
                    $LastOccurenceLine = $MatchingRow.Line;
                }

                # Update stats file
                Write-Verbose "Updating $StatsFile";
                $Stats = @{
                    FileSize = $MonitoredFile.Length;
                    LastModifiedDateUtcTicks = $MonitoredFile.LastWriteTimeUtc.Ticks;
                    RowCount = $RowCount;
                }
                $Stats | ConvertTo-Json | Out-File $StatsFile -ErrorAction Stop;
            }
        }

        if ($TotalNewRows -gt 0) {
            Write-Host "Statistic.NewMatches: $TotalNewRows";
            Write-Host "Message.NewMatches: Last occurence appears to be found in $LastOccurenceFileName on line $LastOccurenceLineNumber '$LastOccurenceLine'";
        } else {
            Write-Host "Statistic.NewMatches: 0";
            Write-Host "Message.NewMatches: No new matches found since last occurrence."; 
        }
    }
}

Search-FileContentForSolarWinds -FolderPath 'C:\Program Files (x86)\SomeLogDirectory' -FileNameRegularExpression "log" -ContentRegularExpression "error";