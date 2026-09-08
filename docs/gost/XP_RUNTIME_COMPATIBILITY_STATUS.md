# Windows XP SP3 x86 — runtime compatibility status

Last updated: 2026-09-08

Track: Windows XP SP3 x86 runtime compatibility only. This document does not describe or prove GOST TLS / NSS / MSSPI / CryptoPro handshake behavior and does not authorize a Firefox/r3dfox 153 -> 154 base update.

Canonical documentation branch: `agent/gost-tls-poc`.

Implementation branch: `agent/winrt-source-poc`.

Frozen baseline: `win-153`; do not modify, merge, rebase or push to it without explicit user instruction.

This is the current handoff for the physical-XP startup and static-runtime-closure line. Read it together with `PROJECT_STATE.md`, the newest XP entries in `TEST_LOG.md`, `TODO.md`, `XP_BUILD_CONTRACT.md`, `XP_MOZ_XP_COMPAT_CONTRACT.md`, and `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md` before proposing runtime-compatibility changes. When identities differ, the newest exact source/run/job/artifact record in `PROJECT_STATE.md` / `TEST_LOG.md` is authoritative.

## Latest all-GREEN full-build/static baseline

The latest full XP x32 build whose aggregate job conclusion is GREEN is:

- branch `agent/winrt-source-poc`;
- source-under-test `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`);
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34107793132`, attempt `1`;
- job `101696721232` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success**;
- package artifact `10018222073`, digest `sha256:e2d535dc622c67cffb754f8bcafbb6d89127e7cdd7d0e40a298c2f675fda5b38`;
- runtime artifact `10018223364`, digest `sha256:ea39193e3f8422ee5e35bbe8f830cef936bb45273eff299392480c17357db61d`;
- diagnostics artifact `10018257313`, digest `sha256:8a4f3939b2bf8d30837060172b7cf4dc5de58dcb4a2b06a4a2e9d7220945a325`.

The build, packaging, runtime archive, XP PE/import gates, matching-PDB diagnostics, YY-Thunks inventory, artifact uploads and final summary all completed successfully. This remains the canonical all-GREEN build/static baseline. Its exact runtime artifact has also been physically tested on XP and currently stops later at the SharedPrefMap read-only mapping failure described below.

## Latest YY DLL entry-point/TLS coverage experiment — STATIC CLOSURE, aggregate RED explained

A later full XP x32 build was deliberately used to extend the already-proven xul YY-Thunks DLL/TLS startup contract to every strong YY-resolver candidate reported by the previous full-build diagnostics.

Exact identity:

- workflow-definition / run-head branch: `agent/gost-tls-poc`;
- workflow-definition / run-head SHA: `4ea3b94c048436c3f316704c54605567dba975bd`;
- checked-out implementation branch: `agent/winrt-source-poc`;
- source-under-test: `6885135565f7262bb88c80c4751f4a6c4b93e3ef`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34138054280`, attempt `1`;
- job `101793510758` (`Windows x86 / r3dfox GOST / XP YY DLL entry-point experiment`);
- aggregate job conclusion: **failure**, for the supplemental warm-relink experiment described below, not for the Firefox build or YY coverage gate.

Exact artifacts were produced before the final aggregate RED:

- package artifact `10028971959`, 327,817,004 bytes, digest `sha256:a856a62da534f774d08cb576978a86001bb063848bc7a30edae362db94749920`;
- runtime artifact `10028972525`, 74,931,692 bytes, digest `sha256:29b8b69d59a7c8ac99f1d5919eee1bba7a97f89a0ecdba209ccd821018523391`;
- diagnostics artifact `10028995017`, 420,495,148 bytes, digest `sha256:6ff6bb1f934ba814059848fd640312bf422446ece11ead93408782872a48e864`.

The full Firefox compile/link succeeded. Packaging, runtime archive creation, PE floor/direct-import audit and `GATE - Verify YY-Thunks DLL entry-point coverage` all succeeded. The YY inventory changed from the preceding run `34107793132`:

```text
run 34107793132: strong candidates=13, contracts=3,  missing=10
run 34138054280: strong candidates=13, contracts=13, missing=0
```

The xul positive control remained true. `yy-dll-entrypoint-missing-contract.txt` contains `none`.

The ten formerly missing strong candidates all have `contract=true` in the exact diagnostics artifact:

```text
gkcodecs.dll
gmp-clearkey/0.1/clearkey.dll
gmp-fake/1.0/fake.dll
gmp-fakeopenh264/1.0/fakeopenh264.dll
libGLESv2.dll
mozavcodec.dll
mozavutil.dll
mozglue.dll
mozinference.dll
nss3.dll
```

Therefore the current strong-candidate set has **13/13 static YY DLL entry-point/TLS contract coverage and 0 missing candidates** in source `688513...` / run `34138054280`. This closes the known static YY DLL entry-point coverage debt for this candidate inventory. It does not prove physical-XP runtime success.

### Why the aggregate job is RED

The supplemental step `GATE - Warm-relink early YY DLLs from completed objdir` was run with `continue-on-error` and internally failed because its objdir-layout assumptions were wrong:

```text
mozglue.dll  — expected one local mozglue.dll before warm relink; found 0
nss3.dll     — expected one generated nss_nss3 target directory; found 0
libGLESv2.dll — expected one local libGLESv2.dll before warm relink; found 0
```

The step therefore did not perform the intended second relink. GitHub displayed the continued step as completed, but its internal outcome remained `failure`; the final `GATE - Summarize XP YY x32 full build` correctly converted that recorded outcome into the aggregate RED.

This warm-relink failure does **not** invalidate the already-completed normal full-build links: the final produced `mozglue.dll`, `nss3.dll`, `libGLESv2.dll` and the other seven candidates all pass the final YY entry-point/TLS contract audit. Do not repeat separate per-library builds merely to re-prove this static result. If the workflow is cleaned up, the flawed warm-relink experiment should be removed or converted to verification of the already-built final DLLs rather than treated as a required rebuild path.

## Current physical-XP blocker — `SharedPrefMap` read-only mapping failure

The exact all-GREEN `cd5e715...` runtime artifact `10018223364` has been physically executed on Windows XP SP3 x86. Nine repeated `0x80000003` failures resolve by exact binary/PDB evidence to:

```text
modules/libpref/SharedPrefMap.cpp:25
SharedPrefMap::SharedPrefMap(const ReadOnlySharedMemoryHandle&)
MOZ_RELEASE_ASSERT(map)
```

The source path is:

```cpp
auto map = aMapHandle.Map();
MOZ_RELEASE_ASSERT(map);
```

On Windows this reaches `ipc/glue/SharedMemoryPlatform_windows.cpp::Platform::Map`, where `MapViewOfFileEx(FILE_MAP_READ, ...)` returns `NULL`. The current physical capture does not preserve the immediate `GetLastError()`, so handle rights/duplication, IPC/sandbox transfer and XP mapping semantics remain hypotheses.

One separate process reached `gfx/webrender_bindings/Moz2DImageRenderer.cpp:487` after `translator.TranslateRecording(...)` returned false. Keep that Moz2D replay failure separate from the nine repeated SharedPrefMap failures.

The next physical-XP experiment remains narrow instrumentation of the shared-memory mapping failure: capture `GetLastError()` immediately after the failed `MapViewOfFileEx`, handle validity/access context, offset, size, read-only/read-write mode and fixed-address request. Do not suppress `MOZ_RELEASE_ASSERT(map)` or add a speculative shared-memory fallback before that evidence exists.

The 13/13 YY static closure in run `34138054280` does not change this current physical blocker until its exact runtime artifact is physically exercised and produces contradictory evidence.

## Historical loader/runtime progression — closed evidence

### `RtlpWaitForCriticalSection` / xul YY startup contract

Source `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`, run `34038288272`, job `101500284497`, runtime artifact `9992440155` physically advanced past the older xul startup access violation in `ntdll!RtlpWaitForCriticalSection` after scoped YY-Thunks DLL/TLS startup integration for `xul.dll`:

```text
-ENTRY:DllMainCRTStartupForYY_Thunks
-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12
```

The preceding failure on source `176eb94b503e773334593508df408fa491faa45f`, run `34027798932`, job `101471779766`, runtime artifact `9989657830` remains historical evidence for a different exact browser and is no longer the current blocker.

### IP Helper API

The source-owned XP compatibility work replaced the Vista+ `NotifyIpInterfaceChange` path with the XP `NotifyAddrChange` path and replaced Rust `mtu` use of `GetIpInterfaceTable` / `FreeMibTable` / `if_indextoname` with the intended legacy adapter-enumeration path. Source `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`, run `34079480996`, job `101611911453` physically advanced past the preceding IP Helper boundary. Treat that line as historical/closed unless later exact evidence contradicts it.

### `SetProcessDPIAware`

The historical browser source `2b1cf7e1b59881b935c7f695a54edd6b92c8066e`, run `33757305364`, job `100654730312`, runtime artifact `9899304858` failed on physical XP with delay-load exception `0xC06D007F` because `USER32.dll!SetProcessDPIAware` is absent on XP.

Classic x86 WinDbg decoded the delay-load target as:

```text
szDll           = "USER32.dll"
szProcName      = "SetProcessDPIAware"
dwLastError     = 0000007f
```

That root cause is closed. The pre-Vista source guard and current DPI delay-import gate remain part of the full-build regression contract.

### `NtCancelIoFileEx`

Focused capability:

- source `be122cfc36d84e3144b73bcbaa2a2f46ff45f1a2`;
- workflow `XP x86 core KERNEL32 cluster smoke`;
- run `33861819326`, job `100987750213`;
- dedicated `NtCancelIoFileEx` YY probe: PASS.

Full Firefox integration later removed `NtCancelIoFileEx` from final production `xul.dll`, leaving the XP-side native boundary at `NtCancelIoFile`. This line remains closed unless contradictory final-PE or physical-runtime evidence appears.

### ADVAPI32 ETW family

The physical browser from source `622a87625036e9c45a8650264336eceeb9be8753`, run `33864176444`, job `100995134125`, runtime artifact `9937355457` advanced past earlier failures and stopped at missing `ADVAPI32.dll!EventRegister`. The final `xul.dll` owned the four-name family:

```text
EventRegister
EventUnregister
EventWrite
EventWriteTransfer
```

Focused YY capability for all four names passed at source `53971dcfdf12e7bcd7f35692ff2c02fb3360d792`, run `33882235341`, job `101053403554`. Later full-build integration closed the production ETW imports. Do not leave ETW as current backlog.

### ANGLE / DXGI

The earlier broad static blocker:

```text
libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1
```

was owned by separately linked `libGLESv2.dll`, not by `xul.dll`. Later compatibility work removed this XP-incompatible static edge while preserving the intended D3D9 fallback path. Do not reopen this line merely because physical XP lacks `dxgi.dll`.

### WS2_32

The observed WS2_32 family, including focused capability for `WSAIoctl` / `inet_ntop` and later integration work for `WSASendMsg` / `WSCGetProviderInfo`, is incorporated into the current lineage. Reopen only on contradictory exact import/runtime evidence.

## Current physical XP system-DLL baseline

The current physical XP machine has previously reported:

```text
%SystemRoot%\System32\propsys.dll          absent
%SystemRoot%\System32\dxgi.dll             absent
%SystemRoot%\System32\UIAutomationCore.dll present, 158048 bytes, 2010-03-18 10:09
%SystemRoot%\System32\ncrypt.dll           absent
```

Interpretation under the current lineage:

- `propsys.dll` absence is historical context because production `xul.dll` no longer carries the ordinary PROPSYS dependency;
- `dxgi.dll` absence is historical context because the static `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` edge was removed;
- `ncrypt.dll` absence matters only if exact runtime or mandatory static evidence reaches that surface; it is not currently promoted to a blocker;
- `UIAutomationCore.dll` presence eliminates the simplest missing-module hypothesis but does not prove every required UIA export/path is XP-compatible.

## Planned NCRYPT source-level remediation if evidence reaches it

Status: **pre-agreed plan only.** There is no exact current run/artifact proving NCRYPT as the next startup or ordinary-browsing blocker, so do not implement this merely because the physical XP system lacks `ncrypt.dll`.

Firefox 153 already contains both Windows private-key paths in `security/manager/ssl/osclientcerts/src/backend_windows.rs`:

```text
KeyHandle::NCrypt
  -> NCryptSignHash
  -> NCryptFreeObject

KeyHandle::CryptoAPI
  -> CryptSignHashW
  -> CryptReleaseContext
```

If NCRYPT becomes a real boundary:

1. introduce one explicit project-owned Rust XP condition for the affected crate/build path;
2. under that condition, stop preferring NCrypt during `CryptAcquireCertificatePrivateKey` and select the existing CryptoAPI path;
3. compile out NCrypt-only code where required to remove hard `ncrypt.dll` imports;
4. keep non-XP Windows builds unchanged;
5. add a build/source gate proving the Rust XP condition is active;
6. add a strict final PE/import gate for the exact owner;
7. revalidate Firefox's ordinary OS client-certificate behavior on the exact rebuilt artifact if required.

Architecture rule: prefer source-level compile-time selection of Firefox's existing legacy CryptoAPI backend before any YY-Thunks solution for NCRYPT. Do not emulate the complete CNG/KSP subsystem on XP preemptively.

## Closed families — do not reopen without contradictory evidence

- pinned/restored msvcr14x XP runtime contract;
- SRW / condition-variable closure;
- `CreateWaitableTimerExA` fallback;
- exact app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` staging/package path;
- narrow YY residual KERNEL32 providers including `TryAcquireSRWLockExclusive` and `FlsGetValue`;
- focused + full-integration `NtCancelIoFileEx` narrow-YY closure;
- ADVAPI32 ETW focused + full Firefox integration closure for the observed four-name family;
- KERNEL32 source-remediation quartet at final-production 0/4;
- final-production `xul.dll -> PROPSYS.dll` ordinary-dependency closure;
- historical `SetProcessDPIAware` root-cause diagnosis and source/static DPI remediation;
- IP Helper observed compatibility family in the physically advanced lineage;
- WS2_32 observed compatibility family integration;
- ANGLE/DXGI `CreateDXGIFactory1` static closure;
- YY-Thunks DLL/TLS entry-point integration for `xul.dll` with physical advancement past the old critical-section failure;
- current strong-candidate YY DLL entry-point/TLS static inventory at `13/13`, `missing=0`, run `34138054280`, source `688513...`;
- historical curated broad-gate `69 -> 3 -> 0` progression.

A new family-specific contradiction is required to reopen any of them.

## Next experiment order

1. **Keep the YY result classified correctly.** Run `34138054280` statically closes current strong-candidate YY DLL startup coverage at `13/13`; its aggregate RED comes from the flawed supplemental warm-relink experiment and is not a failed Firefox build. Do not schedule separate library builds just to repeat the same proof.
2. **Diagnose the current physical SharedPrefMap blocker.** Instrument `SharedMemoryPlatform_windows.cpp::Platform::Map` and capture the immediate `GetLastError()` plus sanitized mapping/handle context on the next exact build/runtime pair.
3. **Keep the Moz2D replay assert separate.** Investigate it only if it persists or becomes the primary boundary after SharedPrefMap is understood.
4. **Investigate optional modern surfaces only when evidence reaches them.** WinRT API sets, UIAutomationCore, NCRYPT, AVRT, DWMAPI and similar paths remain hypotheses until exact runtime/static evidence promotes them.
5. **GOST TLS on XP remains later and separate.** A browser that starts and browses on XP still does not prove MSSPI/CryptoPro GOST TLS behavior.

# Acceptance boundary

A browser is not accepted as XP-compatible merely because the workflow is GREEN or because static YY entry-point coverage is complete. Acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for the shipped/runtime-required PE closure;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use.

Likewise, successful XP startup does not establish any GOST TLS handshake result.