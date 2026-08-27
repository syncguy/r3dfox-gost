# r3dfox GOST TLS — Done / Closed Work

Last updated: 2026-08-27

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

This closes the standalone updater/fallback contract only. Real Mozilla packaging integration, final portable-archive inclusion, transfer into the two main browser workflows, and Firefox runtime behavior remain separate work.

### CryptoPro real Mozilla portable-packaging integration — COMPLETE

Formal passing evidence:

- source SHA: `17b8d9762b489ed8fc9c3a8e1595802065dd7188`;
- run `32847887872`;
- job `97801745453`;
- evidence artifact `9569388324` (`cryptopro-mozilla-packaging-evidence`);
- packaged-browser artifact `9569387758` (`r3dfox-cryptopro-mozilla-packaging`);
- result: success.

Confirmed in one exact run/SHA:

- updater/selection succeeded;
- the full Firefox build succeeded;
- the selected XPI passed exact verification in real `dist/bin/distribution/extensions`;
- `mach package` succeeded;
- the produced portable archive passed the final exact XPI path/hash/manifest-ID gate under `distribution/extensions`.

This closes the final-portable-archive blocker from failed run `32817910715`, job `97709832302`; that failure remains historical evidence of the diagnosed `browser/installer/package-manifest.in` omission. The dedicated real Mozilla packaging proof is complete.

### CryptoPro clean-profile discovery and basic functional runtime — COMPLETE

Authoritative packaged-browser evidence:

- source SHA: `17b8d9762b489ed8fc9c3a8e1595802065dd7188`;
- run `32847887872`;
- job `97801745453`;
- packaged-browser artifact `9569387758` (`r3dfox-cryptopro-mozilla-packaging`).

The user tested that exact portable artifact with a new profile and confirmed:

- the bundled `ru.cryptopro.nmcades@cryptopro.ru` extension is discovered automatically without manual XPI installation;
- version `1.2.14` is enabled in Add-ons Manager;
- normal CryptoPro signature-verification functionality works.

This closes clean-profile discovery/install and basic functional-use questions for the tested artifact. A real version-to-version automatic extension update remains separately open in `TODO.md`; the current source configuration indicates that automatic updates are enabled by default, but that update transition has not yet been observed in runtime evidence.

Transfer of the proven packaging gates into the two main browser workflows also remains separate open work in `TODO.md`.

### Three-extension government bundle real portable packaging — COMPLETE

Formal passing evidence:

- source SHA: `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- companion short validation: run `32976571124`, job `98202642893`, evidence artifact `9609725660`;
- full Firefox packaging run: `32976571122`, job `98202641607`;
- packaged-browser artifact: `9614275050` (`r3dfox-cryptopro-mozilla-packaging`);
- packaging evidence artifact: `9614275551` (`cryptopro-mozilla-packaging-evidence`);
- result: success.

The exact `r3dfox-v153.0.3.win64.portable.7z` from that artifact was independently inspected and contains the three expected signed XPI baselines under `distribution/extensions`: CryptoPro `1.2.14`, legacy Gosuslugi/IFCPlugin `1.2.8`, and Gosplugin `1.3.43.0`, each with the expected repository SHA-256 and manifest identity. The same portable archive's `omni.ja` contains `defaults/pref/r3dfox-bundle.js` with Russian first in `intl.accept_languages` (`ru, en-US, en`).

This closes shared Mozilla staging plus final portable-package inclusion for the three-extension bundle. It does not prove native-component functionality of the two Gosuslugi extensions, does not change the browser UI locale, and does not close extension update behavior or transfer/generalization of the packaging gates into the main browser workflows; those remain in `TODO.md`.

### Three-extension clean-profile discovery/enabled state — COMPLETE

Runtime evidence uses the exact packaged browser from the preceding milestone:

- source SHA `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- full packaging run `32976571122`, job `98202641607`;
- packaged-browser artifact `9614275050`.

On 2026-08-27 the user launched this build with a completely new dedicated profile at `C:\Temp\r3dfox\profile`, explicitly clearing `R3DFOX_GOST_HOSTS`, `R3DFOX_GOST_CLIENT_CERT_THUMBPRINT`, `R3DFOX_GOST_CLIENT_AUTH_MODE`, and `R3DFOX_GOST_CIPHERS`, and opened `https://esia.gosuslugi.ru/login`. In that fresh profile, `about:addons` showed all three bundled project extensions simultaneously under **Enabled**: CryptoPro Extension for CAdES Browser Plug-in, Gosplugin, and the legacy Gosuslugi plugin extension.

The visible uBlock Origin entry is expected on a fresh profile because `r3dfox/policies.json` installs `uBlock0@raymondhill.net` with `installation_mode: normal_installed`; it is not evidence of prior profile state.

This closes clean-profile discovery/enabled-state for the exact three-extension artifact. It does not independently expose runtime ID/version values and does not prove CryptoPro functionality on this exact package, either Gosuslugi nativeMessaging path, extension update behavior, or runtime language-preference behavior. Those remain separate runtime gates.
