$ErrorActionPreference = 'Stop'

$dll = Join-Path $env:OBJDIR 'dist\bin\mozglue.dll'
$diag = Join-Path $env:GITHUB_WORKSPACE 'xp-x32-dpi-delay-import'
New-Item -ItemType Directory -Force $diag | Out-Null
if (-not (Test-Path $dll)) { throw "mozglue.dll missing for DPI import-mode gate: $dll" }
$raw = @(& dumpbin.exe /nologo /imports $dll 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /imports failed for mozglue.dll' }
$raw | Set-Content -Encoding utf8 (Join-Path $diag 'mozglue.dll-imports.txt')
$mode = 'none'
$currentDll = ''
$hits = [System.Collections.Generic.List[string]]::new()
foreach ($line in $raw) {
  if ($line -match '^\s*Section contains the following imports:\s*$') { $mode = 'direct'; $currentDll = ''; continue }
  if ($line -match '^\s*Section contains the following delay load imports:\s*$') { $mode = 'delay'; $currentDll = ''; continue }
  if ($line -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') { $currentDll = $matches[1]; continue }
  if ($line.IndexOf('SetProcessDPIAware', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $hits.Add("$mode|$currentDll|$($line.Trim())") }
}
$hits | Set-Content -Encoding utf8 (Join-Path $diag 'setprocessdpiaware-import-mode.txt')
$directHits = @($hits | Where-Object { $_ -like 'direct|*' })
$delayUser32Hits = @($hits | Where-Object { $_ -match '(?i)^delay\|USER32\.dll\|' })
if ($directHits.Count -gt 0) { throw 'mozglue.dll has an ordinary SetProcessDPIAware import; XP startup would remain loader-incompatible.' }
if ($delayUser32Hits.Count -ne 1 -or $hits.Count -ne 1) { throw "Expected exactly one USER32.dll delay import for SetProcessDPIAware; observed: $($hits -join '; ')" }
'result=PASS|direct=0|delay_user32=1' | Set-Content -Encoding utf8 (Join-Path $diag 'result.txt')
