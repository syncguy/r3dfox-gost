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

# The pinned One-Core commit has one obvious internal WIDL mismatch in the
# normal sdk/tools/widl tree: header.c calls format_namespace with the newer
# five-argument signature, while widltypes.h and typetree.c in that same tree
# declare/implement the older four-argument signature. Keep the normal WIDL
# tree and repair only that call. Do not touch dll/win32/bcrypt.
$widlHeader = Join-Path $src 'sdk\tools\widl\header.c'
$widlText = Get-Content -Raw $widlHeader
$oldCall = 'format_namespace(type->namespace, "", "_", type->name, NULL)'
$newCall = 'format_namespace(type->namespace, "", "_", type->name)'
if (-not $widlText.Contains($oldCall)) {
  throw 'Expected pinned One-Core WIDL format_namespace mismatch not found'
}
$widlText = $widlText.Replace($oldCall, $newCall)
Set-Content -Encoding ascii -Path $widlHeader -Value $widlText
@"
source_sha=$sourceCommit
reason=sdk/tools/widl/header.c uses 5 args while widltypes.h and typetree.c define 4-arg format_namespace
change=sdk/tools/widl/header.c: remove trailing NULL from format_namespace call in format_apicontract_macro
bcrypt_implementation_modified=no
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

$searchRoots = New-Object System.Collections.Generic.List[string]
$fixedRoots = @(
  $rosbe,
  (Join-Path $env:SystemDrive 'RosBE'),
  (Join-Path $env:SystemDrive 'RosBE-2.1.6')
)
if ($env:ProgramFiles) { $fixedRoots += (Join-Path $env:ProgramFiles 'RosBE') }
if (${env:ProgramFiles(x86)}) { $fixedRoots += (Join-Path ${env:ProgramFiles(x86)} 'RosBE') }
foreach ($root in $fixedRoots) {
  if ($root -and (Test-Path $root) -and -not $searchRoots.Contains($root)) { $searchRoots.Add($root) }
}
Get-ChildItem ($env:SystemDrive + '\') -Directory -Filter 'RosBE*' -ErrorAction SilentlyContinue | ForEach-Object {
  if (-not $searchRoots.Contains($_.FullName)) { $searchRoots.Add($_.FullName) }
}
$searchRoots | Set-Content -Encoding utf8 (Join-Path $diag 'rosbe-search-roots.txt')

$rosbeCmd = $null
foreach ($root in $searchRoots) {
  $candidate = Get-ChildItem $root -Recurse -Filter RosBE.cmd -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $rosbeCmd = $candidate; break }
}
if (-not $rosbeCmd) {
  Get-ChildItem ($env:SystemDrive + '\') -Directory -ErrorAction SilentlyContinue |
    Select-Object FullName,LastWriteTimeUtc |
    Format-Table -AutoSize |
    Out-String |
    Set-Content -Encoding utf8 (Join-Path $diag 'system-drive-root-after-rosbe-install.txt')
  throw 'RosBE.cmd not found after RosBE 2.1.6 install; see diagnostics for discovered install roots'
}
$rosbeCmd.FullName | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-command.txt')

$buildCmd = Join-Path $WorkRoot 'build-onecore-bcrypt.cmd'
@"
@echo on
call "$($rosbeCmd.FullName)"
if errorlevel 1 exit /b %errorlevel%
set "PATH=%PATH:C:\mingw64\bin;=%"
set "PATH=%PATH:;C:\mingw64\bin=%"
where cc
where gcc
where cmake
cd /d "$out"
call "$src\configure.cmd" -DENABLE_ROSTESTS=0
if errorlevel 1 exit /b %errorlevel%
ninja bcrypt
exit /b %errorlevel%
"@ | Set-Content -Encoding ascii $buildCmd

$oldErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & cmd.exe /d /c $buildCmd *>&1 | Tee-Object -FilePath (Join-Path $diag 'build.log')
  $buildExit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldErrorActionPreference
}
"exit_code=$buildExit" | Set-Content -Encoding ascii (Join-Path $diag 'build-exit-code.txt')
if ($buildExit -ne 0) { throw "One-Core bcrypt build failed with $buildExit" }

$candidates = @(Get-ChildItem $out -Recurse -Filter bcrypt.dll -File)
if ($candidates.Count -eq 0) { throw 'Built bcrypt.dll not found' }
$bcrypt = $candidates | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
$bcrypt.FullName | Set-Content -Encoding ascii (Join-Path $diag 'bcrypt-build-path.txt')
Copy-Item $bcrypt.FullName (Join-Path $runtime 'bcrypt.dll')

$headers = & dumpbin /headers $bcrypt.FullName 2>&1
$imports = & dumpbin /imports $bcrypt.FullName 2>&1
$exports = & dumpbin /exports $bcrypt.FullName 2>&1
$headers | Set-Content -Encoding utf8 (Join-Path $diag 'bcrypt.headers.txt')
$imports | Set-Content -Encoding utf8 (Join-Path $diag 'bcrypt.imports.txt')
$exports | Set-Content -Encoding utf8 (Join-Path $diag 'bcrypt.exports.txt')

$requiredExports = @(
  'BCryptOpenAlgorithmProvider','BCryptCloseAlgorithmProvider','BCryptGetProperty',
  'BCryptCreateHash','BCryptHashData','BCryptFinishHash','BCryptDestroyHash','BCryptGenRandom'
)
foreach ($name in $requiredExports) {
  if (-not ($exports -match "\b$([regex]::Escape($name))\b")) { throw "Required export missing: $name" }
}

$forbidden = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','ReleaseSRWLockExclusive','ReleaseSRWLockShared',
  'InitializeSRWLock','InitializeConditionVariable','SleepConditionVariableCS','SleepConditionVariableSRW',
  'WakeAllConditionVariable','WakeConditionVariable','InitializeCriticalSectionEx',
  'FlsAlloc','FlsFree','FlsGetValue','FlsSetValue','GetTickCount64','GetSystemTimePreciseAsFileTime'
)
foreach ($name in $forbidden) {
  if ($imports -match "\b$([regex]::Escape($name))\b") { throw "Post-XP hard import found in built bcrypt.dll: $name" }
}

$probeSource = Join-Path $RepoRoot 'tools\gost\xp\bcrypt-smoke\bcrypt_dynamic.cpp'
$probe = Join-Path $runtime 'bcrypt-source-dynamic.exe'
& cl.exe /nologo /c /O2 /GS- /GR- /EHsc- /Fo"$WorkRoot\bcrypt-source-dynamic.obj" $probeSource
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source dynamic probe compile failed' }
& link.exe /nologo /OUT:$probe /ENTRY:mainCRTStartup /SUBSYSTEM:CONSOLE,5.01 /NODEFAULTLIB "$WorkRoot\bcrypt-source-dynamic.obj" kernel32.lib
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source dynamic probe link failed' }

& dumpbin /headers $probe | Set-Content -Encoding utf8 (Join-Path $diag 'probe.headers.txt')
& dumpbin /imports $probe | Set-Content -Encoding utf8 (Join-Path $diag 'probe.imports.txt')

@'
@echo off
setlocal
cd /d "%~dp0"
echo === One-Core source-built bcrypt dynamic probe ===
bcrypt-source-dynamic.exe
echo ExitCode=%ERRORLEVEL%
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'run-on-xp.cmd')

@"
One-Core-API source-built bcrypt XP x86 smoke
Source repository: shorthorn-project/One-Core-API-Source
Pinned source commit: $sourceCommit
Source component: dll/win32/bcrypt
Build environment: RosBE 2.1.6 i386
Build-tree correction: one-line WIDL host-tool signature repair; dll/win32/bcrypt remains unmodified.

Physical XP test:
1. Extract this entire artifact unchanged on Windows XP SP3 x86.
2. Run run-on-xp.cmd.
3. Record the complete console output.

Acceptance markers:
LOAD PASS
EXPORTS PASS
RNG PASS
SHA256 PASS
ExitCode=0
"@ | Set-Content -Encoding utf8 (Join-Path $runtime 'README-XP.md')

Get-ChildItem $runtime -File | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  "$h  $($_.Name)"
} | Set-Content -Encoding ascii (Join-Path $diag 'runtime-bundle-hashes.txt')

Push-Location $runtime
try {
  & .\bcrypt-source-dynamic.exe *>&1 | Tee-Object -FilePath (Join-Path $diag 'hosted-runtime.txt')
  $hostedExit = $LASTEXITCODE
} finally { Pop-Location }
if ($hostedExit -ne 0) { throw "Hosted exact-local source-built bcrypt probe failed with $hostedExit" }
