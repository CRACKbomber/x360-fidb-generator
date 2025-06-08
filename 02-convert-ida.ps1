param(
    [Parameter(Mandatory = $true)]
    [string]$IDAPath,
    [string]$LibraryPath = "$PSScriptRoot\libs",
    [string]$ExtractIDAXMLScript = "$PSScriptRoot\ida_scripts\extract_xml_ghidra.py",
    [int]$ConcurrentJobs = 4
)

# Define the script block that will run in each runspace
$ProcessScript = {
    param($ObjPath, $IDAPath, $ExtractIDAXMLScript, $LogsPath)
    
    function Process-ObjFile([Parameter(Mandatory = $true)][string]$ObjPath) {
        # preprocess obj into idb
        if (-not(Test-Path -Path "$ObjPath.idb" -ErrorAction SilentlyContinue)) {
            $IDAProcess = Start-Process -FilePath $IDAPath -NoNewWindow -Wait -ArgumentList ("-B", $ObjPath) -PassThru
            if (-not($IDAProcess -and $IDAProcess.ExitCode -eq 0)) {
                return @{
                    Success = $false
                    File    = $ObjPath
                    Error   = "IDA Pro failed to analyze $ObjPath"
                }
            } 
        }
        
        # extract XML... in a very shit way... Ghidra XMLExporter doesn't exactly work in batch mode
        if (-not(Test-Path -Path "$ObjPath.xml" -ErrorAction SilentlyContinue) -and -not(Test-Path -Path "$ObjPath.bytes")) {
            $XMLDumpProc = Start-Process -FilePath $IDAPath -PassThru -WindowStyle Hidden `
                -ArgumentList ("-A", "-S`"$ExtractIDAXMLScript`"", $ObjPath)
            while ($XMLDumpProc.HasExited -eq $false) {
                if ($XMLDumpProc.MainWindowHandle -eq 0) {
                    Start-Sleep -Seconds 1
                    continue
                } 
                else {
                    Start-Sleep -Seconds 1
                    $XMLDumpProc.CloseMainWindow() | Out-Null
                }
            }
            
            # Clean up from that app homocide
            @(
                "$ObjPath.idb", 
                "$ObjPath.id0",
                "$ObjPath.id1",
                "$ObjPath.id2",
                "$ObjPath.id3",
                "$ObjPath.id4",
                "$ObjPath.nam",
                "$ObjPath.til",
                "$ObjPath.asm"
                "$ObjPath"
            ) | ForEach-Object { Remove-Item -Path $_ -ErrorAction SilentlyContinue -Force }
        }
        
        return @{
            Success = $true
            File    = $ObjPath
            Error   = $null
        }
    }
    
    try {
        Process-ObjFile -ObjPath $ObjPath
    }
    catch {
        @{
            Success = $false
            File    = $ObjPath
            Error   = $_.Exception.Message
        }
    }
}

# Get all OBJ files
Write-Host "Scanning for OBJ files in $LibraryPath..." -ForegroundColor Cyan
$ObjFiles = Get-ChildItem -Path $LibraryPath -Recurse -Filter "*.obj"
$TotalFiles = $ObjFiles.Count
Write-Host "Found $TotalFiles OBJ files to process" -ForegroundColor Green
Write-Host "Using $ConcurrentJobs concurrent jobs" -ForegroundColor Green

if ($TotalFiles -eq 0) {
    Write-Warning "No OBJ files found in $LibraryPath"
    exit 0
}

# Create runspace pool
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $ConcurrentJobs)
$RunspacePool.Open()

# Create collections for job management
$Jobs = New-Object System.Collections.ArrayList
$CompletedCount = 0
$FailedFiles = New-Object System.Collections.ArrayList
$FileQueue = New-Object System.Collections.Queue
$ObjFiles | ForEach-Object { $FileQueue.Enqueue($_) }

# Start initial jobs
while ($Jobs.Count -lt $ConcurrentJobs -and $FileQueue.Count -gt 0) {
    $File = $FileQueue.Dequeue()
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    $PowerShell.AddScript($ProcessScript).AddArgument($File.FullName).AddArgument($IDAPath).AddArgument($ExtractIDAXMLScript).AddArgument("$PSScriptRoot\logs") | Out-Null
    
    $Job = @{
        PowerShell = $PowerShell
        Handle     = $PowerShell.BeginInvoke()
        File       = $File
    }
    $Jobs.Add($Job) | Out-Null
}

# Process jobs
$StartTime = Get-Date
while ($Jobs.Count -gt 0) {
    # Check for completed jobs
    $CompletedJobs = $Jobs | Where-Object { $_.Handle.IsCompleted }
    
    foreach ($Job in $CompletedJobs) {
        # Get results
        try {
            $Result = $Job.PowerShell.EndInvoke($Job.Handle)
            $CompletedCount++
            
            if ($Result -and -not $Result.Success) {
                $FailedFiles.Add($Result) | Out-Null
                Write-Warning "Failed: $($Result.File) - $($Result.Error)"
            }
            else {
                Write-Host "Completed: $($Job.File)" -ForegroundColor Green
            }
        }
        catch {
            $CompletedCount++
            $FailedFiles.Add(@{
                    File  = $Job.File.FullName
                    Error = $_.Exception.Message
                }) | Out-Null
            Write-Warning "Failed: $($Job.File.Name) - $($_.Exception.Message)"
        }
        finally {
            # Clean up
            $Job.PowerShell.Dispose()
            $Jobs.Remove($Job)
        }
        
        # Start new job if queue has items
        if ($FileQueue.Count -gt 0) {
            $File = $FileQueue.Dequeue()
            $PowerShell = [powershell]::Create()
            $PowerShell.RunspacePool = $RunspacePool
            $PowerShell.AddScript($ProcessScript).AddArgument($File.FullName).AddArgument($IDAPath).AddArgument($ExtractIDAXMLScript).AddArgument("$PSScriptRoot\logs") | Out-Null
            
            $NewJob = @{
                PowerShell = $PowerShell
                Handle     = $PowerShell.BeginInvoke()
                File       = $File
            }
            $Jobs.Add($NewJob) | Out-Null
        }
    }
    
    # Update progress
    $PercentComplete = ($CompletedCount / $TotalFiles) * 100
    $ElapsedTime = (Get-Date) - $StartTime
    $EstimatedTotalTime = if ($CompletedCount -gt 0) { 
        [TimeSpan]::FromSeconds($ElapsedTime.TotalSeconds * $TotalFiles / $CompletedCount) 
    }
    else { 
        [TimeSpan]::Zero 
    }
    $RemainingTime = $EstimatedTotalTime - $ElapsedTime
    
    Write-Progress -Activity "Processing OBJ Files" `
        -Status "Completed: $CompletedCount of $TotalFiles | Active Jobs: $($Jobs.Count)" `
        -PercentComplete $PercentComplete `
        -CurrentOperation "Elapsed: $($ElapsedTime.ToString('hh\:mm\:ss')) | Remaining: $($RemainingTime.ToString('hh\:mm\:ss'))"
    
    # Brief pause to prevent CPU spinning
    Start-Sleep -Milliseconds 100
}

# Clean up
$RunspacePool.Close()
$RunspacePool.Dispose()
Write-Progress -Activity "Processing OBJ Files" -Completed

# Summary
$EndTime = Get-Date
$TotalTime = $EndTime - $StartTime
Write-Host "`nProcessing completed!" -ForegroundColor Green
Write-Host "Total files processed: $TotalFiles" -ForegroundColor Cyan
Write-Host "Successful: $($TotalFiles - $FailedFiles.Count)" -ForegroundColor Green
Write-Host "Failed: $($FailedFiles.Count)" -ForegroundColor $(if ($FailedFiles.Count -gt 0) { "Red" } else { "Green" })
Write-Host "Total time: $($TotalTime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host "Average time per file: $([Math]::Round($TotalTime.TotalSeconds / $TotalFiles, 2)) seconds" -ForegroundColor Cyan

# Report failed files if any
if ($FailedFiles.Count -gt 0) {
    Write-Host "`nFailed files:" -ForegroundColor Red
    $FailedFiles | ForEach-Object { 
        Write-Host "  - $($_.File): $($_.Error)" -ForegroundColor Yellow 
    }
}
