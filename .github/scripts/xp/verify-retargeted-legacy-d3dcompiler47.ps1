$ErrorActionPreference = 'Stop'

$dll = Join-Path $env:OBJDIR 'dist\bin\d3dcompiler_47.dll'
if (-not (Test-Path $dll)) { throw "Retargeted D3DCompiler_47 missing: $dll" }

$version = (Get-Item $dll).VersionInfo.FileVersion
if ($version -notlike '10.0.14393.33*') { throw "Unexpected retargeted D3DCompiler_47 version: $version" }

$headers = @(& dumpbin.exe /nologo /headers $dll 2>&1)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /headers failed for retargeted D3DCompiler_47' }
$subsystem = $headers | Where-Object { $_ -match '(?i)^\s*5\.01\s+subsystem version' } | Select-Object -First 1
if (-not $subsystem) { throw 'Retargeted D3DCompiler_47 is not subsystem 5.01' }

$imports = (& dumpbin.exe /nologo /imports $dll 2>&1 | Out-String)
if ($LASTEXITCODE -ne 0) { throw 'dumpbin /imports failed for retargeted D3DCompiler_47' }
foreach ($forbidden in @('FlsAlloc','FlsFree','FlsGetValue','FlsSetValue','InitializeCriticalSectionEx')) {
  if ($imports -match ('(?m)\b' + [regex]::Escape($forbidden) + '\b')) {
    throw "Legacy D3DCompiler_47 still imports $forbidden"
  }
}

$hash = (Get-FileHash -Algorithm SHA256 $dll).Hash.ToLowerInvariant()
"LEGACY_D3DCOMPILER47_RETARGETED_SHA256=$hash" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
@(
  "retargeted_sha256=$hash",
  "retargeted_file_version=$version",
  'retargeted_subsystem=5.01'
) | Add-Content -Encoding utf8 diagnostics\legacy-d3dcompiler47.txt
