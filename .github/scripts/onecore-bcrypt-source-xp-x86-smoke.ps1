param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$WorkRoot
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$sourceRepo = 'https://github.com/shorthorn-project/One-Core-API-Source.git'
$sourceCommit = '9eb3c31de9460c1ccce3f6a10c9c4a704f032514'
$rosbeUrl = 'https://sourceforge.net/projects/reactos/files/RosBE-Windows/i386/2.1.6/RosBE-2.1.6.exe/download'

$src = Join-Path $WorkRoot 'onecore-source'
$out = Join-Path $WorkRoot 'onecore-build'
$rosbeInstaller = Join-Path $WorkRoot 'RosBE-2.1.6.exe'
$rosbe = Join-Path $WorkRoot 'RosBE'
$runtime = Join-Path $WorkRoot 'runtime'
$diag = Join-Path $WorkRoot 'diagnostics'
New-Item -ItemType Directory -Force -Path $WorkRoot,$out,$runtime,$diag | Out-Null

& git clone --filter=blob:none --no-tags $sourceRepo $src
if ($LASTEXITCODE -ne 0) { throw 'One-Core source clone failed' }
& git -C $src checkout --detach $sourceCommit
if ($LASTEXITCODE -ne 0) { throw 'One-Core source checkout failed' }
$actual = (& git -C $src rev-parse HEAD).Trim()
if ($actual -ne $sourceCommit) { throw "Unexpected One-Core source SHA: $actual" }
$actual | Set-Content -Encoding ascii (Join-Path $diag 'onecore-source-sha.txt')

$widlHeader = Join-Path $src 'sdk\tools\widl\header.c'
$widlText = Get-Content -Raw $widlHeader
$oldCall = 'format_namespace(type->namespace, "", "_", type->name, NULL)'
$newCall = 'format_namespace(type->namespace, "", "_", type->name)'
if (-not $widlText.Contains($oldCall)) { throw 'Expected pinned One-Core WIDL mismatch not found' }
$widlText = $widlText.Replace($oldCall, $newCall)
Set-Content -Encoding ascii -Path $widlHeader -Value $widlText

$mbedtlsSources = @(
  '_reactos_strsafe_wrapper.c',
  'aes.c',
  'aesni.c',
  'arc4.c',
  'asn1parse.c',
  'asn1write.c',
  'bignum.c',
  'blowfish.c',
  'camellia.c',
  'ccm.c',
  'cipher.c',
  'cipher_wrap.c',
  'ctr_drbg.c',
  'des.c',
  'dhm.c',
  'ecdh.c',
  'ecdsa.c',
  'ecp.c',
  'ecp_curves.c',
  'entropy.c',
  'entropy_poll.c',
  'gcm.c',
  'hmac_drbg.c',
  'md5.c',
  'md.c',
  'md_wrap.c',
  'oid.c',
  'padlock.c',
  'pk.c',
  'pkcs12.c',
  'pkcs5.c',
  'pkparse.c',
  'pk_wrap.c',
  'platform.c',
  'ripemd160.c',
  'rsa.c',
  'rsa_internal.c',
  'sha1.c',
  'sha256.c',
  'sha512.c',
  'ssl_ciphersuites.c',
  'ssl_cli.c',
  'ssl_tls.c',
  'timing.c',
  'x509.c',
  'x509_crt.c'
)
$mbedtlsDir = Join-Path $src 'dll\3rdparty\mbedtls'
foreach ($name in $mbedtlsSources) {
  if (-not (Test-Path (Join-Path $mbedtlsDir $name))) { throw "Pinned mbedtls source missing: $name" }
}
$mbedtlsSources | Set-Content -Encoding ascii (Join-Path $diag 'embedded-mbedtls-sources.txt')

$bcryptCmake = Join-Path $src 'dll\win32\bcrypt\CMakeLists.txt'
$bcryptText = Get-Content -Raw $bcryptCmake
$moduleTypeLine = 'set_module_type(bcrypt win32dll)'
$importLine = 'add_importlibs(bcrypt mbedtls advapi32 msvcrt kernel32 ntdll)'
if (-not $bcryptText.Contains($moduleTypeLine)) { throw 'Expected pinned bcrypt module type line not found' }
if ($bcryptText.IndexOf($moduleTypeLine) -ne $bcryptText.LastIndexOf($moduleTypeLine)) { throw 'Pinned bcrypt module type line is not unique' }
if (-not $bcryptText.Contains($importLine)) { throw 'Expected pinned bcrypt mbedtls import line not found' }
if ($bcryptText.IndexOf($importLine) -ne $bcryptText.LastIndexOf($importLine)) { throw 'Pinned bcrypt mbedtls import line is not unique' }

$embedLines = @('target_sources(bcrypt PRIVATE')
foreach ($name in $mbedtlsSources) {
  $embedLines += ('    ${REACTOS_SOURCE_DIR}/dll/3rdparty/mbedtls/' + $name)
}
$embedLines += @(
  ')',
  'target_include_directories(bcrypt PRIVATE',
  '    ${REACTOS_SOURCE_DIR}/sdk/include/reactos/libs',
  '    ${REACTOS_SOURCE_DIR}/sdk/include/reactos/zlib',
  ')',
  'target_compile_definitions(bcrypt PRIVATE MINGW_HAS_SECURE_API CRTDLL)',
  'if(NOT MSVC)',
  '    target_compile_options(bcrypt PRIVATE -Wno-pointer-sign -Wno-unused-function)',
  'elseif(USE_CLANG_CL)',
  '    target_compile_options(bcrypt PRIVATE -Wno-tautological-constant-compare)',
  'endif()'
)
$embedBlock = $embedLines -join [Environment]::NewLine
$bcryptText = $bcryptText.Replace($moduleTypeLine, ($moduleTypeLine + [Environment]::NewLine + $embedBlock))
$bcryptText = $bcryptText.Replace($importLine, 'add_importlibs(bcrypt advapi32 msvcrt kernel32 ntdll)')
Set-Content -Encoding ascii -Path $bcryptCmake -Value $bcryptText

@"
source_sha=$sourceCommit
baseline_project_sha=fdd4d4dac5a7d9611ec71975ae800437f45c47dd
widl_fix=remove trailing NULL from one mismatched format_namespace host-tool call
bcrypt_implementation_modified=no
mbedtls_implementation_modified=no
mbedtls_cmake_modified=no
linkage_change=compile the pinned active mbedtls C modules directly as private sources of bcrypt.dll and remove only the mbedtls import-library dependency
runtime_goal=bcrypt.dll only; no mbedtls.dll dependency
embedded_source_count=$($mbedtlsSources.Count)
"@ | Set-Content -Encoding ascii (Join-Path $diag 'onecore-source-build-adjustments.txt')
& git -C $src diff -- sdk/tools/widl/header.c dll/win32/bcrypt/CMakeLists.txt | Set-Content -Encoding utf8 (Join-Path $diag 'onecore-source-build-adjustments.diff')

& curl.exe -L --fail --retry 3 -o $rosbeInstaller $rosbeUrl
if ($LASTEXITCODE -ne 0) { throw 'RosBE download failed' }
$rosbeHash = (Get-FileHash $rosbeInstaller -Algorithm SHA256).Hash.ToLowerInvariant()
"url=$rosbeUrl`nsha256=$rosbeHash" | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-provenance.txt')

New-Item -ItemType Directory -Force -Path $rosbe | Out-Null
$install = Start-Process -FilePath $rosbeInstaller -ArgumentList '/S',("/D=$rosbe") -Wait -PassThru
"exit_code=$($install.ExitCode)`nrequested_dir=$rosbe" | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-install.txt')
if ($install.ExitCode -ne 0) { throw "RosBE installer failed with $($install.ExitCode)" }

$roots = @($rosbe,(Join-Path $env:SystemDrive 'RosBE'),(Join-Path $env:SystemDrive 'RosBE-2.1.6'))
if ($env:ProgramFiles) { $roots += (Join-Path $env:ProgramFiles 'RosBE') }
if (${env:ProgramFiles(x86)}) { $roots += (Join-Path ${env:ProgramFiles(x86)} 'RosBE') }
$roots += @(Get-ChildItem ($env:SystemDrive + '\') -Directory -Filter 'RosBE*' -ErrorAction SilentlyContinue | ForEach-Object FullName)
$roots = @($roots | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique)
$roots | Set-Content -Encoding utf8 (Join-Path $diag 'rosbe-search-roots.txt')
$rosbeCmd = $null
foreach ($root in $roots) {
  $candidate = Get-ChildItem $root -Recurse -Filter RosBE.cmd -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($candidate) { $rosbeCmd = $candidate; break }
}
if (-not $rosbeCmd) { throw 'RosBE.cmd not found after RosBE 2.1.6 install' }
$rosbeCmd.FullName | Set-Content -Encoding ascii (Join-Path $diag 'rosbe-command.txt')

$buildCmd = Join-Path $WorkRoot 'build-onecore-bcrypt.cmd'
@"
@echo on
call "$($rosbeCmd.FullName)"
if errorlevel 1 exit /b %errorlevel%
set "PATH=%PATH:C:\mingw64\bin;=%"
set "PATH=%PATH:;C:\mingw64\bin=%"
where cc
where gcc
where cmake
cd /d "$out"
call "$src\configure.cmd" -DENABLE_ROSTESTS=0
if errorlevel 1 exit /b %errorlevel%
ninja bcrypt
exit /b %errorlevel%
"@ | Set-Content -Encoding ascii $buildCmd

$oldEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & cmd.exe /d /c $buildCmd *>&1 | Tee-Object -FilePath (Join-Path $diag 'build.log')
  $buildExit = $LASTEXITCODE
} finally { $ErrorActionPreference = $oldEap }
"exit_code=$buildExit" | Set-Content -Encoding ascii (Join-Path $diag 'build-exit-code.txt')
if ($buildExit -ne 0) { throw "One-Core bcrypt build failed with $buildExit" }

$bcryptItems = @(Get-ChildItem $out -Recurse -Filter 'bcrypt.dll' -File)
if ($bcryptItems.Count -eq 0) { throw 'Built bcrypt.dll not found' }
$bcrypt = $bcryptItems | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
"bcrypt=$($bcrypt.FullName)`nruntime_closure=bcrypt.dll only" | Set-Content -Encoding ascii (Join-Path $diag 'runtime-closure-build-paths.txt')
Copy-Item $bcrypt.FullName (Join-Path $runtime 'bcrypt.dll')

$forbidden = @(
  'AcquireSRWLockExclusive','AcquireSRWLockShared','ReleaseSRWLockExclusive','ReleaseSRWLockShared',
  'InitializeSRWLock','InitializeConditionVariable','SleepConditionVariableCS','SleepConditionVariableSRW',
  'WakeAllConditionVariable','WakeConditionVariable','InitializeCriticalSectionEx',
  'FlsAlloc','FlsFree','FlsGetValue','FlsSetValue','GetTickCount64','GetSystemTimePreciseAsFileTime'
)

$headers = & dumpbin /headers $bcrypt.FullName 2>&1
$imports = & dumpbin /imports $bcrypt.FullName 2>&1
$exports = & dumpbin /exports $bcrypt.FullName 2>&1
$headers | Set-Content -Encoding utf8 (Join-Path $diag 'bcrypt.headers.txt')
$imports | Set-Content -Encoding utf8 (Join-Path $diag 'bcrypt.imports.txt')
$exports | Set-Content -Encoding utf8 (Join-Path $diag 'bcrypt.exports.txt')
foreach ($name in $forbidden) {
  if ($imports -match "\b$([regex]::Escape($name))\b") { throw "Post-XP hard import found in bcrypt.dll: $name" }
}
if ($imports -match '(?i)\bmbedtls\.dll\b') { throw 'Embedded-source bcrypt build still imports mbedtls.dll' }

$requiredExports = @(
  'BCryptOpenAlgorithmProvider','BCryptCloseAlgorithmProvider','BCryptGetProperty',
  'BCryptCreateHash','BCryptHashData','BCryptFinishHash','BCryptDestroyHash','BCryptGenRandom'
)
foreach ($name in $requiredExports) {
  if (-not ($exports -match "\b$([regex]::Escape($name))\b")) { throw "Required bcrypt export missing: $name" }
}

$dynamicSource = Join-Path $RepoRoot 'tools\gost\xp\bcrypt-smoke\bcrypt_dynamic.cpp'
$linkedSource = Join-Path $RepoRoot 'tools\gost\xp\bcrypt-smoke\bcrypt_linked.cpp'
$dynamicObj = Join-Path $WorkRoot 'bcrypt-source-dynamic.obj'
$linkedObj = Join-Path $WorkRoot 'bcrypt-source-linked.obj'
$dynamicExe = Join-Path $runtime 'bcrypt-source-dynamic.exe'
$linkedExe = Join-Path $runtime 'bcrypt-source-linked.exe'

& cl.exe /nologo /c /O2 /GS- /GR- /EHsc- /Fo$dynamicObj $dynamicSource
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source dynamic probe compile failed' }
& link.exe /nologo /OUT:$dynamicExe /ENTRY:mainCRTStartup /SUBSYSTEM:CONSOLE,5.01 /NODEFAULTLIB $dynamicObj kernel32.lib
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source dynamic probe link failed' }

& cl.exe /nologo /c /O2 /GS- /GR- /EHsc- /Fo$linkedObj $linkedSource
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source linked probe compile failed' }
& link.exe /nologo /OUT:$linkedExe /ENTRY:mainCRTStartup /SUBSYSTEM:CONSOLE,5.01 /NODEFAULTLIB $linkedObj bcrypt.lib kernel32.lib
if ($LASTEXITCODE -ne 0) { throw 'bcrypt source linked probe link failed' }

$dynamicHeaders = & dumpbin /headers $dynamicExe 2>&1
$dynamicImports = & dumpbin /imports $dynamicExe 2>&1
$linkedHeaders = & dumpbin /headers $linkedExe 2>&1
$linkedImports = & dumpbin /imports $linkedExe 2>&1
$dynamicHeaders | Set-Content -Encoding utf8 (Join-Path $diag 'dynamic-probe.headers.txt')
$dynamicImports | Set-Content -Encoding utf8 (Join-Path $diag 'dynamic-probe.imports.txt')
$linkedHeaders | Set-Content -Encoding utf8 (Join-Path $diag 'linked-probe.headers.txt')
$linkedImports | Set-Content -Encoding utf8 (Join-Path $diag 'linked-probe.imports.txt')
if ($dynamicImports -match '(?i)bcrypt\.dll') { throw 'Dynamic probe unexpectedly imports bcrypt.dll' }
if (-not ($linkedImports -match '(?i)bcrypt\.dll')) { throw 'Linked probe does not import bcrypt.dll' }
foreach ($name in $forbidden) {
  if ($linkedImports -match "\b$([regex]::Escape($name))\b") { throw "Post-XP hard import found in linked consumer: $name" }
}

@'
@echo off
setlocal
cd /d "%~dp0"
echo === One-Core source-built embedded-mbedtls bcrypt dynamic probe ===
bcrypt-source-dynamic.exe
echo DynamicExitCode=%ERRORLEVEL%
echo.
echo === One-Core source-built embedded-mbedtls bcrypt linked probe ===
bcrypt-source-linked.exe
echo LinkedExitCode=%ERRORLEVEL%
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'run-on-xp.cmd')

@"
One-Core-API source-built bcrypt XP x86 embedded-mbedtls smoke
Source repository: shorthorn-project/One-Core-API-Source
Pinned source commit: $sourceCommit
Successful two-DLL baseline project source: fdd4d4dac5a7d9611ec71975ae800437f45c47dd
Source components: dll/win32/bcrypt plus the pinned active C modules from dll/3rdparty/mbedtls, compiled directly into bcrypt.dll
Build environment: RosBE 2.1.6 i386
Build adjustments: the same one-line WIDL host-tool repair as the successful baseline plus bcrypt CMake composition only; bcrypt and mbedtls C implementations and mbedtls CMake remain unmodified.

Runtime closure requirement:
- bcrypt.dll is the only staged DLL;
- bcrypt.dll must not import mbedtls.dll;
- required BCrypt exports must remain present.

Physical XP test:
1. Extract the artifact unchanged on Windows XP SP3 x86.
2. Run run-on-xp.cmd and record complete output.
3. Require both DynamicExitCode=0 and LinkedExitCode=0.

Both probes require:
LOAD PASS
EXPORTS PASS
RNG PASS
SHA256 PASS
"@ | Set-Content -Encoding utf8 (Join-Path $runtime 'README-XP.md')

Get-ChildItem $runtime -File | ForEach-Object {
  $h = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
  "$h  $($_.Name)"
} | Set-Content -Encoding ascii (Join-Path $diag 'runtime-bundle-hashes.txt')

Push-Location $runtime
try {
  & .\bcrypt-source-dynamic.exe *>&1 | Tee-Object -FilePath (Join-Path $diag 'hosted-dynamic-runtime.txt')
  $dynamicExit = $LASTEXITCODE
  & .\bcrypt-source-linked.exe *>&1 | Tee-Object -FilePath (Join-Path $diag 'hosted-linked-runtime.txt')
  $linkedExit = $LASTEXITCODE
} finally { Pop-Location }
if ($dynamicExit -ne 0) { throw "Hosted exact-local embedded-mbedtls bcrypt dynamic probe failed with $dynamicExit" }
if ($linkedExit -ne 0) { throw "Hosted embedded-mbedtls bcrypt linked probe failed with $linkedExit" }
