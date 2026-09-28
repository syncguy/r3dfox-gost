param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('Prepare','Stage','VerifyAfterRetarget','VerifyPackage')]
  [string]$Mode
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sourceUri = 'https://archive.mozilla.org/pub/firefox/releases/52.9.0esr/firefox-52.9.0esr.win32.sdk.zip'
$sourceZipSha256 = 'c3788c977d19149cc62daf9f4494d08092f836b9e60fa8ef411e05469f4bad4f'
$oldSha1 = '98be17e1d324790a5b206e1ea1cc4e64fbe21240'
$oldSha256 = '2f23182ec6f4889397ac4bf03d62536136c5bdba825c7d2c4ef08c827f3a8a1c'
$oldSize = 2106216
$oldVersion = '9.29.952.3111'

New-Item -ItemType Directory -Force diagnostics | Out-Null

function Write-GitHubEnv([string]$Name, [string]$Value) {
  "$Name=$Value" | Out-File $env:GITHUB_ENV -Append -Encoding utf8
}

function Read-PeContract([string]$Path, [string]$Label, [string]$DiagnosticPrefix) {
  if (-not (Test-Path $Path)) {
    throw "$Label missing: $Path"
  }

  $item = Get-Item $Path
  $sha1 = (Get-FileHash -Algorithm SHA1 $Path).Hash.ToLowerInvariant()
  $sha256 = (Get-FileHash -Algorithm SHA256 $Path).Hash.ToLowerInvariant()
  $headers = @(& dumpbin.exe /nologo /headers $Path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /headers failed for $Label" }
  $imports = @(& dumpbin.exe /nologo /imports $Path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /imports failed for $Label" }
  $exports = @(& dumpbin.exe /nologo /exports $Path 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "dumpbin /exports failed for $Label" }

  $headers | Set-Content -Encoding utf8 "diagnostics\$DiagnosticPrefix-headers.txt"
  $imports | Set-Content -Encoding utf8 "diagnostics\$DiagnosticPrefix-imports.txt"
  $exports | Set-Content -Encoding utf8 "diagnostics\$DiagnosticPrefix-exports.txt"

  if (-not ($headers -match '(?im)^\s*14C machine \(x86\)')) {
    throw "$Label is not PE x86 machine 14C"
  }

  $versionLine = $headers | Where-Object { $_ -match '(?i)subsystem version' } | Select-Object -First 1
  if (-not $versionLine -or $versionLine -notmatch '^\s*([0-9]+)\.([0-9]+)\s+subsystem version') {
    throw "Cannot parse subsystem version for $Label"
  }
  $subsystem = [version]("$([int]$matches[1]).$([int]$matches[2])")

  $exportsText = $exports -join "`n"
  foreach ($name in @('D3DCompile','D3DDisassemble')) {
    if ($exportsText -notmatch ('(?m)\b' + [regex]::Escape($name) + '\b')) {
      throw "$Label missing required export $name"
    }
  }

  return [pscustomobject]@{
    Path = $Path
    Size = $item.Length
    SHA1 = $sha1
    SHA256 = $sha256
    FileVersion = $item.VersionInfo.FileVersion
    OriginalFilename = $item.VersionInfo.OriginalFilename
    Subsystem = $subsystem.ToString()
    ImportsText = ($imports -join "`n")
  }
}

function Assert-Legacy43Contract([object]$Info, [string]$Label) {
  if ([int64]$Info.Size -ne $oldSize) {
    throw "$Label size mismatch: expected=$oldSize actual=$($Info.Size)"
  }
  if ($Info.SHA1 -ne $oldSha1) {
    throw "$Label SHA1 mismatch: expected=$oldSha1 actual=$($Info.SHA1)"
  }
  if ($Info.SHA256 -ne $oldSha256) {
    throw "$Label SHA256 mismatch: expected=$oldSha256 actual=$($Info.SHA256)"
  }
  if ($Info.Subsystem -ne '5.0') {
    throw "$Label subsystem changed: expected=5.0 actual=$($Info.Subsystem)"
  }
  if ($Info.FileVersion -notlike "$oldVersion*") {
    throw "$Label file version mismatch: expected=$oldVersion actual=$($Info.FileVersion)"
  }
  foreach ($pattern in @(
    '(?i)\bapi-ms-win-',
    '(?i)\bext-ms-',
    '(?i)\bKERNELBASE\.dll\b',
    '(?i)\bBCRYPTPRIMITIVES\.dll\b',
    '(?i)\b_except_handler4_common\b',
    '(?i)\bFlsAlloc\b',
    '(?i)\bFlsFree\b',
    '(?i)\bFlsGetValue\b',
    '(?i)\bFlsSetValue\b',
    '(?i)\bInitializeCriticalSectionEx\b'
  )) {
    if ($Info.ImportsText -match $pattern) {
      throw "$Label retains forbidden XP dependency/import pattern: $pattern"
    }
  }
}

function Invoke-ShaderProbe([string[]]$Dlls) {
  $root = Join-Path $env:RUNNER_TEMP ("xp-d3dcompiler-probe-" + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Force $root | Out-Null
  $source = Join-Path $root 'd3dcompile-probe.cpp'
  $exe = Join-Path $root 'd3dcompile-probe.exe'

  @'
#include <windows.h>
#include <d3dcompiler.h>
#include <cstdio>
#include <cstring>

using D3DCompileFn = HRESULT (WINAPI*)(
    LPCVOID, SIZE_T, LPCSTR, const D3D_SHADER_MACRO*, ID3DInclude*,
    LPCSTR, LPCSTR, UINT, UINT, ID3DBlob**, ID3DBlob**);

static int CompileOne(D3DCompileFn fn, const char* source, const char* profile) {
  ID3DBlob* code = nullptr;
  ID3DBlob* errors = nullptr;
  const HRESULT hr = fn(source, std::strlen(source), "smoke.hlsl", nullptr, nullptr,
                        "main", profile, 0, 0, &code, &errors);
  if (FAILED(hr) || !code || code->GetBufferSize() == 0) {
    std::printf("%s compile failed: hr=0x%08lx\n", profile,
                static_cast<unsigned long>(hr));
    if (errors && errors->GetBufferPointer()) {
      std::printf("%s\n", static_cast<const char*>(errors->GetBufferPointer()));
    }
    if (errors) errors->Release();
    if (code) code->Release();
    return 5;
  }
  std::printf("%s PASS: bytes=%zu\n", profile, code->GetBufferSize());
  if (errors) errors->Release();
  code->Release();
  return 0;
}

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

  const char vs[] =
      "float4 main(float4 pos : POSITION) : POSITION { return pos; }";
  const char ps[] =
      "float4 main() : COLOR0 { return float4(1,0,0,1); }";

  int rc = CompileOne(fn, vs, "vs_3_0");
  if (rc == 0) rc = CompileOne(fn, ps, "ps_3_0");
  FreeLibrary(mod);
  return rc;
}
'@ | Set-Content -Encoding ascii $source

  & cl.exe /nologo /EHsc /W4 /WX "/Fe:$exe" $source
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to build D3DCompile probe: $LASTEXITCODE"
  }

  foreach ($dll in $Dlls) {
    & $exe $dll
    if ($LASTEXITCODE -ne 0) {
      throw "D3DCompile SM3 probe failed for $dll with exit $LASTEXITCODE"
    }
  }
}

switch ($Mode) {
  'Prepare' {
    $root = Join-Path $env:RUNNER_TEMP 'xp-d3dcompiler43-source'
    $zip = Join-Path $root 'firefox-52.9.0esr.win32.sdk.zip'
    $extract = Join-Path $root 'sdk'
    if (Test-Path $root) { Remove-Item -Recurse -Force $root }
    New-Item -ItemType Directory -Force $root | Out-Null

    Invoke-WebRequest -Uri $sourceUri -OutFile $zip
    $actualZipSha256 = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
    if ($actualZipSha256 -ne $sourceZipSha256) {
      throw "Firefox SDK ZIP SHA256 mismatch: expected=$sourceZipSha256 actual=$actualZipSha256"
    }

    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $matches = @(Get-ChildItem -LiteralPath $extract -Recurse -File | Where-Object { $_.Name -ieq 'D3DCompiler_43.dll' })
    if ($matches.Count -ne 1) {
      throw "Expected exactly one D3DCompiler_43.dll in Firefox SDK; found $($matches.Count)"
    }

    $prepared = Join-Path $root 'd3dcompiler_old.dll'
    Copy-Item -Force $matches[0].FullName $prepared
    $info = Read-PeContract $prepared 'Pinned D3DCompiler_43 fallback' 'd3dcompiler43-source'
    Assert-Legacy43Contract $info 'Pinned D3DCompiler_43 fallback'

    Write-GitHubEnv 'XP_D3DCOMPILER_OLD_SOURCE' $prepared
    Write-GitHubEnv 'XP_D3DCOMPILER_OLD_SHA256' $oldSha256
    Write-GitHubEnv 'XP_D3DCOMPILER_SOURCE_ZIP_SHA256' $sourceZipSha256
    Write-GitHubEnv 'XP_D3DCOMPILER_SOURCE_URI' $sourceUri

    @(
      "source_uri=$sourceUri",
      "source_zip_sha256=$sourceZipSha256",
      "d3dcompiler_old.dll|size=$($info.Size)",
      "d3dcompiler_old.dll|sha1=$($info.SHA1)",
      "d3dcompiler_old.dll|sha256=$($info.SHA256)",
      "d3dcompiler_old.dll|subsystem=$($info.Subsystem)",
      "d3dcompiler_old.dll|file_version=$($info.FileVersion)",
      "d3dcompiler_old.dll|original_filename=$($info.OriginalFilename)"
    ) | Set-Content -Encoding utf8 diagnostics\d3dcompiler-fallback-provenance.txt
  }

  'Stage' {
    if (-not $env:XP_D3DCOMPILER_OLD_SOURCE -or -not (Test-Path $env:XP_D3DCOMPILER_OLD_SOURCE)) {
      throw 'Prepared D3DCompiler_43 fallback source is unavailable'
    }

    $bin = Join-Path $env:OBJDIR 'dist\bin'
    $modern = Join-Path $bin 'd3dcompiler_47.dll'
    $legacy = Join-Path $bin 'd3dcompiler_old.dll'
    if (-not (Test-Path $modern)) {
      throw "Build-produced d3dcompiler_47.dll missing: $modern"
    }

    Copy-Item -Force $env:XP_D3DCOMPILER_OLD_SOURCE $legacy

    $modernInfo = Read-PeContract $modern 'Build-produced d3dcompiler_47.dll' 'd3dcompiler47-staged'
    $legacyInfo = Read-PeContract $legacy 'Staged d3dcompiler_old.dll' 'd3dcompiler-old-staged'
    Assert-Legacy43Contract $legacyInfo 'Staged d3dcompiler_old.dll'

    Write-GitHubEnv 'XP_D3DCOMPILER47_STAGED_SHA256' $modernInfo.SHA256
    Write-GitHubEnv 'XP_D3DCOMPILER47_STAGED_SUBSYSTEM' $modernInfo.Subsystem
    Write-GitHubEnv 'XP_D3DCOMPILER_OLD_STAGED_SHA256' $legacyInfo.SHA256

    @(
      "d3dcompiler_47.dll|size=$($modernInfo.Size)|sha1=$($modernInfo.SHA1)|sha256=$($modernInfo.SHA256)|subsystem=$($modernInfo.Subsystem)|file_version=$($modernInfo.FileVersion)",
      "d3dcompiler_old.dll|size=$($legacyInfo.Size)|sha1=$($legacyInfo.SHA1)|sha256=$($legacyInfo.SHA256)|subsystem=$($legacyInfo.Subsystem)|file_version=$($legacyInfo.FileVersion)"
    ) | Set-Content -Encoding utf8 diagnostics\d3dcompiler-staged-contract.txt
  }

  'VerifyAfterRetarget' {
    if (-not $env:XP_D3DCOMPILER47_STAGED_SHA256 -or -not $env:XP_D3DCOMPILER_OLD_STAGED_SHA256) {
      throw 'Staged D3DCompiler hashes were not recorded before PE retarget'
    }

    $bin = Join-Path $env:OBJDIR 'dist\bin'
    $modern = Join-Path $bin 'd3dcompiler_47.dll'
    $legacy = Join-Path $bin 'd3dcompiler_old.dll'
    $modernInfo = Read-PeContract $modern 'Post-retarget d3dcompiler_47.dll' 'd3dcompiler47-post-retarget'
    $legacyInfo = Read-PeContract $legacy 'Post-retarget d3dcompiler_old.dll' 'd3dcompiler-old-post-retarget'
    Assert-Legacy43Contract $legacyInfo 'Post-retarget d3dcompiler_old.dll'

    if ($modernInfo.SHA256 -ne $env:XP_D3DCOMPILER47_STAGED_SHA256) {
      throw "d3dcompiler_47.dll changed during PE retarget: staged=$env:XP_D3DCOMPILER47_STAGED_SHA256 actual=$($modernInfo.SHA256)"
    }
    if ($legacyInfo.SHA256 -ne $env:XP_D3DCOMPILER_OLD_STAGED_SHA256) {
      throw "d3dcompiler_old.dll changed during PE retarget: staged=$env:XP_D3DCOMPILER_OLD_STAGED_SHA256 actual=$($legacyInfo.SHA256)"
    }
    if ($modernInfo.Subsystem -ne $env:XP_D3DCOMPILER47_STAGED_SUBSYSTEM) {
      throw "d3dcompiler_47.dll subsystem changed during PE retarget: staged=$env:XP_D3DCOMPILER47_STAGED_SUBSYSTEM actual=$($modernInfo.Subsystem)"
    }

    @(
      "d3dcompiler_47.dll|sha256=$($modernInfo.SHA256)|subsystem=$($modernInfo.Subsystem)|unchanged=true",
      "d3dcompiler_old.dll|sha256=$($legacyInfo.SHA256)|subsystem=$($legacyInfo.Subsystem)|unchanged=true"
    ) | Set-Content -Encoding utf8 diagnostics\d3dcompiler-post-retarget-contract.txt
  }

  'VerifyPackage' {
    if (-not $env:XP_PORTABLE_ARCHIVE -or -not (Test-Path $env:XP_PORTABLE_ARCHIVE)) {
      throw 'Portable archive is unavailable for D3DCompiler package gate'
    }
    if (-not $env:XP_D3DCOMPILER47_STAGED_SHA256 -or -not $env:XP_D3DCOMPILER_OLD_STAGED_SHA256) {
      throw 'Staged D3DCompiler hashes were not recorded'
    }

    $extract = Join-Path $env:RUNNER_TEMP ("xp-package-d3dcompiler-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $extract | Out-Null
    & 7z.exe x $env:XP_PORTABLE_ARCHIVE "-o$extract" -y | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw 'Cannot extract portable archive for D3DCompiler gate'
    }

    $modernFound = @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter 'd3dcompiler_47.dll')
    $legacyFound = @(Get-ChildItem -LiteralPath $extract -Recurse -File -Filter 'd3dcompiler_old.dll')
    if ($modernFound.Count -ne 1) {
      throw "Portable package must contain exactly one d3dcompiler_47.dll; found $($modernFound.Count)"
    }
    if ($legacyFound.Count -ne 1) {
      throw "Portable package must contain exactly one d3dcompiler_old.dll; found $($legacyFound.Count)"
    }

    $modernInfo = Read-PeContract $modernFound[0].FullName 'Packaged d3dcompiler_47.dll' 'd3dcompiler47-packaged'
    $legacyInfo = Read-PeContract $legacyFound[0].FullName 'Packaged d3dcompiler_old.dll' 'd3dcompiler-old-packaged'
    Assert-Legacy43Contract $legacyInfo 'Packaged d3dcompiler_old.dll'

    if ($modernInfo.SHA256 -ne $env:XP_D3DCOMPILER47_STAGED_SHA256) {
      throw "Packaged d3dcompiler_47.dll hash mismatch: staged=$env:XP_D3DCOMPILER47_STAGED_SHA256 actual=$($modernInfo.SHA256)"
    }
    if ($legacyInfo.SHA256 -ne $env:XP_D3DCOMPILER_OLD_STAGED_SHA256 -or $legacyInfo.SHA256 -ne $oldSha256) {
      throw "Packaged d3dcompiler_old.dll hash mismatch: staged=$env:XP_D3DCOMPILER_OLD_STAGED_SHA256 expected=$oldSha256 actual=$($legacyInfo.SHA256)"
    }

    Invoke-ShaderProbe @($modernFound[0].FullName, $legacyFound[0].FullName)

    @(
      "archive=$env:XP_PORTABLE_ARCHIVE",
      "d3dcompiler_47.dll|size=$($modernInfo.Size)|sha1=$($modernInfo.SHA1)|sha256=$($modernInfo.SHA256)|subsystem=$($modernInfo.Subsystem)|file_version=$($modernInfo.FileVersion)",
      "d3dcompiler_old.dll|size=$($legacyInfo.Size)|sha1=$($legacyInfo.SHA1)|sha256=$($legacyInfo.SHA256)|subsystem=$($legacyInfo.Subsystem)|file_version=$($legacyInfo.FileVersion)",
      'functional_smoke=D3DCompile(vs_3_0+ps_3_0):PASS:both'
    ) | Set-Content -Encoding utf8 diagnostics\packaged-d3dcompiler-contract.txt
  }
}
