param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('imports', 'stage', 'hosted')]
    [string]$Stage
)

switch ($Stage) {
    'imports' {
$ErrorActionPreference='Stop'
$headers=(& dumpbin.exe /nologo /headers $env:SMOKE_EXE 2>&1|Out-String);$headers|Set-Content -Encoding utf8 diagnostics\probe-headers.txt
if($headers-notmatch'(?im)^\s*14C machine \(x86\)'){throw 'Probe is not x86'}
$line=@($headers-split"`r?`n"|Where-Object{$_-match'(?i)subsystem version'}|Select-Object -First 1);if(-not$line-or$line[0]-notmatch'^\s*([0-9]+)\.([0-9]+)\s+subsystem version'){throw 'Cannot parse subsystem'}
if([version]("$([int]$matches[1]).$([int]$matches[2])")-gt[version]'5.1'){throw 'Probe subsystem newer than XP'}
$imports=(& dumpbin.exe /nologo /imports $env:SMOKE_EXE 2>&1|Out-String);$imports|Set-Content -Encoding utf8 diagnostics\probe-imports.txt
foreach($api in (Get-Content diagnostics\capable-apis.txt)){if($imports.IndexOf($api,[System.StringComparison]::OrdinalIgnoreCase)-ge 0){throw "Probe retains direct import $api"}}
foreach($bad in @('api-ms-win-','ext-ms-','KERNELBASE.dll','bcrypt.dll')){if($imports.IndexOf($bad,[System.StringComparison]::OrdinalIgnoreCase)-ge 0){throw "Forbidden dependency $bad"}}
if($imports.IndexOf('ProcessPrng',[System.StringComparison]::OrdinalIgnoreCase)-ge 0){throw 'Probe retains direct import ProcessPrng'}
if($imports.IndexOf('WindowsCreateString',[System.StringComparison]::OrdinalIgnoreCase)-ge 0){throw 'Probe retains direct WinRT string import'}
'cluster_import_gate=PASS'|Set-Content -Encoding ascii diagnostics\cluster-import-gate.txt
    }
    'stage' {
$ErrorActionPreference='Stop'
foreach($dll in @('ucrtbase.dll','msvcp140.dll')){$src=Join-Path $env:MSVCR14X_RELEASE $dll;if(-not(Test-Path $src)){throw "Missing $dll"};Copy-Item -Force $src runtime}
foreach($bin in Get-ChildItem runtime -File -Filter *.dll){$h=(& dumpbin.exe /nologo /headers $bin.FullName 2>&1|Out-String);if($h-notmatch'(?im)^\s*14C machine \(x86\)'){throw "$($bin.Name) not x86"}}
    }
    'hosted' {
$ErrorActionPreference='Stop'
& $env:SMOKE_EXE | Tee-Object diagnostics\hosted-run.txt
if($LASTEXITCODE-ne 0){throw "Hosted probe failed: $LASTEXITCODE"}
    }
    default { throw "Unsupported cluster stage: $Stage" }
}
