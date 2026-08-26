# r3dfox GOST TLS — Project State

Last updated: 2026-08-26

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
- default explicit GOST cipher policy is `C100:C101:C102:FF85:0081`; `R3DFOX_GOST_CIPHERS=default` retains MSSPI native selection for diagnostics.

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

## Current GOST Stage 2 source-under-test

The current Firefox-facing client-auth and server-certificate acquisition experiment is bound to:

- source SHA `5e8c8821b93a31ae92f07853f1fa2b20bd7b168e`;
- main Actions run `32844083378`;
- job `97789764275`;
- artifact `9567881847` (`r3dfox-gost-win64-release`).

Do not confuse later docs-only HEADs with this binary source SHA.

### Server certificate acquisition / verification state

The source switches Windows MSSPI peer-certificate acquisition from unsupported `SECPKG_ATTR_REMOTE_CERT_CHAIN` to `SECPKG_ATTR_REMOTE_CERT_CONTEXT`, while keeping the existing `CertGetCertificateChain` path.

Runtime on the exact main artifact now obtains the Treasury peer certificate and chain and reports positive verification as `verify ok=1 status=0x00000000`. This closes the earlier acquisition failure but **does not close final server trust**. The wrapper still needs fail-closed enforcement and negative proof:

- reject if `verifyOk == 0`;
- reject any nonzero verification status;
- integrate Firefox temporary/permanent overrides and the positive session verification cache from `STAGE2_PLAN.md`;
- prove valid Treasury hostname/chain succeeds;
- prove wrong hostname and invalid/untrusted chain fail;
- ensure client identity/private-key operations cannot occur before server trust is established.

### Firefox-facing client-certificate picker: confirmed behavior

The asynchronous stock-Firefox picker path is runtime-reachable and a timely selection can complete real Treasury mTLS. Current candidate discovery enumerates `CurrentUser\\MY`, requires `CERT_KEY_PROV_INFO_PROP_ID`, filters against the server acceptable-CA list, creates Firefox `nsIX509Cert` objects and invokes the stock client-auth dialog.

Runtime has established these lifecycle facts:

1. **Unanswered picker timeout / busy wait.** Firefox's built-in HTTP TLS-handshake timeout is 30 seconds. While the first custom async picker waits, `MSSPI_X509_LOOKUP` currently busy-polls instead of becoming quiescent. When Necko times the load out, tab-dialog teardown returns a null certificate with stock Session default; current code misclassifies that as a remembered decline and suppresses later prompts until process restart.
2. **Zero-candidate results are non-sticky.** When no eligible `CurrentUser\\MY` certificate exists, each new connection re-enumerates candidates; no negative decision is cached.
3. **Live MY recovery works.** Restoring an eligible certificate to `CurrentUser\\MY` while r3dfox remains running changes a later attempt from `count=0` to `count=1`; the picker opens and real mTLS can succeed without browser restart.
4. **Parallel requests need single-flight coordination.** The Treasury login flow can create several simultaneous client-auth handshakes. The current one-picker-per-socket model requested five additional dialogs within about 20 ms. The user visibly received another picker after already choosing a certificate. Stale/queued dialog callbacks can coexist with positive remembered selections and later inject no-certificate decisions. The final architecture requires one compatible in-flight selection with multiple socket waiters and generation-safe stale-callback rejection.
5. **A certificate binding is not live-key availability.** A certificate can remain present and eligible in `CurrentUser\\MY` while the referenced CryptoPro private-key container is physically absent. `CERT_KEY_PROV_INFO_PROP_ID` proves binding metadata only.
6. **`client_cert_loaded=1` is not a private-key-availability proof.** The current wrapper sets this flag after `msspi_set_mycert()` accepts the certificate DER. Actual private-key acquisition/use happens later during `msspi_connect()` inside SSPI/CryptoPro; a completed mTLS handshake is the proof that the key was obtained and used.
7. **Missing key media is recoverable.** In the exact main artifact, cancelling CryptoPro's insert-media prompt fails the current handshake with `0x8009030E` (`SEC_E_NO_CREDENTIALS`) but does not create a negative certificate decision. A later attempt in the same process succeeds when the key container is inserted. The confirming capture contains nine successful login-host mTLS handshakes after recovery, all TLS 1.2 / `0xFF85` with protected application traffic; the user entered the personal cabinet successfully.
8. **CryptoPro provider UI is synchronous inside the current Socket-Thread handshake call, but this is not yet classified as a GOST-specific blocker.** The confirmed insert-media waits hold one `msspi_connect()` call for about 14.1 seconds until Cancel and about 27.0 seconds until media insertion. A subsequent exact-source audit of Firefox 153 PSM found that stock `PK11PasswordPrompt()` also synchronously dispatches token/password UI to the main thread with `SyncRunnable::DispatchToThread(...)` and waits for the result on the originating TLS thread. Therefore synchronous token/provider waiting has a stock-Firefox analogue. It remains a parity/performance question unless runtime proves concrete network starvation, timeout corruption or another regression beyond normal Firefox token-auth behavior.

Exact Firefox source also confirms that the ordinary NSS client-auth picker follows an event-driven model: the socket-thread client-auth hook records the request and returns would-block; selection is performed on the main thread; the result returns to the Socket Thread. `NSSSocketControl::SetClientAuthCertificateRequest()` notifies `ClientAuthCertificateRequested()` so Happy Eyeballs can pause other racers. This is the right architectural model for eliminating the custom GOST picker spin. However the callback pair has not yet been proven, by source or runtime, to automatically suspend `nsHttpConnection`'s 30-second TLS-handshake timeout accounting; that part must be verified rather than assumed.

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

If a user explicitly remembered a positive certificate, a temporary provider failure such as missing key media or `SEC_E_NO_CREDENTIALS` must not automatically erase that positive decision. Conversely, with default `Once`, the next login normally asks for the certificate again.

Compatible concurrent client-auth requests must use a single-flight broker keyed at least by normalized host, port, OriginAttributes and exact acceptable-CA-list identity. One picker owns the decision; additional live MSSPI sockets wait for it; stale generations cannot mutate remembered state; positive result is distributed to compatible live waiters.

Candidate enumeration must not trigger invasive CryptoPro provider/PIN/media UI merely to populate the list. Any stronger key-usability probe must be silent/non-interactive, or actual key acquisition must remain deferred until after user selection.

Direct token-only certificate discovery remains open: current tests do not establish whether a certificate that exists only on inserted provider/removable media and is absent from `CurrentUser\\MY` becomes discoverable automatically. Add direct CSP/KSP/provider enumeration only if a focused runtime test proves the current store view cannot expose it.

### Current Stage 2 blockers / next experiments

1. Implement coordinated, quiescent Firefox client-auth lifecycle: single-flight picker, waiter model, generation-safe callbacks, positive-only remembering, and GOST-scoped `Once` default.
2. Integrate the picker wait with Firefox/Necko client-auth lifecycle so the wait becomes event-driven. Verify the exact 30-second timeout interaction rather than assuming `ClientAuthCertificateRequested/Selected` alone suspends timeout accounting; do not globally increase/disable the TLS timeout.
3. Re-run Treasury login after the picker lifecycle fix and prove one user selection safely resumes all compatible sockets without queued dialogs, negative cache poisoning or the earlier application 500 symptom.
4. Re-run the missing-media/provider scenario after that fix, including a provider wait longer than 30 seconds. Treat synchronous CryptoPro waiting as stock-parity behavior unless this produces a concrete browser/network regression; only then promote it to a separate async-provider architecture problem. Pinned MSSPI documents one-handle/single-thread use, so do not move a live handle between threads casually.
5. Complete fail-closed server verification and the valid/wrong-host/untrusted negative matrix.
6. Test direct token-only certificate discovery; add provider enumeration only if required.
7. Exercise explicit no-certificate, abort, missing media, provider Cancel, PIN/private-key failure, wrong certificate and server rejection paths; none may become sticky negative state.
8. Finish with a sanitized exact-run/exact-SHA Treasury mTLS regression proof.

## Windows Vista/7 compatibility track

This track remains independent from GOST handshake success.

Retained strategy:

- preserve Firefox `/MD` runtime model;
- YY-Thunks 1.2.2 `synchronization.lib` plus physically narrow ProcessPrng/precise-time providers;
- never broadly interpose the complete YY `kernel32.lib` before Rust/gkrust;
- audit final PE imports and validate on real target OS.

Important evidence:

- broad YY negative proof: run `32623108290`, job `97162633898`, SHA `a73f18e823c083c970eea649ce305da648640e2f`, duplicate `LockResource`;
- full xul narrow-strategy build/package: run `32695496647`, job `97336702701`, SHA `ae3d52f42b8b6b509c1263418bead8bb9324dd00`, artifact `9512347999`;
- the same exact portable package successfully starts on real Windows 7;
- representative modern Rust + narrow YY + pinned msvcr14x coexistence: run `32713958570`, job `97391163925`, SHA `1abf867307ca56b97b7f2fb41e5e58e86ee08463`.

Next Win7 work is full-Firefox msvcr14x integration, final PE audit, target-OS execution without the current compatibility bundle, and delay-load/runtime-path coverage. GOST TLS on Windows 7 must be tested separately and tied to its own exact build/log.

## Bundled government-system extensions track

This is a third independent track.

CryptoPro CAdES Firefox extension state:

- extension ID `ru.cryptopro.nmcades@cryptopro.ru`;
- committed fallback v1.2.14;
- updater `build/update-cryptopro-extension.py`;
- standalone updater/fallback/staging proof: run `32815118778`, job `97701728235`, SHA `2ad7025ca300613d39a227b9e7582a341260d648`;
- real Mozilla build/package proof: run `32847887872`, job `97801745453`, SHA `17b8d9762b489ed8fc9c3a8e1595802065dd7188`, packaged artifact `9569387758`;
- clean-profile runtime discovery and basic CryptoPro signature functionality are confirmed for that exact artifact.

Remaining extension work: transfer only the proven updater/final-package gates into the two main browser workflows, and later prove a real vendor version-to-version automatic update. Do not mix this work with GOST TLS runtime conclusions or Windows compatibility.

## Separation of conclusions

- Build success does not prove GOST handshake success.
- GOST transport success does not prove server trust or mTLS security closure.
- Positive `verify ok=1/status=0` proves the repaired acquisition/positive path for the tested server, not the final fail-closed policy.
- `msspi_set_mycert()` / `client_cert_loaded=1` proves the client certificate was installed into MSSPI, not that the private key was available; completed client-auth TLS proves actual key use.
- Current Firefox-facing mTLS is demonstrably functional but not production-ready because picker timeout/busy-wait, stale callbacks, concurrent picker races and final server-verification hardening remain open. Synchronous CryptoPro token/media UI remains under stock-parity/performance observation rather than being an independently proven blocker.
- Win7 loader/startup results and GOST runtime results are independent.
- Extension packaging/runtime results are independent from both GOST TLS and Win7 compatibility.

## Maintenance rule

After each meaningful test:

1. append exact source SHA, run/job/artifact where applicable, sanitized observation and conclusion to `TEST_LOG.md`;
2. keep dated `TEST_LOG_*.md` volumes immutable;
3. update this file when the current blocker, architecture, confirmed behavior, dependency or next experiment changes;
4. keep speculative interpretations clearly marked;
5. never publish client certificate/user/private-key identifiers or raw sensitive captures.