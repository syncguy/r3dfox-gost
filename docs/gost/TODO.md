# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog for work that is desired but not yet complete. `PROJECT_STATE.md` remains the authoritative current-state synthesis; `TEST_LOG.md` remains the evidence trail.

## GOST TLS runtime — next

### 1. Make server-certificate verification fail-closed

Current successful GOST sessions still log:

```text
DriveHandshake verify host=fzs.roskazna.ru ok=0 status=0x00000000
```

Pinned MSSPI runs client Schannel with manual credential validation. `msspi_get_verify_status()` verifies the peer certificate; in client mode that means the server certificate, including chain/policy, server-auth usage, hostname, and (by default) revocation handling.

Next steps:

- log `msspi_last_error()` immediately when `msspi_get_verify_status()` returns 0;
- if needed, log peer-certificate and peer-chain retrieval status;
- determine why verification returns its internal-error path on otherwise successful Treasury sessions;
- make the Firefox wrapper fail closed when `verifyOk == 0` as well as when the returned verification status is nonzero;
- prove a valid `fzs.roskazna.ru` certificate succeeds;
- prove a wrong hostname / invalid chain is rejected.

### 2. Add client-certificate / mutual TLS (mTLS) support

This was deliberately outside Phase 1, but it is now an explicit next functional milestone.

Pinned MSSPI already exposes the needed handshake mechanism:

- Schannel can return `SEC_I_INCOMPLETE_CREDENTIALS` when the server requests a client certificate;
- MSSPI then enters `MSSPI_X509_LOOKUP`;
- `msspi_set_cert_cb()` installs a dynamic certificate-selection callback;
- inside that callback the application can verify the server first, read the server issuer list with `msspi_get_issuerlist()`, choose a client certificate, and load it with `msspi_set_mycert()` / related APIs;
- the selected certificate can come from the Windows certificate stores and retain its CryptoPro private-key binding.

Current Firefox GOST wrapper does not install an MSSPI certificate callback and does not select a client certificate.

First baseline attempt on 2026-08-24 exposed an important routing prerequisite before the actual mTLS handshake could be observed. Treasury login redirects from `fzs.roskazna.ru` to `https://lk-fzs.roskazna.ru/certificate-list`. The test process had `R3DFOX_GOST_HOSTS=fzs.roskazna.ru`, so `lk-fzs.roskazna.ru` was not routed through the GOST provider and ordinary NSS failed with `SSL_ERROR_NO_CYPHER_OVERLAP`. The accompanying `GostTLS` log contains only `fzs.roskazna.ru`; no MSSPI connection to `lk-fzs.roskazna.ru` occurred. Therefore that error is not an MSSPI/mTLS failure and does not yet contain the login server's `CertificateRequest`.

Next baseline capture requires no rebuild. Re-run the same proven alternative artifact with both exact hosts in the allowlist:

```text
R3DFOX_GOST_HOSTS=fzs.roskazna.ru,lk-fzs.roskazna.ru
```

The allowlist implementation supports comma/semicolon-separated exact hosts and `*.` suffix tokens, but use the two exact Treasury hosts for this experiment rather than broadening the scope unnecessarily.

Planned evidence/implementation sequence:

1. Capture a runtime log from run `32710363484`, job `97388836234`, source SHA `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`, with both `fzs.roskazna.ru` and `lk-fzs.roskazna.ru` allowlisted. Confirm the login host reaches `ProxyStartSSL()` and MSSPI, then decode the server `CertificateRequest`, `SEC_I_INCOMPLETE_CREDENTIALS`, `MSSPI_X509_LOOKUP`, issuer list, and current failure/stall behavior before changing code.
2. Add diagnostic handling for `MSSPI_X509_LOOKUP` without changing unrelated transport logic.
3. Integrate `msspi_set_cert_cb()` and client-certificate loading/selection.
4. Ensure the server certificate is verified successfully before allowing client-certificate disclosure/use.
5. First prove one explicitly selected known-good CryptoPro client certificate can complete mTLS to the Treasury site.
6. Then design Firefox-facing certificate selection UX instead of permanently relying on an environment-variable or hard-coded certificate selector.
7. Prove negative cases: no suitable certificate, user cancellation, wrong certificate, private-key/PIN failure, and server rejection.

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
