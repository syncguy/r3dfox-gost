param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('identity', 'crt', 'download', 'inventory', 'provider', 'header')]
    [string]$Stage
)

switch ($Stage) {
    'identity' {
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force diagnostics,runtime | Out-Null
@(
  'CreateWaitableTimerExA','GetTickCount64','InitializeCriticalSectionEx','CompareStringOrdinal',
  'GetCurrentProcessorNumber','GetFileInformationByHandleEx','GetFinalPathNameByHandleW',
  'GetLocaleInfoEx','LCIDToLocaleName','LocaleNameToLCID','SetFileInformationByHandle','CancelIoEx',
  'CreateWaitableTimerExW','CancelSynchronousIo','GetDynamicTimeZoneInformation','GetProcessIdOfThread',
  'GetQueuedCompletionStatusEx','GetThreadId','GetTimeZoneInformationForYear','GetThreadPreferredUILanguages',
  'GetProcessPreferredUILanguages','GetUserPreferredUILanguages','InitOnceBeginInitialize','InitOnceComplete',
  'QueryFullProcessImageNameW','QueryProcessCycleTime','QueryThreadCycleTime'
) | Set-Content -Encoding ascii diagnostics\requested-apis.txt
@(
  "repo=$env:GITHUB_REPOSITORY","test_commit=$env:GITHUB_SHA","compatibility_target=Windows XP SP3 x86",
  "yy_thunks_version=$env:YY_THUNKS_VERSION","yy_thunks_target=$env:YY_THUNKS_TARGET",
  "msvcr14x_commit=$env:MSVCR14X_SHA","inventory_evidence_run=$env:EVIDENCE_RUN",
  "inventory_evidence_job=$env:EVIDENCE_JOB","inventory_evidence_sha=$env:EVIDENCE_SHA",
  'proof_level=YY capability + hosted runner; physical XP pending',
  'production_decision=not made by this smoke'
) | Set-Content -Encoding utf8 diagnostics\identity.txt
    }
    'crt' {
$ErrorActionPreference = 'Stop'
$root = Join-Path $env:RUNNER_TEMP 'msvcr14x-cluster'
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
git init $root
git -C $root remote add origin $env:MSVCR14X_REPO
git -C $root fetch --depth=1 origin $env:MSVCR14X_SHA
git -C $root checkout --detach FETCH_HEAD
git -C $root submodule update --init --recursive --depth 1
if ((git -C $root rev-parse HEAD).Trim() -ne $env:MSVCR14X_SHA) { throw 'Unexpected msvcr14x commit' }
& msbuild.exe (Join-Path $root 'msvcr14x.sln') /m /t:Build '/p:Configuration=Release;Platform=x86' -r "/bl:$env:GITHUB_WORKSPACE\diagnostics\msvcr14x-release-x86.binlog"
if ($LASTEXITCODE -ne 0) { throw "msvcr14x build failed: $LASTEXITCODE" }
$required = @('ucrtbase.dll','ucrt.lib','vcruntime.lib','msvcprt.lib','msvcp140.dll')
$release = $null
foreach ($candidate in @(Get-ChildItem -Path $root -Recurse -File -Filter ucrtbase.dll | ForEach-Object { $_.Directory.FullName } | Sort-Object -Unique)) {
  if (@($required | Where-Object { -not (Test-Path (Join-Path $candidate $_)) }).Count) { continue }
  $headers = (& dumpbin.exe /nologo /headers (Join-Path $candidate 'ucrtbase.dll') 2>&1 | Out-String)
  if ($headers -match '(?im)^\s*14C machine \(x86\)') { $release = $candidate; break }
}
if (-not $release) { throw 'Cannot locate complete x86 msvcr14x Release output' }
"MSVCR14X_RELEASE=$release" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"resolved_msvcr14x_release=$release" | Add-Content -Encoding utf8 diagnostics\identity.txt
    }
    'download' {
$ErrorActionPreference = 'Stop'
$release = Invoke-RestMethod -Headers @{ 'User-Agent'='r3dfox-gost-ci' } -Uri "https://api.github.com/repos/Chuyu-Team/YY-Thunks/releases/tags/v$env:YY_THUNKS_VERSION"
$asset = $release.assets | Where-Object { $_.name -match '(?i)Lib.*\.zip$|(?i)-Lib\.zip$' } | Select-Object -First 1
if (-not $asset) { throw 'YY-Thunks Lib asset not found' }
$zip = Join-Path $env:RUNNER_TEMP $asset.name
$root = Join-Path $env:RUNNER_TEMP 'yy-thunks-cluster'
Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
Expand-Archive -Path $zip -DestinationPath $root
$targetPattern = [regex]::Escape($env:YY_THUNKS_TARGET)
$yyLib = Get-ChildItem -Path $root -Recurse -Directory | Where-Object { $_.FullName -match "(?i)[\\/]Lib[\\/]$targetPattern[\\/]x86$" } | Select-Object -First 1
if (-not $yyLib) { throw "YY-Thunks Lib/$env:YY_THUNKS_TARGET/x86 not found" }
$kernel32 = Join-Path $yyLib.FullName 'kernel32.lib'
$ntdll = Join-Path $yyLib.FullName 'ntdll.lib'
$synch = Join-Path $yyLib.FullName 'synchronization.lib'
if (-not (Test-Path $kernel32) -or -not (Test-Path $ntdll) -or -not (Test-Path $synch)) { throw 'Required YY libraries missing' }
"THUNK_YY_KERNEL32_LIB=$kernel32" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"THUNK_YY_NTDLL_LIB=$ntdll" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"THUNK_YY_SYNCH_LIB=$synch" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"THUNK_YY_LIB=$($yyLib.FullName)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
Get-FileHash -Algorithm SHA256 $kernel32 | Format-List | Out-String | Set-Content -Encoding utf8 diagnostics\yy-kernel32-sha256.txt
Get-FileHash -Algorithm SHA256 $ntdll | Format-List | Out-String | Set-Content -Encoding utf8 diagnostics\yy-ntdll-sha256.txt
    }
    'inventory' {
$ErrorActionPreference = 'Stop'
$members = @(& lib.exe /nologo /list $env:THUNK_YY_KERNEL32_LIB 2>&1 | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
if ($LASTEXITCODE -ne 0 -or $members.Count -eq 0) { throw 'Cannot enumerate YY kernel32.lib' }
$members | Set-Content -Encoding utf8 diagnostics\yy-kernel32-members.txt
$report = [System.Collections.Generic.List[string]]::new()
$report.Add("API`tDirectMember`tImportMember`tDecoratedSymbol`tStackBytes`tYYSymbol`tProviderCapability")
$capable = [System.Collections.Generic.List[string]]::new()
foreach ($api in (Get-Content diagnostics\requested-apis.txt)) {
  $escaped = [regex]::Escape($api)
  $directMatches = @($members | Where-Object { $_ -match "(?i)[\\/]_${escaped}@(\d+)\.obj$" })
  $importMatches = @($members | Where-Object { $_ -match "(?i)[\\/]_${escaped}@(\d+)\.obi$" })
  $direct = if ($directMatches.Count -eq 1) { $directMatches[0] } else { '' }
  $import = if ($importMatches.Count -eq 1) { $importMatches[0] } else { '' }
  $decorated=''; $stack=''; $yy='false'; $capability='missing'
  if ($direct -and $direct -match "(?i)[\\/](_${escaped}@(\d+))\.obj$") { $decorated=$matches[1]; $stack=$matches[2] }
  if ($direct) {
    $tmp = Join-Path $env:RUNNER_TEMP ("yy-cap-"+$api); New-Item -ItemType Directory -Force $tmp | Out-Null
    Push-Location $tmp
    try { & lib.exe /nologo "/extract:$direct" $env:THUNK_YY_KERNEL32_LIB | Out-Null; $obj=Get-ChildItem -File | Select-Object -First 1; if ($obj) { $sym=(& dumpbin.exe /nologo /symbols $obj.FullName 2>&1 | Out-String); if ($sym.IndexOf("YY_Thunks_$api",[System.StringComparison]::Ordinal)-ge 0) {$yy='true'} } } finally { Pop-Location }
  }
  if ($direct -and $import -and $decorated -and $yy -eq 'true') { $capability='capable'; $capable.Add($api) }
  $report.Add("$api`t$direct`t$import`t$decorated`t$stack`t$yy`t$capability")
}
$report | Set-Content -Encoding utf8 diagnostics\yy-capability.tsv
$capable | Set-Content -Encoding ascii diagnostics\capable-apis.txt
$report | ForEach-Object { Write-Host $_ }
if (-not $capable.Count) { throw 'No requested YY capability found' }
    }
    'provider' {
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:RUNNER_TEMP 'xp-core-kernel32-cluster'; $selected=Join-Path $work 'selected'
if (Test-Path $work) { Remove-Item -Recurse -Force $work }; New-Item -ItemType Directory -Force $selected | Out-Null
$members=Get-Content diagnostics\yy-kernel32-members.txt; $objects=@(); $map=[System.Collections.Generic.List[string]]::new()
foreach ($api in (Get-Content diagnostics\capable-apis.txt)) {
  foreach ($kind in @('obj','obi')) {
    $escaped=[regex]::Escape($api); $hits=@($members | Where-Object { $_ -match "(?i)[\\/]_${escaped}@\d+\.$kind$" })
    if ($hits.Count -ne 1) { throw "Expected one $api .$kind; found $($hits.Count)" }
    $dir=Join-Path $selected "$api-$kind"; New-Item -ItemType Directory -Force $dir | Out-Null
    Push-Location $dir
    try { & lib.exe /nologo "/extract:$($hits[0])" $env:THUNK_YY_KERNEL32_LIB | Out-Null; if($LASTEXITCODE-ne 0){throw 'extract failed'} } finally { Pop-Location }
    $file=Get-ChildItem $dir -File | Select-Object -First 1; $dst=Join-Path $dir 'member.obj'; Copy-Item -Force $file.FullName $dst; $objects+=$dst; $map.Add("$api-$kind|$($hits[0])")
  }
}
$impl=@($members | Where-Object { $_ -match ('(?i)[\\/]YY_Thunks_for_'+[regex]::Escape($env:YY_THUNKS_TARGET)+'\.obj$') })
if($impl.Count-ne 1){throw "Expected one common YY implementation; found $($impl.Count)"}
$dir=Join-Path $selected 'implementation'; New-Item -ItemType Directory -Force $dir|Out-Null; Push-Location $dir
try { & lib.exe /nologo "/extract:$($impl[0])" $env:THUNK_YY_KERNEL32_LIB | Out-Null } finally { Pop-Location }
$file=Get-ChildItem $dir -File | Select-Object -First 1; $dst=Join-Path $dir 'member.obj'; Copy-Item -Force $file.FullName $dst; $objects+=$dst; $map.Add("implementation|$($impl[0])")
# Exact XP x86 ProcessPrng weak-alias closure; no full YY kernel32.lib.
# Same two weak-alias members already used by the v1.2.3 SRW smoke.
$processSpecs=@(
  @{Kind='obj';Pattern='(?i)[\\/]_ProcessPrng@8\.obj$';Alias='_ProcessPrng@8'},
  @{Kind='obi';Pattern='(?i)[\\/]_ProcessPrng@8\.obi$';Alias='__imp__ProcessPrng@8'}
)
foreach($spec in $processSpecs){
  $hits=@($members|Where-Object{$_-match $spec.Pattern})
  if($hits.Count-ne 1){throw "Expected one ProcessPrng $($spec.Kind) alias; found $($hits.Count)"}
  $dir=Join-Path $selected "processprng-$($spec.Kind)";New-Item -ItemType Directory -Force $dir|Out-Null
  Push-Location $dir
  try{
    & lib.exe /nologo "/extract:$($hits[0])" $env:THUNK_YY_KERNEL32_LIB|Out-Null
    if($LASTEXITCODE-ne 0){throw "ProcessPrng $($spec.Kind) extraction failed"}
  }finally{Pop-Location}
  $file=Get-ChildItem $dir -File|Select-Object -First 1
  if(-not $file){throw "Missing ProcessPrng $($spec.Kind) object"}
  $dst=Join-Path $dir 'member.obj';Copy-Item -Force $file.FullName $dst
  $sym=(& dumpbin.exe /nologo /symbols $dst 2>&1|Out-String)
  if($sym.IndexOf($spec.Alias,[System.StringComparison]::Ordinal)-lt 0 -or
     $sym.IndexOf('YY_Thunks_ProcessPrng',[System.StringComparison]::Ordinal)-lt 0){
    throw "ProcessPrng $($spec.Kind) weak alias mismatch"
  }
  $objects+=$dst;$map.Add("processprng-$($spec.Kind)|$($hits[0])")
}
$map | Set-Content -Encoding utf8 diagnostics\selected-members.txt
$provider=Join-Path $work 'yy-xp-core-kernel32-cluster.lib'; & lib.exe /nologo "/out:$provider" @objects
if($LASTEXITCODE-ne 0){throw 'narrow provider build failed'}
$symbols=(& dumpbin.exe /nologo /linkermember:1 $provider 2>&1 | Out-String); $symbols|Set-Content -Encoding utf8 diagnostics\narrow-provider-symbols.txt
foreach($api in (Get-Content diagnostics\capable-apis.txt)){if($symbols.IndexOf("YY_Thunks_$api",[System.StringComparison]::Ordinal)-lt 0){throw "Provider missing YY_Thunks_$api"}}
if($symbols.IndexOf('YY_Thunks_ProcessPrng',[System.StringComparison]::Ordinal)-lt 0){throw 'Provider missing YY_Thunks_ProcessPrng'}
$winrtAliases=@(
  'RoActivateInstance@8',
  'RoFailFastWithErrorContext@4',
  'RoGetActivationFactory@12',
  'RoGetAgileReference@16',
  'RoGetApartmentIdentifier@4',
  'RoInitialize@4',
  'RoOriginateError@8',
  'RoOriginateErrorW@12',
  'RoOriginateLanguageException@12',
  'RoRegisterActivationFactories@16',
  'RoRegisterForApartmentShutdown@12',
  'RoRevokeActivationFactories@4',
  'RoTransformError@12',
  'RoTransformErrorW@16',
  'RoUninitialize@0',
  'RoUnregisterForApartmentShutdown@4',
  'WindowsCompareStringOrdinal@12',
  'WindowsCreateString@12',
  'WindowsCreateStringReference@16',
  'WindowsDeleteString@4',
  'WindowsDuplicateString@8',
  'WindowsGetStringLen@4',
  'WindowsGetStringRawBuffer@8',
  'WindowsIsStringEmpty@4',
  'WindowsStringHasEmbeddedNull@8'
)
foreach($entry in $winrtAliases){
  $direct="_YY_Thunks_$entry"
  $import="__imp__YY_Thunks_$entry"
  if($symbols.IndexOf(" $direct",[System.StringComparison]::Ordinal)-lt 0-or
     $symbols.IndexOf(" $import",[System.StringComparison]::Ordinal)-lt 0){
    throw "Narrow YY provider missing WinRT direct/IAT closure $entry"
  }
}
$winrtAliases|Set-Content -Encoding ascii diagnostics\winrt-closure-apis.txt
"NARROW_YY_LIB=$provider" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
    }
    'header' {
$capable=@(Get-Content diagnostics\capable-apis.txt); $lines=[System.Collections.Generic.List[string]]::new()
foreach($api in (Get-Content diagnostics\requested-apis.txt)){ $v=if($capable-contains $api){1}else{0}; $lines.Add("#define HAVE_$api $v") }
$lines | Set-Content -Encoding ascii capability.h
    }
    default { throw "Unsupported cluster stage: $Stage" }
}
