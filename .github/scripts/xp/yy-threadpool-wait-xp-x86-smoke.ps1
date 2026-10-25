param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('init', 'provider', 'compile', 'link', 'audit', 'hosted', 'bundle')]
    [string]$Stage
)

$ErrorActionPreference = 'Stop'
$apis = @(
    @{ Name='CreateThreadpoolWait'; Stack=12 },
    @{ Name='SetThreadpoolWait'; Stack=12 },
    @{ Name='WaitForThreadpoolWaitCallbacks'; Stack=8 },
    @{ Name='CloseThreadpoolWait'; Stack=4 }
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

    foreach ($api in $apis) {
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
    foreach ($api in $apis) {
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
@'
#define WIN32_LEAN_AND_MEAN
#define _WIN32_WINNT 0x0601
#include <windows.h>
#include <threadpoolapiset.h>
#include <stdio.h>

typedef struct {
    volatile LONG count;
    volatile LONG last_result;
    HANDLE delivered;
} STATE;

static VOID CALLBACK OnWait(PTP_CALLBACK_INSTANCE instance,
                             PVOID context, PTP_WAIT wait, TP_WAIT_RESULT result) {
    STATE* state = (STATE*)context;
    (void)instance;
    (void)wait;
    InterlockedExchange(&state->last_result, (LONG)result);
    InterlockedIncrement(&state->count);
    SetEvent(state->delivered);
}
#define REQUIRE(cond, name) do { \
    if (!(cond)) { printf("FAIL %s err=%lu\n", name, GetLastError()); ++fails; goto cleanup; } \
    printf("PASS %s\n", name); \
} while (0)

int main(void) {
    int fails = 0;
    int i;
    HANDLE trigger = NULL;
    HANDLE delivered = NULL;
    PTP_WAIT wait = NULL;
    STATE state;
    ZeroMemory(&state, sizeof(state));
    state.last_result = -1;
    trigger = CreateEventW(NULL, TRUE, FALSE, NULL);
    delivered = CreateEventW(NULL, TRUE, FALSE, NULL);
    REQUIRE(trigger != NULL && delivered != NULL, "event setup");
    state.delivered = delivered;
    wait = CreateThreadpoolWait(OnWait, &state, NULL);
    REQUIRE(wait != NULL, "CreateThreadpoolWait");
    SetThreadpoolWait(wait, trigger, NULL);
    REQUIRE(WaitForSingleObject(delivered, 150) == WAIT_TIMEOUT, "no early callback");
    SetEvent(trigger);
    REQUIRE(WaitForSingleObject(delivered, 5000) == WAIT_OBJECT_0, "signaled callback");
    REQUIRE(InterlockedCompareExchange(&state.count, 0, 0) == 1 &&
            InterlockedCompareExchange(&state.last_result, 0, 0) == WAIT_OBJECT_0,
            "exactly one success callback");
    SetThreadpoolWait(wait, NULL, NULL);
    WaitForThreadpoolWaitCallbacks(wait, TRUE);
    printf("PASS SetThreadpoolWait+WaitForThreadpoolWaitCallbacks\n");

    for (i = 0; i < 12; ++i) {
        LONG expected = InterlockedCompareExchange(&state.count, 0, 0) + 1;
        ResetEvent(trigger);
        ResetEvent(delivered);
        SetThreadpoolWait(wait, trigger, NULL);
        SetEvent(trigger);
        if (WaitForSingleObject(delivered, 5000) != WAIT_OBJECT_0 ||
            InterlockedCompareExchange(&state.count, 0, 0) != expected) {
            printf("FAIL rearm iteration=%d\n", i);
            ++fails;
            goto cleanup;
        }
        SetThreadpoolWait(wait, NULL, NULL);
        WaitForThreadpoolWaitCallbacks(wait, TRUE);
    }
    printf("PASS rearm 12 cycles\n");

    ResetEvent(trigger);
    ResetEvent(delivered);
    SetThreadpoolWait(wait, trigger, NULL);
    SetThreadpoolWait(wait, NULL, NULL);
    WaitForThreadpoolWaitCallbacks(wait, TRUE);
    {
        LONG before = InterlockedCompareExchange(&state.count, 0, 0);
        SetEvent(trigger);
        Sleep(200);
        REQUIRE(InterlockedCompareExchange(&state.count, 0, 0) == before,
                "cancel pending callback");
    }
cleanup:
    if (wait) {
        SetThreadpoolWait(wait, NULL, NULL);
        WaitForThreadpoolWaitCallbacks(wait, TRUE);
        CloseThreadpoolWait(wait);
        printf("PASS CloseThreadpoolWait\n");
    }
    if (trigger) CloseHandle(trigger);
    if (delivered) CloseHandle(delivered);
    printf("Overall: %s\n", fails ? "FAIL" : "PASS");
    printf("ExitCode=%d\n", fails ? 1 : 0);
    return fails ? 1 : 0;
}
'@ | Set-Content -Encoding ascii probe.c
    & cl.exe /nologo /c /MD /O2 /GS- /TC /D_WIN32_WINNT=0x0601 probe.c /Foprobe.obj 2>&1 | Tee-Object diagnostics\compile.txt
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path probe.obj)) { throw 'Threadpool probe compilation failed' }
    & dumpbin.exe /nologo /symbols probe.obj | Set-Content -Encoding ascii diagnostics\probe-symbols.txt
  }
  'link' {
    $candidate = Get-Command lld-link.exe -ErrorAction SilentlyContinue
    $lld = if ($candidate) { $candidate.Source } else { 'C:\Program Files\LLVM\bin\lld-link.exe' }
    if (-not (Test-Path $lld)) { throw 'lld-link.exe missing' }
    $exe = Join-Path (Resolve-Path runtime).Path 'yy-threadpool-wait-x86.exe'
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
    #  Correct the exact WinRT signature for RoRegisterActivationFactories.
    $winrt = @($winrt | ForEach-Object { if ($_ -eq 'RoRegisterActivationFactories@12') { 'RoRegisterActivationFactories@16' } else { $_ } })
    foreach ($entry in $winrt) {
      $args += "/alternatename:_$entry=_YY_Thunks_$entry"
      $args += "/alternatename:__imp__$entry=__imp__YY_Thunks_$entry"
    }
    ($lld + ' ' + ($args -join ' ')) | Set-Content -Encoding ascii diagnostics\link-command.txt
    & $lld @args 2>&1 | Tee-Object diagnostics\link-output.txt
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw 'Threadpool probe link failed' }
    & editbin.exe /nologo "/SUBSYSTEM:CONSOLE,$env:WINDOWS_XP_SUBSYSTEM" $exe | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'XP PE subsystem retarget failed' }
    "YY_THREADPOOL_EXE=$exe" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
  }
  'audit' {
    $exe = $env:YY_THREADPOOL_EXE
    if (-not (Test-Path $exe)) { throw 'Probe executable missing' }
    $headers = (& dumpbin.exe /nologo /headers $exe 2>&1 | Out-String)
    $headers | Set-Content -Encoding ascii diagnostics\exe-headers.txt
    if ($headers -notmatch '(?im)^\s*14C machine \(x86\)') { throw 'Probe not x86' }
    if ($headers -notmatch '(?im)^\s*5\.0?1\s+subsystem version') { throw 'Probe subsystem not 5.01' }
    $imports = (& dumpbin.exe /nologo /imports $exe 2>&1 | Out-String)
    $imports | Set-Content -Encoding ascii diagnostics\exe-imports.txt
    foreach ($api in $apis) {
      $name = $api.Name
      if ($imports -match "(?im)\b$([regex]::Escape($name))\b") {
        throw "XP forbidden hard import survived: $name"
      }
    }
    foreach ($name in @('KERNELBASE.dll','api-ms-win-','ext-ms-','bcrypt.dll','ProcessPrng','WindowsCreateString')) {
      if ($imports.IndexOf($name,[System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        throw "Unexpected XP import/dependency: $name"
      }
    }
    'Threadpool wait isolated PE/import gate PASS' | Set-Content -Encoding ascii diagnostics\import-gate.txt
  }
  'hosted' {
    foreach ($dll in @('ucrtbase.dll','msvcp140.dll')) {
      $src = Join-Path $env:MSVCR14X_RELEASE $dll
      if (-not (Test-Path $src)) { throw "Missing XP x86 CRT $dll" }
      Copy-Item -Force $src runtime
    }
    Push-Location runtime
    try {
      & .\yy-threadpool-wait-x86.exe 2>&1 | Tee-Object ..\diagnostics\hosted-stdout.txt
      $code = $LASTEXITCODE
    } finally { Pop-Location }
    if ($code -ne 0) { throw "Hosted runtime failed: $code" }
    'hosted=native Windows implementation; physical XP fallback not exercised' |
      Set-Content -Encoding ascii diagnostics\hosted-scope.txt
  }
  'bundle' {
@'
@echo off
echo YY-Thunks 1.2.2 / XP x86 Threadpool Wait standalone smoke
yy-threadpool-wait-x86.exe
set TEST_EC=%ERRORLEVEL%
echo ThreadpoolExitCode=%TEST_EC%
exit /b %TEST_EC%
'@ | Set-Content -Encoding ascii runtime\run-xp-threadpool.cmd
@'
Standalone Windows XP SP3 x86 test (not Firefox).
Run run-xp-threadpool.cmd on the physical XP test machine.
Preserve the complete output, exit code, and binary SHA-1.
The Windows-hosted CI test takes the OS-native API path and cannot prove
the YY fallback that runs on XP. Test only this isolated executable.
Do not copy the test EXE or its CRT into the browser installation.
'@ | Set-Content -Encoding ascii runtime\README-XP.txt
    Get-ChildItem runtime -File | ForEach-Object {
      $hash = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
      "$hash  $($_.Name)"
    } | Set-Content -Encoding ascii runtime\SHA256SUMS.txt
    Get-FileHash -Algorithm SHA256 $env:YY_THREADPOOL_EXE | Format-List | Out-String |
      Set-Content -Encoding ascii diagnostics\exe-sha256.txt
  }
  default { throw "Unsupported Stage: $Stage" }
}
