# r3dfox GOST TLS — Project State

Last updated: 2026-09-09

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

For Windows XP work, read `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, `XP_RUNTIME_COMPATIBILITY_STATUS.md`, and the newest XP entries in `TEST_LOG.md`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP runtime success. Documentation HEADs never replace the exact source-under-test SHA for an earlier artifact.

# GOST TLS runtime

No GOST-runtime conclusion changes as a result of the XP work below.

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current GOST runtime constraints/open work remain:

- TLS 1.2 / HTTP/1.1 PoC path;
- coordinated Firefox client-auth picker as default;
- `Session` is the current default positive certificate choice and remains process-local;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open;
- synchronous provider/key access can still block the shared Firefox Socket Thread during long CryptoPro waits.

Current authoritative Session-default browser source is `afbdad307f63e594d3715169d6e34235280dddaf`, full build run `33073577269`, job `98521835354`, release artifact `9652941006`.

# Windows XP SP3 x86 compatibility

This track is independent of GOST TLS runtime. Active implementation work is on `agent/winrt-source-poc`; canonical documentation remains on `agent/gost-tls-poc`.

## Supermium DWrite private component — PHYSICAL XP PASS; Firefox integration next

The focused workflow `.github/workflows/xp-supermium-dwrite-closure.yml` does not checkout or build Firefox. Its source identity is the workflow plus pinned external assets; `firefox_source=NOT_APPLICABLE`.

Current authoritative focused DWrite result:

- workflow/head SHA `a42b144cbeeeac6a3765d132111208d600f1a3fc`;
- run `34317489430`;
- job `102356664699`;
- result **completed / success / GREEN**;
- candidate artifact `10090864697` (`xp-supermium-dwrite-dist-bin-34317489430`), digest `sha256:de0765b8ed2e28259420d9671c2b4e4a54b492555698724187a7f6ea2ee40a47`;
- diagnostics artifact `10090863781`, digest `sha256:549913f8ea9a92a87bc602bc486e627be25667cec66fe4ef917939fabd29a8ef`.

The selected future runtime layout is now proven at focused-component scale:

```text
dist/bin/
  ucrtbase.dll                         shared project msvcr14x runtime
  xpcompat/dwrite/
    DWrite.dll
    p_advp32.dll
    p_ole.dll
    pwp_shd.dll
    pwrp_k32.dll
    api-ms-win-crt-heap-l1-1-0.dll
    api-ms-win-crt-math-l1-1-0.dll
    api-ms-win-crt-runtime-l1-1-0.dll
    api-ms-win-crt-stdio-l1-1-0.dll
    api-ms-win-crt-string-l1-1-0.dll
```

Supermium `ucrtbase.dll` is not staged. The shared UCRT is built from pinned project `Chuyu-Team/msvcr14x` source `6495947edbdd8f5dc4b2ddb8ca0cb5dbdac05384`. Exact DWrite still imports 37 CRT functions through the five private API-set forwarders, and the focused workflow proves all 37 targets are exported by the actual msvcr14x UCRT used in the candidate.

The decisive correction relative to the preceding failed smoke is **UCRT load mode**. The failing run `34312848959`, job `102342884960`, late-loaded msvcr14x `ucrtbase.dll` with `LoadLibraryEx`; on physical XP the smoke reached `PWRP_LOAD_PASS` and then `DWRITE_LOAD_FAIL GetLastError=0x000003E6`. WinDbg localized the underlying access violation inside the msvcr14x UCRT static-TLS access during DWrite CRT process attach. That was a test-model error: the project's physically proven XP CRT model uses ordinary process-startup/load-time UCRT loading.

The corrected smoke executable therefore has a normal PE load-time import on `ucrtbase.dll`, verifies `_errno` as a static-TLS positive control, then preloads private `xpcompat/dwrite/pwrp_k32.dll` and loads private `DWrite.dll` through absolute paths with `LOAD_WITH_ALTERED_SEARCH_PATH`.

Physical Windows XP SP3 x86 execution of exact artifact `10090864697` reports:

```text
UCRT_STARTUP_LOAD_PASS
UCRT_PATH=...\dist\bin\ucrtbase.dll
UCRT_STATIC_TLS_PASS
PWRP_LOAD_PASS
PWRP_PATH=...\dist\bin\xpcompat\dwrite\pwrp_k32.dll
DWRITE_LOAD_PASS
DWRITE_FACTORY_PASS
DWRITE_FONT_COLLECTION_PASS
DWRITE_SMOKE_PASS
```

Therefore the focused component now physically proves on XP:

- project msvcr14x UCRT is usable when loaded at process startup, including static TLS;
- exact private `pwrp_k32.dll` can be loaded from the isolated subtree;
- exact Supermium `DWrite.dll` can then be loaded from that subtree;
- `DWriteCreateFactory` succeeds;
- `IDWriteFactory::GetSystemFontCollection()` succeeds.

Conclusion: **the private DWrite component architecture is physically viable on XP without Supermium UCRT.** The earlier hypothesis that Supermium UCRT is required is rejected for this focused path. The external-only static audit at SHA `13acb155...` remains useful historical provider-closure evidence, but it is superseded by this stronger component runtime proof for the integration decision.

Next step is not another standalone DWrite experiment. Transfer the proven component into the main XP implementation/build line:

1. stage the ten private DWrite PEs under `dist/bin/xpcompat/dwrite` while keeping project msvcr14x `ucrtbase.dll` shared at `dist/bin`;
2. implement the narrow XP-only DWrite owner load path in `gfx/2d/Factory.cpp`: preserve normal `LoadLibrarySystem32(L"dwrite.dll")` behavior first, then on the XP compatibility path load the absolute private DWrite path with `LOAD_WITH_ALTERED_SEARCH_PATH` and ensure the private `pwrp_k32.dll` provider is available first;
3. package the subtree without duplicating UCRT or unrelated shared compatibility DLLs;
4. preserve exact PE/import/hash gates for the pinned component;
5. build one full XP browser candidate and physically verify that Firefox advances past the current DirectWrite/WebRender graphics boundary.

Do not interpret this focused PASS as full Firefox startup proof or as GOST TLS runtime evidence.

## Current all-GREEN build/static candidate

Current implementation HEAD and latest completed full-build source-under-test:

- branch `agent/winrt-source-poc`;
- SHA `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4`;
- battery source remediation `b68b925efc504ffe6696fc28848f8df0b3cae343` (`fix(xp): use legacy battery power notifications`);
- battery final-import gate `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4` (`ci(xp): gate Vista-only battery imports`);
- lineage includes `dad33d25dddc060ee74d773dcc492d835a78fd1e`, which removes the rejected shared-memory access-mask override while preserving the physically successful child-HANDLE inheritance fix.

Exact completed full build:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34213345771`, attempt `1`;
- job `102019253738` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success / GREEN**.

Exact artifacts:

- package `10056086223`, digest `sha256:9135b55913dfcf49390d022b94c21520ed2f5852e8b846f4b117635696634949`;
- runtime `10056088395`, digest `sha256:2cf7cf6ca44c0d8abddb930564a65bdf57188f4a2ae0fd5a56b29d7c522ce57f`;
- diagnostics `10056127829`, digest `sha256:04d284ce8738a63b72508e00747576c56fb2dfb86233e6e460fc1803b4234b33`.

The exact run passed full compile/link, packaging, runtime archive generation, current XP PE/import gates, package-integrity gates, YY-Thunks inventory, artifact uploads and the final summary. In particular, the new `GATE - Require XP battery Vista-only USER32 imports absent from xul.dll` passed. Therefore final `xul.dll` from this exact build contains neither ordinary nor delay-load references to:

```text
RegisterPowerSettingNotification
UnregisterPowerSettingNotification
```

This remains build/static evidence. The DWrite focused PASS above does not retroactively add the private component to this old browser artifact; a new integrated full build is required.

## SharedPrefMap child-HANDLE blocker — PHYSICALLY CLOSED on `897e1cdf...`

The preceding exact build `cae81ff9798f759b9a2b162e3455a8ddf382c8ad` repeatedly failed on physical XP at:

```text
mozilla::SharedPrefMap::SharedPrefMap(...)
modules/libpref/SharedPrefMap.cpp:25
MOZ_RELEASE_ASSERT(map)
exception 0x80000003
```

Matching WinDbg evidence established `MapViewOfFileEx(...) -> NULL`, `GetLastError() = 6 = ERROR_INVALID_HANDLE`, and `LastStatusValue = 0xC0000008 = STATUS_INVALID_HANDLE`. The child received the exact numeric `-prefMapHandle` value and size, but the corresponding kernel HANDLE had not been inherited.

Source tracing localized the defect to `base::LaunchApp`: on XP the Vista+ `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` family is unavailable, so the old code left `bInheritHandles = FALSE` even after requested handles had been marked `HANDLE_FLAG_INHERIT`.

The remediation in `ipc/chromium/src/base/process_util_win.cc` preserves the Vista+ selective attribute-list path and, under `MOZ_XP_COMPAT`, enables classic Windows inheritance when that Vista+ API is unavailable.

Physical Windows XP SP3 x86 testing of exact source `897e1cdf98bcc091e13283fa8004177971d30f27` / run `34194737456` was repeated several times. User-reported binary identities:

- `r3dfox.exe` SHA-1 `dbfaed8d2d06d50195a572f8364186e4032f8a97`;
- `xul.dll` SHA-1 `fcc09439c4e36be056b5796303f7e433a7afe585`.

Across those launches, the previous `SharedPrefMap.cpp:25` / `0x80000003` boundary no longer reproduced. Conclusion: **the SharedPrefMap invalid-child-HANDLE blocker is physically closed for source `897e1cdf...` / run `34194737456`.** Do not reopen it without contradictory evidence on a later exact artifact.

The new source `db334d...` retains that launcher remediation but removes the earlier rejected `Platform::Freeze()` access-mask override. Run `34213345771` proves that this cleaned-up lineage still builds/packages and satisfies the static contract; physical XP validation of continued SharedPrefMap closure on the cleaned-up artifact is still required.

## Physical `0xC06D007F` boundary — ROOT CAUSE LOCALIZED; successor static fix GREEN

After the SharedPrefMap advance, exact source `897e1cdf...` repeatedly reached exception `0xC06D007F` on physical Windows XP.

The physical DrWatson capture was tied to the exact package binaries and matching PDB. Symbolization and the captured MSVC delay-load information establish the chain through `__delayLoadHelper2` / `_tailMerge_user32.dll` into the Windows battery HAL, with:

- loaded module `USER32.dll`;
- `dwLastError = 0x7f` (`ERROR_PROC_NOT_FOUND`);
- exact delayed procedure `RegisterPowerSettingNotification`;
- source owner `hal/windows/WindowsBattery.cpp::EnableBatteryNotifications()`;
- caller path from `GPUProcessManager::BatteryObserver` registration after GPU-process launch.

`RegisterPowerSettingNotification` and its paired `UnregisterPowerSettingNotification` are Vista-era APIs. This is a source/legacy-Windows compatibility issue, not a YY-Thunks ownership problem.

The successor remediation on `b68b925...` keeps the existing hidden battery window and `GetSystemPowerStatus()` snapshot logic but, under C/C++ `MOZ_XP_COMPAT`, uses XP-compatible `WM_POWERBROADCAST / PBT_APMPOWERSTATUSCHANGE` and compiles out both Vista-only registration APIs. Vista+ behavior remains unchanged.

Run `34213345771` on exact source `db334d...` passes the dedicated final-`xul.dll` direct+delay import gate for both names. Therefore the exact delayed-import edge that caused the old physical exception is **statically removed**.

Do not call the `0xC06D007F` blocker physically closed yet. Physical XP must exercise artifact `10056088395` or a later exact integrated browser artifact and advance beyond this path.

## Rejected `Platform::Freeze()` access-mask override — removed and rebuilt

The earlier XP-only experiment changed `GENERIC_READ | FILE_MAP_READ` to `FILE_MAP_READ | SECTION_QUERY`. It independently failed to advance SharedPrefMap, while the later launcher inheritance fix did advance the exact physical boundary.

Commit `dad33d25dddc060ee74d773dcc492d835a78fd1e` permanently removes only that rejected access-mask experiment and restores the common source path. The current GREEN source `db334d...` includes this cleanup and the successful launcher fix.

The planned build-level control is now complete: run `34213345771` builds/packages successfully with the rejected override absent. The remaining causal control is physical: the exact new artifact must still advance past SharedPrefMap on Windows XP.

## Latest YY DLL entry-point/TLS static coverage — 13/13 CLOSED

Run `34138054280`, job `101793510758`, source-under-test `6885135565f7262bb88c80c4751f4a6c4b93e3ef` expanded the scoped YY-Thunks DLL/TLS startup contract from 3/13 to 13/13 strong candidates. Its normal Firefox compile/link, package/runtime generation, PE/import audit and final YY contract audit succeeded. The aggregate job was RED only because a separate supplemental warm-relink experiment used incorrect generated-objdir assumptions.

The 13/13 static closure remains valid and does not need separate per-library rebuilds. The current full GREEN run `34213345771` also completes the non-blocking YY DLL entry-point inventory successfully.

## Build-configuration identity

Keep the XP compatibility mechanisms distinct:

- C/C++ `MOZ_XP_COMPAT` is supplied through XP `CFLAGS` / `CXXFLAGS` as `-DMOZ_XP_COMPAT`;
- Rust uses separate job-global `RUSTFLAGS="--cfg moz_xp_compat"`;
- neither implies a `moz.build` `CONFIG["MOZ_XP_COMPAT"]` variable.

## Earlier physical/runtime boundaries closed in the current lineage

Do not reopen these without contradictory evidence on a later exact artifact:

- `SharedPrefMap.cpp:25` / invalid inherited preference HANDLE / `0x80000003` on `897e1cdf...`;
- `xul.dll` `ntdll!RtlpWaitForCriticalSection` startup failure;
- preceding IP Helper runtime boundary;
- `USER32!SetProcessDPIAware` delay-load boundary;
- `NtCancelIoFileEx`;
- ADVAPI32 ETW family;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import dependency;
- WS2_32 observed compatibility family;
- ANGLE/DXGI static `CreateDXGIFactory1` edge;
- current 13-strong-candidate YY DLL entry-point/TLS static coverage debt;
- standalone DWrite dependency/provider ambiguity: the selected `xpcompat/dwrite` private component with project msvcr14x UCRT is physically proven on XP at focused scale by run `34317489430` / artifact `10090864697`.

The `USER32!RegisterPowerSettingNotification` / `0xC06D007F` edge is not in this physically closed browser list yet: its root cause is exact and its successor static gate is GREEN, but successor physical browser execution is pending.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**.

The focused DWrite component is now physically proven, but it has not yet been transferred into a full browser artifact. Current old full-build/static candidate remains source `db334d...` / run `34213345771`, job `102019253738`, GREEN, and does not contain the new private DWrite integration.

Next browser experiment should therefore be a new integrated candidate on `agent/winrt-source-poc` that preserves the already-proven XP fixes and adds the exact focused DWrite component/loader contract. Its physical XP test must establish the next actual browser boundary. XP runtime success would still not prove a GOST TLS handshake.

# Bundled government-system extensions / localization

Current proven three-extension packaging checkpoint remains source `b3d097de20b7a5711f161199a727bcfe9468bcc8`, run `32976571122`, job `98202641607`.

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success.

Manual runtime evidence belongs to the exact artifact on which it was observed; do not reattribute it to later packaging-only correction builds.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard or delay-import runtime edge != physical-XP runtime closure until the exact accepted artifact advances past it.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- A PDB may symbolize only the exact matching binary from the same build.
- Runtime claims must stay bound to exact source SHA + Actions run/job + exact artifact/binary identity.
