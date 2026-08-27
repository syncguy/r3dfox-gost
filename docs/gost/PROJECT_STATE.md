# r3dfox GOST TLS — Project State

Last updated: 2026-08-27

This file is the authoritative current technical synthesis. Detailed evidence is in `TEST_LOG.md` and immutable dated `TEST_LOG_*.md` volumes; forward work is in `TODO.md`; the restart-safe runtime sequence is in `STAGE2_RUNTIME_TEST_PLAN.md`; the GIS GMP branch is in `STAGE2_GIS_GMP.md`.

## Repository / branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; never modify, merge, rebase, force-push or otherwise change it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the working branch.
- Project remains on r3dfox / Firefox 153 until the user explicitly decides to evaluate a newer r3dfox baseline.

## Architecture

Ordinary HTTPS remains on Firefox NSS. Explicitly allowlisted GOST hosts use `nsGostSSLIOLayer.cpp` -> pinned `deemru/msspi` -> Windows SSPI/CryptoPro after normal Necko proxy resolution / HTTP CONNECT / proxy authentication.

Current constraints:

- allowlist: `R3DFOX_GOST_HOSTS`;
- TLS 1.2 / HTTP/1.1 PoC path;
- default GOST ciphers: `C100:C101:C102:FF85:0081`;
- coordinated Firefox client-auth picker is default;
- `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` remains a same-binary diagnostic fallback;
- explicit local thumbprint selection remains diagnostic only;
- current coordinated candidate includes a positive-only default-`Once` fanout lease with a 5-second idle lifetime.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Confirmed GOST milestones

### Basic Treasury GOST HTTPS

Main transport baseline:

- source `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- main run `32710363486`, job `97380247020`, artifact `9518011746`.

Real Treasury HTTP CONNECT, GOST TLS 1.2 / `0xFF85`, protected application traffic and browser rendering are proven.

### Stage 1 explicit-selector Treasury mTLS

Known-good source:

- source `f5d04896e17f91f58b6a137af823360f4718eb29`;
- main run `32751967162`, job `97510763210`.

A locally designated client certificate can be loaded by MSSPI/CryptoPro and completes real Treasury GOST TLS 1.2 / `0xFF85` mutual TLS plus authenticated application traffic. The concrete certificate identifier remains private.

## Current Stage 2 coordinated browser identity

Current F1/F2/F3 source:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea` (`fix(gost): harden coordinated client auth lifecycle`);
- short SSL compile run `33039013892`, job `98408139567`, success;
- authoritative main full build run `33039013849`, job `98408139479`, success;
- main release artifact `9636591432` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9636591757`;
- independent thunk-rs full-xul run `33039013822`, job `98408139313`, success;
- thunk browser artifact `9636047031`, diagnostics `9636048172`.

Artifact `9636591432` is the authoritative browser for current GOST runtime testing. The thunk artifact is independent Windows-compatibility evidence and is not GOST runtime proof.

Exact local binary preflight for main artifact `9636591432`:

- `r3dfox.exe` SHA-256 `ccd3ed44bc57345eb7821a949dd96a6b3c45c71b47f3a577da26fc1265481187`;
- **`xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`**.

The valid T1R capture below was run only after the user verified both hashes exactly.

## Stage 2 coordinated runtime checkpoint

### F1 — close/shutdown client-auth lifecycle — CLOSED

T2R on the current main artifact is a full runtime pass.

Capture identity:

- `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner `t2r.moz_log` SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`.

Three unanswered-picker timeout cycles were completed in one browser process. F5 after the first timeout and `Try again` after the second both produced a fresh picker.

Internal lifecycle proof across the three cycles:

- exactly 3 coordinated decisions created and 3 removed;
- exactly 3 active waiters removed pre-close, each reaching `waiters=0`;
- exactly 3 shutdown-time client-cert callback re-entries rejected with `reason=closing` before decision creation/join;
- exactly 3 abandoned UI callbacks later rejected as stale;
- no shutdown-created replacement decision or orphan waiter;
- no `selected=0` reuse;
- no `0x80090326` / `0x0000054f` sticky failure sequence;
- no `MSSPI_X509_LOOKUP` recurrence.

Measured picker-to-close intervals were `32.576 s`, `37.420 s`, and `30.330 s`. The timeout is therefore not established as one fixed 30- or 45-second constant.

`GostPoll client-auth wait quiescent` counts were `10,825`, `34`, and `21`. The first cycle still shows substantial poll churn (~332/s) while later cycles are near one call per second. Timeout-source attribution and this polling inconsistency remain separate non-blocking work; they do not reopen F1.

The old failure on source `860de8e38deed326b7fcd1c547e928c5b48c72a9`, artifact `9606431408`, is retained only as historical evidence.

### F2 — positive default-`Once` fanout — T1R PASS, T1R-B NEXT

Old T1 on source `860de8e...`, artifact `9606431408`, proved real coordinated Treasury mTLS and concurrent single-flight but required three sequential picker waves in one logical login.

The first attempted T1R capture was later confirmed by the user to have been run from an older browser build. It remains historical invalid-test evidence only and does not affect F1/F2 conclusions.

Valid hash-bound T1R evidence:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- run `33039013849`, job `98408139479`, artifact `9636591432`;
- `t1r-current.zip` SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`;
- inner `t1r-current.moz_log` SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`.

User-visible result: entering the Treasury personal cabinet shows exactly one Firefox client-certificate picker; selecting the intended certificate once with default `Once` completes the protected login and the cabinet then behaves normally.

Internal/runtime proof:

- one coordinated decision and one dialog;
- one positive `Once` lease store (`generation=1`, `idle_ms=5000`);
- seven lease reuses with no further UI;
- the seven reuses span two follow-on waves: five near-simultaneous requests around `08:43:59.635–08:43:59.669 UTC`, then two later requests at `08:44:02.577–08:44:02.588 UTC`;
- eight total successful `lk-fzs.roskazna.ru` mTLS handshakes, all TLS 1.2 / `0xFF85`, state `0x00000000`, `client_cert_loaded=1`;
- zero `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, or `E/GostTLS`.

This closes the original T1 repeated-picker symptom for one logical login: the 5-second positive lease successfully carries the selected certificate across the real sequential connection waves.

F2 is **not yet formally closed** because T1R-B must prove the scope boundary. The last lease reuse occurs at `08:44:02.588 UTC`; because each reuse refreshes the idle expiry, the lease should become inactive around `08:44:07.588 UTC` if no later compatible request occurs. The T1R log continues beyond that time but has no independent new client-auth request, so it cannot prove expiry behavior.

### F3 — generic GOST mTLS host scope — AFTER F2

Old GIS GMP runtime on artifact `9606431408` proved:

- `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` complete GOST TLS 1.2 / `0xFF85`;
- certificate login reaches `portalgisgmp.cert.roskazna.ru`;
- the certificate endpoint sends a real TLS 1.2 `CertificateRequest` with a non-empty CA list (36 DER DNs in that old capture);
- the old Treasury-only callback scope caused an empty client Certificate and server fatal `handshake_failure` / MSSPI `0x80090326`.

Current source registers the normal coordinated callback generically for already-selected GOST sockets. GIS-G1 must prove the real certificate endpoint reaches callback registration, current acceptable-CA collection and candidate enumeration. If candidates are nonzero, continue real GIS-G2 mTLS. If zero, stop and diagnose chain/name/provider filtering before changing issuer policy.

## Immediate runtime order

1. **T1R-B — NEXT:** in the same browser process after the successful T1R, allow a clear idle margin beyond the refreshed 5-second lease, then initiate an independent Treasury login that causes a fresh client-auth handshake. A new picker must appear; `Once` must not have become Session/Permanent.
2. **GIS-G1:** prove generic callback / issuer collection / candidate count on `portalgisgmp.cert.roskazna.ru`, then branch to GIS-G2 or issuer-chain diagnosis.
3. Continue Cancel/Abort, Session/Permanent, provider/media, picker UI, discovery, negative matrix and final server-trust closure.

Do not repeat T1R on this unchanged source merely for confirmation. Do not reopen the invalid old-build T1R attempt.

## Server trust — still mandatory

Positive Treasury server verification and peer-certificate acquisition have been demonstrated on earlier runtime sources, but final trust integration is not closed.

Required:

- fail closed if verification fails or status is nonzero;
- integrate Firefox temporary/permanent certificate overrides;
- positive browser-session verification cache keyed by exact server identity;
- valid Treasury positive case;
- wrong-hostname and untrusted/invalid-chain negative cases;
- no client private-key operation before server trust.

## Provider/private-key media evidence

Earlier source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, run `32844083378`, job `97789764275`, artifact `9567881847` proves:

- a certificate may remain in `CurrentUser\MY` while its CryptoPro private-key medium/container is unavailable;
- `CERT_KEY_PROV_INFO_PROP_ID` is binding metadata, not proof of live key availability;
- provider Cancel can fail only the current attempt with `SEC_E_NO_CREDENTIALS`;
- a later attempt can recover when the medium becomes available.

These scenarios need revalidation after F2/client-auth semantics stabilize.

## Windows Vista/7 compatibility — independent track

Current full-xul narrow YY/thunk-rs revalidation:

- source `ef1a7fdd...`;
- run `33039013822`, job `98408139313`;
- browser artifact `9636047031`;
- diagnostics `9636048172`.

Still open: full-Firefox msvcr14x integration, final direct/delay-load PE audit, real Win7 runtime without the copied compatibility bundle, broader Win7 runtime, and a separate exact GOST-on-Win7 milestone.

## Bundled government-system extensions — independent track

Current three-extension package checkpoint:

- source `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`;
- evidence artifact `9614275551`.

The portable archive contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and the Russian-first content-language preference. Clean-profile discovery/enabled-state is proven for all three project extensions.

Still open: CryptoPro functionality on this exact three-extension artifact, native-component tests for IFCPlugin and Gosplugin, runtime language-preference verification if desired, update behavior, and transfer/generalization of packaging gates.

## Separation of conclusions

- Build success != GOST handshake success.
- Coordinated runtime success != final server-trust closure.
- `client_cert_loaded=1` != private-key-use proof; completed mTLS is the proof.
- GOST runtime != Windows compatibility.
- Extension packaging != extension runtime, GOST runtime, or Win7 runtime.
- Docs HEAD != source-under-test SHA for an earlier binary.