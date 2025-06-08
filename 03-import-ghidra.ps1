param(
    [Parameter(Mandatory=$true)]
    [string]$GhidraPath,
    [string]$GhidraProjectDirRoot = "$PSScriptRoot\projects",
    [string]$LibraryDir = "$PSScriptRoot\libs",
    [string]$LogsDir = "$PSScriptRoot\logs",
    [string]$LanguageID = "PowerPC:BE:64:A2ALT-32addr",
    [string]$GhidraLoaderType = "XmlLoader"
)

$GhidraHeadless = "$GhidraPath\support\analyzeHeadless.bat"
$GhidraFIDScripts = "$GhidraPath\Ghidra\Features\FunctionID\ghidra_scripts"

foreach($LibraryProviderPath in Get-ChildItem -Path $LibraryDir -Directory) {
    $LibraryProvider = $LibraryProviderPath.Name
    $GhidraProjectDir = "$GhidraProjectDirRoot\$($LibraryProvider)"
    if(-not(Test-Path $GhidraProjectDir)) {
        New-Item -ItemType Directory -Path $GhidraProjectDir | Out-Null
    }
    $GhidraArgs = @(
        "`"$GhidraProjectDir`"", "`"$LibraryProvider`"", 
        "-import `"$LibraryDir\$LibraryProvider`"",
        "-recursive",
        "-loader `"$GhidraLoaderType`"",
        "-processor `"$LanguageID`"",
        "-scriptPath `"$GhidraFIDScripts`"",
        "-preScript FunctionIDHeadlessPrescript.java",
        "-postScript FunctionIDHeadlessPostscript.java",
        "-scriptlog `"$LogsDir\$LibraryProvider-scripts.log`"",
        "-log `"$LogsDir\$LibraryProvider-scripts.log`""
    )

    $GhidraProc = Start-Process -FilePath $GhidraHeadless -ArgumentList $GhidraArgs -NoNewWindow -PassThru -Wait

    if($GhidraProc.ExitCode -ne 0) {
        Write-Error "Failed to import $InternalPath : $($GhidraProc.ExitCode)"
    } else {
        Write-Host "Successfully imported $InternalPath"
    }
}
