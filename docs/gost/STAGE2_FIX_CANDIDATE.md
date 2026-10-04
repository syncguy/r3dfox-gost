# Stage 2 GOST TLS — F1/F2/F3 fixing candidate checkpoint

Last updated: 2026-08-27

Purpose: preserve the exact code/build checkpoint for the first combined Stage 2 fixing candidate after Treasury T1/T2 and GIS GMP runtime diagnosis. This file is a recovery checkpoint; build and runtime conclusions remain provisional until their exact gates/tests complete.

## Source-under-test

Code candidate:

- branch: `agent/gost-tls-poc`;
- source-under-test SHA: `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- commit: `fix(gost): harden coordinated client auth lifecycle`;
- parent: `d1299d65f924796937d31fbb30a9504325ba4c43` (documentation-only HEAD before the code change);
- changed code files only:
  - `security/manager/ssl/nsGostSSLIOLayer.cpp`;
  - `security/manager/ssl/GostClientAuthCoordinator.inc`;
- preserved legacy implementation `security/manager/ssl/nsGostSSLIOLayerLegacy.inc` is intentionally unchanged.

Do not cite a later documentation-only HEAD as the source-under-test SHA for these builds.

## F1 — close/shutdown re-entrancy hardening

Implemented in the candidate:

- coordinator keeps an explicit set of MSSPI handle identities that have entered close;
- wrapper `GostClose()` saves the MSSPI handle identity, marks it closing before legacy close / `msspi_shutdown()`, removes an existing coordinated waiter with reason `close-pre`, calls the preserved legacy close, performs a defensive `close-post` waiter cleanup by the saved handle value, then removes the closing marker;
- the client-certificate wrapper checks the closing marker before the explicit selector or Firefox/coordinator path and returns without creating/joining a decision or opening UI;
- the coordinated path independently checks the closing marker;
- diagnostics now record handle closing/closed, waiter add/remove reason, decision create/remove/resolution and stale callback identity.

Intended regression proof remains T2R. The implementation is not considered proven until a runtime timeout/teardown produces no shutdown-created decision/orphan waiter and a later attempt without browser restart opens a fresh picker.

## F2 — positive `Once` fanout across sequential connection waves

Implemented as the first bounded runtime candidate:

- only a positive certificate selection made with Firefox `Once` creates a GOST positive lease;
- lease key reuses the exact coordinated decision key (host, port, OriginAttributes, exact acceptable-CA identity) and additionally requires the same Firefox browser ID;
- selected certificate DER is retained only in memory;
- lease has a 5-second **inactivity** lifetime;
- each compatible follow-on client-auth request that consumes the lease refreshes the 5-second inactivity deadline;
- `Declined`, abort/teardown, zero-candidate, internal failure and provider/server failures do not create a lease;
- explicit Session/Permanent continue through their separate positive remembered-selection path;
- lease reuse/storage is logged with a generation ID and browser ID.

Rationale: the proven Treasury T1 connection waves were separated by roughly 1–2 seconds, so a short inactivity lease should cover the observed 1+5+5 logical-login fanout without becoming a browser-session choice.

Important limitation / validation requirement: this first candidate uses same-browser + exact decision key + bounded inactivity as the attempt boundary rather than a true Necko top-level navigation generation. T1R must prove one picker for the observed Treasury login, and T1R-B must prove a genuinely independent later login asks again. If a distinct login within the lease window is incorrectly reused, replace the time heuristic with an explicit navigation/attempt lifecycle identity before Stage 2 closure.

## F3 — generic GOST mTLS client-auth host scope

Implemented without changing GOST backend selection:

- public `nsGostSSLIOLayerAddToSocket` / `nsGostSSLIOLayerNewSocket` are wrappers around macro-renamed preserved legacy implementations;
- after successful legacy GOST socket setup, non-Treasury GOST hosts also receive `msspi_set_cert_cb(..., SelectStage1ClientCertificate)`;
- the normal Firefox/coordinated callback no longer rejects every host except `lk-fzs.roskazna.ru`;
- Treasury keeps the legacy Stage-1 registration behavior;
- `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` remains Treasury-only because the preserved legacy setup still reads that diagnostic selector only for `kStage1MtlsHost`;
- generic callback registration does not route ordinary NSS traffic to MSSPI and does not send a certificate unless the already-selected GOST server actually requests client authentication;
- diagnostics record generic/stage1 callback registration, host, mode, CA count, candidate count and coordinated decision lifecycle.

Intended GIS proof remains GIS-G1: `pay.gov.ru` -> `portalgisgmp.login.roskazna.ru` -> `portalgisgmp.cert.roskazna.ru` must now reach issuer collection and candidate enumeration after the real server `CertificateRequest`. If candidate count is zero, stop and diagnose the server's acceptable-CA list / local chain policy; do not preemptively change the DER-name matcher.

## Automatically triggered build gates

The code push changed `nsGostSSLIOLayer.cpp`, so the existing workflow path filters started three workflows for the exact candidate SHA.

### Required GOST short gate

- workflow: `GOST SSL compile check`;
- run: `33039013892`;
- attempt: 1;
- job: `98408139567` (`Windows x64 / security-manager-ssl only`);
- source SHA: `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- status when this checkpoint was written: **in progress**;
- required decisive step: `Compile security manager SSL target objects`.

Do not record this gate as passed until the job finishes successfully.

### Authoritative main GOST full build

- workflow: `GOST TLS PoC build`;
- run: `33039013849`;
- attempt: 1;
- job: `98408139479` (`Windows x64 / r3dfox GOST release`);
- source SHA: `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- status when this checkpoint was written: **in progress**.

This is the authoritative browser-build line for later T2R/T1R/GIS-G1 runtime evidence. Do not use an artifact until this exact run completes the required build/package/upload gates successfully.

### Automatically triggered thunk-rs build — separate track

- workflow: `GOST TLS PoC build - thunk-rs experiment`;
- run: `33039013822`;
- attempt: 1;
- source SHA: `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- status when this checkpoint was written: **in progress**.

It started only because the code path also matches that workflow's push filter. Its result belongs to the independent Windows Vista/7 compatibility track and is not a substitute for the main GOST build or runtime proof.

## Required next sequence

1. Observe short run `33039013892` to completion. If SSL object compilation fails, diagnose/fix the candidate and do not treat the concurrently running full build as valid transition evidence.
2. If the short gate is green, require main run `33039013849` to complete successfully and record the exact produced runtime artifact ID/hash.
3. First user runtime regression on the resulting main artifact: **T2R** — unanswered Treasury picker -> timeout/teardown -> without process restart next attempt must show a fresh picker and must not reuse `selected=0`.
4. Second: **T1R** — successful Treasury login with default `Once` must need one picker across compatible sequential/concurrent waves; then T1R-B verifies a separate later login asks again.
5. Third: **GIS-G1** — prove generic callback registration, the real GIS GMP `CertificateRequest`, issuer collection and candidate enumeration on `portalgisgmp.cert.roskazna.ru`.
6. GIS-G1 candidate count > 0 -> GIS-G2 real GOST mTLS. Candidate count == 0 -> stop and diagnose CA-chain/name matching before another code change.

Build success is only a build gate. It does not prove F1, F2, F3 runtime behavior or a successful GOST TLS/mTLS handshake.
