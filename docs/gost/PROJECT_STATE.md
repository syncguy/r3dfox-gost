# r3dfox GOST TLS — Project State

Last updated: 2026-09-08

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

## Current completed all-GREEN build/static baseline

Latest fully completed all-GREEN source/build pair remains:

- source-under-test `cae81ff9798f759b9a2b162e3455a8ddf382c8ad` (`fix(xp): use section-specific rights for frozen shared memory`);
- run `34146514899`, attempt `1`;
- job `101819627976` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success**.

Exact artifacts:

- package `10031193476`, digest `sha256:196cc57802dd626e01cdb1e9ad9946c038f4d61ce6e48bbc305feec852d907e6`;
- runtime `10031194866`, digest `sha256:6b0e64bb02ad7938d14efdaddf41ebea9a6f2cd0973b07c050d0219b07053867`;
- diagnostics `10031215333`, digest `sha256:5be1bc9ec15ab877602919b90b6988e532481f8d65db696f68c9fffdd3de75cd`.

The build, packaging, runtime archive, current XP PE/import gates, matching-PDB diagnostics, YY-Thunks inventory, uploads and final summary are GREEN. This is build/static evidence only, not physical-XP acceptance.

The exact package was physically tested and the reported hashes match it:

- `r3dfox.exe` SHA-1 `9f3f03ceb2d767982f1e83aff20703af1ba740d8`;
- `xul.dll` SHA-1 `d1b57749d82bac77030c98d26b9b13019e8e4274`.

## Latest YY DLL entry-point/TLS static coverage — 13/13 CLOSED

Run `34138054280`, job `101793510758`, source-under-test `6885135565f7262bb88c80c4751f4a6c4b93e3ef` expanded the scoped YY-Thunks DLL/TLS startup contract from 3/13 to 13/13 strong candidates. Its normal Firefox compile/link, package/runtime generation, PE/import audit and final YY contract audit succeeded. The aggregate job was RED only because a separate supplemental warm-relink experiment used incorrect generated-objdir assumptions.

The 13/13 static closure remains valid and does not need separate per-library rebuilds. It is independent of the physical shared-memory child-handle blocker below.

## Physical XP blocker localized — shared-pref HANDLE is not inherited into the child process

The `cae81ff...` browser repeatedly failed at:

```text
mozilla::SharedPrefMap::SharedPrefMap(...)
modules/libpref/SharedPrefMap.cpp:25
MOZ_RELEASE_ASSERT(map)
```

The preceding access-mask experiment is rejected: changing XP `Platform::Freeze()` from `GENERIC_READ | FILE_MAP_READ` to `FILE_MAP_READ | SECTION_QUERY` did not advance the physical boundary.

A subsequent WinDbg session on the exact same `cae81ff...` build established the missing runtime fact. A breakpoint immediately after `MapViewOfFileEx` in `mozilla::ipc::shared_memory::Platform::Map` showed:

```text
MapViewOfFileEx(...) -> NULL
GetLastError() = 6 = ERROR_INVALID_HANDLE
LastStatusValue = 0xC0000008 = STATUS_INVALID_HANDLE
```

For the failing socket child process, the command line contained:

```text
-prefMapHandle 5388:295474
```

and the `HandleBase` reaching `Platform::Map` contained the exact same values:

```text
mHandle = 0x0000150c = 5388
mSize   = 0x00048232 = 295474
```

Therefore the parser, `ReadOnlySharedMemoryHandle`, and mapping size are not corrupting the argument. The child receives the numeric value but does not own a live kernel HANDLE with that value.

### Root cause in the Windows launcher

Source tracing closes the path:

```text
SharedPreferenceSerializer
  -> GeckoArgs::SerializeHandleArgument
  -> ChildProcessArgs::mFiles
  -> WindowsProcessLauncher::DoSetup
  -> LaunchOptions::handles_to_inherit
  -> base::LaunchApp
  -> SetHandleInformation(..., HANDLE_FLAG_INHERIT)
  -> CreateThreadAttributeList(...)
  -> CreateProcess(..., bInheritHandles, ...)
```

On Windows, `GeckoArgs` intentionally serializes child handles by numeric identity. `base::LaunchApp` marks the requested handles inheritable. On Vista+ it then builds `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` and sets `bInheritHandles = TRUE` only when that list succeeds.

Windows XP does not provide `InitializeProcThreadAttributeList` / `UpdateProcThreadAttribute`, so `CreateThreadAttributeList()` returns `NULL`. The old code left `bInheritHandles = FALSE`, causing `CreateProcess` not to inherit the already-marked handles even though their numeric values were still emitted in `-prefsHandle` / `-prefMapHandle`.

Interpretation: **CURRENT ROOT CAUSE = XP CHILD-PROCESS HANDLE INHERITANCE GAP IN `base::LaunchApp`.** `MapViewOfFileEx` is only where the missing child handle becomes visible.

## Current source remediation and validation build

Functional remediation commit:

- `3b95f3dc9755b84c0b392fe9b90a896dd5a00880` — `fix(xp): inherit child handles without thread attributes`.

Current implementation HEAD/source-under-test:

- branch `agent/winrt-source-poc`;
- SHA `897e1cdf98bcc091e13283fa8004177971d30f27`;
- the HEAD commit after the functional fix only restores unrelated loop formatting.

Changed compatibility behavior in `ipc/chromium/src/base/process_util_win.cc`:

- Vista+ continues to use the selective `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` path unchanged;
- under `MOZ_XP_COMPAT`, if requested inheritable handles exist but the Vista+ attribute-list API is unavailable, `bInheritHandles` becomes `TRUE`, enabling classic Windows handle inheritance for handles already marked `HANDLE_FLAG_INHERIT`.

Build-configuration identity:

- C/C++ `MOZ_XP_COMPAT` is supplied through XP `CFLAGS` / `CXXFLAGS` as `-DMOZ_XP_COMPAT`;
- Rust uses the separate job-global `RUSTFLAGS="--cfg moz_xp_compat"`;
- do not infer a `moz.build` `CONFIG["MOZ_XP_COMPAT"]` variable from either of those flags.

Exact validation run currently in progress:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34194737456`, attempt `1`;
- job `101959901573` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- source-under-test `897e1cdf98bcc091e13283fa8004177971d30f27`;
- state at documentation time: **in progress**; bootstrap was running and full build/package/static gates were still pending.

This run must not be called GREEN until it actually completes.

## Current next experiment

1. Evaluate exact run `34194737456` only after completion, preserving run/job/source identity.
2. If successful, physically test its exact package/runtime artifact on Windows XP SP3 x86.
3. The decisive criterion for this remediation is that child processes advance past `SharedPrefMap.cpp:25` without `ERROR_INVALID_HANDLE` on the preference shared-memory handle.
4. If startup advances, record the next actual physical boundary before changing another subsystem.

Do not weaken `MOZ_RELEASE_ASSERT(map)` and do not add a speculative `MapViewOfFileEx` workaround. The current diagnosis points to process-launch handle inheritance, not mapping protection semantics.

## Separate physical symptom — Moz2D replay failure

One event in the current Dr. Watson capture resolves to `gfx/webrender_bindings/Moz2DImageRenderer.cpp:487`, where replay failure reaches `MOZ_RELEASE_ASSERT(false)`. Treat this as a separate GFX symptom; it is not established as the cause of the repeated SharedPrefMap failures.

## Correction of the previous Wasm attribution

The old attribution of repeated `MOZ_RELEASE_ASSERT(map)` to `js/src/wasm/WasmProcess.cpp` remains superseded. Matching-PDB evidence resolves the physically reached address to `modules/libpref/SharedPrefMap.cpp:25`, and WinDbg now further localizes the failure to an invalid child-process shared-memory HANDLE.

## Earlier physical/runtime boundaries closed in the current lineage

Do not reopen these without contradictory evidence on a later exact artifact:

- `xul.dll` `ntdll!RtlpWaitForCriticalSection` startup failure;
- preceding IP Helper runtime boundary;
- `USER32!SetProcessDPIAware` delay-load boundary;
- `NtCancelIoFileEx`;
- ADVAPI32 ETW family;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import dependency;
- WS2_32 observed compatibility family;
- ANGLE/DXGI static `CreateDXGIFactory1` edge;
- current 13-strong-candidate YY DLL entry-point/TLS static coverage debt.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**.

Current state: `cae81ff...` / run `34146514899` is the latest completed all-GREEN build/static baseline but physically fails because child preference shared-memory handles are not inherited. Source `897e1cdf...` contains the launcher remediation and is under validation in run `34194737456`. Physical XP runtime closure remains pending. XP runtime success would still not prove a GOST TLS handshake.

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