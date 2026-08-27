# Stage 2 GOST TLS — GIS GMP multi-host mTLS checkpoint

Last updated: 2026-08-27

Purpose: preserve and resolve the GIS GMP (`pay.gov.ru`) client-auth case inside the current Stage 2 runtime campaign without repeating already-completed Treasury tests. This is a sub-plan of `STAGE2_RUNTIME_TEST_PLAN.md`; `STAGE2_PLAN.md` remains the security/architecture contract.

## Evidence identity

Current browser/source used by the surrounding Stage 2 campaign:

- source-under-test: `860de8e38deed326b7fcd1c547e928c5b48c72a9`;
- main Actions run: `32951903026`, attempt 2;
- job: `98130275465`;
- artifact: `9606431408` (`r3dfox-gost-win64-release`).

Exploratory command supplied by the user:

```bat
set "R3DFOX_GOST_HOSTS=pay.gov.ru,portalgisgmp.login.roskazna.ru,portalgisgmp.cert.roskazna.ru"
set "R3DFOX_GOST_CLIENT_CERT_THUMBPRINT="
set "R3DFOX_GOST_CLIENT_AUTH_MODE="
set "R3DFOX_GOST_CIPHERS="

r3dfox.exe -no-remote ^
  -profile C:\Temp\r3dfox\profile ^
  --MOZ_LOG=timestamp,sync,GostTLS:5 ^
  --MOZ_LOG_FILE=C:\Temp\r3dfox\gost ^
  https://pay.gov.ru/
```

Runtime capture later supplied for this exact described session:

- `gost_pay.gov.ru.zip`, SHA-256 `2e9630e5d8048482ebc6a3d3ac0576db6af2c6b4e108c3c1de6ea4e30d99596b`;
- inner `gost.moz_log`, SHA-256 `f32fd8bf7067dd487e79121faf467f1038906d91ed958df87c572aff991bc5ed`;
- capture span: `2026-08-27 03:28:19.547 UTC` through `03:28:55.898 UTC` (`36.351 s`);
- `51,925` log lines.

The raw capture is not committed. Only sanitized protocol/lifecycle facts and non-sensitive artifact hashes are recorded.

## Runtime-proven GIS GMP path on the old coordinated artifact

The capture upgrades the initial source-only diagnosis to runtime proof.

### `pay.gov.ru`

- matches the explicit GOST allowlist;
- MSSPI GOST layer attaches;
- `verify ok=1 status=0x00000000`;
- one TLS 1.2 / `0xFF85` handshake completes;
- `client_cert_loaded=0`.

### `portalgisgmp.login.roskazna.ru`

- matches the explicit GOST allowlist;
- five GOST TLS handshakes complete in the capture;
- all five are TLS 1.2 / `0xFF85`;
- all five reach `verify ok=1 status=0x00000000`;
- `client_cert_loaded=0`.

This independently confirms the user-visible result that the public GIS GMP site and its password-login page work through the GOST transport.

### `portalgisgmp.cert.roskazna.ru`

The certificate-login action **does reach the certificate endpoint at the network layer**. The capture contains three distinct allowlist matches and GOST-layer attachments for the host, beginning at:

- `03:28:45.657 UTC`;
- `03:28:50.793 UTC`;
- `03:28:52.295 UTC`.

All three handshakes fail before completion. There is no `MSSPI handshake complete` or final verification marker for this host.

The first handshake can be reconstructed from the sanitized TLS record structure:

- server sends TLS 1.2 `CertificateRequest` (handshake type `13`);
- `CertificateRequest` body length is `12,184` bytes;
- its `certificate_authorities` vector is `12,143` bytes;
- it contains **36 DER Distinguished Names**, all decodable as X.509 `Name` values;
- the client then sends TLS `Certificate` message prefix `0B 00 00 03 00 00 00`, i.e. a zero-length `certificate_list`;
- the same empty client-certificate message occurs on all three certificate-host attempts;
- the server returns TLS fatal alert level `2`, description `0x28` (`handshake_failure`);
- MSSPI reports primary `0x80090326` on each attempt; later calls against the already-failed handles emit the known secondary `0x0000054f` diagnostics.

No `client certificate ...`, `issuer-list ...`, or `AddToSocket set_cert_cb ...` marker for `portalgisgmp.cert.roskazna.ru` appears in the capture.

Therefore the user-visible lack of transition is downstream of the mTLS failure: the browser **does** connect to the cert host, but sends no client certificate and the server rejects the handshake.

## Runtime-confirmed blocker — client auth is still Treasury-host-specific

The current source retains `kStage1MtlsHost = "lk-fzs.roskazna.ru"` from the Stage 1 proof.

There are two independent host gates:

1. In socket setup, `msspi_set_cert_cb(..., SelectStage1ClientCertificate)` is registered only when `aHost` equals `kStage1MtlsHost`. Therefore a normal GOST socket for `portalgisgmp.cert.roskazna.ru` has no Firefox/MSSPI client-certificate callback registered.
2. The wrapper callback itself obtains the current host and rejects any host other than `lk-fzs.roskazna.ru` before issuer logging, coordinated decision lookup/creation, candidate enumeration or picker dispatch.

The supplied capture exactly matches this source behavior: the real GIS GMP server sends `CertificateRequest`, but the browser never enters our client-auth callback/coordinator and emits an empty TLS client Certificate instead.

This is a separate blocker from:

- F1: close/shutdown re-entrancy and orphan decision;
- F2: positive `Once` lifetime across sequential Treasury connection waves.

Call this blocker **F3 — generic GOST mTLS host scope**.

## What the real GIS GMP CA list does and does not prove

The earlier hypothesis that GIS GMP may advertise a different trusted-CA set remains relevant, but it is now narrowed:

- the server definitely advertises a non-empty CA list;
- the observed list contains 36 DER DNs;
- current artifact `9606431408` never runs our `CollectGostCANames()` / candidate filtering on this host;
- therefore this capture cannot yet tell whether the user's intended certificate chain matches one of those 36 authorities under our current policy.

Do **not** modify issuer matching merely because the list is different or large. First make F3 reach the existing candidate machinery and obtain the actual candidate count.

## Existing CA/candidate machinery that becomes relevant after F3

Once the callback is allowed to run for `portalgisgmp.cert.roskazna.ru`, the existing code already performs generic server-issuer-driven discovery:

1. `CollectGostCANames()` obtains the `CertificateRequest` acceptable-CA distinguished names from MSSPI.
2. `CollectGostClientCertCandidates()` enumerates `CurrentUser\MY`.
3. A certificate without `CERT_KEY_PROV_INFO_PROP_ID` is rejected.
4. `GostClientCertMatchesCANames()` builds a Windows certificate chain and checks every chain element's Subject and Issuer against the server CA names.
5. An empty server CA list currently means the certificate is not rejected by CA-name policy.

The current name matcher is deliberately simple: `GostCertNameEquals()` requires equal DER length and byte-for-byte equality (`memcmp`). This may be sufficient when the server advertises the exact encoded DN present in the local chain, but it is a possible second compatibility boundary for other PKIs/cross-signed chains.

If GIS GMP reaches the callback after F3 but reports zero candidates, investigate in this order:

- server acceptable-CA count and exact binary identities;
- whether the intended local certificate chain actually contains one of those authorities;
- whether Windows chain building selected a different cross-signed path;
- whether raw DER-name equality rejects names that Windows considers identical (`CertCompareCertificateName` is a candidate comparison primitive);
- whether the expected certificate was excluded earlier by provider/private-key binding requirements.

Do not publish client-certificate identifying DNs, serials, fingerprints, provider/container identifiers or private data while doing that analysis.

## F3 design requirements

The final architecture must not have a special hard-coded mTLS hostname. Client authentication is a property of a particular GOST TLS handshake: if an explicitly selected/allowlisted GOST endpoint sends `CertificateRequest`, the generic Firefox client-auth path must be available.

Required behavior:

1. Register the MSSPI client-certificate callback for every applicable GOST MSSPI socket, not only `lk-fzs.roskazna.ru`.
2. Remove the `lk-fzs.roskazna.ru` rejection from the normal Firefox-UI/coordinated callback path.
3. Do **not** broaden backend selection: only sockets already routed to the GOST layer by the existing allowlist/session-discovery policy are affected.
4. Do **not** automatically send a client certificate merely because the callback is registered. The callback is exercised only when the remote GOST TLS server requests client authentication, and the Firefox selection/remember policy still controls the result.
5. Keep coordinated decision isolation by actual normalized host, port, OriginAttributes and acceptable-CA identity. A Treasury decision must never be reused at GIS GMP merely because the same local certificate could satisfy both.
6. Preserve `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` as a narrow diagnostic/reference path. Do not silently make a locally configured Treasury diagnostic thumbprint an automatic cross-site credential selector for every allowlisted GOST mTLS host.
7. Preserve the legacy A/B path as cleanly as practical. Prefer adding generic registration/dispatch in the wrapper/coordinated integration instead of unnecessarily rewriting the proven legacy core.
8. Add concise diagnostics sufficient to prove: callback registered for host, server requested client cert, acceptable-CA count obtained, candidate count, decision created/joined, and final selection outcome.

F3 should be a separable code change/conclusion even if F1/F2/F3 are included in one final full-build candidate to avoid redundant multi-hour builds.

## Build order

Before asking for GIS GMP runtime retesting:

1. implement F1, F2 and F3 as separately attributable changes;
2. run the short `GOST SSL compile check` against the exact final candidate SHA;
3. run the authoritative main `GOST TLS PoC build` and record run/attempt/job/artifact;
4. continue to use the main artifact for GOST runtime conclusions; the thunk-rs artifact remains a separate Windows-compatibility line.

## Runtime order on the next fixing artifact

The core coordinator regressions remain first:

1. **T2R** — unanswered Treasury picker timeout/teardown must recover and a later attempt must show a fresh picker.
2. **T1R** — one successful logical Treasury login under default `Once` should need one picker while compatible concurrent/sequential sockets receive the positive decision safely.
3. Then run the GIS GMP branch below.

Do not repeat old-artifact T1/T2 or the old GIS GMP capture merely to recreate history.

## GIS-G1 — reach the GIS GMP mTLS decision point

Procedure:

1. start a fresh process with the three-host GIS GMP allowlist shown above;
2. open `https://pay.gov.ru/`;
3. reach `portalgisgmp.login.roskazna.ru`;
4. choose login by certificate;
5. observe `portalgisgmp.cert.roskazna.ru` and capture the GOST log;
6. if a picker appears, do not leave it unanswered long enough to create an unrelated timeout test; either make the planned selection or close the attempt deliberately according to the test branch.

Pass for F3 reachability:

- GOST layer attaches to the certificate endpoint;
- MSSPI client-cert callback is registered for `portalgisgmp.cert.roskazna.ru`;
- the real server `CertificateRequest` reaches our callback;
- acceptable-CA collection executes and records an explicit count;
- candidate enumeration executes and records an explicit count;
- the attempt no longer emits an empty TLS Certificate merely because the host differs from `lk-fzs.roskazna.ru`.

The old capture established a 36-DN CA list. GIS-G1 must treat the new server response as authoritative and record the then-current count rather than assuming it is permanently 36.

### GIS-G1A — candidates > 0

If `candidate count > 0`:

- Firefox picker must appear with only policy-eligible candidates;
- continue to GIS-G2.

### GIS-G1B — candidates == 0

If `candidate count == 0`, stop the login branch and preserve the capture. Do not repeatedly click through the site.

Diagnose the CA/candidate policy using sanitized evidence:

- CA count / binary identity only as needed;
- local chain structure without publishing the user's certificate identity;
- raw DER comparison versus Windows name comparison;
- cross-signed chain path selection;
- provider-binding filter.

Implement the narrowest justified issuer-matching fix, compile/build again if code changes, then repeat GIS-G1. A zero-candidate result must remain non-sticky.

## GIS-G2 — complete real GIS GMP GOST mTLS

Precondition: GIS-G1 produces a valid picker candidate.

Procedure:

1. select the intended certificate using default `Once`;
2. complete any legitimate CryptoPro private-key interaction promptly for this positive-path test;
3. observe TLS completion and application navigation.

Pass:

- selected certificate reaches MSSPI;
- server verification is positive under the currently implemented policy (final fail-closed closure remains its separate Stage 2 gate until completed);
- GOST TLS 1.2 mTLS handshake completes;
- successful handshake, not merely `client_cert_loaded=1`, proves actual private-key use;
- authenticated GIS GMP application flow proceeds beyond the certificate endpoint;
- no Treasury-specific state is required.

If GIS GMP creates parallel or sequential connection waves, the same F1/F2 lifecycle invariants apply: no orphan decisions, one logical `Once` interaction where compatible, and no cross-host decision leakage.

## GIS-G3 — no spurious picker on non-mTLS GOST hosts

Verify `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` do not show a certificate picker merely because the callback is generically registered when those handshakes do not request client authentication.

Pass: generic callback registration changes capability, not behavior; UI appears only after an actual server client-cert request.

## GIS-G4 — cross-host decision isolation

A positive Treasury `Once`/Session/Permanent decision and a GIS GMP decision must remain separated by the actual decision key and Firefox remember semantics.

At minimum prove that a Treasury `Once` choice is never silently applied to `portalgisgmp.cert.roskazna.ru`. If the same certificate is valid for both, each independent host still follows its own explicit remember policy.

## Stop / recovery rules

- The old artifact/runtime capture now completely proves the host-scope failure mechanism; do not ask the user to repeat GIS GMP on `9606431408`.
- The supplied old-artifact capture proves a real non-empty `CertificateRequest` with 36 CA DNs and an empty client Certificate; it does **not** prove whether the user's intended certificate would pass our own candidate filter after F3.
- After F3, the first new GIS GMP capture is authoritative for the current server CA list and candidate result.
- If GIS-G1 returns zero candidates, solve that branch before GIS-G2; do not misclassify zero candidates as a coordinator or timeout failure.
- Keep GIS GMP work inside the GOST runtime track. It is independent of Win7 compatibility and bundled-extension testing.
- Append each meaningful GIS GMP runtime result to `TEST_LOG.md` with exact source/run/job/artifact/capture hashes and update `PROJECT_STATE.md` / `TODO.md` when the blocker changes.
