# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog for work that is desired but not yet complete.

- [`PROJECT_STATE.md`](./PROJECT_STATE.md) is the authoritative current-state synthesis.
- [`DONE.md`](./DONE.md) is the compact registry of formally closed milestones and conclusions.
- The current [`TEST_LOG.md`](./TEST_LOG.md) is the active evidence trail, with earlier evidence preserved in dated `TEST_LOG_*.md` volumes.

Completed work does not remain here as historical narrative. When a milestone closes, preserve its detailed evidence in the test log, add a concise closure entry to `DONE.md`, and remove the completed task from this backlog.

## GOST TLS runtime — next

### 1. Complete fail-closed server-certificate verification

Stage 2.1 diagnosis is complete and recorded in `DONE.md` / `TEST_LOG.md`.

The current blocker is no longer an unknown `msspi_get_verify_status()` failure: the active SSPI/CryptoPro provider returns `SEC_E_UNSUPPORTED_FUNCTION` for `SECPKG_ATTR_REMOTE_CERT_CHAIN`, leaving MSSPI without `peercert` and forcing verification into its internal-failure form.

Required work:

- switch peer-certificate acquisition to `SECPKG_ATTR_REMOTE_CERT_CONTEXT`;
- build the peer chain with `CertGetCertificateChain` using the acquired leaf certificate;
- feed the repaired peer-certificate/chain state into the existing MSSPI verification path;
- fail closed when `verifyOk == 0` or the verification status is nonzero;
- prove the real Treasury server certificate and hostname succeed;
- prove a wrong hostname and an invalid/untrusted chain are rejected;
- do not introduce a production bypass that converts failed server verification into success.

This is a mandatory Stage 2 security gate before GOST mTLS integration can be treated as closed.

### 2. Complete Firefox-facing client-certificate selection and mTLS security/UX closure

Stage 1 explicit-selector mTLS is formally complete and recorded in `DONE.md`. The explicit local selector remains useful only as a controlled diagnostic/reference path while the Firefox-facing flow is implemented and compared against the known-good behavior.

Current compile checkpoint:

- source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`;
- SSL compile run `32844083351`, job `97789764135`, success;
- this proves only that the current asynchronous picker state/refcount implementation compiles, not that the picker or handshake works at runtime.

Required work:

1. Complete the asynchronous Firefox-facing certificate-selection path without blocking the socket thread.
2. Define and implement the final use of the server-provided acceptable-issuer list for candidate filtering/selection.
3. Keep the known-good explicit selector as a priority diagnostic comparison path only while the Firefox flow is being proved; the final normal UX must not depend on a hard-coded or repository-visible certificate identifier.
4. Define appropriate in-memory/session remembering behavior for a user selection without leaking sensitive certificate metadata.
5. Test negative paths: no suitable certificate, user cancellation, wrong certificate, missing/unavailable private key, CryptoPro PIN/private-key failure, and server rejection.
6. Audit diagnostics and artifacts so no complete certificate fingerprint/thumbprint, serial, identifying subject/issuer DN, provider/container identifier, PIN/password, PFX content, account data, or other sensitive user-derived value is published.
7. Re-run the successful Treasury mTLS scenario after Stage 2 hardening and preserve a sanitized exact-run/exact-SHA regression proof.

Only after the applicable server-verification and client-authentication items are complete may the project treat GOST mTLS integration as closed.

### 3. Broaden proxy/network coverage later

The proven environment is an ordinary HTTP proxy using CONNECT. Keep these as separate later cases rather than changing the working HTTP-proxy path blindly:

- direct connection without proxy;
- HTTPS proxy / nested TLS-to-proxy then GOST TLS-to-origin;
- SOCKS lifecycle;
- proxy authentication/reconnect edge cases beyond the currently exercised ASUGATE path.

## Windows Vista/7 compatibility — next/deferred

Keep this track separate from GOST TLS runtime conclusions.

1. Integrate the already-proven representative `msvcr14x + modern Rust/libstd + narrow YY-Thunks` combination into one full Firefox/xul build while preserving `/MD`.
2. Audit the resulting Firefox PE set for direct `api-ms-win-*`, `ext-ms-*`, `VCRUNTIME140*.dll`, and known Win8+ hard imports.
3. Run that msvcr14x-integrated portable build on real Windows 7 without the current copied API-set/UCRT compatibility bundle.
4. Fix/replay the delay-load import parser and classify relevant post-Win7 delay-loaded APIs by guarded runtime path.
5. Expand Windows 7 runtime coverage beyond basic startup.
6. Run GOST TLS on Windows 7 as a separate exact-run/exact-SHA runtime milestone; do not infer it from loader/startup compatibility.

## Bundled government-system extensions — next

Detailed design and evidence are tracked in [`EXTENSIONS.md`](./EXTENSIONS.md). The standalone updater/fallback contract, real Mozilla portable-packaging proof, and clean-profile discovery/basic functional runtime proof are closed and recorded in `DONE.md`.

### 1. Transfer only proven extension integration into the two main browser workflows

The dedicated Mozilla packaging proof is green at run `32847887872`, job `97801745453`, source SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`.

Add only the already-proven updater preparation and final package-verification gates to:

- `.github/workflows/gost-poc-build.yml`;
- `.github/workflows/gost-poc-build-thunk.yml`.

Do not mix unrelated GOST runtime or Windows compatibility changes into that transfer.

### 2. Prove a real CryptoPro extension version-to-version update

Clean-profile discovery/install and basic functional use are already proven with packaged-browser artifact `9569387758` from run `32847887872` / source SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`.

The exact source defaults are already compatible with automatic updating: `extensions.update.enabled = true`, `extensions.update.autoUpdateDefault = true`, the per-extension UI is `Default`, and the XPI declares CryptoPro's official `ffupdates.json` update manifest. No current `r3dfox/policies.json` rule disables CryptoPro extension updates.

The remaining runtime proof is the actual update transition:

- start from an older valid signed CryptoPro Firefox XPI if one can be obtained safely, or wait until CryptoPro publishes a version newer than `1.2.14`;
- use an otherwise clean profile with the extension update choice left at `Default`;
- confirm Firefox discovers the vendor update without manual XPI installation;
- confirm the extension advances to the newer signed version automatically;
- re-run the normal CryptoPro signature-verification functionality after the update.

Do not change the current installation architecture merely to manufacture an update proof. If an explicit enterprise policy is later desired, test it separately before replacing the standard Firefox update path.

## Upstream r3dfox base tracking — deferred

The project is a fork of `Eclipse-Community/r3dfox`, not a direct Firefox-upstream port. Continue development on the current r3dfox 153 base.

- monitor `Eclipse-Community/r3dfox` for a new maintained baseline;
- do not migrate this project directly to Mozilla Firefox 154 merely because Mozilla has released it;
- when r3dfox itself publishes a 154-or-later baseline, evaluate the migration deliberately: compare GOST integration points, Windows compatibility changes, MSSPI/NSPR/NSS interfaces, build workflows, and regression risk;
- perform any base upgrade only after explicit user decision.
