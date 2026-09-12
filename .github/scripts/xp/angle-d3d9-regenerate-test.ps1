param(
  [Parameter(Mandatory = $true)]
  [string]$Source,

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

$Source = (Resolve-Path $Source).Path
New-Item -ItemType Directory -Force $WorkRoot, $Diagnostics | Out-Null
$WorkRoot = (Resolve-Path $WorkRoot).Path
$Diagnostics = (Resolve-Path $Diagnostics).Path

$sourceSha = (& git.exe -C $Source rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $sourceSha) { throw 'Cannot resolve agent/winrt-source-poc SHA' }

$generator = Join-Path $Source 'gfx\angle\update-angle.py'
$mozBuild = Join-Path $Source 'gfx\angle\targets\libGLESv2\moz.build'
$cherryPicks = Join-Path $Source 'gfx\angle\cherry_picks.txt'
$angleCommitHeader = Join-Path $Source 'gfx\angle\checkout\out\gen\angle\angle_commit.h'
foreach ($path in @($generator, $mozBuild, $cherryPicks, $angleCommitHeader)) {
  if (-not (Test-Path $path)) { throw "Required file missing: $path" }
}

$cherryText = [System.IO.File]::ReadAllText($cherryPicks)
$vendorMatch = [regex]::Match($cherryText, '(?m)^commit ([0-9a-f]{40})\r?$')
if (-not $vendorMatch.Success) { throw 'Cannot resolve exact vendored ANGLE commit from cherry_picks.txt' }
$vendorAngleSha = $vendorMatch.Groups[1].Value
$headerText = [System.IO.File]::ReadAllText($angleCommitHeader)
$headerMatch = [regex]::Match($headerText, 'ANGLE_COMMIT_HASH "([0-9a-f]{12})"')
if (-not $headerMatch.Success) { throw 'Cannot resolve ANGLE_COMMIT_HASH from angle_commit.h' }
if (-not $vendorAngleSha.StartsWith($headerMatch.Groups[1].Value)) {
  throw "Vendored ANGLE identity mismatch: cherry_picks=$vendorAngleSha header=$($headerMatch.Groups[1].Value)"
}

$baseline = Join-Path $Diagnostics 'libGLESv2.moz.build.before'
Copy-Item $mozBuild $baseline
$baselineHash = (Get-FileHash -Algorithm SHA256 $baseline).Hash.ToLowerInvariant()

$generatorText = [System.IO.File]::ReadAllText($generator).Replace("`r`n", "`n")
$gnArgsNeedle = "angle_enable_gl = false`n"
$gnArgsReplacement = "angle_enable_d3d11 = false`nangle_enable_d3d9 = true`nangle_enable_gl = false`n"
if (-not $generatorText.Contains($gnArgsNeedle)) {
  throw 'Expected ANGLE GN_ARGS anchor was not found in update-angle.py'
}
if ($generatorText.Contains('angle_enable_d3d11 = false')) {
  throw 'update-angle.py already disables D3D11; refusing to make an ambiguous test patch'
}
$generatorText = $generatorText.Replace($gnArgsNeedle, $gnArgsReplacement)

$oldGeneratorExport = @'
p = run_checked(
    "python3",
    "scripts/export_targets.py",
    str(OUT_DIR),
    *ROOTS,
    stdout=subprocess.PIPE,
    shell=True,
    env=GN_ENV,
)

# -

print("\nProcessing graph")
libraries = json.loads(p.stdout.decode())
'@
$newGeneratorExport = @'
export_json_path = OUT_DIR / "export-targets.json"
with export_json_path.open("wb") as export_json:
    run_checked(
        "python3",
        "scripts/export_targets.py",
        str(OUT_DIR),
        *ROOTS,
        stdout=export_json,
        shell=True,
        env=GN_ENV,
    )

# -

print("\nProcessing graph")
if not export_json_path.is_file() or export_json_path.stat().st_size == 0:
    raise RuntimeError("export_targets.py produced an empty JSON file")
print(f" export_targets JSON bytes: {export_json_path.stat().st_size}")
with export_json_path.open("r", encoding="utf-8-sig") as export_json:
    libraries = json.load(export_json)
'@
$oldGeneratorExport = $oldGeneratorExport.Replace("`r`n", "`n")
$newGeneratorExport = $newGeneratorExport.Replace("`r`n", "`n")
if (-not $generatorText.Contains($oldGeneratorExport)) {
  throw 'Expected update-angle.py exporter capture block was not found'
}
$generatorText = $generatorText.Replace($oldGeneratorExport, $newGeneratorExport)

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($generator, $generatorText, $utf8NoBom)
Copy-Item $generator (Join-Path $Diagnostics 'update-angle.d3d9-only.py')

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
if (-not (Test-Path $gitWrapper)) { throw "depot_tools bootstrap did not create git.bat: $gitWrapper" }
Invoke-Checked -Label 'depot_tools git wrapper preflight' -Command {
  & $gitWrapper --version
}
$env:DEPOT_TOOLS_UPDATE = '0'
New-Item -ItemType File -Force (Join-Path $depotTools '.disable_auto_update') | Out-Null

$angle = Join-Path $WorkRoot 'angle'
if (-not (Test-Path (Join-Path $angle '.git'))) {
  New-Item -ItemType Directory -Force $angle | Out-Null
  Invoke-Checked -Label 'mozilla/angle repository init' -Command {
    & git.exe -C $angle init
  }
  Invoke-Checked -Label 'mozilla/angle origin registration' -Command {
    & git.exe -C $angle remote add origin https://github.com/mozilla/angle.git
  }
}
Invoke-Checked -Label 'fetch exact vendored ANGLE commit' -Command {
  & git.exe -C $angle fetch --depth 1 origin $vendorAngleSha
}
Invoke-Checked -Label 'checkout exact vendored ANGLE commit' -Command {
  & git.exe -C $angle checkout --detach FETCH_HEAD
}
Invoke-Checked -Label 'fetch chromium/5359 reference' -Command {
  & git.exe -C $angle fetch origin refs/heads/chromium/5359:refs/remotes/origin/chromium/5359
}

$angleSha = (& git.exe -C $angle rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or -not $angleSha) { throw 'Cannot resolve mozilla/angle SHA' }
if ($angleSha -ne $vendorAngleSha) { throw "ANGLE checkout mismatch: expected=$vendorAngleSha actual=$angleSha" }

$exportTargetsHash = $null
$patchedExportTargetsHash = $null
$buildGnUpstreamHash = $null
$buildGnPatchedHash = $null
$gnDescHash = $null
$gnDescBytes = $null
$exportJsonHash = $null
$exportJsonBytes = $null
$selectedWindowsSdkVersion = $null
$toolchainSetupUpstreamHash = $null
$toolchainSetupPatchedHash = $null

Push-Location $angle
try {
  Invoke-Checked -Label 'ANGLE bootstrap' -Command {
    & python.exe scripts\bootstrap.py
  }
  Invoke-Checked -Label 'ANGLE gclient sync' -Command {
    & gclient.bat sync
  }

  $windowsKitsRoot = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'
  $sdkIncludeRoot = Join-Path $windowsKitsRoot 'Include'
  $sdkLibRoot = Join-Path $windowsKitsRoot 'Lib'
  foreach ($sdkRootPath in @($sdkIncludeRoot, $sdkLibRoot)) {
    if (-not (Test-Path -LiteralPath $sdkRootPath -PathType Container)) {
      throw "Windows 10 SDK root missing: $sdkRootPath"
    }
  }

  $sdkCandidates = @(
    Get-ChildItem -LiteralPath $sdkIncludeRoot -Directory |
      Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
      Sort-Object { [version]$_.Name } -Descending
  )
  foreach ($candidate in $sdkCandidates) {
    $versionName = $candidate.Name
    $requiredSdkPaths = @(
      (Join-Path $sdkIncludeRoot "$versionName\um"),
      (Join-Path $sdkIncludeRoot "$versionName\shared"),
      (Join-Path $sdkIncludeRoot "$versionName\ucrt"),
      (Join-Path $sdkLibRoot "$versionName\um\x86"),
      (Join-Path $sdkLibRoot "$versionName\ucrt\x86")
    )
    $missingSdkPaths = @($requiredSdkPaths | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Container) })
    if ($missingSdkPaths.Count -eq 0) {
      $selectedWindowsSdkVersion = $versionName
      break
    }
  }
  if (-not $selectedWindowsSdkVersion) {
    throw "No complete Windows 10 SDK x86 layout found under $windowsKitsRoot"
  }

  $setupToolchain = Join-Path $angle 'build\toolchain\win\setup_toolchain.py'
  if (-not (Test-Path -LiteralPath $setupToolchain -PathType Leaf)) {
    throw "Vendored Chromium setup_toolchain.py missing after gclient sync: $setupToolchain"
  }
  $setupToolchainBefore = Join-Path $Diagnostics 'setup_toolchain.py.upstream'
  Copy-Item $setupToolchain $setupToolchainBefore
  $toolchainSetupUpstreamHash = (Get-FileHash -Algorithm SHA256 $setupToolchain).Hash.ToLowerInvariant()
  $setupToolchainText = [System.IO.File]::ReadAllText($setupToolchain).Replace("`r`n", "`n")
  $sdkAnchor = "    args.append('10.0.20348.0')"
  $sdkAnchorCount = ([regex]::Matches($setupToolchainText, [regex]::Escape($sdkAnchor))).Count
  if ($sdkAnchorCount -ne 1) {
    throw "Expected exact Chromium SDK anchor once, found $sdkAnchorCount; refusing a fuzzy toolchain patch"
  }
  $sdkReplacement = "    args.append('$selectedWindowsSdkVersion')"
  $setupToolchainText = $setupToolchainText.Replace($sdkAnchor, $sdkReplacement)
  [System.IO.File]::WriteAllText($setupToolchain, $setupToolchainText, $utf8NoBom)
  $toolchainSetupPatchedHash = (Get-FileHash -Algorithm SHA256 $setupToolchain).Hash.ToLowerInvariant()
  Copy-Item $setupToolchain (Join-Path $Diagnostics 'setup_toolchain.py.selected-sdk')

  @(
    "windows_kits_root=$windowsKitsRoot",
    "selected_windows_sdk_version=$selectedWindowsSdkVersion",
    "setup_toolchain_upstream_sha256=$toolchainSetupUpstreamHash",
    "setup_toolchain_patched_sha256=$toolchainSetupPatchedHash",
    "sdk_anchor=$sdkAnchor",
    "sdk_replacement=$sdkReplacement"
  ) | Set-Content -Encoding utf8 (Join-Path $Diagnostics 'windows-sdk-selection.txt')

  $buildGn = Join-Path $angle 'BUILD.gn'
  if (-not (Test-Path $buildGn)) { throw "ANGLE BUILD.gn missing: $buildGn" }
  $buildGnBefore = Join-Path $Diagnostics 'BUILD.gn.upstream'
  Copy-Item $buildGn $buildGnBefore
  $buildGnUpstreamHash = (Get-FileHash -Algorithm SHA256 $buildGn).Hash.ToLowerInvariant()
  $buildGnText = [System.IO.File]::ReadAllText($buildGn).Replace("`r`n", "`n")

  $oldFormatTables = @'
if ((is_win && angle_enable_gl) || angle_enable_d3d11 || angle_enable_d3d9) {
  angle_source_set("angle_d3d_format_tables") {
    sources = [
      "src/libANGLE/renderer/dxgi_format_map.h",
      "src/libANGLE/renderer/dxgi_format_map_autogen.cpp",
      "src/libANGLE/renderer/dxgi_support_table.h",
      "src/libANGLE/renderer/dxgi_support_table_autogen.cpp",
    ]

    if (!angle_is_winuwp) {
      sources += [
        "src/libANGLE/renderer/d3d_format.cpp",
        "src/libANGLE/renderer/d3d_format.h",
      ]
    }

    public_deps = [ ":libANGLE_headers" ]
    configs += [ ":angle_backend_config" ]
  }
}
'@
  $newFormatTables = @'
if ((is_win && angle_enable_gl) || angle_enable_d3d11 || angle_enable_d3d9) {
  angle_source_set("angle_d3d_format_tables") {
    sources = []

    if ((is_win && angle_enable_gl) || angle_enable_d3d11) {
      sources += [
        "src/libANGLE/renderer/dxgi_format_map.h",
        "src/libANGLE/renderer/dxgi_format_map_autogen.cpp",
        "src/libANGLE/renderer/dxgi_support_table.h",
        "src/libANGLE/renderer/dxgi_support_table_autogen.cpp",
      ]
    }

    if (!angle_is_winuwp) {
      sources += [
        "src/libANGLE/renderer/d3d_format.cpp",
        "src/libANGLE/renderer/d3d_format.h",
      ]
    }

    public_deps = [ ":libANGLE_headers" ]
    configs += [ ":angle_backend_config" ]
  }
}
'@
  $oldFormatTables = $oldFormatTables.Replace("`r`n", "`n")
  $newFormatTables = $newFormatTables.Replace("`r`n", "`n")
  if (-not $buildGnText.Contains($oldFormatTables)) {
    throw 'Exact-vendor angle_d3d_format_tables block was not found; refusing a fuzzy BUILD.gn patch'
  }
  if ($buildGnText.Contains('sources = []') -and $buildGnText.Contains('if ((is_win && angle_enable_gl) || angle_enable_d3d11)')) {
    throw 'ANGLE BUILD.gn already appears to contain the D3D9 format-table split; refusing an ambiguous patch'
  }
  $buildGnText = $buildGnText.Replace($oldFormatTables, $newFormatTables)
  [System.IO.File]::WriteAllText($buildGn, $buildGnText, $utf8NoBom)
  $buildGnPatchedHash = (Get-FileHash -Algorithm SHA256 $buildGn).Hash.ToLowerInvariant()
  Copy-Item $buildGn (Join-Path $Diagnostics 'BUILD.gn.d3d9-format-split')

  $buildGnDiff = Join-Path $Diagnostics 'BUILD.gn.d3d9-format-split.diff'
  $savedPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    & git.exe diff --no-index -- $buildGnBefore $buildGn 2>&1 | Set-Content -Encoding utf8 $buildGnDiff
    $buildGnDiffExit = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $savedPreference
  }
  if ($buildGnDiffExit -notin @(0, 1)) { throw "BUILD.gn diff failed with exit code $buildGnDiffExit" }
  if ($buildGnDiffExit -ne 1) { throw 'ANGLE BUILD.gn D3D9 format-table patch made no change' }

  $exportTargets = Join-Path $angle 'scripts\export_targets.py'
  if (-not (Test-Path $exportTargets)) { throw "ANGLE export helper missing: $exportTargets" }
  $exportTargetsHash = (Get-FileHash -Algorithm SHA256 $exportTargets).Hash.ToLowerInvariant()
  Copy-Item $exportTargets (Join-Path $Diagnostics 'export_targets.upstream.py')

  $exportTargetsText = [System.IO.File]::ReadAllText($exportTargets).Replace("`r`n", "`n")
  $oldGnDesc = @'
try:
    p = run_checked('gn', 'desc', '--format=json', str(OUT_DIR), '*', stdout=subprocess.PIPE,
                env=GN_ENV, shell=(True if sys.platform == 'win32' else False))
except subprocess.CalledProcessError:
    sys.stderr.buffer.write(b'"gn desc" failed. Is depot_tools in your PATH?\n')
    exit(1)

# -

print('\nProcessing graph', file=sys.stderr)
descs = json.loads(p.stdout.decode())
'@
  $newGnDesc = @'
gn_desc_path = pathlib.Path(OUT_DIR) / 'gn-desc.json'
try:
    with gn_desc_path.open('wb') as gn_desc_file:
        run_checked('gn', 'desc', '--format=json', str(OUT_DIR), '*', stdout=gn_desc_file,
                    env=GN_ENV, shell=(True if sys.platform == 'win32' else False))
except subprocess.CalledProcessError:
    sys.stderr.buffer.write(b'"gn desc" failed. Is depot_tools in your PATH?\n')
    exit(1)

# -

print('\nProcessing graph', file=sys.stderr)
if not gn_desc_path.is_file() or gn_desc_path.stat().st_size == 0:
    raise RuntimeError('gn desc produced an empty JSON file')
print(f' gn desc JSON bytes: {gn_desc_path.stat().st_size}', file=sys.stderr)
gn_desc_text = gn_desc_path.read_text(encoding='utf-8-sig')
json_start = gn_desc_text.find('{')
if json_start < 0:
    raise RuntimeError(f'gn desc output has no JSON object; prefix={gn_desc_text[:512]!r}')
if json_start:
    print(f' gn desc leading diagnostics: {gn_desc_text[:json_start]!r}', file=sys.stderr)
descs = json.loads(gn_desc_text[json_start:])
'@
  $oldGnDesc = $oldGnDesc.Replace("`r`n", "`n")
  $newGnDesc = $newGnDesc.Replace("`r`n", "`n")
  if (-not $exportTargetsText.Contains($oldGnDesc)) {
    throw 'Expected exact-vendor export_targets.py GN capture block was not found'
  }
  $exportTargetsText = $exportTargetsText.Replace($oldGnDesc, $newGnDesc)
  [System.IO.File]::WriteAllText($exportTargets, $exportTargetsText, $utf8NoBom)
  $patchedExportTargetsHash = (Get-FileHash -Algorithm SHA256 $exportTargets).Hash.ToLowerInvariant()
  Copy-Item $exportTargets (Join-Path $Diagnostics 'export_targets.file-json.py')

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

  $gnDescPath = Join-Path $angle 'out\gn-desc.json'
  $exportJsonPath = Join-Path $angle 'out\export-targets.json'
  foreach ($jsonPath in @($gnDescPath, $exportJsonPath)) {
    if (-not (Test-Path $jsonPath)) { throw "Expected persisted ANGLE JSON missing: $jsonPath" }
    if ((Get-Item $jsonPath).Length -le 0) { throw "Persisted ANGLE JSON is empty: $jsonPath" }
  }
  $gnDescHash = (Get-FileHash -Algorithm SHA256 $gnDescPath).Hash.ToLowerInvariant()
  $gnDescBytes = (Get-Item $gnDescPath).Length
  $exportJsonHash = (Get-FileHash -Algorithm SHA256 $exportJsonPath).Hash.ToLowerInvariant()
  $exportJsonBytes = (Get-Item $exportJsonPath).Length
}
finally {
  Pop-Location
}

$trim11 = 'gfx/angle/checkout/src/libANGLE/renderer/d3d/d3d11/Trim11.cpp'
& git.exe -C $Source checkout -- $trim11
if ($LASTEXITCODE -ne 0) { throw 'Cannot restore project-local ANGLE Trim11.cpp compatibility patch after regeneration' }

if (-not (Test-Path $mozBuild)) { throw 'Regenerated libGLESv2/moz.build is missing' }
$generated = Join-Path $Diagnostics 'libGLESv2.moz.build.generated'
Copy-Item $mozBuild $generated

$diffPath = Join-Path $Diagnostics 'libGLESv2.moz.build.diff'
$savedPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & git.exe diff --no-index -- $baseline $generated 2>&1 | Set-Content -Encoding utf8 $diffPath
  $diffExit = $LASTEXITCODE
}
finally {
  $ErrorActionPreference = $savedPreference
}
if ($diffExit -notin @(0, 1)) { throw "git diff --no-index failed with exit code $diffExit" }

$changedPaths = @(& git.exe -C $Source diff --name-only -- gfx/angle | Where-Object { $_ })
if ($LASTEXITCODE -ne 0) { throw 'Cannot inventory regenerated gfx/angle changes' }
$changedPaths | Set-Content -Encoding utf8 (Join-Path $Diagnostics 'regenerated-angle-changed-files.txt')
$checkoutChanges = @($changedPaths | Where-Object { $_ -like 'gfx/angle/checkout/*' })
if ($checkoutChanges.Count -ne 0) {
  throw "Exact-vendor regeneration unexpectedly changed checkout sources: $($checkoutChanges -join ', ')"
}

$generatedFilesRoot = Join-Path $Diagnostics 'regenerated-files'
foreach ($relativePath in $changedPaths) {
  $sourcePath = Join-Path $Source $relativePath
  if (-not (Test-Path $sourcePath -PathType Leaf)) { continue }
  $destPath = Join-Path $generatedFilesRoot $relativePath
  New-Item -ItemType Directory -Force (Split-Path -Parent $destPath) | Out-Null
  Copy-Item $sourcePath $destPath
}

$generatedText = [System.IO.File]::ReadAllText($generated)
$d3d11Sources = @([regex]::Matches($generatedText, 'renderer/d3d/d3d11/')).Count
$d3d9Sources = @([regex]::Matches($generatedText, 'renderer/d3d/d3d9/')).Count
$sourceCount = @([regex]::Matches($generatedText, '(?m)^\s*"\.\./\.\./checkout/src/.+\.(?:cpp|cc|c)",\s*$')).Count
$dxgiFormatMap = $generatedText.Contains('renderer/dxgi_format_map_autogen.cpp')
$dxgiSupportTable = $generatedText.Contains('renderer/dxgi_support_table_autogen.cpp')
$dxgiFormatHeader = $generatedText.Contains('renderer/dxgi_format_map.h')
$dxgiSupportHeader = $generatedText.Contains('renderer/dxgi_support_table.h')
$d3dFormatCpp = $generatedText.Contains('renderer/d3d_format.cpp')
$d3dFormatHeader = $generatedText.Contains('renderer/d3d_format.h')

$summary = @(
  "source_under_test=$sourceSha",
  "angle_source=$angleSha",
  "vendored_angle_source=$vendorAngleSha",
  "generator_source=agent/winrt-source-poc",
  "selected_windows_sdk_version=$selectedWindowsSdkVersion",
  "setup_toolchain_upstream_sha256=$toolchainSetupUpstreamHash",
  "setup_toolchain_selected_sdk_sha256=$toolchainSetupPatchedHash",
  "build_gn_upstream_sha256=$buildGnUpstreamHash",
  "build_gn_d3d9_split_sha256=$buildGnPatchedHash",
  "export_targets_upstream_sha256=$exportTargetsHash",
  "export_targets_file_json_sha256=$patchedExportTargetsHash",
  "json_transport=file",
  "gn_desc_json_bytes=$gnDescBytes",
  "gn_desc_json_sha256=$gnDescHash",
  "export_targets_json_bytes=$exportJsonBytes",
  "export_targets_json_sha256=$exportJsonHash",
  "baseline_sha256=$baselineHash",
  "generated_sha256=$((Get-FileHash -Algorithm SHA256 $generated).Hash.ToLowerInvariant())",
  "regenerated_angle_changed_count=$($changedPaths.Count)",
  "ANGLE_ENABLE_D3D11_TRUE=$($generatedText.Contains('DEFINES[\"ANGLE_ENABLE_D3D11\"] = True'))",
  "ANGLE_ENABLE_D3D9_TRUE=$($generatedText.Contains('DEFINES[\"ANGLE_ENABLE_D3D9\"] = True'))",
  "Renderer11=$($generatedText.Contains('renderer/d3d/d3d11/Renderer11.cpp'))",
  "Renderer9=$($generatedText.Contains('renderer/d3d/d3d9/Renderer9.cpp'))",
  "CompositorNativeWindow11=$($generatedText.Contains('renderer/d3d/d3d11/converged/CompositorNativeWindow11.cpp'))",
  "dxgi_format_map_autogen=$dxgiFormatMap",
  "dxgi_support_table_autogen=$dxgiSupportTable",
  "dxgi_format_map_header=$dxgiFormatHeader",
  "dxgi_support_table_header=$dxgiSupportHeader",
  "d3d_format_cpp=$d3dFormatCpp",
  "d3d_format_header=$d3dFormatHeader",
  "d3d11_source_refs=$d3d11Sources",
  "d3d9_source_refs=$d3d9Sources",
  "source_refs=$sourceCount",
  "OS_LIBS_d3d11=$($generatedText -match '(?m)^\s*\"d3d11\",\s*$')",
  "OS_LIBS_dxgi=$($generatedText -match '(?m)^\s*\"dxgi\",\s*$')",
  "OS_LIBS_d3d9=$($generatedText -match '(?m)^\s*\"d3d9\",\s*$')"
)
$summaryPath = Join-Path $Diagnostics 'summary.txt'
$summary | Set-Content -Encoding utf8 $summaryPath
$summary | ForEach-Object { Write-Host $_ }

if ($angleSha -ne $vendorAngleSha) { throw 'Regeneration did not use the exact vendored ANGLE identity' }
if ($generatedText.Contains('DEFINES["ANGLE_ENABLE_D3D11"] = True')) {
  throw 'Regeneration still defines ANGLE_ENABLE_D3D11=True'
}
if ($d3d11Sources -ne 0) {
  throw "Regeneration still contains D3D11 source references: $d3d11Sources"
}
if ($dxgiFormatMap -or $dxgiSupportTable -or $dxgiFormatHeader -or $dxgiSupportHeader) {
  throw 'Regeneration still contains D3D11-owned DXGI format/support-table sources'
}
if (-not $d3dFormatCpp -or -not $d3dFormatHeader) {
  throw 'Regeneration lost the shared D3D9 d3d_format sources'
}
if (-not $generatedText.Contains('DEFINES["ANGLE_ENABLE_D3D9"] = True')) {
  throw 'Regeneration lost ANGLE_ENABLE_D3D9=True'
}
if (-not $generatedText.Contains('renderer/d3d/d3d9/Renderer9.cpp')) {
  throw 'Regeneration lost Renderer9.cpp'
}
if ($generatedText.Contains('renderer/d3d/d3d11/converged/CompositorNativeWindow11.cpp')) {
  throw 'Regeneration still includes CompositorNativeWindow11.cpp'
}
if ($generatedText -match '(?m)^\s*"d3d11",\s*$') {
  throw 'Regeneration still links d3d11'
}
if ($generatedText -match '(?m)^\s*"dxgi",\s*$') {
  throw 'Regeneration still links dxgi'
}
if (-not ($generatedText -match '(?m)^\s*"d3d9",\s*$')) {
  throw 'Regeneration lost d3d9 OS_LIBS dependency'
}
