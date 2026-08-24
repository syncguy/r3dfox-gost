# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog for work that is desired but not yet complete. `PROJECT_STATE.md` remains the authoritative current-state synthesis; `TEST_LOG.md` remains the evidence trail.

## GOST TLS runtime — next

### 1. Make server-certificate verification fail-closed

Current successful GOST sessions still log:

```text
DriveHandshake verify host=fzs.roskazna.ru ok=0 status=0x00000000
```

Pinned MSSPI runs client Schannel with manual credential validation. `msspi_get_verify_status()` verifies the peer certificate; in client mode that means the server certificate, including chain/policy, server-auth usage, hostname, and (by default) revocation handling.

This work is intentionally deferred until after the first successful controlled client-certificate mTLS proof. Do not add a special insecure/server-verification-bypass mode for that proof; simply keep the existing non-gating behavior while isolating the client-certificate path.

This deferral is only Stage 1 test scope. **Fail-closed server verification is mandatory Stage 2 mTLS work and must be completed before the project treats mTLS integration as finished.**

Later steps:

- log only sanitized diagnostics needed to determine why `msspi_get_verify_status()` returns 0;
- if needed, inspect peer-certificate and peer-chain retrieval status without publishing credential-derived identifiers;
- determine why verification returns its internal-error path on otherwise successful Treasury sessions;
- make the Firefox wrapper fail closed when `verifyOk == 0` as well as when the returned verification status is nonzero;
- prove a valid Treasury server certificate succeeds;
- prove a wrong hostname / invalid chain is rejected.

### 2. Add client-certificate / mutual TLS (mTLS) support

This was deliberately outside Phase 1, but it is now an explicit next functional milestone.

Pinned MSSPI already exposes the needed handshake mechanism:

- Schannel can return `SEC_I_INCOMPLETE_CREDENTIALS` when the server requests a client certificate;
- MSSPI then enters `MSSPI_X509_LOOKUP`;
- `msspi_set_cert_cb()` installs a dynamic certificate-selection callback;
- the application can load the explicitly selected client certificate with `msspi_set_mycert()` / related APIs;
- the selected certificate can come from the Windows certificate stores and retain its CryptoPro private-key binding.

Current Firefox GOST wrapper does not install an MSSPI certificate callback and does not select a client certificate.

#### Confirmed Treasury mTLS baseline

The first attempt established a routing prerequisite: Treasury login redirects from `fzs.roskazna.ru` to `https://lk-fzs.roskazna.ru/certificate-list`, so the login host must also be explicitly routed through the GOST provider. With only `fzs.roskazna.ru` allowlisted, ordinary NSS failed on the login host with `SSL_ERROR_NO_CYPHER_OVERLAP`; that was not an MSSPI/mTLS failure.

The follow-up capture used the same proven alternative artifact from run `32710363484`, job `97388836234`, source SHA `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`, with both exact hosts allowlisted. Uploaded archive: `gost_2_mTLS.zip`; inner log `gost.moz_log`; SHA-256 `7b8cb1d2b3bd8593f4a3bbd5d5df5ab6a274fec5c7e0ccfad8bdab955b10809e`.

The login-host behavior is now confirmed, not hypothetical:

- 15/15 `lk-fzs.roskazna.ru` attempts reach the GOST provider, HTTP CONNECT, `ProxyStartSSL()`, and MSSPI;
- the server handshake contains TLS `CertificateRequest` followed by `ServerHelloDone`;
- one decoded `CertificateRequest` has an 11,529-byte body and 34 acceptable CA distinguished names;
- MSSPI transitions to state `0x0000000A` = `MSSPI_READING | MSSPI_X509_LOOKUP` on all 15 attempts;
- because the Firefox wrapper has no `msspi_set_cert_cb()` callback and the client credentials use `SCH_CRED_NO_DEFAULT_CREDS`, merely placing certificates in the Windows `MY` store does not cause automatic selection;
- Schannel sends an empty TLS client `Certificate` message (`0B 00 00 03 00 00 00`), then continues with ClientKeyExchange / ChangeCipherSpec / Finished;
- the server responds on all 15 attempts with TLS fatal `handshake_failure` (`15 03 03 00 02 02 28`);
- Schannel surfaces the alert as `0x80090326` (`SEC_E_ILLEGAL_MESSAGE`), leaving MSSPI in `0x40000008` = `MSSPI_ERROR | MSSPI_X509_LOOKUP`;
- no `MSSPI handshake complete` occurs for `lk-fzs.roskazna.ru`.

This is the current exact mTLS blocker: **the server requests a client certificate correctly, but the Firefox GOST wrapper does not select/load one into MSSPI.**

#### Sensitive-data rule for mTLS work

The repository is public. Any concrete client-certificate identifier used during local testing is sensitive and must remain local. Do not commit or print to CI/public logs complete certificate SHA-1/SHA-256 fingerprints/thumbprints, serial numbers, key IDs, identifying subject/issuer DNs, private-key container/provider identifiers, PINs/passwords, PFX contents, form contents, account data, or other credential/user-originated values. Documentation should use placeholders such as `<local-cert-id>` or `known-good client certificate`. Artifact/log hashes may be retained for reproducibility only when they are not certificate-derived identifiers and the artifact itself is sanitized.

#### Stage 1 — first controlled successful mTLS proof

Keep the first implementation deliberately narrow. The user already trusts the exact Treasury login endpoint and will explicitly provide the intended client certificate locally.

For this first proof:

- do **not** make server-certificate validation a prerequisite or gate;
- do **not** introduce or expose a special insecure/server-verification-bypass option, environment variable, build flag, or CI mode;
- do **not** make `msspi_get_issuerlist()` matching a prerequisite for selecting the certificate;
- do **not** auto-discover or auto-select among certificates in `MY`;
- accept one explicitly supplied local certificate selector and use it only to load the intended certificate into MSSPI;
- the concrete selector value must never be printed to logs, Actions output, diagnostics artifacts, commit messages, repository documentation, PRs, or issues.

The Stage 1 goal is only to establish the client-authentication path:

```text
CertificateRequest
  -> MSSPI_X509_LOOKUP
  -> msspi_set_cert_cb()
  -> explicitly selected local certificate
  -> msspi_set_mycert()
  -> CryptoPro private-key operation / PIN if required
  -> non-empty client Certificate / CertificateVerify
  -> completed mTLS handshake
  -> successful personal-cabinet request/navigation
```

Stage 1 is complete only when a sanitized runtime log tied to an exact Actions run ID and exact source commit SHA proves the successful mTLS handshake and authenticated application traffic/navigation.

#### Stage 2 — mandatory mTLS technical-debt and security closure

**Stage 2 is mandatory. A successful Stage 1 trace does not mean mTLS work is complete. Do not mark the mTLS milestone finished, production-ready, or closed until Stage 2 is completed.**

After the first successful client-certificate connection, immediately perform the following debt/security work:

1. Fix server-certificate verification so the MSSPI GOST path is fail-closed. Diagnose the current `msspi_get_verify_status()` internal-error result using sanitized diagnostics only; reject both `verifyOk == 0` and nonzero verification status once the verification path is understood.
2. Prove server verification with positive and negative cases: the real Treasury server/hostname must pass, while a wrong hostname or invalid/untrusted chain must fail.
3. Decide and implement the final role of the server-provided acceptable-issuer list (`msspi_get_issuerlist()`) in client-certificate filtering/selection. The Stage 1 explicit selector intentionally bypasses this policy question; Stage 2 must resolve it rather than silently carrying the bypass forward.
4. Replace the Stage 1 local explicit-selector mechanism with an appropriate Firefox-facing certificate-selection flow. The final design must not depend on hard-coded certificate identifiers or require publishing local certificate identifiers in repository/CI state.
5. Implement and test negative client-authentication paths: no suitable certificate, user cancellation, wrong certificate, missing/unavailable private key, CryptoPro PIN/private-key failure, and server rejection.
6. Audit mTLS diagnostics and logging so no complete certificate fingerprint/thumbprint, serial, key ID, identifying subject/issuer DN, provider/container identifier, PIN/password, PFX content, account data, or other sensitive user-derived value is emitted to public logs or artifacts.
7. Re-run the successful Treasury mTLS scenario after the Stage 2 changes and preserve a sanitized exact-run/exact-SHA regression trace proving that security/UX hardening did not break client authentication.

Only after all applicable Stage 2 items are complete may the project treat mTLS integration as closed. Any deliberately deferred item must be explicitly approved by the user and remain recorded as an open blocker/debt item rather than disappearing from the plan.

#### Planned implementation/evidence sequence

1. Stage 1: add the narrow `msspi_set_cert_cb()` handling needed for `MSSPI_X509_LOOKUP`, without changing the already-working proxy/lower-I/O path.
2. Stage 1: load exactly one explicitly selected known-good CryptoPro certificate from Windows `MY` with `msspi_set_mycert()` while preserving its private-key provider binding. Keep the selector strictly local and silent.
3. Stage 1: prove that the client sends a non-empty certificate, performs the private-key operation / `CertificateVerify`, and completes the mTLS handshake.
4. Stage 1: prove successful personal-cabinet navigation or the corresponding authenticated application request, including any CryptoPro PIN interaction, without logging credential identifiers or user data.
5. Stage 2: complete every applicable item in the mandatory technical-debt/security closure section above before closing the mTLS milestone.

### 3. Broaden proxy/network coverage later

The current proven environment is an ordinary HTTP proxy using CONNECT. Keep these as separate later cases rather than changing the now-working HTTP-proxy path blindly:

- direct connection without proxy;
- HTTPS proxy / nested TLS-to-proxy then GOST TLS-to-origin;
- SOCKS lifecycle;
- proxy authentication/reconnect edge cases beyond the currently exercised ASUGATE path.

## Windows Vista/7 compatibility — next/deferred

1. Integrate the already-proven representative `msvcr14x + modern Rust/libstd + narrow YY-Thunks` combination into one full Firefox/xul build while preserving `/MD`.
2. Audit the resulting Firefox PE set for direct `api-ms-win-*`, `ext-ms-*`, `VCRUNTIME140*.dll`, and known Win8+ hard imports.
3. Run that msvcr14x-integrated portable build on real Windows 7 without the current copied API-set/UCRT compatibility bundle.
4. Fix/replay the delay-load import parser and classify relevant post-Win7 delay-loaded APIs by guarded runtime path.
5. Expand Windows 7 runtime coverage beyond basic startup.
6. Run GOST TLS on Windows 7 as a separate exact-run/exact-SHA runtime milestone; do not infer it from loader/startup compatibility.

## Upstream r3dfox base tracking — deferred

The project is a fork of `Eclipse-Community/r3dfox`, not a direct Firefox-upstream port. As of 2026-08-24 the upstream r3dfox repository default branch is still `win-153`.

Policy:

- continue development on the current r3dfox 153 base;
- monitor `Eclipse-Community/r3dfox` for a new maintained baseline;
- do not migrate this project directly to Mozilla Firefox 154 merely because Mozilla has released it;
- when r3dfox itself publishes a 154-or-later baseline, evaluate the migration deliberately: compare GOST integration points, Windows compatibility changes, MSSPI/NSPR/NSS interfaces, build workflows, and regression risk;
- perform any base upgrade only after explicit user decision.

## Already confirmed — do not reopen without new evidence

- HTTP proxy CONNECT lifecycle works for the tested ASUGATE environment.
- GOST TLS 1.2 handshake completes with `fzs.roskazna.ru` and negotiates suite `0xFF85`.
- Protected application traffic works.
- Treasury pages fully render with JavaScript and images.
- Interactive forms, information requests, and web-service response-list workflows work in the alternative thunk-rs full build.
- The same GOST TLS source commit works in both current full-build strategies.
- `lk-fzs.roskazna.ru` is confirmed GOST-routed when explicitly allowlisted and is confirmed to request a client certificate; the remaining failure is client-certificate selection/loading, not cipher overlap or proxy routing.
