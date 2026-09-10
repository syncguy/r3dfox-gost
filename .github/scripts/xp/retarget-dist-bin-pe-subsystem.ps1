$ErrorActionPreference = 'Stop'

$bin = Join-Path $env:OBJDIR 'dist\bin'
$rows = [System.Collections.Generic.List[string]]::new()
$targets = @(Get-ChildItem -LiteralPath $bin -Recurse -File | Where-Object { $_.Extension -in @('.exe','.dll') })
foreach ($target in $targets) {
  $headers = @(& dumpbin.exe /nologo /headers $target.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed: $($target.FullName)" }
  $machine = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+ machine ' } | Select-Object -First 1
  if (-not $machine -or $machine -notmatch '(?i)^\s*14C machine \(x86\)') { continue }
  $subsystem = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+ subsystem \(' } | Select-Object -First 1
  if (-not $subsystem) { continue }
  if ($subsystem -match '(?i)Windows CUI') { $kind = 'CONSOLE' } elseif ($subsystem -match '(?i)Windows GUI') { $kind = 'WINDOWS' } else { continue }
  & editbin.exe /nologo "/SUBSYSTEM:$kind,$env:WINDOWS_XP_SUBSYSTEM" $target.FullName
  if ($LASTEXITCODE -ne 0) { throw "editbin failed for $($target.FullName)" }
  $rows.Add("$($target.FullName)|$kind|$env:WINDOWS_XP_SUBSYSTEM")
}
$rows | Set-Content -Encoding utf8 xp-x32-retargeted-pe.txt
