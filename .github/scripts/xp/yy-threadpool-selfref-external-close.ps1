param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('prepare','build','hosted')]
  [string]$Stage
)

$ErrorActionPreference = 'Stop'
$yyCommit = '83d9d0d3f2f212411006e4aa5c5f3db8a6ae2f20'
$work = Join-Path $env:RUNNER_TEMP 'xp-yy-122-selfref-external-close'
$up = Join-Path $work 'yy-v122'
$patched = Join-Path $up 'src\Thunks\api-ms-win-core-threadpool.hpp'
$yyMain = Join-Path $up 'src\Thunks\YY_Thunks.cpp'
$listPath = Join-Path $up 'src\Thunks\YY_Thunks_List.hpp'
$exe = Join-Path $work 'yy-threadpool-selfref-external-close-hosted-x86.exe'
$lf = [string][char]10
$crlf = ([string][char]13) + $lf
New-Item -ItemType Directory -Force diagnostics | Out-Null

function Need([bool]$condition, [string]$reason) {
  if (-not $condition) { throw $reason }
}
function Replace-One([string]$text, [string]$needle, [string]$replacement, [string]$label) {
  $index = $text.IndexOf($needle, [StringComparison]::Ordinal)
  Need ($index -ge 0) "Missing exact YY v1.2.2 source anchor: $label"
  Need ($text.IndexOf($needle,$index + $needle.Length,[StringComparison]::Ordinal) -lt 0) "Ambiguous YY source anchor: $label"
  return $text.Substring(0,$index) + $replacement + $text.Substring($index+$needle.Length)
}

switch ($Stage) {
  'prepare' {
    if (Test-Path $work) { Remove-Item -LiteralPath $work -Force -Recurse }
    New-Item -ItemType Directory -Force $work | Out-Null
    & git.exe clone --quiet --depth 1 --branch v1.2.2 https://github.com/Chuyu-Team/YY-Thunks.git $up
    Need ($LASTEXITCODE -eq 0) 'YY v1.2.2 upstream clone failed'
    $actual = (& git.exe -C $up rev-parse HEAD | Out-String).Trim()
    Need ($LASTEXITCODE -eq 0 -and $actual -eq $yyCommit) "Wrong upstream YY commit: $actual"
    Need (-not (Test-Path $listPath)) 'Generated header unexpectedly present in original checkout'
    $proj = Join-Path $up 'src\YY-Thunks.UnitTest\YY-Thunks.UnitTest.vcxproj'
    & msbuild.exe $proj /nologo /t:Build_YY_Thunks_List_hpp /p:Configuration=Release /p:Platform=Win32 /v:minimal
    Need ($LASTEXITCODE -eq 0 -and (Test-Path $listPath)) 'Authentic YY MSBuild source list generation failed'
    $raw = [IO.File]::ReadAllText($patched).Replace($crlf,$lf)

    $begin = $raw.IndexOf('if (auto const pCreateThreadpoolWait = try_get_CreateThreadpoolWait())',[StringComparison]::Ordinal)
    Need ($begin -ge 0) 'Missing exact CreateThreadpoolWait definition'
    $end = $raw.IndexOf('#endif',$begin,[StringComparison]::Ordinal)
    Need ($end -gt $begin) 'Missing CreateThreadpoolWait block end'
    $fragment = $raw.Substring($begin,$end-$begin)
    $needle = 'auto Flags = CallbackEnviron ? CallbackEnviron->u.Flags : 0;'
    $fragment = Replace-One $fragment $needle ('XP_L1_FallbackSelected();' + $lf + '        ' + $needle) 'forced fallback body'
    $raw = $raw.Substring(0,$begin) + $fragment + $raw.Substring($end)

    $freeBegin = $raw.IndexOf('static void __fastcall TppWaitpFree(_TP_WORK* Work)',[StringComparison]::Ordinal)
    Need ($freeBegin -ge 0) 'Missing TppWaitpFree definition'
    $freeEnd = $raw.IndexOf('static const _TP_CLEANUP_GROUP_FUNCS* __fastcall GetTppWaitpCleanupGroupMemberVFuncs()',$freeBegin,[StringComparison]::Ordinal)
    Need ($freeEnd -gt $freeBegin) 'Missing TppWaitpFree block end'
    $freeBlock = $raw.Substring($freeBegin,$freeEnd-$freeBegin)
    $freeBlock = Replace-One $freeBlock 'HeapFree(ProcessHeap, 0, Work);' 'BOOL freed = HeapFree(ProcessHeap, 0, Work); XP_L1_FreeObserved(Work, freed);' 'actual HeapFree'
    $raw = $raw.Substring(0,$freeBegin) + $freeBlock + $raw.Substring($freeEnd)

    # Negative-control guard at the actual YY worker callback, before AddRef.
    # Test will not dereference the freed wait even if free is observed.
    $workerNeedle = 'auto Wait = (PTP_WAIT)lpParameter;'
    $workerReplace = 'auto Wait = static_cast<Fallback::TP_Wait*>(lpParameter);' + $lf +
      '                if (XP_EXT_BeforeWorkerAddRef(Wait)) return; // TEST GUARD before dereference' + $lf +
      '                Wait->AddRef();' + $lf +
      '                XP_REF_Hold(Wait);'
    $raw = Replace-One $raw $workerNeedle $workerReplace 'worker pre-AddRef guard'
    $postNeedle = 'Fallback::DoWhenCallbackReturns(&Instance);' + $lf + $lf + '                SetEvent(Wait->hEvent);'
    $postReplace = 'Fallback::DoWhenCallbackReturns(&Instance);' + $lf + $lf +
      '                SetEvent(Wait->hEvent);' + $lf +
      '                Wait->Release();'
    $raw = Replace-One $raw $postNeedle $postReplace 'balanced worker reference'
    # Extra setter reference: starts AFTER Handle==nullptr early exit,
    # stays alive beyond ReleaseSRWLockExclusive and all registration error
    # handling. The existing AddRef for the Win32 registration is separate.
    $setBegin = $raw.IndexOf('SetThreadpoolWait,',[StringComparison]::Ordinal)
    Need ($setBegin -ge 0) 'SetThreadpoolWait source definition not found'
    $setEnd = $raw.IndexOf('#endif',$setBegin,[StringComparison]::Ordinal)
    Need ($setEnd -gt $setBegin) 'SetThreadpoolWait source block not found'
    $setBlock = $raw.Substring($setBegin,$setEnd-$setBegin)
    $setBlock = Replace-One $setBlock '        ULONG dwMilliseconds;' (
      '        _pWait->AddRef(); // setter scope reference, test-only' + $lf +
      '        XP_SET_Hold(_pWait);' + $lf +
      '        ULONG dwMilliseconds;') 'setter scoped AddRef before registration'
    $endNeedle = '            _pWait->Release();' + $lf +
      '        }' + $lf +
      '    }'
    $endReplacement = '            _pWait->Release();' + $lf +
      '        }' + $lf +
      '        XP_SET_BeforeRelease(_pWait);' + $lf +
      '        _pWait->Release(); // setter scope release, AFTER unlock' + $lf +
      '    }'
    $setBlock = Replace-One $setBlock $endNeedle $endReplacement 'setter scoped Release after unlock'
    $raw = $raw.Substring(0,$setBegin) + $setBlock + $raw.Substring($setEnd)
    $declarations = @'
extern "C" void __cdecl XP_L1_FallbackSelected(void);
extern "C" void __cdecl XP_L1_FreeObserved(void*, int);
extern "C" void __cdecl XP_REF_Hold(void*);
extern "C" int __cdecl XP_EXT_BeforeWorkerAddRef(void*);
extern "C" void __cdecl XP_SET_Hold(void*);
extern "C" void __cdecl XP_SET_BeforeRelease(void*);
// Test-only instrumented source, no production YY change.
'@
    $raw = $declarations + $lf + $raw
    [IO.File]::WriteAllText($patched,$raw,[Text.UTF8Encoding]::new($false))
    @(
      "source_under_test=$env:GITHUB_SHA",
      "run_id=$env:GITHUB_RUN_ID",
      "run_attempt=$env:GITHUB_RUN_ATTEMPT",
      "YY_version=1.2.2",
      "YY_upstream_commit=$actual",
      'YY_list_generator=upstream_msbuild_Build_YY_Thunks_List_hpp',
      "YY_list_sha256=$((Get-FileHash $listPath -Algorithm SHA256).Hash)",
      "YY_instrumented_header_sha256=$((Get-FileHash $patched -Algorithm SHA256).Hash)",
      'mode=separate_YYSOURCE_test_only_fallback_on_hosted_windows',
      'scope=external_close_before_worker_AddRef_negative_control_NO_FIREFOX',
      'production_provider=unchanged',
      'physical_XP_runtime=not_tested;hosted_only'
    ) | Set-Content -Encoding ascii diagnostics\selfref-identity.txt
    Write-Host "Prepared YY v1.2.2 at $actual with test-only L1 checkpoints"
  }
  'build' {
    Need ((Test-Path $listPath) -and (Test-Path $patched)) 'YY source preparation missing'
    $yyObj = Join-Path $work 'yy-selfref.obj'
    $testObj = Join-Path $work 'selfref-l1-harness.obj'
    $testSource = Join-Path (Get-Location).Path '.github\scripts\xp\yy-threadpool-selfref-external-close.cpp'
    Need (Test-Path $testSource) 'Checked-in L1 harness missing'
    $inc = @("/I$($up)\src", "/I$($up)\src\Shared", "/I$($up)\src\Thunks")
    $yyArgs = @('/nologo','/c','/std:c++17','/MD','/EHsc','/Zi','/O1','/GS-',
      '/D__YY_Thunks_Unit_Test','/D__USING_NTDLL_LIB',
      '/DYY_Thunks_Target=__WindowsNT5_1','/D__FALLBACK_PREFIX=YY_Thunks_',
      '/DWIN32','/DNDEBUG') + $inc + @("/Fo$yyObj",$yyMain)
    & cl.exe @yyArgs *> diagnostics\yy-source-compile.txt
    Need ($LASTEXITCODE -eq 0 -and (Test-Path $yyObj)) 'Instrumented source YY compile failed'
    $hArgs = @('/nologo','/c','/std:c++17','/MD','/EHsc','/Zi','/O1','/GS-',
      "/Fo$testObj",$testSource)
    & cl.exe @hArgs *> diagnostics\selfref-l1-harness-compile.txt
    Need ($LASTEXITCODE -eq 0 -and (Test-Path $testObj)) 'L1 harness compile failed'
    $linkArgs = @('/nologo','/machine:x86','/subsystem:console','/incremental:no',
      "/out:$exe","/map:$($work)\selfref-l1.map",$testObj,$yyObj,
      'kernel32.lib','user32.lib','advapi32.lib','shlwapi.lib','ws2_32.lib','ntdll.lib','ole32.lib')
    & link.exe @linkArgs *> diagnostics\selfref-l1-link.txt
    Need ($LASTEXITCODE -eq 0 -and (Test-Path $exe)) 'Instrumented L1 linker failed'
    $importCensus = (& dumpbin.exe /nologo /imports $exe 2>&1 | Out-String)
    Need ($LASTEXITCODE -eq 0) 'L1 hosted import census unavailable'
    $importCensus | Set-Content -Encoding utf8 diagnostics\selfref-l1-hosted-imports.txt
    $pe = (& dumpbin.exe /nologo /headers $exe 2>&1 | Out-String)
    Need ($LASTEXITCODE -eq 0 -and $pe -match '(?im)^\s*14C machine \(x86\)') 'Wrong L1 host PE machine'
    $pe | Set-Content -Encoding utf8 diagnostics\selfref-l1-hosted-headers.txt
    @(
      "l1_source_sha256=$((Get-FileHash $testSource -Algorithm SHA256).Hash)",
      "instrumented_YY_object_sha256=$((Get-FileHash $yyObj -Algorithm SHA256).Hash)",
      "l1_exe_sha256=$((Get-FileHash $exe -Algorithm SHA256).Hash)",
      'hosted_PE_only=not_XP_compatible_artifact'
    ) | Add-Content -Encoding ascii diagnostics\selfref-identity.txt
    Write-Host 'Instrumented YY selfref presignaled registration race EXE linked'
  }
  'hosted' {
    Need (Test-Path $exe) 'Instrumented external-close gate EXE missing'
    for ($iteration = 1; $iteration -le 3; $iteration++) {
      $label = "pre-addref-$iteration"
      $out = Join-Path (Get-Location).Path "diagnostics\$label-stdout.txt"
      $err = Join-Path (Get-Location).Path "diagnostics\$label-stderr.txt"
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = $exe
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $p = New-Object System.Diagnostics.Process
      $p.StartInfo = $psi
      Need ($p.Start()) "Cannot start $label"
      $done = $p.WaitForExit(15000)
      if (-not $done) { try { $p.Kill(); $p.WaitForExit() } catch {} }
      [IO.File]::WriteAllText($out,$p.StandardOutput.ReadToEnd())
      [IO.File]::WriteAllText($err,$p.StandardError.ReadToEnd())
      $log = [IO.File]::ReadAllText($out)
      $stderr = [IO.File]::ReadAllText($err)
      Write-Host $log
      @("case=$label", "completed=$done", "exit_code=$($p.ExitCode)",
        "stderr_empty=$([string]::IsNullOrEmpty($stderr))") |
        Add-Content -Encoding ascii diagnostics\selfref-identity.txt
      Need $done "$label exceeded 15s watchdog"
      Need ($p.ExitCode -eq 0) "$label exited $($p.ExitCode)"
      Need ([string]::IsNullOrEmpty($stderr)) "$label emitted stderr"
      foreach ($marker in @(
        'kind=yy_fallback_create',
        'kind=setter_scope_ref_acquired',
        'kind=setter_finished_before_signal',
        'kind=worker_before_AddRef_barrier',
        'kind=external_CloseThreadpoolWait_returned',
        'kind=actual_heap_free',
        'kind=external_close_freed_before_AddRef',
        'kind=would_AddRef_freed_wait_TEST_GUARD',
        'external_close_free_count=1 heap_free_ok=1 same_ptr=1',
        'setter_ref=1 setter_release=1 worker_ref=0 user_callback=0 unsafe_before_AddRef=1 errors=0',
        'EXPECTED_EXTERNAL_CLOSE_PRE_ADDREF_UAF_WINDOW_REPRODUCED'
      )) { Need ($log.Contains($marker)) "$label missing evidence: $marker" }
      Write-Host "PASS scope=L1_prearmed_setter_plus_worker_pin_test_only_NO_FIREFOX: unsafe pre-AddRef ownership demonstrated with guard (NOT production safety)"
      $p.Dispose()
    }
    'result=EXPECTED_UNSAFE_PRE_ADDREF_NEGATIVE_CONTROL;NOT_FIREFOX_FIX_OR_XP_RUNTIME' |
      Add-Content -Encoding ascii diagnostics\selfref-identity.txt
  }
}
