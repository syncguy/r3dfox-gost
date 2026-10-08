$ErrorActionPreference = 'Stop'
$diag = Join-Path $env:GITHUB_WORKSPACE 'rpmalloc-va-diagnostics'
$runtime = Join-Path $env:GITHUB_WORKSPACE 'rpmalloc-va-runtime'
New-Item -ItemType Directory -Force $diag, $runtime | Out-Null
$sourceSha = (git rev-parse HEAD).Trim()
$upstreamSha = 'e4393ff85585d91400bcbad2e7266c011075b673'
$root = Join-Path $env:RUNNER_TEMP 'rpmalloc-1.4.5'
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
git init $root
if ($LASTEXITCODE -ne 0) { throw 'rpmalloc git init failed' }
git -C $root remote add origin https://github.com/mjansson/rpmalloc.git
git -C $root fetch --depth=1 origin $upstreamSha
if ($LASTEXITCODE -ne 0) { throw 'rpmalloc fetch failed' }
git -C $root checkout --detach FETCH_HEAD
if ($LASTEXITCODE -ne 0) { throw 'rpmalloc checkout failed' }
if ((git -C $root rev-parse HEAD).Trim() -ne $upstreamSha) { throw 'rpmalloc SHA mismatch' }

$rpInclude = Join-Path $root 'rpmalloc'
$rpSource = Join-Path $rpInclude 'rpmalloc.c'
$shim = Join-Path $env:GITHUB_WORKSPACE '.github\scripts\xp\rpmalloc-xp-fls-shim.h'
$harness = Join-Path $env:GITHUB_WORKSPACE 'memory\allocator_va_stress\AllocatorVaStress.cpp'
foreach ($path in @($rpSource, $shim, $harness)) {
  if (-not (Test-Path $path)) { throw "Required source missing: $path" }
}
if (-not $env:MSVCR14X_RELEASE -or -not (Test-Path $env:MSVCR14X_RELEASE)) {
  throw 'XP x86 CRT missing'
}

$obj = Join-Path $env:RUNNER_TEMP 'rpmalloc-xp.obj'
$cargs = @('/nologo','/c','/O2','/MD','/TC','/DNDEBUG',
  '/D_WIN32_WINNT=0x0501','/DWINVER=0x0501','/DENABLE_OVERRIDE=0',
  '/DENABLE_PRELOAD=0','/DENABLE_STATISTICS=0','/DENABLE_ASSERTS=0',
  "/FI$shim", "/I$rpInclude", $rpSource, "/Fo:$obj")
& cl.exe @cargs 2>&1 | Tee-Object -FilePath (Join-Path $diag 'rpmalloc-compile.txt')
if ($LASTEXITCODE -ne 0) { throw "rpmalloc compile failed: $LASTEXITCODE" }

$exeName = 'allocator-va-stress-rpmalloc-1.4.5.exe'
$exe = Join-Path $runtime $exeName
$hargs = @('/nologo','/O2','/EHsc','/MD','/std:c++17','/DNDEBUG',
  '/DALLOCATOR_RPMALLOC','/D_WIN32_WINNT=0x0501','/DWINVER=0x0501',
  "/I$rpInclude", $harness, $obj,
  '/link','/SUBSYSTEM:CONSOLE,5.01','/LARGEADDRESSAWARE',
  "/LIBPATH:$env:MSVCR14X_RELEASE",'advapi32.lib',"/OUT:$exe")
& cl.exe @hargs 2>&1 | Tee-Object -FilePath (Join-Path $diag 'harness-link.txt')
if ($LASTEXITCODE -ne 0) { throw "harness link failed: $LASTEXITCODE" }

$headers = @(& dumpbin.exe /nologo /headers $exe 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /headers failed' }
$headers | Set-Content -Encoding utf8 (Join-Path $diag 'exe-headers.txt')
if (-not ($headers | Where-Object { $_ -match '(?i)^\s*14C machine \(x86\)' })) { throw 'Wrong machine' }
if (-not ($headers | Where-Object { $_ -match '(?i)^\s*5\.01 subsystem version' })) { throw 'Not XP subsystem' }
if (-not ($headers | Where-Object { $_ -match '(?i)Application can handle large.*addresses' })) { throw 'Not LAA' }
$imports = @(& dumpbin.exe /nologo /imports $exe 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /imports failed' }
$imports | Set-Content -Encoding utf8 (Join-Path $diag 'exe-imports.txt')
$importText = $imports -join [Environment]::NewLine
$forbiddenApis = @('FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'AcquireSRWLockExclusive','AcquireSRWLockShared','ReleaseSRWLockExclusive',
  'ReleaseSRWLockShared','InitializeSRWLock','InitializeConditionVariable',
  'GetCurrentProcessorNumber','GetActiveProcessorCount','GetTickCount64',
  'VirtualAlloc2','GetThreadId','CancelIoEx','CreateEventExW','CreateFile2',
  'GetLargePageMinimum')
foreach ($api in $forbiddenApis) {
  if ($importText -match ('(?m)\b' + [regex]::Escape($api) + '\b')) { throw "Forbidden XP API: $api" }
}
foreach ($line in $imports) {
  if ($line -notmatch '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') { continue }
  $dll = $matches[1]
  if ($dll -match '^(?i)(api-ms-win-|ext-ms-|KERNELBASE\.dll$|COMBASE\.dll$|NCRYPT\.dll$|BCRYPTPRIMITIVES\.dll$|VCRUNTIME140(?:_1)?\.dll$|DBGHELP\.dll$)') {
    throw "Forbidden XP DLL: $dll"
  }
}
foreach ($dll in @('ucrtbase.dll','msvcp140.dll')) {
  $from = Join-Path $env:MSVCR14X_RELEASE $dll
  if (-not (Test-Path $from)) { throw "Missing pinned CRT: $dll" }
  Copy-Item -Force $from (Join-Path $runtime $dll)
}
$lic = Join-Path $root 'LICENSE'
if (Test-Path $lic) { Copy-Item -Force $lic (Join-Path $runtime 'RPMALLOC-LICENSE.txt') }

$smokeArgs = @('--live-mib','48','--survivor-mib','4','--burst-mib','32',
  '--cycles','3','--gc-hold-per-cycle','1','--sleep-ms','0',
  '--max-ms','30000','--stop-free-mib','64','--stop-aligned-mib','0')
Push-Location $runtime
try {
  & ".\$exeName" --label rpmalloc-1.4.5 @smokeArgs 2>&1 |
    Tee-Object -FilePath (Join-Path $diag 'hosted-rpmalloc.txt')
  if ($LASTEXITCODE -ne 0) { throw "Hosted smoke exit: $LASTEXITCODE" }
  $result = Get-Content -Raw (Join-Path $diag 'hosted-rpmalloc.txt')
  if ($result -notmatch 'RESULT label=rpmalloc-1\.4\.5 status=completed cycles_completed=3 cycles_requested=3') {
    throw 'Hosted smoke did not complete 3/3'
  }
  if ($result -match 'SNAPSHOT label=rpmalloc-1\.4\.5.* complete=0') { throw 'Incomplete VA snapshot' }
} finally {
  Pop-Location
}

$common = '--survivor-mib 32 --burst-mib 256 --cycles 30 --gc-hold-per-cycle 2 --sleep-ms 100 --max-ms 90000 --stop-free-mib 64 --stop-aligned-mib 0'
$cmd = @('@echo off','setlocal','cd /d "%~dp0"','set MOZ_REPLACE_MALLOC_LIB=','set MALLOC_OPTIONS=')
for ($i = 1; $i -le 3; $i++) {
  $cmd += "$exeName --label rpmalloc-1.4.5 --live-mib 416 $common > rpmalloc-live416-r$i.log 2>&1"
}
$cmd += 'endlocal'
$cmd | Set-Content -Encoding ascii (Join-Path $runtime 'run-all.cmd')
@(
  "Source-under-test: $sourceSha",
  "rpmalloc upstream: mjansson/rpmalloc@1.4.5 ($upstreamSha)",
  'Standalone XP x86 test only; not Firefox replace_malloc ABI.',
  'rpmalloc FLS mapped to XP TLS for this standalone test; explicit worker-thread finalize.',
  'Run run-all.cmd on idle physical XP SP3 x86.',
  'Interpret allocation-boundary as a test result, not a physical PASS.',
  'Hosted smoke and static imports do not prove XP runtime.'
) | Set-Content -Encoding ascii (Join-Path $runtime 'README.txt')
$manifest = foreach ($file in Get-ChildItem -LiteralPath $runtime -File) {
  $hash = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
  "$($file.Name)|sha256=$hash|bytes=$($file.Length)"
}
$manifest | Set-Content -Encoding utf8 (Join-Path $diag 'runtime-manifest.txt')
"rpmalloc source-under-test=$sourceSha, pinned upstream=$upstreamSha" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"Hosted smoke 3/3; static XP PE/import gate passed; physical XP not tested" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
