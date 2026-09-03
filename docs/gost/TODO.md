# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

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

## Windows XP SP3 x86 compatibility — independent

The proven baseline and the 24 capability-present KERNEL32 cluster are **closed evidence and are not backlog items**:

- immutable SRW/Rust/CRT/YY baseline: source `d65b464c74caadace97995f07a4919363c41a0ea`, run `33470957048`, job `99740439208`;
- 24-API KERNEL32 representative/hosted closure: source `0184985c2f0c5ab1c4c732a200cfbda07a6aefb4`, run `33600786738`, job `100153789478`;
- the later auxiliary RED source `523601862d227da08819a0e4a74276cf3288fb56`, run `33604407934`, job `100165018692`, failed before PE/runtime gates and does not reopen those closed milestones.

The full-build/import validation of the `CreateWaitableTimerExA` source cut has now passed:

- source `17cdb459ec4f115a209fd50ac225cf867b9f3a2f`;
- run `33638897692`;
- job `100276666021`;
- full Firefox x86 build/link PASS;
- 34-name core-browser SRW + KERNEL32 import gate PASS across `r3dfox.exe`, `xul.dll`, `mozglue.dll`, and `plugin-container.exe`;
- independent exact diagnostics inspection proves `CreateWaitableTimerExA` absent from all four saved import inventories;
- `mach package` PASS;
- post-package msvcr14x CRT survival gate FAIL.

The historical physical-XP loader edge remains:

`mozglue.dll -> KERNEL32!CreateWaitableTimerExA`

but it is now removed at the build/import level. It is **not yet formally closed** because no accepted exact package with the required app-local CRT closure has been run on physical XP after this source cut.

Open work, in order:

1. **P0 — repair the msvcr14x package-survival contract.** The workflow stages the proven `ucrtbase.dll` and `msvcp140.dll` into `dist/bin` and records exact hashes before package, but run `33638897692` proves that no produced `.7z`/`.zip` satisfies the required exact-one-copy/hash contract. Fix the Mozilla package input/manifest/configuration so those exact staged DLLs are copied into the produced browser package. Do not weaken the post-package gate.
2. **P0 — harden the core import gate for `CreateWaitableTimerExA`.** The exact diagnostics prove it is gone, but the current fatal 34-name gate still omits this historical loader blocker. Add it explicitly so a later regression fails immediately instead of relying on manual diagnostics inspection.
3. **Rerun the same full XP x32 line from a new exact SHA.** Require full build/link, the 34-name closure plus explicit `CreateWaitableTimerExA` gate, exact CRT package hashes, legacy D3D package survival, runtime-archive creation, and the broad XP PE/import audit to execute. Bind package/runtime/diagnostics artifacts to the run/job/SHA.
4. **Physical XP startup from the accepted exact artifact.** Only after the package contains the exact app-local msvcr14x pair and the broad audit has run should the browser be launched on Windows XP SP3 x86. Verify that startup advances beyond the historical `CreateWaitableTimerExA` dialog.
5. **Close or advance the blocker strictly from physical evidence.** If startup advances, close `CreateWaitableTimerExA` in `DONE.md`; if a new loader/runtime dependency appears, record that exact dependency as the next blocker rather than reopening the SRW/Rust/CRT/24-API baseline.
6. **Keep remaining xul/Win7 legacy APIs secondary.** Existing WinRT-delay-load and sandbox/RNG investigations remain valid separate evidence, but they are not the current XP package/startup target.
7. Keep GOST TLS-on-old-Windows as a later exact-build/runtime milestone independent from loader/startup compatibility. Browser startup and ordinary browsing do not prove the MSSPI GOST path.

The package-manifest mechanism identified by the current run is concrete: stock `browser/installer/package-manifest.in` includes `ucrtbase.dll` only under `MOZ_PACKAGE_WIN_UCRT_DLLS` and the MSVC C++ runtime only under `MOZ_PACKAGE_MSVC_DLLS`. Manual post-build staging by the XP workflow does not by itself activate those predicates. Prefer an explicit, reproducible product/package contract for the custom msvcr14x pair over ad-hoc copying after packaging.

The earlier run `33610933602` had the same CRT package-survival RED. Its previous `TEST_LOG.md` interpretation has been corrected: that diagnostics artifact also records only pre-package CRT hashes and no successful archive record. Do not treat that older run as a package-closure proof.

Do not re-run `GetTickCount64`, SRW, Rust, CRT focused smokes, the 24 capability-present KERNEL32 APIs, or reconstruct their provider closure from memory merely for confirmation. New XP experiments must extend the exact proven baseline and test only the new delta.

## Bundled government-system extensions — independent

Current packaged three-extension artifact `9614275050` is packaging-proven and clean-profile discovery/enabled-state is proven for all three project extensions.

Next:

1. re-check CryptoPro basic functionality on this exact package;
2. test legacy IFCPlugin with installed native host;
3. test Gosplugin with its local/native component;
4. verify the Russian-first content-language preference in runtime if desired;
5. generalize the historically CryptoPro-named packaging workflow to assert all three XPI + language pref;
6. transfer only proven shared packaging gates into the two main browser workflows;
7. later prove real version-to-version update behavior where a valid older/newer signed extension is available.

## CI artifact ergonomics — project-wide

For every heavyweight workflow that performs a full browser compilation/package, add a dedicated portable artifact containing only the produced runnable `.7z` archive.

- Keep the existing package, runtime, diagnostics, import-audit, evidence, and other artifacts; the portable artifact is additional, not a replacement.
- Publish the exact `.7z` produced by the successful full compilation/package as its own artifact payload, without unrelated build trees or diagnostics in that artifact.
- Apply this consistently to the project's heavy full-build lines so a tester can retrieve the portable browser from every successful full compilation without downloading the much larger general package/runtime bundle.
- Treat this as a developer/test ergonomics requirement only; it does not change the evidentiary meaning of the existing build, runtime, packaging, or compatibility artifacts.

## Upstream base — deferred

Stay on r3dfox / Firefox 153. Do not migrate to Firefox 154 merely because upstream Mozilla has released it. Evaluate a newer base only after r3dfox itself publishes one and the user explicitly decides to upgrade.