param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('Browser', 'Driver')]
  [string]$Mode
)

$ErrorActionPreference = 'Stop'

if ($Mode -eq 'Browser') {
  if ([string]::IsNullOrWhiteSpace($env:GH_TOKEN)) { throw "GH_TOKEN is required to read the pinned artifact" }
  $root = Join-Path $env:RUNNER_TEMP 'e029-prebuilt'
  New-Item -ItemType Directory -Path $root -Force | Out-Null
  $outerZip = Join-Path $root 'xp-artifact-12135779653.zip'
  $headers = @{
    Authorization = "Bearer $env:GH_TOKEN"
    Accept = 'application/vnd.github+json'
    'X-GitHub-Api-Version' = '2022-11-28'
  }
  Invoke-WebRequest -Uri 'https://api.github.com/repos/syncguy/r3dfox-gost/actions/artifacts/12135779653/zip' -Headers $headers -OutFile $outerZip -MaximumRedirection 5
  $outerHash = (Get-FileHash -LiteralPath $outerZip -Algorithm SHA256).Hash.ToLowerInvariant()
  $expected = '0d6cb96278b661ea927853f1d2cf399cff7504e645192a335909ebaf766af6a0'
  if ($outerHash -ne $expected) { throw "Pinned CI artifact ZIP SHA-256 mismatch: expected $expected, got $outerHash" }

  $outerDir = Join-Path $root 'artifact'
  Expand-Archive -LiteralPath $outerZip -DestinationPath $outerDir -Force
  $inner = @(Get-ChildItem -Path $outerDir -Filter 'r3dfox-v153.0.3.win32.zip' -File -Recurse)
  if ($inner.Count -ne 1) { throw "Expected exactly one portable ZIP; got $($inner.Count)" }
  $browserDir = Join-Path $root 'browser'
  Expand-Archive -LiteralPath $inner[0].FullName -DestinationPath $browserDir -Force
  $exe = @(Get-ChildItem -Path $browserDir -Filter 'r3dfox.exe' -File -Recurse)
  if ($exe.Count -ne 1) { throw "Expected exactly one r3dfox.exe; got $($exe.Count)" }
  $binDir = $exe[0].DirectoryName
  $expectedMembers = @{
    'r3dfox.exe' = 'f78b3444960d5efbffd7fa897addc7315758b7a7'
    'xul.dll' = 'bd70d93d68e10bae8c1307f10e22dac1378e0dc6'
  }
  foreach ($name in $expectedMembers.Keys) {
    $file = Join-Path $binDir $name
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing verified PE: $name" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA1).Hash.ToLowerInvariant()
    if ($actual -ne $expectedMembers[$name]) { throw "Browser member $name does not match tested artifact" }
  }
  "E029_BROWSER_EXE=$($exe[0].FullName)" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
  Write-Host 'Prebuilt browser verified: original XP run 39119372526, job 117651638583, artifact 12135779653.'
  Write-Host 'Source-under-test: 67dc557067835bb8175f38830887e96afb75cf07 (not the workflow controller SHA).'
  exit 0
}

if ($Mode -eq 'Driver') {
  python -m pip install --disable-pip-version-check 'selenium==4.25.0'
  if ($LASTEXITCODE -ne 0) { throw "Pinned Selenium install failed" }
  $root = Join-Path $env:RUNNER_TEMP 'e029-driver'
  New-Item -ItemType Directory -Path $root -Force | Out-Null
  $zip = Join-Path $root 'geckodriver-v0.36.0-win64.zip'
  Invoke-WebRequest -Uri 'https://github.com/mozilla/geckodriver/releases/download/v0.36.0/geckodriver-v0.36.0-win64.zip' -OutFile $zip
  $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
  $expected = '4c23d54681d431b42575a66c3c89202a40add3ef45e64b94acac620a89774ad2'
  if ($actual -ne $expected) { throw "Pinned geckodriver ZIP SHA-256 mismatch" }
  Expand-Archive -LiteralPath $zip -DestinationPath $root -Force
  $driver = Join-Path $root 'geckodriver.exe'
  if (-not (Test-Path -LiteralPath $driver -PathType Leaf)) { throw "geckodriver.exe missing" }
  "E029_GECKODRIVER=$driver" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
  Write-Host 'Pinned geckodriver 0.36.0 verified by SHA-256.'
  exit 0
}
