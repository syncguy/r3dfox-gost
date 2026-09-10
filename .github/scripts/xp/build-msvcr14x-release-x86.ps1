$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Force diagnostics | Out-Null
$root = Join-Path $env:RUNNER_TEMP 'msvcr14x'
if (Test-Path $root) {
  Remove-Item -Recurse -Force $root
}

git init $root
git -C $root remote add origin $env:MSVCR14X_REPO
git -C $root fetch --depth=1 origin $env:MSVCR14X_SHA
git -C $root checkout --detach FETCH_HEAD
git -C $root submodule update --init --recursive --depth 1

$actual = (git -C $root rev-parse HEAD).Trim()
if ($actual -ne $env:MSVCR14X_SHA) {
  throw "Unexpected msvcr14x commit: $actual"
}

& msbuild.exe (Join-Path $root 'msvcr14x.sln') /m /t:Build '/p:Configuration=Release;Platform=x86' -r "/bl:$env:GITHUB_WORKSPACE\diagnostics\msvcr14x-release-x86.binlog"
if ($LASTEXITCODE -ne 0) {
  throw "msvcr14x build failed: $LASTEXITCODE"
}

$required = @('ucrtbase.dll','ucrt.lib','vcruntime.lib','msvcprt.lib','msvcp140.dll')
$release = $null
$candidateDirs = @(Get-ChildItem -Path $root -Recurse -File -Filter 'ucrtbase.dll' |
  ForEach-Object { $_.Directory.FullName } | Sort-Object -Unique)
foreach ($candidate in $candidateDirs) {
  $missing = @($required | Where-Object { -not (Test-Path (Join-Path $candidate $_)) })
  if ($missing.Count -gt 0) {
    continue
  }

  $headers = (& dumpbin.exe /nologo /headers (Join-Path $candidate 'ucrtbase.dll') 2>&1 | Out-String)
  if ($LASTEXITCODE -eq 0 -and $headers -match '(?im)^\s*14C machine \(x86\)') {
    $release = $candidate
    break
  }
}

if (-not $release) {
  throw 'Cannot locate complete x86 msvcr14x Release output'
}

"MSVCR14X_RELEASE=$release" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"LIB=$release;$env:LIB" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
"LDFLAGS=-LIBPATH:$release" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
Get-ChildItem -LiteralPath $release -File | Sort-Object Name |
  Select-Object Name,Length | Format-Table -AutoSize | Out-String -Width 240 |
  Set-Content -Encoding utf8 diagnostics\msvcr14x-release-files.txt