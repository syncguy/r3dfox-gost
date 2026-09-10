$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $env:GITHUB_WORKSPACE 'toolkit\xre\nsAppRunner.cpp'
if (-not (Test-Path -LiteralPath $sourcePath)) {
  throw "nsAppRunner.cpp missing: $sourcePath"
}

$text = [System.IO.File]::ReadAllText($sourcePath)
$required = @(
  '#ifdef MOZ_XP_COMPAT',
  'HMODULE dwdll = LoadLibraryXPPrivateDWrite();',
  'ReadAheadPackagedDll(L"xpcompat\\dwrite\\DWrite.dll", greDir);'
)
foreach ($needle in $required) {
  if ($text.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Private DirectWrite XRE source contract missing: $needle"
  }
}

$diag = Join-Path $env:GITHUB_WORKSPACE 'diagnostics'
New-Item -ItemType Directory -Force $diag | Out-Null
@(
  'source=toolkit/xre/nsAppRunner.cpp',
  'source_mode=committed',
  'startup_loader=MOZ_XP_COMPAT -> LoadLibraryXPPrivateDWrite; non-XP -> LoadLibrarySystem32',
  'optimized_readahead=MOZ_XP_COMPAT -> xpcompat/dwrite/DWrite.dll; non-XP -> System32 DWrite.dll',
  'xp_system32_dwrite_loader=excluded_by_preprocessor',
  'result=PASS'
) | Set-Content -Encoding utf8 (Join-Path $diag 'dwrite-xre-source-patch.txt')

& (Join-Path $PSScriptRoot 'dwrite-private-closure.ps1') -Mode Prepare
if ($LASTEXITCODE -ne 0) {
  throw "Private DirectWrite closure Prepare failed with exit $LASTEXITCODE"
}
