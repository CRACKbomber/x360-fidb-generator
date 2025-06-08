# Xbox 360 Ghidra FIDB Generator Scripts

These scripts will extract a given Xbox 360 setup exe, extract static libraries, and import them into Ghidra with a translation step through IDA (No xbox 360 COFF support in Ghidra).

## How to Use

## Requirements

- IDA Pro 7.0+ (Tested with IDA Pro 7.7)
- Ghidra 11+ (Tested with Ghidra 11.3.2)
- 7zip
- Powershell 7

## Configure IDA

Since Xbox 360 COFF files are not supported in Ghidra, this script will preprocess them into xml files that can be imported into Ghidra. This requires the Ghidra IDA XML plugin to be installed
Copy the IDA plugin provided with Ghidra to your install directory
```
Ghidra_Install\Extensions\IDAPro\Python\7xx\loaders --> IDA_Install\loaders
Ghidra_Install\Extensions\IDAPro\Python\7xx\plugins --> IDA_Install\plugins
Ghidra_Install\Extensions\IDAPro\Python\7xx\python --> IDA_Install\python
```

1. Clone this repository to a drive with at least 16gb free space
2. Put XDKSetupXenonXXXX.exe in sdks\
3. Run ``` .\01-unpack-sdks.ps1 -SevenZipPath "[Path containing 7z.exe]" ```
4. Run ``` .\02-convert-ida.ps1 -IDAPath "[Path containing ida.exe]" ```
5. Run ``` .\03-import-ghidra.ps1 -GhidraPath "[Path containing ghidraRun.bat]" ```
6. Run ``` .\04-generate-fidb.ps1 -GhidraPath "[Path containing ghidraRun.bat]" ```

The output fidb will be located in .\fid_files

# Give me the FIDBs

[Go Here](https://github.com/CRACKbomber/ghidra-fidb-xenonsdk)
