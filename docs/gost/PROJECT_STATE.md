# r3dfox GOST TLS — Project State

Last updated: 2026-09-06

This file is the authoritative current technical synthesis and handoff for new chats. The immediately preceding synthesis is preserved unchanged in [`PROJECT_STATE_2026-09-06_pre_full_xp_green.md`](./PROJECT_STATE_2026-09-06_pre_full_xp_green.md). Detailed experiment evidence belongs in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; closed milestones are in `DONE.md`; pending work is in `TODO.md`; workflow roles are in `WORKFLOWS.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and canonical documentation source: `agent/gost-tls-poc`.
- Current default-branch HEAD before this documentation update: `09d7e1bf5a330dd4609d07c73b649bc817ab0301` (`docs(xp): close focused WS2_32 YY pair`).
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

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. Win7 x86 runtime success is not XP import closure. Documentation HEADs never replace the exact source-under-test SHA for an earlier artifact.

# GOST TLS runtime

No GOST-runtime conclusion changes as a result of the XP build described below.

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

## Current status — full build/static closure is GREEN

The newest authoritative full XP x32 build is:

- source branch: `agent/winrt-source-poc`;
- source-under-test: `176eb94b503e773334593508df408fa491faa45f`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml` / `GOST TLS PoC build  XP x32`;
- Actions run `34027798932`, attempt `1`;
- job `101471779766`;
- aggregate conclusion: **success**;
- package artifact `9989656813`, digest `sha256:67e490b43001c092f2cb403d88273fd722b9cec5d6b72d1c2bcea02f74fea886`;
- runtime artifact `9989657830`, digest `sha256:64b0f5a0ccf94900fa882069369e26d3beaf46fa128f7b6b650c44d1e87c2c2f`;
- diagnostics artifact `9989658809`, digest `sha256:9e3e9e2e6fac3f0a33a17d94bdf0460edd1020c61c388307a2f8ccd78e2f50fb`.

All substantive build, packaging, compatibility/import evidence and final summary gates completed successfully. This is the current full-build candidate after walking through the presently discovered build/static blockers in the XP line.

**Current interpretation:** the build/link/static-import phase is no longer the active blocker for this exact candidate. All blockers currently known to the workflow/audit line have been closed sufficiently for the full Firefox 153 XP x86 build to go GREEN.

**Current blocker / next acceptance boundary:** physical Windows XP SP3 x86 runtime validation of exact runtime artifact `9989657830`. A new runtime-only missing export, delay-load edge or behavioral incompatibility may still appear and must be treated as a new runtime blocker rather than retroactively invalidating the GREEN build result.

A GREEN CI build does **not** prove:

- successful startup on physical XP;
- representative browser operation on XP;
- exhaustive absence of every possible runtime-only incompatibility;
- GOST TLS handshake success.

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
- ANGLE/DXGI work removing the XP-incompatible static `libGLESv2.dll -> dxgi.dll!CreateDXGIFactory1` edge while preserving the intended D3D9 fallback path.

Historical source/run/job/artifact identities for each individual closure remain authoritative in `TEST_LOG_2026-09-06_pre_full_xp_green.md` and earlier dated test-log volumes. Do not reopen a focused capability already proven there unless contradictory evidence appears.

Full YY `kernel32.lib` interposition remains prohibited. Keep compatibility ownership physically narrow by PE/provider/source owner.

## Relevant predecessor runtime evidence

The previous physical XP line exposed real runtime blockers in sequence even when builds had already advanced substantially. In particular, the exact older artifact from run `33757305364` first exposed the confirmed `USER32.dll!SetProcessDPIAware` delay-load failure, and a later exact runtime artifact from run `33966267770` exposed `WS2_32!WSASendMsg` on physical XP. Those observations remain historical evidence for those exact artifacts; they are not automatically attributable to the new GREEN artifact.

The new build must therefore be tested from its own exact artifact identity rather than inferred from older physical runs.

## Mandatory `MOZ_XP_COMPAT` build rule

`MOZ_XP_COMPAT` remains the preferred project-owned compile-time signal where an XP release intentionally removes or bypasses a modern Windows feature/runtime edge with no useful XP semantic equivalent.

The canonical XP full-build workflow intentionally supplies build-wide XP identity:

```sh
export CFLAGS="$CFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
export CXXFLAGS="$CXXFLAGS -DMOZ_NO_WINRT -DMOZ_XP_COMPAT"
```

Every production translation unit containing a dedicated accepted `MOZ_XP_COMPAT` boundary should also record source-local ownership where practical. Do not add XP compatibility defines to ordinary non-XP build configurations merely for convenience.

Authoritative rules and current owners: `XP_MOZ_XP_COMPAT_CONTRACT.md`.

## XP acceptance boundary

The current GREEN workflow establishes a major milestone, but final XP acceptance still requires:

1. exact source-under-test SHA;
2. exact run/job identity;
3. inventory-driven ordinary/delay import evidence for shipped/runtime-required PEs;
4. exact package/runtime/diagnostics artifact IDs and hashes;
5. physical Windows XP startup and representative browser use of that exact artifact.

A curated known-API list is a regression gate, not exhaustive compatibility proof. A successful XP startup is also not a GOST TLS handshake result.

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