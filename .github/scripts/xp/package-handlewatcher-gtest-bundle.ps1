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
foreach ($name in @('r3dfox.exe', 'xul.dll')) {
    $candidate = Join-Path $distBin $name
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Required linked executable/module missing: $name"
    }
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
    schema = 'xp-handlewatcher-gtest-bundle-v1'
    source_under_test_sha = $actualSourceSha
    controller_commit_sha = $env:GITHUB_SHA
    workflow = $env:GITHUB_WORKFLOW
    run_id = $env:GITHUB_RUN_ID
    run_attempt = $env:GITHUB_RUN_ATTEMPT
    target = 'Windows XP SP3 x86 (i686)'
    evidence_scope = 'hosted compile and link; tests not executed; physical XP not established'
    files = $entries
}
$manifestPath = Join-Path $distBin 'xp-gtest-build-manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Host "GTEST_BUNDLE_SOURCE_SHA=$actualSourceSha"
Write-Host "GTEST_BUNDLE_FILE_COUNT=$($entries.Count)"
Write-Host "GTEST_BUNDLE_MANIFEST=$manifestPath"

$symbolsDir = Join-Path $env:RUNNER_TEMP 'xp-handlewatcher-gtest-symbols'
New-Item -ItemType Directory -Path $symbolsDir -Force | Out-Null
$symbolEntries = @()
$symbolPaths = @(
    (Join-Path $resolvedObjDir 'toolkit\library\gtest\xul.pdb'),
    (Join-Path $resolvedObjDir 'browser\app\r3dfox.pdb')
)
foreach ($candidate in $symbolPaths) {
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        continue
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
