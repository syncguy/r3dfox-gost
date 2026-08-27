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

`r3dfox/moz.build` originally declared only CryptoPro:

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

Therefore the original CryptoPro real Mozilla portable-packaging integration is proven. The final-archive omission diagnosed by run `32817910715` is closed; that failed run remains historical evidence of the missing installer-manifest staging rule.

### Clean-profile Firefox runtime discovery and basic functionality — PROVEN

The packaged browser from the same exact proof has crossed the browser-runtime boundary:

- source-under-test SHA: `17b8d9762b489ed8fc9c3a8e1595802065dd7188`;
- Actions run: `32847887872`;
- job: `97801745453`;
- packaged-browser artifact: `9569387758` (`r3dfox-cryptopro-mozilla-packaging`).

The user started the portable browser with a new profile. Firefox automatically discovered the bundled `ru.cryptopro.nmcades@cryptopro.ru` extension without any manual XPI installation. Add-ons Manager showed `CryptoPro Extension for CAdES Browser Plug-in`, version `1.2.14`, enabled. The user then exercised the normal CryptoPro signature-verification functionality and confirmed it works.

This closes the clean-profile discovery/install and basic functional-use questions for the tested CryptoPro-only packaging artifact.

### Automatic update behavior

The same runtime test shows the extension's per-add-on setting as `Allow automatic updates: Default`.

For the exact source-under-test:

- `browser/app/profile/firefox.js` sets `extensions.update.autoUpdateDefault` to `true`;
- `extensions.update.enabled` is `true`;
- the normal extension update interval is `86400` seconds;
- the XPI declares CryptoPro's official `ffupdates.json` update manifest;
- `r3dfox/policies.json` does not contain a CryptoPro-specific `ExtensionSettings` override and does not disable extension updates.

Therefore an untouched clean profile with the per-extension selector left at `Default` is expected to check and apply CryptoPro extension updates automatically through the vendor manifest. This is standard Firefox add-on update behavior, not a custom r3dfox updater running at browser runtime.

A real version-to-version transition is **not yet runtime-proven**. The remaining proof is to start from an older valid signed CryptoPro XPI if available, or wait for a vendor version newer than `1.2.14`, and confirm that Firefox updates it automatically and that signature-verification functionality still works afterward.

Do not add enterprise-policy installation or forced-update behavior merely to remove UI ambiguity unless the project explicitly chooses managed-extension semantics. The current standard Firefox defaults already enable updates; any stronger policy should be treated as a separate behavioral change and tested independently.

## Legacy Gosuslugi / IFCPlugin Firefox extension

Repository baseline:

- repository path: `r3dfox/extensions/pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru.xpi`;
- extension ID: `pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru`;
- version: `1.2.8`;
- size: `20232` bytes;
- SHA-256: `72916b4ed2adefd91049fbd93aff5e028c423c971c2e0012603a2dae343bdc80`;
- manifest version: 2;
- Mozilla signature and COSE structures: present;
- permission: `nativeMessaging`;
- native host reference: `ru.rtlabs.ifcplugin`;
- manifest `update_url`: absent.

The exact user-supplied XPI is the authoritative committed baseline. GitHub-hosted Windows runners could not reliably reach the known `ds-plugin.gosuslugi.ru` endpoints, so live vendor reachability is intentionally not a hard prerequisite when the committed fallback validates exactly.

Formal short validation proof:

- source SHA `39f59bb954eb0fe047ef2a1b506ccddc3116f988`;
- run `32972186494`;
- job `98188295189`;
- evidence artifact `9608046113` (`bundled-extensions-smoke`);
- result: success.

The preceding bootstrap/network/binary-transport failures are documented in `TEST_LOG.md`; they are harness/delivery evidence and are not extension failures.

The XPI alone is not sufficient for functional use: the system-side IFCPlugin/native host must also be installed. Packaging proof must therefore remain separate from native-host runtime proof.

## Gosplugin Firefox extension

Current signed AMO baseline:

- repository path: `r3dfox/extensions/gosuslugi@plugin.xpi`;
- extension ID: `gosuslugi@plugin`;
- version: `1.3.43.0`;
- size: `1272459` bytes;
- SHA-256: `f9a53a2fb4f33041676bf97d9ae9b061b67dde9ddbdc78221a06454381cd6cbc`;
- manifest version: 3;
- Mozilla signature and COSE structures: present;
- permission: `nativeMessaging`;
- manifest `update_url`: absent.

The initial bootstrap run `32974033522`, job `98194284032`, source SHA `339eb661782ab8b4cb5bcd1a02d930c37a862835` successfully downloaded and validated the exact AMO XPI but failed later on a workflow variable/name handoff. That was a harness failure after XPI validation. The corrected bootstrap run `32974162330`, job `98194711292`, source SHA `9984e41623d675684eb1ad78a35b7830d1e024c0`, completed successfully and produced bot commit `b98d04e204e6bd95d4cd532e1640642e7828b277`, which vendors the validated XPI.

As with the legacy extension, functional runtime requires its separate local/native Gosplugin component. Bundling the XPI proves browser-side availability only.

## Shared three-extension bundle

Integration source SHA:

`b3d097de20b7a5711f161199a727bcfe9468bcc8`

At this source, `r3dfox/moz.build` stages all three extension files through `FINAL_TARGET_FILES.distribution.extensions`, and `browser/installer/package-manifest.in` explicitly admits all three paths into the packaged browser. This deliberately applies the packaging lesson from the earlier CryptoPro-only omission: `dist/bin` staging and installer/package staging are separate boundaries and both are required.

The source also adds `r3dfox/r3dfox-bundle.js` to packaged default preferences with:

```js
pref("intl.accept_languages", "ru, en-US, en");
```

This sets Russian first for website/content language negotiation. It does **not** set `intl.locale.requested`, bundle a Russian Firefox UI language pack, or by itself switch the browser chrome/UI locale to Russian.

### Short integration validation — PROVEN

- source SHA: `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- workflow: `Bundled extensions smoke`;
- run: `32976571124`;
- job: `98202642893`;
- evidence artifact: `9609725660` (`bundled-extensions-smoke`);
- result: success.

This run validates all three committed XPI baselines, registry hashes/versions, required permissions, the presence of each expected extension entry in `r3dfox/moz.build` and `browser/installer/package-manifest.in`, and the Russian-first language pref packaging declarations.

### Real Firefox build/package — PROVEN

The transition proof reused the still-CryptoPro-named full workflow:

- workflow: `CryptoPro Mozilla packaging smoke`;
- source SHA: `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- Actions run: `32976571122`;
- job: `98202641607`;
- packaged-browser artifact: `9614275050` (`r3dfox-cryptopro-mozilla-packaging`);
- packaging evidence artifact: `9614275551` (`cryptopro-mozilla-packaging-evidence`);
- result: success.

The job passed the full Firefox build and `mach package` path. The workflow's historical automated final gate explicitly revalidated CryptoPro in the portable archive; after the run, the exact uploaded artifact was inspected independently to close the whole shared bundle rather than infer it from the source declarations.

Exact portable archive inspected:

- file: `r3dfox-v153.0.3.win64.portable.7z` from artifact `9614275050`;
- SHA-256: `8cdc8ee6ca304787a549bb6879db1f47510bde4d7b9fdc65a56a994bbefed66a`.

The portable archive contains:

- `distribution/extensions/gosuslugi@plugin.xpi` — SHA-256 `f9a53a2fb4f33041676bf97d9ae9b061b67dde9ddbdc78221a06454381cd6cbc`, ID `gosuslugi@plugin`, version `1.3.43.0`;
- `distribution/extensions/pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru.xpi` — SHA-256 `72916b4ed2adefd91049fbd93aff5e028c423c971c2e0012603a2dae343bdc80`, ID `pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru`, version `1.2.8`;
- `distribution/extensions/ru.cryptopro.nmcades@cryptopro.ru.xpi` — SHA-256 `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`, ID `ru.cryptopro.nmcades@cryptopro.ru`, version `1.2.14`.

The same portable archive contains `omni.ja`, and inside it `defaults/pref/r3dfox-bundle.js` contains the exact Russian-first `intl.accept_languages` preference. Therefore the shared three-extension Mozilla staging and final portable-package inclusion are formally proven for this exact run/SHA.

### Remaining runtime/workflow boundary

The new shared package has **not yet** been runtime-proven in a clean profile. The next runtime artifact is `9614275050`; verify all three extensions are discovered/enabled and then test the two Gosuslugi extensions with their required native components. The earlier CryptoPro clean-profile proof remains authoritative only for artifact `9569387758` until CryptoPro is rechecked in the new three-extension build.

The full-build workflow still carries its historical CryptoPro-specific name and automated final assertions. Generalize it later into one shared bundled-extension regression workflow that checks all three XPI plus the packaged language pref. Do not create three separate full Firefox builds.

Transfer into `.github/workflows/gost-poc-build.yml` and `.github/workflows/gost-poc-build-thunk.yml` also remains open. A successful extension package does not establish GOST TLS behavior or Windows Vista/7 compatibility.
