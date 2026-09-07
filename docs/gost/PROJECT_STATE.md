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

For Windows XP work, read `XP_BUILD_CONTRACT.md` and `XP_MOZ_XP_COMPAT_CONTRACT.md` before proposing build/configuration changes. For physical-XP startup/runtime work, also read `XP_RUNTIME_COMPATIBILITY_STATUS.md` and the newest XP entries in `TEST_LOG.md`.

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

The newest completed and authoritative full XP x32 build remains:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34038288272`, attempt `1`;
- job `101500284497`;
- aggregate conclusion: **success**;
- package artifact `9992439692`, digest `sha256:d38cee9081debcab2beedab3b8254574bbc85e6cc135f52839a6ec2bb58db651`;
- runtime artifact `9992440155`, digest `sha256:33731607bbef1e01cfe8b9063be56dd17f149bb9aae547349e7e5b6f5d8c32f4`;
- diagnostics artifact `9992440699`, digest `sha256:0820af3fdfc031ca10dc21546c5f4caee6080da7477aac4109c8e5a3be9fdc6f`.

All substantive build, packaging, compatibility/import evidence and final summary gates completed successfully. Relative to the preceding GREEN source `176eb94b503e773334593508df408fa491faa45f`, this source adds the workflow-level YY-Thunks DLL/TLS entry-point contract for `xul.dll` and the follow-up indentation correction required to apply that contract under the intended `xul-real` / `WINNT` scope:

```text
-ENTRY:DllMainCRTStartupForYY_Thunks
-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12
```

## Physical XP progression — `RtlpWaitForCriticalSection` CLOSED

The exact `b386b7f4...` browser has been physically executed on Windows XP SP3 x86. User-reported extracted-file identities for the browser actually run are:

- `r3dfox.exe` SHA-1 `a2a64f6eb719d632b6264d48984de9e85a82acb7`;
- `xul.dll` SHA-1 `7ef46570af15390fa1c431c9d1b93ff985d79c22`.

On this exact build, the previous early-startup `xul.dll` crash at `ntdll!RtlpWaitForCriticalSection` is no longer observed. Therefore the physical runtime boundary has advanced beyond the failure previously seen on source `176eb94b503e773334593508df408fa491faa45f`, run `34027798932`, job `101471779766`, runtime artifact `9989657830`.

The older artifact remains useful historical evidence: it failed with `C0000005` at `RtlpWaitForCriticalSection` through `RtlEnterCriticalSection -> xul.dll -> XRE_GetBootstrap`, with a null `RTL_CRITICAL_SECTION.DebugInfo` in the contended wait path. That failure must no longer be treated as the current blocker.

**Confirmed conclusion:** applying the YY-Thunks DLL/TLS entry-point contract in the `b386b7f4...` full browser correlates with physical progression past the exact old critical-section boundary. This closes the `RtlpWaitForCriticalSection` blocker for that exact browser. It does not establish full XP acceptance and does not prove anything about GOST TLS runtime.

## Current XP blocker family — IP Helper API compatibility

After the critical-section closure, active implementation work has moved to Windows XP IP Helper compatibility in `xul.dll` and its source owners. The implementation branch has advanced beyond `b386b7f4...`:

- `97ad36ef0322f307ccb43bc4dd5fdcc744a22f16` — `nsNotifyAddrListener.cpp` uses the XP-era `NotifyAddrChange` path instead of the Vista+ `NotifyIpInterfaceChange` path under `MOZ_XP_COMPAT`;
- `9ea33a7b2972e231c95157db416fe866e6f6c667` — the Windows network-listener source is explicitly compiled with the project XP compatibility condition;
- `7e4965bc2057f6f0a75d043f0711fefbcfddff68` — the vendored Rust `mtu` Windows path uses legacy adapter enumeration for XP instead of the modern IP interface-table path;
- `bc37171160d9cad9b81b81da681626b0dd9dcd2d` — refreshes the matching vendored `mtu` checksum;
- current implementation HEAD `0a18ba85b3f493b17c5a62742e869788ca3f2f6b` — adds a final-`xul.dll` IPHLPAPI diagnostic covering the intended removal of `NotifyIpInterfaceChange`, `CancelMibChangeNotify2`, `GetIpInterfaceTable`, `FreeMibTable`, and `if_indextoname`, while retaining `GetAdaptersAddresses` and `GetBestInterfaceEx` as the intended XP-side legacy boundary.

Current validation is provisional:

- workflow `GOST TLS PoC build  XP x32`;
- Actions run `34079480996`, attempt `1`;
- source-under-test `0a18ba85b3f493b17c5a62742e869788ca3f2f6b`;
- job `101611911453`;
- state at last check: **in progress**; full Firefox build step was still running and the IPHLPAPI diagnostic plus later package/static gates had not yet executed.

Do not promote the pending IPHLPAPI diagnostic to PASS until this exact run completes. Likewise, source remediation alone is not physical-XP proof; after a successful exact build, the resulting exact runtime artifact still requires physical execution to establish the next runtime boundary.

## Compatibility work incorporated into the current closure

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
- WS2_32 compatibility work, including the focused YY proof for `WSAIoctl` / `inet_ntop` and later integration work for `WSASendMsg` / `WSCGetProviderInfo`;
- ANGLE/DXGI work removing the XP-incompatible static `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` edge while preserving the intended D3D9 fallback path;
- YY-Thunks DLL/TLS entry-point integration scoped to `xul.dll`, physically proven to advance past the old `RtlpWaitForCriticalSection` crash.

Historical source/run/job/artifact identities for individual closures remain authoritative in `TEST_LOG.md`, `TEST_LOG_2026-09-06_pre_full_xp_green.md`, and earlier dated test-log volumes. Do not reopen a focused capability already proven there unless contradictory evidence appears.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**. The old `RtlpWaitForCriticalSection` failure is closed on runtime artifact `9992440155`, but current work has moved to the later IP Helper compatibility boundary and its successor source is still under full-build validation.

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