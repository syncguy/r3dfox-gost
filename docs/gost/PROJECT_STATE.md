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

## Current all-GREEN build/static candidate

Latest built and physically exercised source-under-test:

- branch `agent/winrt-source-poc`;
- SHA `897e1cdf98bcc091e13283fa8004177971d30f27`;
- functional launcher remediation commit `3b95f3dc9755b84c0b392fe9b90a896dd5a00880` (`fix(xp): inherit child handles without thread attributes`).

Exact completed full build:

- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- run `34194737456`, attempt `1`;
- job `101959901573` (`Windows x86 / r3dfox GOST / XP SP3 full build`);
- aggregate conclusion: **success / GREEN**.

Exact artifacts:

- package `10048182039`, digest `sha256:b9d79e74656057b4252c4c12d250f5230d5ee191f0dd7ba839fce805a60c6710`;
- runtime `10048183305`, digest `sha256:678e93d526d4d8837360e3dafb16d8e3147b09e8bbb4416b5e3773a746770a65`;
- diagnostics `10048220926`, digest `sha256:d44ca9f6c3afe4f9df336d315279d6c214f0c7c80bad454a125c7af5db5a8445`.

The exact run passed full compile/link, packaging, runtime archive generation, current XP PE/import gates, YY-Thunks inventory, artifact uploads and the final summary. This remains build/static evidence only; physical runtime conclusions are recorded separately below.

## SharedPrefMap child-HANDLE blocker — PHYSICALLY CLOSED on `897e1cdf...`

The preceding exact build `cae81ff9798f759b9a2b162e3455a8ddf382c8ad` repeatedly failed on physical XP at:

```text
mozilla::SharedPrefMap::SharedPrefMap(...)
modules/libpref/SharedPrefMap.cpp:25
MOZ_RELEASE_ASSERT(map)
exception 0x80000003
```

Matching WinDbg evidence on that build established:

```text
MapViewOfFileEx(...) -> NULL
GetLastError() = 6 = ERROR_INVALID_HANDLE
LastStatusValue = 0xC0000008 = STATUS_INVALID_HANDLE
```

The failing socket child received the exact numeric `-prefMapHandle` value and size, but the corresponding kernel HANDLE had not been inherited. Source tracing localized the defect to `base::LaunchApp`: on XP the Vista+ `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` API is unavailable, so the old code left `bInheritHandles = FALSE` even after requested handles had been marked `HANDLE_FLAG_INHERIT`.

The remediation in `ipc/chromium/src/base/process_util_win.cc` preserves the Vista+ selective attribute-list path and, under `MOZ_XP_COMPAT`, enables classic Windows inheritance when that Vista+ API is unavailable.

Physical Windows XP SP3 x86 testing of exact source `897e1cdf...` was repeated several times. User-reported binary identities:

- `r3dfox.exe` SHA-1 `dbfaed8d2d06d50195a572f8364186e4032f8a97`;
- `xul.dll` SHA-1 `fcc09439c4e36be056b5796303f7e433a7afe585`.

Across those launches, the previous `SharedPrefMap.cpp:25` / `0x80000003` boundary no longer reproduces. Execution consistently advances to a later exception code:

```text
0xC06D007F
```

Conclusion: **the SharedPrefMap invalid-child-HANDLE blocker is physically closed for source `897e1cdf...` / run `34194737456`.** Do not reopen it without contradictory evidence on a later exact artifact.

## Current physical-XP boundary — `0xC06D007F`

The first repeatedly observed later boundary on the current exact artifact is exception code `0xC06D007F`.

Current evidence does not yet identify the owning module, missing/delayed procedure, stack frame, or source line. Do not guess the owner from the exception code alone. The next runtime analysis must establish the exact module/API/stack boundary before changing code.

## Rejected `Platform::Freeze()` access-mask override removed from source

The earlier XP-only `Platform::Freeze()` experiment changed:

```text
GENERIC_READ | FILE_MAP_READ
```

to:

```text
FILE_MAP_READ | SECTION_QUERY
```

It independently failed to advance the SharedPrefMap boundary on source `cae81ff...`, while the later launcher inheritance fix physically advanced past that boundary on source `897e1cdf...`.

The rejected override has now been removed from the implementation branch without touching the successful launcher remediation:

- new implementation HEAD `dad33d25dddc060ee74d773dcc492d835a78fd1e`;
- commit `fix(xp): drop rejected shared-memory access override`;
- only changed file: `ipc/glue/SharedMemoryPlatform_windows.cpp`;
- diff versus `897e1cdf...`: exactly three deleted lines, restoring the common `GENERIC_READ | FILE_MAP_READ` path.

No heavy Firefox rebuild is being started solely for this cleanup. The next full XP build should first include the precise remediation for the new `0xC06D007F` boundary; that same build will serve as the causal control proving that SharedPrefMap remains passed without the rejected access-mask override.

## Latest YY DLL entry-point/TLS static coverage — 13/13 CLOSED

Run `34138054280`, job `101793510758`, source-under-test `6885135565f7262bb88c80c4751f4a6c4b93e3ef` expanded the scoped YY-Thunks DLL/TLS startup contract from 3/13 to 13/13 strong candidates. Its normal Firefox compile/link, package/runtime generation, PE/import audit and final YY contract audit succeeded. The aggregate job was RED only because a separate supplemental warm-relink experiment used incorrect generated-objdir assumptions.

The 13/13 static closure remains valid and does not need separate per-library rebuilds.

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
- current 13-strong-candidate YY DLL entry-point/TLS static coverage debt.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**.

Current physical evidence remains source `897e1cdf...` / run `34194737456`: it is all-GREEN at build/static level and physically advances beyond the former SharedPrefMap blocker to `0xC06D007F`. Current implementation HEAD `dad33d25...` removes only the rejected shared-memory access override and has not yet been rebuilt. First localize and remediate the new exact API/runtime boundary; then use the next full build to validate both that remediation and continued SharedPrefMap closure without the rejected override. XP runtime success would still not prove a GOST TLS handshake.

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