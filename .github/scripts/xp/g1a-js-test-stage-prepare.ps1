# G1a-only fail-closed check of Firefox's canonical JS shell/test backend.
# Do not synthesize JS Makefiles or bypass stage-jstests. This script is
# invoked only by the dedicated --enable-tests browser-chrome workflow.
$ErrorActionPreference = 'Stop'
if (-not $env:OBJDIR) { throw 'G1a requires OBJDIR' }
$objectRoot = (Resolve-Path -LiteralPath $env:OBJDIR -ErrorAction Stop).Path
$generated = Join-Path $objectRoot 'js/src/tests/Makefile'
$jsapiTests = Join-Path $objectRoot 'dist/bin/jsapi-tests.exe'
$jsShell = Join-Path $objectRoot 'dist/bin/js.exe'
$src = Join-Path (Get-Location) 'js/src/tests/Makefile.in'
if (-not (Test-Path -LiteralPath $src)) {
  throw 'Firefox source JS tests template is missing'
}
if (-not (Test-Path -LiteralPath $generated)) {
  throw 'G1a canonical JS tests objdir Makefile missing: configure must include --enable-js-shell and recursive backend generation'
}
$generatedContent = Get-Content -LiteralPath $generated -Raw
if (-not $generatedContent.Contains('stage-package:') -or
    -not $generatedContent.Contains('--make-manifests')) {
  throw 'Generated JS tests Makefile lacks the canonical staging recipe'
}
if (-not (Test-Path -LiteralPath $jsapiTests)) {
  throw 'G1a JS API tests executable missing: enable JS shell and build its test targets; do not fake test-stage acceptance'
}
if (-not (Test-Path -LiteralPath $jsShell)) {
  throw 'G1a JS shell executable missing: verify --enable-js-shell was effective'
}
New-Item -ItemType Directory -Force 'diagnostics' | Out-Null
@(
  "source_under_test=$env:GITHUB_SHA",
  'result=canonical-generated-JS-test-Makefile-and-jsapi-tests-present',
  'build_scope=G1a-only',
  'manual_makefile_repair=disabled',
  'js_shell=required',
  'stage_jstests=required',
  "source_template_sha256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $src).Hash.ToLowerInvariant())",
  "generated_makefile_sha256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $generated).Hash.ToLowerInvariant())",
  "jsapi_tests_sha256=$((Get-FileHash -Algorithm SHA256 -LiteralPath $jsapiTests).Hash.ToLowerInvariant())"
) | Set-Content -Encoding utf8 'diagnostics/g1a-js-stage-makefile-repair.txt'
Write-Host 'G1a canonical JS shell + jsapi-tests + generated Makefile verified; original stage-jstests remains enabled'
exit 0
