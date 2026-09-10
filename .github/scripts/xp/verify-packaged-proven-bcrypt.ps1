$ErrorActionPreference = 'Stop'

if (-not $env:XP_PORTABLE_ARCHIVE -or -not (Test-Path $env:XP_PORTABLE_ARCHIVE)) {
  throw 'Portable archive is unavailable for bcrypt gate'
}
if (-not $env:XP_BCRYPT_STAGED_SHA256) {
  throw 'Staged bcrypt hash was not recorded before packaging'
}

$extract = Join-Path $env:RUNNER_TEMP ("xp-package-bcrypt-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $extract | Out-Null
& 7z.exe x $env:XP_PORTABLE_ARCHIVE "-o$extract" -y | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw 'Cannot extract portable archive for bcrypt gate'
}

$found = @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter 'bcrypt.dll')
if ($found.Count -ne 1) {
  throw "Portable package must contain exactly one bcrypt.dll; found $($found.Count)"
}

$item = Get-Item $found[0].FullName
$sha1 = (Get-FileHash -Algorithm SHA1 $found[0].FullName).Hash.ToLowerInvariant()
$sha256 = (Get-FileHash -Algorithm SHA256 $found[0].FullName).Hash.ToLowerInvariant()

if ([string]$item.Length -ne $env:BCRYPT_SIZE) {
  throw "Packaged bcrypt.dll size mismatch: $($item.Length)"
}
if ($sha1 -ne $env:BCRYPT_SHA1) {
  throw "Packaged bcrypt.dll SHA1 mismatch: $sha1"
}
if ($sha256 -ne $env:XP_BCRYPT_STAGED_SHA256 -or $sha256 -ne $env:BCRYPT_SHA256) {
  throw "Packaged bcrypt.dll SHA256 mismatch: expected=$env:BCRYPT_SHA256 staged=$env:XP_BCRYPT_STAGED_SHA256 actual=$sha256"
}

@(
  "archive=$env:XP_PORTABLE_ARCHIVE",
  "packaged_path=$($found[0].FullName)",
  "bcrypt.dll|size=$($item.Length)",
  "bcrypt.dll|sha1=$sha1",
  "bcrypt.dll|sha256=$sha256"
) | Add-Content -Encoding utf8 diagnostics\packaged-bcrypt-contract.txt
