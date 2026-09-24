$ErrorActionPreference = 'Stop'

if (-not $env:OBJDIR) {
  throw 'OBJDIR is required'
}

New-Item -ItemType Directory -Force diagnostics | Out-Null

$traceHeader = 'gfx\\angle\\checkout\\src\\third_party\\trace_event\\trace_event.h'
$displaySource = 'gfx\\angle\\checkout\\src\\libANGLE\\Display.cpp'
$formatUtilsSource = 'gfx\\angle\\checkout\\src\\libANGLE\\formatutils.cpp'
$angleBuildConfig = 'gfx\\angle\\moz.build.common'

foreach ($path in @($traceHeader, $displaySource, $formatUtilsSource, $angleBuildConfig)) {
  if (-not (Test-Path $path)) {
    throw "Required ANGLE source file missing: $path"
  }
}

$traceText = [System.IO.File]::ReadAllText($traceHeader)
$displayText = [System.IO.File]::ReadAllText($displaySource)
$formatUtilsText = [System.IO.File]::ReadAllText($formatUtilsSource)
$angleBuildText = [System.IO.File]::ReadAllText($angleBuildConfig)

if (-not $traceText.Contains('static const unsigned char *INTERNALTRACEEVENTUID(catstatic)')) {
  throw 'ANGLE trace category cache is not a function-local static'
}
if (-not $displayText.Contains('ANGLE_TRACE_EVENT0("gpu.angle", "egl::Display::initialize");')) {
  throw 'Display::initialize trace site was not found'
}
if ($formatUtilsText -notmatch 'static\\s+angle::base::NoDestructor<FormatSet>\\s+formatSet\\s*\\(\\s*BuildAllSizedInternalFormatSet\\(\\)\\s*\\)\\s*;') {
  throw 'GetAllSizedInternalFormats local-static FormatSet was not found'
}
if (-not $angleBuildText.Contains("if CONFIG['TARGET_CPU'] == 'x86':")) {
  throw 'ANGLE x86 build guard was not found'
}
if (-not $angleBuildText.Contains("CXXFLAGS += ['/Zc:threadSafeInit-']")) {
  throw 'ANGLE x86 /Zc:threadSafeInit- build flag was not found'
}

$targetDir = Join-Path $env:OBJDIR 'gfx\\angle\\targets\\libGLESv2'
if (-not (Test-Path $targetDir)) {
  throw "Generated libGLESv2 target directory missing: $targetDir"
}

$buildLog = 'diagnostics\\libglesv2-build.log'
if (-not (Test-Path $buildLog)) {
  throw "libGLESv2 build log missing: $buildLog"
}
$buildText = [System.IO.File]::ReadAllText($buildLog)

function Get-CompileCommand {
  param(
    [Parameter(Mandatory = $true)][string]$ObjectName,
    [Parameter(Mandatory = $true)][string]$SourcePattern
  )

  $lines = @(
    $buildText -split '[\\r\\n]+' | Where-Object {
      $_ -match '(?i)clang-cl\\.exe' -and
      $_ -match ("(?i)-Fo(?:\\\")?" + [regex]::Escape($ObjectName) + "(?:\\\"|\\s)") -and
      $_ -match $SourcePattern
    }
  )
  if ($lines.Count -lt 1) {
    throw "libGLESv2 build log has no clang-cl command for $ObjectName"
  }
  return [string]($lines | Select-Object -Last 1)
}

function Assert-CompileContract {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Command
  )

  $hasXpDefine = $Command -match '(?i)(?:^|\\s)-DMOZ_XP_COMPAT(?:=1)?(?:\\s|$)'
  $hasThreadSafeInitDisabled = $Command.Contains('/Zc:threadSafeInit-')
  $hasOptimization = $Command -match '(?i)(?:^|\\s)(?:-O[1-3sz]|/O[12x])(?:\\s|$)'

  if (-not $hasXpDefine) {
    throw "$Label compile command does not contain MOZ_XP_COMPAT"
  }
  if (-not $hasThreadSafeInitDisabled) {
    throw "$Label compile command does not contain /Zc:threadSafeInit-"
  }
  if (-not $hasOptimization) {
    throw "$Label compile command does not contain an optimization flag"
  }

  return [pscustomobject]@{
    HasXpDefine = $hasXpDefine
    HasThreadSafeInitDisabled = $hasThreadSafeInitDisabled
    HasOptimization = $hasOptimization
  }
}

function Get-TargetObject {
  param(
    [Parameter(Mandatory = $true)][string]$FileName
  )

  $exact = Join-Path $targetDir $FileName
  if (Test-Path $exact) {
    return (Get-Item $exact)
  }

  $matches = @(Get-ChildItem -Path $targetDir -Recurse -File -Filter $FileName)
  if ($matches.Count -ne 1) {
    throw "Expected exactly one $FileName under libGLESv2 target, found $($matches.Count)"
  }
  return $matches[0]
}

function Get-ObjectEvidence {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][System.IO.FileInfo]$Object,
    [Parameter(Mandatory = $true)][string]$RequiredSymbolPattern
  )

  $symbols = @(& dumpbin.exe /nologo /symbols $Object.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /symbols failed for $Label"
  }
  $relocations = @(& dumpbin.exe /nologo /relocations $Object.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /relocations failed for $Label"
  }
  $disasm = @(& dumpbin.exe /nologo /disasm /symbols $Object.FullName 2>&1)
  if ($LASTEXITCODE -ne 0) {
    throw "dumpbin /disasm /symbols failed for $Label"
  }

  $symbols | Set-Content -Encoding utf8 "diagnostics\\$Label-symbols.txt"
  $relocations | Set-Content -Encoding utf8 "diagnostics\\$Label-relocations.txt"
  $disasm | Set-Content -Encoding utf8 "diagnostics\\$Label-disasm.txt"
  Copy-Item -Force $Object.FullName "diagnostics\\$Label.obj"

  if (-not ($symbols -match $RequiredSymbolPattern)) {
    throw "$Label object does not contain the expected owner symbol"
  }

  $combined = @($symbols + $relocations + $disasm)
  $initThreadMatches = @($combined | Where-Object {
    $_ -match '(?i)_Init_thread_(?:header|footer|epoch)'
  })

  if ($initThreadMatches.Count -ne 0) {
    $initThreadMatches | Set-Content -Encoding utf8 "diagnostics\\$Label-init-thread-matches.txt"
    throw "$Label object still contains MSVC thread-safe local-static helper evidence ($($initThreadMatches.Count) matches)"
  }

  return [pscustomobject]@{
    InitThreadMatches = $initThreadMatches.Count
  }
}

$displayCommand = Get-CompileCommand -ObjectName 'Display.obj' -SourcePattern '(?i)[\\\\/]gfx[\\\\/]angle[\\\\/]checkout[\\\\/]src[\\\\/]libANGLE[\\\\/]Display\\.cpp(?:\\s|$)'
$formatUtilsCommand = Get-CompileCommand -ObjectName 'formatutils.obj' -SourcePattern '(?i)[\\\\/]gfx[\\\\/]angle[\\\\/]checkout[\\\\/]src[\\\\/]libANGLE[\\\\/]formatutils\\.cpp(?:\\s|$)'

$displayCommand | Set-Content -Encoding utf8 diagnostics\\Display-compile-command.txt
$formatUtilsCommand | Set-Content -Encoding utf8 diagnostics\\formatutils-compile-command.txt

$displayCompile = Assert-CompileContract -Label 'Display.cpp' -Command $displayCommand
$formatUtilsCompile = Assert-CompileContract -Label 'formatutils.cpp' -Command $formatUtilsCommand

$displayObject = Get-TargetObject -FileName 'Display.obj'
$formatUtilsObject = Get-TargetObject -FileName 'formatutils.obj'

$displayEvidence = Get-ObjectEvidence -Label 'Display' -Object $displayObject -RequiredSymbolPattern '\\?initialize@Display@egl@@'
$formatUtilsEvidence = Get-ObjectEvidence -Label 'formatutils' -Object $formatUtilsObject -RequiredSymbolPattern 'GetAllSizedInternalFormats@gl@@'

$pdbCandidates = @(
  (Join-Path $env:OBJDIR 'dist\\bin\\libGLESv2.pdb'),
  (Join-Path $targetDir 'libGLESv2.pdb')
) | Where-Object { Test-Path $_ }
if ($pdbCandidates.Count -lt 1) {
  $pdbCandidates = @(Get-ChildItem -Path $env:OBJDIR -Recurse -File -Filter 'libGLESv2.pdb' | Select-Object -ExpandProperty FullName)
}
if ($pdbCandidates.Count -lt 1) {
  throw 'libGLESv2.pdb was not produced by the focused build'
}

$pdb = $pdbCandidates | Select-Object -First 1
Copy-Item -Force $pdb diagnostics\\libGLESv2.pdb
$pdbSha256 = (Get-FileHash -Algorithm SHA256 $pdb).Hash.ToLowerInvariant()

@(
  'source_trace_static=True',
  'source_formatset_static=True',
  'angle_x86_thread_safe_init_disabled=True',
  "display_compile_moz_xp_compat=$($displayCompile.HasXpDefine)",
  "display_compile_thread_safe_init_disabled=$($displayCompile.HasThreadSafeInitDisabled)",
  "display_compile_optimized=$($displayCompile.HasOptimization)",
  "display_init_thread_matches=$($displayEvidence.InitThreadMatches)",
  "formatutils_compile_moz_xp_compat=$($formatUtilsCompile.HasXpDefine)",
  "formatutils_compile_thread_safe_init_disabled=$($formatUtilsCompile.HasThreadSafeInitDisabled)",
  "formatutils_compile_optimized=$($formatUtilsCompile.HasOptimization)",
  "formatutils_init_thread_matches=$($formatUtilsEvidence.InitThreadMatches)",
  'libGLESv2_pdb=True',
  "libGLESv2_pdb_sha256=$pdbSha256"
) | Set-Content -Encoding utf8 diagnostics\\angle-trace-codegen-result.txt

Write-Host 'ANGLE XP local-static codegen gate passed'
Write-Host "Display.cpp: /Zc:threadSafeInit-=$($displayCompile.HasThreadSafeInitDisabled) Init_thread_matches=$($displayEvidence.InitThreadMatches)"
Write-Host "formatutils.cpp: /Zc:threadSafeInit-=$($formatUtilsCompile.HasThreadSafeInitDisabled) Init_thread_matches=$($formatUtilsEvidence.InitThreadMatches)"
