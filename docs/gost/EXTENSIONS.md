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

The one-time bootstrap is complete. Run `32814928877` validated the downloaded official XPI against the exact user-supplied SHA-256 and commit `e2102e1c9771c0115060303206144ab343de9f0c` added that exact binary to the default branch.

### Updater contract

`build/update-cryptopro-extension.py` implements the proved selection contract:

1. validate the committed fallback before any normal update network operation;
2. download an official candidate only to a temporary file;
3. validate ZIP integrity, `manifest.json`, exact extension ID, version, and signature structure;
4. use the downloaded candidate only after complete validation;
5. on network, HTTP, ZIP, manifest, signature-structure, or extension-ID failure, keep using the valid committed fallback;
6. treat an invalid committed fallback as a hard error;
7. never overwrite the committed fallback as a repository side effect of CI;
8. verify the selected XPI again after staging and final archive packaging.

The updater validates signature-file and COSE structure only. It does not claim independent cryptographic verification of Mozilla's extension signature; Firefox remains the authority for signature enforcement when the XPI is actually installed.

### Standalone updater/fallback smoke — PROVEN

Historical workflow file:

`.github/workflows/cryptopro-extension-smoke.yml`

Formal passing evidence:

- branch: `agent/gost-tls-poc`;
- source-under-test SHA: `2ad7025ca300613d39a227b9e7582a341260d648`;
- Actions run: `32815118778`;
- job: `97701728235`;
- evidence artifact: `9551126137` (`cryptopro-extension-smoke`);
- result: success.

That run proved committed-fallback validation, network-failure fallback, invalid-fallback hard failure, valid-candidate acceptance, malformed-candidate fallback, wrong-ID fallback, live official download, synthetic `distribution/extensions` staging, and final synthetic ZIP verification. During the live check the official endpoint returned version `1.2.14`, size `76880`, and the same SHA-256 as the committed fallback.

The standalone workflow was retired after this proof by commit `628780ec29c1a72d572b33f51c543e88c2d884d5`; its evidence remains authoritative for the updater/fallback behavior.

### Real Mozilla packaging integration — PROVEN

`r3dfox/moz.build` declares:

```python
FINAL_TARGET_FILES.distribution.extensions += [
  "extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi",
]
```

Integration commit: `8e1cd63ccc1bb45400ea675e7e2920595b1ae379`.

Dedicated workflow:

`.github/workflows/cryptopro-mozilla-packaging-smoke.yml`

Workflow name:

`CryptoPro Mozilla packaging smoke`

The workflow is based on the build-critical path of `.github/workflows/gost-poc-build.yml`: it uses the same Windows runner model, MozillaBuild setup, pagefile requirements, pinned MSSPI source, release mozconfig, pinned Rust build-std path, configure/export gates, full `mach build`, and `mach package`. The unrelated Win7 PE import audit is intentionally not part of this extension-packaging proof.

The workflow runs on `agent/gost-tls-poc` when any of these packaging inputs changes:

- `r3dfox/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi`;
- `r3dfox/moz.build`;
- `browser/installer/package-manifest.in`;
- `.github/workflows/cryptopro-mozilla-packaging-smoke.yml`.

It does **not** currently trigger on `build/update-cryptopro-extension.py`, `security/manager/ssl/nsGostSSLIOLayer.cpp`, or either full-build workflow YAML.

The integration-specific stages are:

1. run the proved updater against the official CryptoPro endpoint with the committed XPI as fallback;
2. copy the selected XPI over the source-tree fallback path only inside the ephemeral Actions checkout, so Mozilla's declared `FINAL_TARGET_FILES` path receives the selected candidate without modifying the repository baseline;
3. perform the real full Firefox build;
4. require the selected XPI at `obj-gost-win64/dist/bin/distribution/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi` and require its SHA-256 and manifest ID to match the selected candidate;
5. run the real `mach package`;
6. extract the produced portable `.7z` or `.zip`, require exactly one matching XPI under `distribution/extensions`, and require its SHA-256 to match the selected candidate;
7. upload both the packaged browser and dedicated CryptoPro packaging evidence.

First integration run:

- Actions run: `32817910715`;
- job: `97709832302`;
- source-under-test SHA: `686b7a1d11ff2ad2d4a7cc9907361c8a6f197560`;
- CI result: failure at `GATE - Verify CryptoPro XPI in final portable archive`.

That run proved the real Mozilla `FINAL_TARGET_FILES` path through `dist/bin`: the selected XPI was present at `obj-gost-win64/dist/bin/distribution/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi` and passed the workflow hash/manifest-ID checks. The full Firefox build and `mach package` also succeeded. The extracted portable archive contained no matching XPI because `browser/installer/package-manifest.in` is a separate dist/bin-to-package staging allowlist and did not include the CryptoPro extension path for this r3dfox build configuration.

The corrective packaging line at commit `95eb8c292ab430effd257b9c3f2e92aef27766a4` adds the exact CryptoPro XPI path to `browser/installer/package-manifest.in`.

Formal passing revalidation:

- Actions run: `32847887872`;
- job: `97801745453`;
- source-under-test SHA: `17b8d9762b489ed8fc9c3a8e1595802065dd7188`;
- CI result: success;
- evidence artifact: `9569388324` (`cryptopro-mozilla-packaging-evidence`);
- packaged-browser artifact: `9569387758` (`r3dfox-cryptopro-mozilla-packaging`).

In this exact run the updater/selection gate, full Firefox build, real `dist/bin` XPI verification, `mach package`, and final portable-archive XPI verification all passed together. The final archive contains exactly the expected extension path under `distribution/extensions`, and the workflow's selected-candidate SHA-256 and manifest-ID checks passed.

Therefore the real Mozilla portable-packaging integration is proven. The final-archive omission diagnosed by run `32817910715` is closed; that failed run remains historical evidence of the missing installer-manifest staging rule.

### Full-build integration boundary

`.github/workflows/gost-poc-build.yml` and `.github/workflows/gost-poc-build-thunk.yml` remain separate from the dedicated extension proof. The GOST TLS and Windows compatibility evidence tied to earlier source SHAs is unaffected by later extension commits.

The next integration step is to transfer only the already-proven updater preparation and final package-verification gates into those two main full-build workflows. A later clean-profile runtime test must separately prove that Firefox discovers/installs the bundled extension and that extension update behavior remains functional.
