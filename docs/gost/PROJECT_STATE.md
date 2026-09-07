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

The implementation branch has since advanced for workflow/infrastructure changes; at the latest check its HEAD was `1dec42a35708a7e64197c7047cc19e10eb3ee85f`. That later implementation HEAD is not the source identity of the physically tested browser described below.

## Physical XP progression — earlier blockers CLOSED

The preceding exact `b386b7f4ba8fd20619a2b7ee541a6b8fe609e278` browser, run `34038288272`, job `101500284497`, runtime artifact `9992440155`, physically advanced beyond the old `ntdll!RtlpWaitForCriticalSection` startup crash. That blocker remains closed and must not be reopened without contradictory evidence on a later exact browser.

The newer exact `0a18ba85...` browser has now also been physically executed on Windows XP SP3 x86. The user reports that the preceding IP Helper runtime problem is no longer observed. This is consistent with the exact GREEN build's final IPHLPAPI diagnostic and establishes progression beyond that runtime boundary as well.

The same `0a18ba85...` build starts on physical Windows 7 x86, which remains a useful control showing that the browser is not generically broken on x86 Windows.

## Current XP blocker — repeated SpiderMonkey/Wasm `MOZ_RELEASE_ASSERT(map)`

The physical-XP Dr. Watson log for the exact `0a18ba85...` build is now the current runtime evidence. Supplied `drwtsn32.log` SHA-256:

`15e948215d79d0ce33b2980f5a562764bdc055df8fbdf519e7dea36dd7c3a151`

It contains six `0x80000003` (`hardcoded breakpoint`) exceptions between `12:54:42.642` and `12:55:10.313`. These are not six unrelated failures: all six distinct `r3dfox.exe` PIDs fault at the exact same `xul.dll` site:

- `xul.dll` load base `0x01bb0000`;
- fault VA `0x01e34926` / RVA `0x00284926`;
- instruction `CC` / `int 3`.

Disassembly and PE/string resolution against the exact `xul.dll` from package artifact `10005434231` prove that the intentional fatal path stores the crash-reason pointer immediately before the breakpoint, and that reason resolves to:

```text
MOZ_RELEASE_ASSERT(map)
```

The matching Firefox/SpiderMonkey owner is `js/src/wasm/WasmProcess.cpp`. In that source `map` is the process-wide `sThreadSafeCodeBlockMap`; the same release assertion guards `wasm::RegisterCodeBlock`, `wasm::UnregisterCodeBlock`, and `wasm::ShutDown`. Given the observed early-startup context, registration before successful process-map initialization is the leading interpretation, but the stripped Dr. Watson stack does not yet prove which inline call site emitted the assertion.

**Current conclusion:** the active XP blocker has moved from IP Helper compatibility to a SpiderMonkey/Wasm process-initialization invariant. The six exceptions represent repeated instances of one fatal path. The increase from the user's preceding observation of three hardcoded breakpoints can plausibly reflect more process instances/retries reaching the same latent assert after removal of the earlier IP Helper boundary; count growth alone does not establish additional root causes.

Because the identical build works on Win7 x86, the next investigation should concentrate on XP-only initialization semantics rather than network imports. The highest-priority area is the lifecycle that should initialize `sThreadSafeCodeBlockMap` before code-block registration, with special scrutiny on XP-only synchronization / TLS / one-time-init behavior and the narrow YY-Thunks path used by `xul.dll`. Do not suppress `MOZ_RELEASE_ASSERT(map)` as a fix; determine why the map is null.

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
- YY-Thunks DLL/TLS entry-point integration scoped to `xul.dll`, physically proven to advance past the old `RtlpWaitForCriticalSection` crash;
- source-level IP Helper remediation physically proven to advance beyond the preceding IP Helper runtime boundary on source `0a18ba85...`.

Historical source/run/job/artifact identities for individual closures remain authoritative in `TEST_LOG.md`, `TEST_LOG_2026-09-06_pre_full_xp_green.md`, and earlier dated test-log volumes. Do not reopen a focused capability already proven there unless contradictory evidence appears.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## XP acceptance boundary

Final XP acceptance still requires one exact candidate to start and sustain representative browser use on physical Windows XP. That boundary is **not yet met**. The old `RtlpWaitForCriticalSection` and subsequent IP Helper boundaries are closed on later exact candidates, but source `0a18ba85...` now repeatedly trips the SpiderMonkey/Wasm `MOZ_RELEASE_ASSERT(map)` fatal invariant on physical XP.

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