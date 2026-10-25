# G1a --enable-tests only. Add the four physically XP-proven YY 1.2.2
# Threadpool Wait weak-alias pairs without modifying production build scripts.
$ErrorActionPreference = 'Stop'

if ($env:YY_THUNKS_VERSION -ne '1.2.2' -or $env:YY_THUNKS_TARGET -ne '5.1.2600.0') {
  throw "G1a Threadpool YY overlay requires pinned 1.2.2/5.1.2600.0"
}
if (-not $env:NARROW_YY_LIB -or -not (Test-Path -LiteralPath $env:NARROW_YY_LIB)) {
  throw 'Expected already built primary narrow YY provider is missing'
}
if (-not $env:THUNK_YY_KERNEL32_LIB -or -not (Test-Path -LiteralPath $env:THUNK_YY_KERNEL32_LIB)) {
  throw 'Expected pinned YY kernel32.lib is missing'
}
if ([string]::IsNullOrWhiteSpace($env:LDFLAGS)) {
  throw 'Expected already activated narrow YY target LDFLAGS are missing'
}
$memberText = @(& lib.exe /nologo /list $env:THUNK_YY_KERNEL32_LIB 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory pinned YY kernel32 library' }
$members = @($memberText | ForEach-Object { "$_".Trim() } | Where-Object { $_ } | Select-Object -Unique)
$apis = @(
  @{ Name='CreateThreadpoolWait'; Stack=12 },
  @{ Name='SetThreadpoolWait'; Stack=12 },
  @{ Name='WaitForThreadpoolWaitCallbacks'; Stack=8 },
  @{ Name='CloseThreadpoolWait'; Stack=4 }
)
$work = Join-Path $env:RUNNER_TEMP 'g1a-threadpool-yy-overlay'
$selected = Join-Path $work 'selected'
if (Test-Path -LiteralPath $work) { Remove-Item -Recurse -Force -LiteralPath $work }
New-Item -ItemType Directory -Force -Path $selected,'diagnostics' | Out-Null
$objects = [System.Collections.Generic.List[string]]::new()
$inventory = [System.Collections.Generic.List[string]]::new()
$symbols = (& dumpbin.exe /nologo /linkermember:1 $env:NARROW_YY_LIB 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'Cannot verify existing common YY implementations' }

# The existing production narrow provider already has the proven SRW .obj/.obi
# pair for each of these three dependencies, plus the common YY implementation.
foreach ($api in @('InitializeSRWLock','AcquireSRWLockExclusive','ReleaseSRWLockExclusive')) {
  if ($symbols.IndexOf("YY_Thunks_$api", [StringComparison]::Ordinal) -lt 0) {
    throw "Expected existing product narrow provider to supply YY_Thunks_$api"
  }
}
foreach ($api in $apis) {
  $name = $api.Name
  if ($symbols.IndexOf("YY_Thunks_$name", [StringComparison]::Ordinal) -lt 0) {
    throw "Existing common YY implementation lacks $name"
  }
  foreach ($ext in @('obj','obi')) {
    $pattern = '(?i)[\\/]_' + [regex]::Escape($name) + '@' + $api.Stack + '\.' + $ext + '$'
    $matches = @($members | Where-Object { $_ -match $pattern })
    if ($matches.Count -ne 1) { throw "Expected exactly one $name @$($api.Stack) .$ext, got $($matches.Count)" }
    $dir = Join-Path $selected "$name-$ext"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Push-Location $dir
    try {
      & lib.exe /nologo "/extract:$($matches[0])" $env:THUNK_YY_KERNEL32_LIB *> extract.log
      if ($LASTEXITCODE -ne 0) { throw "YY alias extraction failed: $name .$ext" }
    } finally { Pop-Location }
    $file = Get-ChildItem -LiteralPath $dir -File | Where-Object { $_.Name -ne 'extract.log' } |
      Sort-Object Length -Descending | Select-Object -First 1
    if (-not $file) { throw "YY alias extraction produced no file: $name .$ext" }
    $dst = Join-Path $dir 'member.obj'
    Copy-Item -LiteralPath $file.FullName -Destination $dst -Force
    $memberSymbols = (& dumpbin.exe /nologo /symbols $dst 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0 -or $memberSymbols.IndexOf("YY_Thunks_$name",[StringComparison]::Ordinal) -lt 0) {
      throw "Incorrect YY weak alias member: $name .$ext"
    }
    $objects.Add($dst)
    $inventory.Add("$name|$ext|$($matches[0])")
  }
}
$provider = Join-Path $work 'g1a-threadpool-yy-aliases.lib'
$objectPaths = $objects.ToArray()
& lib.exe /nologo "/out:$provider" @objectPaths
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $provider)) {
  throw 'Cannot build G1a-only narrow Threadpool alias library'
}
$providerSymbols = (& dumpbin.exe /nologo /linkermember:1 $provider 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect Threadpool alias provider' }
foreach ($api in $apis) {
  if ($providerSymbols.IndexOf("YY_Thunks_$($api.Name)",[StringComparison]::Ordinal) -lt 0) {
    throw "Missing G1a Threadpool weak alias $($api.Name)"
  }
}
# Be explicit about the fallback closure: require exactly four Threadpool API
# alias pairs, never add the broad original YY kernel32.lib to target links.
$fullKernel32 = $env:THUNK_YY_KERNEL32_LIB.Replace('\','/')
$overlayLink = $provider.Replace('\','/')
$previousLink = $env:LDFLAGS
if ($previousLink.Replace('\','/').IndexOf($fullKernel32,[StringComparison]::OrdinalIgnoreCase) -ge 0) {
  throw 'Full YY kernel32.lib already reached LDFLAGS; refuse G1a overlay'
}
$flags = "$overlayLink $previousLink".Trim()
$inventory | Set-Content -Encoding utf8 (Join-Path $work 'selected-aliases.txt')
$providerSymbols | Set-Content -Encoding utf8 (Join-Path $work 'provider-symbols.txt')
@(
  "source_under_test=$env:GITHUB_SHA",
  'purpose=G1a test-enabled Threadpool Wait narrow YY alias overlay only',
  "version=$env:YY_THUNKS_VERSION",
  "target=$env:YY_THUNKS_TARGET",
  "existing_provider=$env:NARROW_YY_LIB",
  "test_only_provider=$provider",
  'api=CreateThreadpoolWait@12,SetThreadpoolWait@12,WaitForThreadpoolWaitCallbacks@8,CloseThreadpoolWait@4',
  'srw_closure=InitializeSRWLock@4,AcquireSRWLockExclusive@4,ReleaseSRWLockExclusive@4',
  "provider_sha256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $provider).Hash.ToLowerInvariant())",
  'main_production_scripts=unchanged',
  'full_yy_kernel32_lib=prohibited'
) | Set-Content -Encoding utf8 diagnostics\g1a-threadpool-yy-overlay.txt
"LDFLAGS=$flags" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
Write-Host 'G1a-only four Threadpool Wait aliases selected; existing SRW closure retained; strict browser import audit must independently validate xul.dll'
