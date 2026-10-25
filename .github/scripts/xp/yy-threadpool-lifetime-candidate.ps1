param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('prepare','build','hosted')]
  [string]$Stage
)

$ErrorActionPreference = 'Stop'
$yyCommit = '83d9d0d3f2f212411006e4aa5c5f3db8a6ae2f20'
$work = Join-Path $env:RUNNER_TEMP 'xp-yy-122-owner-lifetime-candidate'
$up = Join-Path $work 'yy-v122'
$patched = Join-Path $up 'src\Thunks\api-ms-win-core-threadpool.hpp'
$yyMain = Join-Path $up 'src\Thunks\YY_Thunks.cpp'
$listPath = Join-Path $up 'src\Thunks\YY_Thunks_List.hpp'
$exe = Join-Path $work 'yy-threadpool-owner-lifetime-hosted-x86.exe'
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

    $postNeedle = 'Fallback::DoWhenCallbackReturns(&Instance);' + $lf + $lf + '                SetEvent(Wait->hEvent);'
    $postReplace = 'Fallback::DoWhenCallbackReturns(&Instance);' + $lf + $lf +
      '                if (XP_L1_PostCallback(Wait)) return; // ONLY controlled negative test' + $lf +
      '                SetEvent(Wait->hEvent);' + $lf +
      '                XP_L1_AfterEvent(Wait);'
    $raw = Replace-One $raw $postNeedle $postReplace 'YY after callback before dereference'
    $declarations = @'
extern "C" void __cdecl XP_L1_FallbackSelected(void);
extern "C" void __cdecl XP_L1_FreeObserved(void*, int);
extern "C" int __cdecl XP_L1_PostCallback(void*);
extern "C" void __cdecl XP_L1_AfterEvent(void*);
// Injected solely into a disposable YY source checkout in CI.
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
      'scope=L1_safe_owner_model_L2_barrier_cancel_L3_shutdown_NO_FIREFOX',
      'production_provider=unchanged',
      'physical_XP_runtime=not_tested'
    ) | Set-Content -Encoding ascii diagnostics\l1-identity.txt
    Write-Host "Prepared YY v1.2.2 at $actual with test-only L1 checkpoints"
  }
  'build' {
    Need ((Test-Path $listPath) -and (Test-Path $patched)) 'YY source preparation missing'
    $yyObj = Join-Path $work 'yy-l1.obj'
    $testObj = Join-Path $work 'l1-harness.obj'
    $testSource = Join-Path (Get-Location).Path '.github\scripts\xp\yy-threadpool-lifetime-candidate.cpp'
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
    & cl.exe @hArgs *> diagnostics\l1-harness-compile.txt
    Need ($LASTEXITCODE -eq 0 -and (Test-Path $testObj)) 'L1 harness compile failed'
    $linkArgs = @('/nologo','/machine:x86','/subsystem:console','/incremental:no',
      "/out:$exe","/map:$($work)\l1.map",$testObj,$yyObj,
      'kernel32.lib','user32.lib','advapi32.lib','shlwapi.lib','ws2_32.lib','ntdll.lib','ole32.lib')
    & link.exe @linkArgs *> diagnostics\l1-link.txt
    Need ($LASTEXITCODE -eq 0 -and (Test-Path $exe)) 'Instrumented L1 linker failed'
    $importCensus = (& dumpbin.exe /nologo /imports $exe 2>&1 | Out-String)
    Need ($LASTEXITCODE -eq 0) 'L1 hosted import census unavailable'
    $importCensus | Set-Content -Encoding utf8 diagnostics\l1-hosted-imports.txt
    $pe = (& dumpbin.exe /nologo /headers $exe 2>&1 | Out-String)
    Need ($LASTEXITCODE -eq 0 -and $pe -match '(?im)^\s*14C machine \(x86\)') 'Wrong L1 host PE machine'
    $pe | Set-Content -Encoding utf8 diagnostics\l1-hosted-headers.txt
    @(
      "l1_source_sha256=$((Get-FileHash $testSource -Algorithm SHA256).Hash)",
      "instrumented_YY_object_sha256=$((Get-FileHash $yyObj -Algorithm SHA256).Hash)",
      "l1_exe_sha256=$((Get-FileHash $exe -Algorithm SHA256).Hash)",
      'hosted_PE_only=not_XP_compatible_artifact'
    ) | Add-Content -Encoding ascii diagnostics\l1-identity.txt
    Write-Host 'Test-only source-built YY 1.2.2 L1 x86 executable linked'
  }
  'hosted' {
    Need (Test-Path $exe) 'Instrumented YY lifetime binary missing'
    foreach ($scenario in @('l1','l2','l2-pending','l3')) {
      $out = Join-Path (Get-Location).Path "diagnostics\lifetime-$scenario-stdout.txt"
      $err = Join-Path (Get-Location).Path "diagnostics\lifetime-$scenario-stderr.txt"
      # New independent process and new YY callback worker per scenario.
      $psi = New-Object System.Diagnostics.ProcessStartInfo
      $psi.FileName = $exe
      $psi.Arguments = $scenario
      $psi.UseShellExecute = $false
      $psi.CreateNoWindow = $true
      $psi.RedirectStandardOutput = $true
      $psi.RedirectStandardError = $true
      $p = New-Object System.Diagnostics.Process
      $p.StartInfo = $psi
      Need ($p.Start()) "Cannot start $scenario"
      $done = $p.WaitForExit(15000)
      if (-not $done) {
        try { $p.Kill(); $p.WaitForExit() } catch {}
      }
      $log = $p.StandardOutput.ReadToEnd()
      $stderr = $p.StandardError.ReadToEnd()
      [IO.File]::WriteAllText($out,$log)
      [IO.File]::WriteAllText($err,$stderr)
      @(
        "scenario=$scenario",
        "child_exited=$done",
        "child_exit_code=$($p.ExitCode)",
        "stderr_empty=$([string]::IsNullOrEmpty($stderr))"
      ) | Add-Content -Encoding ascii diagnostics\l1-identity.txt
      Write-Host $log
      Need $done "Timed out $scenario; terminated independent child"
      Need ($p.ExitCode -eq 0) "$scenario exit code $($p.ExitCode)"
      Need ([string]::IsNullOrEmpty($stderr)) "$scenario emitted stderr"
      foreach ($want in @(
        "SCENARIO mode=$scenario",
        'kind=yy_fallback_create',
        'kind=actual_heap_free',
        'kind=cleanup_cancel_flush_return',
        'kind=cleanup_close_return',
        "RESULT mode=$scenario fallback=1",
        'free_count=1 heap_free_ok=1',
        'same_ptr=1 close_count=1 unsafe=0',
        "SAFE_OWNER_MODEL_PASS mode=$scenario"
      )) { Need ($log.Contains($want)) "$scenario missing evidence: $want" }
      if ($scenario -eq 'l2-pending') {
        Need ($log.Contains('callback_count=0 post_count=0 after_count=0')) 'Pending cancel called callback'
      } else {
        Need ($log.Contains('callback_count=1 post_count=1 after_count=1')) "$scenario lacks callback/YY epilogue"
        Need ($log.Contains('free_after_epilogue=1')) "$scenario freed PTP_WAIT before YY epilogue marker"
      }
      if ($scenario -eq 'l2' -or $scenario -eq 'l3') {
        Need ($log.Contains('kind=barrier_proved_cleanup_blocked')) "$scenario did not prove concurrent cancel waited"
      }
      if ($scenario -eq 'l3') {
        Need ($log.Contains('failed_dispatch=1 shutdown=1')) 'Shutdown/failed dispatch coverage absent'
      }
      Write-Host "$scenario: hosted forced-fallback safe-owner model PASS (NOT Firefox product fix)"
      $p.Dispose()
    }
    'hosted_owner_model=L1_L2_L2pending_L3_PASS;NOT_FIREFOX_XP_RUNTIME_PASS' |
      Add-Content -Encoding ascii diagnostics\l1-identity.txt
  }
}
