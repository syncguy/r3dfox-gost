# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; the WinRT source-removal alternative is in `WINRT_SOURCE_POC.md`; Windows XP compatibility architecture/import triage is in `XP_COMPATIBILITY_STRATEGY.md`; the mandatory XP x86 build/dependency contract is in `XP_BUILD_CONTRACT.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

F1 close/shutdown lifecycle, F2 positive `Once` fanout/scope, F3 generic GOST mTLS host scope, GIS-G4 cross-host decision isolation, explicit positive `Session` lifetime, the SD1-SD6 Session-default exact-artifact regression, T3 explicit Cancel/no-certificate semantics, T4 involuntary tab/load Abort semantics, T7/T8 missing-medium/provider recovery, the T9 long-provider-wait characterization, and T10 detailed Russian picker presentation are closed as experiments.

Current Session-default runtime evidence is source `afbdad307f63e594d3715169d6e34235280dddaf`, main run `33073577269`, job `98521835354`, artifact `9652941006`. Do not repeat closed tests on unchanged source merely for confirmation.

### 1. Continue client-decision / provider semantics

Immediate next:

1. **T6 — real Permanent semantics.** Implement and prove persistence distinct from the current process-local non-Once store, including intended process-restart persistence and the intended forget/change behavior.
2. **T11/T12 — discovery boundary.** Verify dynamic `CurrentUser\MY` re-enumeration and determine whether provider/removable-media-only identities are discoverable without browser restart or interactive provider/PIN/media UI during candidate enumeration.

**T5 — Session failure-boundary regression is DEFERRED, not closed.** The 2026-08-28 T5 probe showed that removing the key medium *after* a successful Treasury Session mTLS does not create a provider failure: CryptoPro/SSPI retains an already-acquired credential context, and a fresh Treasury socket about 192 seconds later still receives a new CertificateRequest, reuses `scope=session`, emits a client-auth flight and completes TLS 1.2 / `0xFF85` mTLS. Therefore post-login medium removal is not a valid T5 fault injection in the current environment. Resume T5 only when there is a safe deterministic way to invalidate an already-acquired provider/private-key credential inside the same browser process; do not invent an invasive synthetic invalidation merely to force the test.

T7/T8 prove the complementary pre-acquisition boundary on the current artifact: with the certificate still discoverable from `CurrentUser\MY` but the key medium unavailable before first private-key acquisition, provider refusal produces `SEC_E_NO_CREDENTIALS` only for that MSSPI attempt; the positive Firefox `Session` decision survives, and after the medium returns the next request in the same browser process reuses `scope=session`, completes GOST mTLS and resumes protected application traffic without another picker.

T9 now proves the long-wait concurrency boundary. A positive Treasury Session selection entered the synchronous CryptoPro/SSPI provider path for `74.742 s`. The Firefox UI remained responsive by user observation, but the shared Firefox Socket Thread produced no `GostTLS` activity during that interval. When the provider action was cancelled, `SEC_E_NO_CREDENTIALS` returned and queued network work resumed immediately: `pay.gov.ru` began on the same timestamp and completed GOST TLS `291 ms` later. The later Treasury flow still reused `scope=session` and recovered successfully. Thus timeout/coordinator state remains safe, but **global Socket Thread network starvation during synchronous provider UI is a confirmed behavior**.

T10 closes the detailed picker presentation on the current artifact: human-readable owner/issuer presentation, correct Cyrillic and localized expiry, readable details, serial details-only, all three remember choices visible, and `Session` visibly selected by default. The successful post-inspection Treasury login is only a functional smoke; T10 does not imply real `Permanent` persistence.

T3/T4 establish the negative-decision split on the current artifact: explicit picker Cancel is consumed as Declined/phase `2`, while an unanswered picker abandoned by tab/load teardown remains unresolved phase `0` and is removed by lifecycle cleanup. Neither path poisons later recovery.

The current source routes every non-`Once` positive choice through the same in-memory remember store. Therefore real persistent `Permanent` semantics remain unproven; do not assume the current `Permanent` UI choice survives process restart.

### 2. Provider-wait Socket Thread isolation follow-up

T9 failed the intended no-network-starvation subcriterion: while CryptoPro/provider key access was synchronously blocked for `74.742 s`, new network work from other browser windows/tabs queued behind the same Firefox Socket Thread and started only when the provider call returned.

Open follow-up:

- compare this behavior with stock Firefox synchronous client-certificate/token/PIN handling before declaring it an incompatibility;
- determine whether MSSPI/CryptoPro key-access can be moved off the shared Socket Thread without breaking NSPR/MSSPI state ownership, client-auth lifecycle, cancellation, or proxy/CONNECT sequencing;
- do not redesign threading merely from intuition: preserve the exact T9 capture as the concrete baseline and require a focused implementation experiment if offloading is attempted;
- treat this as a responsiveness/performance limitation, not as evidence of a failed GOST handshake or broken UI event loop.

### 3. Continue the remaining Stage 2 runtime matrix

Remaining groups include:

- T5 deterministic failure-boundary test once an already-acquired provider credential can be invalidated safely;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 4. Attribute picker timeout and residual poll churn

T2R and the T3 timeout segment both show lifecycle-safe but non-fixed picker teardown timing. T2R measured `32.576 s`, `37.420 s`, `30.330 s`; T3 measured one additional unanswered-picker removal after `30.276 s`. T4 is deliberately different: closing the owning tab removed the pending decision after only `4.059 s`, confirming that its teardown was user/load driven rather than timeout driven.

T9 is also distinct from those Firefox-picker timeouts: after the Firefox certificate decision had already resolved, the Socket Thread remained synchronously inside provider/key acquisition for `74.742 s` until provider Cancel. No automatic ~30-second picker teardown occurred in that state.

Before changing timeout policy or calling the wait path fully quiescent:

- identify which Firefox/Necko/load timer actually tears down each timed-out *Firefox picker* attempt;
- keep that lifecycle separate from the T9 provider/key-access wait;
- explain why the first historical picker-timeout cycle polls much more aggressively than later cycles;
- preserve stock-compatible timeout semantics rather than introducing an arbitrary GOST-specific timeout.

## GOST TLS security — mandatory Stage 2 server-trust closure

Complete fail-closed server verification:

- reject `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail;
- prove client private-key operations cannot occur before server trust.

Do not use a production verification bypass.

## GOST network coverage — later

After Stage 2 security/runtime closure:

- direct connection without proxy;
- HTTPS proxy / nested TLS;
- SOCKS lifecycle;
- proxy authentication/reconnect edge cases beyond the currently exercised HTTP CONNECT path.

## Final UX polish — later

After core GOST TLS is stable, evaluate transparent one-shot GOST discovery:

- explicit allowlist still enters MSSPI immediately;
- unknown host starts with NSS;
- only `SSL_ERROR_NO_CYPHER_OVERLAP` may authorize one MSSPI retry;
- no retry loops;
- only a successful, normally verified GOST connection becomes session-confirmed;
- discovery cache is process/session scoped and never bypasses trust/client-auth policy.

## Windows compatibility — independent

Current authoritative synthesis is in [`PROJECT_STATE.md`](./PROJECT_STATE.md); exact physical/runtime evidence is in the newest entries of [`TEST_LOG.md`](./TEST_LOG.md). The XP dependency/build contract remains [`XP_BUILD_CONTRACT.md`](./XP_BUILD_CONTRACT.md).

### Integrated private DWrite browser — latest successor recorded; aggregate summary still RED

The standalone component work and the full-browser transfer remain proven at their respective boundaries:

- focused physical component: workflow `.github/workflows/xp-supermium-dwrite-closure.yml`, run `34317489430`, job `102356664699`, artifact `10090864697`, **GREEN / PHYSICAL XP COMPONENT PASS**;
- current full-browser source-under-test `71c7f135210030dde4ec9eeee04e6cb36a2cbffc`;
- workflow `.github/workflows/gost-poc-build-xp-x32.yml`;
- run `34485182943`, job `102897550999`, **aggregate RED**;
- package `10162565742`, runtime `10162567956`, diagnostics `10162609423`.

The current full-browser run successfully compiles, links, stages and packages the private DWrite closure, preserves the listed targeted xul/mozglue XP gates, creates the physical-test runtime archive, runs the broad PE/import audit step, completes YY inventory, and uploads all three artifacts. Its only failed Actions step is `GATE - Summarize XP x32 full build`.

This bookkeeping pass deliberately did not inspect the final summary log or diagnostics payload. Therefore the preceding run's exact `gate:broad-import-audit=failure` / 22-row private-DWrite diagnosis is **not** assumed to be the cause of run `34485182943`. That classification remains valid only for run `34439013068`, job `102749929410`, source `c0b5561dc58d588ecb970a333d49ac78fae84eb0`.

Immediate work:

1. **Classify the exact final-summary failure of run `34485182943` before another expensive build.** Use the final summary output and the already-uploaded diagnostics artifact `10162609423`; keep source-under-test identity `71c7f135...` separate from later documentation commits.
2. **Follow the exact remaining gate owner.** If the remaining failure is still broad-import acceptance, keep the fix provider/PE-aware and narrow; if a different aggregate gate is named, remediate that owner instead of reopening already closed compatibility families.
3. **Require the next accepted full build to finish aggregate GREEN.** Preserve all targeted xul/mozglue import gates, DWrite hash/provider/package-survival gates, msvcr14x, bcrypt, legacy D3DCompiler, YY TLS-entry-point contract, Rust XP cfg and PE-floor checks.
4. **Then physically test that exact accepted integrated browser artifact on XP.** Bind evidence to source SHA, run/job, artifact IDs and exact `r3dfox.exe`/`xul.dll` identities; record the next exact runtime boundary if one appears.

Do not spend another cycle re-integrating the same DWrite subtree or mechanically carrying the previous 22-row diagnosis onto a different source SHA. The focused physical DWrite PASS remains component evidence; it does not substitute for full Firefox startup.

#### Supermium DWrite component refresh — separate follow-up

Keep the physically proven 132 component as the browser-integration control while testing newer Supermium component generations separately; do not replace the full-browser pin merely because a newer release exists.

1. **Supermium 138 R9 — active focused refresh experiment.** Use final ESR release `v138-r9`, exact x86 nonsetup asset `supermium_138_32_nonsetup.zip`, SHA-256 `7d5e7578d9e4fe27f1f46530f1614e8ac885c27e36e64004eb97216a54a6bde9`; use the dynamic closure/UCRT-contract methodology and require `DWriteCreateFactory` plus `GetSystemFontCollection` before physical XP testing.
2. **Supermium 144 R5 — planned follow-up after the 138 result.** Evaluate `v144-r5`, exact x86 nonsetup asset `supermium_144_32_nonsetup.zip`, SHA-256 `17acfcdf89ea651905053b50b0fce5a28db19cb2c69ed5579c7b177806ed6d31`, against the proven 132 control and final 138 R9 before any browser pin migration.

### Current full-browser baselines

Current latest integrated full-build evidence is source `71c7f135210030dde4ec9eeee04e6cb36a2cbffc`, run `34485182943`, job `102897550999`: compile/package/artifact production PASS, aggregate workflow RED at the final summary; exact summary reason is not classified in the current bookkeeping pass.

The preceding analyzed integrated build remains source `c0b5561dc58d588ecb970a333d49ac78fae84eb0`, run `34439013068`, job `102749929410`: its aggregate RED was explicitly localized to the private-DWrite-only 22-row broad policy result.

The latest completed all-GREEN pre-DWrite full-browser build/static baseline remains source `db334d39cf929de7a12ea2f74bea32ddc4f3e4e4`, run `34213345771`, job `102019253738`, package `10056086223`, runtime `10056088395`, diagnostics `10056127829`. It remains useful control evidence for earlier compatibility fixes but does not contain the private DWrite integration.

### Deferred XP cleanup — battery observer simplification

The current narrow remediation keeps the Windows battery HAL functional on XP by using the legacy `WM_POWERBROADCAST` / `PBT_APMPOWERSTATUSCHANGE` path instead of Vista-only `RegisterPowerSettingNotification` / `UnregisterPowerSettingNotification`.

For the currently identified GPU consumer, battery state is forwarded to the GPU process and only `charging()` is used to gate D3D11/video enhancement paths such as VP Super Resolution and Auto HDR. Those paths are not useful to the XP target. Therefore, after XP startup/runtime stabilization, consider removing the XP battery notification machinery entirely and replacing it with a narrow XP stub that reports permanent external-power/charging state.

Before doing that cleanup, re-audit all `BatteryInformation` consumers on the then-current Firefox/r3dfox 153 source so the stub does not accidentally change an unrelated DOM/platform battery contract. This is deferred simplification only; do not spend the current full-build cycle on it.

### Deferred only if reached by exact evidence — `ncrypt.dll`

Do not preemptively work on NCRYPT/CNG. If a later exact XP artifact reaches a real `ncrypt.dll` boundary, prefer source-level selection of Firefox's existing legacy CryptoAPI backend under the project-owned Rust XP cfg, compile the NCrypt branch out where practical, and add a final import gate. YY-Thunks for NCRYPT is fallback only if source-level removal is proven insufficient.

### Closed compatibility families — do not spend new cycles without contradictory evidence

The current lineage has already closed or physically advanced past the following families:

- `SharedPrefMap.cpp:25` / child preference-HANDLE inheritance / `0x80000003` on source `897e1cdf...`;
- pinned/restored msvcr14x Release x86 contract;
- app-local `xp-bcrypt-v1/bcrypt.dll`;
- legacy `D3DCompiler_47.dll` staging/packaging;
- narrow YY SRW/condition-variable/KERNEL32 residual strategy;
- `NtCancelIoFileEx`;
- ADVAPI32 ETW family;
- KERNEL32 restart/named-pipe source-remediation quartet;
- `xul.dll -> PROPSYS.dll` ordinary dependency;
- `USER32!SetProcessDPIAware` startup boundary;
- WS2_32 observed compatibility family;
- ANGLE/DXGI `CreateDXGIFactory1` static closure;
- IP Helper physical boundary;
- old `xul.dll` `RtlpWaitForCriticalSection` startup failure;
- YY-Thunks DLL/TLS entry-point static coverage for the current 13 strong candidates (13/13);
- focused private DWrite component runtime contract on physical XP (`a42b144...` / run `34317489430` / artifact `10090864697`).

The battery `RegisterPowerSettingNotification` edge is **statically removed but not yet physically closed on an exact integrated successor browser**, so keep it out of the physically closed browser list until exact XP execution confirms the advance.