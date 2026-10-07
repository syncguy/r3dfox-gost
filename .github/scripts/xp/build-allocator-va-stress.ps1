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

function Find-MozMake() {
  $candidates = @()

  $command = Get-Command mozmake.exe -ErrorAction SilentlyContinue
  if ($command) {
    $candidates += $command.Source
  }

  if ($env:MOZBUILD_STATE_PATH) {
    $candidates += (Join-Path $env:MOZBUILD_STATE_PATH 'mozmake\mozmake.exe')
  }

  if ($env:USERPROFILE) {
    $candidates += (Join-Path $env:USERPROFILE '.mozbuild\mozmake\mozmake.exe')
  }

  foreach ($candidate in ($candidates | Select-Object -Unique)) {
    if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  throw 'Mozilla-managed mozmake.exe was not found in PATH or the mozbuild state directory'
}

function Find-StressExe([string]$ObjDir) {
  $candidates = @(Get-ChildItem -LiteralPath $ObjDir -Recurse -File -Filter 'allocator-va-stress.exe')
  if (-not $candidates.Count) {
    throw "allocator-va-stress.exe not found under $ObjDir"
  }

  $dist = @($candidates | Where-Object {
    $_.FullName -match '(?i)[\\/]dist[\\/]bin[\\/]'
  })
  if ($dist.Count) {
    return $dist[0].FullName
  }
  return $candidates[0].FullName
}

function Write-BrowserMozconfig([string]$Path, [string]$ObjDirName) {
  @'
mk_add_options AUTOCLOBBER=1
mk_add_options MOZ_OBJDIR=@TOPSRCDIR@/OBJDIR_PLACEHOLDER
mk_add_options MOZ_PARALLEL_BUILD=4
mk_add_options MOZ_MAKE_FLAGS="-j4"
ac_add_options --target=i686
ac_add_options --enable-application=browser
ac_add_options --disable-artifact-builds
ac_add_options --disable-debug
ac_add_options --disable-tests
ac_add_options --disable-sandbox
ac_add_options --enable-jemalloc
ac_add_options --enable-replace-malloc
ac_add_options --enable-allocator-va-stress
ac_add_options --enable-optimize
ac_add_options --enable-release
ac_add_options --disable-eme
ac_add_options --disable-backgroundtasks
ac_add_options --disable-bits-download
ac_add_options --disable-crashreporter
ac_add_options --disable-default-browser-agent
ac_add_options --disable-maintenance-service
ac_add_options --disable-necko-wifi
ac_add_options --disable-notification-server
ac_add_options --disable-parental-controls
ac_add_options --without-onnx-runtime
ac_add_options --without-wasm-sandboxed-libraries
ac_add_options --disable-update-agent
ac_add_options --disable-updater
export CFLAGS="$CFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
export CXXFLAGS="$CXXFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
export MOZ_CRASHREPORTER=0
export MOZ_DATA_REPORTING=0
export MOZ_TELEMETRY_REPORTING=
'@.Replace('OBJDIR_PLACEHOLDER', $ObjDirName) | Set-Content -Encoding ascii $Path
}

function Build-MozJemallocVariant(
  [string]$Label,
  [string]$ObjDirName,
  [string]$DestinationName
) {
  $mozconfig = Join-Path $env:GITHUB_WORKSPACE ".mozconfig-$Label"
  Write-BrowserMozconfig $mozconfig $ObjDirName
  $env:MOZCONFIG = $mozconfig

  Invoke-Checked "mach configure ($Label)" { .\mach.ps1 configure }

  Invoke-Checked "mach export ($Label)" {
    .\mach.ps1 build pre-export export
  }

  $objDir = Join-Path $env:GITHUB_WORKSPACE $ObjDirName
  $rootTarget = 'memory/allocator_va_stress/target'
  $dryRunLog = Join-Path $diag "$Label-root-deps-dry-run.txt"
  $mozmake = Find-MozMake

  Copy-Item -Force (Join-Path $objDir 'root.mk') (Join-Path $diag "$Label-root.mk")
  Copy-Item -Force (Join-Path $objDir 'root-deps.mk') (Join-Path $diag "$Label-root-deps.mk")

  $savedErrorActionPreference = $ErrorActionPreference
  try {
    # Windows PowerShell 5 promotes native stderr records to terminating errors
    # when ErrorActionPreference=Stop. A GNU make -n traversal can legitimately
    # print recursive submake failures because prerequisite libraries are only
    # planned, not created. Keep that output as diagnostics and let the real
    # root build below be the dependency-closure gate.
    $ErrorActionPreference = 'Continue'
    & $mozmake -C $objDir -n -k $rootTarget 2>&1 |
      Tee-Object -FilePath $dryRunLog
    $dryRunExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $savedErrorActionPreference
  }

  # GNU make still executes recursive $(MAKE) commands under -n. The root
  # dry-run therefore may enter the harness submake before cross-directory
  # libraries such as pure_virtual.lib physically exist. Treat the dry-run as
  # a dependency-plan diagnostic; the real root build below is the closure
  # gate. Keep the exit code in diagnostics instead of requiring zero here.
  "root_dependency_dry_run_exit_$Label=$dryRunExit" |
    Add-Content (Join-Path $diag 'identity.txt')

  $dryRunText = Get-Content $dryRunLog -Raw
  if ($dryRunText -notmatch '(?i)build[\\/]pure_virtual') {
    throw "root dependency dry-run ($Label) did not include pure_virtual"
  }
  if ($dryRunText -match '(?i)toolkit[\\/]library|xul\.dll') {
    throw "root dependency dry-run ($Label) unexpectedly reaches full xul/browser linkage"
  }

  Invoke-Checked "root focused build ($Label)" {
    & $mozmake -C $objDir -j4 $rootTarget
  }

  $exe = Find-StressExe $objDir
  $dst = Join-Path $runtime $DestinationName
  Copy-Item -Force $exe $dst

  Invoke-Checked "editbin ($Label)" {
    & editbin.exe /NOLOGO /SUBSYSTEM:CONSOLE,5.01 /LARGEADDRESSAWARE $dst
  }
}

$constantsPath = Join-Path $env:GITHUB_WORKSPACE 'memory\build\Constants.h'
$constantsOriginal = [System.IO.File]::ReadAllText($constantsPath)
$expectedRecycle = 'static constexpr size_t gRecycleLimit = 128_MiB;'
if (-not $constantsOriginal.Contains($expectedRecycle)) {
  throw 'Expected mozjemalloc gRecycleLimit definition not found'
}

$stockExe = Join-Path $runtime 'allocator-va-stress-mozjemalloc-128.exe'
$zeroExe = Join-Path $runtime 'allocator-va-stress-mozjemalloc-0.exe'

try {
  Build-MozJemallocVariant -Label 'mozjemalloc-128' -ObjDirName 'obj-memory-va-stock' -DestinationName 'allocator-va-stress-mozjemalloc-128.exe'

  $zeroSource = $constantsOriginal.Replace(
    $expectedRecycle,
    'static constexpr size_t gRecycleLimit = 0;'
  )
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($constantsPath, $zeroSource, $utf8NoBom)

  Build-MozJemallocVariant -Label 'mozjemalloc-0' -ObjDirName 'obj-memory-va-zero' -DestinationName 'allocator-va-stress-mozjemalloc-0.exe'
}
finally {
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($constantsPath, $constantsOriginal, $utf8NoBom)
}

$restored = [System.IO.File]::ReadAllText($constantsPath)
if ($restored -ne $constantsOriginal) {
  throw 'Constants.h was not restored after retention-variant build'
}
if ((git status --porcelain -- memory/build/Constants.h)) {
  throw 'Constants.h remains modified after retention-variant build'
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

function Build-MimallocVariant(
  [string]$Label,
  [string]$ObjectName,
  [string]$ExeName,
  [string]$GlueName,
  [string[]]$ExtraDefines
) {
  $obj = Join-Path $env:RUNNER_TEMP $ObjectName
  $compileLog = Join-Path $diag "$Label-compile.txt"

  $compileArgs = @(
    '/nologo','/c','/O2','/MD','/TC',
    '/DMI_STATIC_LIB','/D_WIN32_WINNT=0x0501','/DWINVER=0x0501'
  )
  if ($ExtraDefines) {
    $compileArgs += $ExtraDefines
  }
  $compileArgs += @(
    "/I$mimallocRoot\include",
    "$mimallocRoot\src\static.c",
    "/Fo:$obj"
  )

  & cl.exe @compileArgs 2>&1 | Tee-Object -FilePath $compileLog
  if ($LASTEXITCODE -ne 0) {
    throw "$Label static mimalloc compile failed: $LASTEXITCODE"
  }

  $exe = Join-Path $runtime $ExeName
  $harness = Join-Path $env:GITHUB_WORKSPACE 'memory\allocator_va_stress\AllocatorVaStress.cpp'
  $harnessLog = Join-Path $diag "$Label-harness-link.txt"
  $harnessArgs = @(
    '/nologo','/O2','/EHsc','/MD','/std:c++17',
    '/DALLOCATOR_MIMALLOC','/D_WIN32_WINNT=0x0501','/DWINVER=0x0501',
    "/I$mimallocRoot\include",
    $harness,$obj,
    '/link','/SUBSYSTEM:CONSOLE,5.01','/LARGEADDRESSAWARE',
    "/OUT:$exe"
  )

  & cl.exe @harnessArgs 2>&1 | Tee-Object -FilePath $harnessLog
  if ($LASTEXITCODE -ne 0) {
    throw "$Label harness link failed: $LASTEXITCODE"
  }

  $glue = Join-Path $runtime $GlueName
  $glueSource = Join-Path $env:GITHUB_WORKSPACE 'memory\allocator_va_stress\MimallocReplaceMalloc.cpp'
  $mozillaInclude = Join-Path $env:GITHUB_WORKSPACE 'obj-memory-va-stock\dist\include'
  $memoryBuildInclude = Join-Path $env:GITHUB_WORKSPACE 'memory\build'

  if (-not (Test-Path $mozillaInclude)) {
    throw "Mozilla generated include directory missing: $mozillaInclude"
  }

  $defPath = Join-Path $env:RUNNER_TEMP "$Label.def"
  @"
LIBRARY "$([System.IO.Path]::GetFileNameWithoutExtension($GlueName))"
EXPORTS
    replace_init
    allocator_va_stress_replace_probe
"@ | Set-Content -Encoding ascii $defPath

  $glueLog = Join-Path $diag "$Label-glue-link.txt"
  $glueArgs = @(
    '/nologo','/O2','/EHsc','/MD','/std:c++17','/LD',
    '/DMI_STATIC_LIB','/D_WIN32_WINNT=0x0501','/DWINVER=0x0501',
    "/I$mimallocRoot\include",
    "/I$mozillaInclude",
    "/I$memoryBuildInclude",
    $glueSource,$obj,
    '/link','/SUBSYSTEM:WINDOWS,5.01','/LARGEADDRESSAWARE',
    "/DEF:$defPath",
    "/OUT:$glue"
  )

  & cl.exe @glueArgs 2>&1 | Tee-Object -FilePath $glueLog
  if ($LASTEXITCODE -ne 0) {
    throw "$Label Firefox replacement glue link failed: $LASTEXITCODE"
  }
}

$mimallocDefaultExe = Join-Path $runtime 'allocator-va-stress-mimalloc-2.5.2-default.exe'
$mimallocDefaultGlue = Join-Path $runtime 'mimalloc_glue_default.dll'
Build-MimallocVariant -Label 'mimalloc-2.5.2-default' -ObjectName 'mimalloc-2.5.2-default.obj' -ExeName 'allocator-va-stress-mimalloc-2.5.2-default.exe' -GlueName 'mimalloc_glue_default.dll' -ExtraDefines @()

$mimallocNoArenaExe = Join-Path $runtime 'allocator-va-stress-mimalloc-2.5.2-noarena.exe'
$mimallocNoArenaGlue = Join-Path $runtime 'mimalloc_glue_noarena.dll'
Build-MimallocVariant -Label 'mimalloc-2.5.2-noarena' -ObjectName 'mimalloc-2.5.2-noarena.obj' -ExeName 'allocator-va-stress-mimalloc-2.5.2-noarena.exe' -GlueName 'mimalloc_glue_noarena.dll' -ExtraDefines @('/DMI_DEFAULT_ARENA_RESERVE=0','/DMI_DEFAULT_DISALLOW_ARENA_ALLOC=1')

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

function Audit-XpPe([string]$Path) {
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
    if ($_ -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') {
      $matches[1]
    }
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

$executables = @($stockExe,$zeroExe,$mimallocDefaultExe,$mimallocNoArenaExe)
foreach ($exe in $executables) {
  Audit-XpPe $exe
}

$replacementDlls = @($mimallocDefaultGlue,$mimallocNoArenaGlue)
foreach ($dll in $replacementDlls) {
  Audit-XpPe $dll

  $name = [System.IO.Path]::GetFileNameWithoutExtension($dll)
  $exportsPath = Join-Path $diag "$name-exports.txt"
  $exports = @(& dumpbin.exe /nologo /exports $dll 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /exports failed for $dll"
  }
  $exports | Set-Content -Encoding utf8 $exportsPath

  if (-not ($exports | Where-Object { $_ -match '(?i)(^|\s)replace_init\s*$' })) {
    throw "$name does not export exact replace_init required by Firefox"
  }
  if (-not ($exports | Where-Object { $_ -match '(?i)(^|\s)allocator_va_stress_replace_probe\s*$' })) {
    throw "$name does not export allocator_va_stress_replace_probe"
  }
}

Get-ChildItem -LiteralPath $runtime -File | ForEach-Object {
  $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
  "$($_.Name)|$($_.Length)|sha256=$hash"
} | Sort-Object | Set-Content -Encoding utf8 (Join-Path $diag 'runtime-hashes.txt')

@'
@echo off
setlocal
set MOZ_REPLACE_MALLOC_LIB=
set MIMALLOC_ARENA_RESERVE=
set MIMALLOC_DISALLOW_ARENA_ALLOC=
set MIMALLOC_RETRY_ON_OOM=
set MIMALLOC_PURGE_DECOMMITS=
set MIMALLOC_EAGER_COMMIT=
set MIMALLOC_PURGE_DELAY=
set MIMALLOC_RESERVE_HUGE_OS_PAGES=
set COMMON=--live-mib 416 --survivor-mib 32 --burst-mib 256 --cycles 30 --gc-hold-per-cycle 2 --sleep-ms 100 --max-ms 90000 --stop-free-mib 64 --stop-aligned-mib 0

echo Repeat 1/3
allocator-va-stress-mozjemalloc-128.exe --label mozjemalloc-128-r1 %COMMON% > mozjemalloc-128-r1.log 2>&1
allocator-va-stress-mozjemalloc-0.exe --label mozjemalloc-0-r1 %COMMON% > mozjemalloc-0-r1.log 2>&1
allocator-va-stress-mimalloc-2.5.2-default.exe --label mimalloc-default-r1 %COMMON% > mimalloc-default-r1.log 2>&1
allocator-va-stress-mimalloc-2.5.2-noarena.exe --label mimalloc-noarena-r1 %COMMON% > mimalloc-noarena-r1.log 2>&1

echo Repeat 2/3
allocator-va-stress-mimalloc-2.5.2-noarena.exe --label mimalloc-noarena-r2 %COMMON% > mimalloc-noarena-r2.log 2>&1
allocator-va-stress-mimalloc-2.5.2-default.exe --label mimalloc-default-r2 %COMMON% > mimalloc-default-r2.log 2>&1
allocator-va-stress-mozjemalloc-0.exe --label mozjemalloc-0-r2 %COMMON% > mozjemalloc-0-r2.log 2>&1
allocator-va-stress-mozjemalloc-128.exe --label mozjemalloc-128-r2 %COMMON% > mozjemalloc-128-r2.log 2>&1

echo Repeat 3/3
allocator-va-stress-mozjemalloc-0.exe --label mozjemalloc-0-r3 %COMMON% > mozjemalloc-0-r3.log 2>&1
allocator-va-stress-mozjemalloc-128.exe --label mozjemalloc-128-r3 %COMMON% > mozjemalloc-128-r3.log 2>&1
allocator-va-stress-mimalloc-2.5.2-noarena.exe --label mimalloc-noarena-r3 %COMMON% > mimalloc-noarena-r3.log 2>&1
allocator-va-stress-mimalloc-2.5.2-default.exe --label mimalloc-default-r3 %COMMON% > mimalloc-default-r3.log 2>&1

echo Complete. Send all twelve *.log files for comparison.
endlocal
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'run-all.cmd')

@'
XP x86 allocator VA stress PoC

Standalone allocator modes:
  allocator-va-stress-mozjemalloc-128.exe
    Exact Firefox 153 mozjemalloc with stock gRecycleLimit = 128 MiB.

  allocator-va-stress-mozjemalloc-0.exe
    Same Firefox mozjemalloc with only gRecycleLimit = 0 in focused build.

  allocator-va-stress-mimalloc-2.5.2-default.exe
    Pinned mimalloc 2.5.2 with normal 32-bit arena policy.

  allocator-va-stress-mimalloc-2.5.2-noarena.exe
    Same mimalloc source with automatic arena allocation disabled and
    default arena reserve set to zero.

Recommended physical XP standalone run:
  run-all.cmd

Each mode runs in a fresh process three times with rotated order. The common
workload keeps a mixed-size long-lived heap, staggered survivor generations,
mixed-size bursts, cross-thread ownership transfer and direct 1 MiB-aligned
GC-like mappings. The GC probe follows the Windows Gecko MapAlignedPages
strategy through ordinary mapping, retained-region alignment, over-reserve
slow path and a bounded last-ditch path.

Experimental Firefox replacement DLLs:
  mimalloc_glue_default.dll
  mimalloc_glue_noarena.dll

Both export the exact replace_init ABI expected by Firefox on Windows. They
replace the ordinary malloc family with mimalloc while keeping Firefox
moz_arena_* allocations on native mozjemalloc. free/realloc/usable-size route
by pointer ownership so native arena pointers remain owned by mozjemalloc.

After standalone physical XP acceptance, a browser A/B can be launched with:

  set MOZ_REPLACE_MALLOC_LIB=%~dp0mimalloc_glue_noarena.dll
  r3dfox.exe

or:

  set MOZ_REPLACE_MALLOC_LIB=%~dp0mimalloc_glue_default.dll
  r3dfox.exe

Unset MOZ_REPLACE_MALLOC_LIB to return to native mozjemalloc.

The environment variable is inherited by the browser process tree. This is a
whole-browser allocator experiment, not a web-process-only switch.

Important reporting limitation:
  Native jemalloc statistics and moz_arena_* remain backed by mozjemalloc.
  The mimalloc-owned ordinary heap is therefore not fully represented by
  Firefox's existing jemalloc heap reports. Use external VA/process metrics as
  primary browser A/B evidence.

Hosted CI success is build/import/export/function evidence only. Physical XP
remains the runtime gate. No product allocator or threshold is selected here.
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'README.txt')

$oldReplaceLib = $env:MOZ_REPLACE_MALLOC_LIB
$mimallocRuntimeEnv = @{}
Get-ChildItem Env: | Where-Object {
  $_.Name -like 'MIMALLOC_*' -and $_.Name -notin @('MIMALLOC_VERSION','MIMALLOC_SHA')
} | ForEach-Object {
  $mimallocRuntimeEnv[$_.Name] = $_.Value
  Remove-Item "Env:$($_.Name)" -ErrorAction SilentlyContinue
}
Remove-Item Env:MOZ_REPLACE_MALLOC_LIB -ErrorAction SilentlyContinue

Push-Location $runtime
try {
  $smokeArgs = @(
    '--live-mib','48',
    '--survivor-mib','4',
    '--burst-mib','32',
    '--cycles','3',
    '--gc-hold-per-cycle','1',
    '--sleep-ms','0',
    '--max-ms','30000',
    '--stop-free-mib','64',
    '--stop-aligned-mib','0'
  )

  foreach ($entry in @(
    @{ File='allocator-va-stress-mozjemalloc-128.exe'; Label='mozjemalloc-128' },
    @{ File='allocator-va-stress-mozjemalloc-0.exe'; Label='mozjemalloc-0' },
    @{ File='allocator-va-stress-mimalloc-2.5.2-default.exe'; Label='mimalloc-default' },
    @{ File='allocator-va-stress-mimalloc-2.5.2-noarena.exe'; Label='mimalloc-noarena' }
  )) {
    $log = Join-Path $diag "hosted-$($entry.Label).txt"
    & ".\$($entry.File)" --label $entry.Label @smokeArgs 2>&1 | Tee-Object -FilePath $log
    if ($LASTEXITCODE -ne 0) {
      throw "Hosted smoke failed for $($entry.Label): $LASTEXITCODE"
    }

    $text = Get-Content $log -Raw
    if ($text -notmatch "RESULT label=$([regex]::Escape($entry.Label)) status=completed .*cycles_completed=3 cycles_requested=3") {
      throw "Hosted smoke did not complete all cycles for $($entry.Label)"
    }
    if ($text -match "SNAPSHOT label=$([regex]::Escape($entry.Label)).* complete=0") {
      throw "Hosted smoke produced an incomplete VA snapshot for $($entry.Label)"
    }

    if ($entry.Label -like 'mozjemalloc-*' -and
        $text -notmatch "ARENA_SMOKE label=$([regex]::Escape($entry.Label)) success=1") {
      throw "Hosted native arena ownership smoke failed for $($entry.Label)"
    }

    if ($entry.Label -eq 'mimalloc-default') {
      if ($text -notmatch 'MIMALLOC_POLICY .*arena_reserve_mib=128\.0 .*disallow_arena_alloc=0') {
        throw 'Default mimalloc policy is not the expected 128 MiB arena mode'
      }
    }

    if ($entry.Label -eq 'mimalloc-noarena') {
      if ($text -notmatch 'MIMALLOC_POLICY .*arena_reserve_mib=0\.0 .*disallow_arena_alloc=1') {
        throw 'No-arena mimalloc policy is not zero-reserve/disallowed-arena'
      }
    }
  }

  try {
    foreach ($entry in @(
      @{ Dll='mimalloc_glue_default.dll'; Label='replace-glue-default' },
      @{ Dll='mimalloc_glue_noarena.dll'; Label='replace-glue-noarena' }
    )) {
      $env:MOZ_REPLACE_MALLOC_LIB = Join-Path $runtime $entry.Dll
      $log = Join-Path $diag "hosted-$($entry.Label).txt"

      $replaceArgs = @(
        '--label',$entry.Label,
        '--live-mib','32',
        '--survivor-mib','2',
        '--burst-mib','16',
        '--cycles','2',
        '--gc-hold-per-cycle','1',
        '--sleep-ms','0',
        '--max-ms','20000',
        '--stop-free-mib','64',
        '--stop-aligned-mib','0'
      )
      & $stockExe @replaceArgs 2>&1 | Tee-Object -FilePath $log

      if ($LASTEXITCODE -ne 0) {
        throw "Hosted replace-malloc smoke failed for $($entry.Dll)"
      }

      $text = Get-Content $log -Raw
      if ($text -notmatch "RESULT label=$([regex]::Escape($entry.Label)) status=completed .*cycles_completed=2 cycles_requested=2") {
        throw "Hosted replace-malloc smoke did not complete all cycles for $($entry.Dll)"
      }
      if ($text -match "SNAPSHOT label=$([regex]::Escape($entry.Label)).* complete=0") {
        throw "Hosted replace-malloc smoke produced an incomplete VA snapshot for $($entry.Dll)"
      }
      if ($text -notmatch "ARENA_SMOKE label=$([regex]::Escape($entry.Label)) success=1") {
        throw "Hosted replace-malloc arena ownership smoke failed for $($entry.Dll)"
      }
      if ($text -notmatch "REPLACE_SMOKE label=$([regex]::Escape($entry.Label)) .*success=1") {
        throw "Hosted replace-malloc smoke did not prove replacement activation for $($entry.Dll)"
      }
    }
  }
  finally {
    Remove-Item Env:MOZ_REPLACE_MALLOC_LIB -ErrorAction SilentlyContinue
  }
}
finally {
  Pop-Location
  if ($null -eq $oldReplaceLib) {
    Remove-Item Env:MOZ_REPLACE_MALLOC_LIB -ErrorAction SilentlyContinue
  } else {
    $env:MOZ_REPLACE_MALLOC_LIB = $oldReplaceLib
  }
  foreach ($name in $mimallocRuntimeEnv.Keys) {
    Set-Item "Env:$name" $mimallocRuntimeEnv[$name]
  }
}

"allocator_va_stress=GREEN" | Add-Content (Join-Path $diag 'identity.txt')
"firefox_replace_malloc_glue=GREEN" | Add-Content (Join-Path $diag 'identity.txt')
