param(
    [Parameter(Mandatory=$true)]
    [string]$SevenZipPath,
    [string]$SDKPath = "$PSScriptRoot\sdks",
    [string]$LibPath = "$PSScriptRoot\libs",
)

function Extract-Pack([string]$FilePath, [string]$OutputPath) {
    return Start-Process -FilePath $SevenZipPath -ArgumentList("x `"$FilePath`"", "-o`"$OutputPath`"", "-y") -Wait -PassThru -NoNewWindow
}

# Get SDK exe files matching the pattern
$SDKExes = Get-ChildItem -Path $SDKPath -Filter "*.exe" | Where-Object { $_.Name -match "XDKSetupXenon(.*)\.exe" }

Write-Host "Found $($SDKExes.Count) SDK file(s)"

foreach ($SDKExe in $SDKExes) {
    try {
        Write-Host "`nProcessing: $($SDKExe.Name)"
        $ProviderName = [System.IO.Path]::GetFileNameWithoutExtension($SDKExe.Name)
        $SDKVersion = $SDKExe.Name -replace "XDKSetupXenon", "" -replace "\.exe$", "" -replace "_", "." -replace "-", "."
        # Create temporary extraction directory
        $TempDir = Join-Path $env:TEMP "XDKExtract_$(Get-Random)"
        New-Item -ItemType Directory -Path $TempDir -Force | Out-Null

        # Extract SDK exe to temp path
        Extract-Pack -FilePath $SDKExe.FullName -OutputPath $TempDir
        
        # extract libs
        $LibSourcePath = Join-Path $TempDir "xdk\lib\xbox"

        Get-ChildItem -Path $LibSourcePath -Filter "*.lib" | ForEach-Object {
            $LibFileName = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
            $ObjDestPath = "$LibPath\$ProviderName\$LibFileName\$SDKVersion\ppc64"
            $LibDestPath = "$ObjDestPath\lib"
            $LibExtractResult = Extract-Pack -FilePath $_ -OutputPath $LibDestPath
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
