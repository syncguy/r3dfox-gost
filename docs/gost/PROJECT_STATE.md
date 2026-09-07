# r3dfox GOST TLS — Project State

Last updated: 2026-09-07

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

## Current implementation and exact GREEN build/static baseline

Current tested implementation source:

- branch `agent/winrt-source-poc`;
- source-under-test `cd5e7155b0f227a22b7c35a0a44e2e24f69456d4` (`fix(xp): use legacy ProgramData shell folder`).

Exact completed full build:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34107793132`, attempt `1`;
- job `101696721232` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success**.

Exact artifacts:

- package `10018222073` (`r3dfox-gost-xp-x32-package`), digest `sha256:e2d535dc622c67cffb754f8bcafbb6d89127e7cdd7d0e40a298c2f675fda5b38`;
- runtime `10018223364` (`r3dfox-gost-xp-x32-runtime`), digest `sha256:ea39193e3f8422ee5e35bbe8f830cef936bb45273eff299392480c17357db61d`;
- diagnostics `10018257313` (`r3dfox-gost-xp-x32-diagnostics`), digest `sha256:8a4f3939b2bf8d30837060172b7cf4dc5de58dcb4a2b06a4a2e9d7220945a325`.

The build, packaging, runtime archive, current XP PE/import gates, matching-PDB diagnostics, YY-Thunks inventory, uploads and final summary are GREEN. This is the authoritative build/static baseline for the current Shell32 source cluster. It is not physical-XP acceptance.

## Current physical-XP blocker — `SharedPrefMap` read-only mapping failure

The exact `cd5e715...` browser above has now been physically executed on Windows XP SP3 x86 with:

```bat
set MOZ_GFX_CRASH_MOZ_CRASH=
r3dfox.exe
```

The supplied Dr. Watson capture contains ten `0x80000003` hardcoded-breakpoint exceptions. Nine processes fail at the same `xul.dll` location:

```text
xul load base  0x01bb0000
fault VA       0x01e348e6
fault RVA      0x002848e6
instruction    int 3
```

Exact binary/symbol identity from the same run:

- `xul.dll`: 155,288,576 bytes, SHA-256 `ba777e5f72332aa93151c068d82c9ea877a2826bf0058393db680ec6fd595e0e`;
- matching `xul.pdb`: 1,864,507,392 bytes, SHA-256 `5748e64d3cfd335a02fac2ec2e906d20db9527d6c7c4151cce89e2ae8c06f326`.

Exact-binary disassembly resolves the repeated fault to:

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

Therefore the current primary blocker is that `ReadOnlySharedMemoryHandle::Map()` returns an invalid mapping on physical XP.

On Windows this path reaches `ipc/glue/SharedMemoryPlatform_windows.cpp::Platform::Map`, which calls `MapViewOfFileEx` with `FILE_MAP_READ` for read-only mappings. The function returns `NULL` in the failing path. The current capture does not preserve `GetLastError()`, so the exact reason is still open: handle rights/duplication, IPC/sandbox transfer, or XP mapping semantics remain hypotheses.

### Correction of the previous Wasm attribution

The earlier repeated `MOZ_RELEASE_ASSERT(map)` symptom was attributed to `js/src/wasm/WasmProcess.cpp` because the crash-reason string was known but the exact source line was not.

That attribution is now **superseded**. The exact `cd5e715...` binary contains multiple references to the same assertion string. The Wasm references carry embedded source lines 58, 73 and 254; the physically reached breakpoint carries source line 25, matching `modules/libpref/SharedPrefMap.cpp` exactly.

Do not investigate `sThreadSafeCodeBlockMap` as the current primary blocker unless later exact evidence points back to a Wasm line.

## Separate physical symptom — Moz2D replay failure

One of the ten Dr. Watson events, PID `3036`, fails at a different location:

```text
fault VA       0x02da8533
fault RVA      0x011f8533
instruction    int 3
```

Exact-binary analysis resolves this to `gfx/webrender_bindings/Moz2DImageRenderer.cpp`, line 487: `translator.TranslateRecording(...)` returned false, emitted `Replay failure: ...`, then reached `MOZ_RELEASE_ASSERT(false)`.

Treat this as a separate GFX symptom. It is not currently established as the cause of the nine repeated SharedPrefMap failures.

## Shell32 source cluster — build validated; old physical boundary advanced past

Current source lineage contains XP-owned `MOZ_XP_COMPAT` fallbacks for the observed `SHGetKnownFolderPath` family, including:

- `toolkit/xre/nsXREDirProvider.cpp`: XP uses `SHGetFolderPathW` with legacy CSIDL values;
- `xpcom/io/SpecialSystemDirectory.cpp`: XP Downloads path avoids the Vista+ known-folder API;
- update ProgramData handling uses `SHGetFolderPathW(CSIDL_COMMON_APPDATA...)` under XP compatibility.

The exact `cd5e715...` full build is GREEN with these changes. In the new physical run the old `SHELL32!SHGetKnownFolderPath` delay-load failure is not the first reached boundary; execution advances to SharedPrefMap shared-memory mapping.

This does not prove every residual Shell32 path is physically closed. Keep remaining candidates evidence-driven.

## Earlier physical/runtime boundaries closed in the current lineage

Do not reopen these without contradictory evidence on a later exact artifact:

- `xul.dll` `ntdll!RtlpWaitForCriticalSection` startup failure: physically advanced past after xul YY DLL/TLS entry-point integration, source `b386b7f4...`, run `34038288272`, job `101500284497`, runtime artifact `9992440155`;
- preceding IP Helper runtime boundary: physically advanced past by source `0a18ba85...`, run `34079480996`, job `101611911453`;
- `USER32!SetProcessDPIAware` delay-load boundary;
- `NtCancelIoFileEx`;
- ADVAPI32 ETW family;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import dependency;
- WS2_32 observed compatibility family;
- ANGLE/DXGI static `CreateDXGIFactory1` edge.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## Current next experiment

Primary next experiment is **not** to suppress `MOZ_RELEASE_ASSERT(map)` and not to add a speculative shared-memory fallback.

Instrument the XP Windows shared-memory mapping failure narrowly in/around `ipc/glue/SharedMemoryPlatform_windows.cpp::Platform::Map` so that a failed `MapViewOfFileEx` records enough sanitized evidence to identify the actual Windows failure:

- `GetLastError()` immediately after `MapViewOfFileEx` returns `NULL`;
- whether the supplied handle is valid;
- mapping offset and size;
- read-only vs read/write mode;
- whether a fixed address was requested.

Then rebuild from the exact new source SHA and repeat the physical-XP launch. Only after the exact Windows error is known should we choose between handle-rights/duplication, IPC/sandbox transfer, or an XP-specific mapping remediation.

The single Moz2D replay assert remains a parallel secondary symptom; investigate it separately if it persists after the SharedPrefMap path is understood.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**.

Current state: build/static gates are GREEN at `cd5e715...`, but physical XP repeatedly fails at `SharedPrefMap.cpp:25` because the read-only preference shared-memory mapping is invalid. XP runtime success would still not prove a GOST TLS handshake.

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
