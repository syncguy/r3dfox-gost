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
- default `Once` uses a positive-only fanout lease with a 5-second idle lifetime; each successful reuse refreshes the idle expiry.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Confirmed GOST milestones

### Basic Treasury GOST HTTPS

- source `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- main run `32710363486`, job `97380247020`, artifact `9518011746`.

Real Treasury HTTP CONNECT, GOST TLS 1.2 / `0xFF85`, protected HTTP application traffic and browser rendering are proven.

### Stage 1 explicit-selector Treasury mTLS

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
- `xul.dll` SHA-256 `8cee03269e18dff2bc48d5c25bef34a6c62c520908d937e3b3e4a03031d0ab68`.

The valid T1R/T1R-B evidence is bound to this artifact. An earlier `t1r_error.zip` was later confirmed by the user to have been produced from an older browser build and is historical invalid-test evidence only.

## Stage 2 coordinated runtime checkpoint

### F1 — close/shutdown client-auth lifecycle — CLOSED

T2R on artifact `9636591432` passed across three unanswered-picker timeout cycles:

- capture `t2r_timeout.zip` SHA-256 `88053089499fee19edf7506d4fe257567dcc688740741313ff9430749e84bba7`;
- inner log SHA-256 `261ddf9a4008c212f1ee5b5ec2213ab0fb3ee6e6a244e586987ff04a8de8d5`;
- 3 decisions created and removed;
- 3 pre-close waiter removals reaching zero waiters;
- 3 shutdown-time callbacks rejected with `reason=closing`;
- 3 abandoned UI callbacks rejected as stale;
- no shutdown-created orphan decision;
- zero `selected=0`, `0x80090326`, `0x0000054f`, or `MSSPI_X509_LOOKUP`.

Measured picker-to-close intervals were `32.576`, `37.420`, and `30.330 s`. Poll counts were `10,825`, `34`, and `21`; timeout-source attribution and first-cycle poll churn remain separate non-blocking work and do not reopen F1.

### F2 — positive default-`Once` fanout/scope — CLOSED

T1R and T1R-B on source `ef1a7...`, run `33039013849`, job `98408139479`, artifact `9636591432` prove both sides of the intended default-`Once` behavior.

T1R capture:

- `t1r-current.zip` SHA-256 `1c75f484607a6e3eb95439275e2698098a04551689619f95f93f13ca890b248e`;
- inner log SHA-256 `9f77de380e9ebf9b98f2e7cf2d3c0d6eb03233eb7afed0d103b2ecbf49bc78c7`.

T1R proves one visible picker for one logical Treasury login, one positive lease store, seven lease reuses across sequential waves, and eight successful `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes with `client_cert_loaded=1`. The protected personal cabinet loads and behaves normally.

T1R-B capture:

- `T1R-B-current.zip` SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`;
- inner `t1r-current.moz_log` SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`.

T1R-B stays in the same process (`Parent 6204`) and same browser context (`browser_id=14`). Generation 1 is last reused at `09:07:13.004 UTC`, nominally expires at `09:07:18.004`, and a real independent client-auth request at `09:09:44.169` creates fresh `decision=2` plus a new picker rather than reusing generation 1. This is `151.165 s` after the final reuse and `146.165 s` after nominal expiry. A new positive choice stores generation 2 at `09:09:46.616` and the new attempt completes GOST mTLS.

Whole T1R-B capture: 2 decisions, 2 picker requests, 2 positive lease stores, 11 generation-1 reuses, 14 successful login-host mTLS handshakes, and zero `selected=0`, `0x80090326`, `0x0000054f`, `MSSPI_X509_LOOKUP`, stale callbacks, or `E/GostTLS`.

Therefore default `Once` now has the intended attempt-local positive fanout semantics: compatible waves within the idle lease reuse one user choice, while an independent post-expiry attempt asks again. F2 is formally closed for this tested artifact.

### F3 — generic GOST mTLS host scope — NEXT RUNTIME BLOCKER

Old GIS GMP runtime on artifact `9606431408` proved:

- `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` complete GOST TLS 1.2 / `0xFF85`;
- certificate login reaches `portalgisgmp.cert.roskazna.ru`;
- the certificate endpoint sends a real TLS 1.2 `CertificateRequest` with a non-empty CA list (36 DER DNs in that old capture);
- the old Treasury-only callback scope caused an empty client Certificate and server fatal `handshake_failure` / MSSPI `0x80090326`.

Current source registers the normal coordinated callback generically for already-selected GOST sockets. **GIS-G1 is now next.** It must prove the real certificate endpoint receives the GOST layer and generic callback, that the server `CertificateRequest` reaches issuer collection, and must record the current acceptable-CA and local candidate counts. Do not assume the old count of 36 is unchanged.

If candidate count > 0, continue GIS-G2 real mTLS/application login. If candidate count == 0, stop and diagnose actual server CA identities/local chain/name/provider filtering before changing issuer policy.

## Immediate runtime order

1. **GIS-G1 — NEXT:** validate generic callback / issuer collection / candidate count on `portalgisgmp.cert.roskazna.ru`; branch to GIS-G2 if candidates are nonzero or issuer-chain diagnosis if zero.
2. Continue explicit Cancel/no-certificate vs Abort, explicit Session/Permanent, provider/media, picker UI, discovery, negative matrix and final server-trust closure.
3. Keep timeout-source/poll-churn attribution as separate non-blocking work.

Do not repeat T1R/T1R-B on this unchanged source merely for confirmation.

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

These scenarios need revalidation after the immediate GIS branch.

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