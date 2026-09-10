$ErrorActionPreference = 'Stop'

if (-not $env:PROVEN_XP_BCRYPT -or -not (Test-Path $env:PROVEN_XP_BCRYPT)) {
  throw 'Proven XP bcrypt release asset is unavailable'
}

$bin = Join-Path $env:OBJDIR 'dist\bin'
$dst = Join-Path $bin 'bcrypt.dll'
Copy-Item -Force $env:PROVEN_XP_BCRYPT $dst

$item = Get-Item $dst
$sha1 = (Get-FileHash -Algorithm SHA1 $dst).Hash.ToLowerInvariant()
$sha256 = (Get-FileHash -Algorithm SHA256 $dst).Hash.ToLowerInvariant()

if ([string]$item.Length -ne $env:BCRYPT_SIZE) {
  throw "Staged bcrypt.dll size mismatch: $($item.Length)"
}
if ($sha1 -ne $env:BCRYPT_SHA1) {
  throw "Staged bcrypt.dll SHA1 mismatch: $sha1"
}
if ($sha256 -ne $env:BCRYPT_SHA256) {
  throw "Staged bcrypt.dll SHA256 mismatch: $sha256"
}

"XP_BCRYPT_STAGED_SHA256=$sha256" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
@(
  "bcrypt.dll|size=$($item.Length)",
  "bcrypt.dll|sha1=$sha1",
  "bcrypt.dll|sha256=$sha256",
  "source_tag=$env:BCRYPT_TAG",
  "source_asset_id=$env:BCRYPT_ASSET_ID"
) | Set-Content -Encoding utf8 diagnostics\packaged-bcrypt-contract.txt
