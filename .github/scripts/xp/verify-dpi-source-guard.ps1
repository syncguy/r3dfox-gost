$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force diagnostics | Out-Null
$path = 'mozglue\misc\WindowsDpiInitialization.cpp'
if (-not (Test-Path $path)) {
  throw "DPI initialization source missing: $path"
}

$source = [System.IO.File]::ReadAllText($path)
$guardPattern = 'if\s*\(\s*!IsVistaOrLater\(\)\s*\)\s*\{\s*return\s+WindowsDpiInitializationResult::Success;\s*\}'
$guard = [regex]::Match(
  $source,
  $guardPattern,
  [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $guard.Success) {
  throw 'XP DPI contract missing pre-Vista success/no-op guard.'
}

$directCall = $source.IndexOf(
  'if (!SetProcessDPIAware())',
  [System.StringComparison]::Ordinal
)
if ($directCall -lt 0) {
  throw 'Expected SetProcessDPIAware fallback call was not found.'
}
if ($guard.Index -gt $directCall) {
  throw 'XP DPI pre-Vista guard occurs after SetProcessDPIAware fallback.'
}

@(
  "source=$path",
  "guard_index=$($guard.Index)",
  "setprocessdpiaware_call_index=$directCall",
  'result=PASS'
) | Set-Content -Encoding utf8 diagnostics\xp-dpi-source-guard.txt
