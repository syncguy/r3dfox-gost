# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

### 1. Validate positive `Once` scope across one logical login

F1 close/shutdown lifecycle is formally closed by T2R on source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`, main run `33039013849`, job `98408139479`, artifact `9636591432`. Do not repeat T2R unless a later source changes that lifecycle.

The F2 candidate is already implemented in source `ef1a7fdd...` as a positive-only `Once` fanout lease with a 5-second idle lifetime. Build gates are complete; runtime proof is still required.

Run T1R:

- one fresh browser process;
- enter Treasury personal cabinet;
- leave default `Once`;
- select the intended certificate once;
- one logical login must complete with one visible picker;
- compatible parallel/sequential connection waves must reuse only that positive choice safely;
- all relevant mTLS handshakes and protected application login must succeed.

If a second picker appears during the same logical login, stop and preserve the capture rather than manually working through repeated prompts.

Then run T1R-B:

- let the candidate's 5-second idle lease become inactive with a clear margin;
- start an independent login in the same browser process;
- a fresh picker must appear;
- `Once` must not have become Session/Permanent.

Never lease a decline, abort, zero-candidate result, internal failure, provider failure or server rejection.

### 2. Validate generic GOST mTLS client-auth on GIS GMP

The F3 candidate is already implemented in source `ef1a7fdd...`: the normal Firefox/coordinated client-auth callback can be registered for non-Stage-1 GOST sockets rather than remaining Treasury-only. Backend selection is still controlled by the existing GOST allowlist/session policy.

Old GIS GMP evidence on artifact `9606431408` proved:

- `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` complete GOST TLS 1.2 / `0xFF85`;
- certificate login reaches `portalgisgmp.cert.roskazna.ru`;
- that host sends a real TLS `CertificateRequest`;
- old capture contained 36 acceptable-CA DER DNs;
- old browser sent an empty TLS client Certificate because the custom client-auth callback was not registered for that host;
- server returned fatal `handshake_failure` (`0x28`) and MSSPI primary `0x80090326`.

After T1R/T1R-B, run GIS-G1 on artifact `9636591432`:

- prove generic callback registration for `portalgisgmp.cert.roskazna.ru`;
- prove the real `CertificateRequest` reaches issuer collection;
- record the then-current acceptable-CA count rather than assuming it is still 36;
- record candidate count.

If candidate count > 0, continue to real GIS-G2 mTLS/application login. If candidate count == 0, stop and diagnose the actual server CA list/local chain matching before changing issuer policy.

Investigate zero candidates in this order:

- server acceptable-CA binary identities/count;
- whether the intended local chain contains an advertised authority;
- Windows chain path/cross-sign selection;
- raw DER-name equality versus Windows certificate-name comparison;
- provider/private-key binding filter.

Do not publish client-certificate identifying DNs, serials, fingerprints, provider/container identifiers or private data.

### 3. Continue Stage 2 runtime matrix after T1R/T1R-B/GIS-G1 closure

Follow `STAGE2_RUNTIME_TEST_PLAN.md` and `STAGE2_GIS_GMP.md` in order. Remaining groups:

- explicit Cancel/no-certificate vs involuntary Abort;
- `Once`, explicit `Session`, explicit `Permanent`;
- missing-media/provider Cancel and recovery;
- long provider-media wait using measured current-artifact timeout behavior;
- Russian picker row/details rendering;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

### 4. Attribute picker timeout and residual poll churn

T2R proved lifecycle safety but also showed non-uniform timeout/poll behavior:

- picker-to-close intervals: `32.576 s`, `37.420 s`, `30.330 s`;
- `GostPoll client-auth wait quiescent`: `10,825`, `34`, and `21` calls respectively.

The first cycle still has substantial polling churn (~332/s), while later cycles are near one call per second. This is **not** a blocker for T1R because decision cleanup is correct, but before changing timeout policy or calling the wait path fully quiescent:

- identify which Firefox/Necko/load timer actually tears down each attempt;
- explain why the first cycle polls much more aggressively than later cycles;
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

## Windows Vista/7 compatibility — independent

Open work:

1. integrate proven `msvcr14x + modern Rust/libstd + narrow YY-Thunks` into full Firefox/xul while preserving `/MD`;
2. audit final PE set for direct API-set/VCRUNTIME/known Win8+ imports;
3. fix/replay delay-load parser and classify guarded post-Win7 paths;
4. run the resulting portable browser on real Windows 7 without the copied compatibility bundle;
5. expand real Win7 runtime coverage;
6. run GOST TLS on Win7 as a separate exact-build/runtime milestone.

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