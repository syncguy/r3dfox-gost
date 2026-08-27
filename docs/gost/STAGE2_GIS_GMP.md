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

No new runtime capture was supplied with this observation. Therefore the exact TLS error/timing/issuer-list contents for the GIS GMP attempt are **not** claimed here. The deterministic source restriction below is independently established from the exact source-under-test.

## User-visible exploratory observation

1. `pay.gov.ru` is successfully entered through the GOST transport.
2. The browser reaches `portalgisgmp.login.roskazna.ru`, also through GOST TLS, and displays the password-login page.
3. The page offers an alternative login-by-certificate action which is expected to use `portalgisgmp.cert.roskazna.ru` as the GOST mTLS endpoint.
4. Activating certificate login does not produce the expected visible transition and no Firefox client-certificate picker appears.

The initial hypothesis was that GIS GMP may advertise a different acceptable-CA list. That remains a valid **second-stage** hypothesis, but the current source has an earlier guaranteed blocker which prevents this hypothesis from being exercised.

## Source-proven blocker — client auth is still Treasury-host-specific

The current source retains `kStage1MtlsHost = "lk-fzs.roskazna.ru"` from the Stage 1 proof.

There are two independent host gates:

1. In socket setup, `msspi_set_cert_cb(..., SelectStage1ClientCertificate)` is registered only when `aHost` equals `kStage1MtlsHost`. Therefore a normal GOST socket for `portalgisgmp.cert.roskazna.ru` has no Firefox/MSSPI client-certificate callback registered at all.
2. The wrapper callback itself obtains the current host and rejects any host other than `lk-fzs.roskazna.ru` before issuer logging, coordinated decision lookup/creation, candidate enumeration or picker dispatch.

Consequently, on source `860de8e...`, GIS GMP cannot reach the current Firefox client-auth UI path regardless of which certificate authorities its server advertises. The absence of a picker is therefore explained at source level before CA filtering.

This is a separate blocker from:

- F1: close/shutdown re-entrancy and orphan decision;
- F2: positive `Once` lifetime across sequential Treasury connection waves.

Call this new blocker **F3 — generic GOST mTLS host scope**.

## Existing CA/candidate machinery that becomes relevant after F3

Once the callback is allowed to run for `portalgisgmp.cert.roskazna.ru`, the existing code already performs generic server-issuer-driven discovery:

1. `CollectGostCANames()` obtains the `CertificateRequest` acceptable-CA distinguished names from MSSPI.
2. `CollectGostClientCertCandidates()` enumerates `CurrentUser\MY`.
3. A certificate without `CERT_KEY_PROV_INFO_PROP_ID` is rejected.
4. `GostClientCertMatchesCANames()` builds a Windows certificate chain and checks every chain element's Subject and Issuer against the server CA names.
5. An empty server CA list currently means the certificate is not rejected by CA-name policy.

The current name matcher is deliberately simple: `GostCertNameEquals()` requires equal DER length and byte-for-byte equality (`memcmp`). This may be sufficient when the server advertises the exact encoded DN present in the local chain, but it is a possible second compatibility boundary for other PKIs/cross-signed chains. Do not change it speculatively before obtaining GIS GMP evidence after F3.

If GIS GMP later reaches the callback but reports zero candidates, investigate in this order:

- server acceptable-CA count and exact binary identities;
- whether the user's intended certificate chain actually contains one of those authorities;
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

Do not repeat old-artifact T1/T2 merely to recreate history.

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
- server client-auth request reaches our callback;
- acceptable-CA collection executes;
- candidate enumeration executes;
- the attempt no longer fails merely because the host differs from `lk-fzs.roskazna.ru`.

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

- The old artifact already proves the host-scope blocker from source; do not ask the user to repeat GIS GMP on `9606431408` just to confirm the same missing callback.
- No runtime capture was supplied for the exploratory GIS GMP observation, so do not invent exact error codes or issuer-list contents for that attempt.
- After F3, the first new GIS GMP capture is the authoritative evidence for the real server CA list and candidate result.
- If GIS-G1 returns zero candidates, solve that branch before GIS-G2; do not misclassify zero candidates as a coordinator or timeout failure.
- Keep GIS GMP work inside the GOST runtime track. It is independent of Win7 compatibility and bundled-extension testing.
- Append each meaningful GIS GMP runtime result to `TEST_LOG.md` with exact source/run/job/artifact/capture hashes and update `PROJECT_STATE.md` / `TODO.md` when the blocker changes.
