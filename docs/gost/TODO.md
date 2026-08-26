# r3dfox GOST TLS — TODO / Deferred Work

This file is the persistent forward-looking backlog for work that is desired but not yet complete.

- [`PROJECT_STATE.md`](./PROJECT_STATE.md) is the authoritative current-state synthesis.
- [`DONE.md`](./DONE.md) is the compact registry of formally closed milestones and conclusions.
- The current [`TEST_LOG.md`](./TEST_LOG.md) is the active evidence trail, with earlier evidence preserved in dated `TEST_LOG_*.md` volumes.

Completed work does not remain here as historical narrative. When a milestone closes, preserve its detailed evidence in the test log, add a concise closure entry to `DONE.md`, and remove the completed task from this backlog.

## GOST TLS runtime — next

### 1. Complete fail-closed server-certificate verification

Stage 2.1 diagnosis is complete and recorded in `DONE.md` / `TEST_LOG.md`.

The original blocker is no longer an unknown `msspi_get_verify_status()` failure. Source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e` switches peer-certificate acquisition to `SECPKG_ATTR_REMOTE_CERT_CONTEXT`, and runtime on the main artifact from run `32844083378`, job `97789764275`, now shows the real Treasury server reaching `verify ok=1 status=0x00000000` with peer certificate and chain available.

Required work:

- fail closed when `verifyOk == 0` or the verification status is nonzero;
- integrate Firefox temporary/permanent certificate overrides and the positive session-verification cache defined in `STAGE2_PLAN.md`;
- prove the real Treasury server certificate and hostname succeed through the final gate;
- prove a wrong hostname and an invalid/untrusted chain are rejected;
- prove client identity/private-key operations cannot occur before server trust is established;
- do not introduce a production bypass that converts failed server verification into success.

This is a mandatory Stage 2 security gate before GOST mTLS integration can be treated as closed.

### 2. Complete Firefox-facing client-certificate selection and mTLS security/UX closure

Stage 1 explicit-selector mTLS is formally complete and recorded in `DONE.md`. The explicit local selector remains useful only as a controlled diagnostic/reference path while the Firefox-facing flow is implemented and compared against the known-good behavior.

#### Current implementation checkpoint

The first coordinated Stage 2 implementation is full-browser build/package validated in the authoritative main workflow at exact source SHA `860de8e38deed326b7fcd1c547e928c5b48c72a9`.

- short compile workflow: `GOST SSL compile check`;
- compile run `32951902976`, job `98124948374`, result: success including `Compile security manager SSL target objects`;
- main full-build workflow: `GOST TLS PoC build`;
- full-build run `32951903026`, attempt 2, job `98130275465`, result: success;
- release artifact `9606431408` (`r3dfox-gost-win64-release`);
- Win7 import-audit artifact `9606431864` (`r3dfox-gost-win64-win7-import-audit`).

This source defaults to coordinated client auth and retains `R3DFOX_GOST_CLIENT_AUTH_MODE=legacy` for same-binary A/B comparison with the previously working per-socket picker. It contains the first single-flight/waiter broker, GOST-scoped `Once` default, positive-only custom remembering, coordinated stale-callback guards, Necko client-auth requested/selected forwarding, a quiescent-wait poll path and the agreed picker presentation changes.

Attempt 1 of main run `32951903026`, job `98124948716`, was cancelled during checkout and is superseded as build evidence by successful attempt-2 job `98130275465` at the same exact source SHA. The thunk-rs run `32951903069`, job `98124948880`, remains cancelled during checkout and provides no evidence for that separate Windows-compatibility line. The main full-build gate no longer blocks Stage 2 runtime validation.

The last runtime-proven Firefox-facing baseline remains source `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`, main build run `32844083378`, job `97789764275`, artifact `9567881847`. Release artifact `9606431408` is the exact coordinated-source browser artifact for the next runtime matrix.

That earlier runtime baseline established that the picker is runtime-reachable and a timely selection can complete real Treasury mTLS, but also exposed the 30-second unanswered-picker timeout, `MSSPI_X509_LOOKUP` busy-spin, sticky negative session caching after involuntary teardown, and duplicate per-socket picker races under parallel login requests.

Required work:

1. Run coordinated mode from exact release artifact `9606431408` against the real Treasury login and prove that compatible concurrent requests produce one visible picker, all live waiters resume correctly, no queued duplicate picker appears after selection, and the authenticated application flow still succeeds.
2. Re-run the unanswered-picker scenario and quantify `DriveHandshake` / `GostPoll` activity and log growth. Prove that the earlier ~2.5k-iterations/s busy-spin is gone rather than assuming it from the new poll code.
3. Verify the exact Firefox/Necko 30-second TLS-handshake timeout interaction while the coordinated picker is outstanding. `ClientAuthCertificateRequested/Selected` is now wired in the full-build-validated source, but runtime must show whether this is sufficient. Do not globally increase or disable the timeout to mask a lifecycle bug.
4. Prove retry/F5/new navigation after involuntary picker/load teardown starts a fresh decision and shows the picker again. No null callback from an abandoned attempt may poison later connections.
5. Close the remaining semantic distinction between explicit `Declined` and involuntary `Aborted`. Positive-only remembering and default `Once` remove the known sticky-negative effect, but explicit Cancel versus teardown still needs a deliberate lifecycle contract and focused proof.
6. Verify `Once`, explicit `Session`, and explicit `Permanent` behavior. Only positive `Selected` may be remembered. `Declined`, `Aborted`, `NoUsableCertificate`, provider/private-key failure and `Failed` remain attempt-local.
7. Verify the agreed picker row/detail presentation in the real Russian UI, including Cyrillic `issuerCommonName`, the human-facing `Issued to` field, localized date rendering, and serial number remaining only in details.
8. Keep candidate discovery dynamic across attempts so adding/installing a certificate or making its private key available can recover without restarting the browser.
9. Complete the final use of the server-provided acceptable-issuer list for candidate filtering/selection, including validity/key-usage/private-key usability rules needed for production behavior.
10. Determine whether certificates that exist only on CryptoPro/removable key media become visible through the current `CurrentUser\\MY` enumeration when the media is inserted. If not, add a planned CSP/KSP/provider discovery layer; deduplicate identical certificates and prefer a currently usable hardware/removable private-key binding when the same certificate is visible through multiple sources.
11. Re-run the missing-media/provider scenario after the coordinator fix, including a provider wait longer than 30 seconds. Treat synchronous CryptoPro waiting as stock-parity behavior unless this produces a concrete browser/network regression; only then promote it to a separate async-provider architecture problem. Pinned MSSPI documents one-handle/single-thread use, so do not move a live handle between threads casually.
12. Keep the known-good explicit selector as a priority diagnostic comparison path only while the Firefox flow is being proved; the final normal UX must not depend on a hard-coded or repository-visible certificate identifier.
13. Test negative paths: no acceptable certificate, explicit no-certificate choice, dialog/load abort, wrong certificate, expired/not-yet-valid or unsuitable-usage certificate where available, missing/unavailable private key, CryptoPro PIN/private-key failure, and server rejection.
14. Audit diagnostics and artifacts so no complete certificate fingerprint/thumbprint, serial, identifying subject/issuer DN, provider/container identifier, PIN/password, PFX content, account data, or other sensitive user-derived value is published.
15. Re-run the successful Treasury mTLS scenario after Stage 2 hardening and preserve a sanitized exact-run/exact-SHA regression proof.

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