$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$uri = 'https://archive.mozilla.org/pub/firefox/releases/52.9.0esr/firefox-52.9.0esr.win32.sdk.zip'
$expected43 = '2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c'
$expected47 = '3a010ee7186086a7f77b6aec3644e05f8495a84895b90572cab8d4f14efa088e'

$root = Join-Path $env:RUNNER_TEMP 'firefox52-d3dcompiler-pair'
$zip = Join-Path $root 'firefox-52.9.0esr.win32.sdk.zip'
$extract = Join-Path $root 'sdk'
$out = Join-Path $env:GITHUB_WORKSPACE 'd3dcompiler-pair'
$diag = Join-Path $env:GITHUB_WORKSPACE 'd3dcompiler-pair-diagnostics'

foreach ($dir in @($root, $out, $diag)) {
  if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
  New-Item -ItemType Directory -Force $dir | Out-Null
}

Invoke-WebRequest -Uri $uri -OutFile $zip
$zipSha256 = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force

function Find-ExactlyOne([string]$name) {
  $matches = @(Get-ChildItem -Path $extract -Recurse -File | Where-Object { $_.Name -ieq $name })
  if ($matches.Count -ne 1) {
    throw "Expected exactly one $name in Firefox SDK; found $($matches.Count)"
  }
  return $matches[0].FullName
}

$src43 = Find-ExactlyOne 'D3DCompiler_43.dll'
$src47 = Find-ExactlyOne 'd3dcompiler_47.dll'
$dst43 = Join-Path $out 'D3DCompiler_43.dll'
$dst47 = Join-Path $out 'd3dcompiler_47.dll'
$dstOld = Join-Path $out 'd3dcompiler_old.dll'
Copy-Item -Force $src43 $dst43
Copy-Item -Force $src47 $dst47
Copy-Item -Force $src43 $dstOld

function Verify-Dll([string]$path, [string]$expectedSha256, [string]$label, [version]$maxSubsystem, [version]$minSubsystem) {
  $item = Get-Item $path
  $sha1 = (Get-FileHash -Algorithm SHA1 $path).Hash.ToLowerInvariant()
  $sha256 = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLowerInvariant()
  if ($sha256 -ne $expectedSha256) {
    throw "$label SHA256 mismatch: expected=$expectedSha256 actual=$sha256"
  }

  $headers = @(& dumpbin.exe /nologo /headers $path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed for $label" }
  $imports = @(& dumpbin.exe /nologo /imports $path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /imports failed for $label" }
  $exports = @(& dumpbin.exe /nologo /exports $path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /exports failed for $label" }

  $headers | Set-Content -Encoding utf8 (Join-Path $diag "$label-headers.txt")
  $imports | Set-Content -Encoding utf8 (Join-Path $diag "$label-imports.txt")
  $exports | Set-Content -Encoding utf8 (Join-Path $diag "$label-exports.txt")

  if (-not ($headers -match '(?im)^\s*14C machine \(x86\)')) {
    throw "$label is not PE x86 machine 14C"
  }
  $versionLine = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
  if (-not $versionLine -or $versionLine -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') {
    throw "Cannot parse subsystem version for $label"
  }
  $subsystem = [version]("$([int]$matches[1]).$([int]$matches[2])")
  if ($subsystem -gt $maxSubsystem -or $subsystem -lt $minSubsystem) {
    throw "$label subsystem $subsystem outside expected range $minSubsystem..$maxSubsystem"
  }

  $exportsText = $exports -join "`n"
  foreach ($name in @('D3DCompile','D3DDisassemble')) {
    if ($exportsText -notmatch ('(?m)\b' + [regex]::Escape($name) + '\b')) {
      throw "$label missing required export $name"
    }
  }

  return [pscustomobject]@{
    Label = $label
    Path = $path
    Size = $item.Length
    SHA1 = $sha1
    SHA256 = $sha256
    FileVersion = $item.VersionInfo.FileVersion
    ProductVersion = $item.VersionInfo.ProductVersion
    OriginalFilename = $item.VersionInfo.OriginalFilename
    Subsystem = $subsystem.ToString()
  }
}

$meta43 = Verify-Dll $dst43 $expected43 'd3dcompiler43' ([version]'5.1') ([version]'0.0')
$meta47 = Verify-Dll $dst47 $expected47 'd3dcompiler47' ([version]'6.0') ([version]'6.0')

$probe = Join-Path $root 'd3dcompile-probe.cpp'
@'
#include <windows.h>
#include <d3dcompiler.h>
#include <cstdio>

using D3DCompileFn = HRESULT (WINAPI*)(
    LPCVOID, SIZE_T, LPCSTR, const D3D_SHADER_MACRO*, ID3DInclude*,
    LPCSTR, LPCSTR, UINT, UINT, ID3DBlob**, ID3DBlob**);

int wmain(int argc, wchar_t** argv) {
  if (argc != 2) return 2;
  HMODULE mod = LoadLibraryW(argv[1]);
  if (!mod) {
    std::printf("LoadLibrary failed: %lu\n", GetLastError());
    return 3;
  }
  auto fn = reinterpret_cast<D3DCompileFn>(GetProcAddress(mod, "D3DCompile"));
  if (!fn) {
    std::printf("GetProcAddress(D3DCompile) failed: %lu\n", GetLastError());
    FreeLibrary(mod);
    return 4;
  }
  const char src[] = "float4 main() : COLOR0 { return float4(1,0,0,1); }";
  ID3DBlob* code = nullptr;
  ID3DBlob* errors = nullptr;
  const HRESULT hr = fn(src, sizeof(src) - 1, "smoke.hlsl", nullptr, nullptr,
                        "main", "ps_3_0", 0, 0, &code, &errors);
  if (FAILED(hr) || !code || code->GetBufferSize() == 0) {
    std::printf("D3DCompile failed: hr=0x%08lx\n", static_cast<unsigned long>(hr));
    if (errors && errors->GetBufferPointer()) {
      std::printf("%s\n", static_cast<const char*>(errors->GetBufferPointer()));
    }
    if (errors) errors->Release();
    if (code) code->Release();
    FreeLibrary(mod);
    return 5;
  }
  std::printf("D3DCompile PASS: bytes=%zu\n", code->GetBufferSize());
  if (errors) errors->Release();
  code->Release();
  FreeLibrary(mod);
  return 0;
}
'@ | Set-Content -Encoding ascii $probe

$probeExe = Join-Path $root 'd3dcompile-probe.exe'
& cl.exe /nologo /EHsc /W4 /WX "/Fe:$probeExe" $probe
if ($LASTEXITCODE -ne 0) { throw "Failed to build D3DCompile probe: $LASTEXITCODE" }

foreach ($dll in @($dst43, $dst47)) {
  & $probeExe $dll
  if ($LASTEXITCODE -ne 0) { throw "D3DCompile functional smoke failed for $dll with exit $LASTEXITCODE" }
}

$aliasHash = (Get-FileHash -Algorithm SHA256 $dstOld).Hash.ToLowerInvariant()
if ($aliasHash -ne $expected43) { throw "d3dcompiler_old.dll alias hash mismatch: $aliasHash" }

@(
  "source_uri=$uri",
  "source_zip_sha256=$zipSha256",
  "D3DCompiler_43.dll|size=$($meta43.Size)|sha1=$($meta43.SHA1)|sha256=$($meta43.SHA256)|subsystem=$($meta43.Subsystem)|file_version=$($meta43.FileVersion)|original_filename=$($meta43.OriginalFilename)",
  "d3dcompiler_47.dll|size=$($meta47.Size)|sha1=$($meta47.SHA1)|sha256=$($meta47.SHA256)|subsystem=$($meta47.Subsystem)|file_version=$($meta47.FileVersion)|original_filename=$($meta47.OriginalFilename)",
  "d3dcompiler_old.dll|sha256=$aliasHash|source=D3DCompiler_43.dll",
  "functional_smoke=D3DCompile(ps_3_0):PASS:both"
) | Set-Content -Encoding utf8 (Join-Path $out 'provenance.txt')

Copy-Item -Force (Join-Path $out 'provenance.txt') (Join-Path $diag 'provenance.txt')
