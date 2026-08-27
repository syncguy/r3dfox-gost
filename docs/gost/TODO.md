# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog. Current synthesis is in `PROJECT_STATE.md`; exact runtime test sequencing/recovery is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP multi-host mTLS branch is in `STAGE2_GIS_GMP.md`; experiment evidence is in `TEST_LOG.md` and dated volumes.

## GOST TLS runtime — immediate

### 1. Formally close F1 from the existing T2R capture

Current fixing candidate:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- authoritative main run `33039013849`, job `98408139479`;
- main runtime artifact `9636591432`.

T2R already passes its user-visible recovery behavior on a clean profile in one browser process:

- unanswered picker -> timeout;
- F5 -> fresh picker;
- second unanswered picker -> timeout;
- `Try again` -> fresh picker;
- third unanswered picker -> timeout.

This removes the old externally visible sticky failure from source `860de8e...`, where one timeout poisoned all later attempts until browser restart.

Before formally closing F1, inspect the already-generated `C:\Temp\r3dfox\t2r*` capture and record hashes/timestamps. Verify:

- handle is marked closing before legacy `msspi_shutdown()`;
- any re-entrant client-cert callback for a closing handle is ignored before decision lookup/create/join;
- pre/post close waiter cleanup leaves no orphan waiter/decision;
- stale abandoned-dialog callback is harmless;
- later attempts do not consume a stale automatic `selected=0`;
- no `MSSPI_X509_LOOKUP` tight re-entry returns;
- current `GostPoll client-auth wait quiescent` rate;
- exact unanswered-picker lifetime on the fixing artifact.

The user observed approximately 30 seconds on all three cycles, versus the old exact ~45.005-second capture. Do not attribute the timing difference before reading the new log.

If the capture passes, remove F1 from open work and add the concise closure to `DONE.md`.

### 2. Validate positive `Once` scope across one logical login

The F2 candidate is already implemented in source `ef1a7fdd...` as a positive-only `Once` fanout lease with a 5-second idle lifetime. Build gates are complete; runtime proof is still required.

Run T1R after F1 log-level closure:

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

### 3. Validate generic GOST mTLS client-auth on GIS GMP

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

### 4. Continue Stage 2 runtime matrix after T2R/T1R/GIS-G1 closure

Follow `STAGE2_RUNTIME_TEST_PLAN.md` and `STAGE2_GIS_GMP.md` in order. Remaining groups:

- explicit Cancel/no-certificate vs involuntary Abort;
- `Once`, explicit `Session`, explicit `Permanent`;
- missing-media/provider Cancel and recovery;
- long provider-media wait using the current artifact's measured timeout scale;
- Russian picker row/details rendering;
- dynamic `CurrentUser\MY` discovery and token-only/removable-media discovery;
- no acceptable cert / unsuitable cert / wrong cert / unavailable key / PIN-private-key failure / server rejection;
- issuer-aware validity/KU/EKU/private-key candidate policy;
- sensitive-log audit;
- final exact-build Treasury mTLS regression.

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