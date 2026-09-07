$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

New-Item -ItemType Directory -Force diagnostics | Out-Null
$root = Join-Path $env:RUNNER_TEMP 'xp-bcrypt-release'
if (Test-Path $root) { Remove-Item -Recurse -Force $root }
New-Item -ItemType Directory -Force $root | Out-Null

$releaseUri = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/releases/tags/$env:BCRYPT_TAG"
$release = Invoke-RestMethod -Headers @{ 'User-Agent' = 'r3dfox-gost-ci' } -Uri $releaseUri
if ([string]$release.id -ne $env:BCRYPT_RELEASE_ID) { throw "Unexpected bcrypt release id: $($release.id)" }
if ($release.tag_name -ne $env:BCRYPT_TAG) { throw "Unexpected bcrypt release tag: $($release.tag_name)" }
if ($release.target_commitish -ne $env:BCRYPT_SOURCE_SHA) { throw "Unexpected bcrypt release source: $($release.target_commitish)" }
$assets = @($release.assets | Where-Object { $_.name -eq 'bcrypt.dll' })
if ($assets.Count -ne 1) { throw "Expected exactly one bcrypt.dll release asset; found $($assets.Count)" }
$asset = $assets[0]
if ([string]$asset.id -ne $env:BCRYPT_ASSET_ID) { throw "Unexpected bcrypt asset id: $($asset.id)" }
if ([string]$asset.size -ne $env:BCRYPT_SIZE) { throw "Unexpected bcrypt asset size metadata: $($asset.size)" }

$dll = Join-Path $root 'bcrypt.dll'
Invoke-WebRequest -Headers @{ 'User-Agent' = 'r3dfox-gost-ci' } -Uri $asset.browser_download_url -OutFile $dll
$item = Get-Item $dll
$sha1 = (Get-FileHash -Algorithm SHA1 $dll).Hash.ToLowerInvariant()
$sha256 = (Get-FileHash -Algorithm SHA256 $dll).Hash.ToLowerInvariant()
if ([string]$item.Length -ne $env:BCRYPT_SIZE) { throw "bcrypt.dll size mismatch: expected=$env:BCRYPT_SIZE actual=$($item.Length)" }
if ($sha1 -ne $env:BCRYPT_SHA1) { throw "bcrypt.dll SHA1 mismatch: expected=$env:BCRYPT_SHA1 actual=$sha1" }
if ($sha256 -ne $env:BCRYPT_SHA256) { throw "bcrypt.dll SHA256 mismatch: expected=$env:BCRYPT_SHA256 actual=$sha256" }

$headers = @(& dumpbin.exe /nologo /headers $dll 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /headers failed for proven bcrypt.dll' }
$imports = @(& dumpbin.exe /nologo /imports $dll 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /imports failed for proven bcrypt.dll' }
$exports = @(& dumpbin.exe /nologo /exports $dll 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /exports failed for proven bcrypt.dll' }
$headers | Set-Content -Encoding utf8 diagnostics\bcrypt-release-headers.txt
$imports | Set-Content -Encoding utf8 diagnostics\bcrypt-release-imports.txt
$exports | Set-Content -Encoding utf8 diagnostics\bcrypt-release-exports.txt
if (-not ($headers -match '(?im)^\s*14C machine \(x86\)')) { throw 'Proven bcrypt.dll is not x86 machine 14C' }
$importsText = $imports -join "`n"
foreach ($pattern in @('(?i)\bmbedtls\.dll\b','(?i)\bapi-ms-win-','(?i)\bext-ms-','(?i)\bKERNELBASE\.dll\b','(?i)\bBCRYPTPRIMITIVES\.dll\b')) {
  if ($importsText -match $pattern) { throw "Proven bcrypt.dll retains forbidden dependency pattern: $pattern" }
}
foreach ($name in @(
  'BCryptOpenAlgorithmProvider','BCryptCloseAlgorithmProvider','BCryptGetProperty',
  'BCryptCreateHash','BCryptHashData','BCryptFinishHash','BCryptDestroyHash','BCryptGenRandom'
)) {
  if (-not (($exports -join "`n") -match ('\b' + [regex]::Escape($name) + '\b'))) { throw "Required bcrypt export missing: $name" }
}

@(
  "tag=$($release.tag_name)",
  "release_id=$($release.id)",
  "source_sha=$($release.target_commitish)",
  "asset_id=$($asset.id)",
  "asset_size=$($asset.size)",
  "sha1=$sha1",
  "sha256=$sha256",
  "source_path=$dll"
) | Set-Content -Encoding utf8 diagnostics\bcrypt-release-provenance.txt
"PROVEN_XP_BCRYPT=$dll" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
