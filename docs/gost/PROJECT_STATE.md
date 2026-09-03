# r3dfox GOST TLS — Project State

Last updated: 2026-09-03

This file is the authoritative current technical synthesis and handoff for new chats.

## Canonical documentation location — read this first

All project documentation is maintained in the repository default branch `agent/gost-tls-poc`, under `docs/gost/`, regardless of which experimental/work branch contains the code being investigated.

Do not look for copies of the XP contracts/status documents in `agent/winrt-source-poc` or other experiment branches. For documentation, explicitly read `agent/gost-tls-poc:docs/gost/...`. Experimental branches are for code/workflow state and exact source-under-test identity; they do not relocate the documentation source of truth.

For Windows XP x86 work, the mandatory starting documents are therefore on `agent/gost-tls-poc`:

- `docs/gost/PROJECT_STATE.md`;
- `docs/gost/XP_BUILD_CONTRACT.md`;
- `docs/gost/XP_COMPATIBILITY_STRATEGY.md` when architectural strategy is relevant;
- `docs/gost/XP_SYNC_IMPORT_STATUS.md`, `XP_IMPORT_REMEDIATION.md`, `XP_PROPSYS_STATUS.md`, `XP_BCRYPT_STATUS.md`, `XP_CREATE_WAITABLE_TIMER_STATUS.md` as applicable;
- `docs/gost/TEST_LOG.md`, `DONE.md`, `TODO.md`, `WORKFLOWS.md` as required by the question.

Detailed experiment evidence belongs in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; closed milestones are in `DONE.md`; workflow roles are in `WORKFLOWS.md`; Windows XP x86 dependency/build rules are in `XP_BUILD_CONTRACT.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch and documentation source of truth: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility work branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

When a technical question concerns a non-default work branch, verify that branch's exact HEAD and inspect its code/workflow/runtime evidence, but continue reading the canonical documentation from `agent/gost-tls-poc`.

## Separation of conclusions

Keep these tracks independent unless a deliberately combined experiment tests both:

1. GOST TLS runtime / NSS / NSPR / MSSPI / SSPI / CryptoPro / handshake.
2. Windows Vista/7/XP compatibility / Rust / msvcr14x / YY-Thunks / linker / PE imports / physical runtime.
3. Bundled government-system extensions and localization/package behavior.

A successful build is not a successful GOST handshake. A hosted compatibility probe is not physical-XP proof. A Win7 x86 runtime pass does not prove XP import closure. A later documentation commit is never the source-under-test SHA for an earlier binary.

# GOST TLS runtime

## Architecture and current checkpoint

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current runtime constraints include:

- allowlist through `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- coordinated Firefox client-auth picker as default;
- diagnostic legacy selector/mode remains available but is not production policy;
- `Session` is the current default positive choice and remains process-local;
- true persistent `Permanent` semantics remain open;
- final fail-closed server verification remains open;
- synchronous provider/key access can still block the shared Firefox Socket Thread during long CryptoPro waits.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

Current authoritative Session-default browser:

- source `afbdad307f63e594d3715169d6e34235280dddaf`;
- full build run `33073577269`, job `98521835354`;
- release artifact `9652941006`;
- `r3dfox.exe` SHA-256 `75a292e0c765b076088db3cc82bb3ed357a07e53cf632b1b98a399c725a61cd1`;
- `xul.dll` SHA-256 `38352f1a7240c5e9a3b980fcc4344e7e6a2f7d4bffb0ec9d86f242e81876e82b`.

Closed runtime groups include basic Treasury GOST HTTPS, explicit-selector Treasury mTLS, coordinated client-auth lifecycle, GIS GMP isolation, Session lifetime, SD1-SD6 Session-default regression, T3 Cancel, T4 Abort, T7/T8 provider recovery, T9 provider-wait characterization and T10 picker presentation. Exact evidence is in `DONE.md` and the test logs.

## Current GOST runtime work

1. Implement and prove true persistent `Permanent` semantics.
2. Continue certificate-discovery/provider-boundary tests.
3. Compare provider-wait behavior with stock Firefox before changing Socket Thread architecture.
4. Complete mandatory fail-closed server trust and Firefox certificate-override integration.

# Windows XP SP3 x86 compatibility

This track is independent of GOST TLS runtime.

## Current handoff — read this before historical XP entries

Active work is on `agent/winrt-source-poc`; canonical documentation remains on `agent/gost-tls-poc`.

The old SRW/condition-variable loader failures are **closed historical blockers**, not the current XP edge. The canonical narrow synchronization baseline remains:

- source `d65b464c74caadace97995f07a4919363c41a0ea`;
- workflow `msvcr14x Rust YY XP x86 SRW smoke`;
- run `33470957048`;
- job `99740439208`;
- runtime artifact `9786702687`.

The later full-Firefox/physical-XP line progressed beyond that synchronization cluster. Do not reopen `AcquireSRWLockExclusive`, the SRW family, or `CloseThreadpoolWork` without new contradictory evidence.

`CreateWaitableTimerExA` is also **closed** by source-level remediation. The optional base-profiler high-resolution timer is compiled out for the legacy build and Firefox uses its pre-existing fallback. Full Firefox confirmation is tied to source `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`, run `33638897692`, job `100276666021`. The historical absence of a YY-Thunks `CreateWaitableTimerExA` capability is therefore not a current product blocker. Detailed closure: `XP_CREATE_WAITABLE_TIMER_STATUS.md`.

### Current physical-XP loader edge

The latest physical Windows XP startup progression has moved past the earlier SRW and `CreateWaitableTimerExA` edges. The current observed loader failure is:

`r3dfox.exe - Entry Point Not Found`

`KERNEL32!InitOnceExecuteOnce`

Treat `InitOnceExecuteOnce` as the current physical loader edge until a newer exact physical-XP artifact advances beyond it.

The related bounded YY-Thunks mechanism has already passed focused proof together with two other residual KERNEL32 APIs:

- source `ffb72c4ae6988a7c4f82b4e67a9027e41afb572b`;
- workflow `XP x86 core KERNEL32 cluster smoke`;
- run `33712987285`;
- job `100516220327`;
- focused residuals: `InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, `QueryFullProcessImageNameA`.

That GREEN proves focused capability/link/import/runtime behavior only. It does not by itself prove full Firefox integration or physical-XP startup.

### KERNEL32 source-remediation quartet — strategy GREEN, production open

The remaining source-remediation quartet is `GetApplicationRestartSettings`, `RegisterApplicationRestart`, `UnregisterApplicationRestart`, and `GetNamedPipeServerProcessId`. Its focused representative strategy proof is GREEN at source `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4`, workflow `XP KERNEL32 source remediation smoke`, run `33720100459`, job `100537300030`, diagnostics artifact `9879912839`. This does not prove production `xul.dll` or physical XP.

For the Application Restart trio, source ownership is `toolkit/xre/nsAppRunner.cpp`: the callback `RegisterApplicationRestartChanged` is registered from `XREMain::XRE_mainRun()`. The accepted XP design is now a dedicated `MOZ_XP_COMPAT` compile-time boundary: guard the complete callback definition and independently guard only its `Preferences::RegisterCallbackAndCall(...)` registration. Do not disable the surrounding Windows startup block; altered DLL prefetch, Launcher Process, Skeleton UI/default-browser-agent setup and adjacent registry synchronization remain independent facilities.

The source design is settled but the two guards are **not yet landed**. The available direct GitHub full-file update path for the large `nsAppRunner.cpp` produced truncated writes during the 2026-09-03 edit attempt; both attempts were immediately discarded by restoring `agent/winrt-source-poc` to exact pre-edit HEAD `10e055bacbfb5f955b1fd3b6e986c841f08797b1`, and the source blob was verified restored as `8f85b5323cda4a6444e04c8d370ff1871ad16793`. Do not treat either discarded write as source-under-test evidence.

`MOZ_XP_COMPAT` is accepted as the dedicated legacy-XP source guard, but its actual build-config wiring still must be implemented and verified. Existing `MOZ_NO_WINRT` remediations need not be rewritten solely for naming consistency.

For `GetNamedPipeServerProcessId`, ownership remains `accessible/windows/msaa/CompatibilityUIA.cpp` / `GetUiaClientPidsWin11::QueryThreadProc`. Preferred remediation remains bounded runtime resolution of the real native API, with failure when unavailable and no fabricated PID. Detailed plan: `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md`.

### Current full Firefox integration run — provisional

The current full XP x32 validation run is:

- branch `agent/winrt-source-poc`;
- source-under-test `4949a16e730cc15fc85b128fd62dac2a27c4d9c5`;
- workflow `GOST TLS PoC build  XP x32`;
- run `33718674533`;
- job `100533128424`;
- status at this documentation checkpoint: **in progress**.

The purpose of this run is to carry the current narrow XP compatibility provider into the real Firefox build while preserving package/runtime/diagnostic artifacts even when later gates are red. Do not call `InitOnceExecuteOnce` closed at full-browser or physical-XP level until this exact run completes and its resulting exact artifact is tested on physical XP.

### XP package/dependency closures already established

- Pinned/restored msvcr14x Release x86 is the required CRT baseline; do not substitute host redistributables.
- The selected XP bcrypt closure is the single app-local `bcrypt.dll` published as `xp-bcrypt-v1`; source `a30a701fcf50eb08b6ea7574cb7cc927f6eae014`, focused run `33513084915`, job `99873297193`, physically proven on XP.
- Legacy `D3DCompiler_47.dll` staging/packaging is closed by source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`.
- Full YY `kernel32.lib` interposition remains prohibited; keep per-PE narrow ownership.
- Final XP acceptance must be inventory-driven across required PEs and must distinguish ordinary hard imports from delay-load dependencies. A curated known-API gate is a regression gate, not exhaustive proof.

Detailed residual classification is in `XP_IMPORT_REMEDIATION.md`. `XP_BUILD_CONTRACT.md` remains authoritative for build/staging/PE-floor rules.

### Win7 x86 evidence boundary

A current XP-targeted x86 browser artifact can run successfully on Windows 7 x86 while still failing on XP because Win7 exports APIs that XP lacks. A Win7 x86 launch is therefore a useful general x86 runtime sanity check, but it must never be promoted to XP compatibility proof.

# Bundled government-system extensions / localization

Current proven three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and Russian-first content-language preference. Clean-profile discovery/enabled state is proven for all three. Native-component behavior and update behavior remain separate work.

## Russian localization

The previous mass-empty Russian payload defect and final Gate D path-shape false negative are closed.

Current corrected package gate:

- source `3e2c32386f373d4693db52b32c05aa2000878def`;
- workflow `CryptoPro Mozilla packaging smoke`;
- run `33520207057`, job `99897230730`;
- packaged-browser artifact `9812333220`;
- evidence artifact `9812333789`;
- conclusion: success.

Manual runtime evidence on predecessor artifact `9798517225` from run `33489331410` observed Russian UI by default, localized Settings/TLS error UI, and successful switching to `en-US`. The later corrected CI source changed only the final path predicate; do not relabel that manual execution as artifact `9812333220`.

# Global evidence rules

- Build success != GOST handshake success.
- GOST runtime success != final server-trust closure.
- Focused dependency/runtime success != full Firefox startup.
- Win7 x86 startup != XP startup.
- Source/build removal of a hard import != physical-XP runtime closure until the exact accepted artifact advances past that edge.
- Documentation HEADs never replace the exact source-under-test SHA for previously built or runtime-tested artifacts.
- For an in-progress run, record it as provisional and never mark its pending gate as passed.
