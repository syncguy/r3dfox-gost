param(
    [Parameter(Mandatory = $true)][string]$ObjDir,
    [Parameter(Mandatory = $true)][string]$ExpectedSourceSha
)

$ErrorActionPreference = 'Stop'

$actualSourceSha = (& git rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actualSourceSha -ne $ExpectedSourceSha) {
    throw "Checkout/source identity mismatch: expected $ExpectedSourceSha, actual $actualSourceSha"
}

$resolvedObjDir = (Resolve-Path -LiteralPath $ObjDir).Path
$distBin = Join-Path $resolvedObjDir 'dist\bin'
if (-not (Test-Path -LiteralPath $distBin -PathType Container)) {
    throw 'dist/bin is missing'
}
$requiredPaths = @('r3dfox.exe', 'gtest\xul.dll', 'dependentlibs.list.gtest')
foreach ($name in $requiredPaths) {
    $candidate = Join-Path $distBin $name
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Required gtest runtime file missing: $name"
    }
    if ((Get-Item -LiteralPath $candidate).Length -le 0) {
        throw "Required gtest runtime file is empty: $name"
    }
}
$gtestDeps = @(Get-Content -LiteralPath (Join-Path $distBin 'dependentlibs.list.gtest') |
    ForEach-Object { $_.Trim().Replace('\', '/') } |
    Where-Object { $_ })
if ($gtestDeps.Count -lt 1 -or $gtestDeps[-1] -ne 'gtest/xul.dll') {
    throw 'dependentlibs.list.gtest does not select gtest/xul.dll'
}

$entries = @(
    Get-ChildItem -LiteralPath $distBin -Recurse -File |
        Where-Object { $_.Name -ne 'xp-gtest-build-manifest.json' } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($distBin.Length + 1).Replace('\', '/')
            [ordered]@{
                path = $relative
                size_bytes = $_.Length
                sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
            }
        }
)
if ($entries.Count -lt 2) {
    throw 'Unexpected empty gtest dist/bin runtime closure'
}

$manifest = [ordered]@{
    schema = 'xp-handlewatcher-gtest-bundle-v2'
    source_under_test_sha = $actualSourceSha
    controller_commit_sha = $env:GITHUB_SHA
    workflow = $env:GITHUB_WORKFLOW
    run_id = $env:GITHUB_RUN_ID
    run_attempt = $env:GITHUB_RUN_ATTEMPT
    target = 'Windows XP SP3 x86 (i686)'
    gtest_xul = 'gtest/xul.dll'
    loader_manifest = 'dependentlibs.list.gtest'
    evidence_scope = 'hosted link plus structure/hash check only; runtime closure and tests not proven'
    files = $entries
}
$symbolsDir = Join-Path $env:RUNNER_TEMP 'xp-handlewatcher-gtest-symbols'
New-Item -ItemType Directory -Path $symbolsDir -Force | Out-Null
$symbolEntries = @()
$symbolPaths = @(
    (Join-Path $resolvedObjDir 'toolkit\library\gtest\xul.pdb'),
    (Join-Path $resolvedObjDir 'browser\app\r3dfox.pdb')
)
foreach ($candidate in $symbolPaths) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Required matching PDB missing: $candidate"
    }
    $target = Join-Path $symbolsDir (Split-Path -Path $candidate -Leaf)
    Copy-Item -LiteralPath $candidate -Destination $target -Force
    $item = Get-Item -LiteralPath $target
    $symbolEntries += [ordered]@{
        file = $item.Name
        size_bytes = $item.Length
        sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}
$symbolManifest = [ordered]@{
    source_under_test_sha = $actualSourceSha
    controller_commit_sha = $env:GITHUB_SHA
    symbols = $symbolEntries
}
$symbolManifest | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $symbolsDir 'symbols-manifest.json') -Encoding UTF8
Write-Host "GTEST_SYMBOL_COUNT=$($symbolEntries.Count)"

$manifestPath = Join-Path $distBin 'xp-gtest-build-manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "GTEST_BUNDLE_SOURCE_SHA=$actualSourceSha"
Write-Host "GTEST_BUNDLE_FILE_COUNT=$($entries.Count)"
Write-Host "GTEST_BUNDLE_MANIFEST=$manifestPath"
