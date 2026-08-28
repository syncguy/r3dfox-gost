# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

F1 close/shutdown lifecycle, F2 positive `Once` fanout/scope, F3 generic GOST mTLS host scope, GIS-G4 cross-host decision isolation, explicit positive `Session` lifetime, the SD1-SD6 Session-default exact-artifact regression, T3 explicit Cancel/no-certificate semantics, and T4 involuntary tab/load Abort semantics are closed.

Current Session-default runtime evidence is source `afbdad307f63e594d3715169d6e34235280dddaf`, main run `33073577269`, job `98521835354`, artifact `9652941006`. Do not repeat closed tests on unchanged source merely for confirmation.

### 1. Continue client-decision / provider semantics

Immediate runtime next:

1. **T7/T8 — missing key medium + provider Cancel/recovery.** Start a new clean process/profile with the private-key medium unavailable **before the first GOST private-key acquisition**. Reach the Treasury client-auth flow, observe the current-attempt provider/key failure or provider Cancel, then restore the medium while keeping the same browser process/profile and retry. The recovery attempt must be able to obtain/use the key and complete Treasury GOST mTLS without sticky negative certificate state.
2. **T6 — real Permanent semantics.** Implement and prove persistence distinct from the current process-local non-Once store, including the intended forget/change behavior.

**T5 — Session failure-boundary regression is DEFERRED, not closed.** The 2026-08-28 T5 probe showed that removing the key medium *after* a successful Treasury Session mTLS does not create a provider failure: CryptoPro/SSPI retains an already-acquired credential context, and a fresh Treasury socket about 192 seconds later still receives a new CertificateRequest, reuses `scope=session`, emits a client-auth flight and completes TLS 1.2 / `0xFF85` mTLS. Therefore post-login medium removal is not a valid T5 fault injection in the current environment. Resume T5 only when there is a safe deterministic way to invalidate an already-acquired provider/private-key credential inside the same browser process; do not invent an invasive synthetic invalidation merely to force the test.

T3/T4 establish the negative-decision split on the current artifact: explicit picker Cancel is consumed as Declined/phase `2`, while an unanswered picker abandoned by tab/load teardown remains unresolved phase `0` and is removed by lifecycle cleanup. Neither path poisons later recovery.

The current source routes every non-`Once` positive choice through the same in-memory remember store. Therefore real persistent `Permanent` semantics remain unproven; do not assume the current `Permanent` UI choice survives process restart.

### 2. Continue the remaining Stage 2 runtime matrix

Remaining groups include:

- T5 deterministic failure-boundary test once an already-acquired provider credential can be invalidated safely;
- long provider-media wait using measured current-artifact timeout behavior;
- Russian picker row/details rendering beyond the completed SD6 smoke;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 3. Attribute picker timeout and residual poll churn

T2R and the T3 timeout segment both show lifecycle-safe but non-fixed picker teardown timing. T2R measured `32.576 s`, `37.420 s`, `30.330 s`; T3 measured one additional unanswered-picker removal after `30.276 s`. T4 is deliberately different: closing the owning tab removed the pending decision after only `4.059 s`, confirming that its teardown was user/load driven rather than timeout driven.

Before changing timeout policy or calling the wait path fully quiescent:

- identify which Firefox/Necko/load timer actually tears down each timed-out attempt;
- explain why the first historical cycle polls much more aggressively than later cycles;
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

The representative Windows XP SP3 x86 coexistence question is closed for source `d78137a931145af877dc458b01e494ad0467723d`, run `33138244191`, job `98743029100`, runtime artifact `9673057839`: the exact probe with bundled msvcr14x `ucrtbase.dll` and `msvcp140.dll` ran three times on physical Windows XP SP3 x86 with `ExitCode=0`.

Open work:

1. create a separate full 32-bit Firefox/xul experiment using the proven x86 `msvcr14x + modern Rust/libstd + narrow YY-Thunks` scheme while preserving `/MD` and XP x86 PE floor;
2. audit the resulting Firefox PE/runtime dependency closure for direct API-set/VCRUNTIME/known post-XP imports and fix only observed blockers;
3. if the full x86 build and import gates pass, run the exact portable browser first on a modern Windows host as packaging/startup sanity and then on real Windows XP SP3 x86;
4. separately continue the existing Win7 full-xul line: fix/replay delay-load parser, run real Win7, and expand Win7 runtime coverage;
5. keep GOST TLS-on-old-Windows as a later exact-build/runtime milestone independent from loader/startup compatibility.

## Bundled government-system extensions — independent

Current packaged three-extension artifact `9614275050` is packaging-proven and clean-profile discovery/enabled-state is proven for all three bundled project extensions.

Next:

1. re-check CryptoPro basic functionality on this exact package;
2. test legacy IFCPlugin with installed native host;
3. test Gosplugin with its local/native component;
4. verify the Russian-first content-language preference in runtime if desired;
5. generalize the historically CryptoPro-named packaging workflow to assert all three XPI + language pref;
6. transfer only proven shared packaging gates into the two main browser workflows;
7. later prove real version-to-version update behavior where a valid older/newer signed extension is available.

## Upstream base — deferred

Stay on r3dfox / Firefox 153. Do not migrate to Firefox 154 merely because upstream Mozilla has released it. Evaluate a newer base only after r3dfox itself publishes one and the user explicitly decides to upgrade.