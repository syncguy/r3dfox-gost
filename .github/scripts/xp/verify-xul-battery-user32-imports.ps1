$ErrorActionPreference = 'Stop'

$xul = Join-Path $env:OBJDIR 'dist\bin\xul.dll'
$diag = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-battery-power-import'
New-Item -ItemType Directory -Force $diag | Out-Null

if (-not (Test-Path $xul)) {
  'result=FAIL|reason=xul.dll missing' | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
  throw "xul.dll missing for battery power import gate: $xul"
}

$raw = @(& dumpbin.exe /nologo /imports $xul 2>&1)
$dumpbinExit = $LASTEXITCODE
$raw | Set-Content -Encoding utf8 (Join-Path $diag 'xul.dll-imports.txt')
if ($dumpbinExit -ne 0) {
  "result=FAIL|reason=dumpbin exit $dumpbinExit" | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
  throw "dumpbin /imports failed for xul.dll with exit $dumpbinExit"
}

$apis = @('RegisterPowerSettingNotification','UnregisterPowerSettingNotification')
$mode = 'none'
$currentDll = ''
$hits = [System.Collections.Generic.List[string]]::new()

foreach ($line in $raw) {
  if ($line -match '^\s*Section contains the following imports:\s*$') {
    $mode = 'direct'
    $currentDll = ''
    continue
  }
  if ($line -match '^\s*Section contains the following delay load imports:\s*$') {
    $mode = 'delay'
    $currentDll = ''
    continue
  }
  if ($line -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') {
    $currentDll = $matches[1]
    continue
  }
  if ($mode -notin @('direct','delay') -or $currentDll -notmatch '(?i)^USER32\.dll$') {
    continue
  }

  foreach ($api in $apis) {
    if ($line.IndexOf($api,[System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
      $hits.Add("$mode|$api")
    }
  }
}

$unique = @($hits | Sort-Object -Unique)
$unique | Set-Content -Encoding utf8 (Join-Path $diag 'surviving-battery-power-imports.txt')
if ($unique.Count -gt 0) {
  ("result=FAIL|surviving=" + ($unique -join ',')) | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
  throw ("xul.dll still imports Vista-only battery USER32 APIs: " + ($unique -join ', '))
}

'result=PASS|surviving=none' | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
