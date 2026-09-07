# r3dfox GOST TLS — Project State

Last updated: 2026-09-07

This file is the authoritative current technical synthesis and handoff for new chats. The immediately preceding synthesis is preserved unchanged in [`PROJECT_STATE_2026-09-06_pre_full_xp_green.md`](./PROJECT_STATE_2026-09-06_pre_full_xp_green.md). Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility implementation branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active work branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

For Windows XP work, read `XP_BUILD_CONTRACT.md` and `XP_MOZ_XP_COMPAT_CONTRACT.md` before proposing build/configuration changes. For the current Shell32 cluster also read `XP_SHELL32_COMPATIBILITY.md`. For physical-XP startup/runtime work, also read `XP_RUNTIME_COMPATIBILITY_STATUS.md` and the newest XP entries in `TEST_LOG.md`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP runtime success. Documentation HEADs never replace the exact source-under-test SHA for an earlier artifact.

# GOST TLS runtime

No GOST-runtime conclusion changes as a result of the XP work described below.

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

## Latest completed build/static baseline — GREEN

The newest completed and authoritative full XP x32 build is:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34079480996`, attempt `1`;
- job `101611911453`;
- aggregate conclusion: **success**;
- package artifact `10005434231`, digest `sha256:e95f55a7789c271a96a96e78a3c166a43a05a6979eec535319e0d878139f32c0`;
- runtime artifact `10005434852`, digest `sha256:23ea95085afbe98035f736fafaa04b6225acadfd79dde571de034eca9d4da971`;
- diagnostics artifact `10005435712`, digest `sha256:55615a9294107a6d890d9bb34a61970c225d6425cb15e43e77d45b5b12009d7c`.

This exact run completed the dedicated final-`xul.dll` IPHLPAPI diagnostic and all later build/package/static compatibility gates successfully. The source-under-test carries the XP-era network listener and Rust `mtu` remediation that remove the modern IP Helper paths from the intended final `xul.dll` boundary.

The same `0a18ba85...` browser starts on physical Windows 7 x86. On physical XP it advances beyond the previously closed `RtlpWaitForCriticalSection` and IP Helper boundaries but still exposes later runtime failures described below.

## Current implementation HEAD and active validation builds

Current XP implementation HEAD is:

- branch `agent/winrt-source-poc`;
- HEAD `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`).

This HEAD contains the physically motivated `nsXREDirProvider.cpp` Shell32 remediation plus two proactively identified neighboring `SHGetKnownFolderPath` owners, all under the project-owned `MOZ_XP_COMPAT` contract.

A new full XP build has now been launched from this exact HEAD:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34107793132`, attempt `1`;
- job `101696721232` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- source-under-test `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`;
- event `workflow_dispatch`;
- state when documented: **in progress**.

This is the authoritative validation build for the current three-owner Shell32 source-remediation cluster. Do not mark any of its pending gates as passed until the exact job completes.

The separate older diagnostics/PDB/YY inventory build is:

- source-under-test `a15dcd738edda4ab810fc9f92289170f115519e4`;
- run `34095425319`;
- job `101657910987`;
- purpose includes matching `xul.pdb` preservation and `DIAG - Inventory YY-Thunks DLL entry-point coverage`.

Do not attribute any current Shell32 remediation to run `34095425319`; it predates the Shell32 source changes.

## Physical XP runtime — inherited AutoConfig forces GFX critical failures to crash

The shipped/inherited `config.cfg` contains:

```js
// Added via patches/autoconfig-setEnv.patch
setEnv("MOZ_GFX_CRASH_MOZ_CRASH", 1);
```

This setting is applied inside the running browser by AutoConfig, so it need not be present in the parent command shell environment before startup. In a supplied physical-XP dump from the exact `0a18ba85...` browser, one `0x80000003` path resolves to `MOZ_CRASH(GFX_CRASH)` after:

```text
[GFX1-]: Failed to initialize CompositorD3D11 for SWGL:
FEATURE_FAILURE_D3D11_NO_DEVICE
```

For release builds, `MOZ_GFX_CRASH_MOZ_CRASH` deliberately converts the graphics critical action into a fatal `MOZ_CRASH`. Therefore that particular breakpoint is not by itself proof of a new missing XP API. It is an inherited runtime policy which can obscure the next compatibility boundary.

Deleting the whole `config.cfg` is a diagnostic experiment only; it changes more than this single variable and is not an accepted packaging fix.

## Most recently exposed config-free parent-process blocker — `SHELL32!SHGetKnownFolderPath`

The user temporarily removed `config.cfg` and launched the same exact `0a18ba85...` physical-XP browser. The resulting Dr. Watson capture contains one MSVC delay-load exception:

```text
exception      C06D007F
DLL            SHELL32.dll
procedure      SHGetKnownFolderPath
pfnCur         0
last error     0x0000007f / ERROR_PROC_NOT_FOUND
```

Physical capture identity:

- `drwtsn32.log` SHA-256 `f54366c0787cc53962f3300cbd84ddab0fdf507cf9d3a613901f2f6879144a36`;
- `user.dmp` SHA-256 `0e3cb1e3e4822729145bcc4f6d6e799ead772321fc018cb1c9fb648c97efbb38`;
- PID `6184`;
- time `2026-09-07 15:12:04.957` local physical-XP time.

The physically reached source owner is `toolkit/xre/nsXREDirProvider.cpp`. Its existing registry fallback could not handle this boundary because the delay-load helper raises before `SHGetKnownFolderPath` returns a failing `HRESULT`.

The implementation branch now carries three project-owned `MOZ_XP_COMPAT` remediations for this Shell32 family:

- `nsXREDirProvider.cpp`: XP uses `SHGetFolderPathW` with `CSIDL_LOCAL_APPDATA` / `CSIDL_APPDATA` and preserves the existing registry fallback; non-XP builds retain `SHGetKnownFolderPath` / `FOLDERID_*`;
- `xpcom/io/SpecialSystemDirectory.cpp`: the XP `Win_Downloads` path goes directly to the existing `CSIDL_DESKTOP` fallback and the direct `SHGetKnownFolderPath` helper is excluded from the XP translation unit;
- `toolkit/mozapps/update/common/commonupdatedir.cpp`: the XP ProgramData path uses `SHGetFolderPathW` with `CSIDL_COMMON_APPDATA | CSIDL_FLAG_CREATE`; non-XP builds retain `SHGetKnownFolderPath(FOLDERID_ProgramData, ...)`.

All three dedicated owners are ordinary `SOURCES` entries with source-local `-DMOZ_XP_COMPAT` ownership. `SpecialSystemDirectory.cpp` and `commonupdatedir.cpp` were removed from unified compilation before applying their source-local flags. The net implementation change from `b59e957015544fa7761abf07fedde3c5d259104c` to current HEAD `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` is limited to the two source files and their two owning `moz.build` files.

Only the first `nsXREDirProvider.cpp` path is backed by the supplied physical-XP `C06D007F` evidence. The two neighboring owners were identified proactively from the same Shell32 API family and are **source-integrated but not yet build- or runtime-proven**.

Detailed Shell32 inventory, implementation commits, current validation run and remaining candidates are maintained in `XP_SHELL32_COMPATIBILITY.md`.

### Remaining Shell32 candidates already identified

These are intentionally **not** part of run `34107793132` so the current experiment remains attributable to the three `SHGetKnownFolderPath` owners:

- `SHCreateItemFromParsingName` — known owner `toolkit/components/downloads/DownloadPlatform.cpp`; likely XP direction is to use the existing `SHAddToRecentDocs(SHARD_PATHW, ...)` path directly under `MOZ_XP_COMPAT`, but this remains a separate planned experiment rather than a current fix;
- `SHOpenWithDialog` — appears in the inspected Shell32 delay-import family, but the current production owner/runtime path must be localized before changing source;
- `GetCurrentProcessExplicitAppUserModelID` — Windows 7-era API present in the earlier inventory, but at least one current owner already resolves it dynamically with `GetProcAddress`; audit final ownership before any remediation.

Do not treat these three as physically proven blockers. The next exact XP runtime result should decide which path is actually worth changing next.

## Unresolved parallel symptom — SpiderMonkey/Wasm `MOZ_RELEASE_ASSERT(map)`

The preceding physical-XP Dr. Watson log for the same exact `0a18ba85...` browser contained six `0x80000003` events at the same `xul.dll` site:

- `xul.dll` load base `0x01bb0000`;
- fault VA `0x01e34926` / RVA `0x00284926`;
- instruction `CC` / `int 3`;
- exact crash reason `MOZ_RELEASE_ASSERT(map)`.

The source owner is `js/src/wasm/WasmProcess.cpp`, where `map` is the process-wide `sThreadSafeCodeBlockMap`. The assertion exists in `wasm::RegisterCodeBlock`, `wasm::UnregisterCodeBlock`, and `wasm::ShutDown`.

This symptom is **not considered closed** by the config-free `SHGetKnownFolderPath` experiment. Removing the whole `config.cfg` changes startup behavior, so one run reaching a different parent-process boundary does not prove that the Wasm assertion disappeared. The older `a15dcd...` build is intended to provide matching PDBs and an all-DLL YY-Thunks entry-point/TLS inventory so this line can be classified more precisely.

Do not suppress `MOZ_RELEASE_ASSERT(map)` as a fix. Also do not assume it is intrinsically a SpiderMonkey implementation bug: an XP-only DLL/TLS/one-time-init integration defect can manifest there first.

## Physical XP progression — earlier blockers CLOSED

The exact `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278` browser, run `34038288272`, job `101500284497`, runtime artifact `9992440155`, physically advanced beyond the old `ntdll!RtlpWaitForCriticalSection` startup crash. That blocker remains closed and must not be reopened without contradictory evidence on a later exact browser.

The newer exact `0a18ba85...` browser also physically advances beyond the preceding IP Helper runtime problem. This is consistent with run `34079480996`'s final IPHLPAPI diagnostic.

## Compatibility work incorporated into the current closure / implementation lineage

The current lineage includes:

- SRW / condition-variable and narrow residual KERNEL32 compatibility;
- `CreateWaitableTimerExA` source fallback;
- selected XP-compatible `bcrypt.dll` packaging;
- legacy `D3DCompiler_47.dll` staging;
- `NtCancelIoFileEx` narrow YY-Thunks remediation and final `xul.dll` import closure;
- ADVAPI32 ETW family remediation;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import removal;
- DPI startup fix for `USER32.dll!SetProcessDPIAware`;
- WS2_32 compatibility work, including focused YY capability and later integration;
- ANGLE/DXGI work removing the XP-incompatible static `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` edge while preserving the intended D3D9 fallback path;
- YY-Thunks DLL/TLS entry-point integration scoped to `xul.dll`, physically proven to advance past the old `RtlpWaitForCriticalSection` crash;
- source-level IP Helper remediation physically proven to advance beyond the preceding IP Helper runtime boundary on source `0a18ba85...`;
- source-level `MOZ_XP_COMPAT` remediation for the `SHELL32!SHGetKnownFolderPath` family in `nsXREDirProvider.cpp`, `SpecialSystemDirectory.cpp`, and `commonupdatedir.cpp`; the physically reached `nsXREDirProvider` boundary motivated the cluster, while the latter two proactive owners remain pending rebuild/runtime validation.

Historical source/run/job/artifact identities for individual closures remain authoritative in `TEST_LOG.md`, `TEST_LOG_2026-09-06_pre_full_xp_green.md`, and earlier dated test-log volumes. Do not reopen a focused capability already proven there unless contradictory evidence appears.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## Next experiment order

1. Finish and classify the current Shell32 validation build: run `34107793132`, job `101696721232`, source `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4`.
2. Preserve the exact result of the older PDB/YY inventory build `34095425319` / job `101657910987` / source `a15dcd738edda4ab810fc9f92289170f115519e4` and keep its conclusions separate from the Shell32 build.
3. Inspect the final rebuilt `xul.dll` Shell32 delay-import inventory, especially any residual `SHGetKnownFolderPath` edge.
4. Physically test the exact `34107793132` artifact on XP. For clean diagnosis of the Shell32 boundary, distinguish a normal packaged run from any temporary config-free diagnostic run; do not silently treat deleting `config.cfg` as a product fix.
5. If startup advances, record the next actual runtime boundary before broadening Shell32 changes. `SHCreateItemFromParsingName` is the next already-localized feature-path candidate; `SHOpenWithDialog` must be localized first.
6. If `MOZ_RELEASE_ASSERT(map)` remains, use a matching PDB from the exact failing rebuilt browser to resolve the exact `RegisterCodeBlock` / `UnregisterCodeBlock` / `ShutDown` call site and then trace initialization ordering.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**. The old critical-section and IP Helper boundaries are closed on later exact candidates; the current Shell32 cluster is source-remediated and now under exact full-build validation in run `34107793132`, but has no rebuilt physical proof yet; the Wasm assertion remains unresolved in parallel.

A curated known-API list is a regression gate, not exhaustive compatibility proof. A successful XP startup would also not be a GOST TLS handshake result.

# Bundled government-system extensions / localization

Current proven three-extension packaging checkpoint remains source `b3d097de20b7a5711f161199a727bcfe9468bcc8`, run `32976571122`, job `98202641607`.

Current corrected Russian localization package gate is source `3e2c32386f373d4693db52b32c05aa2000878def`, workflow `CryptoPro Mozilla packaging smoke`, run `33520207057`, job `99897230730`, success.

Manual runtime evidence belongs to the exact artifact on which it was observed; do not reattribute it to later packaging-only correction builds.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard import != physical-XP runtime closure until the exact accepted artifact advances past that edge.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- For in-progress runs, record provisional state and never mark a pending gate as passed.
