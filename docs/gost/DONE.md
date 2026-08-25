# r3dfox GOST TLS — Done / Closed Work

Last updated: 2026-08-25

This file is the compact registry of project milestones, blockers, and research conclusions that are formally closed.

It is **not** an experiment log. Exact run IDs, job IDs, commit SHAs, observations, failed attempts, and superseded hypotheses remain in the current [`TEST_LOG.md`](./TEST_LOG.md) and dated `TEST_LOG_*.md` historical volumes. [`PROJECT_STATE.md`](./PROJECT_STATE.md) remains the current technical synthesis, and [`TODO.md`](./TODO.md) contains only open, deferred, or future work.

Keep entries here concise. Do not copy long test histories into this file. A closed item should state what is proven, identify the key authoritative evidence when useful, and make clear which adjacent work remains open.

If new evidence invalidates a closed conclusion, record the new experiment in `TEST_LOG.md`, add the reopened work to `TODO.md`, and update the relevant entry here rather than silently deleting the old conclusion.

## GOST TLS runtime

### Phase 1 GOST HTTPS transport baseline — COMPLETE

The following baseline behavior is established for the tested Treasury environment and must not be reopened without new evidence:

- the Firefox/Necko HTTP proxy CONNECT lifecycle works with the tested ASUGATE environment;
- allowlisted GOST sessions complete TLS 1.2 with `fzs.roskazna.ru` and negotiate suite `0xFF85`;
- protected HTTP application traffic works over the MSSPI-backed GOST transport;
- Treasury pages render with JavaScript and images;
- interactive forms, information requests, and response-list workflows have worked in the tested browser artifacts;
- the same GOST TLS source behavior has been exercised through both current full-build strategies.

Detailed transport/proxy/runtime evidence is preserved in `PROJECT_STATE.md` and the historical/current test logs.

### Stage 1 Treasury client-certificate mTLS — COMPLETE

Exact Stage 1 source SHA:

`f5d04896e17f91f58b6a137af823360f4718eb29`

Authoritative full-build/runtime evidence:

- main build: run `32751967162`, job `97510763210`;
- experimental thunk-rs full build: run `32751967189`, job `97510762742`.

Confirmed:

- `lk-fzs.roskazna.ru` reaches the GOST path when explicitly allowlisted and sends a client-certificate request;
- the Stage 1 wrapper callback selects one explicitly designated local certificate from `CurrentUser\MY` without publishing its identifier;
- the selected certificate has an available private-key binding;
- MSSPI loads the client certificate and completes GOST TLS 1.2 / `0xFF85` mutual TLS;
- the previous empty-client-certificate / `0x80090326` failure is closed for the tested Stage 1 path;
- authenticated Treasury application traffic succeeds in both current full-build strategies.

Stage 1 deliberately used a local explicit selector as a controlled diagnostic mechanism. Its success does **not** close Stage 2 server-verification, issuer-policy, Firefox-facing certificate-selection UX, negative-path, or privacy-hardening work; those remain in `TODO.md`.

### Stage 2.1 trust observability and verifier diagnosis — COMPLETE

Exact diagnostic source SHA:

`c62022a5530a61124b756648293113187b8e5b8b`

Build evidence:

- main full build: run `32810337957`, job `97688347771`, success;
- experimental thunk-rs full build: run `32810337879`, job `97688347489`, success;
- short SSL compile gate: run `32810337880`, job `97688347363`, success.

Runtime diagnosis from the main-build artifact established that:

- the acceptable-issuer list is returned and the detailed dump is correctly deduplicated once per browser session;
- the active SSPI/CryptoPro provider returns `0x80090302` (`SEC_E_UNSUPPORTED_FUNCTION`) for `SECPKG_ATTR_REMOTE_CERT_CHAIN`;
- the resulting lack of MSSPI `peercert` is why `msspi_get_verify_status()` reaches its internal-failure form in the tested path;
- this is a peer-certificate acquisition blocker, not evidence that Treasury's real server certificate failed chain or hostname policy;
- the next implementation path is `SECPKG_ATTR_REMOTE_CERT_CONTEXT` for the leaf certificate followed by `CertGetCertificateChain`.

The diagnosis is closed; implementing and proving fail-closed server verification remains open in `TODO.md`.

## Bundled government-system extensions

### CryptoPro standalone updater/fallback/package mechanism — COMPLETE

Formal passing evidence:

- source SHA: `2ad7025ca300613d39a227b9e7582a341260d648`;
- run `32815118778`;
- job `97701728235`;
- evidence artifact `9551126137` (`cryptopro-extension-smoke`);
- result: success.

Confirmed:

- the committed fallback XPI validates before network update attempts;
- network failure falls back to the committed XPI;
- an invalid committed fallback is a hard error;
- valid downloaded candidates are accepted only after structural validation;
- malformed or wrong-extension-ID candidates are rejected in favor of the valid fallback;
- the official CryptoPro endpoint was successfully exercised;
- synthetic `distribution/extensions` staging and final synthetic ZIP verification preserve the selected XPI and its identity.

This closes the standalone updater/fallback contract only. Real Mozilla packaging integration, final portable-archive inclusion, transfer into the two main browser workflows, and clean-profile Firefox runtime discovery/update behavior remain separate open work in `TODO.md` and [`EXTENSIONS.md`](./EXTENSIONS.md).
