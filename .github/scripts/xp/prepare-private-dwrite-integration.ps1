$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $env:GITHUB_WORKSPACE 'toolkit\xre\nsAppRunner.cpp'
if (-not (Test-Path -LiteralPath $sourcePath)) {
  throw "nsAppRunner.cpp missing: $sourcePath"
}

$text = [System.IO.File]::ReadAllText($sourcePath)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }

$loaderPattern = '(?m)^  LOGREGISTRY\(L"loading dwrite\.dll"\);\r?\n  HMODULE dwdll = LoadLibrarySystem32\(L"dwrite\.dll"\);\r?\n  if \(dwdll\) \{$'
$loaderRegex = [regex]::new($loaderPattern)
$loaderMatches = $loaderRegex.Matches($text)
if ($loaderMatches.Count -ne 1) {
  throw "Expected exactly one XRE DirectWrite startup loader anchor; found $($loaderMatches.Count)."
}
$loaderReplacement = @(
  '  LOGREGISTRY(L"loading dwrite.dll");',
  '#  ifdef MOZ_XP_COMPAT',
  '  HMODULE dwdll = LoadLibraryXPPrivateDWrite();',
  '#  else',
  '  HMODULE dwdll = LoadLibrarySystem32(L"dwrite.dll");',
  '#  endif',
  '  if (dwdll) {'
) -join $newline
$text = $loaderRegex.Replace($text, $loaderReplacement, 1)

$readAheadPattern = '(?m)^    // Prefetch the system DLLs\r?\n    ReadAheadSystemDll\(L"DWrite\.dll"\);\r?\n    ReadAheadSystemDll\(L"D3DCompiler_47\.dll"\);$'
$readAheadRegex = [regex]::new($readAheadPattern)
$readAheadMatches = $readAheadRegex.Matches($text)
if ($readAheadMatches.Count -ne 1) {
  throw "Expected exactly one optimized DWrite read-ahead anchor; found $($readAheadMatches.Count)."
}
$readAheadReplacement = @(
  '    // Prefetch the system DLLs',
  '#  ifdef MOZ_XP_COMPAT',
  '    ReadAheadPackagedDll(L"xpcompat\\dwrite\\DWrite.dll", greDir);',
  '#  else',
  '    ReadAheadSystemDll(L"DWrite.dll");',
  '#  endif',
  '    ReadAheadSystemDll(L"D3DCompiler_47.dll");'
) -join $newline
$text = $readAheadRegex.Replace($text, $readAheadReplacement, 1)

$required = @(
  'HMODULE dwdll = LoadLibraryXPPrivateDWrite();',
  'ReadAheadPackagedDll(L"xpcompat\\dwrite\\DWrite.dll", greDir);'
)
foreach ($needle in $required) {
  if ($text.IndexOf($needle, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Private DirectWrite XRE patch verification failed: $needle"
  }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($sourcePath, $text, $utf8NoBom)

$diag = Join-Path $env:GITHUB_WORKSPACE 'diagnostics'
New-Item -ItemType Directory -Force $diag | Out-Null
@(
  'source=toolkit/xre/nsAppRunner.cpp',
  'startup_loader=MOZ_XP_COMPAT -> LoadLibraryXPPrivateDWrite; non-XP -> LoadLibrarySystem32',
  'optimized_readahead=MOZ_XP_COMPAT -> xpcompat/dwrite/DWrite.dll; non-XP -> System32 DWrite.dll',
  'xp_system32_dwrite_loader=excluded_by_preprocessor',
  'result=PASS'
) | Set-Content -Encoding utf8 (Join-Path $diag 'dwrite-xre-source-patch.txt')

& (Join-Path $PSScriptRoot 'dwrite-private-closure.ps1') -Mode Prepare
if ($LASTEXITCODE -ne 0) {
  throw "Private DirectWrite closure Prepare failed with exit $LASTEXITCODE"
}
