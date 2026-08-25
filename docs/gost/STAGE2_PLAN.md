# r3dfox GOST TLS — Stage 2 plan

Last updated: 2026-08-25

This document is the detailed execution plan for the mandatory Stage 2 security/UX closure after the successful Stage 1 Treasury mTLS proof at source SHA `f5d04896e17f91f58b6a137af823360f4718eb29`.

`PROJECT_STATE.md` remains the current synthesis, `TODO.md` remains the forward backlog, and `TEST_LOG.md` remains the active evidence trail. This file defines the ordered Stage 2 implementation sequence and its invariants.

## Security and performance invariants

1. A GOST connection may continue only after the presented server certificate is accepted by one of these paths:
   - a matching Firefox temporary certificate override;
   - a matching Firefox permanent certificate override;
   - a successful full server-certificate verification performed earlier in the same browser session for the same server-certificate identity;
   - a successful full server-certificate verification performed on the current connection.
2. Existing Firefox certificate overrides are checked before full verification. If the exact presented certificate already has a matching temporary or permanent override, full verification is skipped.
3. The positive verification cache is browser-session/process scoped only. It is not written to disk and is discarded when the browser exits.
4. The positive verification-cache key must intentionally overlap Firefox override identity semantics: normalized ASCII host, normalized port, OriginAttributes, and SHA-256 identity of the exact presented server leaf certificate. A changed server certificate therefore causes a cache miss and requires a new trust decision.
5. Only successful full verification is entered into the positive session cache. Verification failure is never converted into trust by the cache.
6. No client certificate, client `CertificateVerify`, CryptoPro private-key proof, or protected application data may be disclosed before server trust is established through a matching Firefox override or successful verification/cache hit.
7. The server-provided acceptable-CA/issuer list is diagnostic and later selection-policy input. A full detailed dump must not be repeated on every TLS connection. Each unique issuer list for a host/port is logged in full only on its first appearance during a browser session; repeated identical lists produce only compact cache-hit diagnostics.
8. If an endpoint changes its issuer list during the same browser session, the changed list is a new diagnostic identity and is dumped in full once.
9. Concrete client-certificate identifiers and private user data remain subject to the public-repository sanitization rules in `/AGENTS.md`. Server public-certificate and server issuer-policy diagnostics may be inspected locally, but permanent documentation should retain only the details needed for engineering conclusions.

## Firefox override identity

The existing Firefox `nsCertOverrideService` stores and matches overrides using:

- ASCII hostname;
- normalized port;
- OriginAttributes;
- SHA-256 fingerprint of the exact presented certificate.

Temporary overrides live only for the session. Permanent overrides are written to the Firefox profile. Stage 2 must reuse this mechanism rather than introduce a GOST-only trust database or production environment variable that disables verification.

The intended fast-path order is:

```text
server Certificate received
  -> build exact server-certificate identity
  -> Firefox HasMatchingOverride(host, port, OriginAttributes, cert)
       -> hit: accept immediately; do not run full verification
       -> miss: positive browser-session verification cache lookup
            -> hit: accept immediately
            -> miss: run full verification
                 -> success: insert positive session-cache entry and accept
                 -> failure: stop; later surface Firefox certificate-error/override UX
```

## Stage 2.1 — observability first

Purpose: understand the current `msspi_get_verify_status()` `ok=0/status=0` behavior and obtain the complete server acceptable-issuer policy without changing the already-proven Stage 1 client-certificate selection behavior.

Implementation requirements:

1. Keep current Stage 1 handshake acceptance behavior unchanged for this diagnostic implementation.
2. Add structured server-verification diagnostics around `msspi_get_verify_status()`:
   - returned boolean/result;
   - verification status;
   - `msspi_last_error()` immediately after the call;
   - MSSPI state;
   - peer-certificate count retrieval result/error;
   - peer-chain count retrieval result/error;
   - server subject/issuer retrieval result and lengths when available.
3. When MSSPI enters the client-certificate lookup path and `msspi_get_issuerlist()` is available, retrieve the complete issuer list using the documented two-pass API.
4. Build an exact binary identity of the complete issuer list for browser-session deduplication. The identity must include entry boundaries/lengths, not merely concatenated text.
5. On the first appearance of a unique list for a host/port during the browser session, log:
   - host and port;
   - issuer count;
   - total DER bytes;
   - each issuer index and DER length;
   - a canonical formatted X.500 DN where Windows can format it;
   - decoded ASN.1 `CERT_NAME_INFO` structure;
   - each RDN and each attribute within it;
   - attribute OID;
   - OID friendly name when Windows knows it;
   - ASN.1/RDN value type;
   - decoded textual value when Windows can convert it;
   - a clear decode/format failure and Windows error when a field cannot be decoded.
6. At debug level, preserve enough DER diagnostics to recover from formatter ambiguity without requiring the original raw TLS handshake dump. Do not automatically copy the full issuer table into public `TEST_LOG.md`.
7. On repeated identical issuer lists, emit one compact `already_logged=1`/cache-hit line rather than repeating the table.
8. If the list changes, log the new list in full once.
9. Do not yet use the issuer list to reject or filter the Stage 1 explicitly selected local client certificate. Filtering belongs to a later stage after the real server policy has been inspected.

Evidence required before Stage 2.1 is closed:

- SSL target compile gate passes for the exact implementation SHA;
- one sanitized runtime capture shows verification diagnostics sufficient to explain or further localize `verifyOk=0`;
- one runtime capture shows the full acceptable-issuer list decoded once and subsequent repeated TLS connections suppressing duplicate full dumps;
- the existing Stage 1 Treasury mTLS path still completes.

## Stage 2.2 — server trust decision and positive session cache

After Stage 2.1 explains the verifier behavior:

1. Create/reuse an `nsIX509Cert` representation of the exact server leaf certificate.
2. Check `nsCertOverrideService::HasMatchingOverride` first using host, normalized port, OriginAttributes, and that certificate.
3. If a matching temporary or permanent override exists, accept without invoking full server verification.
4. Otherwise check the process/session positive-verification cache using the same identity dimensions: host, port, OriginAttributes, SHA-256(server leaf certificate).
5. On a cache miss, perform full verification.
6. On full-verification success, insert the identity into the positive session cache.
7. On verification failure or internal verification failure, do not insert anything and stop automatic continuation.
8. Invalidate/clear the positive cache on browser shutdown and when trust/certificate-database policy changes in a way that makes an old successful decision stale.

Evidence requirements:

- first connection to a valid unchanged endpoint logs cache miss + full verification + cache insert;
- subsequent connections in the same browser session log cache hits and do not repeat full verification;
- a changed server certificate causes a cache miss;
- an existing Firefox override bypasses full verification;
- invalid/untrusted server certificate with no override does not continue automatically.

## Stage 2.3 — enforce server trust before client identity

Rework the mTLS callback/state machine so `msspi_set_mycert()` and any CryptoPro private-key operation are impossible until server trust is established by:

- matching Firefox temporary/permanent override; or
- positive session-cache hit; or
- successful current full verification.

A server that has not passed one of those gates must not receive the client Certificate or CertificateVerify.

## Stage 2.4 — Firefox certificate-error / override UX

Connect a failed GOST server-verification decision to Firefox's normal certificate-error workflow rather than a GOST-only bypass.

Required behavior:

- failed verification + no existing override -> stop and surface certificate-error flow;
- user may choose the Firefox-supported temporary/session exception or permanent exception where the underlying error is overridable;
- retry/reconnect sees `HasMatchingOverride == true` for the exact host/port/OriginAttributes/certificate and skips full verification;
- replacing the server certificate invalidates the match and requires a new decision.

No production `R3DFOX_GOST_IGNORE_SERVER_CERT`-style global bypass is part of the final design.

## Stage 2.5 — issuer-aware client-certificate filtering and Firefox UX

Use the real Stage 2.1 issuer table and Chromium-Gost experience to design final candidate filtering.

Work items:

1. Compare the known-good client certificate chain with the actual server-provided acceptable issuer names.
2. Decide the matching rule using DER/X.500 identity rather than display-string heuristics wherever possible.
3. Determine whether matching any issuer in the client chain is the appropriate rule for the Treasury endpoint and broader GOST use.
4. Feed the acceptable-CA constraints into Firefox-facing client-certificate selection.
5. Replace the Stage 1 explicit `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT` mechanism with an appropriate Firefox certificate picker/selection flow.
6. Cover negative client-auth cases: no acceptable certificate, user cancellation, wrong certificate, missing private key, CryptoPro PIN/private-key failure, and server rejection.

Chromium-Gost is a reference implementation, not an authority over Firefox architecture. Its useful retained patterns are:

- server certificates are installed/verified before client-certificate selection;
- `msspi_get_issuerlist()` is retrieved with the two-pass API and passed into browser client-certificate machinery;
- issuer constraints are used to filter candidate client certificate chains.

## Final Stage 2 regression closure

After all applicable Stage 2 items are implemented:

- rerun the real Treasury GOST mTLS scenario;
- bind runtime evidence to exact Actions run/job and exact source SHA;
- prove server verification/override semantics;
- prove session-cache behavior;
- prove issuer-aware client-cert selection;
- prove client Certificate/CertificateVerify is never disclosed before server trust;
- prove authenticated application traffic still works;
- preserve only sanitized evidence in the active `TEST_LOG.md`.
