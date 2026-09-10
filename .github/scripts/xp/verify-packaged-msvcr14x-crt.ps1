$ErrorActionPreference = 'Stop'

if (-not $env:XP_UCRTBASE_STAGED_SHA256 -or -not $env:XP_MSVCP140_STAGED_SHA256) {
  throw 'Staged XP CRT hashes were not recorded before packaging'
}

$expected = @{
  'ucrtbase.dll' = $env:XP_UCRTBASE_STAGED_SHA256
  'msvcp140.dll' = $env:XP_MSVCP140_STAGED_SHA256
}

$dist = (Resolve-Path (Join-Path $env:OBJDIR 'dist')).Path
$archives = @(
  Get-ChildItem -LiteralPath $dist -File |
    Where-Object { $_.Extension -in @('.7z','.zip') -and $_.Name -ne 'r3dfox-gost-xp-x32-runtime.7z' } |
    Sort-Object LastWriteTimeUtc -Descending
)
if ($archives.Count -eq 0) {
  throw "No portable package archive found under $dist"
}

"XP_PORTABLE_ARCHIVE=$($archives[0].FullName)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
$verifiedArchive = $null

foreach ($archive in $archives) {
  $extract = Join-Path $env:RUNNER_TEMP ("xp-package-crt-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $extract | Out-Null
  & 7z.exe x $archive.FullName "-o$extract" -y | Out-Null
  if ($LASTEXITCODE -ne 0) {
    continue
  }

  $matches = @{}
  $candidateOk = $true
  foreach ($dll in @('ucrtbase.dll','msvcp140.dll')) {
    $found = @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter $dll)
    if ($found.Count -ne 1) {
      $candidateOk = $false
      break
    }
    $hash = (Get-FileHash -Algorithm SHA256 $found[0].FullName).Hash.ToLowerInvariant()
    if ($hash -ne $expected[$dll]) {
      throw "$dll packaged hash mismatch in $($archive.Name): expected=$($expected[$dll]) actual=$hash"
    }
    $matches[$dll] = $hash
  }

  if (-not $candidateOk) {
    continue
  }

  $verifiedArchive = $archive
  @(
    "archive=$($archive.FullName)",
    "ucrtbase.dll|sha256=$($matches['ucrtbase.dll'])",
    "msvcp140.dll|sha256=$($matches['msvcp140.dll'])"
  ) | Add-Content -Encoding utf8 diagnostics\packaged-crt-contract.txt
  "XP_PORTABLE_ARCHIVE=$($verifiedArchive.FullName)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
  break
}

if (-not $verifiedArchive) {
  throw 'No produced portable package contains exactly one matching ucrtbase.dll and msvcp140.dll'
}
