# r3dfox GOST TLS — Project State

Last updated: 2026-09-03

This file is the authoritative current technical synthesis and handoff for new chats. Detailed experiment evidence belongs in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; closed milestones are in `DONE.md`; workflow roles are in `WORKFLOWS.md`; Windows XP x86 dependency/build rules are in `XP_BUILD_CONTRACT.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default GOST development branch: `agent/gost-tls-poc`.
- Windows XP SP3 x86 compatibility work branch: `agent/winrt-source-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer base.

### Branch-local state precedence

When a technical question concerns a non-default active branch, the branch-local `docs/gost/PROJECT_STATE.md`, `TEST_LOG.md`, `TODO.md`, `DONE.md`, and relevant status documents at that branch HEAD must be read after this default-branch handoff. Newer branch-local evidence overrides an older cross-branch snapshot here. A historical blocker in this file must never override a later exact physical-runtime or CI result from the active branch.

For Windows XP x86 work specifically, always verify `agent/winrt-source-poc` HEAD and read its branch-local XP documentation before drawing a current-blocker conclusion.

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

Active work is on `agent/winrt-source-poc`.

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

Treat `InitOnceExecuteOnce` as the current **observed physical** loader edge until a newer exact physical-XP artifact advances beyond it.

The related bounded YY-Thunks mechanism has passed focused proof together with two other residual KERNEL32 APIs:

- source `ffb72c4ae6988a7c4f82b4e67a9027e41afb572b`;
- workflow `XP x86 core KERNEL32 cluster smoke`;
- run `33712987285`;
- job `100516220327`;
- focused residuals: `InitOnceExecuteOnce`, `GetThreadPreferredUILanguages`, `QueryFullProcessImageNameA`.

The full Firefox run below advances this from focused proof to production build/import evidence: none of those three names appears in its broad forbidden-import report and the production core-browser import gate is GREEN. Physical-XP closure still requires launching the exact new runtime artifact.

### Full Firefox integration — package dependency closure GREEN, broad distribution audit RED

Current full XP x32 evidence point:

- branch `agent/winrt-source-poc`;
- source-under-test `4949a16e730cc15fc85b128fd62dac2a27c4d9c5`;
- workflow `GOST TLS PoC build  XP x32`;
- run `33718674533`;
- job `100533128424`;
- run attempt `1`;
- aggregate Actions result: **failure** because the final evidence summary intentionally propagates diagnostic RED outcomes after artifacts are preserved.

Substantive build/package results:

- full Firefox x86 build — GREEN;
- production core-browser import gate — GREEN;
- CRT staging and package-survival gate — GREEN;
- legacy `D3DCompiler_47.dll` staging/retarget/package gate — GREEN;
- proven `xp-bcrypt-v1` staging and package-survival gate — GREEN;
- runtime archive generation — GREEN;
- package/runtime/diagnostics artifact uploads — GREEN;
- broad all-PE import audit — RED, collected non-fatally with `continue-on-error: true`, then promoted to the aggregate RED by the final summary.

Exact artifacts:

- package `9883134667`, `327699666` bytes, digest `sha256:64b9537376b72a9e38728236b666b929e84e9c6895a022a1dd66338b9a645582`;
- physical-test runtime `9883135451`, `74911275` bytes, digest `sha256:9a5380bfec2b05a8460f6dfef99c85a1c053e1b31f9f18f101d6a7fc5563127b`;
- diagnostics `9883136547`, `5912540` bytes, digest `sha256:b7fb3503a258d78fec927cd0f81413d5124f6f9b4a61cd27a034ec6092607f1c`.

The previous msvcr14x packaging blocker is **closed**. `packaged-crt-contract.txt` names `r3dfox-v153.0.3.win32.portable.7z` and proves pre/post-package equality for:

- `ucrtbase.dll` SHA-256 `455fa6bc5ceedd89fc3650a224f96ba4dee0fbcb87e2823c1670a4704b737b2f`;
- `msvcp140.dll` SHA-256 `a1d6099eea3b7742b86ba44a7be7fc64bf0041a80e67ef7e54641ab283285c19`.

The bcrypt release-to-package contract is also **closed at automated build/package level**. The packaged library is exactly the physically proven `xp-bcrypt-v1` asset: size `520704`, SHA-1 `ae021f44edc48b03bb4d67cb5773b62bdf60cb67`, SHA-256 `f157f8026347d180e9ab42732bedaad0ea2b3b03dfd0d9ba8b8abe9612aff193`, release asset ID `539647946`.

The broad audit remains a real finite compatibility backlog. Diagnostics contain 69 known post-XP findings across auxiliary/media/test PEs, including `gkcodecs.dll`, Clearkey/fake GMPs, `libGLESv2.dll`, `logalloc-replay.exe`, `mozavcodec.dll`, `mozavutil.dll`, `mozinference.dll`, and `xpcshell.exe`. The residual API set is dominated by SRW/condition-variable/FLS/InitOnce-family calls plus `GetTickCount64` and `GetThreadId`. Do not confuse this distribution-wide RED with the already-GREEN core-browser import gate or with the now-closed CRT/bcrypt packaging contracts.

The exact runtime artifact `9883135451` is the next physical-XP candidate to test whether startup advances beyond the previously observed `InitOnceExecuteOnce` edge. Separately, classify the broad audit findings by shipped/runtime-required versus test-only/non-shipped PE before deciding remediation scope.

### Remaining KERNEL32 source-remediation quartet — focused strategy GREEN

The next known source-remediation quartet after residual-3 is:

- `GetApplicationRestartSettings`;
- `RegisterApplicationRestart`;
- `UnregisterApplicationRestart`;
- `GetNamedPipeServerProcessId`.

Exact ownership and chosen remediation are now established:

- the Application Restart trio is owned by `toolkit/xre/nsAppRunner.cpp::RegisterApplicationRestartChanged` and is optional Windows OS-restart/relaunch integration; the legacy-XP policy is a compile-time no-op for this feature as one unit, not three YY thunks;
- `GetNamedPipeServerProcessId` is owned by `accessible/windows/msaa/CompatibilityUIA.cpp::GetUiaClientPidsWin11::QueryThreadProc`; it belongs to Windows 11 UI Automation client detection, not sandbox IPC. The selected remediation is runtime `GetProcAddress` resolution preserving the native call when available and failing the candidate lookup when unavailable.

Focused proof is GREEN:

- source-under-test `0450fd8f2b22b9e0263e0755e0ea52f4dd6e2aa4`;
- workflow `XP KERNEL32 source remediation smoke`;
- run `33720100459`;
- job `100537300030`;
- diagnostics artifact `9879912839`, digest `sha256:29f742d11f584a07695fcb5cfa87d5f7046e5a22d54470f3b97acb065b85b886`.

The exact smoke proves source ownership, representative x86 compile/link, positive-control hard imports, absence of all four imports in the remediation variant, PE subsystem 5.01, and hosted runtime sanity. It does **not** yet prove production Firefox object/xul import closure or physical XP runtime.

The next low-cost step for this quartet is production source integration followed by exact affected-target/object compilation and symbol/import inspection. Do not request a separate heavy full Firefox build solely to test this source hypothesis before that target-level proof. Detailed status: `XP_KERNEL32_SOURCE_REMEDIATION_STATUS.md`; dated experiment evidence: `TEST_LOG_2026-09-03.md`.

### XP package/dependency closures already established

- Pinned/restored msvcr14x Release x86 is the required CRT baseline; do not substitute host redistributables.
- The selected XP bcrypt closure is the single app-local `bcrypt.dll` published as `xp-bcrypt-v1`; its focused release-staging smoke and full package-survival gate are GREEN. Full-package evidence is run `33718674533`, job `100533128424`, source `4949a16e...`.
- Legacy `D3DCompiler_47.dll` staging/packaging is closed by source `b77b22ef1e35564dfe76997d3d393d45ee697e49`, run `33349340069`, job `99359475336`, and remains GREEN in the current full build.
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
