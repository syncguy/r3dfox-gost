param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sourceRepo = 'https://github.com/shorthorn-project/One-Core-API-Source.git'
$sourceCommit = '9eb3c31de9460c1ccce3f6a10c9c4a704f032514'
$rosbeUrl = 'https://sourceforge.net/projects/reactos/files/RosBE-Windows/i386/2.1.6/RosBE-2.1.6.exe/download'

$src = Join-Path $WorkRoot 'onecore-source'
$out = Join-Path $WorkRoot 'onecore-build'
$rosbeInstaller = Join-Path $WorkRoot 'RosBE-2.1.6.exe'
$rosbe = Join-Path $WorkRoot 'RosBE'
$runtime = Join-Path $WorkRoot 'runtime'
$diag = Join-Path $WorkRoot 'diagnostics'
New-Item -ItemType Directory -Force -Path $WorkRoot,$out,$runtime,$diag | Out-Null

& git clone --filter=blob:none --no-tags $sourceRepo $src
if ($LASTEXITCODE -ne 0) { throw 'One-Core source clone failed' }
& git -C $src checkout --detach $sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'One-Core source checkout failed' }
$actual = (& git -C $src rev-parse HEAD).Trim()
if ($actual -ne $sourceCommit) { throw "Unexpected One-Core source SHA: $actual" }
$actual | Set-Content -Encoding ascii (Join-Path $diag 'onecore-source-sha.txt')

# Pinned One-Core has one internal WIDL mismatch in the normal sdk/tools/widl
# tree: header.c calls the newer 5-argument format_namespace API while its own
# widltypes.h/typetree.c declare and implement the 4-argument API. Repair only
# that host-tool call. dll/win32/bcrypt and dll/3rdparty/mbedtls stay untouched.
$widlHeader = Join-Path $src 'sdk\tools\widl\header.c'
$widlText = Get-Content -Raw $widlHeader
$oldCall = 'format_namespace(type->namespace, "", "_", type->name, NULL)'
$newCall = 'format_namespace(type->namespace, "", "_", type->name)'
if (-not $widlText.Contains($oldCall)) { throw 'Expected pinned One-Core WIDL mismatch not found' }
$widlText = $widlText.Replace($oldCall, $newCall)
Set-Content -Encoding ascii -Path $widlHeader -Value $widlText
@"
source_sha=$sourceCommit
reason=sdk/tools/widl/header.c uses 5 args while widltypes.h and typetree.c define 4-arg format_namespace
change=remove trailing NULL from format_namespace call in format_apicontract_macro
bcrypt_implementation_modified=no
mbedtls_implementation_modified=no
"@ | Set-Content -Encoding ascii (Join-Path $diag 'onecore-widl-source-fix.txt')
& git -C $src diff -- sdk/tools/widl/header.c | Set-Content -Encoding utf8 (Join-Path $diag 'onecore-widl-source-fix.diff')

& curl.exe -L --fail --retry 3 -o $rosbeInstaller $rosbeUrl
if ($LASTEXITCODE -ne 0) { throw 'RosBE download failed' }
$rosbeHash = (Get-FileHash $rosbeInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
"url=$rosbeUrl`nsha256=$rosbeHash" | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-provenance.txt')

New-Item -ItemType Directory -Force -Path $rosbe | Out-Null
$install = Start-Process -FilePath $rosbeInstaller -ArgumentList '/S',("/D=$rosbe") -Wait -PassThru
"exit_code=$($install.ExitCode)`nrequested_dir=$rosbe" | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-install.txt')
if ($install.ExitCode -ne 0) { throw "RosBE installer failed with $($install.ExitCode)" }

$roots = @($rosbe,(Join-Path $env:SystemDrive 'RosBE'),(Join-Path $env:SystemDrive 'RosBE-2.1.6'))
if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'RosBE') }
if (${env:ProgramFiles(x86)}) { $roots += (Join-Path ${env:ProgramFiles(x86)} 'RosBE') }
$roots += @(Get-ChildItem ($env:SystemDrive + '\') -Directory -Filter 'RosBE*' -ErrorAction SilentlyContinue | ForEach-Object FullName)
$roots = @($roots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
$roots | Set-Content -Encoding utf8 (Join-Path $diag 'rosbe-search-roots.txt')
$rosbeCmd = $null
foreach ($root in $roots) {
  $candidate = Get-ChildItem $root -Recurse -Filter RosBE.cmd -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $rosbeCmd = $candidate; break }
}
if (-not $rosbeCmd) { throw 'RosBE.cmd not found after RosBE 2.1.6 install' }
$rosbeCmd.FullName | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-command.txt')

$linkedSource = Join-Path $RepoRoot 'tools\gost\xp\bcrypt-smoke\bcrypt_linked.cpp'
$linkedObj = Join-Path $WorkRoot 'bcrypt-source-linked.o'
$linkedExe = Join-Path $runtime 'bcrypt-source-linked.exe'
$buildCmd = Join-Path $WorkRoot 'build-onecore-bcrypt.cmd'
@"
@echo on
call "$($rosbeCmd.FullName)"
if errorlevel 1 exit /b %errorlevel%
set "PATH=%PATH:C:\mingw64\bin;=%"
set "PATH=%PATH:;C:\mingw64\bin=%"
where cc
where gcc
where g++
where cmake
cd /d "$out"
call "$src\configure.cmd" -DENABLE_ROSTESTS=0
if errorlevel 1 exit /b %errorlevel%
ninja mbedtls bcrypt
if errorlevel 1 exit /b %errorlevel%
g++ -c -O2 -fno-exceptions -fno-rtti -o "$linkedObj" "$linkedSource"
if errorlevel 1 exit /b %errorlevel%
g++ -nostdlib -Wl,--entry,_mainCRTStartup -Wl,--subsystem,console -Wl,--major-subsystem-version,5 -Wl,--minor-subsystem-version,1 -o "$linkedExe" "$linkedObj" "$out\dll\win32\bcrypt\libbcrypt.a" -lkernel32
exit /b %errorlevel%
"@ | Set-Content -Encoding ascii $buildCmd

$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & cmd.exe /d /c $buildCmd *>&1 | Tee-Object -FilePath (Join-Path $diag 'build.log')
  $buildExit = $LASTEXITCODE
} finally { $ErrorActionPreference = $oldEap }
"exit_code=$buildExit" | Set-Content -Encoding ascii (Join-Path $diag 'build-exit-code.txt')
if ($buildExit -ne 0) { throw "One-Core bcrypt build failed with $buildExit" }
if (-not (Test-Path $linkedExe)) { throw 'Source bcrypt linked consumer was not produced' }

function Find-BuiltDll([string]$name) {
  $items = @(Get-ChildItem $out -Recurse -Filter $name -File)
  if ($items.Count -eq 0) { throw "Built $name not found" }
  return ($items | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
}

$bcrypt = Find-BuiltDll 'bcrypt.dll'
$mbedtls = Find-BuiltDll 'mbedtls.dll'
"bcrypt=$($bcrypt.FullName)`nmbedtls=$($mbedtls.FullName)`nlinked_importlib=$out\dll\win32\bcrypt\libbcrypt.a" | Set-Content -Encoding ascii (Join-Path $diag 'runtime-closure-build-paths.txt')
Copy-Item $bcrypt.FullName (Join-Path $runtime 'bcrypt.dll')
Copy-Item $mbedtls.FullName (Join-Path $runtime 'mbedtls.dll')

$forbidden = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','ReleaseSRWLockExclusive','ReleaseSRWLockShared',
  'InitializeSRWLock','InitializeConditionVariable','SleepConditionVariableCS','SleepConditionVariableSRW',
  'WakeAllConditionVariable','WakeConditionVariable','InitializeCriticalSectionEx',
  'FlsAlloc','FlsFree','FlsGetValue','FlsSetValue','GetTickCount64','GetSystemTimePreciseAsFileTime'
)

function Audit-Dll([System.IO.FileInfo]$dll,[string]$stem) {
  $headers = & dumpbin /headers $dll.FullName 2>&1
  $imports = & dumpbin /imports $dll.FullName 2>&1
  $exports = & dumpbin /exports $dll.FullName 2>&1
  $headers | Set-Content -Encoding utf8 (Join-Path $diag "$stem.headers.txt")
  $imports | Set-Content -Encoding utf8 (Join-Path $diag "$stem.imports.txt")
  $exports | Set-Content -Encoding utf8 (Join-Path $diag "$stem.exports.txt")
  foreach ($name in $forbidden) {
    if ($imports -match "\b$([regex]::Escape($name))\b") { throw "Post-XP hard import found in $($dll.Name): $name" }
  }
  return @{ Headers=$headers; Imports=$imports; Exports=$exports }
}

$bcryptAudit = Audit-Dll $bcrypt 'bcrypt'
$mbedtlsAudit = Audit-Dll $mbedtls 'mbedtls'

$requiredExports = @(
  'BCryptOpenAlgorithmProvider','BCryptCloseAlgorithmProvider','BCryptGetProperty',
  'BCryptCreateHash','BCryptHashData','BCryptFinishHash','BCryptDestroyHash','BCryptGenRandom'
)
foreach ($name in $requiredExports) {
  if (-not ($bcryptAudit.Exports -match "\b$([regex]::Escape($name))\b")) { throw "Required bcrypt export missing: $name" }
}
if (-not ($bcryptAudit.Imports -match '\bmbedtls\.dll\b')) { throw 'Expected bcrypt -> mbedtls.dll runtime dependency not found' }

$dynamicSource = Join-Path $RepoRoot 'tools\gost\xp\bcrypt-smoke\bcrypt_dynamic.cpp'
$dynamicExe = Join-Path $runtime 'bcrypt-source-dynamic.exe'
& cl.exe /nologo /c /O2 /GS- /GR- /EHsc- /Fo"$WorkRoot\bcrypt-source-dynamic.obj" $dynamicSource
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source dynamic probe compile failed' }
& link.exe /nologo /OUT:$dynamicExe /ENTRY:mainCRTStartup /SUBSYSTEM:CONSOLE,5.01 /NODEFAULTLIB "$WorkRoot\bcrypt-source-dynamic.obj" kernel32.lib
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source dynamic probe link failed' }

$dynamicHeaders = & dumpbin /headers $dynamicExe 2>&1
$dynamicImports = & dumpbin /imports $dynamicExe 2>&1
$linkedHeaders = & dumpbin /headers $linkedExe 2>&1
$linkedImports = & dumpbin /imports $linkedExe 2>&1
$dynamicHeaders | Set-Content -Encoding utf8 (Join-Path $diag 'dynamic-probe.headers.txt')
$dynamicImports | Set-Content -Encoding utf8 (Join-Path $diag 'dynamic-probe.imports.txt')
$linkedHeaders | Set-Content -Encoding utf8 (Join-Path $diag 'linked-probe.headers.txt')
$linkedImports | Set-Content -Encoding utf8 (Join-Path $diag 'linked-probe.imports.txt')
if ($dynamicImports -match '(?i)bcrypt\.dll') { throw 'Dynamic probe unexpectedly imports bcrypt.dll' }
if (-not ($linkedImports -match '(?i)bcrypt\.dll')) { throw 'Linked probe does not import bcrypt.dll' }
foreach ($name in $forbidden) {
  if ($linkedImports -match "\b$([regex]::Escape($name))\b") { throw "Post-XP hard import found in linked consumer: $name" }
}

@'
@echo off
setlocal
cd /d "%~dp0"
echo === One-Core source-built bcrypt + mbedtls dynamic probe ===
bcrypt-source-dynamic.exe
echo DynamicExitCode=%ERRORLEVEL%
echo.
echo === One-Core source-built bcrypt + mbedtls linked probe ===
bcrypt-source-linked.exe
echo LinkedExitCode=%ERRORLEVEL%
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'run-on-xp.cmd')

@"
One-Core-API source-built bcrypt XP x86 smoke
Source repository: shorthorn-project/One-Core-API-Source
Pinned source commit: $sourceCommit
Source components: dll/win32/bcrypt + dll/3rdparty/mbedtls
Build environment: RosBE 2.1.6 i386
Build-tree correction: one-line WIDL host-tool signature repair only; bcrypt and mbedtls sources remain unmodified.

Physical XP test:
1. Extract the entire artifact unchanged on Windows XP SP3 x86.
2. Keep bcrypt.dll and mbedtls.dll beside both probe EXEs.
3. Run run-on-xp.cmd and record complete output.

Dynamic probe contract:
- no bcrypt.dll static import;
- LoadLibraryW(.\\bcrypt.dll) + GetProcAddress;
- BCryptGenRandom;
- SHA-256('abc').

Linked probe contract:
- ordinary PE import of bcrypt.dll through One-Core-generated libbcrypt.a;
- BCryptGenRandom;
- SHA-256('abc').

Acceptance for each probe:
LOAD PASS
EXPORTS PASS
RNG PASS
SHA256 PASS
exit code 0
"@ | Set-Content -Encoding utf8 (Join-Path $runtime 'README-XP.md')

Get-ChildItem $runtime -File | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  "$h  $($_.Name)"
} | Set-Content -Encoding ascii (Join-Path $diag 'runtime-bundle-hashes.txt')

Push-Location $runtime
try {
  & .\bcrypt-source-dynamic.exe *>&1 | Tee-Object -FilePath (Join-Path $diag 'hosted-dynamic-runtime.txt')
  $dynamicExit = $LASTEXITCODE
  & .\bcrypt-source-linked.exe *>&1 | Tee-Object -FilePath (Join-Path $diag 'hosted-linked-runtime.txt')
  $linkedExit = $LASTEXITCODE
} finally { Pop-Location }
if ($dynamicExit -ne 0) { throw "Hosted exact-local source-built bcrypt dynamic probe failed with $dynamicExit" }
if ($linkedExit -ne 0) { throw "Hosted source-built bcrypt linked probe failed with $linkedExit" }
