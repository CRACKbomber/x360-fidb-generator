param(
    [Parameter(Mandatory=$true)]
    [string]$GhidraPath,

    [string]$ProjectDir = "$PSScriptRoot\projects",
    [string]$FIDBDir = "$PSScriptRoot\fid_files",
    [string]$LogsDir = "$PSScriptRoot\logs",
    [string]$LanguageID = "PowerPC:BE:64:A2ALT-32addr"
)

# required directories
@(
    $LogsDir,
    $FIDBDir
) | ForEach-Object {
    if(-not (Test-Path $_ -ErrorAction SilentlyContinue)) {
        New-Item -Path $_ -ItemType Directory -Force | Out-Null
    }
}

foreach($LibProjectDir in (Get-ChildItem -Path $ProjectDir -Directory)) {
    $LibraryProvider = $LibProjectDir.Name
    $FIDBName = "$LibraryProvider.fidb".ToLower()
    $DbPropertiesFile = "$LibProjectDir\CreateMultipleLibraries.properties"
    $DuplicateSymbolsFile = ("$LogsDir\$LibraryProvider-duplicates.txt").Replace("$PSScriptRoot\", "") -replace "\\", "/"
    $CommonSymbolsFile = ("$LibProjectDir\common_symbols.txt").Replace("$PSScriptRoot\", "") -replace "\\", "/"
    $OutputFIDB = ("$FIDBDir\$FIDBName").Replace("$PSScriptRoot\", "") -replace "\\", "/"-replace "\\", "/"
    $GhidraHeadless = "$GhidraPath\support\analyzeHeadless.bat"
    $GhidraFIDScripts = "$GhidraPath\Ghidra\Features\FunctionID\ghidra_scripts"
    $GhidraScripts = "$GhidraFIDScripts;$PSScriptRoot\ghidra_scripts"

    # required files
    @(
        $DuplicateSymbolsFile,
        $CommonSymbolsFile,
        $DbPropertiesFile
    ) | ForEach-Object {
        if(-not (Test-Path $_ -ErrorAction SilentlyContinue)) {
            New-Item -Path $_ -ItemType File -Force | Out-Null
        }
    }

    if(Test-Path $OutputFIDB -ErrorAction SilentlyContinue) {
        Remove-Item -Path $OutputFIDB -Force -ErrorAction SilentlyContinue
    }

    # Create properties file
    "Duplicate Results File OK = $DuplicateSymbolsFile" | Out-File -FilePath $DbPropertiesFile
    "Do Duplication Detection Do you want to detect duplicates = true" | Out-File -FilePath $DbPropertiesFile -Append
    "Choose destination FidDB Please choose the destination FidDB for population = $FIDBName" | Out-File -FilePath $DbPropertiesFile -Append
    "Select root folder containing all libraries (at a depth of 3): = /$LibraryProvider/" | Out-File -FilePath $DbPropertiesFile -Append
    "Common symbols file (optional): OK = $CommonSymbolsFile" | Out-File -FilePath $DbPropertiesFile -Append
    "Enter LanguageID To Process Language ID: = $LanguageID" | Out-File -FilePath $DbPropertiesFile -Append

    # Create FIDB, Populate it with signatures, then repack it
    $BuildArgs = @(
        "`"$LibProjectDir`"", "`"$LibraryProvider`"",
        "-noanalysis",
        "-propertiesPath `"$LibProjectDir`"",
        "-scriptPath `"$GhidraScripts`"",
        "-preScript CreateEmptyFidDatabase.java `"$OutputFIDB`"",
        "-preScript CreateMultipleLibraries.java",
        "-postScript RepackFidHeadless.java `"$OutputFIDB`"",
        "-log `"$LogsDir\$LibraryProvider-fidbgen.log`""
    )
    Start-Process -FilePath $GhidraHeadless -ArgumentList $BuildArgs -NoNewWindow -PassThru -Wait
}
