$ErrorActionPreference = 'Stop'

$forbiddenApis = @(
  'FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'AcquireSRWLockExclusive','AcquireSRWLockShared',
  'ReleaseSRWLockExclusive','ReleaseSRWLockShared',
  'InitializeSRWLock','InitializeConditionVariable',
  'SleepConditionVariableCS','SleepConditionVariableSRW',
  'WakeAllConditionVariable','WakeConditionVariable',
  'TryAcquireSRWLockExclusive','TryAcquireSRWLockShared'
)
$forbiddenDllPatterns = @(
  '^(?i)(api-ms-win-|ext-ms-)',
  '^(?i)KERNELBASE\.dll$',
  '^(?i)BCRYPT(?:PRIMITIVES)?\.dll$',
  '^(?i)COMBASE\.dll$',
  '^(?i)NCRYPT\.dll$',
  '^(?i)VCRUNTIME140(?:_1)?\.dll$'
)
$report = [System.Collections.Generic.List[string]]::new()
foreach ($dll in @('ucrtbase.dll','msvcp140.dll')) {
  $path = Join-Path $env:MSVCR14X_RELEASE $dll
  if (-not (Test-Path $path)) { throw "XP CRT contract missing runtime: $path" }

  $headers = @(& dumpbin.exe /nologo /headers $path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed: $path" }
  $headers | Set-Content -Encoding utf8 (Join-Path 'diagnostics' "$dll-headers.txt")
  $machine = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+ machine ' } | Select-Object -First 1
  if (-not $machine -or $machine -notmatch '(?i)^\s*14C machine \(x86\)') { throw "$dll is not x86 machine 14C" }
  $versionLine = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
  if (-not $versionLine -or $versionLine -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') { throw "Cannot parse subsystem version: $dll" }
  $version = [version]("$([int]$matches[1]).$([int]$matches[2])")
  if ($version -gt [version]'5.1') { throw "$dll subsystem $version is newer than XP x86 5.01" }

  $imports = @(& dumpbin.exe /nologo /imports $path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /imports failed: $path" }
  $imports | Set-Content -Encoding utf8 (Join-Path 'diagnostics' "$dll-imports.txt")
  $text = $imports -join "`n"
  foreach ($api in $forbiddenApis) {
    if ($text -match ('(?m)\b' + [regex]::Escape($api) + '\b')) { throw "$dll retains forbidden XP direct import $api" }
  }
  foreach ($line in $imports) {
    if ($line -notmatch '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') { continue }
    $dep = $matches[1]
    foreach ($pattern in $forbiddenDllPatterns) {
      if ($dep -match $pattern) { throw "$dll retains forbidden XP dependency $dep" }
    }
  }
  $hash = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
  $report.Add("$dll|sha256=$hash|subsystem=$version|machine=x86")
}
$report | Set-Content -Encoding utf8 diagnostics\msvcr14x-xp-contract.txt
