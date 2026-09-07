New-Item -ItemType Directory -Force diagnostics | Out-Null
$xul = Join-Path $env:OBJDIR 'dist\bin\xul.dll'
$resultPath = 'diagnostics\xul-iphlpapi-xp-imports.txt'
$rawPath = 'diagnostics\xul-iphlpapi-xp-imports-raw.txt'
if (-not (Test-Path $xul)) {
  'result=INCONCLUSIVE|reason=xul.dll missing' | Set-Content -Encoding utf8 $resultPath
  Write-Warning "xul.dll missing for IPHLPAPI diagnostic: $xul"
  exit 0
}
$raw = @(& dumpbin.exe /nologo /imports $xul 2>&1)
$dumpbinExit = $LASTEXITCODE
$raw | Set-Content -Encoding utf8 $rawPath
if ($dumpbinExit -ne 0) {
  "result=INCONCLUSIVE|reason=dumpbin exit $dumpbinExit" | Set-Content -Encoding utf8 $resultPath
  Write-Warning "dumpbin /imports failed for xul.dll with exit $dumpbinExit"
  exit 0
}
$expectedRemoved = @('NotifyIpInterfaceChange','CancelMibChangeNotify2','GetIpInterfaceTable','FreeMibTable','if_indextoname')
$xpSafe = @('GetAdaptersAddresses','GetBestInterfaceEx')
$tracked = @($expectedRemoved + $xpSafe)
$seen = @{}
foreach ($api in $tracked) { $seen[$api] = $false }
$rows = [System.Collections.Generic.List[string]]::new()
$mode = 'none'
$currentDll = ''
foreach ($line in $raw) {
  if ($line -match '^\s*Section contains the following imports:\s*$') { $mode = 'direct'; $currentDll = ''; continue }
  if ($line -match '^\s*Section contains the following delay load imports:\s*$') { $mode = 'delay'; $currentDll = ''; continue }
  if ($line -match '^\s{4}([A-Za-z0-9_.-]+\.dll)\s*$') { $currentDll = $matches[1]; continue }
  if ($currentDll -notmatch '(?i)^IPHLPAPI\.dll$') { continue }
  foreach ($api in $tracked) {
    if ($line.IndexOf($api, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $seen[$api] = $true; $rows.Add("hit|api=$api|mode=$mode|dll=$currentDll|line=$($line.Trim())") }
  }
}
$survivors = [System.Collections.Generic.List[string]]::new()
foreach ($api in $expectedRemoved) { $present = [bool]$seen[$api]; $rows.Add("expected_absent|api=$api|present=$($present.ToString().ToLowerInvariant())"); if ($present) { $survivors.Add($api) } }
foreach ($api in $xpSafe) { $present = [bool]$seen[$api]; $rows.Add("xp_safe|api=$api|present=$($present.ToString().ToLowerInvariant())") }
if ($survivors.Count -eq 0) { $rows.Add('result=EXPECTED|post_vista_survivors=none') } else { $rows.Add("result=UNEXPECTED|post_vista_survivors=$($survivors -join ',')") }
$rows | Set-Content -Encoding utf8 $resultPath
$rows | ForEach-Object { Write-Host $_ }
