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

## Current all-GREEN build/static baseline

Current tested implementation source:

- branch `agent/winrt-source-poc`;
- source-under-test `cae81ff9798f759b9a2b162e3455a8ddf382c8ad` (`fix(xp): use section-specific rights for frozen shared memory`).

Exact completed full build:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34146514899`, attempt `1`;
- job `101819627976` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success**.

Exact artifacts:

- package `10031193476`, digest `sha256:196cc57802dd626e01cdb1e9ad9946c038f4d61ce6e48bbc305feec852d907e6`;
- runtime `10031194866`, digest `sha256:6b0e64bb02ad7938d14efdaddf41ebea9a6f2cd0973b07c050d0219b07053867`;
- diagnostics `10031215333`, digest `sha256:5be1bc9ec15ab877602919b90b6988e532481f8d65db696f68c9fffdd3de75cd`.

The build, packaging, runtime archive, current XP PE/import gates, matching-PDB diagnostics, YY-Thunks inventory, uploads and final summary are GREEN. This is the current all-GREEN build/static baseline. It is not physical-XP acceptance.

The user physically tested the exact package artifact. Reported hashes match the package exactly:

- `r3dfox.exe` SHA-1 `9f3f03ceb2d767982f1e83aff20703af1ba740d8`;
- `xul.dll` SHA-1 `d1b57749d82bac77030c98d26b9b13019e8e4274`.

## Latest YY DLL entry-point/TLS static coverage — 13/13 CLOSED

Run `34138054280`, job `101793510758`, source-under-test `6885135565f7262bb88c80c4751f4a6c4b93e3ef` expanded the scoped YY-Thunks DLL/TLS startup contract from 3/13 to 13/13 strong candidates. Its normal Firefox compile/link, package/runtime generation, PE/import audit and final YY contract audit succeeded. The aggregate job is RED only because a separate supplemental warm-relink experiment used incorrect generated-objdir assumptions.

The 13/13 static closure therefore remains valid and does not need separate per-library rebuilds. It is independent of the physical SharedPrefMap runtime blocker below.

## Current physical-XP blocker — `SharedPrefMap` read-only mapping failure

The exact current `cae81ff...` browser was physically executed on Windows XP SP3 x86 with:

```bat
set MOZ_GFX_CRASH_MOZ_CRASH=
r3dfox.exe
```

The supplied current Dr. Watson capture contains eight `0x80000003` events. Seven processes fail at the same `xul.dll` location as the preceding build:

```text
xul load base  0x01bb0000
fault VA       0x01e348e6
fault RVA      0x002848e6
instruction    int 3
```

Exact matching-PDB symbolization resolves the repeated fault to:

```text
mozilla::SharedPrefMap::SharedPrefMap(...)
modules/libpref/SharedPrefMap.cpp:25
MOZ_RELEASE_ASSERT(map)
```

Exact current binary/symbol identity:

- `xul.dll` SHA-256 `e0d72150fc592bf5737c2ca28c3d49b342c3ea7ae6b6314e1a7cae40c2d96d95`;
- matching `xul.pdb` SHA-256 `18717ff9f3eda0321cdf7d1a3c9fc51e469bc4b914364acd73381e6d64fe6a18`.

The source path remains:

```cpp
auto map = aMapHandle.Map();
MOZ_RELEASE_ASSERT(map);
```

Therefore the current primary blocker remains that `ReadOnlySharedMemoryHandle::Map()` returns an invalid mapping on physical XP. On Windows this reaches `ipc/glue/SharedMemoryPlatform_windows.cpp::Platform::Map`, where `MapViewOfFileEx` is requested with `FILE_MAP_READ` and returns `NULL` on the failing path.

### Rejected hypothesis — frozen-handle access mask

Source `cae81ff...` changed the XP-only `Platform::Freeze()` duplicate access mask from:

```text
GENERIC_READ | FILE_MAP_READ
```

to:

```text
FILE_MAP_READ | SECTION_QUERY
```

The exact build is GREEN, but physical XP still reaches the identical `SharedPrefMap.cpp:25` breakpoint.

This negative result is meaningful: source tracing confirms `SharedPrefMapBuilder::Finalize()` uses `MemMapSnapshot`, and `MemMapSnapshot::Finalize()` calls `std::move(mMem).Freeze()`. Therefore the tested access-mask change was exercised on the relevant preference-map handle path.

Conclusion: **the local `Freeze()` access-mask hypothesis is rejected.** Do not repeat this change as if untested and do not treat `SECTION_QUERY` as the missing fix.

### Current next analysis target — post-Freeze handle transfer

Trace the already-frozen read-only handle after `Freeze()` through:

```text
SharedPrefMap::CloneHandle()
  -> HandleBase::Clone()
  -> Platform::CloneHandle()
  -> DuplicateFileHandle(..., DUPLICATE_SAME_ACCESS)
  -> IPC message attachment/serialization
  -> actual cross-process HANDLE transfer
  -> received HandleBase
  -> Platform::Map()
```

The local clone path already uses `DUPLICATE_SAME_ACCESS`, so it preserves the frozen handle's rights. The unresolved boundary is the actual Windows IPC target-process transfer / received-handle state, or an XP-specific mapping semantic after that transfer.

Do not weaken `MOZ_RELEASE_ASSERT(map)` and do not add a speculative mapping fallback. `GetLastError()` at the failed `MapViewOfFileEx` remains useful evidence if source analysis does not isolate a concrete XP/Win7 behavioral difference, but the immediate code-analysis focus is the post-Freeze interprocess transfer path rather than another `Freeze()` mask experiment.

## Separate physical symptom — Moz2D replay failure

One event in the current Dr. Watson capture again resolves to `gfx/webrender_bindings/Moz2DImageRenderer.cpp:487`, where replay failure reaches `MOZ_RELEASE_ASSERT(false)`. Treat this as a separate GFX symptom; it is not established as the cause of the seven repeated SharedPrefMap failures.

## Correction of the previous Wasm attribution

The old attribution of the repeated `MOZ_RELEASE_ASSERT(map)` to `js/src/wasm/WasmProcess.cpp` is superseded. Exact PDB evidence on two successive physical-XP artifacts resolves the reached address to `modules/libpref/SharedPrefMap.cpp:25`. Do not investigate `sThreadSafeCodeBlockMap` as the current primary blocker unless later exact evidence points back to a Wasm line.

## Shell32 source cluster — build validated; old physical boundary advanced past

Current source lineage contains XP-owned `MOZ_XP_COMPAT` fallbacks for the observed `SHGetKnownFolderPath` family, including legacy `SHGetFolderPathW`/CSIDL paths. Physical execution advances beyond the old Shell32 boundary and reaches SharedPrefMap shared-memory mapping. This does not prove every residual Shell32 path is closed; keep remaining candidates evidence-driven.

## Earlier physical/runtime boundaries closed in the current lineage

Do not reopen these without contradictory evidence on a later exact artifact:

- `xul.dll` `ntdll!RtlpWaitForCriticalSection` startup failure, physically advanced past after xul YY DLL/TLS entry-point integration;
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

Current state: all build/static gates are GREEN for source `cae81ff...` / run `34146514899`, but the exact artifact still repeatedly fails at `SharedPrefMap.cpp:25`. The `FILE_MAP_READ | SECTION_QUERY` frozen-handle experiment is rejected; next work is the post-Freeze cross-process HANDLE transfer / received mapping path. XP runtime success would still not prove a GOST TLS handshake.

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