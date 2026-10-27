param(
  [Parameter(Mandatory = $true)][string]$DistBin,
  [Parameter(Mandatory = $true)][string]$ReportDir,
  [int]$TimeoutSeconds = 180
)
$ErrorActionPreference = 'Stop'
$tested = 'e9375fb5f8bb7eb2b783a40b1a86abc6040a6919'
$controller = 'd5e78c8dfa6574f3e27967a32637e705771ca93c'
$hashes = [ordered]@{
  'r3dfox.exe' = '098470d7d2c8b3b2bc4a51e7172a8d0bbb4392096df4ec078ad9afb5b6b253c7'
  'xul.dll' = '2aaf6884d6987857c4fec483c7964181f3b20ea1677be42e5145493cf68cad2f'
  'gtest/xul.dll' = '76fcb3ca258ad127d2812918da29e2d18a68b5d418261c6f9ec01a83b9aae96e'
}
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null
$outFile = Join-Path $ReportDir 'gtest-stdout.log'
$errFile = Join-Path $ReportDir 'gtest-stderr.log'
$reportFile = Join-Path $ReportDir 'gtest-result.json'
$report = [ordered]@{
  schema = 'xp-handlewatcher-039-prebuilt-gtest-v1'
  build_run_id = '40519752469'
  build_job_id = '122245422443'
  source_under_test_sha = $tested
  build_controller_sha = $controller
  test_controller_sha = $env:GITHUB_SHA
  host = 'windows-2022'
  gtest_filter = 'TestHandleWatcher.*'
  test_started = $false
  timed_out = $false
  exit_code = $null
  observed_run = 0
  observed_ok = 0
  observed_failed = 0
  regression_test_observed = $false
  verdict = 'NOT_RUN'
  failure = $null
  verified_files = @()
}
$proc = $null
$success = $false
try {
  if ($TimeoutSeconds -lt 30 -or $TimeoutSeconds -gt 300) {
    throw 'TimeoutSeconds must be in 30-300'
  }
  $dist = (Resolve-Path -LiteralPath $DistBin).Path
  $manifestPath = Join-Path $dist 'xp-gtest-build-manifest.json'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'Original 038 build manifest is missing'
  }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
  if ($manifest.schema -ne 'xp-handlewatcher-gtest-bundle-v2' -or
      $manifest.source_under_test_sha -ne $tested -or
      $manifest.controller_commit_sha -ne $controller) {
    throw '038 manifest source/controller/schema identity mismatch'
  }
  foreach ($rel in $hashes.Keys) {
    $file = Join-Path $dist $rel.Replace('/', '\')
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
      throw "Missing linked file: $rel"
    }
    $hash = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne $hashes[$rel]) { throw "SHA mismatch for $rel : $hash" }
    $records = @($manifest.files | Where-Object { $_.path -eq $rel })
    if ($records.Count -ne 1 -or $records[0].sha256 -ne $hash) {
      throw "Manifest hash mismatch for $rel"
    }
    $report.verified_files += [ordered]@{ path = $rel; sha256 = $hash }
    Write-Host "VERIFIED_BINARY=$rel SHA256=$hash"
  }
  $list = Join-Path $dist 'dependentlibs.list.gtest'
  if (-not (Test-Path -LiteralPath $list -PathType Leaf)) {
    throw 'dependentlibs.list.gtest missing'
  }
  $dependencies = @(Get-Content -LiteralPath $list |
      ForEach-Object { $_.Trim().Replace('\', '/') } |
      Where-Object { $_ })
  if ($dependencies.Count -lt 2 -or $dependencies[-1] -ne 'gtest/xul.dll') {
    throw 'Gtest loader list does not end with gtest/xul.dll'
  }
  foreach ($rel in $dependencies) {
    if (-not (Test-Path -LiteralPath (Join-Path $dist $rel.Replace('/', '\')) -PathType Leaf)) {
      throw "Missing loader dependency: $rel"
    }
  }
  foreach ($rel in @('application.ini', 'platform.ini')) {
    if (-not (Test-Path -LiteralPath (Join-Path $dist $rel) -PathType Leaf)) {
      throw "Missing runtime metadata: $rel"
    }
  }
  $env:MOZ_XRE_DIR = $dist
  $env:MOZ_RUN_GTEST = 'True'
  $env:GTEST_FILTER = 'TestHandleWatcher.*'
  $env:MOZ_GMP_PATH = (@(
    (Join-Path $dist 'gmp-fake\1.0'),
    (Join-Path $dist 'gmp-fakeopenh264\1.0')
  ) -join [IO.Path]::PathSeparator)
  $env:MOZ_WEBRENDER = '0'
  $env:MOZ_HEADLESS = '1'
  $env:MOZ_CRASHREPORTER_DISABLE = '1'
  $env:GTEST_COLOR = 'no'
  $exe = Join-Path $dist 'r3dfox.exe'
  $args = @('-unittest', '--gtest_death_test_style=threadsafe', '--wait-for-browser')
  Write-Host "GTEST_FILTER=$env:GTEST_FILTER GTEST_TIMEOUT_SEC=$TimeoutSeconds"
  $report.test_started = $true
  $proc = Start-Process -FilePath $exe -ArgumentList $args -WorkingDirectory $dist -RedirectStandardOutput $outFile -RedirectStandardError $errFile -PassThru
  if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
    $report.timed_out = $true
    & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-String | Write-Host
    throw 'Focused gtest watchdog expired'
  }
  $proc.WaitForExit()
  $report.exit_code = $proc.ExitCode
  $out = if (Test-Path -LiteralPath $outFile) { Get-Content -LiteralPath $outFile -Raw } else { '' }
  $err = if (Test-Path -LiteralPath $errFile) { Get-Content -LiteralPath $errFile -Raw } else { '' }
  $combined = $out + [Environment]::NewLine + $err
  $report.observed_run = [regex]::Matches($combined, '(?m)^\[\s*RUN\s*\]\s+TestHandleWatcher\.').Count
  $report.observed_ok = [regex]::Matches($combined, '(?m)^\[\s*OK\s*\]\s+TestHandleWatcher\.').Count
  $report.observed_failed = [regex]::Matches($combined, '(?m)^\[\s*FAILED\s*\]\s+TestHandleWatcher\.').Count
  $report.regression_test_observed = $combined.Contains('TestHandleWatcher.DispatchFailureRunnableDestructorStop')
  Write-Host "GTEST_EXIT=$($proc.ExitCode) RUN=$($report.observed_run) OK=$($report.observed_ok) FAILED=$($report.observed_failed) XP_REGRESSION_SEEN=$($report.regression_test_observed)"
  if ($proc.ExitCode -ne 0) { throw "Gtest process exited $($proc.ExitCode)" }
  if ($report.observed_run -lt 1 -or $report.observed_run -ne $report.observed_ok) {
    throw 'No complete focused gtest PASS sequence observed'
  }
  if ($report.observed_failed -gt 0 -or $combined.Contains('TEST-UNEXPECTED-FAIL')) {
    throw 'Gtest failure markers in output'
  }
  if (-not $report.regression_test_observed) {
    throw 'XP DispatchFailureRunnableDestructorStop gtest was not observed'
  }
  $report.verdict = 'HOSTED_GTEST_PASS'
  $success = $true
} catch {
  $report.verdict = 'NO_GTEST_PASS'
  $report.failure = $_.Exception.Message
  Write-Host "GTEST_FAILURE=$($report.failure)"
} finally {
  if ($proc -and -not $proc.HasExited) {
    & taskkill.exe /PID $proc.Id /T /F 2>&1 | Out-String | Write-Host
  }
  foreach ($file in @($outFile, $errFile)) {
    if (Test-Path -LiteralPath $file -PathType Leaf) {
      Write-Host "===== $(Split-Path -Leaf $file) (last 80 lines) ====="
      Get-Content -LiteralPath $file -Tail 80 | ForEach-Object { Write-Host $_ }
    }
  }
  $report | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $reportFile -Encoding UTF8
  Write-Host "GTEST_REPORT=$reportFile VERDICT=$($report.verdict)"
}
if (-not $success) { exit 1 }
Write-Host 'HOSTED_HANDLEWATCHER_GTEST_PASS'
