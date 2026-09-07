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

## Current build/static baseline — GREEN

The newest authoritative full XP x32 build is:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34038288272`, attempt `1`;
- job `101500284497`;
- aggregate conclusion: **success**;
- package artifact `9992439692`, digest `sha256:d38cee9081debcab2beedab3b8254574bbc85e6cc135f52839a6ec2bb58db651`;
- runtime artifact `9992440155`, digest `sha256:33731607bbef1e01cfe8b9063be56dd17f149bb9aae547349e7e5b6f5d8c32f4`;
- diagnostics artifact `9992440699`, digest `sha256:0820af3fdfc031ca10dc21546c5f4caee6080da7477aac4109c8e5a3be9fdc6f`.

All substantive build, packaging, compatibility/import evidence and final summary gates completed successfully. Relative to the preceding GREEN source `176eb94b503e773334593508df408fa491faa45f`, this source adds the workflow-level YY-Thunks DLL/TLS entry-point contract for `xul.dll` and the follow-up indentation correction required to apply that contract under the intended `xul-real` / `WINNT` scope. The exact linker contract is:

```text
-ENTRY:DllMainCRTStartupForYY_Thunks
-alternatename:_YY_ThunksOriginalDllMainCRTStartup@12=__DllMainCRTStartup@12
```

The exact job's `Apply YY-Thunks XP DLL TLS entry point to xul.dll` step and the subsequent full Firefox compile/link/package/static gates are GREEN. Therefore build/link/static-import closure remains closed for this newer candidate.

## Current physical-runtime boundary

The newest build/static candidate `b386b7f4...` / runtime artifact `9992440155` has **not yet been physically classified on Windows XP**. Do not transfer the older runtime failure to this artifact merely because it descends from the same compatibility lineage.

The latest authoritative physical-runtime result still belongs to the preceding source/build:

- source-under-test `176eb94b503e773334593508df408fa491faa45f`;
- Actions run `34027798932`, job `101471779766`;
- runtime artifact `9989657830`, digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`.

For that exact artifact:

- Windows 7 x86: **PASS / starts and works** by user observation;
- Windows XP SP3 x86: **FAIL / startup access violation** with no current missing-import or missing-export dialog before the crash.

The supplied Dr. Watson log for that exact artifact, `drwtsn32.log` SHA-256 `d436c0056af14012fac84aa1b78afe607f61ceb6ba9229cffc9f211b5530d2f4`, records:

```text
Exception: C0000005
ntdll!RtlpWaitForCriticalSection
  -> ntdll!RtlEnterCriticalSection
  -> xul.dll
  -> xul!XRE_GetBootstrap
```

At the fault, XP executes `mov eax,[esi]` followed by `inc dword ptr [eax+0x10]`, with `EAX == 0`. For the x86 `RTL_CRITICAL_SECTION` layout this means the critical section's first field, `DebugInfo`, is null when XP reaches the contended wait path. XP then dereferences `NULL+0x10` and crashes.

**Current interpretation:** the known direct-import loader blockers remain closed, and the most recent physical-XP evidence reaches an early-runtime synchronization/initialization failure. The newer GREEN candidate now changes one plausible YY integration variable, but that variable has not yet been tested physically.

## Current root-cause status and next experiment

Root cause is **not yet proven**.

For the physically failing `176eb94b...` artifact, the exact diagnostics prove that the narrow YY provider contains the selected `InitializeCriticalSectionEx` weak alias and the shared `YY_Thunks_for_5.1.2600.0.obj` implementation. Disassembly of that exact implementation shows the XP fallback ignores the third `Flags` argument and calls `InitializeCriticalSectionAndSpinCount`. Therefore the specific hypothesis that this thunk directly forwards `CRITICAL_SECTION_NO_DEBUG_INFO` into XP is not supported by the exact object and should not be used as the explanation.

A separate YY integration concern was that the shared implementation object contains `DllMainCRTStartupForYY_Thunks` while the old full `xul.dll` link had not explicitly applied YY-Thunks' DLL/TLS entry-point contract. The new source `b386b7f4...`, run `34038288272`, job `101500284497` now incorporates that contract and remains fully GREEN at build/package/static level.

This build result does **not** establish that the contract fixes the XP crash. The decisive next experiment is physical Windows XP execution of exact runtime artifact `9992440155`. If it still fails at the same `RtlpWaitForCriticalSection` boundary, return to exact `xul.dll` owner/call-site localization and the initialization/corruption history of the specific critical section rather than broadening YY or synchronization changes. A Win7 x86 launch of the same artifact remains a useful regression check but is not XP acceptance.

## Compatibility work incorporated into the current closure

The current GREEN lineage follows the accumulated closure work already documented in the experiment log, including:

- SRW / condition-variable and narrow residual KERNEL32 compatibility;
- `CreateWaitableTimerExA` source fallback;
- selected XP-compatible `bcrypt.dll` packaging;
- legacy `D3DCompiler_47.dll` staging;
- `NtCancelIoFileEx` narrow YY-Thunks remediation and final `xul.dll` import closure;
- ADVAPI32 ETW family remediation;
- KERNEL32 restart/named-pipe source-remediation quartet;
- PROPSYS ordinary-import removal;
- DPI startup fix for `USER32.dll!SetProcessDPIAware`;
- WS2_32 compatibility work, including the focused YY proof for `WSAIoctl` / `inet_ntop` and later integration work for the previously missing `WSASendMsg` / `WSCGetProviderInfo` cases;
- ANGLE/DXGI work removing the XP-incompatible static `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` edge while preserving the intended D3D9 fallback path;
- YY-Thunks DLL/TLS entry-point integration scoped to `xul.dll` in the current full-build candidate.

Historical source/run/job/artifact identities for each individual closure remain authoritative in `TEST_LOG_2026-09-06_pre_full_xp_green.md` and earlier dated test-log volumes. Do not reopen a focused capability already proven there unless contradictory evidence appears.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is currently **not met**: the latest physically tested runtime artifact `9989657830` fails during early startup in `RtlpWaitForCriticalSection`, while the newer build/static baseline runtime artifact `9992440155` has not yet received physical-XP classification.

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