$ErrorActionPreference = 'Stop'

$xul = Join-Path $env:OBJDIR 'dist\bin\xul.dll'
$diag = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-source-remediation-quartet'
New-Item -ItemType Directory -Force $diag | Out-Null

if (-not (Test-Path $xul)) {
  'result=FAIL|reason=xul.dll missing' | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
  throw "xul.dll missing for source-remediation quartet gate: $xul"
}

$raw = (& dumpbin.exe /nologo /imports $xul 2>&1 | Out-String)
$dumpbinExit = $LASTEXITCODE
$raw | Set-Content -Encoding utf8 (Join-Path $diag 'xul.dll-imports.txt')
if ($dumpbinExit -ne 0) {
  "result=FAIL|reason=dumpbin exit $dumpbinExit" | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
  throw "dumpbin /imports failed for xul.dll with exit $dumpbinExit"
}

$apis = @('GetApplicationRestartSettings','RegisterApplicationRestart','UnregisterApplicationRestart','GetNamedPipeServerProcessId')
$hits = [System.Collections.Generic.List[string]]::new()
foreach ($api in $apis) {
  if ($raw.IndexOf($api, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
    $hits.Add($api)
  }
}

$hits | Set-Content -Encoding utf8 (Join-Path $diag 'surviving-quartet-imports.txt')
if ($hits.Count -gt 0) {
  ("result=FAIL|surviving=" + ($hits -join ',')) | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
  throw ("xul.dll still imports source-remediation quartet members: " + ($hits -join ', '))
}

'result=PASS|surviving=none' | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
Write-Host 'xul.dll contains none of the four source-remediation imports.'
