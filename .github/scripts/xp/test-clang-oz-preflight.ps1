$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$clang = Join-Path $env:USERPROFILE '.mozbuild\clang\bin\clang-cl.exe'
if (-not (Test-Path -LiteralPath $clang)) {
  throw 'Expected Firefox-bootstrap clang-cl was not installed'
}

$versionOutput = @(& $clang --version 2>&1) -join "`n"
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch 'clang version 21\.1\.8\b') {
  throw "Expected project clang-cl 21.1.8, got: $versionOutput"
}
Write-Host 'Compiler identity PASS: clang-cl 21.1.8'

$root = Join-Path $env:RUNNER_TEMP 'xp-clang-oz-preflight'
New-Item -ItemType Directory -Force -Path $root | Out-Null

function Invoke-Probe {
  param(
    [string] $Name,
    [string] $Dir,
    [string[]] $Flags
  )
  $stdout = Join-Path $Dir "$Name.stdout.txt"
  $stderr = Join-Path $Dir "$Name.stderr.txt"
  $arguments = $Flags -join ' '
  $p = Start-Process -FilePath $clang -ArgumentList $arguments -WorkingDirectory $Dir -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
  $out = (Get-Content -LiteralPath $stdout -Raw) + "`n" + (Get-Content -LiteralPath $stderr -Raw)
  return [pscustomobject]@{ ExitCode = $p.ExitCode; Output = $out }
}

function Require-Success {
  param([string] $Label, $Result)
  if ($Result.ExitCode -ne 0 -or $Result.Output -match 'argument unused during compilation') {
    throw "$Label failed: $($Result.Output)"
  }
}

$cases = @(
  @{ Ext = 'c'; Label = 'C'; Source = 'int oz_preflight_c(int n) { int s = 0; for (int i = 0; i < n; ++i) s += i * 3 + 1; return s; }' },
  @{ Ext = 'cpp'; Label = 'C++'; Source = 'extern "C" int oz_preflight_cpp(int n) { int s = 0; for (int i = 0; i < n; ++i) s += i * 3 + 1; return s; }' }
)

foreach ($case in $cases) {
  $dir = Join-Path $root $case.Ext
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $filename = "probe.$($case.Ext)"
  [System.IO.File]::WriteAllText((Join-Path $dir $filename), $case.Source, (New-Object System.Text.UTF8Encoding($false)))

  $bad = Invoke-Probe 'bad-raw-Oz' $dir @('-m32', '-Oz', '-Werror=unused-command-line-argument', '-c', $filename)
  if ($bad.ExitCode -eq 0 -or $bad.Output -notmatch "argument unused during compilation: '-Oz'") {
    throw "Negative control did not reproduce ignored raw -Oz for $($case.Label): $($bad.Output)"
  }
  Write-Host "Negative control PASS: raw -Oz rejected for $($case.Label)"

  $driver = Invoke-Probe 'cc1-probe' $dir @('-m32', '-O2', '/clang:-Oz', '-Werror=unused-command-line-argument', '-###', '-c', $filename)
  Require-Success "clang-cl -### for $($case.Label)" $driver
  $cc1Lines = @($driver.Output -split "`r?`n" | Where-Object { $_ -match '(?<!\S)"?-cc1"?(?!\S)' })
  if ($cc1Lines.Count -ne 1) {
    throw "Expected one cc1 invocation for $($case.Label), found $($cc1Lines.Count)"
  }
  $cc1 = $cc1Lines[0]
  if ($cc1 -notmatch '(?<!\S)"?-Oz"?(?!\S)' -or $cc1 -match '(?<!\S)"?-O2"?(?!\S)') {
    throw "cc1 did not select -Oz over -O2 for $($case.Label): $cc1"
  }
  Write-Host "Driver PASS: $($case.Label) cc1 uses -Oz (not -O2)"

  foreach ($mode in @('O2', 'Os', 'Oz')) {
    $flags = switch ($mode) {
      'O2' { @('-m32', '-O2') }
      'Os' { @('-m32', '-Os') }
      'Oz' { @('-m32', '-O2', '/clang:-Oz') }
    }
    $result = Invoke-Probe "ir-$mode" $dir ($flags + @('-Werror=unused-command-line-argument', '/clang:-emit-llvm', '/clang:-S', $filename))
    Require-Success "$mode IR for $($case.Label)" $result

    $irPath = Join-Path $dir 'probe.ll'
    if (-not (Test-Path -LiteralPath $irPath)) {
      throw "Missing LLVM IR for $mode / $($case.Label)"
    }
    $ir = Get-Content -LiteralPath $irPath -Raw
    $hasOptSize = [regex]::IsMatch($ir, '(?m)^attributes #\d+ = \{[^\r\n]*\boptsize\b')
    $hasMinSize = [regex]::IsMatch($ir, '(?m)^attributes #\d+ = \{[^\r\n]*\bminsize\b')
    if ($mode -eq 'O2' -and ($hasOptSize -or $hasMinSize)) {
      throw "Control O2 unexpectedly has size attributes for $($case.Label)"
    }
    if ($mode -eq 'Os' -and (-not $hasOptSize -or $hasMinSize)) {
      throw "Control Os IR attributes invalid for $($case.Label)"
    }
    if ($mode -eq 'Oz' -and (-not $hasOptSize -or -not $hasMinSize)) {
      throw "Effective Oz IR is missing both optsize and minsize for $($case.Label)"
    }
    Write-Host "IR PASS: $($case.Label) $mode optsize=$hasOptSize minsize=$hasMinSize"
  }
}

Write-Host 'XP clang-cl -Oz preflight PASS: compiler 21.1.8, raw negative control, cc1 and C/C++ IR'
