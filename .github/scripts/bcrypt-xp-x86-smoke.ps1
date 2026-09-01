$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

New-Item -ItemType Directory -Force diagnostics, onecore, build, runtime, smoke-src | Out-Null
@(
  "repo=$env:GITHUB_REPOSITORY"
  "source_commit=$env:GITHUB_SHA"
  "track=Windows XP x86 compatibility only"
  "upstream_repo=$env:ONECORE_REPO"
  "upstream_commit=$env:ONECORE_COMMIT"
  "upstream_base_path=$env:ONECORE_BASE_PATH"
  "bcrypt_expected_blob_sha1=$env:BCRYPT_BLOB_SHA1"
  "bcrypt_expected_size=$env:BCRYPT_SIZE"
  "probe_pe_floor=$env:WINDOWS_XP_SUBSYSTEM"
  "physical_xp_verified=false"
) | Set-Content -Encoding utf8 diagnostics\identity.txt

cmd /c "where cl > diagnostics\cl-version.txt 2>&1 & cl >> diagnostics\cl-version.txt 2>&1 & exit /b 0"
cmd /c "where link > diagnostics\link-version.txt 2>&1 & link >> diagnostics\link-version.txt 2>&1 & exit /b 0"
cmd /c "where dumpbin > diagnostics\dumpbin-version.txt 2>&1 & dumpbin /? >> diagnostics\dumpbin-version.txt 2>&1 & exit /b 0"

$repoRaw = "https://raw.githubusercontent.com/$env:GITHUB_REPOSITORY/$env:GITHUB_SHA"
foreach ($rel in @(
  'tools/gost/xp/bcrypt-smoke/bcrypt_dynamic.cpp',
  'tools/gost/xp/bcrypt-smoke/bcrypt_linked.cpp',
  'tools/gost/xp/bcrypt-smoke/run-on-xp.cmd',
  'tools/gost/xp/bcrypt-smoke/README-XP.md'
)) {
  $leaf = Split-Path -Leaf $rel
  Invoke-WebRequest -Uri "$repoRaw/$rel" -OutFile (Join-Path smoke-src $leaf)
}

$headers = @{ 'User-Agent' = 'r3dfox-gost-bcrypt-xp-smoke' }
$treeApi = "https://api.github.com/repos/$env:ONECORE_REPO/git/trees/$env:ONECORE_COMMIT`?recursive=1"
$treeResponse = Invoke-RestMethod -Headers $headers -Uri $treeApi
if (-not $treeResponse.tree) { throw 'Pinned upstream Git tree is empty' }
$prefix = "$env:ONECORE_BASE_PATH/"
$byName = @{}
foreach ($entry in $treeResponse.tree) {
  if ($entry.type -ne 'blob' -or -not $entry.path.StartsWith($prefix, [System.StringComparison]::Ordinal)) { continue }
  $relative = $entry.path.Substring($prefix.Length)
  if ($relative.Contains('/')) { continue }
  $name = $relative
  $download = "https://raw.githubusercontent.com/$env:ONECORE_REPO/$env:ONECORE_COMMIT/$($entry.path)"
  $byName[$name.ToLowerInvariant()] = [pscustomobject]@{
    name = $name
    path = $entry.path
    sha = $entry.sha
    size = [int64]$entry.size
    download_url = $download
  }
}
if (-not $byName.ContainsKey('bcrypt.dll')) { throw 'Pinned upstream directory does not contain bcrypt.dll' }
$bcryptMeta = $byName['bcrypt.dll']
if ($bcryptMeta.sha -ne $env:BCRYPT_BLOB_SHA1) { throw "bcrypt Git blob changed: $($bcryptMeta.sha)" }
if ([int64]$bcryptMeta.size -ne [int64]$env:BCRYPT_SIZE) { throw "bcrypt size changed: $($bcryptMeta.size)" }

$xpSystem = @(
  'advapi32.dll','comdlg32.dll','crypt32.dll','gdi32.dll','imm32.dll','kernel32.dll','lz32.dll',
  'msvcrt.dll','netapi32.dll','ntdll.dll','ole32.dll','oleaut32.dll','psapi.dll','rpcrt4.dll',
  'secur32.dll','setupapi.dll','shell32.dll','shlwapi.dll','user32.dll','userenv.dll','version.dll',
  'wininet.dll','winmm.dll','winspool.drv','ws2_32.dll','wsock32.dll'
)
$xpSystemSet = @{}; foreach($n in $xpSystem){ $xpSystemSet[$n] = $true }
$obviousPostXpModules = '^(api-ms-win-|ext-ms-win-|kernelbase\.dll$)'
$obviousPostXpApis = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','ReleaseSRWLockExclusive','ReleaseSRWLockShared',
  'TryAcquireSRWLockExclusive','TryAcquireSRWLockShared','InitializeSRWLock','InitializeConditionVariable',
  'SleepConditionVariableCS','SleepConditionVariableSRW','WakeAllConditionVariable','WakeConditionVariable',
  'InitializeCriticalSectionEx','GetSystemTimePreciseAsFileTime','GetTickCount64','SetDefaultDllDirectories',
  'AddDllDirectory','RemoveDllDirectory','CancelIoEx','GetFileInformationByHandleEx','SetFileInformationByHandle',
  'GetFinalPathNameByHandleW','CreateSymbolicLinkW','FlsAlloc','FlsFree','FlsGetValue','FlsSetValue',
  'IsThreadAFiber','SetThreadStackGuarantee'
)

$queue = [System.Collections.Generic.Queue[string]]::new()
$queue.Enqueue('bcrypt.dll')
$seen = @{}
$closure = [System.Collections.Generic.List[string]]::new()
$summary = [System.Collections.Generic.List[string]]::new()
$hashes = [System.Collections.Generic.List[string]]::new()
$violations = [System.Collections.Generic.List[string]]::new()
while ($queue.Count -gt 0) {
  $name = $queue.Dequeue().ToLowerInvariant()
  if ($seen.ContainsKey($name)) { continue }
  $seen[$name] = $true
  if (-not $byName.ContainsKey($name)) { throw "Required local dependency is absent from pinned upstream directory: $name" }
  $meta = $byName[$name]
  $dst = Join-Path $env:GITHUB_WORKSPACE ("onecore\" + $meta.name)
  Invoke-WebRequest -Headers $headers -Uri $meta.download_url -OutFile $dst
  $size = (Get-Item -LiteralPath $dst).Length
  if ($size -ne [int64]$meta.size) { throw "Size mismatch for $($name): $size vs $($meta.size)" }
  $blob = (& git hash-object --no-filters -- $dst).Trim()
  if ($LASTEXITCODE -ne 0 -or $blob -ne $meta.sha) { throw "Git blob mismatch for $($name): $blob vs $($meta.sha)" }
  $sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $dst).Hash.ToLowerInvariant()
  $hashes.Add("$($meta.name)|size=$size|git_blob=$blob|sha256=$sha256|upstream_commit=$env:ONECORE_COMMIT|path=$($meta.path)")
  $closure.Add($meta.name)

  $headersOut = (& dumpbin.exe /nologo /headers $dst 2>&1 | Out-String -Width 4096)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed for $name" }
  $importsOut = (& dumpbin.exe /nologo /imports $dst 2>&1 | Out-String -Width 4096)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /imports failed for $name" }
  $exportsOut = (& dumpbin.exe /nologo /exports $dst 2>&1 | Out-String -Width 4096)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /exports failed for $name" }
  $headersOut | Set-Content -Encoding utf8 ("diagnostics\$($meta.name).headers.txt")
  $importsOut | Set-Content -Encoding utf8 ("diagnostics\$($meta.name).imports.txt")
  $exportsOut | Set-Content -Encoding utf8 ("diagnostics\$($meta.name).exports.txt")
  if ($headersOut -notmatch '(?im)^\s*14C machine \(x86\)') { $violations.Add("$($meta.name): machine is not x86") }
  $subsystem = if ($headersOut -match '(?im)^\s*([0-9]+\.[0-9]+) subsystem version') { $Matches[1] } else { 'unknown' }
  $summary.Add("$($meta.name)|machine=x86|subsystem_version=$subsystem")

  $modules = @([regex]::Matches($importsOut,'(?im)^\s*([A-Za-z0-9_.-]+\.(?:dll|drv))\s*$') | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique)
  foreach ($dep in $modules) {
    $summary.Add("$($meta.name) -> $dep")
    if ($dep -match $obviousPostXpModules) { $violations.Add("$($meta.name): obvious post-XP module import $dep"); continue }
    if ($xpSystemSet.ContainsKey($dep)) { continue }
    if ($byName.ContainsKey($dep)) { if(-not $seen.ContainsKey($dep)){ $queue.Enqueue($dep) }; continue }
    $violations.Add("$($meta.name): unresolved non-XP-system dependency $dep")
  }
  foreach ($apiName in $obviousPostXpApis) {
    if ($importsOut -match "(?im)^\s*[0-9A-F]+\s+$([regex]::Escape($apiName))\s*$") {
      $violations.Add("$($meta.name): obvious post-XP hard import $apiName")
    }
  }
}
$closure | Set-Content -Encoding utf8 diagnostics\dependency-closure-local-files.txt
$summary | Set-Content -Encoding utf8 diagnostics\dependency-closure.txt
$hashes | Set-Content -Encoding utf8 diagnostics\hashes-and-provenance.txt
if ($violations.Count -gt 0) {
  $violations | Set-Content -Encoding utf8 diagnostics\xp-obvious-import-violations.txt
  throw "One-Core dependency closure has $($violations.Count) obvious XP compatibility violation(s)"
}
'No obvious post-XP hard imports found in the pinned local closure.' | Set-Content -Encoding utf8 diagnostics\xp-obvious-import-violations.txt

$exports = Get-Content -Raw diagnostics\bcrypt.dll.exports.txt
$required = @(
  'BCryptOpenAlgorithmProvider','BCryptCloseAlgorithmProvider','BCryptGetProperty','BCryptCreateHash',
  'BCryptHashData','BCryptFinishHash','BCryptDestroyHash','BCryptGenRandom'
)
$rows = @()
foreach($name in $required){
  $present = $exports -match "(?im)\b$([regex]::Escape($name))\b"
  $rows += "$name=$present"
  if(-not $present){ throw "Missing required export: $name" }
}
$rows | Set-Content -Encoding utf8 diagnostics\required-exports.txt

cmd /c "cl.exe /nologo /c /O2 /Oi /GS- /GR- /Zl /Fo:build\bcrypt-dynamic.obj smoke-src\bcrypt_dynamic.cpp > diagnostics\build-dynamic.txt 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content diagnostics\build-dynamic.txt; throw 'dynamic probe compile failed' }
cmd /c "link.exe /nologo /NODEFAULTLIB /MACHINE:X86 /SUBSYSTEM:CONSOLE,$env:WINDOWS_XP_SUBSYSTEM /ENTRY:mainCRTStartup /OUT:build\bcrypt-dynamic.exe build\bcrypt-dynamic.obj kernel32.lib >> diagnostics\build-dynamic.txt 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content diagnostics\build-dynamic.txt; throw 'dynamic probe link failed' }
cmd /c "cl.exe /nologo /c /O2 /Oi /GS- /GR- /Zl /Fo:build\bcrypt-linked.obj smoke-src\bcrypt_linked.cpp > diagnostics\build-linked.txt 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content diagnostics\build-linked.txt; throw 'linked probe compile failed' }
cmd /c "link.exe /nologo /NODEFAULTLIB /MACHINE:X86 /SUBSYSTEM:CONSOLE,$env:WINDOWS_XP_SUBSYSTEM /ENTRY:mainCRTStartup /OUT:build\bcrypt-linked.exe build\bcrypt-linked.obj kernel32.lib bcrypt.lib >> diagnostics\build-linked.txt 2>&1"
if ($LASTEXITCODE -ne 0) { Get-Content diagnostics\build-linked.txt; throw 'linked probe link failed' }

foreach($name in @('bcrypt-dynamic.exe','bcrypt-linked.exe')){
  $path = Join-Path 'build' $name
  $h = (& dumpbin.exe /nologo /headers $path 2>&1 | Out-String -Width 4096)
  $i = (& dumpbin.exe /nologo /imports $path 2>&1 | Out-String -Width 4096)
  $h | Set-Content -Encoding utf8 ("diagnostics\$name.headers.txt")
  $i | Set-Content -Encoding utf8 ("diagnostics\$name.imports.txt")
  if($h -notmatch '(?im)^\s*14C machine \(x86\)'){ throw "$name is not x86" }
  if($h -notmatch '(?im)^\s*5\.01 subsystem version'){ throw "$name is not PE subsystem 5.01" }
}
$dynamicImports = Get-Content -Raw diagnostics\bcrypt-dynamic.exe.imports.txt
$linkedImports = Get-Content -Raw diagnostics\bcrypt-linked.exe.imports.txt
if($dynamicImports -match '(?im)^\s*bcrypt\.dll\s*$'){ throw 'Dynamic probe unexpectedly has a link-time bcrypt.dll dependency' }
if($linkedImports -notmatch '(?im)^\s*bcrypt\.dll\s*$'){ throw 'Linked probe does not have the required bcrypt.dll import' }
@('dynamic_probe_link_time_bcrypt=false','linked_probe_link_time_bcrypt=true') | Set-Content -Encoding utf8 diagnostics\probe-import-model.txt

Copy-Item build\bcrypt-dynamic.exe,build\bcrypt-linked.exe runtime\
Get-Content diagnostics\dependency-closure-local-files.txt | ForEach-Object {
  if($_.Trim()){ Copy-Item (Join-Path 'onecore' $_.Trim()) runtime\ }
}
Copy-Item smoke-src\run-on-xp.cmd,smoke-src\README-XP.md runtime\
Get-ChildItem runtime -File | Sort-Object Name | ForEach-Object {
  "$($_.Name)|size=$($_.Length)|sha256=$((Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant())"
} | Set-Content -Encoding utf8 diagnostics\runtime-bundle-hashes.txt

Push-Location runtime
try {
  & .\bcrypt-dynamic.exe 2>&1 | Tee-Object ..\diagnostics\hosted-dynamic.txt
  $dynamicRc = $LASTEXITCODE
} finally { Pop-Location }
"ExitCode=$dynamicRc" | Add-Content -Encoding utf8 diagnostics\hosted-dynamic.txt
if($dynamicRc -ne 0){ throw "dynamic probe failed with $dynamicRc" }
$dynamicOutput = Get-Content -Raw diagnostics\hosted-dynamic.txt
foreach($mark in @('LOAD PASS','EXPORTS PASS','RNG PASS','SHA256 PASS')){ if($dynamicOutput -notmatch [regex]::Escape($mark)){ throw "dynamic probe missing $mark" } }

Push-Location runtime
try {
  & .\bcrypt-linked.exe 2>&1 | Tee-Object ..\diagnostics\hosted-linked.txt
  $linkedRc = $LASTEXITCODE
} finally { Pop-Location }
"ExitCode=$linkedRc" | Add-Content -Encoding utf8 diagnostics\hosted-linked.txt
if($linkedRc -ne 0){ throw "linked probe failed with $linkedRc" }
$linkedOutput = Get-Content -Raw diagnostics\hosted-linked.txt
foreach($mark in @('LOAD PASS','EXPORTS PASS','RNG PASS','SHA256 PASS')){ if($linkedOutput -notmatch [regex]::Escape($mark)){ throw "linked probe missing $mark" } }
@(
  'Hosted Windows execution is a smoke only, not Windows XP evidence.'
  'MODULE PATH output records what the Windows 2022 loader actually selected; modern KnownDLL behavior may select the OS bcrypt.dll.'
  'Physical Windows XP SP3 x86 validation must use the runtime artifact.'
) | Set-Content -Encoding utf8 diagnostics\hosted-runtime-caveat.txt

Write-Host 'bcrypt XP x86 focused smoke PASS'
