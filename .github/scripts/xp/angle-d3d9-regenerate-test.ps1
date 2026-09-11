param(
  [Parameter(Mandatory = $true)]
  [string]$GostSource,

  [Parameter(Mandatory = $true)]
  [string]$XpSource,

  [Parameter(Mandatory = $true)]
  [string]$WorkRoot,

  [Parameter(Mandatory = $true)]
  [string]$Diagnostics
)

$ErrorActionPreference = 'Stop'

function Invoke-Checked {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Command,
    [Parameter(Mandatory = $true)]
    [string]$Label
  )

  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE"
  }
}

$GostSource = (Resolve-Path $GostSource).Path
$XpSource = (Resolve-Path $XpSource).Path
New-Item -ItemType Directory -Force $WorkRoot, $Diagnostics | Out-Null
$WorkRoot = (Resolve-Path $WorkRoot).Path
$Diagnostics = (Resolve-Path $Diagnostics).Path

$gostSha = (& git.exe -C $GostSource rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $gostSha) { throw 'Cannot resolve agent/gost-tls-poc SHA' }
$xpSha = (& git.exe -C $XpSource rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $xpSha) { throw 'Cannot resolve agent/winrt-source-poc SHA' }

$generator = Join-Path $GostSource 'gfx\angle\update-angle.py'
$gostMozBuild = Join-Path $GostSource 'gfx\angle\targets\libGLESv2\moz.build'
$xpMozBuild = Join-Path $XpSource 'gfx\angle\targets\libGLESv2\moz.build'
foreach ($path in @($generator, $gostMozBuild, $xpMozBuild)) {
  if (-not (Test-Path $path)) { throw "Required file missing: $path" }
}

$baselineGost = Join-Path $Diagnostics 'libGLESv2.moz.build.gost-before'
$baselineXp = Join-Path $Diagnostics 'libGLESv2.moz.build.xp-before'
Copy-Item $gostMozBuild $baselineGost
Copy-Item $xpMozBuild $baselineXp

$gostBaselineHash = (Get-FileHash -Algorithm SHA256 $baselineGost).Hash.ToLowerInvariant()
$xpBaselineHash = (Get-FileHash -Algorithm SHA256 $baselineXp).Hash.ToLowerInvariant()

$generatorText = [System.IO.File]::ReadAllText($generator).Replace("`r`n", "`n")
$staleArg = "angle_enable_apple_translator_workarounds = true`n"
if (-not $generatorText.Contains($staleArg)) {
  throw 'Expected stale ANGLE GN arg was not found in update-angle.py'
}
$generatorText = $generatorText.Replace($staleArg, '')

$needle = "angle_enable_gl = false`n"
$replacement = "angle_enable_d3d11 = false`nangle_enable_d3d9 = true`nangle_enable_gl = false`n"
if (-not $generatorText.Contains($needle)) {
  throw 'Expected ANGLE GN_ARGS anchor was not found in update-angle.py'
}
if ($generatorText.Contains('angle_enable_d3d11 = false')) {
  throw 'update-angle.py already disables D3D11; refusing to make an ambiguous test patch'
}
$generatorText = $generatorText.Replace($needle, $replacement)

if ($generatorText.Contains('angle_enable_apple_translator_workarounds = true')) {
  throw 'Stale ANGLE GN arg survived the test patch'
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($generator, $generatorText, $utf8NoBom)

$patchedGenerator = Join-Path $Diagnostics 'update-angle.d3d9-only.py'
Copy-Item $generator $patchedGenerator

$depotTools = Join-Path $WorkRoot 'depot_tools'
if (-not (Test-Path (Join-Path $depotTools '.git'))) {
  Invoke-Checked -Label 'depot_tools clone' -Command {
    & git.exe clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git $depotTools
  }
}

$env:DEPOT_TOOLS_WIN_TOOLCHAIN = '0'
$env:PATH = "$depotTools;$env:PATH"
$env:GIT_CACHE_PATH = Join-Path $WorkRoot 'git-cache'
New-Item -ItemType Directory -Force $env:GIT_CACHE_PATH | Out-Null

Invoke-Checked -Label 'depot_tools CIPD bootstrap' -Command {
  & (Join-Path $depotTools 'cipd_bin_setup.bat')
}
Invoke-Checked -Label 'depot_tools Windows bootstrap' -Command {
  & (Join-Path $depotTools 'bootstrap\win_tools.bat')
}

$gitWrapper = Join-Path $depotTools 'git.bat'
if (-not (Test-Path $gitWrapper)) {
  throw "depot_tools bootstrap did not create git.bat: $gitWrapper"
}
Invoke-Checked -Label 'depot_tools git wrapper preflight' -Command {
  & $gitWrapper --version
}

$env:DEPOT_TOOLS_UPDATE = '0'
New-Item -ItemType File -Force (Join-Path $depotTools '.disable_auto_update') | Out-Null

$angle = Join-Path $WorkRoot 'angle'
if (-not (Test-Path (Join-Path $angle '.git'))) {
  Invoke-Checked -Label 'mozilla/angle firefox-153 clone' -Command {
    & git.exe clone --branch firefox-153 --single-branch https://github.com/mozilla/angle.git $angle
  }
}

Invoke-Checked -Label 'fetch chromium/5359 reference' -Command {
  & git.exe -C $angle fetch origin refs/heads/chromium/5359:refs/remotes/origin/chromium/5359
}

$angleSha = (& git.exe -C $angle rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $angleSha) { throw 'Cannot resolve mozilla/angle SHA' }
$angleBranch = (& git.exe -C $angle branch --show-current).Trim()
if ($angleBranch -ne 'firefox-153') { throw "Unexpected ANGLE branch: $angleBranch" }

$exportTargetsHash = $null
Push-Location $angle
try {
  Invoke-Checked -Label 'ANGLE bootstrap' -Command {
    & python.exe scripts\bootstrap.py
  }
  Invoke-Checked -Label 'ANGLE gclient sync' -Command {
    & gclient.bat sync
  }

  $exportTargets = Join-Path $angle 'scripts\export_targets.py'
  if (-not (Test-Path $exportTargets)) { throw "ANGLE export helper missing: $exportTargets" }
  $exportTargetsHash = (Get-FileHash -Algorithm SHA256 $exportTargets).Hash.ToLowerInvariant()
  Copy-Item $exportTargets (Join-Path $Diagnostics 'export_targets.upstream.py')

  $regenLog = Join-Path $Diagnostics 'update-angle-regenerate.log'
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & python.exe $generator origin 2>&1 | Tee-Object -FilePath $regenLog
    $regenExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $savedPreference
  }
  if ($regenExit -ne 0) { throw "update-angle.py failed with exit code $regenExit" }
}
finally {
  Pop-Location
}

if (-not (Test-Path $gostMozBuild)) { throw 'Regenerated libGLESv2/moz.build is missing' }
$generated = Join-Path $Diagnostics 'libGLESv2.moz.build.generated'
Copy-Item $gostMozBuild $generated

$diffPath = Join-Path $Diagnostics 'libGLESv2.moz.build.diff'
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & git.exe diff --no-index -- $baselineGost $generated 2>&1 | Set-Content -Encoding utf8 $diffPath
  $diffExit = $LASTEXITCODE
}
finally {
  $ErrorActionPreference = $savedPreference
}
if ($diffExit -notin @(0, 1)) { throw "git diff --no-index failed with exit code $diffExit" }

$generatedText = [System.IO.File]::ReadAllText($generated)
$d3d11Sources = @([regex]::Matches($generatedText, 'renderer/d3d/d3d11/')).Count
$d3d9Sources = @([regex]::Matches($generatedText, 'renderer/d3d/d3d9/')).Count
$sourceCount = @([regex]::Matches($generatedText, '(?m)^\s*"\.\./\.\./checkout/src/.+\.(?:cpp|cc|c)",\s*$')).Count

$changedAngleFiles = Join-Path $Diagnostics 'regenerated-angle-changed-files.txt'
& git.exe -C $GostSource status --short -- gfx/angle | Set-Content -Encoding utf8 $changedAngleFiles
if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory regenerated gfx/angle changes' }

$summary = @(
  "gost_source=$gostSha",
  "xp_source=$xpSha",
  "angle_branch=$angleBranch",
  "angle_source=$angleSha",
  "export_targets_sha256=$exportTargetsHash",
  "removed_stale_angle_enable_apple_translator_workarounds=True",
  "gost_baseline_sha256=$gostBaselineHash",
  "xp_baseline_sha256=$xpBaselineHash",
  "baselines_identical=$($gostBaselineHash -eq $xpBaselineHash)",
  "generated_sha256=$((Get-FileHash -Algorithm SHA256 $generated).Hash.ToLowerInvariant())",
  "ANGLE_ENABLE_D3D11_TRUE=$($generatedText.Contains('DEFINES["ANGLE_ENABLE_D3D11"] = True'))",
  "ANGLE_ENABLE_D3D9_TRUE=$($generatedText.Contains('DEFINES["ANGLE_ENABLE_D3D9"] = True'))",
  "Renderer11=$($generatedText.Contains('renderer/d3d/d3d11/Renderer11.cpp'))",
  "Renderer9=$($generatedText.Contains('renderer/d3d/d3d9/Renderer9.cpp'))",
  "CompositorNativeWindow11=$($generatedText.Contains('renderer/d3d/d3d11/converged/CompositorNativeWindow11.cpp'))",
  "d3d11_source_refs=$d3d11Sources",
  "d3d9_source_refs=$d3d9Sources",
  "source_refs=$sourceCount",
  "OS_LIBS_d3d11=$($generatedText -match '(?m)^\s*"d3d11",\s*$')",
  "OS_LIBS_dxgi=$($generatedText -match '(?m)^\s*"dxgi",\s*$')",
  "OS_LIBS_d3d9=$($generatedText -match '(?m)^\s*"d3d9",\s*$')"
)
$summaryPath = Join-Path $Diagnostics 'summary.txt'
$summary | Set-Content -Encoding utf8 $summaryPath
$summary | ForEach-Object { Write-Host $_ }

if ($generatedText.Contains('DEFINES["ANGLE_ENABLE_D3D11"] = True')) {
  throw 'Regeneration still defines ANGLE_ENABLE_D3D11=True'
}
if ($d3d11Sources -ne 0) {
  throw "Regeneration still contains D3D11 source references: $d3d11Sources"
}
if (-not $generatedText.Contains('DEFINES["ANGLE_ENABLE_D3D9"] = True')) {
  throw 'Regeneration lost ANGLE_ENABLE_D3D9=True'
}
if (-not $generatedText.Contains('renderer/d3d/d3d9/Renderer9.cpp')) {
  throw 'Regeneration lost Renderer9.cpp'
}
