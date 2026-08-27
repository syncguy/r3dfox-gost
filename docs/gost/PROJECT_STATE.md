# r3dfox GOST TLS — Project State

Last updated: 2026-08-27

This file is the authoritative current technical synthesis for the project. Detailed experiment evidence belongs in the current [`TEST_LOG.md`](./TEST_LOG.md) and immutable dated `TEST_LOG_*.md` volumes; closed milestones are summarized in [`DONE.md`](./DONE.md); forward work is in [`TODO.md`](./TODO.md); the detailed Stage 2 contract is in [`STAGE2_PLAN.md`](./STAGE2_PLAN.md).

## Repository and branch policy

- Repository: `syncguy/r3dfox-gost`.
- Default / active development branch: `agent/gost-tls-poc`.
- Frozen baseline: `win-153`; do not modify, merge, rebase, or push it without explicit user instruction.
- PR #1 historically targets `win-153`; it does not define the active development branch.
- The project remains based on r3dfox / Firefox 153. Do not retarget to Firefox 154 until the user explicitly decides to update the base.

## Project objective and architecture

Add GOST TLS support to r3dfox while preserving normal Firefox NSS TLS for non-allowlisted hosts.

Current GOST path:

- allowlist through `R3DFOX_GOST_HOSTS`;
- Firefox/Necko retains proxy resolution, HTTP CONNECT, proxy auth and retry ownership;
- after `ProxyStartSSL()`, `nsGostSSLIOLayer.cpp` runs TLS through pinned `deemru/msspi` + Windows SSPI/CryptoPro;
- TLS is currently constrained to TLS 1.2 / HTTP/1.1 for the PoC;
- default explicit GOST cipher policy is `C100:C101:C102:FF85:0081`; `R3DFOX_GOST_CIPHERS=default` retains MSSPI native selection for diagnostics;
- the current Stage 2 source defaults the Treasury client-auth path to a coordinated Firefox picker implementation; `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` keeps the previously working per-socket picker path available for same-binary A/B comparison;
- the explicit local thumbprint selector remains a separate diagnostic/reference path and is not the intended final UX.

Pinned MSSPI source: `f1ae7bdb26bde1aab4e6ac9a293890b0f14a6232`.

## Confirmed GOST runtime milestones

### Basic proxy/GOST HTTPS

First complete main-build end-to-end success:

- workflow `GOST TLS PoC build`;
- run `32710363486`;
- job `97380247020`;
- source SHA `4887e07d847b1c3c2e13b491dcc85f50ddaa9804`;
- artifact `9518011746`.

The real Treasury site completes HTTP CONNECT, GOST TLS 1.2 with suite `0xFF85`, protected application traffic and full browser rendering including JavaScript/images. The alternative full-build strategy also succeeded at the same source SHA in run `32710363484`, job `97388836234`, artifact `9519011295`. Therefore basic proxy/GOST behavior is not specific to one Windows build strategy.

### Stage 1 explicit-selector Treasury mTLS

Known-good Stage 1 source:

- SHA `f5d04896e17f91f58b6a137af823360f4718eb29`;
- main run `32751967162`, job `97510763210`;
- SSL compile run `32751967187`, job `97510762872`;
- alternative full build run `32751967189`, job `97510762742`.

With a local diagnostic thumbprint selector, both full-build strategies successfully load the real CryptoPro-bound client certificate, complete Treasury TLS 1.2 / `0xFF85` mTLS and enter authenticated application workflows. The concrete client-certificate identifier remains private and must never be committed.

## Current GOST Stage 2 implementation checkpoint and runtime baseline

### Full-build-validated implementation checkpoint

The current coordinated client-auth implementation is bound to exact source SHA:

- source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9`;
- short compile workflow `GOST SSL compile check`, run `32951902976`, job `98124948374`, success including `Compile security manager SSL target objects`;
- main full-build workflow `GOST TLS PoC build`, run `32951903026`, attempt 2, job `98130275465`, success;
- release artifact `9606431408` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9606431864` (`r3dfox-gost-win64-win7-import-audit`).

This source is validated both by the short SSL compile gate and by the authoritative main full-browser build/package line. In run `32951903026` attempt 2, the full release build, xul import audit, package step, release upload, audit upload and final known-Win8+-import gate all completed successfully. Build success by itself is not runtime proof; the exact artifact now also has the coordinated Treasury runtime evidence recorded below.

The earlier job `98124948716` from attempt 1 of the same run was cancelled during checkout and is superseded as build evidence by successful attempt-2 job `98130275465` at the same exact source SHA. The separate thunk-rs workflow for the same exact source also now has a successful attempt 2: run `32951903069`, job `98205801026`, browser artifact `9613443984`, diagnostics artifact `9613444775`. That result belongs to the independent Windows Vista/7 compatibility line and is not GOST runtime evidence.

### Current coordinated Firefox-facing runtime checkpoint

The most recent Stage 2 Firefox-facing runtime evidence now belongs to the coordinated source itself:

- source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9`;
- main Actions run `32951903026`, attempt 2;
- job `98130275465`;
- artifact `9606431408` (`r3dfox-gost-win64-release`);
- runtime capture `gost_main_test_connect.zip`, SHA-256 `0756fe71a15ecd56a1576b026888b0a504fb941ab3958f1fda93653fc74c620b`;
- inner `gost.moz_log`, SHA-256 `f77e68a5a2c1673500ef8542f12b5db46f6b93d5160e8203fe189eb1913eed89`.

The exact browser was run with the explicit thumbprint selector disabled and default coordinated mode. The log confirms `mode=coordinated` and a real Treasury login reached three sequential client-auth decision waves. The first wave had one waiter; the next two each had five compatible waiters, with four sockets joining the already-open decision. All eleven resulting `lk-fzs.roskazna.ru` MSSPI handshakes completed successfully as TLS 1.2 / `0xFF85` with `client_cert_loaded=1`, and the user observed the personal cabinet loading successfully. There are no `E/GostTLS` entries or `0x800903xx` failures in the capture.

This proves real mTLS and concurrent-wave single-flight for the coordinated implementation. It also exposes the current UX blocker: the default `Once` choice is retained only for the lifetime of one active decision wave. After the final waiter consumes the positive selection, the decision is removed; because `Once` is intentionally not stored as a remembered decision, a later compatible wave opens a new picker. Treasury produced three such waves during one logical login, so the user had to select the same certificate three times. This is not the old stale queued-dialog race; each visible picker corresponds to a newly-created decision after the previous decision had completed.

The picker-wait path is substantially calmer than the old tight `MSSPI_X509_LOOKUP` loop but is not fully event-quiescent. The capture contains zero `MSSPI_X509_LOOKUP` markers and 534 `GostPoll client-auth wait quiescent` calls. During the second five-waiter wave, 242 calls occur over about 1.495 s (~162/s combined, ~32/s per waiter); during the third, 290 calls occur over about 1.242 s (~233/s combined, ~47/s per waiter). Treat this as residual periodic poll churn, not as a return to the previously measured thousands-of-iterations-per-second tight spin. The unanswered-picker >40 s experiment is still required before concluding that long waits and the 30-second timeout are correct.

### Earlier runtime evidence still authoritative for scenarios not yet rerun

The previous Firefox-facing runtime source/build remains authoritative for missing-media/provider and other scenarios that have not yet been repeated on `860de8e...`:

- source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`;
- main Actions run `32844083378`;
- job `97789764275`;
- artifact `9567881847` (`r3dfox-gost-win64-release`).

Do not attribute missing-media timing, provider-cancel recovery, or other exact observations from that artifact to the later coordinated binary until they are rerun. Conversely, coordinated single-flight/`Once` behavior from artifact `9606431408` must not be retroactively attributed to `5e8c8821...`.

### Server certificate acquisition / verification state

The runtime-proven `5e8c8821...` source switches Windows MSSPI peer-certificate acquisition from unsupported `SECPKG_ATTR_REMOTE_CERT_CHAIN` to `SECPKG_ATTR_REMOTE_CERT_CONTEXT`, while keeping the existing `CertGetCertificateChain` path.

Runtime on that exact main artifact obtains the Treasury peer certificate and chain and reports positive verification as `verify ok=1 status=0x00000000`. This closes the earlier acquisition failure but **does not close final server trust**. The wrapper still needs fail-closed enforcement and negative proof:

- reject if `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent overrides and the positive session verification cache from `STAGE2_PLAN.md`;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail;
- ensure client identity/private-key operations cannot occur before server trust is established.

### Coordinated Firefox client-auth implementation status

Source `860de8e38deed326b7fcd1c547e928c5b48c72a9` contains the first coordinated Stage 2 implementation of the agreed direction:

- coordinated/single-flight client-certificate decisions with multiple live MSSPI waiters;
- a same-binary `legacy` mode for comparison with the previously proven per-socket picker;
- GOST-scoped `Once` as the initial remember choice without changing Firefox's global client-auth remember default;
- positive-only custom GOST remembered selections, so null/no-certificate callbacks are not persisted as negative GOST session decisions;
- stale-callback/lifetime checks for coordinated decisions;
- `ClientAuthCertificateRequested()` / `ClientAuthCertificateSelected()` forwarding through `GostSocketControl` toward Necko's existing client-auth lifecycle;
- a coordinated picker-wait poll path that avoids the old repeated `MSSPI_X509_LOOKUP` re-entry;
- the agreed human-facing certificate picker row/detail formatting changes.

Runtime on exact artifact `9606431408` now proves several of these properties rather than merely build-validating them:

- the coordinated path is reachable in the real Treasury login;
- a timely positive selection completes real GOST mTLS;
- compatible concurrent requests join one active decision and receive the same selected certificate safely;
- the second and third Treasury waves each fan one visible picker out to five live sockets;
- no stale callback marker or negative remembered decision appears in the successful capture;
- the GOST-scoped `Once` default is visible in the picker and creates no custom `remembered` reuse marker;
- the old `MSSPI_X509_LOOKUP` tight re-entry is absent.

What is **not** yet correct is the lifetime of an explicit positive `Once` choice across one logical login. Current cleanup removes the coordinated decision as soon as its last live waiter consumes it, so sequential HTTP/1.1 connection waves approximately one second later trigger new dialogs. The needed next design is an attempt-local positive fanout/lease for compatible follow-on waves. It must not silently convert `Once` into `Session` or `Permanent`, and it must never retain a decline, abort, no-usable-certificate result, provider failure, or other negative state.

The current implementation also does not yet establish the full `Declined` versus involuntary `Aborted` distinction at the dialog callback/lifecycle contract level. Positive-only remembering and GOST `Once` prevent the previously observed automatic null callback from poisoning the custom GOST session cache, but explicit Cancel versus involuntary teardown still needs focused runtime/source closure.

### Firefox-facing client-certificate picker: runtime-proven behavior

The earlier asynchronous Firefox picker path in runtime source `5e8c8821...` established the baseline defects and recovery behavior. Candidate discovery enumerates `CurrentUser\\MY`, requires `CERT_KEY_PROV_INFO_PROP_ID`, filters against the server acceptable-CA list, creates Firefox `nsIX509Cert` objects and invokes the stock client-auth dialog.

Runtime evidence across the earlier and current coordinated artifacts establishes these lifecycle facts:

1. **Unanswered picker timeout / old busy wait remains a baseline defect until rerun.** On `5e8c8821...`, Firefox's built-in HTTP TLS-handshake timeout is 30 seconds. While the old custom async picker waits, `MSSPI_X509_LOOKUP` busy-polls. When Necko times the load out, tab-dialog teardown returns a null certificate with the old stock Session default; baseline code misclassifies that as a remembered decline and suppresses later prompts until process restart. The coordinated source removes the `MSSPI_X509_LOOKUP` re-entry in the successful short waits, but the >40 s timeout/teardown case has not yet been rerun.
2. **Zero-candidate results are non-sticky.** When no eligible `CurrentUser\\MY` certificate exists, each new connection re-enumerates candidates; no negative decision is cached.
3. **Live MY recovery works.** Restoring an eligible certificate to `CurrentUser\\MY` while r3dfox remains running changes a later attempt from `count=0` to `count=1`; the picker opens and real mTLS can succeed without browser restart.
4. **Concurrent single-flight is now runtime-proven, but one logical login still spans multiple decision waves.** The old per-socket model requested five additional dialogs within about 20 ms. On coordinated artifact `9606431408`, both observed five-socket bursts produced one `dialog requested` plus four `joined existing decision` events and only one visible picker per burst. However, Treasury created three sequential bursts in one login, and default `Once` caused three sequential pickers because the completed decision was not retained between bursts.
5. **A certificate binding is not live-key availability.** A certificate can remain present and eligible in `CurrentUser\\MY` while the referenced CryptoPro private-key container is physically absent. `CERT_KEY_PROV_INFO_PROP_ID` proves binding metadata only.
6. **`client_cert_loaded=1` is not a private-key-availability proof.** The wrapper sets this flag after `msspi_set_mycert()` accepts the certificate DER. Actual private-key acquisition/use happens later during `msspi_connect()` inside SSPI/CryptoPro; a completed client-auth TLS handshake is the proof that the key was obtained and used.
7. **Missing key media is recoverable on the earlier exact artifact.** Cancelling CryptoPro's insert-media prompt fails the current handshake with `0x8009030E` (`SEC_E_NO_CREDENTIALS`) but does not create a negative certificate decision. A later attempt in the same process succeeds when the key container is inserted. The confirming earlier capture contains nine successful login-host mTLS handshakes after recovery, all TLS 1.2 / `0xFF85` with protected application traffic; the user entered the personal cabinet successfully. This scenario must still be rerun after the coordinator lifetime fix.
8. **CryptoPro provider UI is synchronous inside the Socket-Thread handshake call, but this is not yet classified as a GOST-specific blocker.** The earlier confirmed insert-media waits hold one `msspi_connect()` call for about 14.1 seconds until Cancel and about 27.0 seconds until media insertion. A source audit of Firefox 153 PSM found that stock `PK11PasswordPrompt()` also synchronously dispatches token/password UI to the main thread with `SyncRunnable::DispatchToThread(...)` and waits for the result on the originating TLS thread. Therefore synchronous token/provider waiting has a stock-Firefox analogue. It remains a parity/performance question unless runtime proves concrete network starvation, timeout corruption or another regression beyond normal Firefox token-auth behavior.
9. **Picker wait is no longer a tight `MSSPI_X509_LOOKUP` loop, but residual `GostPoll` churn remains.** The current successful capture has no `MSSPI_X509_LOOKUP` markers while selection is pending. In five-waiter waves the nominally quiescent poll path is still called roughly 32–47 times/s per waiter. Long-duration behavior remains open.

Exact Firefox source also confirms that the ordinary NSS client-auth picker follows an event-driven model: the socket-thread client-auth hook records the request and returns would-block; selection is performed on the main thread; the result returns to the Socket Thread. `NSSSocketControl::SetClientAuthCertificateRequest()` notifies `ClientAuthCertificateRequested()` so Happy Eyeballs can pause other racers. This is the architectural model reflected in the coordinated source. However neither source inspection nor the current successful short-wait runtime proves that the callback pair automatically suspends `nsHttpConnection`'s 30-second TLS-handshake timeout accounting; that part must still be verified in runtime.

### Agreed final client-auth UX / state contract

The final implementation keeps the stock Firefox client-auth window, with GOST-specific invocation/lifecycle behavior where necessary.

Certificate presentation:

```js
`${cert.displayName}, действителен до ${date} [ ${cert.issuerCommonName} ]`
```

- use `cert.displayName` for the owner and for the details-field `Issued to`;
- use `cert.issuerCommonName` for the compact issuer label and verify Cyrillic rendering in runtime;
- keep serial number only in details.

Attempt states are separate from remember policy:

- `Pending`;
- `Selected`;
- `Declined`;
- `Aborted`;
- `NoUsableCertificate`;
- `Failed`.

Only explicit positive `Selected` may be remembered. `Declined`, `Aborted`, `NoUsableCertificate`, provider/private-key failure and `Failed` are attempt-local and must never poison later prompts.

**GOST picker default is `Once` only for the GOST invocation.** The global Firefox `security.client_auth_certificate_default_remember_setting` must not be changed. `Session` or `Permanent` applies only when the user explicitly chooses it.

If a user explicitly remembered a positive certificate, a temporary provider failure such as missing key media or `SEC_E_NO_CREDENTIALS` must not automatically erase that positive decision. Conversely, with default `Once`, a later independent login should ask for the certificate again. The current Treasury evidence adds an important distinction: compatible connection waves belonging to the **same logical login interaction** should be able to share the one explicit positive `Once` choice without turning it into a session-level remembered decision.

Compatible concurrent client-auth requests use a single-flight broker keyed at least by normalized host, port, OriginAttributes and exact acceptable-CA-list identity. Runtime now proves that one active decision safely fans a positive selection out to multiple live sockets. The remaining design question is how to extend that positive-only fanout across immediately-following compatible waves from the same logical login/navigation while keeping the scope narrower than `Session` and ensuring stale generations cannot mutate later state.

Candidate enumeration must not trigger invasive CryptoPro provider/PIN/media UI merely to populate the list. Any stronger key-usability probe must be silent/non-interactive, or actual key acquisition must remain deferred until after user selection.

Direct token-only certificate discovery remains open: current tests do not establish whether a certificate that exists only on inserted provider/removable media and is absent from `CurrentUser\\MY` becomes discoverable automatically. Add direct CSP/KSP/provider enumeration only if a focused runtime test proves the current store view cannot expose it.

### Current Stage 2 blockers / next experiments

1. **Fix positive `Once` lifetime across one logical Treasury login.** Preserve the one explicit positive selection across compatible sequential connection waves belonging to the same interaction, without changing the GOST default to `Session`, without writing a persistent/session remember entry, and without retaining any negative result. Prefer an explicit attempt/navigation-scoped lifetime over an arbitrary long cache; if a short grace lease is used, its scope and expiration must be deliberate and regression-tested.
2. Before rebuilding, reproduce the unanswered-picker case on exact artifact `9606431408` for >40 seconds. Measure log growth and `GostPoll` counts, verify whether the old tight spin remains gone over a long wait, and then retry/F5 after involuntary teardown. A fresh picker must appear rather than a sticky no-certificate decision.
3. Verify the exact 30-second Necko TLS-handshake timeout interaction. `ClientAuthCertificateRequested/Selected` is wired and short waits succeed, but runtime must establish whether a long user decision is paused/handled correctly; do not globally increase or disable the timeout as a substitute for correct lifecycle integration.
4. Exercise explicit no-certificate versus involuntary dialog/load abort and close the remaining `Declined`/`Aborted` semantic distinction. Neither path may poison later prompts.
5. After the `Once` lifetime/coordinator fix, re-run the missing-media/provider scenario, including a provider wait longer than 30 seconds. Treat synchronous CryptoPro waiting as stock-parity behavior unless this produces a concrete browser/network regression; only then promote it to a separate async-provider architecture problem. Pinned MSSPI documents one-handle/single-thread use, so do not move a live handle between threads casually.
6. Complete the picker-formatting/localization check in the real Russian UI, including Cyrillic `issuerCommonName` and the human-facing `Issued to` field. The current run confirms the revised dialog/default `Once` is visible, but it was not a complete formatting audit.
7. Complete fail-closed server verification and the valid/wrong-host/untrusted negative matrix.
8. Test direct token-only certificate discovery; add provider enumeration only if required.
9. Exercise no suitable cert, missing media, provider Cancel, PIN/private-key failure, wrong certificate and server rejection paths; none may become sticky negative state.
10. Finish with a sanitized exact-run/exact-SHA Treasury mTLS regression proof after the Stage 2 lifecycle/security fixes.

## Windows Vista/7 compatibility track

This track remains independent from GOST handshake success.

Retained strategy:

- preserve Firefox `/MD` runtime model;
- YY-Thunks 1.2.2 `synchronization.lib` plus physically narrow ProcessPrng/precise-time providers;
- never broadly interpose the complete YY `kernel32.lib` before Rust/gkrust;
- audit final PE imports and validate on real target OS.

Important evidence:

- broad YY negative proof: run `32623108290`, job `97162633898`, SHA `a73f18e823c083c970eea649ce305da648640e2f`, duplicate `LockResource`;
- original full xul narrow-strategy build/package: run `32695496647`, job `97336702701`, SHA `ae3d52f42b8b6b509c1263418bead8bb9324dd00`, artifact `9512347999`; the same exact portable package successfully starts on real Windows 7;
- current clean full-xul revalidation: run `32951903069`, attempt 2, job `98205801026`, SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9`, browser artifact `9613443984`, diagnostics artifact `9613444775`; full build/package/direct-import gate success;
- representative modern Rust + narrow YY + pinned msvcr14x coexistence: run `32713958570`, job `97391163925`, SHA `1abf867307ca56b97b7f2fb41e5e58e86ee08463`.

The current green thunk run confirms that the narrow YY/thunk-rs strategy still scales through a full Firefox/xul build/package at the coordinated Stage 2 source and passes the workflow's direct known-Win8+-import gate. It does not prove this newer artifact starts on real Windows 7, does not repair/prove the delay-load parser, and does not prove GOST TLS on Windows 7.

Next Win7 work is full-Firefox msvcr14x integration, final PE audit, target-OS execution without the current compatibility bundle, and delay-load/runtime-path coverage. GOST TLS on Windows 7 must be tested separately and tied to its own exact build/log.

## Bundled government-system extensions track

This is a third independent track. The current shared bundle contains three signed Firefox extensions:

- CryptoPro CAdES: ID `ru.cryptopro.nmcades@cryptopro.ru`, version `1.2.14`, committed SHA-256 `3df7ee8c7d655921abce942befc2bfd6e0ddcf9179e6173d72e35083844cc0e7`;
- legacy Gosuslugi/IFCPlugin: ID `pbafkdcnd@ngodfeigfdgiodgnmbgcfha.ru`, version `1.2.8`, committed SHA-256 `72916b4ed2adefd91049fbd93aff5e028c423c971c2e0012603a2dae343bdc80`, native host reference `ru.rtlabs.ifcplugin`;
- Gosplugin: ID `gosuslugi@plugin`, version `1.3.43.0`, committed SHA-256 `f9a53a2fb4f33041676bf97d9ae9b061b67dde9ddbdc78221a06454381cd6cbc`.

Current shared packaging checkpoint:

- source SHA `b3d097de20b7a5711f161199a727bcfe9468bcc8`;
- short `Bundled extensions smoke`: run `32976571124`, job `98202642893`, success, evidence artifact `9609725660`;
- full `CryptoPro Mozilla packaging smoke` transition run: `32976571122`, job `98202641607`, success;
- packaged-browser artifact `9614275050` (`r3dfox-cryptopro-mozilla-packaging`);
- packaging evidence artifact `9614275551` (`cryptopro-mozilla-packaging-evidence`).

The exact `r3dfox-v153.0.3.win64.portable.7z` from artifact `9614275050` has SHA-256 `8cdc8ee6ca304787a549bb6879db1f47510bde4d7b9fdc65a56a994bbefed66a`. Independent inspection confirms that this portable archive contains all three expected XPI paths under `distribution/extensions`, and each file matches the expected SHA-256, manifest ID and version above. Therefore shared Mozilla `FINAL_TARGET_FILES` staging plus the separate `browser/installer/package-manifest.in` package boundary are both proven for the three-extension bundle.

The same portable archive's `omni.ja` contains `defaults/pref/r3dfox-bundle.js` with:

```js
pref("intl.accept_languages", "ru, en-US, en");
```

This makes Russian the first website/content language preference. It does not change the Firefox UI locale or bundle a Russian UI language pack.

Runtime state remains narrower than packaging state. CryptoPro clean-profile discovery and basic signature functionality were proven earlier on artifact `9569387758`, but the new three-extension artifact `9614275050` has not yet been clean-profile/runtime-tested. The immediate extension experiment is to start that exact package with a clean profile, confirm all three extensions are discovered/enabled, re-check CryptoPro functionality, and test both Gosuslugi extensions with their required external native components. After that, generalize the still-CryptoPro-named full packaging workflow so its automated final gates explicitly assert all three XPI and the packaged language pref, then transfer only the proven shared gates into the two main browser workflows. Real version-to-version update behavior remains separately open.

## Separation of conclusions

- Build success does not prove GOST handshake success.
- The successful short SSL compile gate and main full build at source `860de8e...` prove compilation plus full Firefox build/package viability of the coordinated Stage 2 changes; the later exact-artifact runtime capture separately proves real coordinated Treasury mTLS and concurrent-wave fanout.
- The successful thunk-rs full build at the same source proves the current Windows-compatibility build/package/direct-import strategy at full-xul scale; it does not prove real Windows 7 runtime or GOST TLS behavior on Windows 7.
- GOST transport success does not prove server trust or mTLS security closure.
- Positive `verify ok=1/status=0` proves the repaired acquisition/positive path for the tested earlier runtime server, not the final fail-closed policy.
- `msspi_set_mycert()` / `client_cert_loaded=1` proves the client certificate was installed into MSSPI, not by itself that the private key was available; completed client-auth TLS proves actual key use.
- Coordinated Firefox-facing mTLS is now demonstrably functional on exact artifact `9606431408`. Concurrent single-flight is proven within an active decision wave, while default-`Once` lifetime across sequential waves of one logical login is the current UX blocker. The old `MSSPI_X509_LOOKUP` tight spin is absent in the current short waits, but long-wait timeout handling and residual `GostPoll` churn remain open. Final Cancel/abort semantics and the complete picker-formatting audit also remain open.
- Synchronous CryptoPro token/media UI remains under stock-parity/performance observation rather than being an independently proven blocker.
- Win7 loader/startup results and GOST runtime results are independent.
- Extension packaging/runtime results are independent from both GOST TLS and Win7 compatibility.

## Maintenance rule

After each meaningful test:

1. append exact source SHA, run/job/artifact where applicable, sanitized observation and conclusion to `TEST_LOG.md`;
2. keep dated `TEST_LOG_*.md` volumes immutable;
3. update this file when the current blocker, architecture, confirmed behavior, dependency or next experiment changes;
4. keep speculative interpretations clearly marked;
5. never publish client certificate/user/private-key identifiers or raw sensitive captures.