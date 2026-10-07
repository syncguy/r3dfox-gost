$ErrorActionPreference = 'Stop'

$diag = Join-Path $env:GITHUB_WORKSPACE 'allocator-va-diagnostics'
$runtime = Join-Path $env:GITHUB_WORKSPACE 'allocator-va-runtime'
New-Item -ItemType Directory -Force $diag | Out-Null
New-Item -ItemType Directory -Force $runtime | Out-Null

$sourceSha = (git rev-parse HEAD).Trim()
@(
  "source_under_test=$sourceSha"
  "msvcr14x_sha=$env:MSVCR14X_SHA"
  "mimalloc_sha=$env:MIMALLOC_SHA"
  "mimalloc_version=$env:MIMALLOC_VERSION"
) | Set-Content -Encoding utf8 (Join-Path $diag 'identity.txt')

function Invoke-Checked([string]$Name, [scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit code $LASTEXITCODE"
  }
}

function Find-StressExe([string]$ObjDir) {
  $candidates = @(Get-ChildItem -LiteralPath $ObjDir -Recurse -File -Filter 'allocator-va-stress.exe')
  if (-not $candidates.Count) {
    throw "allocator-va-stress.exe not found under $ObjDir"
  }
  $dist = @($candidates | Where-Object { $_.FullName -match '(?i)[\\/]dist[\\/]bin[\\/]' })
  if ($dist.Count) {
    return $dist[0].FullName
  }
  return $candidates[0].FullName
}

function Write-MemoryMozconfig([string]$Path, [string]$ObjDirName) {
  @'
mk_add_options AUTOCLOBBER=1
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/OBJDIR_PLACEHOLDER
ac_add_options --enable-project=memory
ac_add_options --target=i686
ac_add_options --disable-debug
ac_add_options --disable-tests
ac_add_options --enable-jemalloc
ac_add_options --enable-replace-malloc
ac_add_options --enable-optimize
ac_add_options --enable-release
export CFLAGS="$CFLAGS -DMOZ_XP_COMPAT"
export CXXFLAGS="$CXXFLAGS -DMOZ_XP_COMPAT"
'@.Replace('OBJDIR_PLACEHOLDER', $ObjDirName) | Set-Content -Encoding ascii $Path
}

function Build-MozJemallocVariant(
  [string]$Label,
  [string]$ObjDirName,
  [string]$DestinationName
) {
  $mozconfig = Join-Path $env:GITHUB_WORKSPACE ".mozconfig-$Label"
  Write-MemoryMozconfig $mozconfig $ObjDirName
  $env:MOZCONFIG = $mozconfig

  Invoke-Checked "mach configure ($Label)" { .\mach.ps1 configure }
  Invoke-Checked "mach build ($Label)" { .\mach.ps1 build memory/allocator_va_stress }

  $objDir = Join-Path $env:GITHUB_WORKSPACE $ObjDirName
  $exe = Find-StressExe $objDir
  $dst = Join-Path $runtime $DestinationName
  Copy-Item -Force $exe $dst

  Invoke-Checked "editbin ($Label)" {
    & editbin.exe /NOLOGO /SUBSYSTEM:CONSOLE,5.01 /LARGEADDRESSAWARE $dst
  }

  return $dst
}

$constantsPath = Join-Path $env:GITHUB_WORKSPACE 'memory\build\Constants.h'
$constantsOriginal = [System.IO.File]::ReadAllText($constantsPath)
$expectedRecycle = 'static constexpr size_t gRecycleLimit = 128_MiB;'
if (-not $constantsOriginal.Contains($expectedRecycle)) {
  throw 'Expected mozjemalloc gRecycleLimit definition not found'
}

try {
  $stockExe = Join-Path $runtime 'allocator-va-stress-mozjemalloc-128.exe'
  Build-MozJemallocVariant -Label 'mozjemalloc-128' -ObjDirName 'obj-memory-va-stock' -DestinationName 'allocator-va-stress-mozjemalloc-128.exe' | Out-Host

  $zeroSource = $constantsOriginal.Replace(
    $expectedRecycle,
    'static constexpr size_t gRecycleLimit = 0;'
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($constantsPath, $zeroSource, $utf8NoBom)

  $zeroExe = Join-Path $runtime 'allocator-va-stress-mozjemalloc-0.exe'
  Build-MozJemallocVariant -Label 'mozjemalloc-0' -ObjDirName 'obj-memory-va-zero' -DestinationName 'allocator-va-stress-mozjemalloc-0.exe' | Out-Host
}
finally {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($constantsPath, $constantsOriginal, $utf8NoBom)
}

$restored = [System.IO.File]::ReadAllText($constantsPath)
if ($restored -ne $constantsOriginal) {
  throw 'Constants.h was not restored after mozjemalloc retention variant build'
}
if ((git status --porcelain -- memory/build/Constants.h)) {
  throw 'Constants.h remains modified after retention variant build'
}

$mimallocRoot = Join-Path $env:RUNNER_TEMP 'mimalloc-va-poc'
if (Test-Path $mimallocRoot) {
  Remove-Item -Recurse -Force $mimallocRoot
}
git init $mimallocRoot | Out-Null
git -C $mimallocRoot remote add origin https://github.com/microsoft/mimalloc.git
Invoke-Checked 'fetch mimalloc' {
  git -C $mimallocRoot fetch --depth=1 origin $env:MIMALLOC_SHA
}
Invoke-Checked 'checkout mimalloc' {
  git -C $mimallocRoot checkout --detach FETCH_HEAD
}
$mimallocActual = (git -C $mimallocRoot rev-parse HEAD).Trim()
if ($mimallocActual -ne $env:MIMALLOC_SHA) {
  throw "Unexpected mimalloc commit: $mimallocActual"
}

$mimallocObj = Join-Path $env:RUNNER_TEMP 'mimalloc-static.obj'
$mimallocCompileLog = Join-Path $diag 'mimalloc-compile.txt'
$miCompileArgs = @(
  '/nologo','/c','/O2','/MD','/TC',
  '/DMI_STATIC_LIB','/D_WIN32_WINNT=0x0501','/DWINVER=0x0501',
  "/I$mimallocRoot\include",
  "$mimallocRoot\src\static.c",
  "/Fo:$mimallocObj"
)
& cl.exe @miCompileArgs 2>&1 | Tee-Object -FilePath $mimallocCompileLog
if ($LASTEXITCODE -ne 0) {
  throw "mimalloc static compile failed: $LASTEXITCODE"
}

$mimallocExe = Join-Path $runtime 'allocator-va-stress-mimalloc-2.5.2.exe'
$harness = Join-Path $env:GITHUB_WORKSPACE 'memory\allocator_va_stress\AllocatorVaStress.cpp'
$mimallocLinkLog = Join-Path $diag 'mimalloc-harness-link.txt'
$miLinkArgs = @(
  '/nologo','/O2','/EHsc','/MD','/std:c++17',
  '/DALLOCATOR_MIMALLOC','/D_WIN32_WINNT=0x0501','/DWINVER=0x0501',
  "/I$mimallocRoot\include",
  $harness,$mimallocObj,
  '/link','/SUBSYSTEM:CONSOLE,5.01','/LARGEADDRESSAWARE',"/OUT:$mimallocExe"
)
& cl.exe @miLinkArgs 2>&1 | Tee-Object -FilePath $mimallocLinkLog
if ($LASTEXITCODE -ne 0) {
  throw "mimalloc harness link failed: $LASTEXITCODE"
}

foreach ($dll in @('ucrtbase.dll', 'msvcp140.dll')) {
  $src = Join-Path $env:MSVCR14X_RELEASE $dll
  if (-not (Test-Path $src)) {
    throw "Required msvcr14x runtime missing: $src"
  }
  Copy-Item -Force $src (Join-Path $runtime $dll)
}

$forbiddenDllPatterns = @(
  '^(?i)(api-ms-win-|ext-ms-)',
  '^(?i)KERNELBASE\.dll$',
  '^(?i)BCRYPTPRIMITIVES\.dll$',
  '^(?i)COMBASE\.dll$',
  '^(?i)NCRYPT\.dll$',
  '^(?i)WEVTAPI\.dll$',
  '^(?i)DWMAPI\.dll$',
  '^(?i)SHCORE\.dll$',
  '^(?i)PATHCCH\.dll$',
  '^(?i)NORMALIZ\.dll$',
  '^(?i)PROPSYS\.dll$',
  '^(?i)DXGI\.dll$',
  '^(?i)VCRUNTIME140(?:_1)?\.dll$'
)

$forbiddenApis = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx',
  'CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA',
  'CreateMutexExW','CreateSemaphoreExW','FlsAlloc','FlsFree','FlsGetValue',
  'FlsSetValue','GetActiveProcessorCount','GetCurrentProcessorNumber',
  'GetCurrentProcessorNumberEx','GetFileInformationByHandleEx',
  'GetFinalPathNameByHandleA','GetFinalPathNameByHandleW',
  'GetLogicalProcessorInformationEx','GetMaximumProcessorCount',
  'GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A',
  'GetTempPath2W','GetTickCount64','InitializeConditionVariable',
  'InitializeCriticalSectionEx','InitializeSRWLock','IsThreadAFiber',
  'QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive',
  'ReleaseSRWLockShared','SetFileInformationByHandle',
  'SetThreadDescription','SleepConditionVariableCS',
  'SleepConditionVariableSRW','SubmitThreadpoolWork',
  'TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress',
  'WakeAllConditionVariable','WakeByAddressAll','WakeByAddressSingle',
  'WakeConditionVariable','CreateWaitableTimerExA','CreateWaitableTimerExW',
  'CancelSynchronousIo','GetProcessIdOfThread','GetQueuedCompletionStatusEx',
  'GetThreadId','InitOnceExecuteOnce','InitOnceBeginInitialize',
  'InitOnceComplete','QueryFullProcessImageNameA','QueryFullProcessImageNameW'
)

function Audit-XpExe([string]$Path) {
  $name = [System.IO.Path]::GetFileNameWithoutExtension($Path)
  $headersPath = Join-Path $diag "$name-headers.txt"
  $importsPath = Join-Path $diag "$name-imports.txt"

  $headers = @(& dumpbin.exe /nologo /headers $Path 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /headers failed for $Path"
  }
  $headers | Set-Content -Encoding utf8 $headersPath

  if (-not ($headers | Where-Object { $_ -match '(?i)^\s*14C machine \(x86\)' })) {
    throw "$name is not x86"
  }
  if (-not ($headers | Where-Object { $_ -match '(?i)^\s*5\.01 subsystem version' })) {
    throw "$name is not subsystem 5.01"
  }
  if (-not ($headers | Where-Object { $_ -match '(?i)Application can handle large.*addresses' })) {
    throw "$name is not LARGEADDRESSAWARE"
  }

  $imports = @(& dumpbin.exe /nologo /imports $Path 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /imports failed for $Path"
  }
  $imports | Set-Content -Encoding utf8 $importsPath

  $dllNames = @($imports | ForEach-Object {
    if ($_ -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') { $matches[1] }
  })
  foreach ($dll in $dllNames) {
    foreach ($pattern in $forbiddenDllPatterns) {
      if ($dll -match $pattern) {
        throw "$name contains forbidden post-XP DLL: $dll"
      }
    }
  }

  $text = $imports -join [Environment]::NewLine
  foreach ($api in $forbiddenApis) {
    if ($text -match "(?im)\b$([regex]::Escape($api))\b") {
      throw "$name contains forbidden post-XP API import: $api"
    }
  }
}

$executables = @($stockExe, $zeroExe, $mimallocExe)
foreach ($exe in $executables) {
  Audit-XpExe $exe
}

Get-ChildItem -LiteralPath $runtime -File | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
  "$($_.Name)|$($_.Length)|sha256=$hash"
} | Sort-Object | Set-Content -Encoding utf8 (Join-Path $diag 'runtime-hashes.txt')

@'
@echo off
setlocal
set COMMON=--live-mib 512 --burst-mib 256 --cycles 30 --gc-hold-per-cycle 2 --sleep-ms 100 --stop-free-mib 128 --stop-aligned-mib 2

echo Running mozjemalloc stock retention...
allocator-va-stress-mozjemalloc-128.exe --label mozjemalloc-128 %COMMON% > mozjemalloc-128.log 2>&1

echo Running mozjemalloc zero retention...
allocator-va-stress-mozjemalloc-0.exe --label mozjemalloc-0 %COMMON% > mozjemalloc-0.log 2>&1

echo Running mimalloc 2.5.2...
allocator-va-stress-mimalloc-2.5.2.exe --label mimalloc-2.5.2 %COMMON% > mimalloc-2.5.2.log 2>&1

echo Complete. Send all three *.log files for comparison.
endlocal
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'run-all.cmd')

@'
XP x86 allocator VA stress PoC

Variants:
  allocator-va-stress-mozjemalloc-128.exe
    Firefox 153 mozjemalloc with stock gRecycleLimit = 128 MiB.

  allocator-va-stress-mozjemalloc-0.exe
    Same Firefox 153 mozjemalloc with only gRecycleLimit changed to 0
    during the focused build.

  allocator-va-stress-mimalloc-2.5.2.exe
    mimalloc v2.5.2 from pinned source commit.

Recommended physical XP run:
  run-all.cmd

The default physical workload keeps a long-lived 512 MiB heap, repeatedly
allocates and frees 256 MiB bursts, exercises cross-thread allocation/free,
and holds two direct 1 MiB-aligned VirtualAlloc chunks per cycle. It stops
before the already-observed near-failure boundary if total free VA reaches
128 MiB or the largest 1 MiB-aligned capacity falls to 2 MiB.

Compare VA metrics, not only Working Set. Hosted CI success is only
build/import/function evidence. Physical XP remains a separate runtime gate.
The zero-retention build is an experiment, not a product setting.
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'README.txt')

Push-Location $runtime
try {
  $smokeArgs = @(
    '--live-mib','64',
    '--burst-mib','32',
    '--cycles','3',
    '--gc-hold-per-cycle','1',
    '--sleep-ms','0',
    '--stop-free-mib','64',
    '--stop-aligned-mib','1'
  )

  foreach ($entry in @(
    @{ File='allocator-va-stress-mozjemalloc-128.exe'; Label='mozjemalloc-128' },
    @{ File='allocator-va-stress-mozjemalloc-0.exe'; Label='mozjemalloc-0' },
    @{ File='allocator-va-stress-mimalloc-2.5.2.exe'; Label='mimalloc-2.5.2' }
  )) {
    $log = Join-Path $diag "hosted-$($entry.Label).txt"
    & ".\$($entry.File)" --label $entry.Label @smokeArgs 2>&1 | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
      throw "Hosted smoke failed for $($entry.Label): $LASTEXITCODE"
    }
    $text = Get-Content $log -Raw
    if ($text -notmatch "RESULT label=$([regex]::Escape($entry.Label)) status=") {
      throw "Hosted smoke produced no RESULT line for $($entry.Label)"
    }
  }
}
finally {
  Pop-Location
}

"allocator_va_stress=GREEN" | Add-Content (Join-Path $diag 'identity.txt')
