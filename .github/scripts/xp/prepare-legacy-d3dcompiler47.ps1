$ErrorActionPreference = 'Stop'

$expected = '3a010ee7186086a7f77b6aec3644e05f8495a84895b90572cab8d4f14efa088e'
$uri = 'https://archive.mozilla.org/pub/firefox/releases/52.2.1esr/win32/en-US/Firefox%20Setup%2052.2.1esr.exe'
$installer = Join-Path $env:RUNNER_TEMP 'firefox-legacy-d3dcompiler.exe'
$extract = Join-Path $env:RUNNER_TEMP 'firefox-legacy-d3dcompiler'

Invoke-WebRequest -Uri $uri -OutFile $installer
if (Test-Path $extract) {
  Remove-Item -Recurse -Force $extract
}
New-Item -ItemType Directory -Force $extract | Out-Null

& 7z.exe x $installer "-o$extract" -y | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "Cannot extract pinned legacy Firefox installer: $LASTEXITCODE"
}

$match = $null
foreach ($candidate in @(Get-ChildItem -Path $extract -Recurse -File -Filter 'd3dcompiler_47.dll')) {
  $hash = (Get-FileHash -Algorithm SHA256 $candidate.FullName).Hash.ToLowerInvariant()
  if ($hash -eq $expected) {
    $match = $candidate
    break
  }
}

if (-not $match) {
  throw "Pinned Firefox source does not contain expected D3DCompiler_47 SHA256 $expected"
}

"LEGACY_D3DCOMPILER47=$($match.FullName)" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
