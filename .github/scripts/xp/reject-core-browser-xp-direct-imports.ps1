$ErrorActionPreference = 'Stop'

$bin = Join-Path $env:OBJDIR 'dist\bin'
$diag = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-sync-import-gate'
New-Item -ItemType Directory -Force $diag | Out-Null

$apis = @(
  'GetTickCount64','InitializeCriticalSectionEx','CompareStringOrdinal','GetCurrentProcessorNumber','GetFileInformationByHandleEx','GetFinalPathNameByHandleW',
  'GetLocaleInfoEx','LCIDToLocaleName','LocaleNameToLCID','SetFileInformationByHandle','CancelIoEx','CreateWaitableTimerExW','CancelSynchronousIo',
  'GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
  'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete',
  'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'AcquireSRWLockExclusive','AcquireSRWLockShared','ReleaseSRWLockExclusive','ReleaseSRWLockShared','InitializeSRWLock','InitializeConditionVariable',
  'SleepConditionVariableCS','SleepConditionVariableSRW','WakeAllConditionVariable','WakeConditionVariable','NtCancelIoFileEx'
)

$targets = @('r3dfox.exe','xul.dll','mozglue.dll','plugin-container.exe')
$hits = [System.Collections.Generic.List[string]]::new()

foreach ($name in $targets) {
  $path = Join-Path $bin $name
  if (-not (Test-Path $path)) {
    throw "Core browser PE missing for synchronization gate: $path"
  }

  $raw = (& dumpbin.exe /nologo /imports $path 2>&1 | Out-String)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /imports failed: $path"
  }

  $raw | Set-Content -Encoding utf8 (Join-Path $diag "$name-imports.txt")
  foreach ($api in $apis) {
    if ($raw.IndexOf($api,[System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      $hits.Add("$name|$api")
    }
  }
}

$hits | Set-Content -Encoding utf8 (Join-Path $diag 'surviving-sync-imports.txt')
if ($hits.Count -gt 0) {
  throw 'Core browser imports survived the proven SRW/KERNEL32/NTDLL YY integration; see xp-x32-sync-import-gate/surviving-sync-imports.txt'
}
