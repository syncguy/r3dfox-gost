# r3dfox GOST TLS — Done / Closed Work

Last updated: 2026-08-27

This file is the compact registry of project milestones, blockers, and research conclusions that are formally closed. Detailed run history and failures remain in `TEST_LOG.md` and dated `TEST_LOG_*.md` volumes; current synthesis is in `PROJECT_STATE.md`; open work is in `TODO.md`.

## GOST TLS runtime

### Phase 1 GOST HTTPS transport baseline — COMPLETE

Established for the tested Treasury environment:

- Firefox/Necko HTTP proxy CONNECT lifecycle works with the tested ASUGATE environment;
- allowlisted GOST sessions complete TLS 1.2 with `fzs.roskazna.ru` and suite `0xFF85`;
- protected HTTP application traffic works over the MSSPI-backed GOST transport;
- Treasury pages render and tested interactive workflows operate normally.

Detailed transport evidence remains in the test logs and `PROJECT_STATE.md`.

### Stage 1 Treasury client-certificate mTLS — COMPLETE

Exact Stage 1 source `f5d04896e17f91f58b6a137af823360f4718eb29`.

Authoritative main build/runtime evidence: run `32751967162`, job `97510763210`. A locally designated client certificate can be loaded by MSSPI/CryptoPro and completes real Treasury GOST TLS 1.2 / `0xFF85` mutual TLS plus authenticated protected application traffic. The concrete certificate identifier remains private.

Stage 1 used an explicit local selector as a diagnostic mechanism; it did not close Stage 2 browser-facing selection, negative-path, issuer-policy, or final server-trust work.

### Stage 2.1 trust observability and verifier diagnosis — COMPLETE

Diagnostic source `c62022a5530a61124b756648293113187b8e5b8b`; main run `32810337957`, job `97688347771`; thunk run `32810337879`, job `97688347489`; short SSL run `32810337880`, job `97688347363`.

Closed diagnosis:

- acceptable-issuer collection/deduplication works;
- active SSPI/CryptoPro returns `0x80090302` for `SECPKG_ATTR_REMOTE_CERT_CHAIN`;
- missing MSSPI `peercert` explains the then-observed internal verification failure;
- next implementation path is remote leaf context plus Windows chain construction.

Final fail-closed server verification remains open separately.

### Stage 2 F1 close/shutdown client-auth lifecycle — COMPLETE

Exact fixing source/runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, job `98408139479`;
- artifact `9636591432`.

T2R proves unanswered-picker teardown no longer creates a replacement/orphan decision during `msspi_shutdown()`. Across three timeout cycles, active waiters/decisions are removed, shutdown-time callback re-entry is rejected because the handle is closing, abandoned UI callbacks are stale-safe, and retries receive fresh pickers without browser restart. The capture contains zero automatic `selected=0`, `0x80090326`, `0x0000054f`, or `MSSPI_X509_LOOKUP`.

### Stage 2 F2 positive default-`Once` fanout/scope — COMPLETE

Exact source/runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, job `98408139479`;
- artifact `9636591432`.

T1R proves one positive Firefox `Once` choice feeds the complete Treasury login across compatible sequential connection waves without additional UI: one picker, one lease store, seven lease reuses, eight successful `lk-fzs.roskazna.ru` TLS 1.2 / `0xFF85` mTLS handshakes, and successful protected personal-cabinet use.

T1R-B proves the scope boundary in the same browser process/context. Generation 1 is last reused at `09:07:13.004 UTC` and nominally expires at `09:07:18.004`; a real independent client-auth request at `09:09:44.169` creates fresh `decision=2` and a new Firefox picker rather than reusing generation 1. The new positive choice creates generation 2 and mTLS succeeds again.

T1R-B capture identity:

- `T1R-B-current.zip` SHA-256 `c2d018b8637467b4c1368bfa66399dd042d73b88c39c6de7bf07368c7524ea65`;
- inner log SHA-256 `c30c9f61e008d8bdb321570373c1c5cf6f3bc9eaa9e980564d463d03e307686e`.

Therefore default `Once` has the intended attempt-local positive fanout semantics for the tested Treasury flow: compatible sockets inside the idle window reuse the positive choice, while an independent post-expiry attempt asks again.

### Stage 2 F3 generic GOST mTLS host scope — COMPLETE

Exact source/runtime browser:

- source `ef1a7fdd442a0dd06946dbe4c904e1bf435634ea`;
- main run `33039013849`, job `98408139479`;
- artifact `9636591432`.

Passing GIS GMP runtime capture:

- `gis-g1-g2-g3.zip` SHA-256 `8bb1fd3cfb6773739f0c9b05fd31555eef4180d65ce0518d54a63c85691558ce`;
- inner `gis-g1.moz_log` SHA-256 `451ed230a972b19ec35c1edc8952d1b234366ac5775c7252e8e67a92a289f1b1`.

GIS-G1 proves the generic coordinated callback reaches the real `portalgisgmp.cert.roskazna.ru` `CertificateRequest`: current acceptable-CA count is `36`, candidate count is `1`, and one Firefox picker is produced.

GIS-G2 proves real GIS GMP GOST mTLS/application success: the selected certificate creates one positive `Once` lease, four follow-on requests reuse it, and five certificate-host TLS 1.2 / `0xFF85` handshakes complete with `client_cert_loaded=1`, state `0x00000000`, and positive current verification status. The user confirms the certificate-login/application flow succeeds.

GIS-G3 proves generic callback registration does not create spurious UI: `pay.gov.ru` and `portalgisgmp.login.roskazna.ru` register the capability but issue zero client-certificate requests and complete with `client_cert_loaded=0`; all client-auth requests/picker activity belong only to the certificate endpoint.

The old Treasury-host-specific empty-client-Certificate / `0x80090326` GIS failure is therefore closed.

### GIS-G4 cross-host remembered-decision isolation — COMPLETE

Exact source/runtime browser is the same `ef1a7...` / run `33039013849` / job `98408139479` / artifact `9636591432`.

Capture:

- `session-current.zip` SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`;
- inner `session-current.moz_log` SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`.

A positive Treasury `Session` decision is established first and reused for later matching `lk-fzs.roskazna.ru` handshakes. In the same running browser process, navigation to `portalgisgmp.cert.roskazna.ru` creates a fresh client-auth request with a different browser context (`browser_id=17`), a fresh coordinated decision, and a fresh Firefox picker. The Treasury Session certificate is not silently applied to the GIS GMP host. After an explicit GIS `Once` choice, GIS mTLS succeeds normally.

This closes the planned cross-host isolation regression.

### Stage 2 explicit positive `Session` browser-process lifetime — COMPLETE

Exact source/runtime browser remains `ef1a7...` / run `33039013849` / job `98408139479` / artifact `9636591432`.

In-process evidence:

- `session-current.zip` SHA-256 `6eccbf7d49e69a92d9634507b111759f096c4dee00a0313ec3d7c20017f5dec1`;
- inner log SHA-256 `b3b2c8751e1f0cf66cfda73a1c068f609efb1692ade910b0d4ffcb42ff4905f8`;
- explicit Treasury `Session` (`remember=2`) is reused for ten later matching client-auth requests without another Treasury picker;
- all eleven Treasury mTLS handshakes succeed;
- user-visible behavior remains usable across tabs/windows in the same running browser process.

Restart-boundary evidence:

- `session-current2.zip` SHA-256 `e32b71ca51d151e553ab82c321fd8f829270e09b6a8390f7fb3ea828af3a29e7`;
- inner log SHA-256 `5b156cf0765c9aad3ceffeac6d1a845cea381f219ea168d59b318201b9f419b5`;
- prior Session process is `Parent 6200`; restarted browser is `Parent 5112`;
- first Treasury client-auth in the restarted process creates a fresh decision and fresh picker rather than consuming old Session state;
- after a new explicit Session choice, five later matching requests are again served from `scope=session`, and six Treasury mTLS handshakes succeed.

Therefore the tested positive Session decision has the intended process lifetime: shared across matching handshakes/windows/tabs while the browser is running, isolated from another GOST mTLS host, and cleared when the browser process exits. The planned next UX change is only to make this already-proven `Session` behavior the picker default. True persistent `Permanent` semantics remain open separately.

## Bundled government-system extensions

### CryptoPro standalone updater/fallback/package mechanism — COMPLETE

Source `2ad7025ca300613d39a227b9e7582a341260d648`, run `32815118778`, job `97701728235`, evidence artifact `9551126137`.

Proven: committed fallback validation, network-failure fallback, invalid-fallback hard failure, downloaded-candidate validation, malformed/wrong-ID rejection, live CryptoPro endpoint exercise, synthetic staging and final synthetic package verification.

### CryptoPro real Mozilla portable-packaging integration — COMPLETE

Source `17b8d9762b489ed8fc9c3a8e1595802065dd7188`, run `32847887872`, job `97801745453`, evidence artifact `9569388324`, packaged-browser artifact `9569387758`.

Proven in one exact run: updater/selection, full Firefox build, real `dist/bin` extension verification, `mach package`, and final portable-archive exact extension path/hash/manifest-ID verification.

### CryptoPro clean-profile discovery and basic functional runtime — COMPLETE

Using packaged-browser artifact `9569387758`, a fresh profile automatically discovers/enables CryptoPro CAdES extension version `1.2.14`, and normal CryptoPro signature-verification functionality works. Version-to-version automatic update remains open separately.

### Three-extension government bundle real portable packaging — COMPLETE

Source `b3d097de20b7a5711f161199a727bcfe9468bcc8`; short validation run `32976571124`, job `98202642893`; full packaging run `32976571122`, job `98202641607`; packaged-browser artifact `9614275050`; evidence artifact `9614275551`.

The portable package contains CryptoPro CAdES `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, Gosplugin `1.3.43.0`, and Russian-first `intl.accept_languages` packaging.

### Three-extension clean-profile discovery/enabled state — COMPLETE

On the exact packaged browser from source `b3d097de...`, run `32976571122`, artifact `9614275050`, a fresh dedicated profile shows all three bundled project extensions enabled. Native functionality of IFCPlugin/Gosplugin and update behavior remain open separately.