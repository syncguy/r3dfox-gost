$ErrorActionPreference = 'Stop'

$checks = @(
  @{ Name='dpi-source-guard'; Outcome=$env:DPI_SOURCE_GUARD_OUTCOME },
  @{ Name='battery-power-import'; Outcome=$env:BATTERY_POWER_IMPORT_OUTCOME },
  @{ Name='source-remediation-quartet'; Outcome=$env:SOURCE_REMEDIATION_QUARTET_OUTCOME },
  @{ Name='advapi32-compat-import'; Outcome=$env:ADVAPI32_COMPAT_IMPORT_OUTCOME },
  @{ Name='dpi-import-mode'; Outcome=$env:DPI_IMPORT_MODE_OUTCOME },
  @{ Name='core-import'; Outcome=$env:CORE_IMPORT_OUTCOME },
  @{ Name='retargeted-d3dcompiler'; Outcome=$env:RETARGETED_D3DCOMPILER_OUTCOME },
  @{ Name='private-dwrite'; Outcome=$env:PRIVATE_DWRITE_OUTCOME },
  @{ Name='packaged-d3dcompiler'; Outcome=$env:PACKAGED_D3DCOMPILER_OUTCOME },
  @{ Name='packaged-crt'; Outcome=$env:PACKAGED_CRT_OUTCOME },
  @{ Name='packaged-private-dwrite'; Outcome=$env:PACKAGED_PRIVATE_DWRITE_OUTCOME },
  @{ Name='packaged-bcrypt'; Outcome=$env:PACKAGED_BCRYPT_OUTCOME },
  @{ Name='broad-import-audit'; Outcome=$env:BROAD_IMPORT_AUDIT_OUTCOME }
)
$operations = @(
  @{ Name='build'; Outcome=$env:BUILD_OUTCOME },
  @{ Name='package'; Outcome=$env:PACKAGE_OUTCOME },
  @{ Name='runtime-archive'; Outcome=$env:RUNTIME_ARCHIVE_OUTCOME }
)
$red = [System.Collections.Generic.List[string]]::new()

"## GOST TLS PoC build XP x32: final evidence summary" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Source: $env:GITHUB_SHA" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Target: i686-pc-windows-msvc / Windows XP SP3 x86." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- XP source defines: MOZ_NO_WINRT + MOZ_XP_COMPAT via CFLAGS/CXXFLAGS." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Private DirectWrite: focused contract source 8c30be63ea03a289ca24de4e2dc3e3859f34473e / run 34321430843 / job 102368728335; packaged as xpcompat/dwrite with exact 10-member pinned closure, shared msvcr14x ucrtbase.dll, absolute private DWrite path + LOAD_WITH_ALTERED_SEARCH_PATH, and no explicit pwrp preload." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Under MOZ_XP_COMPAT both XRE startup and gfx Factory DirectWrite load paths use LoadLibraryXPPrivateDWrite; LoadLibrarySystem32(DWrite.dll) remains non-XP only. Optimized read-ahead uses the packaged private path." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Broad PE audit retains the api-ms-win-* prohibition except for the five exact pinned CRT API-set imports of xpcompat/dwrite/DWrite.dll; the dedicated private-DWrite closure gate validates that exception recursively." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- DPI pre-Vista source guard: $env:DPI_SOURCE_GUARD_OUTCOME." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Battery USER32 import gate: $env:BATTERY_POWER_IMPORT_OUTCOME; RegisterPowerSettingNotification/UnregisterPowerSettingNotification must be absent from both ordinary and delay imports in xul.dll for the MOZ_XP_COMPAT legacy PBT_APMPOWERSTATUSCHANGE path." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Source-remediation quartet gate: $env:SOURCE_REMEDIATION_QUARTET_OUTCOME (evidence-preserving; survivors make the final verdict RED)." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- ADVAPI32 compatibility final xul.dll gate: $env:ADVAPI32_COMPAT_IMPORT_OUTCOME; ETW focused capability source 53971dcfdf12e7bcd7f35692ff2c02fb3360d792 / run 33882235341 / job 101053403554; RegGetValueW focused capability source 8ad1d5e9a935ed1cce8ee268f693af72aad1f7c4 / run 33946751857 / job 101254130849." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- WS2_32 focused YY capability: WSAIoctl + inet_ntop from source 5451673565030445262f5b6ef48b4059e0e0501e / run 34021400841 / job 101454550948; production link uses only their weak-alias pairs plus the shared narrow YY implementation." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- WSASendMsg is source late-bound and WSCGetProviderInfo LSP-category diagnostics are compiled out under MOZ_XP_COMPAT; all four WS2_32 names are forbidden as ordinary final imports." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- xul IPHLPAPI legacy MTU diagnostic: $env:XUL_IPHLPAPI_IMPORT_DIAG_OUTCOME (non-blocking; see diagnostics/xul-iphlpapi-xp-imports.txt)." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- YY DLL entry-point inventory: $env:YY_DLL_ENTRYPOINT_DIAG_OUTCOME (non-blocking; see diagnostics/yy-dll-entrypoint-audit.txt and diagnostics/yy-dll-entrypoint-missing-contract.txt)." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- mozglue SetProcessDPIAware import-mode gate: $env:DPI_IMPORT_MODE_OUTCOME." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Final all-PE audit records both ordinary and delay imports; only proven forbidden ordinary dependencies/APIs drive this gate." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- CRT/UCRT: pinned msvcr14x $env:MSVCR14X_SHA, preserving Firefox /MD." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- XP bcrypt: exact release $env:BCRYPT_TAG / asset $env:BCRYPT_ASSET_ID / SHA-256 $env:BCRYPT_SHA256." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- YY-Thunks: v$env:YY_THUNKS_VERSION target $env:YY_THUNKS_TARGET/x86; NtCancelIoFileEx ntdll alias + five-name ADVAPI32 alias family + two-name WS2_32 alias family + narrow provider + synchronization.lib are injected through global target LDFLAGS; full kernel32.lib, ntdll.lib, advapi32.lib and ws2_32.lib remain prohibited." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"### Operations" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
foreach ($item in $operations) {
  "- $($item.Name): $($item.Outcome)" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
  if ($item.Outcome -ne 'success') { $red.Add("operation:$($item.Name)=$($item.Outcome)") }
}
"" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"### Diagnostic gates" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
foreach ($item in $checks) {
  "- $($item.Name): $($item.Outcome)" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
  if ($item.Outcome -notin @('success','skipped')) { $red.Add("gate:$($item.Name)=$($item.Outcome)") }
}
"" | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Package/runtime/diagnostics uploads execute before this final verdict." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- A diagnostic RED does not suppress later evidence collection." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
"- Real Firefox startup on physical XP remains a separate runtime gate." | Out-File $env:GITHUB_STEP_SUMMARY -Append -Encoding utf8
if ($red.Count -gt 0) {
  $red | Set-Content -Encoding utf8 diagnostics\final-red-gates.txt
  throw ("XP x32 build completed evidence collection with RED outcomes: " + ($red -join '; '))
}
