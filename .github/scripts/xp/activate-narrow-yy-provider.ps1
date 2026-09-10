$ErrorActionPreference = 'Stop'

$ntdll = Join-Path $env:THUNK_YY_LIB 'ntdll.lib'
$advapi = Join-Path $env:THUNK_YY_LIB 'advapi32.lib'
$ws2 = $env:THUNK_YY_WS2_32_LIB
foreach ($required in @($env:THUNK_YY_SYNCH_LIB,$env:NARROW_YY_LIB,$env:THUNK_YY_KERNEL32_LIB,$ntdll,$advapi,$ws2)) {
  if (-not $required -or -not (Test-Path $required)) { throw "Required YY linker input missing: $required" }
}

$members = @(& lib.exe /nologo /list $ntdll 2>&1 |
  ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($LASTEXITCODE -ne 0 -or $members.Count -eq 0) { throw 'Cannot enumerate YY XP x86 ntdll.lib' }
$direct = @($members | Where-Object { $_ -match '(?i)[\\/]_NtCancelIoFileEx@12\.obj$' })
$import = @($members | Where-Object { $_ -match '(?i)[\\/]_NtCancelIoFileEx@12\.obi$' })
if ($direct.Count -ne 1 -or $import.Count -ne 1) { throw "Expected one NtCancelIoFileEx .obj/.obi pair; found obj=$($direct.Count) obi=$($import.Count)" }
$aliasWork = Join-Path $env:RUNNER_TEMP 'r3dfox-xp-x32-ntcancel-alias'
$selected = Join-Path $aliasWork 'selected'
if (Test-Path $aliasWork) { Remove-Item -Recurse -Force $aliasWork }
New-Item -ItemType Directory -Force $selected | Out-Null
$aliasObjects = @()
foreach ($item in @($direct[0],$import[0])) {
  $dir = Join-Path $selected ([IO.Path]::GetExtension($item).TrimStart('.'))
  New-Item -ItemType Directory -Force $dir | Out-Null
  Push-Location $dir
  try {
    & lib.exe /nologo "/extract:$item" $ntdll *> extract.log
    if ($LASTEXITCODE -ne 0) { throw 'NtCancelIoFileEx alias extraction failed' }
  } finally { Pop-Location }
  $file = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ne 'extract.log' } | Sort-Object Length -Descending | Select-Object -First 1
  if (-not $file) { throw 'NtCancelIoFileEx alias extraction produced no object' }
  $dst = Join-Path $dir 'member.obj'
  Copy-Item -Force $file.FullName $dst
  $aliasObjects += $dst
}
$ntCancelAlias = Join-Path $aliasWork 'yy-xp-ntcancel-alias.lib'
& lib.exe /nologo "/out:$ntCancelAlias" @aliasObjects
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ntCancelAlias)) { throw 'NtCancelIoFileEx alias library build failed' }
$aliasSymbols = (& dumpbin.exe /nologo /linkermember:1 $ntCancelAlias 2>&1 | Out-String)
$aliasSymbols | Set-Content -Encoding utf8 (Join-Path $aliasWork 'alias-symbols.txt')
if ($aliasSymbols.IndexOf('_NtCancelIoFileEx@12',[System.StringComparison]::Ordinal) -lt 0) { throw 'NtCancelIoFileEx alias library lacks the x86 entry symbol' }
$providerSymbols = (& dumpbin.exe /nologo /linkermember:1 $env:NARROW_YY_LIB 2>&1 | Out-String)
if ($providerSymbols.IndexOf('_YY_Thunks_NtCancelIoFileEx@12',[System.StringComparison]::Ordinal) -lt 0) { throw 'Proven narrow provider lacks YY_Thunks_NtCancelIoFileEx implementation' }
@(
  "direct=$($direct[0])",
  "import=$($import[0])",
  "alias_provider=$ntCancelAlias",
  'implementation=existing NARROW_YY_LIB common YY object',
  'evidence_run=33861819326',
  'evidence_job=100987750213',
  'evidence_sha=be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2',
  'capability=PASS'
) | Set-Content -Encoding utf8 diagnostics\yy-ntcancel-capability.txt

$etwApis = @('EventRegister','EventUnregister','EventWrite','EventWriteTransfer','RegGetValueW')
$advapiMembers = @(& lib.exe /nologo /list $advapi 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($LASTEXITCODE -ne 0 -or $advapiMembers.Count -eq 0) { throw 'Cannot enumerate YY XP x86 advapi32.lib' }
$etwAliasWork = Join-Path $env:RUNNER_TEMP 'r3dfox-xp-x32-advapi32-etw-alias'
$etwSelected = Join-Path $etwAliasWork 'selected'
if (Test-Path $etwAliasWork) { Remove-Item -Recurse -Force $etwAliasWork }
New-Item -ItemType Directory -Force $etwSelected | Out-Null
$etwAliasObjects = @()
$etwEvidence = [System.Collections.Generic.List[string]]::new()
foreach ($api in $etwApis) {
  $escaped = [regex]::Escape($api)
  $direct = @($advapiMembers | Where-Object { $_ -match "(?i)[\\/]_${escaped}@\d+\.obj$" })
  $import = @($advapiMembers | Where-Object { $_ -match "(?i)[\\/]_${escaped}@\d+\.obi$" })
  if ($direct.Count -ne 1 -or $import.Count -ne 1) { throw "Expected one $api .obj/.obi pair; found obj=$($direct.Count) obi=$($import.Count)" }
  $etwEvidence.Add("$api|direct=$($direct[0])|import=$($import[0])")
  foreach ($item in @($direct[0],$import[0])) {
    $kind = [IO.Path]::GetExtension($item).TrimStart('.')
    $dir = Join-Path $etwSelected "$api-$kind"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Push-Location $dir
    try { & lib.exe /nologo "/extract:$item" $advapi *> extract.log; if ($LASTEXITCODE -ne 0) { throw "$api alias extraction failed" } } finally { Pop-Location }
    $file = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ne 'extract.log' } | Sort-Object Length -Descending | Select-Object -First 1
    if (-not $file) { throw "$api alias extraction produced no object" }
    $dst = Join-Path $dir 'member.obj'
    Copy-Item -Force $file.FullName $dst
    $etwAliasObjects += $dst
  }
}
$advapiEtwAlias = Join-Path $etwAliasWork 'yy-xp-advapi32-etw-alias.lib'
& lib.exe /nologo "/out:$advapiEtwAlias" @etwAliasObjects
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $advapiEtwAlias)) { throw 'ADVAPI32 alias library build failed' }
$etwAliasSymbols = (& dumpbin.exe /nologo /linkermember:1 $advapiEtwAlias 2>&1 | Out-String)
$etwAliasSymbols | Set-Content -Encoding utf8 (Join-Path $etwAliasWork 'alias-symbols.txt')
foreach ($api in $etwApis) {
  if ($etwAliasSymbols.IndexOf($api,[System.StringComparison]::Ordinal) -lt 0) { throw "ADVAPI32 alias provider missing $api" }
  if ($providerSymbols.IndexOf("YY_Thunks_$api",[System.StringComparison]::Ordinal) -lt 0) { throw "Proven narrow provider lacks YY_Thunks_$api implementation" }
}
$etwEvidence.Add("alias_provider=$advapiEtwAlias")
$etwEvidence.Add('implementation=existing NARROW_YY_LIB common YY object')
$etwEvidence.Add('apis=EventRegister,EventUnregister,EventWrite,EventWriteTransfer,RegGetValueW')
$etwEvidence.Add('etw_evidence_run=33882235341')
$etwEvidence.Add('etw_evidence_job=101053403554')
$etwEvidence.Add('etw_evidence_sha=53971dcfdf12e7bcd7f35692ff2c02fb3360d792')
$etwEvidence.Add('reggetvaluew_evidence_run=33946751857')
$etwEvidence.Add('reggetvaluew_evidence_job=101254130849')
$etwEvidence.Add('reggetvaluew_evidence_sha=8ad1d5e9a935ed1cce8ee268f693af72aad1f7c4')
$etwEvidence.Add('capability=PASS')
$etwEvidence | Set-Content -Encoding utf8 diagnostics\yy-etw-capability.txt

$ws2Apis = @(@{ Name='WSAIoctl'; Stack=36 }, @{ Name='inet_ntop'; Stack=16 })
$ws2Members = @(& lib.exe /nologo /list $ws2 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($LASTEXITCODE -ne 0 -or $ws2Members.Count -eq 0) { throw 'Cannot enumerate YY XP x86 ws2_32.lib' }
$ws2AliasWork = Join-Path $env:RUNNER_TEMP 'r3dfox-xp-x32-ws2_32-alias'
$ws2Selected = Join-Path $ws2AliasWork 'selected'
if (Test-Path $ws2AliasWork) { Remove-Item -Recurse -Force $ws2AliasWork }
New-Item -ItemType Directory -Force $ws2Selected | Out-Null
$ws2AliasObjects = @()
$ws2Evidence = [System.Collections.Generic.List[string]]::new()
foreach ($spec in $ws2Apis) {
  $api = $spec.Name
  $stack = $spec.Stack
  $escaped = [regex]::Escape($api)
  $direct = @($ws2Members | Where-Object { $_ -match "(?i)[\\/]_${escaped}@$stack\.obj$" })
  $import = @($ws2Members | Where-Object { $_ -match "(?i)[\\/]_${escaped}@$stack\.obi$" })
  if ($direct.Count -ne 1 -or $import.Count -ne 1) { throw "Expected one proven $api @$stack .obj/.obi pair; found obj=$($direct.Count) obi=$($import.Count)" }
  if ($providerSymbols.IndexOf("YY_Thunks_$api",[System.StringComparison]::Ordinal) -lt 0) { throw "Proven narrow provider lacks YY_Thunks_$api implementation" }
  $ws2Evidence.Add("$api|direct=$($direct[0])|import=$($import[0])")
  foreach ($item in @($direct[0],$import[0])) {
    $kind = [IO.Path]::GetExtension($item).TrimStart('.')
    $dir = Join-Path $ws2Selected "$api-$kind"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Push-Location $dir
    try { & lib.exe /nologo "/extract:$item" $ws2 *> extract.log; if ($LASTEXITCODE -ne 0) { throw "$api alias extraction failed" } } finally { Pop-Location }
    $file = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ne 'extract.log' } | Sort-Object Length -Descending | Select-Object -First 1
    if (-not $file) { throw "$api alias extraction produced no object"}
    $dst = Join-Path $dir 'member.obj'
    Copy-Item -Force $file.FullName $dst
    $ws2AliasObjects += $dst
  }
}
$ws2Alias = Join-Path $ws2AliasWork 'yy-xp-ws2_32-alias.lib'
& lib.exe /nologo "/out:$ws2Alias" @ws2AliasObjects
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ws2Alias)) { throw 'WS2_32 alias library build failed' }
$ws2AliasSymbols = (& dumpbin.exe /nologo /linkermember:1 $ws2Alias 2>&1 | Out-String)
$ws2AliasSymbols | Set-Content -Encoding utf8 (Join-Path $ws2AliasWork 'alias-symbols.txt')
foreach ($spec in $ws2Apis) { if ($ws2AliasSymbols.IndexOf($spec.Name,[System.StringComparison]::Ordinal) -lt 0) { throw "WS2_32 alias provider missing $($spec.Name)" } }
$ws2Evidence.Add("alias_provider=$ws2Alias")
$ws2Evidence.Add('implementation=existing NARROW_YY_LIB common YY object')
$ws2Evidence.Add('apis=WSAIoctl,inet_ntop')
$ws2Evidence.Add('evidence_run=34021400841')
$ws2Evidence.Add('evidence_job=101454550948')
$ws2Evidence.Add('evidence_sha=5451673565030445262f5b6ef48b4059e0e0501e')
$ws2Evidence.Add('capability=PASS')
$ws2Evidence | Set-Content -Encoding utf8 diagnostics\yy-ws2_32-capability.txt

$yySynch = $env:THUNK_YY_SYNCH_LIB -replace '\\','/'
$narrow = $env:NARROW_YY_LIB -replace '\\','/'
$ntCancelAliasLink = $ntCancelAlias -replace '\\','/'
$advapiEtwAliasLink = $advapiEtwAlias -replace '\\','/'
$ws2AliasLink = $ws2Alias -replace '\\','/'
$fullKernel32 = $env:THUNK_YY_KERNEL32_LIB -replace '\\','/'
$fullNtdll = $ntdll -replace '\\','/'
$fullAdvapi = $advapi -replace '\\','/'
$fullWs2 = $ws2 -replace '\\','/'
$targetLdflags = "$env:LDFLAGS $ntCancelAliasLink $advapiEtwAliasLink $ws2AliasLink $narrow $yySynch".Trim()
if ($targetLdflags.IndexOf($fullKernel32, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Invariant violation: full YY kernel32.lib was injected into global target LDFLAGS' }
if ($targetLdflags.IndexOf($fullNtdll, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Invariant violation: full YY ntdll.lib was injected into global target LDFLAGS' }
if ($targetLdflags.IndexOf($fullAdvapi, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Invariant violation: full YY advapi32.lib was injected into global target LDFLAGS' }
if ($targetLdflags.IndexOf($fullWs2, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'Invariant violation: full YY ws2_32.lib was injected into global target LDFLAGS' }
"LDFLAGS=$targetLdflags" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
@(
  'scope=all-target-links',
  "ntcancel_alias_provider=$ntCancelAliasLink",
  "advapi32_etw_alias_provider=$advapiEtwAliasLink",
  "ws2_32_alias_provider=$ws2AliasLink",
  "narrow_provider=$narrow",
  "synchronization_lib=$yySynch",
  'full_kernel32_lib=prohibited',
  'full_ntdll_lib=prohibited',
  'full_advapi32_lib=prohibited',
  'full_ws2_32_lib=prohibited',
  "target_ldflags=$targetLdflags"
) | Set-Content -Encoding utf8 diagnostics\xp-x32-global-yy-link-contract.txt
