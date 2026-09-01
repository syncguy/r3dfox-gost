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

$mbedtlsCmake = Join-Path $src 'dll\3rdparty\mbedtls\CMakeLists.txt'
$mbedtlsText = Get-Content -Raw $mbedtlsCmake
$mbedtlsAnchor = @'
add_library(mbedtls MODULE
    ${SOURCE}
    mbedtls.rc
    ${CMAKE_CURRENT_BINARY_DIR}/mbedtls.def)
'@
$mbedtlsStatic = @'
add_library(mbedtls_bcrypt STATIC ${SOURCE})

add_library(mbedtls MODULE
    ${SOURCE}
    mbedtls.rc
    ${CMAKE_CURRENT_BINARY_DIR}/mbedtls.def)
'@
if (-not $mbedtlsText.Contains($mbedtlsAnchor)) { throw 'Expected One-Core mbedtls module target not found' }
$mbedtlsText = $mbedtlsText.Replace($mbedtlsAnchor, $mbedtlsStatic)
$compileAnchor = @'
if(NOT MSVC)
    target_compile_options(mbedtls PRIVATE -Wno-pointer-sign -Wno-unused-function)
'@
$compileReplacement = @'
if(NOT MSVC)
    target_compile_options(mbedtls_bcrypt PRIVATE -Wno-pointer-sign -Wno-unused-function)
    target_compile_options(mbedtls PRIVATE -Wno-pointer-sign -Wno-unused-function)
'@
if (-not $mbedtlsText.Contains($compileAnchor)) { throw 'Expected One-Core mbedtls compile options not found' }
$mbedtlsText = $mbedtlsText.Replace($compileAnchor, $compileReplacement)
Set-Content -Encoding ascii -Path $mbedtlsCmake -Value $mbedtlsText

$bcryptCmake = Join-Path $src 'dll\win32\bcrypt\CMakeLists.txt'
$bcryptText = Get-Content -Raw $bcryptCmake
$oldLink = @'
target_link_libraries(bcrypt wine)
add_importlibs(bcrypt mbedtls advapi32 msvcrt kernel32 ntdll)
'@
$newLink = @'
target_link_libraries(bcrypt wine mbedtls_bcrypt)
add_importlibs(bcrypt advapi32 msvcrt kernel32 ntdll)
'@
if (-not $bcryptText.Contains($oldLink)) { throw 'Expected One-Core bcrypt mbedtls import wiring not found' }
$bcryptText = $bcryptText.Replace($oldLink, $newLink)
Set-Content -Encoding ascii -Path $bcryptCmake -Value $bcryptText

@"
source_sha=$sourceCommit
widl_fix=remove trailing NULL from one mismatched format_namespace host-tool call
bcrypt_implementation_modified=no
mbedtls_implementation_modified=no
linkage_change=compile the existing mbedtls SOURCE list into static target mbedtls_bcrypt and link that target into bcrypt.dll
runtime_goal=bcrypt.dll only; no mbedtls.dll dependency
"@ | Set-Content -Encoding ascii (Join-Path $diag 'onecore-source-build-adjustments.txt')
& git -C $src diff -- sdk/tools/widl/header.c dll/3rdparty/mbedtls/CMakeLists.txt dll/win32/bcrypt/CMakeLists.txt | Set-Content -Encoding utf8 (Join-Path $diag 'onecore-source-build-adjustments.diff')

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
if ($imports -match '(?i)\bmbedtls\.dll\b') { throw 'Static bcrypt build still imports mbedtls.dll' }

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
echo === One-Core source-built static-mbedtls bcrypt dynamic probe ===
bcrypt-source-dynamic.exe
echo DynamicExitCode=%ERRORLEVEL%
echo.
echo === One-Core source-built static-mbedtls bcrypt linked probe ===
bcrypt-source-linked.exe
echo LinkedExitCode=%ERRORLEVEL%
'@ | Set-Content -Encoding ascii (Join-Path $runtime 'run-on-xp.cmd')

@"
One-Core-API source-built bcrypt XP x86 static-mbedtls smoke
Source repository: shorthorn-project/One-Core-API-Source
Pinned source commit: $sourceCommit
Source components: dll/win32/bcrypt + dll/3rdparty/mbedtls compiled into bcrypt.dll
Build environment: RosBE 2.1.6 i386
Build adjustments: one-line WIDL host-tool repair plus linkage-only CMake change; bcrypt and mbedtls C implementations remain unmodified.

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
if ($dynamicExit -ne 0) { throw "Hosted exact-local static-mbedtls bcrypt dynamic probe failed with $dynamicExit" }
if ($linkedExit -ne 0) { throw "Hosted static-mbedtls bcrypt linked probe failed with $linkedExit" }
