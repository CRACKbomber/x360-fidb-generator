param(
    [string]$SevenZipPath,
    [string]$Python3Path,
    [string]$SDKPath = "$PSScriptRoot\sdks",
    [string]$LibPath = "$PSScriptRoot\libs",
    [string]$LibraryProvider = "*",
    [string]$GoobyPyPath = "$PSScriptRoot\Xbox-360-Crypto"
)

function Extract-Lib([string]$FilePath, [string]$OutputPath) {
    return Start-Process -FilePath 7z -ArgumentList("x `"$FilePath`"", "-o`"$OutputPath`"", "-y") -Wait -PassThru -NoNewWindow
}

function Extract-Pack([string]$FilePath, [string]$OutputPath) {
    $ExtractScript = Join-Path $GoobyPyPath "xdk_extract.py"
    # xdk setup --> data_X.cab
    Start-Process -FilePath py -ArgumentList ("`"$ExtractScript`"", "$FilePath", "`"$OutputPath`"") -Wait -PassThru -NoNewWindow
    # data_X.cab --> exploded cab. en-US is always low index so other locales are discarded (oh well)
    Resolve-Path (Join-Path $OutputPath "*.cab") | ForEach-Object {
        Start-Process -FilePath 7z -ArgumentList("x `"$_`"", "-o`"$OutputPath`"", "-y") -Wait -PassThru -NoNewWindow
    }
}

$env:Path += ";$SevenZipPath"

if($Python3Path) {
    $env:Path += ";$Python3Path"
}

if(-not(Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Error "'py' was not found. Python 3.8+ required"
    return -1
}

if(-not(Get-Command 7z -ErrorAction SilentlyContinue)) {
        Write-Error "'7z' was not found. 7-Zip required"
    return -1
}

# Get SDK exe files matching the pattern and library provider pattern
$ExecutablePattern = "XDKSetupXenon(.*)\.exe"
$SDKExes = Get-ChildItem -Path $SDKPath -Filter "*.exe" | Where-Object { 
                $_.Name -match $ExecutablePattern -and $_.Name -like $LibraryProvider 
            }

Write-Host "Found $($SDKExes.Count) SDK file(s)"

foreach ($SDKExe in $SDKExes) {
    try {
        Write-Host "`nProcessing: $($SDKExe.Name)"
        $ProviderName = [System.IO.Path]::GetFileNameWithoutExtension($SDKExe.Name)
        $SDKVersion = $SDKExe.Name -replace "XDKSetupXenon", "" -replace "\.exe$", "" -replace "_", "." -replace "-", "."
        # Create temporary extraction directory
        $TempDir = Join-Path $SDKPath "XDKExtract_$(Get-Random)"
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

        # Extract SDK exe to temp path
        Extract-Pack -FilePath $SDKExe.FullName -OutputPath $TempDir
        
        # extract libs
        $LibSourcePath = Join-Path $TempDir "xdk\lib\xbox"

        Get-ChildItem -Path $LibSourcePath -Filter "*.lib" | ForEach-Object {
            $LibFileName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $ObjDestPath = "$LibPath\$ProviderName\$LibFileName\$SDKVersion\ppc64"
            $LibDestPath = "$ObjDestPath\lib"
            $LibExtractResult = Extract-Lib -FilePath $_ -OutputPath $LibDestPath
            if ($LibExtractResult.ExitCode -ne 0) {
                Write-Error "Failed to extract library '$($_.Name)' from '$LibSourcePath'. Exit code: $($LibExtractResult.ExitCode)"
                continue
            }
            
            # Move from extracted dir to the proper dir
            Get-ChildItem $LibDestPath -Recurse -Include *.obj | `
                ForEach-Object { Move-Item -Path $_ -Destination $ObjDestPath }
            
            # Clean up the reamining directories and files from the lib expansion
            Remove-Item -Path $LibDestPath -Recurse -Force
            Write-Host "Extracted library '$($_.Name)' to '$LibDestPath'"
        }
    }
    catch {
        Write-Error "An error occurred while processing '$($SDKExe.Name)': $_"
    }
    finally {
        # Clean up temporary directory
        if (Test-Path $TempDir) {
            Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
