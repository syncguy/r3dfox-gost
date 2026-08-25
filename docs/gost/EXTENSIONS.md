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

The initial known-good fallback supplied on 2026-08-25 is:

- version: `1.2.14`;
- extension ID: `ru.cryptopro.nmcades@cryptopro.ru`;
- size: `76880` bytes;
- SHA-256: `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`;
- ZIP integrity: valid;
- Mozilla signature structure: `META-INF/manifest.mf`, `META-INF/mozilla.sf`, `META-INF/mozilla.rsa` present;
- COSE structure: `META-INF/cose.manifest`, `META-INF/cose.sig` present.

Repository location after the one-time bootstrap step:

`r3dfox/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`

The first smoke workflow may bootstrap this exact binary from the official endpoint only if its SHA-256 matches the user-supplied baseline byte-for-byte. That bootstrap is a one-time repository setup mechanism, not the intended normal update behavior.

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

### Current smoke scope

Workflow:

`.github/workflows/cryptopro-extension-smoke.yml`

Updater:

`build/update-cryptopro-extension.py`

The smoke runs on `agent/gost-tls-poc` when the updater, smoke workflow, or vendored fallback changes. It deliberately does not compile Firefox.

The initial smoke proves:

- fallback validation and hard failure for an invalid fallback;
- deterministic network-failure fallback;
- acceptance of a structurally valid downloaded candidate;
- rejection of malformed downloads;
- rejection of a candidate with the wrong extension ID;
- a live best-effort check of the official CryptoPro endpoint;
- staging into a minimal `distribution/extensions` tree;
- ZIP packaging and re-validation of the packaged XPI by ID and SHA-256.

### Integration boundary

During initial smoke development:

- do not modify `.github/workflows/gost-poc-build.yml`;
- do not modify `.github/workflows/gost-poc-build-thunk.yml`;
- do not yet connect the XPI to the real Firefox `r3dfox/moz.build` packaging graph.

After the standalone updater/fallback/package smoke is stable, add a separate Mozilla build-system integration proof. Only after that proof should the already-tested preparation and package gates be transferred into both full browser workflows.
