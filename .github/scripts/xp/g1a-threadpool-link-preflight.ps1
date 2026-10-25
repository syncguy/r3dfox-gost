# Permanent short x86 link/PE preflight of the *actual G1a split-provider*
# ordering. No Firefox configure/build, no runtime callback execution.
$ErrorActionPreference = 'Stop'
foreach ($name in @('G1A_THREADPOOL_YY_ALIAS_LIB','NARROW_YY_LIB','THUNK_YY_SYNCH_LIB','MSVCR14X_RELEASE')) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if (-not $value -or -not (Test-Path -LiteralPath $value)) {
    throw "Missing exact G1a x86 preflight input $name"
  }
}
$dir = Join-Path $env:RUNNER_TEMP 'g1a-yy-threadpool-short-link'
New-Item -ItemType Directory -Force -Path $dir,'diagnostics' | Out-Null
$apis = @(
  @{Name='CreateThreadpoolWait';Stack=12},
  @{Name='SetThreadpoolWait';Stack=12},
  @{Name='WaitForThreadpoolWaitCallbacks';Stack=8},
  @{Name='CloseThreadpoolWait';Stack=4}
)
$directSrc = @'
typedef void* TPWAIT;
extern TPWAIT __stdcall CreateThreadpoolWait(void*,void*,void*);
extern void __stdcall SetThreadpoolWait(TPWAIT,void*,void*);
extern void __stdcall WaitForThreadpoolWaitCallbacks(TPWAIT,int);
extern void __stdcall CloseThreadpoolWait(TPWAIT);
int __cdecl direct_probe(void) {
  TPWAIT w = CreateThreadpoolWait(0,0,0);
  SetThreadpoolWait(w,0,0);
  WaitForThreadpoolWaitCallbacks(w,1);
  CloseThreadpoolWait(w);
  return w != 0;
}
'@
$importSrc = @'
typedef void* TPWAIT;
extern __declspec(dllimport) TPWAIT __stdcall CreateThreadpoolWait(void*,void*,void*);
extern __declspec(dllimport) void __stdcall SetThreadpoolWait(TPWAIT,void*,void*);
extern __declspec(dllimport) void __stdcall WaitForThreadpoolWaitCallbacks(TPWAIT,int);
extern __declspec(dllimport) void __stdcall CloseThreadpoolWait(TPWAIT);
int __cdecl import_probe(void) {
  TPWAIT w = CreateThreadpoolWait(0,0,0);
  SetThreadpoolWait(w,0,0);
  WaitForThreadpoolWaitCallbacks(w,1);
  CloseThreadpoolWait(w);
  return w != 0;
}
'@
$mainSrc = @'
extern int __cdecl direct_probe(void);
extern int __cdecl import_probe(void);
int __cdecl main(void) {
  return direct_probe() + import_probe();
}
'@
[IO.File]::WriteAllText((Join-Path $dir 'direct.c'),$directSrc)
[IO.File]::WriteAllText((Join-Path $dir 'import.c'),$importSrc)
[IO.File]::WriteAllText((Join-Path $dir 'main.c'),$mainSrc)
foreach($unit in @('direct','import','main')) {
  $source = Join-Path $dir "$unit.c"
  $obj = Join-Path $dir "$unit.obj"
  # Follow the accepted standalone XP probe's /MD CRT linkage contract.
  # /Zl would deliberately strip default libraries from the COFF objects,
  # leaving C++ runtime dependencies of the *YY common implementation*
  # (notably __purecall) unresolved in this real split-provider link.
  & cl.exe /nologo /c /MD /TC /GS- /O2 "/Fo$obj" $source
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $obj)) { throw "MSVC x86 $unit compilation failed" }
  $dump = (& dumpbin.exe /nologo /symbols $obj 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) { throw "Cannot inspect $unit.obj" }
  $dump | Set-Content -Encoding utf8 (Join-Path diagnostics "coff-$unit.txt")
}
# Keep real direct and imported undefined references observable in COFF.
$directSymbols = Get-Content diagnostics\coff-direct.txt -Raw
$importSymbols = Get-Content diagnostics\coff-import.txt -Raw
foreach ($api in $apis) {
  $a = "_$($api.Name)@$($api.Stack)"
  $b = "__imp__$($api.Name)@$($api.Stack)"
  if ($directSymbols.IndexOf($a,[StringComparison]::Ordinal) -lt 0) {
    throw "Direct consumer lost decorated reference: $a"
  }
  if ($importSymbols.IndexOf($b,[StringComparison]::Ordinal) -lt 0) {
    throw "Dllimport consumer lost decorated reference: $b"
  }
}
$exe = Join-Path $dir 'g1a-split-yy-link-only.exe'
$map = Join-Path $dir 'g1a-split-final.map'
$link = Get-Command lld-link.exe -ErrorAction Stop
$args = @(
  '/nologo',
  '/machine:x86',
  '/subsystem:console,5.01',
  '/entry:main',
  '/nodefaultlib:runtimeobject.lib',
  "/libpath:$env:MSVCR14X_RELEASE",
  "/out:$exe",
  "/map:$map",
  (Join-Path $dir 'main.obj'),
  (Join-Path $dir 'direct.obj'),
  (Join-Path $dir 'import.obj'),
  $env:G1A_THREADPOOL_YY_ALIAS_LIB,
  $env:NARROW_YY_LIB,
  $env:THUNK_YY_SYNCH_LIB
)
$record = @(
  "source_under_test=$env:GITHUB_SHA",
  'purpose=real-two-TU-x86-link-of-G1a-split-YY-provider; not runtime',
  'direct_and_dllimport_calls=all_four_threadpool_wait_apis',
  'original_linker=lld-link',
  'original_YY_version=1.2.2',
  'CRT=msvcr14x_pinned_x86_release; MSVC_C=/MD; COFF_defaultlib_records=retained',
  'Firefox_compilation=not_performed',
  'main_production_inputs=not_modified'
)
$record | Set-Content -Encoding utf8 diagnostics\g1a-link-evidence.txt
& $link.Source @args 2>&1 | Tee-Object diagnostics\g1a-link-output.txt
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) {
  throw "Split G1a YY two-TU link failed (lld exit $LASTEXITCODE)"
}
if (-not (Test-Path $map)) { throw "Split G1a YY linker map missing" }
$mapped = Get-Content $map -Raw
$mapped | Set-Content -Encoding utf8 diagnostics\g1a-split-final.map.txt
foreach ($api in $apis) {
  if ($mapped.IndexOf("YY_Thunks_$($api.Name)",[StringComparison]::Ordinal) -lt 0) {
    throw "Split YY link map does not contain fallback target $($api.Name)"
  }
}
$imports = (& dumpbin.exe /nologo /imports $exe 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw "Split G1a import census unavailable" }
$imports | Set-Content -Encoding utf8 diagnostics\g1a-split-imports.txt
foreach ($api in $apis) {
  if ($imports -match "(?im)\b$([regex]::Escape($api.Name))\b") {
    throw "Direct XP import survived two-TU split link: $($api.Name)"
  }
}
foreach ($name in @('AcquireSRWLockExclusive','ReleaseSRWLockExclusive','InitializeSRWLock','ProcessPrng')) {
  if ($imports -match "(?im)\b$([regex]::Escape($name))\b") {
    throw "Transitive XP import survived split link: $name"
  }
}
$headers = (& dumpbin.exe /nologo /headers $exe 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0 -or $headers -notmatch '(?im)^\s*14C machine \(x86\)') {
  throw 'Split G1a x86 machine gate failed'
}
if ($headers -notmatch '(?im)^\s*5\.01\s+subsystem version') {
  throw 'Split G1a XP 5.01 subsystem gate failed'
}
$headers | Set-Content -Encoding utf8 diagnostics\g1a-split-headers.txt
"split_exe_sha256=$((Get-FileHash -Algorithm SHA256 $exe).Hash.ToLowerInvariant())" |
  Add-Content -Encoding utf8 diagnostics\g1a-link-evidence.txt
'PRELIMINARY PASS: four real direct + dllimport symbol chains, split YY link/map and known XP forbidden API absence. DOES NOT validate callback lifetime or Firefox xul.dll.' |
  Add-Content -Encoding utf8 diagnostics\g1a-link-evidence.txt
