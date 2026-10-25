param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('init', 'provider', 'compile', 'link', 'audit', 'audit-runtime', 'hosted', 'bundle')]
    [string]$Stage
)

$ErrorActionPreference = 'Stop'
$apis = @(
    @{ Name='CreateThreadpoolWait'; Stack=12 },
    @{ Name='SetThreadpoolWait'; Stack=12 },
    @{ Name='WaitForThreadpoolWaitCallbacks'; Stack=8 },
    @{ Name='CloseThreadpoolWait'; Stack=4 }
)
# Proven YY XP narrow SRW dependency, private to this standalone test.
$srwClosure = @(
    @{ Name='AcquireSRWLockExclusive'; Stack=4 },
    @{ Name='ReleaseSRWLockExclusive'; Stack=4 },
    @{ Name='InitializeSRWLock'; Stack=4 }
)

switch ($Stage) {
  'init' {
    New-Item -ItemType Directory -Force diagnostics,runtime | Out-Null
    @(
      "controller_sha=$env:GITHUB_SHA",
      "run_id=$env:GITHUB_RUN_ID",
      "run_attempt=$env:GITHUB_RUN_ATTEMPT",
      "yy_thunks_version=$env:YY_THUNKS_VERSION",
      "yy_target=$env:YY_THUNKS_TARGET",
      "msvcr14x_sha=$env:MSVCR14X_SHA",
      'probe_scope=standalone x86 threadpool wait; no Firefox build',
      'hosted_scope=native Windows Threadpool path; XP YY fallback requires physical XP',
      'production_browser_source=not rebuilt or modified'
    ) | Set-Content -Encoding ascii diagnostics\identity.txt
  }
  'provider' {
    $kernel32 = $env:THUNK_YY_KERNEL32_LIB
    if (-not $kernel32 -or -not (Test-Path $kernel32)) { throw 'YY kernel32.lib not provisioned' }
    $members = @(& lib.exe /nologo /list $kernel32 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
    if ($LASTEXITCODE -ne 0 -or $members.Count -eq 0) { throw 'Cannot enumerate YY kernel32.lib' }
    $members | Set-Content -Encoding ascii diagnostics\yy-kernel32-members.txt
    $work = Join-Path $env:RUNNER_TEMP 'yy-threadpool-wait-narrow'
    $selected = Join-Path $work 'selected'
    New-Item -ItemType Directory -Force $selected | Out-Null
    $objects = @()
    $inventory = [System.Collections.Generic.List[string]]::new()

    function Select-And-Extract([string]$key, [string]$regex, [string]$expectedSymbol) {
      $hits = @($members | Where-Object { $_ -match $regex })
      if ($hits.Count -ne 1) { throw "Expected exactly one YY library member for $key, found $($hits.Count)" }
      $dir = Join-Path $selected $key
      New-Item -ItemType Directory -Force $dir | Out-Null
      Push-Location $dir
      try {
        & lib.exe /nologo "/extract:$($hits[0])" $kernel32 *> extract.log
        if ($LASTEXITCODE -ne 0) { throw "Failed to extract $key" }
      } finally { Pop-Location }
      $file = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ne 'extract.log' } | Select-Object -First 1
      if (-not $file) { throw "Missing extracted member for $key" }
      $dst = Join-Path $dir 'member.obj'
      Copy-Item -Force $file.FullName $dst
      $sym = (& dumpbin.exe /nologo /symbols $dst 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) { throw "dumpbin failed for $key" }
      $sym | Set-Content -Encoding ascii (Join-Path $dir 'symbols.txt')
      if ($sym.IndexOf($expectedSymbol,[System.StringComparison]::Ordinal) -lt 0) {
        throw "YY member $key does not reference/define $expectedSymbol"
      }
      $script:objects += $dst
      $script:inventory.Add("$key|$($hits[0])|$expectedSymbol")
    }

    foreach ($api in ($apis + $srwClosure)) {
      $name = $api.Name
      $stack = $api.Stack
      $escaped = [regex]::Escape($name)
      Select-And-Extract "$name-direct" "(?i)[\\/]_$escaped@$stack\.obj$" "YY_Thunks_$name"
      Select-And-Extract "$name-import" "(?i)[\\/]_$escaped@$stack\.obi$" "YY_Thunks_$name"
    }
    # YY common implementation object is separate from the weak alias members.
    $target = [regex]::Escape($env:YY_THUNKS_TARGET)
    Select-And-Extract 'implementation' "(?i)[\\/]YY_Thunks_for_$target\.obj$" 'YY_Thunks_CreateThreadpoolWait'

    # The YY implementation's verified non-threadpool closure can require the
    # ProcessPrng weak aliases. Preserve them without loading full kernel32.lib.
    Select-And-Extract 'processprng-direct' '(?i)[\\/]_ProcessPrng@8\.obj$' 'YY_Thunks_ProcessPrng'
    Select-And-Extract 'processprng-import' '(?i)[\\/]_ProcessPrng@8\.obi$' 'YY_Thunks_ProcessPrng'

    $provider = Join-Path $work 'yy-threadpool-wait-narrow.lib'
    & lib.exe /nologo "/out:$provider" @objects
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $provider)) { throw 'Cannot build narrow threadpool YY provider' }
    $symbols = (& dumpbin.exe /nologo /linkermember:1 $provider 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot list narrow provider symbols' }
    $symbols | Set-Content -Encoding ascii diagnostics\yy-threadpool-provider-symbols.txt
    foreach ($api in ($apis + $srwClosure)) {
      $name = $api.Name
      if ($symbols.IndexOf("YY_Thunks_$name",[System.StringComparison]::Ordinal) -lt 0) {
        throw "Missing YY implementation for $name"
      }
    }
    $inventory | Set-Content -Encoding ascii diagnostics\yy-threadpool-selected-members.txt
    "NARROW_THREADPOOL_YY_LIB=$provider" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
    Get-FileHash -Algorithm SHA256 $provider | Format-List | Out-String | Set-Content -Encoding ascii diagnostics\yy-threadpool-provider-sha256.txt
  }
  'compile' {
    $src = Join-Path (Get-Location).Path '.github\scripts\xp\yy-threadpool-owner-xp.c'
    if (-not (Test-Path $src)) { throw 'Checked-in XP owner lifetime source missing' }
    Copy-Item -LiteralPath $src -Destination probe.c -Force
    & cl.exe /nologo /c /MD /O2 /GS- /TC /D_WIN32_WINNT=0x0601 probe.c /Foprobe.obj 2>&1 | Tee-Object diagnostics\compile.txt
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path probe.obj)) { throw 'XP owner lifetime probe compilation failed' }
    & dumpbin.exe /nologo /symbols probe.obj | Set-Content -Encoding ascii diagnostics\probe-symbols.txt
    "xp_probe_source_sha256=$((Get-FileHash $src -Algorithm SHA256).Hash)" | Add-Content -Encoding ascii diagnostics\identity.txt
  }
  'link' {
    $candidate = Get-Command lld-link.exe -ErrorAction SilentlyContinue
    $lld = if ($candidate) { $candidate.Source } else { 'C:\Program Files\LLVM\bin\lld-link.exe' }
    if (-not (Test-Path $lld)) { throw 'lld-link.exe missing' }
    $exe = Join-Path (Resolve-Path runtime).Path 'yy-threadpool-owner-x86.exe'
    $map = Join-Path (Resolve-Path diagnostics).Path 'final.map'
    $args = @(
      "-LIBPATH:$env:MSVCR14X_RELEASE",
      $env:THUNK_YY_SYNCH_LIB,
      $env:NARROW_THREADPOOL_YY_LIB,
      '/nodefaultlib:runtimeobject.lib',
      'probe.obj',
      '/subsystem:console',
      '/entry:mainCRTStartup',
      "/map:$map",
      "/out:$exe"
    )
    # Only the known, explicit YY implementation weak-alias closure is allowed.
    $winrt = @(
      'RoActivateInstance@8','RoFailFastWithErrorContext@4','RoGetActivationFactory@12',
      'RoGetAgileReference@16','RoGetApartmentIdentifier@4','RoInitialize@4',
      'RoOriginateError@8','RoOriginateErrorW@12','RoOriginateLanguageException@12',
      'RoRegisterActivationFactories@12','RoRegisterForApartmentShutdown@12',
      'RoRevokeActivationFactories@4','RoTransformError@12','RoTransformErrorW@16',
      'RoUninitialize@0','RoUnregisterForApartmentShutdown@4',
      'WindowsCompareStringOrdinal@12','WindowsCreateString@12',
      'WindowsCreateStringReference@16','WindowsDeleteString@4',
      'WindowsDuplicateString@8','WindowsGetStringLen@4',
      'WindowsGetStringRawBuffer@8','WindowsIsStringEmpty@4',
      'WindowsStringHasEmbeddedNull@8'
    )
    # Force explicit direct + IAT weak alternatives for this sole SRW dependency pair.
    foreach ($api in $srwClosure) {
      $stack = $api.Stack
      $name = $api.Name
      $args += "/alternatename:_${name}@$stack=_YY_Thunks_${name}@$stack"
      $args += "/alternatename:__imp__${name}@$stack=__imp__YY_Thunks_${name}@$stack"
    }
    foreach ($entry in $winrt) {
      $args += "/alternatename:_$entry=_YY_Thunks_$entry"
      $args += "/alternatename:__imp__$entry=__imp__YY_Thunks_$entry"
    }
    ($lld + ' ' + ($args -join ' ')) | Set-Content -Encoding ascii diagnostics\link-command.txt
    & $lld @args 2>&1 | Tee-Object diagnostics\link-output.txt
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw 'Threadpool probe link failed' }
    $mapText = Get-Content $map -Raw
    foreach ($api in ($apis + $srwClosure)) {
      if ($mapText.IndexOf("YY_Thunks_$($api.Name)",[System.StringComparison]::Ordinal) -lt 0) {
        throw "Final map does not select YY provider for $($api.Name)"
      }
    }
    & editbin.exe /nologo "/SUBSYSTEM:CONSOLE,$env:WINDOWS_XP_SUBSYSTEM" $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'XP PE subsystem retarget failed' }
    "YY_THREADPOOL_EXE=$exe" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
  }
  'audit' {
    # Audit exactly what will be packaged, including CRT DLL dependencies.
    # Staging here ensures the ordinary workflow invokes the complete gate.
    foreach ($dll in @('ucrtbase.dll','msvcp140.dll')) {
      $src = Join-Path $env:MSVCR14X_RELEASE $dll
      if (-not (Test-Path $src)) { throw "Missing XP-compatible CRT: $dll" }
      Copy-Item -Force $src runtime
    }
    $targets = @(Get-ChildItem -LiteralPath runtime -File | Where-Object { $_.Extension -in @('.exe','.dll') })
    if ($targets.Count -lt 1) { throw 'No PE image for XP import audit' }
    # Mirror the primary browser's broad XP post-5.1 direct-import list.
    # Independent copy: do not modify the production checker or shared script.
    $forbiddenApis = @(
      'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx','CompareStringEx','CompareStringOrdinal','CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA','CreateMutexExW','CreateSemaphoreExW',
      'CreateSymbolicLinkA','CreateSymbolicLinkW','CreateThreadpool','CreateThreadpoolCleanupGroup','CreateThreadpoolIo','CreateThreadpoolTimer','CreateThreadpoolWait','CreateThreadpoolWork','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
      'GetActiveProcessorCount','GetCurrentProcessorNumber','GetCurrentProcessorNumberEx','GetFileInformationByHandleEx','GetFinalPathNameByHandleA','GetFinalPathNameByHandleW','GetLocaleInfoEx','GetLogicalProcessorInformationEx',
      'GetMaximumProcessorCount','GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A','GetTempPath2W','GetTickCount64','GetUserDefaultLocaleName','InitializeConditionVariable','InitializeCriticalSectionEx','InitializeSRWLock',
      'IsThreadAFiber','LCIDToLocaleName','LocaleNameToLCID','ProcessPrng','QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive','ReleaseSRWLockShared','SetFileInformationByHandle','SetThreadDescription','SetThreadStackGuarantee',
      'SleepConditionVariableCS','SleepConditionVariableSRW','SubmitThreadpoolWork','TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress','WakeAllConditionVariable','WakeByAddressAll','WakeConditionVariable',
      'CreateWaitableTimerExA','CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
      'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart',
      'GetNamedPipeServerProcessId','SetProcessDPIAware','NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop','inet_pton','WSASendMsg','WSCGetProviderInfo',
      'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime'
    )
    $forbiddenDllPatterns = @(
      '^(api-ms-win-|ext-ms-)','^KERNELBASE\.dll$','^BCRYPTPRIMITIVES\.dll$','^COMBASE\.dll$','^NCRYPT\.dll$',
      '^WEVTAPI\.dll$','^DWMAPI\.dll$','^SHCORE\.dll$','^PATHCCH\.dll$','^NORMALIZ\.dll$',
      '^PROPSYS\.dll$','^DXGI\.dll$','^VCRUNTIME140(?:_1)?\.dll$'
    )
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($image in $targets) {
      $headers = @(& dumpbin.exe /nologo /headers $image.FullName 2>&1)
      if ($LASTEXITCODE -ne 0) { throw "dumpbin headers failed: $($image.Name)" }
      $headers | Set-Content -Encoding ascii (Join-Path diagnostics "$($Stage)-$($image.Name)-headers.txt")
      $machine = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+\s+machine' } | Select-Object -First 1
      if ($machine -notmatch '(?i)^\s*14C machine \(x86\)') { $issues.Add("$($image.Name)|MACHINE|$machine") }
      $line = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
      if ($line -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') {
        $issues.Add("$($image.Name)|SUBSYSTEM|unparseable")
      } elseif ([version]("$([int]$matches[1]).$([int]$matches[2])") -gt [version]'5.1') {
        $issues.Add("$($image.Name)|SUBSYSTEM|$line")
      }

      $imports = @(& dumpbin.exe /nologo /imports $image.FullName 2>&1)
      if ($LASTEXITCODE -ne 0) { throw "dumpbin imports failed: $($image.Name)" }
      $imports | Set-Content -Encoding ascii (Join-Path diagnostics "$($Stage)-$($image.Name)-imports.txt")
      $mode = 'none'
      foreach ($raw in $imports) {
        if ($raw -match '^\s*Section contains the following imports:\s*$') { $mode = 'direct'; continue }
        if ($raw -match '^\s*Section contains the following delay load imports:\s*$') { $mode = 'delay'; continue }
        if ($mode -ne 'direct') { continue }
        if ($raw -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') {
          $dll = $matches[1]
          foreach ($pattern in $forbiddenDllPatterns) {
            if ($dll -match $pattern) { $issues.Add("$($image.Name)|DLL|$dll"); break }
          }
          continue
        }
        if ($raw.Trim() -match '^[0-9A-Fa-f]+\s+(\S+)$') {
          $api = $matches[1] -replace '^_(.+)@\d+$','$1'
          if ($forbiddenApis -contains $api) { $issues.Add("$($image.Name)|API|$api") }
        }
      }
    }
    $issues | Set-Content -Encoding ascii (Join-Path diagnostics "$Stage-forbidden-imports.txt")
    if ($issues.Count -gt 0) { throw "XP $Stage direct import gate FAILED, count=$($issues.Count). See diagnostics/$Stage-forbidden-imports.txt" }
    "XP $Stage broad PE/import gate PASS; image_count=$($targets.Count)" |
      Set-Content -Encoding ascii (Join-Path diagnostics "$Stage-import-gate.txt")
  }

  'audit-runtime' {
    $targets = if ($Stage -eq 'audit-runtime') {
      @(Get-ChildItem -LiteralPath runtime -File | Where-Object { $_.Extension -in @('.exe','.dll') })
    } else {
      @(Get-Item -LiteralPath $env:YY_THREADPOOL_EXE)
    }
    if ($targets.Count -lt 1) { throw 'No PE image for XP import audit' }
    # Mirror the primary browser's broad XP post-5.1 direct-import list.
    # Independent copy: do not modify the production checker or shared script.
    $forbiddenApis = @(
      'AcquireSRWLockExclusive','AcquireSRWLockShared','CancelIoEx','CompareStringEx','CompareStringOrdinal','CreateEventExA','CreateEventExW','CreateFile2','CreateMutexExA','CreateMutexExW','CreateSemaphoreExW',
      'CreateSymbolicLinkA','CreateSymbolicLinkW','CreateThreadpool','CreateThreadpoolCleanupGroup','CreateThreadpoolIo','CreateThreadpoolTimer','CreateThreadpoolWait','CreateThreadpoolWork','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
      'GetActiveProcessorCount','GetCurrentProcessorNumber','GetCurrentProcessorNumberEx','GetFileInformationByHandleEx','GetFinalPathNameByHandleA','GetFinalPathNameByHandleW','GetLocaleInfoEx','GetLogicalProcessorInformationEx',
      'GetMaximumProcessorCount','GetOverlappedResultEx','GetSystemTimePreciseAsFileTime','GetTempPath2A','GetTempPath2W','GetTickCount64','GetUserDefaultLocaleName','InitializeConditionVariable','InitializeCriticalSectionEx','InitializeSRWLock',
      'IsThreadAFiber','LCIDToLocaleName','LocaleNameToLCID','ProcessPrng','QueryUnbiasedInterruptTime','ReleaseSRWLockExclusive','ReleaseSRWLockShared','SetFileInformationByHandle','SetThreadDescription','SetThreadStackGuarantee',
      'SleepConditionVariableCS','SleepConditionVariableSRW','SubmitThreadpoolWork','TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','WaitOnAddress','WakeAllConditionVariable','WakeByAddressAll','WakeConditionVariable',
      'CreateWaitableTimerExA','CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread','GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear',
      'GetUserPreferredUILanguages','GetThreadPreferredUILanguages','InitOnceExecuteOnce','InitOnceBeginInitialize','InitOnceComplete','GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart',
      'GetNamedPipeServerProcessId','SetProcessDPIAware','NtCancelIoFileEx','EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW','WSAIoctl','inet_ntop','inet_pton','WSASendMsg','WSCGetProviderInfo',
      'QueryFullProcessImageNameA','QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime'
    )
    $forbiddenDllPatterns = @(
      '^(api-ms-win-|ext-ms-)','^KERNELBASE\.dll$','^BCRYPTPRIMITIVES\.dll$','^COMBASE\.dll$','^NCRYPT\.dll$',
      '^WEVTAPI\.dll$','^DWMAPI\.dll$','^SHCORE\.dll$','^PATHCCH\.dll$','^NORMALIZ\.dll$',
      '^PROPSYS\.dll$','^DXGI\.dll$','^VCRUNTIME140(?:_1)?\.dll$'
    )
    $issues = [System.Collections.Generic.List[string]]::new()
    foreach ($image in $targets) {
      $headers = @(& dumpbin.exe /nologo /headers $image.FullName 2>&1)
      if ($LASTEXITCODE -ne 0) { throw "dumpbin headers failed: $($image.Name)" }
      $headers | Set-Content -Encoding ascii (Join-Path diagnostics "$($Stage)-$($image.Name)-headers.txt")
      $machine = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+\s+machine' } | Select-Object -First 1
      if ($machine -notmatch '(?i)^\s*14C machine \(x86\)') { $issues.Add("$($image.Name)|MACHINE|$machine") }
      $line = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
      if ($line -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') {
        $issues.Add("$($image.Name)|SUBSYSTEM|unparseable")
      } elseif ([version]("$([int]$matches[1]).$([int]$matches[2])") -gt [version]'5.1') {
        $issues.Add("$($image.Name)|SUBSYSTEM|$line")
      }

      $imports = @(& dumpbin.exe /nologo /imports $image.FullName 2>&1)
      if ($LASTEXITCODE -ne 0) { throw "dumpbin imports failed: $($image.Name)" }
      $imports | Set-Content -Encoding ascii (Join-Path diagnostics "$($Stage)-$($image.Name)-imports.txt")
      $mode = 'none'
      foreach ($raw in $imports) {
        if ($raw -match '^\s*Section contains the following imports:\s*$') { $mode = 'direct'; continue }
        if ($raw -match '^\s*Section contains the following delay load imports:\s*$') { $mode = 'delay'; continue }
        if ($mode -ne 'direct') { continue }
        if ($raw -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') {
          $dll = $matches[1]
          foreach ($pattern in $forbiddenDllPatterns) {
            if ($dll -match $pattern) { $issues.Add("$($image.Name)|DLL|$dll"); break }
          }
          continue
        }
        if ($raw.Trim() -match '^[0-9A-Fa-f]+\s+(\S+)$') {
          $api = $matches[1] -replace '^_(.+)@\d+$','$1'
          if ($forbiddenApis -contains $api) { $issues.Add("$($image.Name)|API|$api") }
        }
      }
    }
    $issues | Set-Content -Encoding ascii (Join-Path diagnostics "$Stage-forbidden-imports.txt")
    if ($issues.Count -gt 0) { throw "XP $Stage direct import gate FAILED, count=$($issues.Count). See diagnostics/$Stage-forbidden-imports.txt" }
    "XP $Stage broad PE/import gate PASS; image_count=$($targets.Count)" |
      Set-Content -Encoding ascii (Join-Path diagnostics "$Stage-import-gate.txt")
  }
  'hosted' {
    foreach ($dll in @('ucrtbase.dll','msvcp140.dll')) {
      $src = Join-Path $env:MSVCR14X_RELEASE $dll
      if (-not (Test-Path $src)) { throw "Missing XP CRT DLL $dll" }
      Copy-Item -Force $src runtime
    }
    foreach ($scenario in @('l1','l2','l2-pending','l3')) {
      Push-Location runtime
      try {
        & .\yy-threadpool-owner-x86.exe $scenario 2>&1 |
          Tee-Object "..\diagnostics\hosted-$scenario.txt"
        $code = $LASTEXITCODE
      } finally { Pop-Location }
      if ($code -ne 0) { throw "Hosted native $scenario returned $code" }
      $log = Get-Content "diagnostics\hosted-$scenario.txt" -Raw
      if (-not $log.Contains("XP_OWNER_LIFETIME_PASS mode=$scenario")) {
        throw "Hosted native $scenario missing scenario pass marker"
      }
      Write-Host "Hosted native OS-Threadpool control $scenario PASS; physical XP fallback PENDING"
    }
    'hosted=OS_native_threadpool_not_YY_XP_fallback' |
      Set-Content -Encoding ascii diagnostics\hosted-scope.txt
  }
  'bundle' {
@'
@echo off
setlocal
echo YY-Thunks 1.2.2 XP SP3 x86 release-fallback owner lifetime tests
echo Run: 4 distinct process executions. Do not copy to Firefox folder.
for %%S in (l1 l2 l2-pending l3) do (
  echo === SCENARIO %%S ===
  yy-threadpool-owner-x86.exe %%S
  if errorlevel 1 goto failed
)
echo Overall: PASS
echo OwnerLifetimeExitCode=0
exit /b 0
:failed
echo Overall: FAIL
echo OwnerLifetimeExitCode=%ERRORLEVEL%
exit /b 1
'@ | Set-Content -Encoding ascii runtime\run-xp-owner-lifetime.cmd
@'
Standalone YY-Thunks 1.2.2 owner lifetime XP SP3 x86 runtime.
Do not copy any DLL or EXE into the Firefox installation.
Run "run-xp-owner-lifetime.cmd" on physical XP SP3 x86.
Each scenario is a separate process with internal 14 second watchdog.
Capture full CMD output, "ver", and certutil SHA-1 for this EXE.
L1: off-callback cleanup after notification; L2: cancel in-flight
callback; L2-pending: cancel before signaling; L3: simulated
failed delivery and shutdown. This tests a standalone owner model.
No real Firefox WinHandleWatcher is changed by this test.
Hosted CI uses native Windows Threadpool; XP uses YY fallback.
A passing PE gate or hosted PASS is NOT physical XP runtime PASS.
'@ | Set-Content -Encoding ascii runtime\README-XP.txt
    Get-ChildItem runtime -File | ForEach-Object {
      $hash=(Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
      "$hash  $($_.Name)"
    } | Set-Content -Encoding ascii runtime\SHA256SUMS.txt
    Get-FileHash -Algorithm SHA256 $env:YY_THREADPOOL_EXE | Format-List | Out-String |
      Set-Content -Encoding ascii diagnostics\exe-sha256.txt
    "source_under_test=$env:GITHUB_SHA" | Add-Content -Encoding ascii diagnostics\identity.txt
    'physical_XP=not_executed_in_GitHub_Actions' | Add-Content -Encoding ascii diagnostics\identity.txt
  }
  default { throw "Unsupported Stage: $Stage" }
}
