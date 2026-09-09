param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Prepare', 'Stage', 'Verify', 'VerifyPackage')]
  [string]$Mode
)

$ErrorActionPreference = 'Stop'

$SupermiumTag = 'v132-r5-02'
$SupermiumAsset = 'supermium_132_32_nonsetup.zip'
$SupermiumAssetSHA256 = '3e181d50818fc95769f123012ad4cc0ffefe882f2fa4606620d2c031638a5912'
$DWriteSHA1 = '4e466d98bebea7b31764cfb15603b91a5f53fe72'
$DWriteSHA256 = '945f83efcec25ea71334a2d6117666aa625641cc2a92def474ef96cffa969e77'
$DWriteSize = 2667048
$FocusedRun = '34321430843'
$FocusedJob = '102368728335'
$FocusedSource = '8c30be63ea03a289ca24de4e2dc3e3859f34473e'

$Expected = [ordered]@{
  'DWrite.dll' = '945f83efcec25ea71334a2d6117666aa625641cc2a92def474ef96cffa969e77'
  'p_advp32.dll' = '9c493060173a6637b0f903171eaac63c749f0336a0789934cfeeebda381af289'
  'p_ole.dll' = '2fde6c35e1ed76b4bfe2707c3382c81aa60f84f6695c9431c2ae37522171f4cb'
  'pwp_shd.dll' = '5a01c4cdc18d646621dbf7407e607114d5aafee53a8f32f4b9e1e4d80cfe464f'
  'pwrp_k32.dll' = '5e2b41d24f59291fdadce1f57a843e809ecbb444b2f15c0c71f19fe67ebe47cd'
  'api-ms-win-crt-heap-l1-1-0.dll' = 'b5d69a1c45ea9e480ad518e2735224983f3885e3ec2a064619be4b02055ea9af'
  'api-ms-win-crt-math-l1-1-0.dll' = '7b4586e58ed1e6a247777093abb00b9815a10b371baf3c81ec1082784a9fd352'
  'api-ms-win-crt-runtime-l1-1-0.dll' = '6cbd9ec2330c8c4f92d3251c850f0a6e6d68cbd647eb8c1c17ca3bedae81e9c5'
  'api-ms-win-crt-stdio-l1-1-0.dll' = '423e9315811aaa783f2ac380232a27692ffb31202450f1fb4693a071aeb129ca'
  'api-ms-win-crt-string-l1-1-0.dll' = '08264ab7c5e3e5c08895a90d208cedf216db2cc36b58776662705a338dd62f62'
}

$Diagnostics = Join-Path $env:GITHUB_WORKSPACE 'diagnostics'
New-Item -ItemType Directory -Force $Diagnostics | Out-Null

function Write-Env([string]$Name, [string]$Value) {
  "$Name=$Value" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
}

function Get-PrivatePath {
  $bin = Join-Path $env:OBJDIR 'dist\bin'
  return Join-Path $bin 'xpcompat\dwrite'
}

function Normalize-ModuleName([string]$Name) {
  $value = $Name.Trim()
  if ($value -notmatch '(?i)\.(dll|drv)$') { $value += '.dll' }
  return $value
}

function Get-DependencyEdges([string]$Path) {
  $edges = [System.Collections.Generic.List[object]]::new()
  $imports = @(& dumpbin.exe /nologo /imports $Path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /imports failed: $Path" }
  $mode = 'none'
  foreach ($line in $imports) {
    if ($line -match '^\s*Section contains the following imports:\s*$') { $mode = 'direct'; continue }
    if ($line -match '^\s*Section contains the following delay load imports:\s*$') { $mode = 'delay'; continue }
    if ($mode -ne 'none' -and $line -match '^\s{4}([A-Za-z0-9_.-]+\.(?:dll|drv))\s*$') {
      $edges.Add([pscustomobject]@{ Kind = $mode; Module = (Normalize-ModuleName $matches[1]); Detail = '' })
    }
  }

  $exports = @(& dumpbin.exe /nologo /exports $Path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /exports failed: $Path" }
  foreach ($line in $exports) {
    if ($line -match '(?i)\(forwarded to\s+([A-Za-z0-9_.-]+)\.([A-Za-z0-9_@?$#-]+)\)') {
      $edges.Add([pscustomobject]@{ Kind = 'forwarder'; Module = (Normalize-ModuleName $matches[1]); Detail = $matches[2] })
    } elseif ($line -match '=\s*([A-Za-z0-9_.-]+)\.([A-Za-z0-9_@?$#-]+)\s*$') {
      $edges.Add([pscustomobject]@{ Kind = 'forwarder'; Module = (Normalize-ModuleName $matches[1]); Detail = $matches[2] })
    }
  }
  return $edges
}

function Assert-ExpectedSource([string]$Root) {
  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($name in $Expected.Keys) {
    $path = Join-Path $Root $name
    if (-not (Test-Path -LiteralPath $path)) { throw "Pinned Supermium private member missing: $name" }
    $hash = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
    if ($hash -ne $Expected[$name]) { throw "$name SHA256 mismatch: expected=$($Expected[$name]) actual=$hash" }
    $rows.Add([pscustomobject]@{ Name = $name; SHA256 = $hash; Size = (Get-Item $path).Length })
  }
  if (@(Get-ChildItem -LiteralPath $Root -File -Filter '*.dll' | Where-Object { $Expected.Contains($_.Name) }).Count -lt 10) {
    throw 'Expected Supermium source directory does not expose all 10 pinned private members.'
  }
  return $rows
}

if ($Mode -eq 'Prepare') {
  $uri = "https://github.com/win32ss/supermium/releases/download/$SupermiumTag/$SupermiumAsset"
  $archive = Join-Path $env:RUNNER_TEMP $SupermiumAsset
  $extract = Join-Path $env:RUNNER_TEMP 'r3dfox-supermium-dwrite'
  if (Test-Path $extract) { Remove-Item -Recurse -Force $extract }
  Invoke-WebRequest -Uri $uri -OutFile $archive
  $archiveHash = (Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant()
  if ($archiveHash -ne $SupermiumAssetSHA256) {
    throw "Pinned Supermium asset SHA256 mismatch: expected=$SupermiumAssetSHA256 actual=$archiveHash"
  }
  Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force

  $matchesFound = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
  foreach ($candidate in @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter 'DWrite.dll')) {
    if ((Get-FileHash -Algorithm SHA256 $candidate.FullName).Hash.ToLowerInvariant() -eq $DWriteSHA256) {
      $matchesFound.Add($candidate)
    }
  }
  if ($matchesFound.Count -ne 1) { throw "Expected exactly one exact DWrite.dll; found $($matchesFound.Count)." }
  $dwrite = $matchesFound[0]
  $sha1 = (Get-FileHash -Algorithm SHA1 $dwrite.FullName).Hash.ToLowerInvariant()
  $sha256 = (Get-FileHash -Algorithm SHA256 $dwrite.FullName).Hash.ToLowerInvariant()
  if ($dwrite.Length -ne $DWriteSize -or $sha1 -ne $DWriteSHA1 -or $sha256 -ne $DWriteSHA256) {
    throw 'Exact DWrite.dll identity contract failed.'
  }

  $sourceRows = @(Assert-ExpectedSource $dwrite.Directory.FullName)
  $sourceRows | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-source-manifest.csv')
  Write-Env 'DWRITE_PRIVATE_SOURCE_ROOT' $dwrite.Directory.FullName
  Write-Env 'DWRITE_FOCUSED_RUN' $FocusedRun
  Write-Env 'DWRITE_FOCUSED_JOB' $FocusedJob
  Write-Env 'DWRITE_FOCUSED_SOURCE' $FocusedSource

  $manifestPath = Join-Path $env:GITHUB_WORKSPACE 'browser\installer\package-manifest.in'
  $text = [System.IO.File]::ReadAllText($manifestPath)
  $entry = '@BINPATH@/xpcompat/dwrite/*'
  if (-not $text.Contains($entry)) {
    $anchor = '@BINPATH@/bcrypt.dll'
    $first = $text.IndexOf($anchor, [System.StringComparison]::Ordinal)
    $last = $text.LastIndexOf($anchor, [System.StringComparison]::Ordinal)
    if ($first -lt 0 -or $first -ne $last) { throw 'Expected unique bcrypt package-manifest anchor was not found.' }
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $text = $text.Insert($first + $anchor.Length, $newline + $entry)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($manifestPath, $text, $utf8NoBom)
  }
  if (-not ([System.IO.File]::ReadAllText($manifestPath)).Contains($entry)) {
    throw 'XP private DWrite package-manifest entry was not installed.'
  }

  @(
    "focused_run=$FocusedRun",
    "focused_job=$FocusedJob",
    "focused_source=$FocusedSource",
    "supermium_tag=$SupermiumTag",
    "supermium_asset=$SupermiumAsset",
    "supermium_asset_sha256=$archiveHash",
    "dwrite_sha1=$sha1",
    "dwrite_sha256=$sha256",
    "dwrite_size=$($dwrite.Length)",
    'loader_model=absolute private DWrite path + LOAD_WITH_ALTERED_SEARCH_PATH; no explicit pwrp preload',
    'private_dll_count=10',
    'private_ucrtbase=false',
    'package_manifest=@BINPATH@/xpcompat/dwrite/*'
  ) | Set-Content -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-identity.txt')
  exit 0
}

if ($Mode -eq 'Stage') {
  if (-not $env:DWRITE_PRIVATE_SOURCE_ROOT -or -not (Test-Path -LiteralPath $env:DWRITE_PRIVATE_SOURCE_ROOT)) {
    throw 'Prepared Supermium DWrite source root is unavailable.'
  }
  $bin = Join-Path $env:OBJDIR 'dist\bin'
  if (-not (Test-Path -LiteralPath $bin)) { throw "Firefox dist/bin missing: $bin" }
  $private = Get-PrivatePath
  if (Test-Path $private) { Remove-Item -Recurse -Force $private }
  New-Item -ItemType Directory -Force $private | Out-Null

  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($name in $Expected.Keys) {
    $src = Join-Path $env:DWRITE_PRIVATE_SOURCE_ROOT $name
    $sourceHash = (Get-FileHash -Algorithm SHA256 $src).Hash.ToLowerInvariant()
    if ($sourceHash -ne $Expected[$name]) { throw "$name source SHA256 changed before staging." }
    $dst = Join-Path $private $name
    Copy-Item -LiteralPath $src -Destination $dst
    $stagedHash = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()
    if ($stagedHash -ne $sourceHash) { throw "$name staging changed source bytes before PE retarget." }
    $rows.Add([pscustomobject]@{
      RelativePath = "xpcompat/dwrite/$name"
      Provenance = "Supermium $SupermiumTag"
      SourceSHA256 = $sourceHash
      PreRetargetSHA256 = $stagedHash
      Size = (Get-Item $dst).Length
    })
  }

  if (@(Get-ChildItem -LiteralPath $private -File -Filter '*.dll').Count -ne 10) { throw 'Expected exactly 10 private DWrite DLLs.' }
  if (Test-Path (Join-Path $private 'ucrtbase.dll')) { throw 'ucrtbase.dll must remain shared at dist/bin.' }
  if (-not (Test-Path (Join-Path $bin 'ucrtbase.dll'))) { throw 'Shared msvcr14x ucrtbase.dll is missing from dist/bin.' }
  $rows | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-staged-preretarget.csv')
  Write-Env 'XP_DWRITE_PRIVATE_DIR' $private
  exit 0
}

if ($Mode -eq 'Verify') {
  $bin = Join-Path $env:OBJDIR 'dist\bin'
  $private = Get-PrivatePath
  if (-not (Test-Path $private)) { throw "Private DWrite directory missing: $private" }
  $files = @(Get-ChildItem -LiteralPath $private -File -Filter '*.dll' | Sort-Object Name)
  if ($files.Count -ne 10) { throw "Expected exactly 10 private DWrite DLLs; found $($files.Count)." }
  $actualNames = @($files.Name | Sort-Object)
  $expectedNames = @($Expected.Keys | Sort-Object)
  if (($actualNames -join '|') -cne ($expectedNames -join '|')) { throw 'Private DWrite filename set differs from the pinned 10-member contract.' }
  if (Test-Path (Join-Path $private 'ucrtbase.dll')) { throw 'Private DWrite directory must not contain ucrtbase.dll.' }

  $privateNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($file in $files) { [void]$privateNames.Add($file.Name) }
  $sharedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($file in @(Get-ChildItem -LiteralPath $bin -File -Filter '*.dll')) { [void]$sharedNames.Add($file.Name) }
  if (-not $sharedNames.Contains('ucrtbase.dll')) { throw 'Shared dist/bin ucrtbase.dll is missing.' }

  $xpSystemNames = @(
    'advapi32.dll','comctl32.dll','comdlg32.dll','crypt32.dll','d3d9.dll','dnsapi.dll','gdi32.dll','gdiplus.dll',
    'imagehlp.dll','imm32.dll','iphlpapi.dll','kernel32.dll','mpr.dll','msctf.dll','msimg32.dll','msvcrt.dll',
    'netapi32.dll','ntdll.dll','ole32.dll','oleaut32.dll','powrprof.dll','psapi.dll','rpcrt4.dll','secur32.dll',
    'sensapi.dll','setupapi.dll','shell32.dll','shlwapi.dll','user32.dll','userenv.dll','usp10.dll','uxtheme.dll',
    'version.dll','wininet.dll','winmm.dll','wintrust.dll','wldap32.dll','ws2_32.dll','winspool.drv'
  )
  $xpSystem = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($name in $xpSystemNames) { [void]$xpSystem.Add($name) }

  $manifest = [System.Collections.Generic.List[object]]::new()
  $edgeRows = [System.Collections.Generic.List[object]]::new()
  $unresolved = [System.Collections.Generic.List[string]]::new()
  foreach ($file in $files) {
    $headers = @(& dumpbin.exe /nologo /headers $file.FullName 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed: $($file.FullName)" }
    $machine = $headers | Where-Object { $_ -match '(?i)^\s*[0-9A-F]+ machine ' } | Select-Object -First 1
    if (-not $machine -or $machine -notmatch '(?i)^\s*14C machine \(x86\)') { throw "$($file.Name) is not x86 machine 14C" }
    $versionLine = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
    if (-not $versionLine -or $versionLine -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') { throw "Cannot parse subsystem: $($file.Name)" }
    $version = [version]("$([int]$matches[1]).$([int]$matches[2])")
    if ($version -gt [version]'5.1') { throw "$($file.Name) subsystem $version is newer than XP 5.01" }

    if ($file.Name -ieq 'DWrite.dll') {
      $exports = @(& dumpbin.exe /nologo /exports $file.FullName 2>&1)
      if ($LASTEXITCODE -ne 0 -or ($exports -join "`n") -notmatch '(?m)\bDWriteCreateFactory\b') {
        throw 'Staged DWrite.dll does not export DWriteCreateFactory.'
      }
    }

    foreach ($edge in @(Get-DependencyEdges $file.FullName)) {
      if ($privateNames.Contains($edge.Module)) { $classification = 'private-xpcompat-dwrite' }
      elseif ($sharedNames.Contains($edge.Module)) { $classification = 'shared-dist-bin' }
      elseif ($xpSystem.Contains($edge.Module)) { $classification = 'xp-system' }
      else { $classification = 'external-unresolved' }
      $edgeRows.Add([pscustomobject]@{
        From = $file.Name
        Kind = $edge.Kind
        To = $edge.Module
        Detail = $edge.Detail
        Classification = $classification
      })
      if ($classification -eq 'external-unresolved') { $unresolved.Add("$($file.Name)|$($edge.Kind)|$($edge.Module)|$($edge.Detail)") }
    }

    $manifest.Add([pscustomobject]@{
      RelativePath = "xpcompat/dwrite/$($file.Name)"
      SHA256 = (Get-FileHash -Algorithm SHA256 $file.FullName).Hash.ToLowerInvariant()
      Size = $file.Length
      Machine = '14C-x86'
      Subsystem = $version.ToString(2)
    })
  }

  $manifest | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-retargeted-manifest.csv')
  $edgeRows | Sort-Object From,Kind,To,Detail -Unique | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-closure-edges.csv')
  $unresolved | Sort-Object -Unique | Set-Content -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-unresolved.txt')
  if ($unresolved.Count -gt 0) { throw 'Private DWrite closure retains unresolved dependency/forwarder edges.' }

  @(
    "focused_run=$FocusedRun",
    "focused_job=$FocusedJob",
    "focused_source=$FocusedSource",
    'private_dll_count=10',
    'private_ucrtbase_present=false',
    'shared_ucrtbase_present=true',
    'loader_model=automatic same-directory dependency resolution through LOAD_WITH_ALTERED_SEARCH_PATH',
    'result=PASS'
  ) | Set-Content -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-closure-result.txt')
  exit 0
}

if ($Mode -eq 'VerifyPackage') {
  if (-not $env:XP_PORTABLE_ARCHIVE -or -not (Test-Path -LiteralPath $env:XP_PORTABLE_ARCHIVE)) {
    throw 'Portable archive is unavailable for private DWrite packaging gate.'
  }
  $stagedManifestPath = Join-Path $Diagnostics 'dwrite-private-retargeted-manifest.csv'
  if (-not (Test-Path $stagedManifestPath)) { throw 'Retargeted private DWrite manifest is unavailable.' }
  $staged = @(Import-Csv -LiteralPath $stagedManifestPath)
  if ($staged.Count -ne 10) { throw 'Retargeted private DWrite manifest must contain 10 rows.' }

  $extract = Join-Path $env:RUNNER_TEMP ("xp-package-dwrite-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $extract | Out-Null
  & 7z.exe x $env:XP_PORTABLE_ARCHIVE "-o$extract" -y | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Cannot extract portable archive for private DWrite gate.' }

  $dirs = @(Get-ChildItem -LiteralPath $extract -Recurse -Directory -Filter 'dwrite' | Where-Object { $_.Parent -and $_.Parent.Name -ieq 'xpcompat' })
  if ($dirs.Count -ne 1) { throw "Portable package must contain exactly one xpcompat/dwrite directory; found $($dirs.Count)." }
  $private = $dirs[0].FullName
  $files = @(Get-ChildItem -LiteralPath $private -File -Filter '*.dll' | Sort-Object Name)
  if ($files.Count -ne 10) { throw "Portable xpcompat/dwrite must contain exactly 10 DLLs; found $($files.Count)." }
  if (Test-Path (Join-Path $private 'ucrtbase.dll')) { throw 'Portable private DWrite directory contains forbidden private ucrtbase.dll.' }

  $rows = [System.Collections.Generic.List[object]]::new()
  foreach ($row in $staged) {
    $name = [System.IO.Path]::GetFileName($row.RelativePath)
    $path = Join-Path $private $name
    if (-not (Test-Path -LiteralPath $path)) { throw "Portable private DWrite member missing: $name" }
    $hash = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
    if ($hash -ne $row.SHA256) { throw "$name packaged hash mismatch: expected=$($row.SHA256) actual=$hash" }
    $rows.Add([pscustomobject]@{ Name = $name; SHA256 = $hash; Size = (Get-Item $path).Length })
  }
  $rows | Export-Csv -NoTypeInformation -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-packaged-manifest.csv')
  @(
    "archive=$env:XP_PORTABLE_ARCHIVE",
    "private_path=$private",
    'private_dll_count=10',
    'private_ucrtbase_present=false',
    'hash_identity=10/10 post-retarget bytes',
    'result=PASS'
  ) | Set-Content -Encoding utf8 (Join-Path $Diagnostics 'dwrite-private-package-result.txt')
}
