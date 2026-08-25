# Bundled government-system extensions

This document records the packaging design and experiment state for browser extensions required by Russian government systems. This work is separate from both the GOST TLS runtime/handshake track and the Windows Vista/7 binary-compatibility track.

## CryptoPro CAdES Firefox extension

Extension ID:

`ru.cryptopro.nmcades@cryptopro.ru`

Official latest-XPI endpoint:

`https://www.cryptopro.ru/sites/default/files/products/cades/extensions/firefox_cryptopro_extension_latest.xpi`

Official extension update manifest declared by the current XPI:

`https://www.cryptopro.ru/sites/default/files/products/cades/extensions/ffupdates.json`

### Committed fallback baseline

The known-good fallback supplied and vendored on 2026-08-25 is:

- version: `1.2.14`;
- extension ID: `ru.cryptopro.nmcades@cryptopro.ru`;
- size: `76880` bytes;
- SHA-256: `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`;
- ZIP integrity: valid;
- Mozilla signature structure: `META-INF/manifest.mf`, `META-INF/mozilla.sf`, `META-INF/mozilla.rsa` present;
- COSE structure: `META-INF/cose.manifest`, `META-INF/cose.sig` present.

Repository location:

`r3dfox/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`

The one-time bootstrap is complete. Run `32814928877` validated the downloaded official XPI against the exact user-supplied SHA-256 and commit `e2102e1c9771c0115060303206144ab343de9f0c` added that exact binary to the default branch. The permanent smoke is read-only and does not commit or overwrite this fallback.

### Intended production contract

Before either full Firefox build is changed, the update/fallback logic is proved in the dedicated `CryptoPro extension packaging smoke` workflow.

The updater contract is:

1. validate the committed fallback before any normal update network operation;
2. download an official candidate only to a temporary file;
3. validate ZIP integrity, `manifest.json`, exact extension ID, version, and signature structure;
4. use the downloaded candidate only after complete validation;
5. on network, HTTP, ZIP, manifest, signature-structure, or extension-ID failure, keep using the valid committed fallback;
6. treat an invalid committed fallback as a hard error;
7. never overwrite the committed fallback as a side effect of normal CI update checks;
8. stage the selected XPI as `distribution/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`;
9. verify the selected XPI again after staging and after final archive packaging.

The live CryptoPro endpoint is an integration check, not the only proof of fallback behavior. Deterministic local fixtures exercise success, network-failure, malformed-XPI, and wrong-extension-ID paths.

The smoke validates signature-file and COSE structure only. It does not claim independent cryptographic verification of the Mozilla extension signature; Firefox remains the authority for signature enforcement when the extension is actually installed.

### Standalone smoke — PROVEN

Workflow:

`.github/workflows/cryptopro-extension-smoke.yml`

Updater:

`build/update-cryptopro-extension.py`

Formal passing evidence:

- branch: `agent/gost-tls-poc`;
- source-under-test SHA: `2ad7025ca300613d39a227b9e7582a341260d648`;
- Actions run: `32815118778`;
- job: `97701728235`;
- evidence artifact: `9551126137` (`cryptopro-extension-smoke`);
- result: success.

All standalone gates passed:

- exact committed-fallback validation;
- forced network-failure fallback;
- invalid committed fallback hard failure with no output XPI;
- acceptance of a deterministic valid downloaded candidate;
- malformed-XPI rejection and fallback;
- wrong-extension-ID rejection and fallback;
- live download from the official CryptoPro endpoint;
- staging into a minimal `distribution/extensions` tree;
- final ZIP packaging and re-validation by path, ID, version, and SHA-256.

During the passing run the live official endpoint returned version `1.2.14`, size `76880`, and SHA-256 `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`, byte-identical to the committed fallback.

The workflow uses sparse checkout and `contents: read`; it deliberately does not compile Firefox and cannot modify repository contents.

### Integration boundary and next proof

The standalone updater/fallback/staging/package contract is now proven, but Mozilla build-system integration is not yet proven.

Current constraints remain:

- `.github/workflows/gost-poc-build.yml` is unchanged by this experiment;
- `.github/workflows/gost-poc-build-thunk.yml` is unchanged by this experiment;
- `r3dfox/moz.build` has not yet been changed to put the XPI into the real Firefox packaging graph.

The next extension-track experiment is a separate minimal Mozilla build-system integration proof for `FINAL_TARGET_FILES.distribution.extensions`. It should demonstrate that the already-selected XPI reaches the real Firefox `dist/bin/distribution/extensions` / package layout without first modifying either full browser workflow.

Only after that proof should the already-tested updater invocation and package gates be transferred into both full browser builds.
