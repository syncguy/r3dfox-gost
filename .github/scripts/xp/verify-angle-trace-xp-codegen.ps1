$ErrorActionPreference = 'Stop'

if (-not $env:OBJDIR) {
  throw 'OBJDIR is required'
}

New-Item -ItemType Directory -Force diagnostics | Out-Null

$traceHeader = 'gfx\angle\checkout\src\third_party\trace_event\trace_event.h'
$displaySource = 'gfx\angle\checkout\src\libANGLE\Display.cpp'
foreach ($path in @($traceHeader, $displaySource)) {
  if (-not (Test-Path $path)) {
    throw "Required ANGLE source file missing: $path"
  }
}

$traceText = [System.IO.File]::ReadAllText($traceHeader).Replace("`r`n", "`n")
$expectedTraceBlock = @'
#ifdef MOZ_XP_COMPAT
#  define INTERNAL_TRACE_EVENT_GET_CATEGORY_INFO(platform, category) \
    const unsigned char *INTERNALTRACEEVENTUID(catstatic) =          \
        TRACE_EVENT_API_GET_CATEGORY_ENABLED(platform, category);
#else
#  define INTERNAL_TRACE_EVENT_GET_CATEGORY_INFO(platform, category) \
    static const unsigned char *INTERNALTRACEEVENTUID(catstatic) =   \
        TRACE_EVENT_API_GET_CATEGORY_ENABLED(platform, category);
#endif
'@
if (-not $traceText.Contains($expectedTraceBlock.Replace("`r`n", "`n"))) {
  throw 'Expected MOZ_XP_COMPAT trace category branch is not present exactly as required'
}

$displayText = [System.IO.File]::ReadAllText($displaySource)
if (-not $displayText.Contains('ANGLE_TRACE_EVENT0("gpu.angle", "egl::Display::initialize");')) {
  throw 'Display::initialize trace site was not found'
}

$targetDir = Join-Path $env:OBJDIR 'gfx\angle\targets\libGLESv2'
if (-not (Test-Path $targetDir)) {
  throw "Generated libGLESv2 target directory missing: $targetDir"
}

$buildLog = 'diagnostics\libglesv2-build.log'
if (-not (Test-Path $buildLog)) {
  throw "libGLESv2 build log missing: $buildLog"
}
$buildText = [System.IO.File]::ReadAllText($buildLog)
$displayCompileLines = @(
  $buildText -split "`r?`n" | Where-Object {
    $_ -match '(?i)clang-cl\.exe' -and
    $_ -match '(?i)-Fo(?:")?Display\.obj' -and
    $_ -match '(?i)[\\/]gfx[\\/]angle[\\/]checkout[\\/]src[\\/]libANGLE[\\/]Display\.cpp(?:\s|$)'
  }
)
if ($displayCompileLines.Count -lt 1) {
  throw 'libGLESv2 build log has no clang-cl command for libANGLE/Display.cpp -> Display.obj'
}

$compileCommand = [string]($displayCompileLines | Select-Object -Last 1)
$compileCommand | Set-Content -Encoding utf8 diagnostics\Display-compile-command.txt

$hasXpDefine = [bool]($compileCommand -match '(?i)(?:^|\s)-DMOZ_XP_COMPAT(?:=1)?(?:\s|$)')
$hasOptimization = [bool]($compileCommand -match '(?i)(?:^|\s)(?:-O[1-3sz]|/O[12x])(?:\s|$)')
if (-not $hasXpDefine) {
  throw 'Display.cpp compile command does not contain MOZ_XP_COMPAT'
}
if (-not $hasOptimization) {
  throw 'Display.cpp compile command does not contain an optimization flag'
}

$displayObjects = @()
$exactDisplayObject = Join-Path $targetDir 'Display.obj'
if (Test-Path $exactDisplayObject) {
  $displayObjects = @(Get-Item $exactDisplayObject)
} else {
  $displayObjects = @(Get-ChildItem -Path $targetDir -Recurse -File -Filter '*Display*.obj')
}
if ($displayObjects.Count -lt 1) {
  throw 'Compiled Display object was not found under the libGLESv2 target'
}

$displayObject = $null
$displaySymbols = $null
foreach ($candidate in $displayObjects) {
  $candidateSymbols = @(& dumpbin.exe /nologo /symbols $candidate.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /symbols failed for $($candidate.Name)"
  }
  if ($candidateSymbols -match '\?initialize@Display@egl@@') {
    $displayObject = $candidate
    $displaySymbols = $candidateSymbols
    break
  }
}
if (-not $displayObject) {
  throw 'No Display object contains egl::Display::initialize'
}

$displayRelocations = @(& dumpbin.exe /nologo /relocations $displayObject.FullName 2>&1)
if ($LASTEXITCODE -ne 0) {
  throw 'dumpbin /relocations failed for Display object'
}
$displayDisasm = @(& dumpbin.exe /nologo /disasm /symbols $displayObject.FullName 2>&1)
if ($LASTEXITCODE -ne 0) {
  throw 'dumpbin /disasm /symbols failed for Display object'
}

$displaySymbols | Set-Content -Encoding utf8 diagnostics\Display-symbols.txt
$displayRelocations | Set-Content -Encoding utf8 diagnostics\Display-relocations.txt
$displayDisasm | Set-Content -Encoding utf8 diagnostics\Display-disasm.txt
Copy-Item -Force $displayObject.FullName diagnostics\Display.obj

$combinedObjectEvidence = @($displaySymbols + $displayRelocations + $displayDisasm)
$traceStaticMatches = @($combinedObjectEvidence | Where-Object { $_ -match 'trace_event_unique_catstatic' })
$traceHelperMatches = @($combinedObjectEvidence | Where-Object { $_ -match 'GetTraceCategoryEnabledFlag' })
$initThreadEpochMatches = @($combinedObjectEvidence | Where-Object { $_ -match '_Init_thread_epoch' })

if ($traceStaticMatches.Count -ne 0) {
  throw "Display object still contains trace_event_unique_catstatic evidence ($($traceStaticMatches.Count) matches)"
}
if ($traceHelperMatches.Count -eq 0) {
  throw 'Display object has no GetTraceCategoryEnabledFlag reference; trace call path is not proven present'
}

$pdbCandidates = @(
  (Join-Path $env:OBJDIR 'dist\bin\libGLESv2.pdb'),
  (Join-Path $targetDir 'libGLESv2.pdb')
) | Where-Object { Test-Path $_ }
if ($pdbCandidates.Count -lt 1) {
  $pdbCandidates = @(Get-ChildItem -Path $env:OBJDIR -Recurse -File -Filter 'libGLESv2.pdb' | Select-Object -ExpandProperty FullName)
}
if ($pdbCandidates.Count -lt 1) {
  throw 'libGLESv2.pdb was not produced by the focused build'
}

$pdb = $pdbCandidates | Select-Object -First 1
Copy-Item -Force $pdb diagnostics\libGLESv2.pdb
$pdbSha256 = (Get-FileHash -Algorithm SHA256 $pdb).Hash.ToLowerInvariant()

@(
  'source_guard=True',
  "display_compile_log_matches=$($displayCompileLines.Count)",
  "display_compile_moz_xp_compat=$hasXpDefine",
  "display_compile_optimized=$hasOptimization",
  'display_initialize_symbol=True',
  "trace_static_symbol_matches=$($traceStaticMatches.Count)",
  "trace_helper_reference_matches=$($traceHelperMatches.Count)",
  "init_thread_epoch_reference_matches=$($initThreadEpochMatches.Count)",
  'libGLESv2_pdb=True',
  "libGLESv2_pdb_sha256=$pdbSha256"
) | Set-Content -Encoding utf8 diagnostics\angle-trace-codegen-result.txt

Write-Host 'ANGLE XP trace codegen gate passed'
Write-Host "MOZ_XP_COMPAT=$hasXpDefine optimized=$hasOptimization trace-static-matches=$($traceStaticMatches.Count) helper-refs=$($traceHelperMatches.Count) Init_thread_epoch-refs=$($initThreadEpochMatches.Count)"
