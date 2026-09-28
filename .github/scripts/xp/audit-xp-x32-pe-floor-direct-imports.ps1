$ErrorActionPreference = 'Stop'

function Normalize-Api([string]$name) {
  if ($name -match '^_(.+)@\d+$') { return $matches[1] }
  return $name
}

function Read-Binary([System.IO.FileInfo]$binary, [string]$diagRoot, [bool]$allowPostXpSubsystem) {
  $safe = ($binary.FullName.Substring((Resolve-Path (Join-Path $env:OBJDIR 'dist\bin')).Path.Length).TrimStart('\') -replace '[^A-Za-z0-9_.-]', '_')
  $headers = @(& dumpbin.exe /nologo /headers $binary.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed: $($binary.FullName)" }
  $headers | Set-Content -Encoding utf8 (Join-Path $diagRoot "$safe-headers.txt")
  $machine = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+ machine ' } | Select-Object -First 1
  if (-not $machine -or $machine -notmatch '(?i)^\s*14C machine \(x86\)') { throw "$($binary.FullName) is not PE x86 machine 14C" }
  $versionLine = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
  if (-not $versionLine -or $versionLine -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') { throw "Cannot parse subsystem version: $($binary.FullName)" }
  $version = [version]("$([int]$matches[1]).$([int]$matches[2])")
  if (-not $allowPostXpSubsystem -and $version -gt [version]'5.1') { throw "$($binary.FullName) subsystem $version is newer than XP x86 5.01" }
  $importsRaw = @(& dumpbin.exe /nologo /imports $binary.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /imports failed: $($binary.FullName)" }
  $importsRaw | Set-Content -Encoding utf8 (Join-Path $diagRoot "$safe-imports.txt")
  $dlls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $apis = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $delayDlls = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $delayApis = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $mode = 'none'
  $currentDll = $null
  $importsExceptHandler4CommonFromMsvcrt = $false
  foreach ($line in $importsRaw) {
    if ($line -match '^\s*Section contains the following imports:\s*    $entry = $line.Trim()
    if ($entry -match '^[0-9A-Fa-f]+\s+(\S+)$') {
      $api = Normalize-Api $matches[1]
      if ($mode -eq 'direct') {
        [void]$apis.Add($api)
        if ($currentDll -ieq 'msvcrt.dll' -and $api -ieq '_except_handler4_common') {
          $importsExceptHandler4CommonFromMsvcrt = $true
        }
      }
      elseif ($mode -eq 'delay') { [void]$delayApis.Add($api) }
    }
  }
  return @{ Dlls=$dlls; Apis=$apis; DelayDlls=$delayDlls; DelayApis=$delayApis; Subsystem=$version; ImportsExceptHandler4CommonFromMsvcrt=$importsExceptHandler4CommonFromMsvcrt }
}

$diagRoot = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-import-audit'
New-Item -ItemType Directory -Force $diagRoot | Out-Null
$bin = Join-Path $env:OBJDIR 'dist\bin'
$binResolved = (Resolve-Path $bin).Path
$targets = @(Get-ChildItem -LiteralPath $bin -Recurse -File | Where-Object { $_.Extension -in @('.exe','.dll') })
$forbiddenDllPatterns = @('^(?i)(api-ms-win-|ext-ms-)','^(?i)KERNELBASE\.dll$','^(?i)BCRYPTPRIMITIVES\.dll$','^(?i)COMBASE\.dll$','^(?i)NCRYPT\.dll$','^(?i)WEVTAPI\.dll$','^(?i)DWMAPI\.dll$','^(?i)SHCORE\.dll$','^(?i)PATHCCH\.dll$','^(?i)NORMALIZ\.dll$','^(?i)PROPSYS\.dll$','^(?i)DXGI\.dll$','^(?i)VCRUNTIME140(?:_1)?\.dll$')
$privateDwriteApiSets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('api-ms-win-crt-heap-l1-1-0.dll','api-ms-win-crt-math-l1-1-0.dll','api-ms-win-crt-runtime-l1-1-0.dll','api-ms-win-crt-stdio-l1-1-0.dll','api-ms-win-crt-string-l1-1-0.dll')) { [void]$privateDwriteApiSets.Add($name) }
$forbiddenApis = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx','CompareStringEx','CompareStringOrdinal','CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA','CreateMutexExW','CreateSemaphoreExW',
  'CreateSymbolicLinkA','CreateSymbolicLinkW','CreateThreadpool','CreateThreadpoolCleanupGroup','CreateThreadpoolIo','CreateThreadpoolTimer','CreateThreadpoolWait','CreateThreadpoolWork','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'GetActiveProcessorCount','GetCurrentProcessorNumber','GetCurrentProcessorNumberEx','GetFileInformationByHandleEx','GetFinalPathNameByHandleA','GetFinalPathNameByHandleW','GetLocaleInfoEx','GetLogicalProcessorInformationEx',
  'GetMaximumProcessorCount','GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A','GetTempPath2W','GetTickCount64','GetUserDefaultLocaleName','InitializeConditionVariable','InitializeCriticalSectionEx','InitializeSRWLock',
  'IsThreadAFiber','LCIDToLocaleName','LocaleNameToLCID','ProcessPrng','QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive','ReleaseSRWLockShared','SetFileInformationByHandle','SetThreadDescription','SetThreadStackGuarantee',
  'SleepConditionVariableCS','SleepConditionVariableSRW','SubmitThreadpoolWork','TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress','WakeAllConditionVariable','WakeByAddressAll','WakeByAddressSingle','WakeConditionVariable',
  'CreateWaitableTimerExA','CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
  'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart',
  'GetNamedPipeServerProcessId','SetProcessDPIAware','NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop','inet_pton','WSASendMsg','WSCGetProviderInfo',
  'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime'
)
$hits = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[string]]::new()
$delayRows = [System.Collections.Generic.List[string]]::new()
$optionalModernD3dCompilerCount = 0
$optionalModernD3dCompilerRows = [System.Collections.Generic.List[string]]::new()
foreach ($target in $targets) {
  $relativeTarget = $target.FullName.Substring($binResolved.Length).TrimStart('\') -replace '\\','/'
  $isPrivateDwrite = $relativeTarget -ieq 'xpcompat/dwrite/DWrite.dll'
  $isOptionalModernD3dCompiler = $relativeTarget -ieq 'd3dcompiler_47.dll'
  if ($isOptionalModernD3dCompiler) { $optionalModernD3dCompilerCount++ }
  $imports = Read-Binary $target $diagRoot $isOptionalModernD3dCompiler
  if ($isOptionalModernD3dCompiler) {
    $hash = (Get-FileHash -Algorithm SHA256 $target.FullName).Hash.ToLowerInvariant()
    $optionalModernD3dCompilerRows.Add("$($target.FullName)|sha256=$hash|subsystem=$($imports.Subsystem)|role=optional-loadlibrary-fallback-primary")
  } elseif ($imports.ImportsExceptHandler4CommonFromMsvcrt) {
    $hits.Add("$($target.FullName)|API|msvcrt.dll!_except_handler4_common|reason=required-pe-imports-vista-only-msvcrt-entrypoint")
  }
  foreach ($dll in @($imports.Dlls | Sort-Object)) {
    $rows.Add("$($target.FullName)|DLL|$dll")
    if (-not $isOptionalModernD3dCompiler -and $dll -ieq 'd3dcompiler_47.dll') {
      $hits.Add("$($target.FullName)|DLL|$dll|reason=required-pe-must-not-hard-import-optional-modern-compiler")
      continue
    }
    if ($isOptionalModernD3dCompiler) { continue }
    $privateDwriteApiSet = $isPrivateDwrite -and $privateDwriteApiSets.Contains($dll)
    if ($privateDwriteApiSet) { continue }
    foreach ($pattern in $forbiddenDllPatterns) {
      if ($dll -match $pattern) { $hits.Add("$($target.FullName)|DLL|$dll"); break }
    }
  }
  foreach ($api in @($imports.Apis | Sort-Object)) {
    $rows.Add("$($target.FullName)|API|$api")
    if (-not $isPrivateDwrite -and -not $isOptionalModernD3dCompiler -and $forbiddenApis -contains $api) {
      $hits.Add("$($target.FullName)|API|$api")
    }
  }
  foreach ($dll in @($imports.DelayDlls | Sort-Object)) { $delayRows.Add("$($target.FullName)|DLL|$dll") }
  foreach ($api in @($imports.DelayApis | Sort-Object)) { $delayRows.Add("$($target.FullName)|API|$api") }
}
if ($optionalModernD3dCompilerCount -ne 1) {
  throw "Expected exactly one root d3dcompiler_47.dll optional compiler; found $optionalModernD3dCompilerCount"
}
$optionalModernD3dCompilerRows | Set-Content -Encoding utf8 diagnostics\d3dcompiler47-optional-role.txt
$rows | Set-Content -Encoding utf8 xp-x32-direct-imports.txt
$delayRows | Set-Content -Encoding utf8 xp-x32-delay-imports.txt
$hits | Sort-Object -Unique | Set-Content -Encoding utf8 xp-x32-forbidden-direct-imports.txt
if ($hits.Count -gt 0) { throw 'Known direct post-XP imports survived; see xp-x32-forbidden-direct-imports.txt' }
) { $mode = 'direct'; $currentDll = $null; continue }
    if ($line -match '^\s*Section contains the following delay load imports:\s*    $entry = $line.Trim()
    if ($entry -match '^[0-9A-Fa-f]+\s+(\S+)$') {
      $api = Normalize-Api $matches[1]
      if ($mode -eq 'direct') { [void]$apis.Add($api) }
      elseif ($mode -eq 'delay') { [void]$delayApis.Add($api) }
    }
  }
  return @{ Dlls=$dlls; Apis=$apis; DelayDlls=$delayDlls; DelayApis=$delayApis; Subsystem=$version }
}

$diagRoot = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-import-audit'
New-Item -ItemType Directory -Force $diagRoot | Out-Null
$bin = Join-Path $env:OBJDIR 'dist\bin'
$binResolved = (Resolve-Path $bin).Path
$targets = @(Get-ChildItem -LiteralPath $bin -Recurse -File | Where-Object { $_.Extension -in @('.exe','.dll') })
$forbiddenDllPatterns = @('^(?i)(api-ms-win-|ext-ms-)','^(?i)KERNELBASE\.dll$','^(?i)BCRYPTPRIMITIVES\.dll$','^(?i)COMBASE\.dll$','^(?i)NCRYPT\.dll$','^(?i)WEVTAPI\.dll$','^(?i)DWMAPI\.dll$','^(?i)SHCORE\.dll$','^(?i)PATHCCH\.dll$','^(?i)NORMALIZ\.dll$','^(?i)PROPSYS\.dll$','^(?i)DXGI\.dll$','^(?i)VCRUNTIME140(?:_1)?\.dll$')
$privateDwriteApiSets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('api-ms-win-crt-heap-l1-1-0.dll','api-ms-win-crt-math-l1-1-0.dll','api-ms-win-crt-runtime-l1-1-0.dll','api-ms-win-crt-stdio-l1-1-0.dll','api-ms-win-crt-string-l1-1-0.dll')) { [void]$privateDwriteApiSets.Add($name) }
$forbiddenApis = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx','CompareStringEx','CompareStringOrdinal','CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA','CreateMutexExW','CreateSemaphoreExW',
  'CreateSymbolicLinkA','CreateSymbolicLinkW','CreateThreadpool','CreateThreadpoolCleanupGroup','CreateThreadpoolIo','CreateThreadpoolTimer','CreateThreadpoolWait','CreateThreadpoolWork','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'GetActiveProcessorCount','GetCurrentProcessorNumber','GetCurrentProcessorNumberEx','GetFileInformationByHandleEx','GetFinalPathNameByHandleA','GetFinalPathNameByHandleW','GetLocaleInfoEx','GetLogicalProcessorInformationEx',
  'GetMaximumProcessorCount','GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A','GetTempPath2W','GetTickCount64','GetUserDefaultLocaleName','InitializeConditionVariable','InitializeCriticalSectionEx','InitializeSRWLock',
  'IsThreadAFiber','LCIDToLocaleName','LocaleNameToLCID','ProcessPrng','QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive','ReleaseSRWLockShared','SetFileInformationByHandle','SetThreadDescription','SetThreadStackGuarantee',
  'SleepConditionVariableCS','SleepConditionVariableSRW','SubmitThreadpoolWork','TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress','WakeAllConditionVariable','WakeByAddressAll','WakeByAddressSingle','WakeConditionVariable',
  'CreateWaitableTimerExA','CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
  'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart',
  'GetNamedPipeServerProcessId','SetProcessDPIAware','NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop','inet_pton','WSASendMsg','WSCGetProviderInfo',
  'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime','_except_handler4_common'
)
$hits = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[string]]::new()
$delayRows = [System.Collections.Generic.List[string]]::new()
$optionalModernD3dCompilerCount = 0
$optionalModernD3dCompilerRows = [System.Collections.Generic.List[string]]::new()
foreach ($target in $targets) {
  $relativeTarget = $target.FullName.Substring($binResolved.Length).TrimStart('\') -replace '\\','/'
  $isPrivateDwrite = $relativeTarget -ieq 'xpcompat/dwrite/DWrite.dll'
  $isOptionalModernD3dCompiler = $relativeTarget -ieq 'd3dcompiler_47.dll'
  if ($isOptionalModernD3dCompiler) { $optionalModernD3dCompilerCount++ }
  $imports = Read-Binary $target $diagRoot $isOptionalModernD3dCompiler
  if ($isOptionalModernD3dCompiler) {
    $hash = (Get-FileHash -Algorithm SHA256 $target.FullName).Hash.ToLowerInvariant()
    $optionalModernD3dCompilerRows.Add("$($target.FullName)|sha256=$hash|subsystem=$($imports.Subsystem)|role=optional-loadlibrary-fallback-primary")
  }
  foreach ($dll in @($imports.Dlls | Sort-Object)) {
    $rows.Add("$($target.FullName)|DLL|$dll")
    if (-not $isOptionalModernD3dCompiler -and $dll -ieq 'd3dcompiler_47.dll') {
      $hits.Add("$($target.FullName)|DLL|$dll|reason=required-pe-must-not-hard-import-optional-modern-compiler")
      continue
    }
    if ($isOptionalModernD3dCompiler) { continue }
    $privateDwriteApiSet = $isPrivateDwrite -and $privateDwriteApiSets.Contains($dll)
    if ($privateDwriteApiSet) { continue }
    foreach ($pattern in $forbiddenDllPatterns) {
      if ($dll -match $pattern) { $hits.Add("$($target.FullName)|DLL|$dll"); break }
    }
  }
  foreach ($api in @($imports.Apis | Sort-Object)) {
    $rows.Add("$($target.FullName)|API|$api")
    if (-not $isPrivateDwrite -and -not $isOptionalModernD3dCompiler -and $forbiddenApis -contains $api) {
      $hits.Add("$($target.FullName)|API|$api")
    }
  }
  foreach ($dll in @($imports.DelayDlls | Sort-Object)) { $delayRows.Add("$($target.FullName)|DLL|$dll") }
  foreach ($api in @($imports.DelayApis | Sort-Object)) { $delayRows.Add("$($target.FullName)|API|$api") }
}
if ($optionalModernD3dCompilerCount -ne 1) {
  throw "Expected exactly one root d3dcompiler_47.dll optional compiler; found $optionalModernD3dCompilerCount"
}
$optionalModernD3dCompilerRows | Set-Content -Encoding utf8 diagnostics\d3dcompiler47-optional-role.txt
$rows | Set-Content -Encoding utf8 xp-x32-direct-imports.txt
$delayRows | Set-Content -Encoding utf8 xp-x32-delay-imports.txt
$hits | Sort-Object -Unique | Set-Content -Encoding utf8 xp-x32-forbidden-direct-imports.txt
if ($hits.Count -gt 0) { throw 'Known direct post-XP imports survived; see xp-x32-forbidden-direct-imports.txt' }
) { $mode = 'delay'; $currentDll = $null; continue }
    if ($line -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*    $entry = $line.Trim()
    if ($entry -match '^[0-9A-Fa-f]+\s+(\S+)$') {
      $api = Normalize-Api $matches[1]
      if ($mode -eq 'direct') { [void]$apis.Add($api) }
      elseif ($mode -eq 'delay') { [void]$delayApis.Add($api) }
    }
  }
  return @{ Dlls=$dlls; Apis=$apis; DelayDlls=$delayDlls; DelayApis=$delayApis; Subsystem=$version }
}

$diagRoot = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-import-audit'
New-Item -ItemType Directory -Force $diagRoot | Out-Null
$bin = Join-Path $env:OBJDIR 'dist\bin'
$binResolved = (Resolve-Path $bin).Path
$targets = @(Get-ChildItem -LiteralPath $bin -Recurse -File | Where-Object { $_.Extension -in @('.exe','.dll') })
$forbiddenDllPatterns = @('^(?i)(api-ms-win-|ext-ms-)','^(?i)KERNELBASE\.dll$','^(?i)BCRYPTPRIMITIVES\.dll$','^(?i)COMBASE\.dll$','^(?i)NCRYPT\.dll$','^(?i)WEVTAPI\.dll$','^(?i)DWMAPI\.dll$','^(?i)SHCORE\.dll$','^(?i)PATHCCH\.dll$','^(?i)NORMALIZ\.dll$','^(?i)PROPSYS\.dll$','^(?i)DXGI\.dll$','^(?i)VCRUNTIME140(?:_1)?\.dll$')
$privateDwriteApiSets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('api-ms-win-crt-heap-l1-1-0.dll','api-ms-win-crt-math-l1-1-0.dll','api-ms-win-crt-runtime-l1-1-0.dll','api-ms-win-crt-stdio-l1-1-0.dll','api-ms-win-crt-string-l1-1-0.dll')) { [void]$privateDwriteApiSets.Add($name) }
$forbiddenApis = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx','CompareStringEx','CompareStringOrdinal','CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA','CreateMutexExW','CreateSemaphoreExW',
  'CreateSymbolicLinkA','CreateSymbolicLinkW','CreateThreadpool','CreateThreadpoolCleanupGroup','CreateThreadpoolIo','CreateThreadpoolTimer','CreateThreadpoolWait','CreateThreadpoolWork','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'GetActiveProcessorCount','GetCurrentProcessorNumber','GetCurrentProcessorNumberEx','GetFileInformationByHandleEx','GetFinalPathNameByHandleA','GetFinalPathNameByHandleW','GetLocaleInfoEx','GetLogicalProcessorInformationEx',
  'GetMaximumProcessorCount','GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A','GetTempPath2W','GetTickCount64','GetUserDefaultLocaleName','InitializeConditionVariable','InitializeCriticalSectionEx','InitializeSRWLock',
  'IsThreadAFiber','LCIDToLocaleName','LocaleNameToLCID','ProcessPrng','QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive','ReleaseSRWLockShared','SetFileInformationByHandle','SetThreadDescription','SetThreadStackGuarantee',
  'SleepConditionVariableCS','SleepConditionVariableSRW','SubmitThreadpoolWork','TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress','WakeAllConditionVariable','WakeByAddressAll','WakeByAddressSingle','WakeConditionVariable',
  'CreateWaitableTimerExA','CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
  'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart',
  'GetNamedPipeServerProcessId','SetProcessDPIAware','NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop','inet_pton','WSASendMsg','WSCGetProviderInfo',
  'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime','_except_handler4_common'
)
$hits = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[string]]::new()
$delayRows = [System.Collections.Generic.List[string]]::new()
$optionalModernD3dCompilerCount = 0
$optionalModernD3dCompilerRows = [System.Collections.Generic.List[string]]::new()
foreach ($target in $targets) {
  $relativeTarget = $target.FullName.Substring($binResolved.Length).TrimStart('\') -replace '\\','/'
  $isPrivateDwrite = $relativeTarget -ieq 'xpcompat/dwrite/DWrite.dll'
  $isOptionalModernD3dCompiler = $relativeTarget -ieq 'd3dcompiler_47.dll'
  if ($isOptionalModernD3dCompiler) { $optionalModernD3dCompilerCount++ }
  $imports = Read-Binary $target $diagRoot $isOptionalModernD3dCompiler
  if ($isOptionalModernD3dCompiler) {
    $hash = (Get-FileHash -Algorithm SHA256 $target.FullName).Hash.ToLowerInvariant()
    $optionalModernD3dCompilerRows.Add("$($target.FullName)|sha256=$hash|subsystem=$($imports.Subsystem)|role=optional-loadlibrary-fallback-primary")
  }
  foreach ($dll in @($imports.Dlls | Sort-Object)) {
    $rows.Add("$($target.FullName)|DLL|$dll")
    if (-not $isOptionalModernD3dCompiler -and $dll -ieq 'd3dcompiler_47.dll') {
      $hits.Add("$($target.FullName)|DLL|$dll|reason=required-pe-must-not-hard-import-optional-modern-compiler")
      continue
    }
    if ($isOptionalModernD3dCompiler) { continue }
    $privateDwriteApiSet = $isPrivateDwrite -and $privateDwriteApiSets.Contains($dll)
    if ($privateDwriteApiSet) { continue }
    foreach ($pattern in $forbiddenDllPatterns) {
      if ($dll -match $pattern) { $hits.Add("$($target.FullName)|DLL|$dll"); break }
    }
  }
  foreach ($api in @($imports.Apis | Sort-Object)) {
    $rows.Add("$($target.FullName)|API|$api")
    if (-not $isPrivateDwrite -and -not $isOptionalModernD3dCompiler -and $forbiddenApis -contains $api) {
      $hits.Add("$($target.FullName)|API|$api")
    }
  }
  foreach ($dll in @($imports.DelayDlls | Sort-Object)) { $delayRows.Add("$($target.FullName)|DLL|$dll") }
  foreach ($api in @($imports.DelayApis | Sort-Object)) { $delayRows.Add("$($target.FullName)|API|$api") }
}
if ($optionalModernD3dCompilerCount -ne 1) {
  throw "Expected exactly one root d3dcompiler_47.dll optional compiler; found $optionalModernD3dCompilerCount"
}
$optionalModernD3dCompilerRows | Set-Content -Encoding utf8 diagnostics\d3dcompiler47-optional-role.txt
$rows | Set-Content -Encoding utf8 xp-x32-direct-imports.txt
$delayRows | Set-Content -Encoding utf8 xp-x32-delay-imports.txt
$hits | Sort-Object -Unique | Set-Content -Encoding utf8 xp-x32-forbidden-direct-imports.txt
if ($hits.Count -gt 0) { throw 'Known direct post-XP imports survived; see xp-x32-forbidden-direct-imports.txt' }
) {
      $currentDll = $matches[1]
      if ($mode -eq 'direct') { [void]$dlls.Add($currentDll) }
      elseif ($mode -eq 'delay') { [void]$delayDlls.Add($currentDll) }
      continue
    }
    $entry = $line.Trim()
    if ($entry -match '^[0-9A-Fa-f]+\s+(\S+)$') {
      $api = Normalize-Api $matches[1]
      if ($mode -eq 'direct') { [void]$apis.Add($api) }
      elseif ($mode -eq 'delay') { [void]$delayApis.Add($api) }
    }
  }
  return @{ Dlls=$dlls; Apis=$apis; DelayDlls=$delayDlls; DelayApis=$delayApis; Subsystem=$version }
}

$diagRoot = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-import-audit'
New-Item -ItemType Directory -Force $diagRoot | Out-Null
$bin = Join-Path $env:OBJDIR 'dist\bin'
$binResolved = (Resolve-Path $bin).Path
$targets = @(Get-ChildItem -LiteralPath $bin -Recurse -File | Where-Object { $_.Extension -in @('.exe','.dll') })
$forbiddenDllPatterns = @('^(?i)(api-ms-win-|ext-ms-)','^(?i)KERNELBASE\.dll$','^(?i)BCRYPTPRIMITIVES\.dll$','^(?i)COMBASE\.dll$','^(?i)NCRYPT\.dll$','^(?i)WEVTAPI\.dll$','^(?i)DWMAPI\.dll$','^(?i)SHCORE\.dll$','^(?i)PATHCCH\.dll$','^(?i)NORMALIZ\.dll$','^(?i)PROPSYS\.dll$','^(?i)DXGI\.dll$','^(?i)VCRUNTIME140(?:_1)?\.dll$')
$privateDwriteApiSets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($name in @('api-ms-win-crt-heap-l1-1-0.dll','api-ms-win-crt-math-l1-1-0.dll','api-ms-win-crt-runtime-l1-1-0.dll','api-ms-win-crt-stdio-l1-1-0.dll','api-ms-win-crt-string-l1-1-0.dll')) { [void]$privateDwriteApiSets.Add($name) }
$forbiddenApis = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx','CompareStringEx','CompareStringOrdinal','CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA','CreateMutexExW','CreateSemaphoreExW',
  'CreateSymbolicLinkA','CreateSymbolicLinkW','CreateThreadpool','CreateThreadpoolCleanupGroup','CreateThreadpoolIo','CreateThreadpoolTimer','CreateThreadpoolWait','CreateThreadpoolWork','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'GetActiveProcessorCount','GetCurrentProcessorNumber','GetCurrentProcessorNumberEx','GetFileInformationByHandleEx','GetFinalPathNameByHandleA','GetFinalPathNameByHandleW','GetLocaleInfoEx','GetLogicalProcessorInformationEx',
  'GetMaximumProcessorCount','GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A','GetTempPath2W','GetTickCount64','GetUserDefaultLocaleName','InitializeConditionVariable','InitializeCriticalSectionEx','InitializeSRWLock',
  'IsThreadAFiber','LCIDToLocaleName','LocaleNameToLCID','ProcessPrng','QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive','ReleaseSRWLockShared','SetFileInformationByHandle','SetThreadDescription','SetThreadStackGuarantee',
  'SleepConditionVariableCS','SleepConditionVariableSRW','SubmitThreadpoolWork','TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress','WakeAllConditionVariable','WakeByAddressAll','WakeByAddressSingle','WakeConditionVariable',
  'CreateWaitableTimerExA','CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
  'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart',
  'GetNamedPipeServerProcessId','SetProcessDPIAware','NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop','inet_pton','WSASendMsg','WSCGetProviderInfo',
  'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime','_except_handler4_common'
)
$hits = [System.Collections.Generic.List[string]]::new()
$rows = [System.Collections.Generic.List[string]]::new()
$delayRows = [System.Collections.Generic.List[string]]::new()
$optionalModernD3dCompilerCount = 0
$optionalModernD3dCompilerRows = [System.Collections.Generic.List[string]]::new()
foreach ($target in $targets) {
  $relativeTarget = $target.FullName.Substring($binResolved.Length).TrimStart('\') -replace '\\','/'
  $isPrivateDwrite = $relativeTarget -ieq 'xpcompat/dwrite/DWrite.dll'
  $isOptionalModernD3dCompiler = $relativeTarget -ieq 'd3dcompiler_47.dll'
  if ($isOptionalModernD3dCompiler) { $optionalModernD3dCompilerCount++ }
  $imports = Read-Binary $target $diagRoot $isOptionalModernD3dCompiler
  if ($isOptionalModernD3dCompiler) {
    $hash = (Get-FileHash -Algorithm SHA256 $target.FullName).Hash.ToLowerInvariant()
    $optionalModernD3dCompilerRows.Add("$($target.FullName)|sha256=$hash|subsystem=$($imports.Subsystem)|role=optional-loadlibrary-fallback-primary")
  }
  foreach ($dll in @($imports.Dlls | Sort-Object)) {
    $rows.Add("$($target.FullName)|DLL|$dll")
    if (-not $isOptionalModernD3dCompiler -and $dll -ieq 'd3dcompiler_47.dll') {
      $hits.Add("$($target.FullName)|DLL|$dll|reason=required-pe-must-not-hard-import-optional-modern-compiler")
      continue
    }
    if ($isOptionalModernD3dCompiler) { continue }
    $privateDwriteApiSet = $isPrivateDwrite -and $privateDwriteApiSets.Contains($dll)
    if ($privateDwriteApiSet) { continue }
    foreach ($pattern in $forbiddenDllPatterns) {
      if ($dll -match $pattern) { $hits.Add("$($target.FullName)|DLL|$dll"); break }
    }
  }
  foreach ($api in @($imports.Apis | Sort-Object)) {
    $rows.Add("$($target.FullName)|API|$api")
    if (-not $isPrivateDwrite -and -not $isOptionalModernD3dCompiler -and $forbiddenApis -contains $api) {
      $hits.Add("$($target.FullName)|API|$api")
    }
  }
  foreach ($dll in @($imports.DelayDlls | Sort-Object)) { $delayRows.Add("$($target.FullName)|DLL|$dll") }
  foreach ($api in @($imports.DelayApis | Sort-Object)) { $delayRows.Add("$($target.FullName)|API|$api") }
}
if ($optionalModernD3dCompilerCount -ne 1) {
  throw "Expected exactly one root d3dcompiler_47.dll optional compiler; found $optionalModernD3dCompilerCount"
}
$optionalModernD3dCompilerRows | Set-Content -Encoding utf8 diagnostics\d3dcompiler47-optional-role.txt
$rows | Set-Content -Encoding utf8 xp-x32-direct-imports.txt
$delayRows | Set-Content -Encoding utf8 xp-x32-delay-imports.txt
$hits | Sort-Object -Unique | Set-Content -Encoding utf8 xp-x32-forbidden-direct-imports.txt
if ($hits.Count -gt 0) { throw 'Known direct post-XP imports survived; see xp-x32-forbidden-direct-imports.txt' }
