$ErrorActionPreference = 'Stop'
$work = Join-Path $env:RUNNER_TEMP 'r3dfox-xp-x32-narrow-yy'
$selected = Join-Path $work 'selected'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }
New-Item -ItemType Directory -Force $selected | Out-Null

$members = @(& lib.exe /nologo /list $env:THUNK_YY_KERNEL32_LIB 2>&1 |
  ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($LASTEXITCODE -ne 0 -or $members.Count -eq 0) { throw 'Cannot enumerate YY XP x86 kernel32.lib' }
$members | Set-Content -Encoding utf8 (Join-Path $work 'yy-kernel32-members.txt')

$implementationPattern = '(?i)[\\/]YY_Thunks_for_' + [regex]::Escape($env:YY_THUNKS_TARGET) + '\.obj$'
$clusterApis = @(
  'GetTickCount64','InitializeCriticalSectionEx','CompareStringOrdinal',
  'GetCurrentProcessorNumber','GetFileInformationByHandleEx','GetFinalPathNameByHandleW',
  'GetLocaleInfoEx','LCIDToLocaleName','LocaleNameToLCID','SetFileInformationByHandle','CancelIoEx',
  'CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread',
  'GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear','GetUserPreferredUILanguages',
  'GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete',
  'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime',
  'TryAcquireSRWLockExclusive','FlsGetValue'
)
$wanted = @(
  @{ Key='process-direct'; Pattern='(?i)[\\/]_ProcessPrng@8\.obj$' },
  @{ Key='process-import'; Pattern='(?i)[\\/]_ProcessPrng@8\.obi$' },
  @{ Key='precise-direct'; Pattern='(?i)[\\/]_GetSystemTimePreciseAsFileTime@4\.obj$' },
  @{ Key='precise-import'; Pattern='(?i)[\\/]_GetSystemTimePreciseAsFileTime@4\.obi$' },
  @{ Key='flsalloc-direct'; Pattern='(?i)[\\/]_FlsAlloc@4\.obj$' },
  @{ Key='flsalloc-import'; Pattern='(?i)[\\/]_FlsAlloc@4\.obi$' },
  @{ Key='flsfree-direct'; Pattern='(?i)[\\/]_FlsFree@4\.obj$' },
  @{ Key='flsfree-import'; Pattern='(?i)[\\/]_FlsFree@4\.obi$' },
  @{ Key='flsset-direct'; Pattern='(?i)[\\/]_FlsSetValue@8\.obj$' },
  @{ Key='flsset-import'; Pattern='(?i)[\\/]_FlsSetValue@8\.obi$' },
  @{ Key='isfiber-direct'; Pattern='(?i)[\\/]_IsThreadAFiber@0\.obj$' },
  @{ Key='isfiber-import'; Pattern='(?i)[\\/]_IsThreadAFiber@0\.obi$' },
  @{ Key='stackguarantee-direct'; Pattern='(?i)[\\/]_SetThreadStackGuarantee@4\.obj$' },
  @{ Key='stackguarantee-import'; Pattern='(?i)[\\/]_SetThreadStackGuarantee@4\.obi$' },
  @{ Key='srw-acq-ex-direct'; Pattern='(?i)[\\/]_AcquireSRWLockExclusive@4\.obj$' },
  @{ Key='srw-acq-ex-import'; Pattern='(?i)[\\/]_AcquireSRWLockExclusive@4\.obi$' },
  @{ Key='srw-acq-sh-direct'; Pattern='(?i)[\\/]_AcquireSRWLockShared@4\.obj$' },
  @{ Key='srw-acq-sh-import'; Pattern='(?i)[\\/]_AcquireSRWLockShared@4\.obi$' },
  @{ Key='srw-rel-ex-direct'; Pattern='(?i)[\\/]_ReleaseSRWLockExclusive@4\.obj$' },
  @{ Key='srw-rel-ex-import'; Pattern='(?i)[\\/]_ReleaseSRWLockExclusive@4\.obi$' },
  @{ Key='srw-rel-sh-direct'; Pattern='(?i)[\\/]_ReleaseSRWLockShared@4\.obj$' },
  @{ Key='srw-rel-sh-import'; Pattern='(?i)[\\/]_ReleaseSRWLockShared@4\.obi$' },
  @{ Key='srw-init-direct'; Pattern='(?i)[\\/]_InitializeSRWLock@4\.obj$' },
  @{ Key='srw-init-import'; Pattern='(?i)[\\/]_InitializeSRWLock@4\.obi$' },
  @{ Key='cv-init-direct'; Pattern='(?i)[\\/]_InitializeConditionVariable@4\.obj$' },
  @{ Key='cv-init-import'; Pattern='(?i)[\\/]_InitializeConditionVariable@4\.obi$' },
  @{ Key='cv-sleep-cs-direct'; Pattern='(?i)[\\/]_SleepConditionVariableCS@12\.obj$' },
  @{ Key='cv-sleep-cs-import'; Pattern='(?i)[\\/]_SleepConditionVariableCS@12\.obi$' },
  @{ Key='cv-sleep-srw-direct'; Pattern='(?i)[\\/]_SleepConditionVariableSRW@16\.obj$' },
  @{ Key='cv-sleep-srw-import'; Pattern='(?i)[\\/]_SleepConditionVariableSRW@16\.obi$' },
  @{ Key='cv-wake-all-direct'; Pattern='(?i)[\\/]_WakeAllConditionVariable@4\.obj$' },
  @{ Key='cv-wake-all-import'; Pattern='(?i)[\\/]_WakeAllConditionVariable@4\.obi$' },
  @{ Key='cv-wake-one-direct'; Pattern='(?i)[\\/]_WakeConditionVariable@4\.obj$' },
  @{ Key='cv-wake-one-import'; Pattern='(?i)[\\/]_WakeConditionVariable@4\.obi$' },
  @{ Key='implementation'; Pattern=$implementationPattern }
)
foreach ($api in $clusterApis) {
  $escaped = [regex]::Escape($api)
  $wanted += @{ Key="cluster-$api-direct"; Pattern="(?i)[\\/]_${escaped}@\d+\.obj$" }
  $wanted += @{ Key="cluster-$api-import"; Pattern="(?i)[\\/]_${escaped}@\d+\.obi$" }
}

$objects = @()
$memberMap = [System.Collections.Generic.List[string]]::new()
foreach ($spec in $wanted) {
  $matches = @($members | Where-Object { $_ -match $spec.Pattern })
  if ($matches.Count -ne 1) { throw "Expected one $($spec.Key) member; found $($matches.Count)" }
  $dir = Join-Path $selected $spec.Key
  New-Item -ItemType Directory -Force $dir | Out-Null
  Push-Location $dir
  try {
    & lib.exe /nologo "/extract:$($matches[0])" $env:THUNK_YY_KERNEL32_LIB *> extract.log
    if ($LASTEXITCODE -ne 0) { throw "Failed to extract $($matches[0])" }
  } finally { Pop-Location }
  $file = Get-ChildItem -LiteralPath $dir -File |
    Where-Object { $_.Name -ne 'extract.log' } |
    Sort-Object Length -Descending | Select-Object -First 1
  if (-not $file) { throw "No extracted object for $($spec.Key)" }
  $dst = Join-Path $dir 'member.obj'
  Copy-Item -Force $file.FullName $dst
  (& dumpbin.exe /nologo /symbols $dst 2>&1 | Out-String) |
    Set-Content -Encoding utf8 (Join-Path $dir 'symbols.txt')
  $objects += $dst
  $memberMap.Add("$($spec.Key)|$($matches[0])")
}
$memberMap | Set-Content -Encoding utf8 (Join-Path $work 'selected-members.txt')

$narrow = Join-Path $work 'yy-xp-rust-provider.lib'
& lib.exe /nologo "/out:$narrow" @objects
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $narrow)) { throw 'Failed to build narrow YY XP x86 provider' }
$symbols = (& dumpbin.exe /nologo /linkermember:1 $narrow 2>&1 | Out-String)
$symbols | Set-Content -Encoding utf8 (Join-Path $work 'narrow-provider-symbols.txt')
foreach ($required in @(
  'YY_Thunks_ProcessPrng','YY_Thunks_GetSystemTimePreciseAsFileTime',
  'YY_Thunks_FlsAlloc','YY_Thunks_FlsFree','YY_Thunks_FlsSetValue',
  'YY_Thunks_IsThreadAFiber','YY_Thunks_SetThreadStackGuarantee',
  'YY_Thunks_AcquireSRWLockExclusive','YY_Thunks_AcquireSRWLockShared',
  'YY_Thunks_ReleaseSRWLockExclusive','YY_Thunks_ReleaseSRWLockShared',
  'YY_Thunks_InitializeSRWLock','YY_Thunks_InitializeConditionVariable',
  'YY_Thunks_SleepConditionVariableCS','YY_Thunks_SleepConditionVariableSRW',
  'YY_Thunks_WakeAllConditionVariable','YY_Thunks_WakeConditionVariable',
  'YY_Thunks_EventRegister','YY_Thunks_EventUnregister',
  'YY_Thunks_EventWrite','YY_Thunks_EventWriteTransfer','YY_Thunks_RegGetValueW'
)) {
  if ($symbols.IndexOf($required, [System.StringComparison]::Ordinal) -lt 0) { throw "Narrow provider missing $required" }
}
foreach ($api in $clusterApis) {
  $required = "YY_Thunks_$api"
  if ($symbols.IndexOf($required, [System.StringComparison]::Ordinal) -lt 0) { throw "Narrow provider missing $required" }
}
foreach ($broad in @('LockResource','__imp_LockResource')) {
  if ($symbols -match ('(?m)(?:^|\s)' + [regex]::Escape($broad) + '\s*$')) { throw "Narrow provider exposes broad symbol $broad" }
}

"NARROW_YY_LIB=$narrow" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
